# =============================================================================
# SCENE ARCHITECTURE — added inside main.tscn:
#
# Main (Node2D)                    <- warlord_commander.gd
# └── WarCouncil (CanvasLayer)     <- attach this script (war_council.gd).
#                                     NO children needed — builds its
#                                     gray-box controls in code.
#
# INSPECTOR SETUP: drag every UnitType .tres the player may pick into
# "Unit Types", and every Ability .tres into "Abilities".
#
# THE WAR COUNCIL is the pre-level loadout menu. It pauses the game at
# scene start and walks the player's warlords one at a time (A, B, X, Y):
#   Up/Down      - switch between the Unit Type and Ability rows
#   Left/Right   - cycle the focused row's options
#   A (ui_accept) - confirm this warlord and move to the next; after the
#                   last warlord the level unpauses and begins
#   B (ui_cancel) - go back to the previous warlord
# (Menu input uses Godot's built-in ui_* actions: d-pad, left stick,
# arrow keys, Enter, Escape all work with no Input Map setup.)
#
# On confirm, each warlord receives its chosen UnitType (applied to its
# whole retinue) and its chosen ability in the UP slot — see
# warlord.set_loadout. Picking "Levy (default)" / "(keep current)" leaves
# the Inspector-assigned value untouched. Left/Right ability slots keep
# their Inspector assignments — renown thresholds will unlock choosing
# those in a later iteration.
#
# Remove the WarCouncil node from the scene to skip the menu entirely.
# =============================================================================

extends CanvasLayer
class_name WarCouncil

# All choices offered to the player. Drag .tres assets here.
@export var unit_types: Array[UnitType] = []
@export var abilities: Array[Ability] = []

var _commander: WarlordCommander
var _warlords: Array[Warlord] = []
var _index: int = 0   # which warlord is being configured
var _row: int = 0     # 0 = unit type row, 1 = ability row
var _type_choice: Array[int] = []     # 0 = keep default, else unit_types[i-1]
var _ability_choice: Array[int] = []  # 0 = keep current, else abilities[i-1]

# Church ability-pick mode (see open_ability_pick): set while choosing a
# single ability for one newly unlocked slot, UNPAUSED.
var _single_warlord: Warlord = null
var _single_slot: int = -1
var _single_choice: int = 0

var _subtitle: Label
var _type_label: Label
var _ability_label: Label

func _ready() -> void:
	# Keep running while the rest of the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("war_council")
	_commander = get_parent() as WarlordCommander
	if _commander != null:
		for warlord in [_commander.warlord_a, _commander.warlord_b,
				_commander.warlord_x, _commander.warlord_y]:
			if warlord != null:
				_warlords.append(warlord)
	if _warlords.is_empty():
		queue_free()
		return
	for warlord in _warlords:
		_type_choice.append(0)
		_ability_choice.append(0)
	get_tree().paused = true
	_build_ui()
	_refresh()

# Called by a Church: pick one ability for one newly unlocked slot.
# The game keeps running — the stick still moves the warlord; only the
# d-pad / keyboard drive this menu.
func open_ability_pick(warlord: Warlord, slot: int) -> void:
	if visible or warlord == null:
		return
	_single_warlord = warlord
	_single_slot = slot
	_single_choice = 0
	visible = true
	_refresh()

func _close_ability_pick() -> void:
	_single_warlord = null
	_single_slot = -1
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# Unpaused church pick: ignore stick motion so walking doesn't cycle
	# the menu — d-pad and keyboard only.
	if _single_warlord != null and event is InputEventJoypadMotion:
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		if _single_warlord == null:
			_row = 1 - _row
			_refresh()
	elif event.is_action_pressed("ui_left"):
		_cycle(-1)
	elif event.is_action_pressed("ui_right"):
		_cycle(1)
	elif event.is_action_pressed("ui_accept"):
		_confirm()
	elif event.is_action_pressed("ui_cancel"):
		_back()
	else:
		return
	get_viewport().set_input_as_handled()

# --- Menu flow --------------------------------------------------------------

func _cycle(direction: int) -> void:
	if _single_warlord != null:
		_single_choice = posmod(_single_choice + direction, abilities.size() + 1)
	elif _row == 0:
		_type_choice[_index] = posmod(
				_type_choice[_index] + direction, unit_types.size() + 1)
	else:
		_ability_choice[_index] = posmod(
				_ability_choice[_index] + direction, abilities.size() + 1)
	_refresh()

func _confirm() -> void:
	if _single_warlord != null:
		if _single_choice > 0 and is_instance_valid(_single_warlord):
			_single_warlord.set_slot_ability(
					_single_slot, abilities[_single_choice - 1])
		_close_ability_pick()
		return
	if _index < _warlords.size() - 1:
		_index += 1
		_row = 0
		_refresh()
		return
	_apply_and_start()

func _back() -> void:
	if _single_warlord != null:
		_close_ability_pick()  # decline; the church offers again on return
		return
	if _index > 0:
		_index -= 1
		_row = 0
		_refresh()

func _apply_and_start() -> void:
	for i in _warlords.size():
		var chosen_type: UnitType = null
		if _type_choice[i] > 0:
			chosen_type = unit_types[_type_choice[i] - 1]
		var chosen_ability: Ability = null
		if _ability_choice[i] > 0:
			chosen_ability = abilities[_ability_choice[i] - 1]
		_warlords[i].set_loadout(chosen_type, chosen_ability)
	get_tree().paused = false
	visible = false

# --- Gray-box UI ------------------------------------------------------------

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "WAR COUNCIL"
	box.add_child(title)

	_subtitle = Label.new()
	box.add_child(_subtitle)

	_type_label = Label.new()
	box.add_child(_type_label)

	_ability_label = Label.new()
	box.add_child(_ability_label)

	var footer := Label.new()
	footer.text = "Up/Down row   Left/Right change   (A) confirm   (B) back"
	footer.modulate = Color(1, 1, 1, 0.6)
	box.add_child(footer)

func _refresh() -> void:
	if _single_warlord != null:
		if not is_instance_valid(_single_warlord):
			_close_ability_pick()
			return
		_subtitle.text = "%s — choose a new ability  |  RENOWN %d" % [
				_single_warlord.name, _single_warlord.renown]
		_type_label.visible = false
		var pick_name := "(decide later)"
		if _single_choice > 0:
			pick_name = abilities[_single_choice - 1].display_name
		_ability_label.text = "> New Ability:  < %s >" % pick_name
		return
	_type_label.visible = true
	var warlord := _warlords[_index]
	_subtitle.text = "%s  (%d of %d)  |  RENOWN %d" % [
			warlord.name, _index + 1, _warlords.size(), warlord.renown]
	var type_name := "Levy (default)"
	if _type_choice[_index] > 0:
		type_name = unit_types[_type_choice[_index] - 1].display_name
	var ability_name := "(keep current)"
	if _ability_choice[_index] > 0:
		ability_name = abilities[_ability_choice[_index] - 1].display_name
	_type_label.text = "%s Unit Type:     < %s >" % [_marker(0), type_name]
	_ability_label.text = "%s First Ability: < %s >" % [_marker(1), ability_name]

func _marker(row: int) -> String:
	return ">" if _row == row else "  "
