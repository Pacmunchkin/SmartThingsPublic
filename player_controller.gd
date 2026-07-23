# =============================================================================
# NODE SCRIPT — player_controller.gd (no scene file of its own).
#
# Attach to a plain Node named "Controller", added as a direct child of a
# player warlord instance in the level scene:
#
#   WarlordA (warlord.tscn instance)
#   └── Controller (Node)           <- this script
#
# Extends WarlordController. Feeds gamepad/keyboard movement to the parent
# warlord, but only while that warlord is the one selected by
# WarlordCommander — unselected player warlords stand still.
# =============================================================================

extends WarlordController
class_name PlayerController

func get_move_direction() -> Vector2:
	if _warlord == null or not _warlord.is_selected:
		return Vector2.ZERO
	return Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
