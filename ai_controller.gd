# =============================================================================
# NODE SCRIPT — ai_controller.gd (no scene file of its own).
#
# Attach to a plain Node named "AIController", added as a direct child of an
# enemy warlord instance in the level scene:
#
#   EnemyWarlord (warlord.tscn instance, Team = 1)
#   └── AIController (Node)         <- this script
#
# Extends WarlordController. Behaves like a garrison does (see recruit.gd):
#   - Holds the position it started at (its "post").
#   - If a targetable enemy combatant comes within aggro_range, walks to it
#     and lets the warlord's built-in auto-attack do the fighting.
#   - When no enemies are in range, walks back to the post.
# The warlord's retinue follows it and pairs off with enemies on its own.
#
# PATHFINDING: if the warlord scene has a NavigationAgent2D child (see
# warlord.gd), this AI steers along the navmesh path to reach its target,
# routing around walls/burhs/city. With no agent it goes straight (the
# player warlord never uses the agent — it is stick-controlled).
# =============================================================================

extends WarlordController
class_name AIController

# Enemy searches run at most 4x/s; the chase itself updates every frame
# because the cached target's live position is followed between scans.
const TARGET_SCAN_INTERVAL: float = 0.25

# Pathfinding only kicks in beyond this distance (matches recruit.gd).
const PATH_NEAR_DISTANCE: float = 64.0

@export var aggro_range: float = 160.0  # enemies inside this get chased

var _post_position: Vector2
var _scan_timer: float = 0.0
var _cached_enemy: Combatant = null
var _nav_agent: NavigationAgent2D = null

func _ready() -> void:
	super._ready()
	_scan_timer = randf() * TARGET_SCAN_INTERVAL  # stagger scans across units
	if _warlord != null:
		_post_position = _warlord.global_position
		_nav_agent = _warlord.get_node_or_null("NavigationAgent2D")

func _physics_process(delta: float) -> void:
	_scan_timer = maxf(_scan_timer - delta, 0.0)

func get_move_direction() -> Vector2:
	if _warlord == null:
		return Vector2.ZERO
	if _cached_enemy != null and not is_instance_valid(_cached_enemy):
		_cached_enemy = null
	if _scan_timer <= 0.0:
		_scan_timer = TARGET_SCAN_INTERVAL
		_cached_enemy = _nearest_enemy()
	var enemy := _cached_enemy
	if enemy != null:
		if _warlord.global_position.distance_to(enemy.global_position) \
				<= _warlord.attack_range:
			return Vector2.ZERO
		return _direction_to(enemy.global_position)
	if _warlord.global_position.distance_to(_post_position) <= 4.0:
		return Vector2.ZERO
	return _direction_to(_post_position)

# Straight line up close / with no agent; navmesh path when far.
func _direction_to(point: Vector2) -> Vector2:
	var from: Vector2 = _warlord.global_position
	if from.distance_to(point) <= PATH_NEAR_DISTANCE or _nav_agent == null:
		return from.direction_to(point)
	if _nav_agent.target_position.distance_to(point) > 16.0:
		_nav_agent.target_position = point
	var next := _nav_agent.get_next_path_position()
	if from.distance_to(next) < 1.0:
		return from.direction_to(point)  # navmesh not ready — go straight
	return from.direction_to(next)

func _nearest_enemy() -> Combatant:
	var best: Combatant = null
	var best_dist: float = aggro_range
	for node in get_tree().get_nodes_in_group("combatants"):
		var other := node as Combatant
		if other == null or other == _warlord or other.team == _warlord.team:
			continue
		if not other.can_be_targeted():
			continue
		var dist := _warlord.global_position.distance_to(other.global_position)
		if dist <= best_dist:
			best_dist = dist
			best = other
	return best
