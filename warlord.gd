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
# Extends Combatant (combatant.gd) for team / health / died handling.
# This scene is instanced multiple times inside main.tscn — see
# warlord_commander.gd for the main scene layout.
#
# COMBAT: the warlord cannot be targeted while any of its retinue lives
# (can_be_targeted below). Once the retinue is defeated, enemy recruits
# turn on the warlord. The warlord auto-attacks the nearest enemy inside
# attack_range every attack_interval, selected or not — movement stays
# player-controlled, the swings are automatic.
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

# --- Selection --------------------------------------------------------------
# Set by WarlordCommander. Only the selected warlord responds to the stick.
var is_selected: bool = false

# --- Retinue / army ---------------------------------------------------------
# +1 per recruit in the Retinue node at scene start, -1 when one dies.
var army_size: int = 0

var _attack_timer: float = 0.0

@onready var _retinue: Node2D = $Retinue

func _ready() -> void:
	super._ready()
	health = max_health
	for child in _retinue.get_children():
		if child is Recruit:
			child.team = team
			child.set_follow_target(self)
			child.died.connect(_on_recruit_died)
			army_size += 1

# Untouchable while the retinue lives; fair game once it is defeated.
func can_be_targeted() -> bool:
	return army_size <= 0

func _physics_process(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_auto_attack()
	if not is_selected:
		velocity = Vector2.ZERO
		return
	var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_dir * move_speed
	move_and_slide()

# Swing at the nearest targetable enemy in reach, on cooldown.
func _auto_attack() -> void:
	if _attack_timer > 0.0:
		return
	var target: Combatant = null
	var best_dist: float = attack_range
	for node in get_tree().get_nodes_in_group("combatants"):
		var other := node as Combatant
		if other == null or other == self or other.team == team:
			continue
		if not other.can_be_targeted():
			continue
		var dist := global_position.distance_to(other.global_position)
		if dist <= best_dist:
			best_dist = dist
			target = other
	if target != null:
		_attack_timer = attack_interval
		target.take_damage(attack_damage)

func _on_recruit_died(_recruit: Combatant) -> void:
	army_size -= 1
