# =============================================================================
# NODE SCRIPT — health_bar.gd (no scene file of its own).
#
# A reusable gray-box health bar. Add a Node2D named "HealthBar" as a
# child of any scene whose root has `health` and `max_health` (Warlord,
# Recruit, CityGate), attach this script, and position it under the body:
#
#   warlord.tscn   -> HealthBar at (0, 18), default size
#   recruit.tscn   -> HealthBar at (0, 12), Bar Width 16, Hide When Full ON
#   city_gate.tscn -> HealthBar at (0, 20), Bar Width 96
#
# Draws a dark background with a fill that drains right-to-left and shifts
# from green to red as health drops. With hide_when_full on, the bar only
# appears once the owner has taken damage (keeps crowds readable).
# =============================================================================

extends Node2D
class_name HealthBar

@export var bar_width: float = 28.0
@export var bar_height: float = 4.0
@export var hide_when_full: bool = false

var _owner_node: Node2D

func _ready() -> void:
	_owner_node = get_parent() as Node2D

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if _owner_node == null:
		return
	var health = _owner_node.get("health")
	var max_health = _owner_node.get("max_health")
	if health == null or max_health == null or float(max_health) <= 0.0:
		return
	var ratio := clampf(float(health) / float(max_health), 0.0, 1.0)
	if hide_when_full and ratio >= 1.0:
		return
	var half := bar_width / 2.0
	draw_rect(Rect2(-half, 0.0, bar_width, bar_height),
			Color(0.12, 0.12, 0.12, 0.85))
	var fill := Color(0.85, 0.25, 0.2).lerp(Color(0.3, 0.8, 0.3), ratio)
	draw_rect(Rect2(-half, 0.0, bar_width * ratio, bar_height), fill)
