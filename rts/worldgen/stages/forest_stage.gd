class_name ForestStage
extends RefCounted

## Stage 1. Cover the whole map in wildwood.
##
## Every later stage subtracts from this: the river clears its channel and
## banks, the cliffs go bare above the treeline, the villages clear their
## fields and the roads cut a corridor. Starting from full cover and removing
## is what makes the map read as inhabited - every gap in the canopy is
## somewhere water, rock or people put it there.

const SPACING := 14.0        ## Mean gap between trunks, px.
const JITTER := 0.62         ## Fraction of a cell a trunk may wander.
const GLADE_THRESHOLD := 0.16  ## Below this density value, no tree.

const KIND_OAK := 0
const KIND_ASH := 1
const KIND_THORN := 2


static func run(world: WorldData) -> void:
	var density := FastNoiseLite.new()
	density.seed = world.rng.randi()
	density.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	density.frequency = 0.0022
	density.fractal_octaves = 4
	density.fractal_lacunarity = 2.1
	density.fractal_gain = 0.48

	# A second, coarser field decides species, so oak stands and thorn scrub
	# come in patches rather than salt-and-pepper.
	var species := FastNoiseLite.new()
	species.seed = world.rng.randi()
	species.noise_type = FastNoiseLite.TYPE_SIMPLEX
	species.frequency = 0.0016

	var positions := PackedVector2Array()
	var scales := PackedFloat32Array()
	var rotations := PackedFloat32Array()
	var kinds := PackedByteArray()

	var step := SPACING
	var cols := int(ceil(float(world.size_px.x) / step))
	var rows := int(ceil(float(world.size_px.y) / step))

	for gy in rows:
		for gx in cols:
			# Offset alternate rows so the grid never shows through as lines.
			var ox := (float(gy) * 0.5) if gy % 2 == 1 else 0.0
			var base := Vector2((float(gx) + ox) * step, float(gy) * step)
			var jitter := Vector2(
				world.rng.randf_range(-JITTER, JITTER) * step,
				world.rng.randf_range(-JITTER, JITTER) * step)
			var point := base + jitter
			if point.x < 4.0 or point.y < 4.0 \
					or point.x > float(world.size_px.x) - 4.0 \
					or point.y > float(world.size_px.y) - 4.0:
				continue

			var d := density.get_noise_2dv(point) * 0.5 + 0.5
			if d < GLADE_THRESHOLD:
				continue
			# Thin the canopy toward the edge of a glade instead of ending it
			# with a hard line.
			var edge := smoothstep(GLADE_THRESHOLD, GLADE_THRESHOLD + 0.18, d)
			if world.rng.randf() > edge:
				continue

			var s := species.get_noise_2dv(point)
			var kind := KIND_OAK
			if s < -0.25:
				kind = KIND_THORN
			elif s < 0.15:
				kind = KIND_ASH

			var scale := 1.0
			match kind:
				KIND_OAK: scale = world.rng.randf_range(0.92, 1.35)
				KIND_ASH: scale = world.rng.randf_range(0.78, 1.10)
				_: scale = world.rng.randf_range(0.48, 0.72)
			# Bigger trees where the canopy is densest - crowding reads as depth.
			scale *= lerpf(0.86, 1.12, d)

			positions.append(point)
			scales.append(scale)
			rotations.append(world.rng.randf_range(0.0, TAU))
			kinds.append(kind)

			var c := world.cell_at(point)
			world.set_flag(c.x, c.y, WorldData.FOREST)

	world.tree_positions = positions
	world.tree_scales = scales
	world.tree_rotations = rotations
	world.tree_kinds = kinds
	world.note("forest", "%d trees over %d x %d px"
		% [positions.size(), world.size_px.x, world.size_px.y])


## Remove every tree for which `should_clear` returns true. Later stages call
## this rather than editing the parallel arrays by hand.
static func clear_where(world: WorldData, should_clear: Callable) -> int:
	var positions := PackedVector2Array()
	var scales := PackedFloat32Array()
	var rotations := PackedFloat32Array()
	var kinds := PackedByteArray()
	var removed := 0
	for i in world.tree_positions.size():
		var point := world.tree_positions[i]
		if should_clear.call(point):
			removed += 1
			continue
		positions.append(point)
		scales.append(world.tree_scales[i])
		rotations.append(world.tree_rotations[i])
		kinds.append(world.tree_kinds[i])
	world.tree_positions = positions
	world.tree_scales = scales
	world.tree_rotations = rotations
	world.tree_kinds = kinds
	return removed


## Recompute the FOREST flag from the surviving trunks. Cheap, and keeps the
## cell field honest after a stage has cleared a swathe.
static func refresh_forest_flags(world: WorldData) -> void:
	for i in world.flags.size():
		world.flags[i] &= ~WorldData.FOREST
	for point in world.tree_positions:
		var c := world.cell_at(point)
		world.set_flag(c.x, c.y, WorldData.FOREST)
