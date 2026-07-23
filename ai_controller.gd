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
# =============================================================================

extends WarlordController
class_name AIController

@export var aggro_range: float = 160.0  # enemies inside this get chased

var _post_position: Vector2

func _ready() -> void:
	super._ready()
	if _warlord != null:
		_post_position = _warlord.global_position

func get_move_direction() -> Vector2:
	if _warlord == null:
		return Vector2.ZERO
	var enemy := _nearest_enemy()
	if enemy != null:
		if _warlord.global_position.distance_to(enemy.global_position) \
				<= _warlord.attack_range:
			return Vector2.ZERO
		return _warlord.global_position.direction_to(enemy.global_position)
	if _warlord.global_position.distance_to(_post_position) <= 4.0:
		return Vector2.ZERO
	return _warlord.global_position.direction_to(_post_position)

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
