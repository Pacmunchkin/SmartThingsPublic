@tool
class_name ScarpBrush
extends WorldBrush

## A step in the ground along a Path2D child: high on one side, low on the
## other. Valley walls, escarpments, terrace edges, the lip of a plateau.
##
## **This is the brush that answers "which part is uphill".** A curve on its own
## cannot say - it is a line, and a line has no up. What it does have is two
## sides, and that is enough: set `height_left` and `height_right` and the
## ground steps between them as you cross the line.
##
## Left and right are relative to the direction the curve is drawn, the same
## convention as walking it from first point to last. If you get them the wrong
## way round, either swap the two numbers or reverse the curve - both work, and
## the first is quicker.
##
## The transition happens over `run` px either side. A short run is a cliff
## (and LevelRoot will mark it impassable once the gradient passes
## LandscapeStage.CLIFF_SLOPE); a long run is a hillside you can walk up.
## Nothing here decides which - it is the gradient that decides, which is the
## same rule everywhere else in the terrain.

@export_range(-200.0, 300.0, 1.0) var height_left: float = 70.0:
	set(value):
		height_left = value
		request_rebuild()
@export_range(-200.0, 300.0, 1.0) var height_right: float = 0.0:
	set(value):
		height_right = value
		request_rebuild()
## Horizontal distance the step is spread over, each side of the line.
## Small = cliff, large = slope.
@export_range(5.0, 600.0, 5.0) var run: float = 120.0:
	set(value):
		run = value
		request_rebuild()
## How far from the line the scarp still has any effect. Beyond this it fades
## out, so an escarpment does not silently re-level the whole map.
@export_range(50.0, 1500.0, 10.0) var influence: float = 620.0:
	set(value):
		influence = value
		request_rebuild()

@export_group("Roughness")
@export_range(0.0, 120.0, 1.0) var roughness: float = 18.0:
	set(value):
		roughness = value
		request_rebuild()
@export_range(0.0005, 0.02, 0.0005) var roughness_frequency: float = 0.005:
	set(value):
		roughness_frequency = value
		request_rebuild()

@export_group("Water")
## Leave the valley floor alone within this distance of a river centreline.
@export_range(0.0, 600.0, 10.0) var keep_clear_of_water: float = 120.0:
	set(value):
		keep_clear_of_water = value
		request_rebuild()


func affects_height() -> bool:
	return true


func apply(world: WorldData) -> void:
	var line := curve_points()
	if line.size() < 2:
		world.note("hills", "%s has no Path2D curve; nothing stepped" % name)
		return

	var noise := FastNoiseLite.new()
	noise.seed = hash(line) & 0x7FFFFFFF
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = roughness_frequency
	noise.fractal_octaves = 3

	var changed := for_each_cell_near(world, line, influence + 8.0,
		func(cx: int, cy: int, centre: Vector2) -> bool:
			var d := distance_to_polyline(centre, line)
			if d < 0.0 or d > influence:
				return false

			# Signed across the line: negative on the left of travel, positive
			# on the right. This is the only place the two sides differ.
			var signed := side_of_polyline(centre, line) * d
			var t: float = smoothstep(-run, run, signed)
			var step := lerpf(height_left, height_right, t)

			# Fade the whole step out toward the influence limit so the far side
			# of the map is not quietly raised or lowered.
			var reach: float = 1.0 - smoothstep(influence * 0.55, influence, d)
			var weight := reach

			if keep_clear_of_water > 0.0:
				var water := world.river_distance[world.idx(cx, cy)]
				weight *= smoothstep(0.0, keep_clear_of_water, water)

			if weight <= 0.001:
				return false

			# Broken ground is strongest on the face, not on the flats above
			# and below it - that is where a scarp actually crumbles.
			var face := 1.0 - absf(t * 2.0 - 1.0)
			var crag := noise.get_noise_2dv(centre) * roughness * face

			world.height[world.idx(cx, cy)] += (step + crag) * weight
			return true)

	world.note("hills", "%s stepped %d cells, %+.0f left to %+.0f right over %.0f px"
		% [name, changed, height_left, height_right, run * 2.0])


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if not has_curve():
		warnings.append("ScarpBrush needs a Path2D child with at least two points.")
	if is_equal_approx(height_left, height_right):
		warnings.append("Both sides are the same height, so this scarp is flat ground.")
	return warnings
