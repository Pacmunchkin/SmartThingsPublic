# =============================================================================
# SCENE ARCHITECTURE — warlord.tscn
#
# Warlord (CharacterBody2D)        <- attach this script (warlord.gd) here
# ├── Sprite2D                     <- warlord visual
# ├── CollisionShape2D             <- physics collision shape
# └── Retinue (Node2D)             <- plain Node2D; drop recruit.tscn
#     ├── Recruit (recruit.tscn)      instances in here. Each recruit found
#     └── ...                         here at scene start follows this
#                                     warlord and adds +1 to army_size.
#
# CONTROLLER (added per instance in the LEVEL scene, not inside
# warlord.tscn) — the same warlord scene serves player and AI:
#
#   WarlordA (warlord.tscn, Team 0)       EnemyWarlord (warlord.tscn, Team 1)
#   └── Controller (Node)                 └── AIController (Node)
#       [player_controller.gd]                [ai_controller.gd]
#
# warlord.gd finds its controller by wildcard name "*Controller" and asks
# it for a move direction every physics frame. No controller = stands still
# (but still auto-attacks and can still be fought).
#
# Extends Combatant (combatant.gd) for team / health / died handling.
#
# COMBAT: the warlord cannot be targeted while any of its retinue lives
# (can_be_targeted below). Once the retinue is defeated, enemy recruits
# turn on the warlord. The warlord auto-attacks the nearest enemy inside
# attack_range every attack_interval — movement comes from the controller,
# the swings are automatic.
#
# DEATH IS PERMANENT: the warlord is removed from the game and
# WarlordCommander drops it (its select button goes dead).
#
# Planned (not yet implemented):
#   - Exported variables + a Warlord character Resource (.tres) will control
#     special abilities, cooldowns, and special items.
# =============================================================================

extends Combatant
class_name Warlord

# --- Movement ---------------------------------------------------------------
@export var move_speed: float = 200.0  # pixels per second

# --- Combat -----------------------------------------------------------------
# TUNING — "worth 5 recruits": beats 5 default recruits (10 HP, 2 dmg,
# 1 hit/s) attacking together, dies to 6. At 5 dmg/hit the warlord kills a
# recruit every 2 s; N simultaneous attackers land 50-60 total damage for
# N=5 and 72-84 for N=6 (range covers hit-order timing). max_health = 65
# sits between those bands: 5 always lose, 6 always win.
# If you change recruit combat exports, this breakpoint moves — retune.
@export var max_health: float = 65.0
@export var attack_damage: float = 5.0
@export var attack_interval: float = 1.0 # seconds between attacks
@export var attack_range: float = 24.0   # close enough to swing

# --- Retinue / army ---------------------------------------------------------
# Villages stop mustering recruits into this retinue once it is full.
@export var max_retinue: int = 50

# The unit type this warlord's recruits fight as (Seaxes, Axes, Spears,
# Shield & Sword, Bows). Drag a UnitType .tres here. Every recruit that
# joins the retinue takes these stats. Empty = recruit script defaults.
@export var unit_type: UnitType

# --- Abilities --------------------------------------------------------------
# Cooldown powers, one per d-pad direction: hold X + press Up/Left/Right
# (handled by WarlordCommander for the selected warlord). Drag Ability
# .tres assets here. Effects apply to this warlord AND its retinue.
@export var ability_up: Ability
@export var ability_left: Ability
@export var ability_right: Ability

# --- Selection --------------------------------------------------------------
# Set by WarlordCommander. Read by PlayerController: only the selected
# player warlord responds to the stick. Meaningless for AI warlords.
var is_selected: bool = false

# +1 per recruit under this warlord's command, -1 when one dies.
var army_size: int = 0

var _attack_timer: float = 0.0
var _controller: WarlordController = null
var _ability_cooldowns: Array[float] = [0.0, 0.0, 0.0]  # up, left, right
var _active_effects: Array[Dictionary] = []  # {ability: Ability, time_left: float}

@onready var _retinue: Node2D = $Retinue

func _ready() -> void:
	super._ready()
	add_to_group("warlords")
	health = max_health
	_controller = find_child("*Controller", false, false) as WarlordController
	for child in _retinue.get_children():
		if child is Recruit:
			add_recruit(child)

# Puts a recruit under this warlord's command: retinue recruits placed in
# the scene at start, and garrison recruits mustered by a Village.
func add_recruit(recruit: Recruit) -> void:
	recruit.team = team
	if unit_type != null:
		recruit.apply_unit_type(unit_type)
	recruit.set_follow_target(self)
	recruit.died.connect(_on_recruit_died)
	army_size += 1
	if recruit.get_parent() != _retinue:
		recruit.reparent.call_deferred(_retinue)

# Untouchable while the retinue lives — unless leading from the front
# (Warlord Leads active). Fair game once the retinue is defeated.
func can_be_targeted() -> bool:
	if army_size <= 0:
		return true
	for effect in _active_effects:
		var ability: Ability = effect.ability
		if ability.effect == Ability.Effect.WARLORD_LEADS:
			return true
	return false

func _physics_process(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_update_abilities(delta)
	stun_timer = maxf(stun_timer - delta, 0.0)
	if is_stunned():
		velocity = Vector2.ZERO
		return
	_auto_attack()
	var direction := Vector2.ZERO
	if _controller != null:
		direction = _controller.get_move_direction().limit_length(1.0)
	velocity = direction * move_speed * speed_multiplier
	move_and_slide()

# --- Abilities --------------------------------------------------------------

# Called by WarlordCommander. Slots: 0 = up, 1 = left, 2 = right.
func activate_ability(slot: int) -> void:
	var ability := _get_ability(slot)
	if ability == null or _ability_cooldowns[slot] > 0.0:
		return
	_ability_cooldowns[slot] = ability.cooldown
	match ability.effect:
		Ability.Effect.KNOCK_BACK:
			_do_knock_back(ability)  # instant, nothing sustained
		Ability.Effect.WARLORD_LEADS:
			_heal_retinue(ability.magnitude)
			_active_effects.append({"ability": ability, "time_left": ability.duration})
		_:
			_active_effects.append({"ability": ability, "time_left": ability.duration})

# Shove every enemy unit within radius away from the warlord and stun it.
func _do_knock_back(ability: Ability) -> void:
	for node in get_tree().get_nodes_in_group("combatants"):
		var other := node as Combatant
		if other == null or other == self or other.team == team:
			continue
		if other.is_structure():
			continue
		var offset: Vector2 = other.global_position - global_position
		if offset.length() > ability.radius:
			continue
		var push := offset.normalized() if offset.length() > 0.0 else Vector2.RIGHT
		other.move_and_collide(push * ability.magnitude)
		other.stun(ability.duration)

# Warlord Leads: an immediate rally — heal each retinue recruit.
func _heal_retinue(amount: float) -> void:
	for child in _retinue.get_children():
		if child is Recruit:
			child.health = minf(child.health + amount, child.max_health)

func _get_ability(slot: int) -> Ability:
	match slot:
		0: return ability_up
		1: return ability_left
		2: return ability_right
	return null

func _update_abilities(delta: float) -> void:
	for i in _ability_cooldowns.size():
		_ability_cooldowns[i] = maxf(_ability_cooldowns[i] - delta, 0.0)
	var any_expired := false
	for effect in _active_effects:
		effect.time_left -= delta
		if effect.time_left <= 0.0:
			any_expired = true
	if any_expired:
		_active_effects = _active_effects.filter(
				func(e: Dictionary) -> bool: return e.time_left > 0.0)
	_apply_ability_modifiers()

# Recompute and push modifiers to self and the whole retinue.
func _apply_ability_modifiers() -> void:
	var speed_mult := 1.0
	var damage_mult := 1.0
	for effect in _active_effects:
		var ability: Ability = effect.ability
		match ability.effect:
			Ability.Effect.CHARGE:
				speed_mult *= ability.magnitude
			Ability.Effect.STEADFAST:
				damage_mult *= ability.magnitude
	speed_multiplier = speed_mult
	damage_taken_multiplier = damage_mult
	for child in _retinue.get_children():
		if child is Recruit:
			child.speed_multiplier = speed_mult
			child.damage_taken_multiplier = damage_mult

# Swing at the nearest targetable enemy in reach, on cooldown.
# Living enemies outrank structures (e.g. a city gate).
func _auto_attack() -> void:
	if _attack_timer > 0.0:
		return
	var best_unit: Combatant = null
	var best_unit_dist: float = attack_range
	var best_structure: Combatant = null
	var best_structure_dist: float = attack_range
	for node in get_tree().get_nodes_in_group("combatants"):
		var other := node as Combatant
		if other == null or other == self or other.team == team:
			continue
		if not other.can_be_targeted():
			continue
		# Reach is measured to the target's edge (see target_radius).
		var dist := global_position.distance_to(other.global_position) \
				- other.target_radius()
		if other.is_structure():
			if dist <= best_structure_dist:
				best_structure_dist = dist
				best_structure = other
		elif dist <= best_unit_dist:
			best_unit_dist = dist
			best_unit = other
	var target := best_unit if best_unit != null else best_structure
	if target != null:
		_attack_timer = attack_interval
		target.take_damage(attack_damage)

func _on_recruit_died(_recruit: Combatant) -> void:
	army_size -= 1
