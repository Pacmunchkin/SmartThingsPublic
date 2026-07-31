@tool
class_name RoadBrush
extends WorldBrush

## Lays a track, and clears the verges.
##
## Two modes, because both are genuinely useful:
##
## SOLVE  - name two settlements and let A* find the cheapest way between them
##          over the real cost of the ground: climbing is expensive, wading is
##          worse, standing wood is a nuisance, and an existing road is nearly
##          free. Put this *below* your other roads in the tree and it will
##          join them and share a stretch rather than running parallel.
##
## DRAWN  - add a Path2D child and the road follows exactly that. Use it when
##          the route is a design decision rather than a logistics one: a road
##          that has to pass the shrine, or one you want funnelling attackers
##          into a killing ground.
##
## Both stamp the same thing, so a level can mix them freely.

enum Mode {
	SOLVE = 0,  ## Cheapest route between two named settlements.
	DRAWN = 1,  ## Follow the Path2D child exactly.
}

@export var mode: Mode = Mode.SOLVE:
	set(value):
		mode = value
		request_rebuild()
		notify_property_list_changed()

@export_group("Solved route")
## Must match a SettlementBrush's settlement_name earlier in the tree.
@export var from_settlement: String = "":
	set(value):
		from_settlement = value
		request_rebuild()
@export var to_settlement: String = "":
	set(value):
		to_settlement = value
		request_rebuild()
## Instead of a second settlement, run off the nearest map edge. Useful for the
## road that leaves the valley - a map with no approach reads as a pocket.
@export var to_map_edge: bool = false:
	set(value):
		to_map_edge = value
		request_rebuild()

@export_group("Surface")
@export_range(2.0, 60.0, 1.0) var half_width: float = 10.0:
	set(value):
		half_width = value
		request_rebuild()
@export_range(0.0, 80.0, 1.0) var verge: float = 20.0:
	set(value):
		verge = value
		request_rebuild()
## Grade the surface so the way is walkable rather than following every ripple.
@export var level_surface: bool = true:
	set(value):
		level_surface = value
		request_rebuild()


func affects_height() -> bool:
	return level_surface


func apply(world: WorldData) -> void:
	var path := _route(world)
	if path.size() < 2:
		return

	var smoothed := RoadStage.smooth_route(path)
	world.roads.append(smoothed)

	# stamp_route wants a live cost field so repeated roads can share; build it
	# fresh here because brushes are independent and one may have been disabled.
	var cost := RoadStage.build_cost(world)
	RoadStage.stamp_route(world, cost, smoothed)
	var removed := RoadStage.clear_verges(world)

	world.note("roads", "%s laid %d segments, cleared %d trees"
		% [name, smoothed.size(), removed])


func _route(world: WorldData) -> PackedVector2Array:
	if mode == Mode.DRAWN:
		var drawn := curve_points()
		if drawn.size() < 2:
			world.note("roads", "%s is set to DRAWN but has no Path2D curve" % name)
		return drawn

	var from := _find_settlement(world, from_settlement)
	if from.is_empty():
		world.note("roads", "%s: no settlement named '%s' has been placed yet"
			% [name, from_settlement])
		return PackedVector2Array()

	var start: Vector2 = from["position"]
	var goal := Vector2.ZERO
	if to_map_edge:
		goal = _nearest_edge_point(world, start)
	else:
		var to := _find_settlement(world, to_settlement)
		if to.is_empty():
			world.note("roads", "%s: no settlement named '%s' has been placed yet"
				% [name, to_settlement])
			return PackedVector2Array()
		goal = to["position"]

	var cost := RoadStage.build_cost(world)
	var path := RoadStage.solve_route(world, cost, start, goal)
	if path.is_empty():
		world.note("roads", "%s found no passable route; is a cliff in the way?" % name)
	return path


## Settlements are only visible to roads placed below them in the tree. That is
## the layer order doing its job, not a limitation - a road cannot lead to a
## village that does not exist yet.
func _find_settlement(world: WorldData, target: String) -> Dictionary:
	if target.strip_edges().is_empty():
		return {}
	for village in world.villages:
		if String(village["name"]) == target:
			return village
	return {}


func _nearest_edge_point(world: WorldData, from: Vector2) -> Vector2:
	var map_w := float(world.size_px.x)
	var map_h := float(world.size_px.y)
	var candidates := [
		Vector2(from.x, 12.0), Vector2(from.x, map_h - 12.0),
		Vector2(12.0, from.y), Vector2(map_w - 12.0, from.y)]
	var best: Vector2 = candidates[0]
	var best_distance := INF
	for candidate in candidates:
		var d := from.distance_to(candidate)
		if d < best_distance:
			best_distance = d
			best = candidate
	return best


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if mode == Mode.DRAWN and not has_curve():
		warnings.append("RoadBrush is in DRAWN mode but has no Path2D child.")
	if mode == Mode.SOLVE:
		if from_settlement.strip_edges().is_empty():
			warnings.append("Set from_settlement to a SettlementBrush's name.")
		if not to_map_edge and to_settlement.strip_edges().is_empty():
			warnings.append("Set to_settlement, or tick to_map_edge.")
	return warnings
