class_name VillageStage
extends RefCounted

## Stage 4. Decide where people would have chosen to live.
##
## The scoring is an argument about pre-modern settlement, not an aesthetic
## preference. In rough order of how much it matters:
##
##   Water you can carry from, every day, by hand. Close - but not so close
##   that the spring flood takes the houses. This is the single strongest
##   term, and it is a band, not a gradient.
##   Dry ground. Height above the channel is worth more than any view.
##   Flat, workable land, and enough of it that the settlement can grow into
##   fields rather than being hemmed in after two generations.
##   A crossing. Wherever people must ford, other people stop, trade and
##   eventually stay. Fords make towns.
##   Shelter. The valley floor and the lee of a shoulder, not an exposed top.
##
## The result is deliberately clustered near the water and the fords, because
## that is where the real ones are.

const COUNT := 4
const RADIUS := 92.0            ## Core of the settlement, px.
const FIELD_RADIUS := 168.0     ## Cleared and worked ground around it.
const MIN_SEPARATION := 400.0   ## A day's business apart, px.
const EDGE_MARGIN := 110.0

## Ideal distance from the centreline, and the width of the band that is
## still acceptable. Roughly a hundred paces to the water.
const WATER_IDEAL := 105.0
const WATER_TOLERANCE := 85.0
## Height above the local waterline that counts as safely dry.
const DRY_MIN := 5.0
const DRY_IDEAL := 20.0

const W_WATER := 3.2
const W_DRY := 2.4
const W_FLAT := 2.0
const W_ROOM := 1.8
const W_FORD := 1.6
const W_SHELTER := 0.8

const NAME_PREFIX := ["Ēast", "Wes", "Nor", "Sūð", "Ash", "Elm", "Haw", "Stan",
	"Wic", "Cyne", "Æsc", "Oak", "Bear", "Hart", "Fen", "Mere"]
const NAME_SUFFIX := ["burh", "tūn", "ham", "ford", "leah", "stede", "wic",
	"cot", "denu", "wella"]


static func run(world: WorldData) -> void:
	var water_level := _water_level_per_row(world)
	var room := _buildable_integral(world)
	var scores := _score_all(world, water_level, room)
	_choose_sites(world, scores)
	_settle(world)
	LandscapeStage.recompute_slope(world)


## The river's surface height for each row, carried across rows the channel
## does not touch. "Above the water" has to mean the local water, not the
## mouth, or every site in the north of the map looks like a cliff top.
static func _water_level_per_row(world: WorldData) -> PackedFloat32Array:
	var level := PackedFloat32Array()
	level.resize(world.rows)
	var last := 0.0
	var seen := false
	for cy in world.rows:
		var lowest := INF
		for cx in world.cols:
			var index := world.idx(cx, cy)
			if (world.flags[index] & WorldData.RIVER) != 0:
				lowest = minf(lowest, world.height[index])
		if is_finite(lowest):
			last = lowest
			seen = true
		level[cy] = last if seen else 0.0
	# Rows above the first channel cell inherit the first known level.
	if seen:
		for cy in world.rows:
			if level[cy] == 0.0 and cy < world.rows - 1:
				level[cy] = last
			else:
				break
	return level


## Summed-area table over buildable cells, so "how much flat ground is within
## reach of here" is a constant-time query per candidate instead of a window
## scan over the whole map.
static func _buildable_integral(world: WorldData) -> PackedInt32Array:
	var w := world.cols + 1
	var h := world.rows + 1
	var table := PackedInt32Array()
	table.resize(w * h)
	for i in table.size():
		table[i] = 0
	for cy in world.rows:
		var row_total := 0
		for cx in world.cols:
			row_total += 1 if LandscapeStage.is_buildable(world, world.idx(cx, cy)) else 0
			table[(cy + 1) * w + (cx + 1)] = table[cy * w + (cx + 1)] + row_total
	return table


static func _room_within(world: WorldData, table: PackedInt32Array,
		cx: int, cy: int, cells: int) -> int:
	var w := world.cols + 1
	var x0 := clampi(cx - cells, 0, world.cols)
	var y0 := clampi(cy - cells, 0, world.rows)
	var x1 := clampi(cx + cells + 1, 0, world.cols)
	var y1 := clampi(cy + cells + 1, 0, world.rows)
	return table[y1 * w + x1] - table[y0 * w + x1] - table[y1 * w + x0] + table[y0 * w + x0]


static func _score_all(world: WorldData, water_level: PackedFloat32Array,
		room: PackedInt32Array) -> PackedFloat32Array:
	var scores := PackedFloat32Array()
	scores.resize(world.cols * world.rows)
	scores.fill(-1.0)

	var room_cells := int(ceil(FIELD_RADIUS / float(world.cell)))
	var room_max := float((room_cells * 2 + 1) * (room_cells * 2 + 1))
	var map_w := float(world.size_px.x)
	var map_h := float(world.size_px.y)

	for cy in world.rows:
		for cx in world.cols:
			var index := world.idx(cx, cy)
			var point := world.cell_centre(cx, cy)
			if point.x < EDGE_MARGIN or point.y < EDGE_MARGIN \
					or point.x > map_w - EDGE_MARGIN or point.y > map_h - EDGE_MARGIN:
				continue
			if (world.flags[index] & (WorldData.RIVER | WorldData.BANK | WorldData.CLIFF)) != 0:
				continue
			if not LandscapeStage.is_buildable(world, index):
				continue

			# Water: a band around the ideal carry, falling off both ways.
			var d := world.river_distance[index]
			var water := exp(-pow((d - WATER_IDEAL) / WATER_TOLERANCE, 2.0))

			# Dry: strictly above the flood, and better a little higher.
			var above := world.height[index] - water_level[cy]
			if above < DRY_MIN:
				continue
			var dry := clampf((above - DRY_MIN) / (DRY_IDEAL - DRY_MIN), 0.0, 1.0)
			# Past the ideal it stops helping - nobody hauls water up a hill.
			dry *= clampf(1.0 - (above - DRY_IDEAL) / 70.0, 0.25, 1.0)

			var flat := clampf(1.0 - world.slope[index] / LandscapeStage.BUILDABLE_SLOPE,
				0.0, 1.0)
			var space := clampf(float(_room_within(world, room, cx, cy, room_cells))
				/ room_max, 0.0, 1.0)

			var ford := 0.0
			for crossing in world.fords:
				var fd := point.distance_to(crossing)
				ford = maxf(ford, clampf(1.0 - fd / 340.0, 0.0, 1.0))

			# Shelter: within the valley, out of the wind on the tops.
			var shelter := clampf(1.0 - d / (LandscapeStage.TERRACE_HALF_WIDTH
				+ LandscapeStage.WALL_RUN + 120.0), 0.0, 1.0)

			scores[index] = W_WATER * water + W_DRY * dry + W_FLAT * flat \
				+ W_ROOM * space + W_FORD * ford + W_SHELTER * shelter
	return scores


static func _choose_sites(world: WorldData, scores: PackedFloat32Array) -> void:
	var ranked: Array[Dictionary] = []
	for i in scores.size():
		if scores[i] > 0.0:
			ranked.append({"index": i, "score": scores[i]})
	if ranked.is_empty():
		world.note("villages", "no site met the settlement criteria")
		return
	ranked.sort_custom(func(a, b): return a["score"] > b["score"])

	var chosen: Array[Dictionary] = []
	var used_names: Dictionary = {}
	for candidate in ranked:
		if chosen.size() >= COUNT:
			break
		var index: int = candidate["index"]
		var cx := index % world.cols
		var cy := index / world.cols
		var point := world.cell_centre(cx, cy)
		var too_close := false
		for existing in chosen:
			if (existing["position"] as Vector2).distance_to(point) < MIN_SEPARATION:
				too_close = true
				break
		if too_close:
			continue
		chosen.append({
			"position": point,
			"radius": RADIUS,
			"field_radius": FIELD_RADIUS,
			"score": candidate["score"],
			"name": _make_name(world, used_names),
			"on_ford": _near_ford(world, point),
		})

	world.villages = chosen
	for village in chosen:
		world.note("villages", "%s at %s (score %.2f%s)"
			% [village["name"], village["position"],
			   village["score"], ", on a crossing" if village["on_ford"] else ""])


static func _near_ford(world: WorldData, point: Vector2) -> bool:
	for crossing in world.fords:
		if point.distance_to(crossing) < 200.0:
			return true
	return false


static func _make_name(world: WorldData, used: Dictionary) -> String:
	for _attempt in 24:
		var name: String = NAME_PREFIX[world.rng.randi() % NAME_PREFIX.size()] \
			+ NAME_SUFFIX[world.rng.randi() % NAME_SUFFIX.size()]
		if not used.has(name):
			used[name] = true
			return name
	return "Nameless"


## Clear the trees, work the fields and level the ground people build on.
static func _settle(world: WorldData) -> void:
	if world.villages.is_empty():
		return

	for village in world.villages:
		var centre: Vector2 = village["position"]
		var radius: float = village["radius"]
		var field: float = village["field_radius"]
		var cells := int(ceil(field / float(world.cell))) + 1
		var origin := world.cell_at(centre)

		# Level the core toward the site's own height so buildings sit true,
		# feathering out so the village does not end in a step.
		var target := world.height[world.idx(origin.x, origin.y)]
		for dy in range(-cells, cells + 1):
			for dx in range(-cells, cells + 1):
				var cx := origin.x + dx
				var cy := origin.y + dy
				if not world.in_bounds(cx, cy):
					continue
				var index := world.idx(cx, cy)
				if (world.flags[index] & WorldData.RIVER) != 0:
					continue
				var d := world.cell_centre(cx, cy).distance_to(centre)
				if d > field:
					continue
				var pull := 1.0 - smoothstep(radius * 0.6, field, d)
				world.height[index] = lerpf(world.height[index], target, pull * 0.9)
				world.flags[index] &= ~WorldData.CLIFF
				if d <= radius:
					world.flags[index] |= WorldData.VILLAGE
				else:
					world.flags[index] |= WorldData.FIELD

	var removed := ForestStage.clear_where(world, func(point: Vector2) -> bool:
		for village in world.villages:
			var centre: Vector2 = village["position"]
			var d := point.distance_to(centre)
			var core: float = village["radius"]
			var edge: float = village["field_radius"]
			if d <= core:
				return true
			# Thin the wood out toward the field edge rather than ending it
			# with a shaved circle.
			if d <= edge:
				var t: float = (d - core) / maxf(edge - core, 0.001)
				return world.rng.randf() > t * t
		return false)
	ForestStage.refresh_forest_flags(world)
	world.note("villages", "%d settlements, cleared %d trees for houses and fields"
		% [world.villages.size(), removed])
