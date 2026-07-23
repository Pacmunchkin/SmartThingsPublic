# =============================================================================
# SCENE ARCHITECTURE — city.tscn
#
# City (Node2D)                    <- attach this script (city.gd) here
# ├── Gate (city_gate.tscn)        <- the attackable way in; blocks passage
# │                                   until destroyed. Position it in the
# │                                   wall opening.
# ├── Battlements (Node2D)         <- plain Node2D container
# │   ├── Battlement (battlement.tscn)   <- place along the walls; shoot
# │   ├── Battlement (battlement.tscn)      arrows at enemies in range
# │   └── ...
# └── Walls (StaticBody2D)         <- indestructible wall segments: one
#     ├── CollisionShape2D            CollisionShape2D + ColorRect pair per
#     ├── ColorRect                   segment, arranged so the Gate is the
#     └── ...                         only way through
#
# The city to assault: walls seal it, battlements rain arrows, and the
# gate is the one attackable entry. Attackers are never locked onto the
# gate — pull the warlord back and the retinue breaks off (see recruit.gd).
# When the gate's health reaches 0 it is removed and the city is open.
#
# This script just assigns the city's team to its gate and battlements.
# Set "Team" in the Inspector (defaults to 1, the enemy).
#
# Planned (not yet implemented): what lies inside the city, capturing it,
# attackable battlements.
# =============================================================================

extends Node2D
class_name City

@export var team: int = 1

func _ready() -> void:
	var gate := get_node_or_null("Gate") as CityGate
	if gate != null:
		gate.team = team
	var battlements := get_node_or_null("Battlements")
	if battlements != null:
		for child in battlements.get_children():
			if child is Battlement:
				child.team = team
