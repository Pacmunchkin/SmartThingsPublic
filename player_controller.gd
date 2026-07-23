# =============================================================================
# NODE SCRIPT — player_controller.gd (no scene file of its own).
#
# Attach to a plain Node named "Controller", added as a direct child of a
# player warlord instance in the level scene:
#
#   WarlordA (warlord.tscn instance)
#   └── Controller (Node)           <- this script
#
# Extends WarlordController. Feeds movement to the parent warlord, but
# only while that warlord is the one selected by WarlordCommander —
# unselected player warlords stand still.
#
# REQUIRED INPUT MAP (Project Settings > Input Map):
#   move_left / move_right / move_up / move_down
#     -> bind to the LEFT STICK axes only (Joypad Axis 0 -/+, Axis 1 -/+).
#     Do NOT bind the d-pad here: the d-pad belongs to abilities
#     (see warlord_commander.gd). Add WASD too if you want keyboard.
# =============================================================================

extends WarlordController
class_name PlayerController

func get_move_direction() -> Vector2:
	if _warlord == null or not _warlord.is_selected:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")
