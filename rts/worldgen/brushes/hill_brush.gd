@tool
class_name HillBrush
extends WorldBrush

## Raises (or sinks) the ground inside a Polygon2D child.
##
## There is no "uphill" setting, and there should not be. You set a **height**;
## the slope is the gradient of the height field, so which way is up falls out
## of the numbers rather than being declared. Positive peak_height makes a hill,
## negative makes a hollow or a dry valley, and the falloff decides whether it
## is a gentle swell or a knoll with steep sides.
##
## The polygon is the *top*, not the outline. Ground inside it reaches the full
## peak; ground outside falls away over `falloff` px. So drag a small polygon
## with a long falloff for a rounded down, or a large polygon with a short
## falloff for a plateau with an abrupt edge.
##
## Whether the slope it produces counts as an impassable cliff is not decided
## here - LevelRoot recomputes the gradient after every height brush and marks
## anything over LandscapeStage.CLIFF_SLOPE. Steepen a hill far enough and it
## becomes a cliff on its own, which is the behaviour you want.

@export_range(-200.0, 300.0, 1.0) var peak_height: float = 60.0:
	set(value):
		peak_height = value
		request_rebuild()
## Distance over which the ground returns to what it was outside the polygon.
@export_range(0.0, 900.0, 5.0) var falloff: float = 220.0:
	set(value):
		falloff = value
		request_rebuild()
## 1 = smooth shoulder, higher = flatter top with a sharper break of slope.
@export_range(0.4, 4.0, 0.1) var falloff_shape: float = 1.0:
	set(value):
		falloff_shape = value
		request_rebuild()

@export_group("Roughness")
## Broken ground on the slope. 0 is a smooth mound, higher gives crags.
@export_range(0.0, 120.0, 1.0) var roughness: float = 22.0:
	set(value):
		roughness = value
		request_rebuild()
@export_range(0.0005, 0.02, 0.0005) var roughness_frequency: float = 0.004:
	set(value):
		roughness_frequency = value
		request_rebuild()

@export_group("Water")
## Keep the hill off the valley floor. Ground within this distance of a river
## centreline is left alone, feathering in beyond it. Set 0 to ignore water.
##
## Without this a hill dropped across the river dams it, and the level stops
## having a navigable corridor.
@export_range(0.0, 600.0, 10.0) var keep_clear_of_water: float = 160.0:
	set(value):
		keep_clear_of_water = value
		request_rebuild()


func affects_height() -> bool:
	return true


func apply(world: WorldData) -> void:
	var outline := polygon_points()
	if outline.size() < 3:
		world.note("hills", "%s has no Polygon2D; nothing raised" % name)
		return

	var noise := FastNoiseLite.new()
	noise.seed = hash(outline) & 0x7FFFFFFF
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise.frequency = roughness_frequency
	noise.fractal_octaves = 4

	# Lambdas capture by value, so the peak has to live somewhere shared. An
	# Array is a reference; a float is not.
	var peak := [0.0]

	var raised := for_each_cell_near(world, outline, falloff + 8.0,
		func(cx: int, cy: int, centre: Vector2) -> bool:
			var inside := Geometry2D.is_point_in_polygon(centre, outline)
			var d := 0.0 if inside else _distance_to_outline(centre, outline)
			if d > falloff:
				return false

			# 1 on the top, easing to 0 at the foot.
			var t := 1.0 if falloff <= 0.0 else 1.0 - (d / falloff)
			var weight: float = pow(smoothstep(0.0, 1.0, t), falloff_shape)

			if keep_clear_of_water > 0.0:
				var water := world.river_distance[world.idx(cx, cy)]
				weight *= smoothstep(0.0, keep_clear_of_water, water)

			if weight <= 0.001:
				return false

			var crag := (noise.get_noise_2dv(centre) * 0.5 + 0.5) * roughness
			var lift := (peak_height + crag) * weight
			world.height[world.idx(cx, cy)] += lift
			peak[0] = maxf(peak[0], lift)
			return true)

	world.note("hills", "%s reshaped %d cells, peak %+.0f" % [name, raised, peak[0]])


static func _distance_to_outline(point: Vector2, outline: PackedVector2Array) -> float:
	var best := INF
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		best = minf(best, WorldData.distance_to_segment(point, a, b))
	return best


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if not has_polygon():
		warnings.append("HillBrush needs a Polygon2D child to define the high ground.")
	return warnings
