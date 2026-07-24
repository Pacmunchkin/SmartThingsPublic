# =============================================================================
# SCENE ARCHITECTURE — warlord.tscn
#
# Warlord (CharacterBody2D)        <- attach this script (warlord.gd) here
# ├── Sprite2D                     <- warlord visual
# ├── CollisionShape2D             <- physics collision shape
# ├── HealthBar (Node2D)           <- health_bar.gd, position (0, 18)
# ├── SelectionMarker (Node2D)     <- selection_marker.gd, position (0, -24)
# ├── NavigationAgent2D            <- OPTIONAL. Only AI warlords use it (to
# │                                   path around walls — see ai_controller
# │                                   .gd). The PLAYER warlord ignores it:
# │                                   it is stick-controlled and just
# │                                   collides with walls via move_and_slide.
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

# --- Identity ---------------------------------------------------------------
# Shown on the HUD and in menus. Leave empty to draw a random Norse name
# from warlord_names.csv at scene start (see name_pool.gd).
@export var warlord_name: String = ""

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

# --- Renown -----------------------------------------------------------------
# Morale/veterancy, earned by DEEDS (never by waiting): +1 for conquering
# a village, defeating a burh garrison, destroying a city gate, or killing
# an enemy warlord. Levels 0..RENOWN_MAX. Longship replacements will start
# at 0; set your starting warlords to 2 in the Inspector.
# Per level: warlord +10% max health; retinue +5% max health, +2% speed.
@export var renown: int = 0

const RENOWN_MAX: int = 5
const RENOWN_WARLORD_HEALTH: float = 0.10   # warlord max HP per level
const RENOWN_RETINUE_HEALTH: float = 0.05   # retinue max HP per level
const RENOWN_RETINUE_SPEED: float = 0.02    # retinue speed per level

# Renown needed to USE each ability slot (up, left, right). Locked slots
# ignore activation and show as LOCKED on the HUD. Newly unlocked slots
# are filled by visiting a Church (see church.gd / war_council.gd).
const ABILITY_SLOT_RENOWN: Array[int] = [0, 2, 4]

# --- Selection --------------------------------------------------------------
# Set by WarlordCommander. Read by PlayerController: only the selected
# player warlord responds to the stick. Meaningless for AI warlords.
var is_selected: bool = false

# +1 per recruit under this warlord's command, -1 when one dies.
var army_size: int = 0

# Idle target searches run at most 4x/s; swings at enemies already in
# reach are never delayed, so combat pacing (and 5-vs-6 tuning) is intact.
const TARGET_SCAN_INTERVAL: float = 0.25

var _attack_timer: float = 0.0
var _controller: WarlordController = null
var _ability_cooldowns: Array[float] = [0.0, 0.0, 0.0]  # up, left, right
var _active_effects: Array[Dictionary] = []  # {ability: Ability, time_left: float}
var _scan_timer: float = 0.0
var _base_max_health: float = 65.0  # pre-renown max health

@onready var _retinue: Node2D = $Retinue

func _ready() -> void:
	super._ready()
	add_to_group("warlords")
	if warlord_name.strip_edges().is_empty():
		warlord_name = NamePool.draw()
	renown = clampi(renown, 0, RENOWN_MAX)
	_base_max_health = max_health
	max_health = _base_max_health * (1.0 + RENOWN_WARLORD_HEALTH * renown)
	health = max_health
	_scan_timer = randf() * TARGET_SCAN_INTERVAL  # stagger scans across units
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
	recruit.apply_health_bonus(1.0 + RENOWN_RETINUE_HEALTH * renown)
	recruit.set_follow_target(self)
	recruit.died.connect(_on_recruit_died)
	army_size += 1
	if recruit.get_parent() != _retinue:
		recruit.reparent.call_deferred(_retinue)

# Renown credit for my own hits flows to me.
func get_credited_warlord() -> Warlord:
	return self

# Called by the War Council loadout menu before the level begins.
# Null keeps the Inspector-assigned value. The chosen ability fills the
# UP slot; Left/Right slots are untouched (renown unlocks them later).
func set_loadout(new_unit_type: UnitType, first_ability: Ability) -> void:
	if new_unit_type != null:
		unit_type = new_unit_type
		for child in _retinue.get_children():
			if child is Recruit:
				child.apply_unit_type(unit_type)
				child.apply_health_bonus(1.0 + RENOWN_RETINUE_HEALTH * renown)
	if first_ability != null:
		ability_up = first_ability

# --- Renown -----------------------------------------------------------------

func add_renown(amount: int) -> void:
	var new_renown := clampi(renown + amount, 0, RENOWN_MAX)
	if new_renown == renown:
		return
	renown = new_renown
	# Warlord max health rises with reputation; the gain heals.
	var old_max := max_health
	max_health = _base_max_health * (1.0 + RENOWN_WARLORD_HEALTH * renown)
	health += maxf(max_health - old_max, 0.0)
	# The retinue's trust rises with it.
	for child in _retinue.get_children():
		if child is Recruit:
			child.apply_health_bonus(1.0 + RENOWN_RETINUE_HEALTH * renown)

# Called by Combatant._award_kill_credit on the victim's death.
# Only the great deeds count — recruits fall uncounted.
func on_enemy_killed(victim: Combatant) -> void:
	if victim is Warlord or victim is CityGate:
		add_renown(1)

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
	_scan_timer = maxf(_scan_timer - delta, 0.0)
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
	if not is_slot_unlocked(slot):
		return
	var ability := get_ability(slot)
	if ability == null or _ability_cooldowns[slot] > 0.0:
		return
	_ability_cooldowns[slot] = ability.cooldown
	match ability.effect:
		Ability.Effect.KNOCK_BACK:
			_do_knock_back(ability)  # instant, nothing sustained
		Ability.Effect.DRAW_OUT:
			_do_draw_out(ability)    # instant taunt; commitment does the rest
		Ability.Effect.CALL:
			_do_call(ability)        # instant summons; recruits run over
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

# Draw Out: force every enemy recruit within radius to engage this army.
# Lures are the retinue; a retinue-less warlord lures onto itself.
func _do_draw_out(ability: Ability) -> void:
	var lures: Array[Combatant] = []
	for child in _retinue.get_children():
		if child is Recruit:
			lures.append(child)
	if lures.is_empty():
		lures.append(self)
	for node in get_tree().get_nodes_in_group("combatants"):
		var enemy := node as Recruit
		if enemy == null or enemy.team == team:
			continue
		if enemy.global_position.distance_to(global_position) > ability.radius:
			continue
		var nearest: Combatant = null
		var nearest_dist: float = INF
		for lure in lures:
			var dist := enemy.global_position.distance_to(lure.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = lure
		if nearest != null:
			enemy.force_engage(nearest)

# Call: every same-team village within radius sends its garrison running.
func _do_call(ability: Ability) -> void:
	for node in get_tree().get_nodes_in_group("villages"):
		var village := node as Village
		if village == null or village.team != team:
			continue
		if global_position.distance_to(village.global_position) > ability.radius:
			continue
		village.send_garrison(self)

func get_ability(slot: int) -> Ability:
	match slot:
		0: return ability_up
		1: return ability_left
		2: return ability_right
	return null

func is_slot_unlocked(slot: int) -> bool:
	return renown >= ABILITY_SLOT_RENOWN[slot]

# First slot unlocked by renown but with no ability assigned (-1 if none).
# The Church offers to fill this slot when the warlord visits.
func next_empty_unlocked_slot() -> int:
	for slot in 3:
		if is_slot_unlocked(slot) and get_ability(slot) == null:
			return slot
	return -1

# Called by WarCouncil when the player picks an ability at a Church.
func set_slot_ability(slot: int, ability: Ability) -> void:
	match slot:
		0: ability_up = ability
		1: ability_left = ability
		2: ability_right = ability

# Church sanctuary healing: restore this warlord and their retinue.
func heal_army(amount: float) -> void:
	health = minf(health + amount, max_health)
	for child in _retinue.get_children():
		if child is Recruit:
			child.health = minf(child.health + amount, child.max_health)

# --- UI queries (used by hud.gd) --------------------------------------------

func get_ability_cooldown(slot: int) -> float:
	return _ability_cooldowns[slot]

# Seconds a sustained ability has left, 0 if it is not currently active.
func get_ability_active_time(ability: Ability) -> float:
	for effect in _active_effects:
		if effect.ability == ability:
			return effect.time_left
	return 0.0

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
	var ranged_mult := 1.0
	var push := 0.0
	for effect in _active_effects:
		var ability: Ability = effect.ability
		match ability.effect:
			Ability.Effect.CHARGE:
				speed_mult *= ability.magnitude
			Ability.Effect.STEADFAST:
				damage_mult *= ability.magnitude
			Ability.Effect.DITCH:
				ranged_mult *= ability.magnitude
			Ability.Effect.ADVANCE:
				push = maxf(push, ability.magnitude)
	speed_multiplier = speed_mult
	damage_taken_multiplier = damage_mult
	ranged_damage_taken_multiplier = ranged_mult
	melee_push = push
	# Renown: a confident retinue runs in faster (stacks with Charge).
	var retinue_speed := speed_mult * (1.0 + RENOWN_RETINUE_SPEED * renown)
	for child in _retinue.get_children():
		if child is Recruit:
			child.speed_multiplier = retinue_speed
			child.damage_taken_multiplier = damage_mult
			child.ranged_damage_taken_multiplier = ranged_mult
			child.melee_push = push

# Swing at the nearest targetable enemy in reach, on cooldown.
# Living enemies outrank structures (e.g. a city gate).
func _auto_attack() -> void:
	if _attack_timer > 0.0:
		return
	if _scan_timer > 0.0:
		return  # last scan found nothing in reach; don't rescan every frame
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
	if target == null:
		_scan_timer = TARGET_SCAN_INTERVAL  # idle: wait before rescanning
		return
	_attack_timer = attack_interval
	target.take_damage(attack_damage, self)
	# Advance: the warlord's own hits shove the enemy back too.
	if melee_push > 0.0 and is_instance_valid(target) \
			and not target.is_structure():
		var offset: Vector2 = target.global_position - global_position
		var dir := offset.normalized() if offset.length() > 0.0 \
				else Vector2.RIGHT
		target.move_and_collide(dir * melee_push)

func _on_recruit_died(_recruit: Combatant) -> void:
	army_size -= 1
