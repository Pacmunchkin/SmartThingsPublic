# =============================================================================
# SCRIPT-ONLY BASE CLASS — warlord_controller.gd has no scene file.
#
# WarlordController (extends Node) is the base for anything that drives a
# Warlord's movement:
#   - PlayerController (player_controller.gd) extends WarlordController
#   - AIController     (ai_controller.gd)     extends WarlordController
#
# USAGE: add exactly one controller node as a direct child of a warlord
# instance in the level scene (see warlord.gd header). The warlord finds it
# by wildcard name "*Controller" and calls get_move_direction() every
# physics frame. The node's NAME must therefore end in "Controller"
# (e.g. "Controller", "AIController").
# =============================================================================

extends Node
class_name WarlordController

var _warlord: Warlord

func _ready() -> void:
	_warlord = get_parent() as Warlord

# Direction the warlord should move this physics frame (length 0..1).
# Override in subclasses.
func get_move_direction() -> Vector2:
	return Vector2.ZERO
