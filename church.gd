# =============================================================================
# SCENE ARCHITECTURE — church.tscn
#
# Church (Node2D)                  <- attach this script (church.gd) here
# └── ColorRect                    <- gray box chapel visual, e.g. 32x32,
#                                     offset -16,-16 so it is centered
#
# A sanctuary and (eventually) checkpoint. While a same-team warlord is
# within sanctuary_range:
#   - HEAL: the warlord and their retinue recover heal_per_second HP.
#   - LEVEL UP: if the warlord has an ability slot unlocked by renown but
#     not yet filled (see warlord.gd ABILITY_SLOT_LEVEL), the ability
#     pick menu opens when they arrive. The game does NOT pause: the left
#     stick still moves the warlord; d-pad Left/Right cycles the choice,
#     (A) confirms, (B) declines. A declined offer comes back the next
#     time the warlord leaves and re-enters the sanctuary.
#
# Requires a WarCouncil node in main.tscn (it hosts the pick menu).
# Instance church.tscn into main.tscn; set Team per church (default 0,
# the player — enemy-team churches would heal enemy warlords).
#
# Planned (not yet implemented): checkpoint saving, restocking.
# =============================================================================

extends Node2D
class_name Church

@export var team: int = 0
@export var sanctuary_range: float = 200.0
@export var heal_per_second: float = 2.0

var _was_in_range: Dictionary = {}  # Warlord -> bool, to detect arrival

func _physics_process(delta: float) -> void:
	var council := get_tree().get_first_node_in_group("war_council") as WarCouncil
	for node in get_tree().get_nodes_in_group("warlords"):
		var warlord := node as Warlord
		if warlord == null or warlord.team != team:
			continue
		var in_range := global_position.distance_to(warlord.global_position) \
				<= sanctuary_range
		if in_range:
			warlord.heal_army(heal_per_second * delta)
			var just_arrived: bool = not _was_in_range.get(warlord, false)
			if just_arrived and council != null and not council.visible:
				var slot := warlord.next_empty_unlocked_slot()
				if slot >= 0:
					council.open_ability_pick(warlord, slot)
		_was_in_range[warlord] = in_range
