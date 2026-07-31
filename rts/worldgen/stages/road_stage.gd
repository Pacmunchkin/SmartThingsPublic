class_name RoadStage
extends RefCounted

## Stage 5. Join the villages by the routes people would actually have worn.
##
## "Most efficient" is not the shortest line. It is the cheapest one, and the
## costs are the ones that mattered to someone walking with a loaded pony:
## climbing is expensive, wading is worse, cutting through standing wood is a
## nuisance, and someone else's road is nearly free. That last term is what
## makes the network braid - a new route joins an existing one and shares it
## for a stretch rather than running parallel fifty paces away, which is what
## real road networks do and what a naive shortest-path per pair does not.
##
## Cliffs are impassable, so the roads find the passes; the river is passable
## only at the fords, so the roads find the crossings. Neither is special-cased
## anywhere - both fall out of the cost field.

const HALF_WIDTH := 10.0         ## Metalled width either side of centreline.
const CLEAR_MARGIN := 20.0       ## Extra tree-free verge.
const SLOPE_PENALTY := 16.0
const FOREST_PENALTY := 0.45
## Amplitude of the ground-roughness field that keeps routes from running dead
## straight across flat ground.
const ROUGH_PENALTY := 0.85
const RIVER_PENALTY := 45.0      ## Off a ford, wading is close to prohibitive.
const FORD_PENALTY := 3.5
const VILLAGE_COST := 0.55       ## Roads converge on the places they serve.
const ROAD_COST := 0.22          ## Reuse of an existing road.
const IMPASSABLE := INF

const DIAGONAL := sqrt(2.0)


static func run(world: WorldData) -> void:
	if world.villages.size() < 2:
		world.note("roads", "fewer than two settlements; no network to build")
		return
	var cost := build_cost(world)
	var edges := _minimum_spanning_edges(world, cost)
	_lay_edges(world, cost, edges)
	_lay_road_out(world, cost)
	var removed := clear_verges(world)
	world.note("roads", "%d road(s), cleared %d trees from the verges"
		% [world.roads.size(), removed])
	LandscapeStage.recompute_slope(world)


static func build_cost(world: WorldData) -> PackedFloat32Array:
	# Rough going: bog, stone, bramble. Without it the valley floor is a
	# perfectly uniform plain, and a least-cost path across a uniform plain is
	# a dead straight line - which is exactly what the roads looked like, and
	# nothing like a track worn by feet. The noise is small enough not to beat
	# a real gradient, and low-frequency enough to bend a route rather than
	# make it jitter.
	var going := FastNoiseLite.new()
	going.seed = world.rng.randi()
	going.noise_type = FastNoiseLite.TYPE_SIMPLEX
	going.frequency = 0.006
	going.fractal_octaves = 3

	var cost := PackedFloat32Array()
	cost.resize(world.cols * world.rows)
	for i in cost.size():
		var flags := world.flags[i]
		if (flags & WorldData.CLIFF) != 0:
			cost[i] = IMPASSABLE
			continue
		var centre := world.cell_centre(i % world.cols, i / world.cols)
		var rough := (going.get_noise_2dv(centre) * 0.5 + 0.5) * ROUGH_PENALTY
		var value := 1.0 + world.slope[i] * SLOPE_PENALTY + rough
		if (flags & WorldData.RIVER) != 0:
			value += FORD_PENALTY if (flags & WorldData.FORD) != 0 else RIVER_PENALTY
		if (flags & WorldData.FOREST) != 0:
			value += FOREST_PENALTY
		if (flags & (WorldData.VILLAGE | WorldData.FIELD)) != 0:
			value = minf(value, VILLAGE_COST)
		cost[i] = value
	return cost


## Prim's, over A* path costs between every pair of settlements. Four villages
## is six searches; the network is small enough that exactness is free.
static func _minimum_spanning_edges(world: WorldData,
		cost: PackedFloat32Array) -> Array[Vector2i]:
	var count := world.villages.size()
	var distance := {}
	for a in count:
		for b in range(a + 1, count):
			var path := solve_route(world, cost,
				world.villages[a]["position"], world.villages[b]["position"])
			# Rank by what the route actually costs to walk, not by how many
			# cells it happens to pass through - a short climb is not a bargain.
			var route := route_cost(world, cost, path) if not path.is_empty() else -1.0
			distance[Vector2i(a, b)] = route
			distance[Vector2i(b, a)] = route

	var connected := [0]
	var edges: Array[Vector2i] = []
	while connected.size() < count:
		var best := Vector2i(-1, -1)
		var best_cost := INF
		for a in connected:
			for b in count:
				if connected.has(b):
					continue
				var route: float = distance.get(Vector2i(a, b), -1.0)
				if route < 0.0:
					continue
				if route < best_cost:
					best_cost = route
					best = Vector2i(a, b)
		if best.x < 0:
			break  # Unreachable settlement; leave it off the network.
		edges.append(best)
		connected.append(best.y)

	# One redundant link so the network is a web, not a tree. People do not
	# walk to the next village via the one in between if they can help it.
	var extra := Vector2i(-1, -1)
	var extra_cost := INF
	for a in count:
		for b in range(a + 1, count):
			var pair := Vector2i(a, b)
			if edges.has(pair) or edges.has(Vector2i(b, a)):
				continue
			var route: float = distance.get(pair, -1.0)
			if route >= 0.0 and route < extra_cost:
				extra_cost = route
				extra = pair
	if extra.x >= 0:
		edges.append(extra)
	return edges


static func _lay_edges(world: WorldData, cost: PackedFloat32Array,
		edges: Array[Vector2i]) -> void:
	for edge in edges:
		var from: Vector2 = world.villages[edge.x]["position"]
		var to: Vector2 = world.villages[edge.y]["position"]
		# Re-search on the live cost field so this road can join one already laid.
		var path := solve_route(world, cost, from, to)
		if path.is_empty():
			world.note("roads", "no route between %s and %s"
				% [world.villages[edge.x]["name"], world.villages[edge.y]["name"]])
			continue
		var smoothed := smooth_route(path)
		world.roads.append(smoothed)
		stamp_route(world, cost, smoothed)
		world.note("roads", "%s to %s, %d segments"
			% [world.villages[edge.x]["name"], world.villages[edge.y]["name"],
			   smoothed.size()])


## A road out of the valley, from whichever settlement sits nearest an edge.
## Without it the network is a closed pocket and the map has no approach.
static func _lay_road_out(world: WorldData, cost: PackedFloat32Array) -> void:
	var best_village := -1
	var best_target := Vector2.ZERO
	var best_distance := INF
	var map_w := float(world.size_px.x)
	var map_h := float(world.size_px.y)
	for i in world.villages.size():
		var point: Vector2 = world.villages[i]["position"]
		var candidates := [
			Vector2(point.x, 12.0), Vector2(point.x, map_h - 12.0),
			Vector2(12.0, point.y), Vector2(map_w - 12.0, point.y)]
		for target in candidates:
			var d := point.distance_to(target)
			if d < best_distance:
				best_distance = d
				best_village = i
				best_target = target
	if best_village < 0:
		return
	var path := solve_route(world, cost, world.villages[best_village]["position"], best_target)
	if path.is_empty():
		return
	var smoothed := smooth_route(path)
	world.roads.append(smoothed)
	stamp_route(world, cost, smoothed)
	world.note("roads", "way out of the valley from %s"
		% world.villages[best_village]["name"])


## Mark the corridor, grade it level and make it cheap for the next road.
static func stamp_route(world: WorldData, cost: PackedFloat32Array,
		path: PackedVector2Array) -> void:
	var reach := HALF_WIDTH + CLEAR_MARGIN
	var cells := int(ceil(reach / float(world.cell))) + 1
	for i in range(path.size() - 1):
		var a := path[i]
		var b := path[i + 1]
		var origin := world.cell_at((a + b) * 0.5)
		for dy in range(-cells, cells + 1):
			for dx in range(-cells, cells + 1):
				var cx := origin.x + dx
				var cy := origin.y + dy
				if not world.in_bounds(cx, cy):
					continue
				var index := world.idx(cx, cy)
				var d := WorldData.distance_to_segment(world.cell_centre(cx, cy), a, b)
				if d > HALF_WIDTH:
					continue
				world.flags[index] |= WorldData.ROAD
				world.flags[index] &= ~WorldData.CLIFF
				cost[index] = minf(cost[index], ROAD_COST)

	# Grade the surface: pull each road cell toward the average of its
	# neighbours along the route so the way is walkable rather than following
	# every ripple in the noise.
	for _pass in 2:
		var source := world.height.duplicate()
		for i in range(path.size()):
			var origin := world.cell_at(path[i])
			for dy in range(-cells, cells + 1):
				for dx in range(-cells, cells + 1):
					var cx := origin.x + dx
					var cy := origin.y + dy
					if not world.in_bounds(cx, cy):
						continue
					var index := world.idx(cx, cy)
					if (world.flags[index] & WorldData.ROAD) == 0:
						continue
					if (world.flags[index] & WorldData.RIVER) != 0:
						continue
					var total := 0.0
					var n := 0
					for ny in range(cy - 1, cy + 2):
						for nx in range(cx - 1, cx + 2):
							if world.in_bounds(nx, ny):
								total += source[world.idx(nx, ny)]
								n += 1
					world.height[index] = lerpf(world.height[index],
						total / float(n), 0.75)


## Fell whatever is standing in the road. Returns the count so a caller can
## report it; the generator logs a summary, a brush logs its own.
static func clear_verges(world: WorldData) -> int:
	var removed := ForestStage.clear_where(world, func(point: Vector2) -> bool:
		var c := world.cell_at(point)
		return world.has_flag(c.x, c.y, WorldData.ROAD))
	ForestStage.refresh_forest_flags(world)
	return removed


# --- pathfinding ------------------------------------------------------------

## Sum of per-cell cost along a route, weighted by the length of each step so
## diagonal moves are not counted as cheaply as orthogonal ones.
static func route_cost(world: WorldData, cost: PackedFloat32Array,
		path: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(path.size() - 1):
		var c := world.cell_at(path[i + 1])
		var step := cost[world.idx(c.x, c.y)]
		if not is_finite(step):
			return -1.0
		total += step * (path[i].distance_to(path[i + 1]) / float(world.cell))
	return total



static func solve_route(world: WorldData, cost: PackedFloat32Array,
		from_world: Vector2, to_world: Vector2) -> PackedVector2Array:
	var start_cell := world.cell_at(from_world)
	var goal_cell := world.cell_at(to_world)
	var start := world.idx(start_cell.x, start_cell.y)
	var goal := world.idx(goal_cell.x, goal_cell.y)
	var count := cost.size()
	if start == goal:
		return PackedVector2Array([from_world, to_world])

	var g := PackedFloat32Array()
	g.resize(count)
	g.fill(INF)
	var came := PackedInt32Array()
	came.resize(count)
	came.fill(-1)
	var closed := PackedByteArray()
	closed.resize(count)

	var heap_cell := PackedInt32Array()
	var heap_priority := PackedFloat32Array()

	g[start] = 0.0
	_heap_push(heap_cell, heap_priority, start, 0.0)

	while heap_cell.size() > 0:
		var current := _heap_pop(heap_cell, heap_priority)
		if closed[current] == 1:
			continue
		closed[current] = 1
		if current == goal:
			return _reconstruct(world, came, goal, from_world, to_world)

		var cx := current % world.cols
		var cy := current / world.cols
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var nx := cx + dx
				var ny := cy + dy
				if not world.in_bounds(nx, ny):
					continue
				var neighbour := world.idx(nx, ny)
				if closed[neighbour] == 1:
					continue
				var step_cost := cost[neighbour]
				if not is_finite(step_cost):
					continue
				# Corner-cutting past a cliff is not a route.
				if dx != 0 and dy != 0:
					if not is_finite(cost[world.idx(nx, cy)]) \
							or not is_finite(cost[world.idx(cx, ny)]):
						continue
					step_cost *= DIAGONAL
				var tentative := g[current] + step_cost
				if tentative >= g[neighbour]:
					continue
				g[neighbour] = tentative
				came[neighbour] = current
				var heuristic := Vector2(nx - goal_cell.x, ny - goal_cell.y).length()
				_heap_push(heap_cell, heap_priority, neighbour, tentative + heuristic)

	return PackedVector2Array()


static func _reconstruct(world: WorldData, came: PackedInt32Array, goal: int,
		from_world: Vector2, to_world: Vector2) -> PackedVector2Array:
	var reversed := PackedVector2Array()
	var current := goal
	while current != -1:
		reversed.append(world.cell_centre(current % world.cols, current / world.cols))
		current = came[current]
	var path := PackedVector2Array()
	path.append(from_world)
	for i in range(reversed.size() - 1, -1, -1):
		path.append(reversed[i])
	path.append(to_world)
	return path


## Chaikin corner cutting. The grid path is a staircase; two passes are enough
## to make it read as a worn track without pulling it off the pass it found.
static func smooth_route(path: PackedVector2Array) -> PackedVector2Array:
	var current := path
	for _pass in 2:
		if current.size() < 3:
			break
		var next := PackedVector2Array()
		next.append(current[0])
		for i in range(current.size() - 1):
			var a := current[i]
			var b := current[i + 1]
			next.append(a.lerp(b, 0.25))
			next.append(a.lerp(b, 0.75))
		next.append(current[current.size() - 1])
		current = next
	return current


static func _heap_push(cells: PackedInt32Array, priorities: PackedFloat32Array,
		cell: int, priority: float) -> void:
	cells.append(cell)
	priorities.append(priority)
	var i := cells.size() - 1
	while i > 0:
		var parent := (i - 1) / 2
		if priorities[parent] <= priorities[i]:
			break
		_heap_swap(cells, priorities, i, parent)
		i = parent


static func _heap_pop(cells: PackedInt32Array, priorities: PackedFloat32Array) -> int:
	var top := cells[0]
	var last := cells.size() - 1
	cells[0] = cells[last]
	priorities[0] = priorities[last]
	cells.remove_at(last)
	priorities.remove_at(last)
	var i := 0
	var size := cells.size()
	while true:
		var left := i * 2 + 1
		var right := left + 1
		var smallest := i
		if left < size and priorities[left] < priorities[smallest]:
			smallest = left
		if right < size and priorities[right] < priorities[smallest]:
			smallest = right
		if smallest == i:
			break
		_heap_swap(cells, priorities, i, smallest)
		i = smallest
	return top


static func _heap_swap(cells: PackedInt32Array, priorities: PackedFloat32Array,
		a: int, b: int) -> void:
	var cell := cells[a]
	cells[a] = cells[b]
	cells[b] = cell
	var priority := priorities[a]
	priorities[a] = priorities[b]
	priorities[b] = priority
