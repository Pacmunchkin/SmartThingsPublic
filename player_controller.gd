# =============================================================================
# NODE SCRIPT — player_controller.gd (no scene file of its own).
#
# Attach to a plain Node child of a player warlord instance:
#
#   WarlordA (warlord.tscn instance)
#   └── Controller (Node)           <- this script
#
# Extends WarlordController. Two jobs:
#   1. SELECT — when this controller's `selection_action` is pressed, ask the
#      WarlordCommander to select (and thus control) this warlord. The button
#      binding lives HERE, per warlord — no central slot list to maintain.
#   2. MOVE — while this warlord is the selected one, feed it the left stick.
#
# REQUIRED INPUT MAP:
#   selection_action (per warlord: select_a / select_b / select_x / select_y)
#   move_left / move_right / move_up / move_down  -> LEFT STICK
#   ability, ability_up / ability_left / ability_right, retreat (commander)
# =============================================================================

extends WarlordController
class_name PlayerController

## The input action that selects (and controls) THIS warlord — set it UNIQUE
## per warlord in the Inspector: "select_a" / "select_b" / "select_x" /
## "select_y". Longship replacements inherit the fallen warlord's action.
@export var selection_action: String = "select_a"

func _process(_delta: float) -> void:
	if _warlord == null or not is_instance_valid(_warlord):
		return
	if Input.is_action_just_pressed(selection_action):
		var commander := get_tree().get_first_node_in_group("warlord_commander") \
				as WarlordCommander
		if commander != null:
			commander.select_warlord(_warlord)

func get_move_direction() -> Vector2:
	if _warlord == null or not _warlord.is_selected:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")
