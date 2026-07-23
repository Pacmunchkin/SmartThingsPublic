# =============================================================================
# SCENE ARCHITECTURE — battlement.tscn
#
# Battlement (Node2D)              <- attach this script (battlement.gd) here
# └── ColorRect                    <- gray box tower visual, e.g. 24x24,
#                                     offset -12,-12 so it is centered
#
# A stationary wall emplacement that shoots arrows at enemy units within
# arrow_range. Arrows (arrow.gd) fly to their target and deal damage on
# impact. Battlements are NOT Combatants: they cannot be targeted or
# destroyed by melee — the way past them is destroying the city gate and
# moving on (making them attackable can be a later iteration).
#
# Respects the warlord protection rule: it only shoots targets whose
# can_be_targeted() is true, so a warlord is safe until its retinue falls.
#
# Instanced inside city.tscn under Battlements (see city.gd), which
# assigns its team.
# =============================================================================

extends Node2D
class_name Battlement

# Only shoots combatants on a different team.
@export var team: int = 1

@export var arrow_range: float = 320.0  # start shooting inside this
@export var fire_interval: float = 2.0  # seconds between arrows
@export var arrow_damage: float = 2.0
@export var arrow_speed: float = 400.0  # pixels per second

# Idle target searches run at most 4x/s (staggered); an arrow is never
# delayed once an enemy is actually in range and the fire timer is ready.
const TARGET_SCAN_INTERVAL: float = 0.25

var _fire_timer: float = 0.0
var _scan_timer: float = 0.0

func _ready() -> void:
	_scan_timer = randf() * TARGET_SCAN_INTERVAL  # stagger scans across towers

func _physics_process(delta: float) -> void:
	_fire_timer = maxf(_fire_timer - delta, 0.0)
	_scan_timer = maxf(_scan_timer - delta, 0.0)
	if _fire_timer > 0.0 or _scan_timer > 0.0:
		return
	var target := _nearest_enemy()
	if target == null:
		_scan_timer = TARGET_SCAN_INTERVAL  # idle: wait before rescanning
		return
	_fire_timer = fire_interval
	var arrow := Arrow.new()
	arrow.target = target
	arrow.damage = arrow_damage
	arrow.speed = arrow_speed
	add_child(arrow)
	arrow.global_position = global_position

func _nearest_enemy() -> Combatant:
	var best: Combatant = null
	var best_dist: float = arrow_range
	for node in get_tree().get_nodes_in_group("combatants"):
		var other := node as Combatant
		if other == null or other.team == team or other.is_structure():
			continue
		if not other.can_be_targeted():
			continue
		var dist := global_position.distance_to(other.global_position)
		if dist <= best_dist:
			best_dist = dist
			best = other
	return best
