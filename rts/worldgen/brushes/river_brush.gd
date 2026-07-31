@tool
class_name RiverBrush
extends WorldBrush

## Cuts a watercourse along a Path2D child, and clears the trees out of it.
##
## Add a Path2D under this node and drag its handles: that curve is the
## centreline. Width is interpolated from source to mouth along the curve, so
## a stream that starts as a beck and ends as a river needs two numbers, not a
## per-point table.
##
## The channel is also what the ground reads: LandscapeStage's valley profile
## and VillageStage's water-access score both work off distance to the nearest
## centreline, so a hill brush placed after this one will still leave the
## valley floor alone if you use its river_aware option.

@export_range(4.0, 400.0, 1.0) var source_width: float = 30.0:
	set(value):
		source_width = value
		request_rebuild()
@export_range(4.0, 400.0, 1.0) var mouth_width: float = 90.0:
	set(value):
		mouth_width = value
		request_rebuild()
## Bends the source-to-mouth interpolation. Below 1 the river widens early.
@export_range(0.25, 3.0, 0.05) var width_curve: float = 0.75:
	set(value):
		width_curve = value
		request_rebuild()
## Irregularity in the width, so the channel narrows and opens naturally.
## The narrows are also where fords get placed.
@export_range(0.0, 0.6, 0.02) var width_variation: float = 0.25:
	set(value):
		width_variation = value
		request_rebuild()
## Pick crossings automatically at the narrowest points.
@export var place_fords: bool = true:
	set(value):
		place_fords = value
		request_rebuild()
@export_range(0, 6) var ford_count: int = 2:
	set(value):
		ford_count = value
		request_rebuild()


func apply(world: WorldData) -> void:
	var points := curve_points()
	if points.size() < 2:
		world.note("river", "%s has no Path2D curve; nothing carved" % name)
		return

	var widths := _widths_along(points)

	# Append rather than replace, so a level can have a river and its tributary
	# as two brushes. The distance field takes the minimum across both.
	var first := world.river_points.is_empty()
	world.river_points.append_array(points)
	world.river_widths.append_array(widths)

	RiverStage.carve_channel(world, points, widths)
	if place_fords and ford_count > 0:
		_place_fords(world, points, widths)
	RiverStage.clear_channel(world)

	world.note("river", "%s carved %d segments, %.0f to %.0f px wide%s"
		% [name, points.size() - 1, widths[0], widths[widths.size() - 1],
		   "" if first else " (joined an existing watercourse)"])


func _widths_along(points: PackedVector2Array) -> PackedFloat32Array:
	var variation := FastNoiseLite.new()
	# Seeded from the curve itself, so a given river keeps its shape between
	# rebuilds but two different rivers do not narrow in the same places.
	variation.seed = hash(points) & 0x7FFFFFFF
	variation.noise_type = FastNoiseLite.TYPE_SIMPLEX
	variation.frequency = 0.006

	var widths := PackedFloat32Array()
	var total := 0.0
	var lengths := PackedFloat32Array()
	lengths.append(0.0)
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
		lengths.append(total)

	for i in points.size():
		var t := lengths[i] / maxf(total, 0.001)
		var width := lerpf(source_width, mouth_width, pow(t, width_curve))
		width *= 1.0 + variation.get_noise_2dv(points[i]) * width_variation
		widths.append(maxf(width, 6.0))
	return widths


## Fords go at the local narrows, spread along the length so two crossings are
## never within sight of each other.
func _place_fords(world: WorldData, points: PackedVector2Array,
		widths: PackedFloat32Array) -> void:
	var candidates: Array[Dictionary] = []
	var margin := maxi(int(points.size() * 0.08), 1)
	for i in range(margin, points.size() - margin):
		candidates.append({"width": widths[i], "point": points[i]})
	candidates.sort_custom(func(a, b): return a["width"] < b["width"])

	var separation := maxf(float(world.size_px.y) * 0.18, 200.0)
	var placed := 0
	for candidate in candidates:
		if placed >= ford_count:
			break
		var point: Vector2 = candidate["point"]
		var too_close := false
		for existing in world.fords:
			if existing.distance_to(point) < separation:
				too_close = true
				break
		if too_close:
			continue
		world.fords.append(point)
		placed += 1
		var c := world.cell_at(point)
		var radius := int(ceil(56.0 / float(world.cell)))
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if Vector2(dx, dy).length() <= float(radius):
					world.set_flag(c.x + dx, c.y + dy, WorldData.FORD)
	world.note("river", "%s set %d ford(s)" % [name, placed])


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if not has_curve():
		warnings.append("RiverBrush needs a Path2D child with at least two points.")
	return warnings
