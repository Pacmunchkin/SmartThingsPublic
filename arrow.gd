# =============================================================================
# SCRIPT-ONLY PROJECTILE — arrow.gd has no scene file.
#
# Created in code by Battlement (battlement.gd): Arrow.new() with target,
# damage, and speed set, then added as a child of the battlement. Draws its
# own small gray dart, homes in on its target node every physics frame, and
# deals damage on arrival. Despawns if the target dies mid-flight.
# =============================================================================

extends Node2D
class_name Arrow

var target: Combatant = null
var damage: float = 0.0
var speed: float = 400.0
var shooter: Combatant = null  # for renown kill credit; battlements leave null

func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		queue_free()
		return
	var to_target: Vector2 = target.global_position - global_position
	rotation = to_target.angle()
	var step: float = speed * delta
	if to_target.length() <= step:
		var valid_shooter := shooter if shooter != null \
				and is_instance_valid(shooter) else null
		target.take_ranged_damage(damage, valid_shooter)
		queue_free()
		return
	global_position += to_target.normalized() * step

func _draw() -> void:
	draw_rect(Rect2(-6.0, -1.5, 12.0, 3.0), Color(0.85, 0.85, 0.85))
