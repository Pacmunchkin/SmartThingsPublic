# =============================================================================
# SCENE ARCHITECTURE — added inside main.tscn:
#
# Main (Node2D)                    <- warlord_commander.gd
# └── Hud (CanvasLayer)            <- attach this script (hud.gd) here.
#                                     NO children needed — the HUD builds
#                                     its gray-box labels in code.
#
# Screen-space UI for the SELECTED warlord (read from the parent
# WarlordCommander every frame), bottom-left corner:
#
#   WarlordA  |  HP 65/65  |  ARMY 12/50
#   D-PAD UP     D-PAD LEFT    D-PAD RIGHT
#   Charge       Knock Back    Call
#   READY        32s           ACTIVE 4s
#
# Ability slots show the .tres display_name and one of three states:
#   READY      — off cooldown, will fire on hold-X + d-pad direction
#   <N>s       — cooldown remaining, counts down
#   ACTIVE <N>s — a sustained effect is currently running
#
# Swap the code-built labels for a designed scene when the art pass comes.
# =============================================================================

extends CanvasLayer
class_name Hud

const SLOT_TITLES: Array[String] = ["D-PAD UP", "D-PAD LEFT", "D-PAD RIGHT"]

var _commander: WarlordCommander
var _info_label: Label
var _slot_names: Array[Label] = []
var _slot_status: Array[Label] = []

func _ready() -> void:
	_commander = get_parent() as WarlordCommander
	var panel := VBoxContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 16.0
	panel.offset_bottom = -16.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(panel)

	_info_label = Label.new()
	panel.add_child(_info_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	panel.add_child(row)

	for i in 3:
		var slot := VBoxContainer.new()
		row.add_child(slot)
		var title := Label.new()
		title.text = SLOT_TITLES[i]
		title.modulate = Color(1, 1, 1, 0.6)
		slot.add_child(title)
		var ability_name := Label.new()
		slot.add_child(ability_name)
		_slot_names.append(ability_name)
		var status := Label.new()
		slot.add_child(status)
		_slot_status.append(status)

func _process(_delta: float) -> void:
	var warlord: Warlord = null
	if _commander != null:
		warlord = _commander.get_selected_warlord()
	if warlord == null:
		_info_label.text = "NO WARLORD"
		for i in 3:
			_slot_names[i].text = "-"
			_slot_status[i].text = ""
		return
	_info_label.text = "%s  |  RENOWN %d/%d  |  HP %d/%d  |  ARMY %d/%d" % [
			warlord.warlord_name, warlord.renown, Warlord.RENOWN_MAX,
			roundi(warlord.health), roundi(warlord.max_health),
			warlord.army_size, warlord.max_retinue]
	for i in 3:
		if not warlord.is_slot_unlocked(i):
			_slot_names[i].text = "LOCKED"
			_slot_status[i].text = "RENOWN %d" % Warlord.ABILITY_SLOT_RENOWN[i]
			_slot_status[i].modulate = Color(1, 1, 1, 0.4)
			continue
		var ability := warlord.get_ability(i)
		if ability == null:
			_slot_names[i].text = "(empty)"
			_slot_status[i].text = "VISIT A CHURCH"
			_slot_status[i].modulate = Color(0.6, 0.8, 1.0)
			continue
		_slot_names[i].text = ability.display_name
		var active := warlord.get_ability_active_time(ability)
		var cooldown := warlord.get_ability_cooldown(i)
		if active > 0.0:
			_slot_status[i].text = "ACTIVE %ds" % ceili(active)
			_slot_status[i].modulate = Color(0.4, 1.0, 0.4)
		elif cooldown > 0.0:
			_slot_status[i].text = "%ds" % ceili(cooldown)
			_slot_status[i].modulate = Color(1.0, 0.6, 0.3)
		else:
			_slot_status[i].text = "READY"
			_slot_status[i].modulate = Color(1, 1, 1)
