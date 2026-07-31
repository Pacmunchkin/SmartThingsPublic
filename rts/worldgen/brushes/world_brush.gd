@tool
class_name WorldBrush
extends Node2D

## Base class for anything that paints into the level's shared WorldData.
##
## A hand-authored level is a tree of these. LevelRoot walks its descendants in
## tree order and calls apply() on each, so **the scene tree is the layer
## stack**: a brush paints over whatever the brushes above it already did.
## Drag a node up or down and the level changes accordingly.
##
## Brushes never draw anything. They only write cells and trees into WorldData;
## the terrain shader, the tree MultiMesh and WorldSampler all read the finished
## grid afterwards and have no idea which brushes produced it. That is what lets
## the same renderer serve a hand-built level and a fully generated one.
##
## To write a new brush:
##   1. extend WorldBrush,
##   2. override apply(),
##   3. override affects_height() if you touch WorldData.height.
## Shape helpers below read an optional Polygon2D or Path2D child, so the
## footprint is something you drag in the editor rather than a number you type.

## Unticking is a lot more useful than deleting while you are laying a level
## out - it leaves the node, its shape and its settings in place.
@export var enabled: bool = true:
	set(value):
		enabled = value
		request_rebuild()

## Shown in the build log so a level's history reads like the generator's.
@export var note: String = ""


## Paint into the world. Override this.
func apply(_world: WorldData) -> void:
	pass


## True if this brush writes WorldData.height. LevelRoot recomputes the slope
## and cliff fields after any brush that does, so the next brush down the tree
## sees a consistent gradient.
func affects_height() -> bool:
	return false


## Ask the owning level to rebuild. Safe to call from a setter during scene
## load, when there is no LevelRoot yet.
func request_rebuild() -> void:
	var node := get_parent()
	while node != null:
		if node.has_method(&"request_rebuild"):
			node.call(&"request_rebuild")
			return
		node = node.get_parent()


# --- shape helpers ----------------------------------------------------------

## The first Polygon2D child, in world coordinates. Empty if there is none,
## which every brush treats as "the whole map".
func polygon_points() -> PackedVector2Array:
	var polygon := _first_child_of_type("Polygon2D") as Polygon2D
	if polygon == null:
		return PackedVector2Array()
	var points := PackedVector2Array()
	for point in polygon.polygon:
		points.append(polygon.to_global(point))
	return points


## The first Path2D child's curve, tessellated and in world coordinates.
func curve_points(max_stages: int = 5, tolerance: float = 2.0) -> PackedVector2Array:
	var path := _first_child_of_type("Path2D") as Path2D
	if path == null or path.curve == null or path.curve.point_count < 2:
		return PackedVector2Array()
	var points := PackedVector2Array()
	for point in path.curve.tessellate(max_stages, tolerance):
		points.append(path.to_global(point))
	return points


func has_polygon() -> bool:
	return _first_child_of_type("Polygon2D") != null


func has_curve() -> bool:
	var path := _first_child_of_type("Path2D") as Path2D
	return path != null and path.curve != null and path.curve.point_count >= 2


func _first_child_of_type(type_name: String) -> Node:
	for child in get_children():
		if child.is_class(type_name):
			return child
	return null


## Point-in-footprint test. With no Polygon2D child this is the whole map, so a
## brush dropped in with no shape does something visible rather than nothing.
func contains_point(world: WorldData, point: Vector2,
		points: PackedVector2Array) -> bool:
	if points.is_empty():
		return point.x >= 0.0 and point.y >= 0.0 \
			and point.x <= float(world.size_px.x) and point.y <= float(world.size_px.y)
	return Geometry2D.is_point_in_polygon(point, points)


## Distance from a point to a polyline, and -1 when the line is degenerate.
static func distance_to_polyline(point: Vector2, line: PackedVector2Array) -> float:
	if line.size() < 2:
		return -1.0
	var best := INF
	for i in range(line.size() - 1):
		best = minf(best, WorldData.distance_to_segment(point, line[i], line[i + 1]))
	return best


## Which side of a polyline a point falls on: +1 right of travel, -1 left.
## This is how a scarp knows its steep face from its dip slope, and how any
## future one-sided feature (a ditch's spoil bank, a wall's fighting step)
## can tell inside from outside without the author labelling it.
static func side_of_polyline(point: Vector2, line: PackedVector2Array) -> float:
	if line.size() < 2:
		return 0.0
	var best := INF
	var side := 0.0
	for i in range(line.size() - 1):
		var a := line[i]
		var b := line[i + 1]
		var d := WorldData.distance_to_segment(point, a, b)
		if d >= best:
			continue
		best = d
		var tangent := b - a
		side = signf(tangent.cross(point - a))
	return side if side != 0.0 else 1.0


# --- painting helpers -------------------------------------------------------

## Remove every tree the test accepts, and refresh the canopy flags.
func clear_trees(world: WorldData, should_clear: Callable) -> int:
	var removed := ForestStage.clear_where(world, should_clear)
	ForestStage.refresh_forest_flags(world)
	return removed


## Run a callback over every cell whose centre lies within `margin` of the
## brush's footprint bounding box, and return how many the callback reported it
## touched. Saves every height brush writing the same bounds-clipped double loop.
##
## The callback returns true when it changed the cell. It has to be a return
## value rather than a counter the callback increments, because GDScript
## lambdas capture by value - a `count += 1` inside one updates a copy and the
## caller sees zero, which makes a brush that is working look like a brush that
## is not.
func for_each_cell_near(world: WorldData, points: PackedVector2Array,
		margin: float, callback: Callable) -> int:
	var min_x := 0
	var min_y := 0
	var max_x := world.cols - 1
	var max_y := world.rows - 1
	if not points.is_empty():
		var lo := points[0]
		var hi := points[0]
		for point in points:
			lo = lo.min(point)
			hi = hi.max(point)
		min_x = maxi(int((lo.x - margin) / world.cell), 0)
		min_y = maxi(int((lo.y - margin) / world.cell), 0)
		max_x = mini(int((hi.x + margin) / world.cell) + 1, world.cols - 1)
		max_y = mini(int((hi.y + margin) / world.cell) + 1, world.rows - 1)
	var touched := 0
	for cy in range(min_y, max_y + 1):
		for cx in range(min_x, max_x + 1):
			if callback.call(cx, cy, world.cell_centre(cx, cy)):
				touched += 1
	return touched


# --- rebuild detection ------------------------------------------------------

## A cheap value that changes whenever anything about this brush changes.
## LevelRoot polls it in the editor so dragging a curve handle rebuilds the
## level, without every brush having to wire up change signals by hand.
func fingerprint() -> int:
	var values: Array = [get_class(), enabled, global_position, rotation, scale]
	for property in get_property_list():
		if (property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		if property["type"] == TYPE_OBJECT:
			continue
		values.append(get(property["name"]))
	values.append(polygon_points())
	values.append(curve_points())
	return hash(values)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var parent_is_level := false
	var node := get_parent()
	while node != null:
		if node.has_method(&"request_rebuild"):
			parent_is_level = true
			break
		node = node.get_parent()
	if not parent_is_level:
		warnings.append("A WorldBrush only does anything under a LevelRoot.")
	return warnings
