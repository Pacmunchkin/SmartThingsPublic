# =============================================================================
# SCENE ARCHITECTURE — main.tscn
#
# Main (Node2D)                    <- attach this script (warlord_commander.gd)
# ├── Camera2D                     <- single game camera, driven by this script
# ├── WarlordA (warlord.tscn)      <- drag into "Warlord A" in the Inspector
# ├── WarlordB (warlord.tscn)      <- drag into "Warlord B"
# ├── WarlordX (warlord.tscn)      <- drag into "Warlord X"
# └── WarlordY (warlord.tscn)      <- drag into "Warlord Y"
#
# REQUIRED INPUT MAP (Project Settings > Input Map):
#   select_a -> Joypad Button 0 (Bottom Action: Xbox A / Sony Cross)
#   select_b -> Joypad Button 1 (Right Action:  Xbox B / Sony Circle)
#   select_x -> Joypad Button 2 (Left Action:   Xbox X / Sony Square)
#   select_y -> Joypad Button 3 (Top Action:    Xbox Y / Sony Triangle)
# Movement uses the built-in ui_* actions, which already include the left
# stick and d-pad by default — no extra Input Map setup needed for movement.
# =============================================================================

extends Node2D
class_name WarlordCommander

@export var warlord_a: Warlord
@export var warlord_b: Warlord
@export var warlord_x: Warlord
@export var warlord_y: Warlord

@onready var _camera: Camera2D = $Camera2D

var _selected: Warlord = null

func _ready() -> void:
	# Warlord A starts selected.
	_select(warlord_a)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("select_a"):
		_select(warlord_a)
	elif event.is_action_pressed("select_b"):
		_select(warlord_b)
	elif event.is_action_pressed("select_x"):
		_select(warlord_x)
	elif event.is_action_pressed("select_y"):
		_select(warlord_y)

func _process(_delta: float) -> void:
	# Camera stays snapped to the selected warlord (no smoothing, no tween).
	if _selected != null:
		_camera.global_position = _selected.global_position

func _select(warlord: Warlord) -> void:
	if warlord == null or warlord == _selected:
		return
	if _selected != null:
		_selected.is_selected = false
	_selected = warlord
	_selected.is_selected = true
	_camera.global_position = _selected.global_position
