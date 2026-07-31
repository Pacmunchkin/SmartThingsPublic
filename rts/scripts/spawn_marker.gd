@tool
class_name SpawnMarker
extends Marker2D

## Where something enters the level.
##
## Markers carry a squad_id string rather than a direct resource reference, so
## the scene does not need to know the faction rosters. The mission resource
## owns the squad library and resolves ids at spawn time - that keeps the
## level file editable without dragging every archetype into it.

enum Faction { NEUTRAL = 0, SAXON = 1, DANE = 2 }

enum Arrival {
	DEPLOYED = 0,  ## Already on the field when the act opens.
	MARCH = 1,     ## Walks in from the map edge; visible on approach.
	LANDING = 2,   ## Comes off a ship; brief vulnerable disembark.
	SALLY = 3,     ## Exits a garrisoned building at this point.
}

enum Stance {
	HOLD = 0,       ## Stand and shoot; will not chase.
	DEFEND = 1,     ## Holds, but pursues briefly within the sector.
	ADVANCE = 2,    ## Moves to its order target, engaging on the way.
	ASSAULT = 3,    ## Closes to melee, ignores suppression longer.
	WITHDRAW = 4,   ## Falls back toward its spawn.
}

@export var spawn_id: StringName = &""
@export var faction: Faction = Faction.SAXON
## Looked up in MissionDefinition.squad_library. Empty means the marker is a
## navigation target only (an evacuation goal, a rally point).
@export var squad_id: StringName = &""
@export var arrival: Arrival = Arrival.DEPLOYED
@export var stance: Stance = Stance.DEFEND
## Facing on arrival, in Godot 2D degrees (0 = east, 270 = north).
@export_range(0.0, 360.0, 5.0) var facing_deg: float = 270.0
## Squads arriving here spread over this radius so they do not stack.
@export_range(0.0, 300.0, 5.0) var scatter_px: float = 40.0
## Optional sector this spawn's squads move to by default.
@export var default_order_target: StringName = &""
## Free-form tag for scripted events, e.g. "act2_reinforcement".
@export var group_tag: StringName = &""


func _ready() -> void:
	add_to_group(&"spawn")
	if group_tag != &"":
		add_to_group(group_tag)


## A scattered position for the nth squad arriving here.
func position_for_index(index: int) -> Vector2:
	if scatter_px <= 0.0 or index <= 0:
		return global_position
	var angle := deg_to_rad(facing_deg + 180.0) + float(index) * 2.399963  # golden angle
	var radius := scatter_px * sqrt(float(index) / 6.0)
	return global_position + Vector2.RIGHT.rotated(angle) * radius


func is_navigation_target_only() -> bool:
	return squad_id == &""


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if String(spawn_id).is_empty():
		warnings.append("SpawnMarker needs a spawn_id; waves reference it by that id.")
	return warnings
