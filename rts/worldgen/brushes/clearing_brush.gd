@tool
class_name ClearingBrush
extends WorldBrush

## Fells the wood inside a Polygon2D child.
##
## The plain "take the trees out of here" brush - a meadow, a burnt patch, a
## battlefield someone cleared for a reason the level never explains. For a
## settlement use SettlementBrush instead; it clears *and* levels the ground,
## works the fields and leaves a capture point behind.
##
## The feather is what stops a clearing reading as a cookie cutter: inside the
## polygon everything goes, and for `feather` px beyond it the wood thins out
## with distance rather than stopping at a line.

@export_range(0.0, 400.0, 5.0) var feather: float = 60.0:
	set(value):
		feather = value
		request_rebuild()
## Mark the cleared ground as worked. Changes how it renders (tilled earth with
## ridge and furrow) and gives it a little concealment in WorldSampler.
@export var mark_as_field: bool = false:
	set(value):
		mark_as_field = value
		request_rebuild()


func apply(world: WorldData) -> void:
	var outline := polygon_points()
	if outline.size() < 3:
		world.note("clearings", "%s has no Polygon2D; nothing felled" % name)
		return

	var removed := clear_trees(world, func(point: Vector2) -> bool:
		if Geometry2D.is_point_in_polygon(point, outline):
			return true
		if feather <= 0.0:
			return false
		var d := HillBrush._distance_to_outline(point, outline)
		if d > feather:
			return false
		# Thin with distance rather than ending at a hard edge.
		var t := d / feather
		return world.rng.randf() > t * t)

	if mark_as_field:
		for_each_cell_near(world, outline, 4.0,
			func(cx: int, cy: int, centre: Vector2) -> bool:
				if not Geometry2D.is_point_in_polygon(centre, outline):
					return false
				world.set_flag(cx, cy, WorldData.FIELD)
				return true)

	world.note("clearings", "%s felled %d trees%s"
		% [name, removed, " and marked them worked" if mark_as_field else ""])


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if not has_polygon():
		warnings.append("ClearingBrush needs a Polygon2D child.")
	return warnings
