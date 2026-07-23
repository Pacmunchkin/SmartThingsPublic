# =============================================================================
# NODE SCRIPT — selection_marker.gd (no scene file of its own).
#
# Add a Node2D named "SelectionMarker" as a child of warlord.tscn,
# positioned above the body (e.g. 0, -24), and attach this script.
#
# Draws a small white triangle over the warlord while it is the one
# selected by WarlordCommander; invisible otherwise. AI warlords are never
# selected, so the same scene stays clean for them.
# =============================================================================

extends Node2D
class_name SelectionMarker

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var warlord := get_parent() as Warlord
	if warlord == null or not warlord.is_selected:
		return
	var points := PackedVector2Array([
		Vector2(-6.0, -8.0),
		Vector2(6.0, -8.0),
		Vector2(0.0, 0.0),
	])
	draw_colored_polygon(points, Color(1.0, 1.0, 1.0, 0.9))
