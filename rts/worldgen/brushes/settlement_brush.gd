@tool
class_name SettlementBrush
extends WorldBrush

## A place people live. Drag the node itself to move it - there is no shape to
## draw, because a settlement is a centre and two radii, not an outline.
##
## Does four things at once, which is the point of it being one brush:
##   clears the wood for houses and fields,
##   levels the ground so buildings sit true,
##   marks the core and the worked land,
##   registers itself so a capture sector and any roads can find it.
##
## RoadBrush looks settlements up by `settlement_name`, so naming these is not
## decoration - it is how the road network is wired.

@export var settlement_name: String = "Newtown":
	set(value):
		settlement_name = value
		request_rebuild()
## Houses, yards and trodden ground.
@export_range(20.0, 400.0, 2.0) var radius: float = 92.0:
	set(value):
		radius = value
		request_rebuild()
## Ploughed and grazed land around the core. Must exceed radius.
@export_range(20.0, 700.0, 2.0) var field_radius: float = 168.0:
	set(value):
		field_radius = value
		request_rebuild()
## Level the ground. Turn off to keep a village clinging to a hillside.
@export var level_ground: bool = true:
	set(value):
		level_ground = value
		request_rebuild()
## Become a TacticalSector the mission layer can fight over.
@export var is_capture_point: bool = true:
	set(value):
		is_capture_point = value
		request_rebuild()
@export var owner_faction: TacticalSector.Faction = TacticalSector.Faction.NEUTRAL:
	set(value):
		owner_faction = value
		request_rebuild()


func affects_height() -> bool:
	return level_ground


func apply(world: WorldData) -> void:
	var centre := global_position
	var village := {
		"position": centre,
		"radius": radius,
		"field_radius": maxf(field_radius, radius + 10.0),
		"name": settlement_name,
		"score": 0.0,
		"on_ford": _near_ford(world, centre),
		"sector_id": StringName("sector_%s" % settlement_name.to_snake_case()),
		"owner": owner_faction,
		"capture_point": is_capture_point,
	}

	if level_ground:
		VillageStage.settle_one(world, village)
	else:
		# Still mark the ground, just do not touch its height.
		_mark_only(world, village)

	var removed := VillageStage.clear_around(world, [village])

	# Only registered as a village if it should become a capture point; a
	# farmstead is a place without being an objective.
	if is_capture_point:
		world.villages.append(village)

	world.note("settlements", "%s at %s, cleared %d trees%s"
		% [settlement_name, centre, removed,
		   ", on a crossing" if village["on_ford"] else ""])


func _mark_only(world: WorldData, village: Dictionary) -> void:
	var centre: Vector2 = village["position"]
	var field: float = village["field_radius"]
	var cells := int(ceil(field / float(world.cell))) + 1
	var origin := world.cell_at(centre)
	for dy in range(-cells, cells + 1):
		for dx in range(-cells, cells + 1):
			var cx := origin.x + dx
			var cy := origin.y + dy
			if not world.in_bounds(cx, cy):
				continue
			var d := world.cell_centre(cx, cy).distance_to(centre)
			if d > field:
				continue
			if d <= radius:
				world.set_flag(cx, cy, WorldData.VILLAGE)
			else:
				world.set_flag(cx, cy, WorldData.FIELD)


func _near_ford(world: WorldData, centre: Vector2) -> bool:
	for crossing in world.fords:
		if centre.distance_to(crossing) < 200.0:
			return true
	return false


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if field_radius <= radius:
		warnings.append("field_radius should be larger than radius.")
	if settlement_name.strip_edges().is_empty():
		warnings.append("Give this settlement a name; RoadBrush finds it by name.")
	return warnings
