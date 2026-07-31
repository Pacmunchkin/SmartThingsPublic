class_name TextureBaker
extends RefCounted

## Turns the generated world into textures the shaders can read. Nothing here
## is loaded from disk - every pixel is written from the stage output at run
## time, which is what lets the whole map change with one seed.
##
## Two textures carry the world:
##
##   field:  R height (normalised)  G slope  B water depth  A river distance
##   cover:  R road    G village/field  B forest density    A cliff
##
## The field map is RGBA16F: the hillshade differentiates the height channel,
## and 8-bit steps show up as contour rings across any ground flat enough to
## build on. The cover map is RGBA8, which is all a set of masks needs.
## Gameplay never reads either - those queries go to the float arrays through
## WorldSampler.

## Height is packed against a fixed range so the lighting does not change
## character between seeds. Anything outside is clamped.
const HEIGHT_MIN := -80.0
const HEIGHT_MAX := 200.0
const SLOPE_MAX := 1.2
const WATER_MAX := 3.0
const RIVER_DISTANCE_MAX := 420.0
## Radius, in cells, over which canopy cover is averaged for the forest floor
## tint. Individual trunks are drawn as instances; this is the shade they cast.
const CANOPY_BLUR := 2


static func bake_field(world: WorldData) -> ImageTexture:
	var image := Image.create(world.cols, world.rows, false, Image.FORMAT_RGBAH)
	for cy in world.rows:
		for cx in world.cols:
			var index := world.idx(cx, cy)
			var height := inverse_lerp(HEIGHT_MIN, HEIGHT_MAX, world.height[index])
			var slope := world.slope[index] / SLOPE_MAX
			var water := world.water_depth[index] / WATER_MAX
			var distance := world.river_distance[index] / RIVER_DISTANCE_MAX
			image.set_pixel(cx, cy, Color(
				clampf(height, 0.0, 1.0),
				clampf(slope, 0.0, 1.0),
				clampf(water, 0.0, 1.0),
				clampf(distance, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


static func bake_cover(world: WorldData) -> ImageTexture:
	var canopy := _canopy_density(world)
	var image := Image.create(world.cols, world.rows, false, Image.FORMAT_RGBA8)
	for cy in world.rows:
		for cx in world.cols:
			var index := world.idx(cx, cy)
			var flags := world.flags[index]
			var road := 1.0 if (flags & WorldData.ROAD) != 0 else 0.0
			var settled := 0.0
			if (flags & WorldData.VILLAGE) != 0:
				settled = 1.0
			elif (flags & WorldData.FIELD) != 0:
				settled = 0.5
			var cliff := 1.0 if (flags & WorldData.CLIFF) != 0 else 0.0
			image.set_pixel(cx, cy, Color(road, settled, canopy[index], cliff))
	return ImageTexture.create_from_image(image)


## Blurred trunk count per cell. Used for the shade the canopy throws on the
## ground, so a clearing reads as a clearing even before the trees draw.
static func _canopy_density(world: WorldData) -> PackedFloat32Array:
	var raw := PackedFloat32Array()
	raw.resize(world.cols * world.rows)
	raw.fill(0.0)
	for i in world.tree_positions.size():
		var c := world.cell_at(world.tree_positions[i])
		var index := world.idx(c.x, c.y)
		raw[index] = minf(raw[index] + 0.34 * world.tree_scales[i], 1.0)

	var blurred := raw.duplicate()
	for _pass in 2:
		var source := blurred.duplicate()
		for cy in world.rows:
			for cx in world.cols:
				var total := 0.0
				var count := 0
				for dy in range(-CANOPY_BLUR, CANOPY_BLUR + 1):
					for dx in range(-CANOPY_BLUR, CANOPY_BLUR + 1):
						var nx := cx + dx
						var ny := cy + dy
						if world.in_bounds(nx, ny):
							total += source[world.idx(nx, ny)]
							count += 1
				blurred[world.idx(cx, cy)] = total / float(count)
	return blurred


## A canopy sprite, drawn in code. Three species share one texture, split
## across the horizontal axis, so the tree shader can pick a frame from
## per-instance custom data and the whole forest is one draw call.
##
## Each is built the same way: a lobed silhouette from summed sine harmonics,
## shaded by a light from the north-west, broken up with value noise so no two
## instances read as the same stamp once rotation and scale are applied.
static func bake_tree_atlas(size: int = 96) -> ImageTexture:
	var frames := 3
	var image := Image.create(size * frames, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()

	# lobes, radius, raggedness, base colour
	var species := [
		{"lobes": 5, "radius": 0.40, "ragged": 0.16, "colour": Color(0.22, 0.35, 0.17)},
		{"lobes": 7, "radius": 0.35, "ragged": 0.12, "colour": Color(0.28, 0.42, 0.21)},
		{"lobes": 9, "radius": 0.27, "ragged": 0.26, "colour": Color(0.31, 0.34, 0.19)},
	]

	for frame in frames:
		var spec: Dictionary = species[frame]
		rng.seed = 1000 + frame * 77
		var phase_a := rng.randf_range(0.0, TAU)
		var phase_b := rng.randf_range(0.0, TAU)
		var centre := Vector2(size * 0.5, size * 0.5)
		var lobes: float = float(spec["lobes"])
		var ragged: float = spec["ragged"]
		var base_radius: float = float(size) * float(spec["radius"])

		for y in size:
			for x in size:
				var point := Vector2(float(x) + 0.5, float(y) + 0.5)
				var offset := point - centre
				var angle := offset.angle()
				var distance := offset.length()

				# Lobed outline: two harmonics so the silhouette is irregular
				# rather than a flower.
				var wobble: float = sin(angle * lobes + phase_a) * ragged \
					+ sin(angle * (lobes * 2.0 + 1.0) + phase_b) * ragged * 0.45
				var radius: float = base_radius * (1.0 + wobble)
				var edge := distance / maxf(radius, 0.001)
				if edge > 1.0:
					continue

				var alpha := clampf((1.0 - edge) / 0.18, 0.0, 1.0)
				# Light from the north-west, plus a little ambient from below.
				var normal_y := -offset.y / maxf(radius, 0.001)
				var normal_x := -offset.x / maxf(radius, 0.001)
				var lambert := clampf(0.5 + 0.5 * (normal_x * 0.5 + normal_y * 0.72), 0.0, 1.0)
				var dome := sqrt(clampf(1.0 - edge * edge, 0.0, 1.0))
				var light := lerpf(0.45, 1.25, lambert * 0.65 + dome * 0.35)

				var grain := _value_noise(point * 0.22 + Vector2(frame * 31, 0)) * 0.18 \
					+ _value_noise(point * 0.07) * 0.12
				var colour: Color = spec["colour"]
				colour = Color(
					clampf(colour.r * (light + grain), 0.0, 1.0),
					clampf(colour.g * (light + grain), 0.0, 1.0),
					clampf(colour.b * (light + grain * 0.6), 0.0, 1.0),
					alpha)
				image.set_pixel(frame * size + x, y, colour)

	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


static func _hash21(point: Vector2) -> float:
	var value := sin(point.dot(Vector2(127.1, 311.7))) * 43758.5453
	return value - floor(value)


static func _value_noise(point: Vector2) -> float:
	var cell := point.floor()
	var f := point - cell
	f = f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var a := _hash21(cell)
	var b := _hash21(cell + Vector2(1, 0))
	var c := _hash21(cell + Vector2(0, 1))
	var d := _hash21(cell + Vector2(1, 1))
	return lerpf(lerpf(a, b, f.x), lerpf(c, d, f.x), f.y) * 2.0 - 1.0
