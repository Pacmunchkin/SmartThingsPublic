class_name WorldData
extends RefCounted

## Everything the five generation stages read and write.
##
## The world is a raster of square cells plus a handful of vector features
## (the river's centreline, the roads, the village sites). Stages run in order
## and each one may only add to what the previous ones established - the river
## is never moved to suit the hills, because the hills are generated knowing
## where the river already is.

const FOREST := 1
const RIVER := 2
const BANK := 4      ## Shingle and mud inside the river's influence, tree-free.
const CLIFF := 8     ## Too steep to walk.
const VILLAGE := 16
const ROAD := 32
const FIELD := 64    ## Cleared and worked ground around a village.
const FORD := 128    ## The river is shallow and narrow enough to cross here.

var size_px: Vector2i = Vector2i(1080, 1920)
var cell: int = 6
var cols: int = 180
var rows: int = 320
var rng := RandomNumberGenerator.new()

## Per-cell fields. All sized cols * rows.
var height := PackedFloat32Array()        ## Metres above the river mouth.
var slope := PackedFloat32Array()         ## Rise over run, 0 = flat.
var water_depth := PackedFloat32Array()   ## 0 on land, >0 in the channel.
var river_distance := PackedFloat32Array()## Pixels to the river centreline.
var flags := PackedByteArray()

## Vector features.
var river_points := PackedVector2Array()
var river_widths := PackedFloat32Array()
var fords: Array[Vector2] = []
var villages: Array[Dictionary] = []      ## {position, radius, score, name}
var roads: Array[PackedVector2Array] = []

## Forest instances, parallel arrays.
var tree_positions := PackedVector2Array()
var tree_scales := PackedFloat32Array()
var tree_rotations := PackedFloat32Array()
var tree_kinds := PackedByteArray()       ## 0 oak, 1 ash, 2 thorn/scrub

var stage_log: Array[String] = []


func configure(map_size: Vector2i, cell_size: int, world_seed: int) -> void:
	size_px = map_size
	cell = maxi(cell_size, 1)
	cols = int(ceil(float(size_px.x) / float(cell)))
	rows = int(ceil(float(size_px.y) / float(cell)))
	rng.seed = world_seed
	var count := cols * rows
	height.resize(count)
	slope.resize(count)
	water_depth.resize(count)
	river_distance.resize(count)
	flags.resize(count)
	height.fill(0.0)
	slope.fill(0.0)
	water_depth.fill(0.0)
	river_distance.fill(1.0e9)
	for i in count:
		flags[i] = 0


func idx(cx: int, cy: int) -> int:
	return cy * cols + cx


func in_bounds(cx: int, cy: int) -> bool:
	return cx >= 0 and cy >= 0 and cx < cols and cy < rows


func cell_centre(cx: int, cy: int) -> Vector2:
	return Vector2((float(cx) + 0.5) * cell, (float(cy) + 0.5) * cell)


func cell_at(world_pos: Vector2) -> Vector2i:
	return Vector2i(clampi(int(world_pos.x / cell), 0, cols - 1),
		clampi(int(world_pos.y / cell), 0, rows - 1))


func has_flag(cx: int, cy: int, flag: int) -> bool:
	return in_bounds(cx, cy) and (flags[idx(cx, cy)] & flag) != 0


func set_flag(cx: int, cy: int, flag: int) -> void:
	if in_bounds(cx, cy):
		flags[idx(cx, cy)] |= flag


func clear_flag(cx: int, cy: int, flag: int) -> void:
	if in_bounds(cx, cy):
		flags[idx(cx, cy)] &= ~flag


func height_at(world_pos: Vector2) -> float:
	return _sample(height, world_pos)


func slope_at(world_pos: Vector2) -> float:
	return _sample(slope, world_pos)


func river_distance_at(world_pos: Vector2) -> float:
	return _sample(river_distance, world_pos)


## Bilinear sample of a cell field at a world position.
func _sample(field: PackedFloat32Array, world_pos: Vector2) -> float:
	var fx := world_pos.x / float(cell) - 0.5
	var fy := world_pos.y / float(cell) - 0.5
	var x0 := clampi(int(floor(fx)), 0, cols - 1)
	var y0 := clampi(int(floor(fy)), 0, rows - 1)
	var x1 := clampi(x0 + 1, 0, cols - 1)
	var y1 := clampi(y0 + 1, 0, rows - 1)
	var tx := clampf(fx - float(x0), 0.0, 1.0)
	var ty := clampf(fy - float(y0), 0.0, 1.0)
	var top: float = lerpf(field[idx(x0, y0)], field[idx(x1, y0)], tx)
	var bottom: float = lerpf(field[idx(x0, y1)], field[idx(x1, y1)], tx)
	return lerpf(top, bottom, ty)


## Min and max of a field, for normalising into a texture.
func field_range(field: PackedFloat32Array) -> Vector2:
	var lo := INF
	var hi := -INF
	for value in field:
		lo = minf(lo, value)
		hi = maxf(hi, value)
	if not is_finite(lo) or not is_finite(hi) or is_equal_approx(lo, hi):
		return Vector2(0.0, 1.0)
	return Vector2(lo, hi)


## Distance from a point to a polyline segment, used by several stages.
static func distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_sq := ab.length_squared()
	if length_sq < 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / length_sq, 0.0, 1.0)
	return point.distance_to(a + ab * t)


func note(stage: String, message: String) -> void:
	stage_log.append("%s: %s" % [stage, message])
