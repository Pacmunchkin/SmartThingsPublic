# =============================================================================
# SCENE ARCHITECTURE — added inside main.tscn:
#
# Main (Node2D)                    <- warlord_commander.gd
# └── LevelManager (CanvasLayer)   <- attach this script (level_manager.gd).
#                                     NO children needed — builds its
#                                     victory panel in code.
#
# WIN CONDITION: the level is won when no living warlord remains whose team
# differs from player_team. Populate the level with as many enemy warlords
# as you like (warlord.tscn instances, Team = 1, with an AIController) —
# defeating every one of them wins. On victory the game pauses and a
# gray-box VICTORY panel appears.
#
# NO DEFEAT STATE (by design): dead player warlords are replaced endlessly
# by longship (see warlord_commander.gd). A level meant to be losable would
# leave "Warlord Scene" empty on the commander (true permadeath) — a defeat
# check can be added here later for those levels.
#
# Set Player Team to match your player warlords' Team (default 0).
# =============================================================================

extends CanvasLayer
class_name LevelManager

@export var player_team: int = 0

var _won: bool = false
var _panel: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep working while paused
	add_to_group("level_manager")
	# Wait one frame so every warlord has registered in the group.
	_connect_warlords.call_deferred()

func _connect_warlords() -> void:
	for node in get_tree().get_nodes_in_group("warlords"):
		var warlord := node as Warlord
		if warlord != null and not warlord.died.is_connected(_on_warlord_died):
			warlord.died.connect(_on_warlord_died)
	_check_victory()

# Player longship replacements arrive mid-level; hook their deaths too so a
# late-spawned warlord dying still re-checks (harmless for the win test).
func register_warlord(warlord: Warlord) -> void:
	if warlord != null and not warlord.died.is_connected(_on_warlord_died):
		warlord.died.connect(_on_warlord_died)

func _on_warlord_died(_combatant: Combatant) -> void:
	_check_victory()

func _check_victory() -> void:
	if _won:
		return
	for node in get_tree().get_nodes_in_group("warlords"):
		var warlord := node as Warlord
		if warlord == null or warlord.is_queued_for_deletion():
			continue
		if warlord.team != player_team:
			return  # an enemy warlord still stands — not won yet
	_declare_victory()

func _declare_victory() -> void:
	_won = true
	_show_panel("VICTORY", "The last enemy warlord has fallen.")
	get_tree().paused = true

# --- Gray-box panel ---------------------------------------------------------

func _show_panel(title_text: String, subtitle_text: String) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = center

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = subtitle_text
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(1, 1, 1, 0.7)
	box.add_child(subtitle)
