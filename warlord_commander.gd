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
# ├── Village (village.tscn)       <- any number of village instances
# ├── Burh (burh.tscn)             <- fortifications at choke points
# ├── City (city.tscn)             <- walled city with gate + battlements
# └── Hud (CanvasLayer)            <- hud.gd: selected warlord's health,
#                                     army size, ability cooldowns
#
# Only player warlords go in the four commander slots below. Enemy warlords
# are plain warlord.tscn instances with an AIController child and their
# Team set in the Inspector.
#
# REQUIRED INPUT MAP (Project Settings > Input Map):
#   select_a      -> Joypad Button 0 (Bottom Action: Xbox A / Sony Cross)
#   select_b      -> Joypad Button 1 (Right Action:  Xbox B / Sony Circle)
#   select_x      -> Joypad Button 2 (Left Action:   Xbox X / Sony Square)
#   select_y      -> Joypad Button 3 (Top Action:    Xbox Y / Sony Triangle)
#   ability_up    -> Joypad D-pad Up
#   ability_left  -> Joypad D-pad Left
#   ability_right -> Joypad D-pad Right
#   move_left / move_right / move_up / move_down
#                 -> LEFT STICK axes only (see player_controller.gd);
#                    keep the d-pad out of these — it belongs to abilities.
#
# ABILITIES: hold X and press d-pad Up / Left / Right to fire the selected
# warlord's matching ability slot (see warlord.gd / ability.gd). Because X
# doubles as a modifier, warlord X is selected on RELEASE of the X button:
# a plain tap still selects, but a hold used for an ability does not.
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
var _x_hold_used: bool = false  # X was used as an ability modifier

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
	elif event.is_action_pressed("select_y"):
		_select(warlord_y)
	elif event.is_action_released("select_x"):
		# X selects on release so that hold-X + d-pad can fire abilities.
		if not _x_hold_used:
			_select(warlord_x)
		_x_hold_used = false
	elif event.is_action_pressed("ability_up"):
		_try_ability(0)
	elif event.is_action_pressed("ability_left"):
		_try_ability(1)
	elif event.is_action_pressed("ability_right"):
		_try_ability(2)

# Fire an ability slot on the selected warlord — only while X is held.
func _try_ability(slot: int) -> void:
	if not Input.is_action_pressed("select_x"):
		return
	_x_hold_used = true
	if _selected != null:
		_selected.activate_ability(slot)

func _process(_delta: float) -> void:
	# Camera stays snapped to the selected warlord (no smoothing, no tween).
	if _selected != null:
		_camera.global_position = _selected.global_position

# Used by hud.gd; null when no warlord survives.
func get_selected_warlord() -> Warlord:
	return _selected

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
