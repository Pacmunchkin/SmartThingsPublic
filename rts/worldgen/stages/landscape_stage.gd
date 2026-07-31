class_name LandscapeStage
extends RefCounted

## Stage 3. Raise cliffs and hills, and let the river's course explain them.
##
## Height is assembled in three parts and then flattened selectively:
##   1. rolling hills from fBm,
##   2. ridged noise for crags, suppressed near the water,
##   3. a valley profile driven entirely by distance to the centreline.
##
## Step 3 is what makes the terrain look carved. The valley floor is a flat
## terrace either side of the channel, the walls climb over a fixed run, and
## the crags only get to exist beyond the shoulder. Without the terrace the
## valley is a V and there is nowhere to put a village; with it, the flat
## ground is a deliberate, measurable output of this stage rather than
## something the designer hopes the noise leaves behind.

const HILL_AMPLITUDE := 62.0
const CRAG_AMPLITUDE := 44.0
const VALLEY_DEPTH := 54.0
## Half-width of the flat valley floor, measured from the centreline.
const TERRACE_HALF_WIDTH := 150.0
## Distance over which the valley wall climbs from floor to shoulder.
const WALL_RUN := 190.0
## Above this gradient the ground is a cliff: impassable, and bare of trees.
const CLIFF_SLOPE := 0.80
## Ground at or under this gradient counts as buildable.
const BUILDABLE_SLOPE := 0.14
const TREELINE := 135.0


static func run(world: WorldData) -> void:
	_build_height(world)
	_smooth(world, 3)
	recompute_slope(world)
	_mark_cliffs(world)
	_clear_bare_ground(world)
	_report_flats(world)


static func _build_height(world: WorldData) -> void:
	var hills := FastNoiseLite.new()
	hills.seed = world.rng.randi()
	hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	hills.frequency = 0.0018
	hills.fractal_octaves = 5
	hills.fractal_gain = 0.5

	var crags := FastNoiseLite.new()
	crags.seed = world.rng.randi()
	crags.noise_type = FastNoiseLite.TYPE_SIMPLEX
	crags.frequency = 0.0030
	crags.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	crags.fractal_octaves = 4
	crags.fractal_gain = 0.55

	# The river falls steadily from source to mouth; everything else is
	# measured relative to that, so "above the water" means the same thing at
	# the top of the map as at the bottom.
	var fall := 46.0

	for cy in world.rows:
		for cx in world.cols:
			var index := world.idx(cx, cy)
			var point := world.cell_centre(cx, cy)
			var down := point.y / float(world.size_px.y)
			var base := (1.0 - down) * fall

			var d := world.river_distance[index]
			# 0 on the valley floor, 1 at the shoulder and beyond.
			var wall := clampf((d - TERRACE_HALF_WIDTH) / WALL_RUN, 0.0, 1.0)
			var climb := wall * wall * (3.0 - 2.0 * wall)  # smoothstep

			var hill := (hills.get_noise_2dv(point) * 0.5 + 0.5) * HILL_AMPLITUDE
			var crag := (crags.get_noise_2dv(point) * 0.5 + 0.5)
			crag = pow(crag, 1.8) * CRAG_AMPLITUDE

			# Hills and crags are both scaled by the valley profile, so neither
			# can intrude onto the floor and block the corridor.
			var relief := hill * climb + crag * climb * climb
			var value := base + relief - VALLEY_DEPTH * (1.0 - climb)

			# The channel itself is cut below its banks.
			if (world.flags[index] & WorldData.RIVER) != 0:
				value -= 6.0 + world.water_depth[index] * 3.0
			world.height[index] = value


## Box blur. Two passes is enough to take the noise's high frequencies off
## without losing the crags, and it is what stops the slope field from being
## speckled with false cliffs.
static func _smooth(world: WorldData, passes: int) -> void:
	for _p in passes:
		var source := world.height.duplicate()
		for cy in world.rows:
			for cx in world.cols:
				var total := 0.0
				var count := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var nx := cx + dx
						var ny := cy + dy
						if world.in_bounds(nx, ny):
							total += source[world.idx(nx, ny)]
							count += 1
				world.height[world.idx(cx, cy)] = total / float(count)


## Public: stages 4 and 5 flatten ground and must refresh the gradient after.
static func recompute_slope(world: WorldData) -> void:
	var run := float(world.cell)
	for cy in world.rows:
		for cx in world.cols:
			var xa := world.height[world.idx(maxi(cx - 1, 0), cy)]
			var xb := world.height[world.idx(mini(cx + 1, world.cols - 1), cy)]
			var ya := world.height[world.idx(cx, maxi(cy - 1, 0))]
			var yb := world.height[world.idx(cx, mini(cy + 1, world.rows - 1))]
			var gx := (xb - xa) / (2.0 * run)
			var gy := (yb - ya) / (2.0 * run)
			world.slope[world.idx(cx, cy)] = Vector2(gx, gy).length()


static func _mark_cliffs(world: WorldData) -> void:
	var count := 0
	for i in world.slope.size():
		if world.slope[i] >= CLIFF_SLOPE and (world.flags[i] & WorldData.RIVER) == 0:
			world.flags[i] |= WorldData.CLIFF
			count += 1
	world.note("landscape", "%d cliff cells (%.1f%% of the map)"
		% [count, 100.0 * float(count) / float(world.flags.size())])


## Nothing grows on a rock face or above the treeline.
static func _clear_bare_ground(world: WorldData) -> void:
	var removed := ForestStage.clear_where(world, func(point: Vector2) -> bool:
		var c := world.cell_at(point)
		var index := world.idx(c.x, c.y)
		if (world.flags[index] & WorldData.CLIFF) != 0:
			return true
		return world.height[index] > TREELINE)
	ForestStage.refresh_forest_flags(world)
	world.note("landscape", "cleared %d trees from crag and fell" % removed)


## The stage's contract with stage 4: report how much buildable ground the
## valley floor actually ended up with.
static func _report_flats(world: WorldData) -> void:
	var buildable := 0
	var on_floor := 0
	for i in world.slope.size():
		if (world.flags[i] & (WorldData.RIVER | WorldData.CLIFF)) != 0:
			continue
		if world.river_distance[i] > TERRACE_HALF_WIDTH + WALL_RUN:
			continue
		on_floor += 1
		if world.slope[i] <= BUILDABLE_SLOPE:
			buildable += 1
	var area := float(buildable) * pow(float(world.cell), 2.0)
	world.note("landscape", "%d buildable cells in the valley (%.0f%% of the floor, %.0f px^2)"
		% [buildable, 100.0 * float(buildable) / maxf(float(on_floor), 1.0), area])


static func is_buildable(world: WorldData, index: int) -> bool:
	if (world.flags[index] & (WorldData.RIVER | WorldData.CLIFF)) != 0:
		return false
	return world.slope[index] <= BUILDABLE_SLOPE
