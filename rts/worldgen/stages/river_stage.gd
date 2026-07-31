class_name RiverStage
extends RefCounted

## Stage 2. Run a river down the map and clear the trees out of its way.
##
## The river is authored before the terrain, not derived from it. That is the
## reverse of how water works in the world, but it is the right way round for
## a playable map: it guarantees one continuous navigable corridor from top to
## bottom, and stage 3 then raises the land around it so the valley looks
## carved rather than drawn.

const STEP := 46.0            ## Distance between centreline points, px.
const MEANDER := 0.55         ## Radians of wander the noise may add.
const SOURCE_WIDTH := 26.0
const MOUTH_WIDTH := 88.0
const BANK_MARGIN := 16.0     ## Tree-free shingle beyond the waterline.
## Cells further than this from the centreline stop tracking their distance,
## which keeps the distance field's cost proportional to the river, not the map.
const MAX_INFLUENCE := 420.0


static func run(world: WorldData) -> void:
	_trace_channel(world)
	carve_channel(world, world.river_points, world.river_widths)
	choose_fords(world)
	clear_channel(world)


static func _trace_channel(world: WorldData) -> void:
	var wander := FastNoiseLite.new()
	wander.seed = world.rng.randi()
	wander.noise_type = FastNoiseLite.TYPE_SIMPLEX
	wander.frequency = 0.0035
	wander.fractal_octaves = 3

	var width_noise := FastNoiseLite.new()
	width_noise.seed = world.rng.randi()
	width_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	width_noise.frequency = 0.006

	var points := PackedVector2Array()
	var widths := PackedFloat32Array()

	var map_w := float(world.size_px.x)
	var map_h := float(world.size_px.y)
	# Enter and leave through the short edges so the valley runs the length of
	# the portrait map and both banks stay playable.
	var point := Vector2(world.rng.randf_range(map_w * 0.34, map_w * 0.66), -40.0)
	var mouth_x := world.rng.randf_range(map_w * 0.30, map_w * 0.70)
	var heading := PI * 0.5  # Straight down.

	var guard := 0
	while point.y < map_h + 60.0 and guard < 400:
		guard += 1
		points.append(point)

		var t := clampf(point.y / map_h, 0.0, 1.0)
		var width := lerpf(SOURCE_WIDTH, MOUTH_WIDTH, pow(t, 0.75))
		width *= 1.0 + width_noise.get_noise_2dv(point) * 0.28
		widths.append(maxf(width, 14.0))

		# Meander from noise, plus a gentle pull toward the chosen mouth so the
		# river cannot wander off the map or pin itself to one edge.
		var meander := wander.get_noise_2dv(point) * MEANDER
		var pull := clampf((mouth_x - point.x) / map_w, -1.0, 1.0) * 0.9 * t
		var margin_push := 0.0
		if point.x < map_w * 0.18:
			margin_push = (map_w * 0.18 - point.x) / (map_w * 0.18) * 0.8
		elif point.x > map_w * 0.82:
			margin_push = -(point.x - map_w * 0.82) / (map_w * 0.18) * 0.8
		heading = PI * 0.5 + meander + pull + margin_push
		# Never let the channel double back uphill; a river that flows north is
		# a bug the player will notice before the designer does.
		heading = clampf(heading, PI * 0.5 - 1.0, PI * 0.5 + 1.0)
		point += Vector2.RIGHT.rotated(heading) * STEP

	points.append(Vector2(mouth_x, map_h + 60.0))
	widths.append(MOUTH_WIDTH * 1.1)

	world.river_points = points
	world.river_widths = widths
	world.note("river", "%d centreline points, %.0f to %.0f px wide"
		% [points.size(), widths[0], widths[widths.size() - 1]])


## Distance to the centreline, and water depth inside the channel. Stamped
## per segment with a bounding box so the cost tracks the river's length
## rather than cells times segments.
static func carve_channel(world: WorldData, points: PackedVector2Array,
		widths: PackedFloat32Array) -> void:
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var half := maxf(widths[i], widths[i + 1]) * 0.5
		var reach := MAX_INFLUENCE
		var min_x := int(floor((minf(a.x, b.x) - reach) / world.cell))
		var max_x := int(ceil((maxf(a.x, b.x) + reach) / world.cell))
		var min_y := int(floor((minf(a.y, b.y) - reach) / world.cell))
		var max_y := int(ceil((maxf(a.y, b.y) + reach) / world.cell))
		for cy in range(maxi(min_y, 0), mini(max_y + 1, world.rows)):
			for cx in range(maxi(min_x, 0), mini(max_x + 1, world.cols)):
				var centre := world.cell_centre(cx, cy)
				var d := WorldData.distance_to_segment(centre, a, b)
				var index := world.idx(cx, cy)
				if d >= world.river_distance[index]:
					continue
				world.river_distance[index] = d
				if d < half:
					# Deepest mid-channel, shelving to nothing at the bank.
					var shelf := 1.0 - (d / half)
					world.water_depth[index] = maxf(world.water_depth[index],
						shelf * shelf * (half / 30.0))
					world.flags[index] |= WorldData.RIVER
					world.flags[index] &= ~WorldData.FOREST
				elif d < half + BANK_MARGIN:
					world.flags[index] |= WorldData.BANK
					world.flags[index] &= ~WorldData.FOREST

	# Cells the stamping never reached are simply far away.
	for i in world.river_distance.size():
		if world.river_distance[i] > MAX_INFLUENCE:
			world.river_distance[i] = MAX_INFLUENCE


## Fords are where the channel is locally narrowest. Roads will want them, and
## so will anyone flanking; picking them here means stages 4 and 5 can treat
## them as fixed facts about the map.
static func choose_fords(world: WorldData) -> void:
	var widths := world.river_widths
	var points := world.river_points
	var count := widths.size()
	if count < 12:
		return
	var candidates: Array[Dictionary] = []
	# Ignore the first and last stretch: a ford in the top or bottom margin is
	# off the playable map.
	for i in range(4, count - 5):
		var is_local_min := true
		for j in range(maxi(i - 3, 0), mini(i + 4, count)):
			if widths[j] < widths[i]:
				is_local_min = false
				break
		if is_local_min:
			candidates.append({"index": i, "width": widths[i], "point": points[i]})
	candidates.sort_custom(func(a, b): return a["width"] < b["width"])

	var chosen: Array[Vector2] = []
	var min_separation := float(world.size_px.y) * 0.22
	for candidate in candidates:
		var point: Vector2 = candidate["point"]
		var too_close := false
		for existing in chosen:
			if existing.distance_to(point) < min_separation:
				too_close = true
				break
		if too_close:
			continue
		chosen.append(point)
		if chosen.size() >= 3:
			break

	world.fords = chosen
	for point in chosen:
		var c := world.cell_at(point)
		var radius := int(ceil(56.0 / world.cell))
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if Vector2(dx, dy).length() <= float(radius):
					world.set_flag(c.x + dx, c.y + dy, WorldData.FORD)
	world.note("river", "%d ford(s) at the narrows" % chosen.size())


static func clear_channel(world: WorldData) -> void:
	var removed := ForestStage.clear_where(world, func(point: Vector2) -> bool:
		var c := world.cell_at(point)
		return world.has_flag(c.x, c.y, WorldData.RIVER) \
			or world.has_flag(c.x, c.y, WorldData.BANK))
	world.note("river", "cleared %d trees from the channel and banks" % removed)
