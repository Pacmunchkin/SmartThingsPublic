# =============================================================================
# SCENE ARCHITECTURE — main.tscn
#
# Main (Node2D)                    <- attach this script (warlord_commander.gd)
# ├── Camera2D                     <- single game camera, driven by this script
# ├── WarlordA (warlord.tscn)      <- drag into "Warlord A" in the Inspector
# │   └── Controller (Node)        <- player_controller.gd
# ├── WarlordB (warlord.tscn)      <- drag into "Warlord B"
# │   └── Controller (Node)        <- player_controller.gd
# ├── WarlordX (warlord.tscn)      <- drag into "Warlord X"
# │   └── Controller (Node)        <- player_controller.gd
# ├── WarlordY (warlord.tscn)      <- drag into "Warlord Y"
# │   └── Controller (Node)        <- player_controller.gd
# ├── EnemyWarlord (warlord.tscn)  <- Team = 1; NOT in a commander slot
# │   └── AIController (Node)      <- ai_controller.gd
# └── Village (village.tscn)       <- any number of village instances
#
# Only player warlords go in the four commander slots below. Enemy warlords
# are plain warlord.tscn instances with an AIController child and their
# Team set in the Inspector.
#
# REQUIRED INPUT MAP (Project Settings > Input Map):
#   select_a -> Joypad Button 0 (Bottom Action: Xbox A / Sony Cross)
#   select_b -> Joypad Button 1 (Right Action:  Xbox B / Sony Circle)
#   select_x -> Joypad Button 2 (Left Action:   Xbox X / Sony Square)
#   select_y -> Joypad Button 3 (Top Action:    Xbox Y / Sony Triangle)
# Movement uses the built-in ui_* actions, which already include the left
# stick and d-pad by default — no extra Input Map setup needed for movement.
#
# PERMADEATH: when a warlord dies its slot is cleared and its select button
# goes dead for the rest of the run. If the selected warlord dies, selection
# jumps to the first surviving warlord (A, B, X, Y order). If none survive,
# nothing is selected and the camera stays where it is (game over screen is
# a future iteration).
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
	for warlord in [warlord_a, warlord_b, warlord_x, warlord_y]:
		if warlord != null:
			warlord.died.connect(_on_warlord_died)
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

func _on_warlord_died(combatant: Combatant) -> void:
	# Permadeath: clear the slot so its select button does nothing.
	if combatant == warlord_a:
		warlord_a = null
	if combatant == warlord_b:
		warlord_b = null
	if combatant == warlord_x:
		warlord_x = null
	if combatant == warlord_y:
		warlord_y = null
	if _selected == combatant:
		_selected = null
		for survivor in [warlord_a, warlord_b, warlord_x, warlord_y]:
			if survivor != null:
				_select(survivor)
				return
