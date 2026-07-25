# =============================================================================
# SCENE ARCHITECTURE — main.tscn
#
# Main (Node2D)                    <- attach this script (warlord_commander.gd)
# ├── Camera2D                     <- single game camera, driven by this script
# ├── WarlordA (warlord.tscn)      <- Team 0; give its Controller a
# │   └── Controller (Node)           selection_action of "select_a"
# ├── WarlordB (warlord.tscn)      <- Controller.selection_action = "select_b"
# │   └── Controller (Node)
# ├── WarlordX (warlord.tscn)      <- Controller.selection_action = "select_x"
# │   └── Controller (Node)
# ├── WarlordY (warlord.tscn)      <- Controller.selection_action = "select_y"
# │   └── Controller (Node)
# ├── EnemyWarlord (warlord.tscn)  <- Team = 1; AIController child (not a player)
# │   └── AIController (Node)
# ├── Village / Burh / City / Church instances
# ├── Hud (CanvasLayer)            <- hud.gd
# ├── WarCouncil (CanvasLayer)     <- war_council.gd
# └── LevelManager (CanvasLayer)   <- level_manager.gd
#
# SELECTION is now decentralized: each player warlord's Controller declares
# its own button via an exported `selection_action` (see player_controller
# .gd). This commander no longer holds four fixed slots — it discovers player
# warlords from the "warlords" group (those with a PlayerController) and just
# owns the shared concerns: the camera, ability + retreat routing to the
# selected warlord, permadeath reselection, and longship replacements.
#
# REQUIRED INPUT MAP (Project Settings > Input Map):
#   select_a / select_b / select_x / select_y -> the four face buttons
#     (each warlord's Controller.selection_action points at one of these)
#   move_left / move_right / move_up / move_down -> LEFT STICK
#   ability       -> a dedicated modifier button (e.g. Right Shoulder / RB)
#   ability_up / ability_left / ability_right    -> D-pad Up / Left / Right
#   retreat       -> a button held 3s to flee (e.g. Left Shoulder / LB)
#
# ABILITIES: hold `ability` and press d-pad Up/Left/Right to fire the selected
# warlord's matching slot. (Abilities use their OWN button now, so the face
# buttons are pure selection — no more X double-duty.)
#
# PERMADEATH + LONGSHIP: a dead warlord is gone; replacement_delay seconds
# later a fresh warlord (renown 0, drawn name) lands at the Longship Dock,
# inherits the fallen warlord's selection_action, and gets an arrival loadout.
# Leave "Warlord Scene" empty to disable replacements (true permadeath).
# =============================================================================

extends Node2D
class_name WarlordCommander

# --- Longship replacements ---------------------------------------------------
# Drag warlord.tscn here; empty = no replacements (true permadeath).
@export var warlord_scene: PackedScene
# Marker2D at the shoreline where replacements land.
@export var longship_dock: Node2D
# Seconds between a death and the replacement's arrival — the time cost.
@export var replacement_delay: float = 60.0

@onready var _camera: Camera2D = $Camera2D

# Hold the "retreat" action this long to trigger a retreat.
const RETREAT_HOLD_TIME: float = 3.0

var _selected: Warlord = null
var _pending_longships: Dictionary = {}  # selection_action -> seconds
var _death_action: Dictionary = {}       # warlord -> its selection_action
var _retreat_hold: float = 0.0
var _retreat_fired: bool = false

func _ready() -> void:
	add_to_group("warlord_commander")

# Called by a PlayerController when its selection_action is pressed.
func select_warlord(warlord: Warlord) -> void:
	if warlord == null or not is_instance_valid(warlord) or warlord == _selected:
		return
	if _selected != null and is_instance_valid(_selected):
		_selected.is_selected = false
	_selected = warlord
	_selected.is_selected = true
	_camera.global_position = _selected.global_position

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ability_up"):
		_try_ability(0)
	elif event.is_action_pressed("ability_left"):
		_try_ability(1)
	elif event.is_action_pressed("ability_right"):
		_try_ability(2)

# Fire an ability slot on the selected warlord — only while `ability` is held.
func _try_ability(slot: int) -> void:
	if not Input.is_action_pressed("ability"):
		return
	if _selected != null and is_instance_valid(_selected):
		_selected.activate_ability(slot)

func _process(delta: float) -> void:
	_track_players()
	_tick_longships(delta)
	_tick_retreat(delta)
	# Auto-select if nothing is selected (game start, or after a death).
	if _selected == null or not is_instance_valid(_selected):
		_selected = null
		_select_first_player()
	if _selected != null and is_instance_valid(_selected):
		_camera.global_position = _selected.global_position

# --- Player discovery --------------------------------------------------------

# Player warlords = warlords in the group carrying a PlayerController.
func _player_warlords() -> Array:
	var result: Array = []
	for node in get_tree().get_nodes_in_group("warlords"):
		var w := node as Warlord
		if w == null or w.is_queued_for_deletion():
			continue
		if w.find_child("*Controller", false, false) is PlayerController:
			result.append(w)
	return result

# Discover each player warlord once: remember its selection_action (for
# respawn) and hook its death.
func _track_players() -> void:
	for warlord in _player_warlords():
		if _death_action.has(warlord):
			continue
		var pc := warlord.find_child("*Controller", false, false) as PlayerController
		_death_action[warlord] = pc.selection_action if pc != null else "select_a"
		if not warlord.died.is_connected(_on_warlord_died):
			warlord.died.connect(_on_warlord_died)

func _select_first_player() -> void:
	var players := _player_warlords()
	if not players.is_empty():
		select_warlord(players[0])

func _tick_retreat(delta: float) -> void:
	if _selected != null and is_instance_valid(_selected) \
			and Input.is_action_pressed("retreat"):
		_retreat_hold += delta
		if _retreat_hold >= RETREAT_HOLD_TIME and not _retreat_fired:
			_retreat_fired = true
			_selected.begin_retreat()
	else:
		_retreat_hold = 0.0
		_retreat_fired = false

# --- Queries (used by hud.gd / war_council.gd) -------------------------------

func get_selected_warlord() -> Warlord:
	if _selected != null and is_instance_valid(_selected):
		return _selected
	return null

func get_players() -> Array:
	return _player_warlords()

func get_next_longship_time() -> float:
	var soonest: float = 0.0
	for time_left in _pending_longships.values():
		if soonest == 0.0 or time_left < soonest:
			soonest = time_left
	return soonest

# --- Longship replacements ---------------------------------------------------

func _tick_longships(delta: float) -> void:
	if warlord_scene == null or _pending_longships.is_empty():
		return
	for action in _pending_longships.keys():
		_pending_longships[action] -= delta
		if _pending_longships[action] <= 0.0:
			_spawn_replacement(action)

func _spawn_replacement(action: String) -> void:
	_pending_longships.erase(action)
	var warlord := warlord_scene.instantiate() as Warlord
	if warlord == null:
		return
	# A fresh face: renown 0, random name, no unit type until the arrival
	# loadout is set. Its controller inherits the fallen warlord's button.
	var controller := PlayerController.new()
	controller.name = "Controller"
	controller.selection_action = action
	warlord.add_child(controller)
	warlord.renown = 0.0
	add_child(warlord)
	if longship_dock != null:
		warlord.global_position = longship_dock.global_position
	# _track_players will hook its death and record its action next frame;
	# _process will auto-select it if nothing is selected.
	var level := get_tree().get_first_node_in_group("level_manager") as LevelManager
	if level != null:
		level.register_warlord(warlord)
	var council := get_tree().get_first_node_in_group("war_council") as WarCouncil
	if council != null:
		council.open_warlord_setup(warlord)

func _on_warlord_died(combatant: Combatant) -> void:
	# Permadeath: queue the fallen warlord's button for the next longship.
	var action: String = _death_action.get(combatant, "")
	_death_action.erase(combatant)
	if action != "":
		_pending_longships[action] = replacement_delay
	if _selected == combatant:
		_selected = null  # _process reselects a survivor
