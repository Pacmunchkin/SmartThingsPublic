@tool
class_name LevelRoot
extends Node2D

## The root of a hand-authored level.
##
## Walks its descendants in tree order and lets each WorldBrush paint into one
## shared WorldData, then hands the finished grid to the same renderer and the
## same WorldSampler the procedural generator uses. Nothing downstream knows or
## cares that a person placed these features rather than an algorithm.
##
## **Tree order is layer order.** A brush paints over whatever the brushes above
## it already did, so moving a node up or down in the Scene dock changes the
## level. Group brushes under plain Node2Ds to keep the dock tidy - the walk is
## depth-first, so a group behaves exactly like its contents inlined.
##
## The slope and cliff fields are recomputed after every brush that reports
## affects_height(), so a road laid after a hill sees the hill's real gradient
## and routes around it rather than through it.

signal level_built(world: WorldData)

@export var map_size: Vector2i = Vector2i(1080, 1920):
	set(value):
		map_size = value
		request_rebuild()
## World grid resolution, px per cell. Smaller is sharper and slower.
@export var cell_size: int = 6:
	set(value):
		cell_size = maxi(value, 2)
		request_rebuild()
## Seeds the scatter inside brushes. Change it to reroll the noise without
## moving anything you placed.
@export var level_seed: int = 1:
	set(value):
		level_seed = value
		request_rebuild()

@export_group("Editing")
## Rebuild automatically when a brush is moved or edited. Turn off on a heavy
## level and use the Rebuild tick instead.
@export var live_rebuild: bool = true
## Seconds to wait after the last change before rebuilding, so dragging a curve
## handle does not queue one rebuild per frame.
@export_range(0.05, 2.0, 0.05) var rebuild_delay: float = 0.35
## Tick to rebuild now; it resets itself.
@export var rebuild: bool = false:
	set(value):
		if value:
			_build_now()
		rebuild = false
@export var verbose: bool = true

@export_group("Nodes")
@export var terrain_rect_path: NodePath = ^"Terrain"
@export var trees_path: NodePath = ^"Trees"
@export var sectors_path: NodePath = ^"Sectors"
@export var sampler_path: NodePath = ^"WorldSampler"

var world: WorldData

var _dirty := false
var _countdown := 0.0
var _fingerprint := 0


func _ready() -> void:
	set_process(true)
	_build_now()


func _process(delta: float) -> void:
	if _dirty:
		_countdown -= delta
		if _countdown <= 0.0:
			_build_now()
		return
	# Polling beats wiring change signals into every brush: Polygon2D has no
	# "polygon changed" signal at all, so there is nothing to connect to.
	if Engine.is_editor_hint() and live_rebuild:
		var current := _tree_fingerprint()
		if current != _fingerprint:
			_fingerprint = current
			request_rebuild()


## Any brush calls this when something about it changes.
func request_rebuild() -> void:
	if not is_inside_tree():
		return
	if not live_rebuild and not Engine.is_editor_hint():
		return
	_dirty = true
	_countdown = rebuild_delay


func _build_now() -> void:
	_dirty = false
	if not is_inside_tree():
		return
	build()


func build() -> void:
	var started := Time.get_ticks_msec()

	world = WorldData.new()
	world.configure(map_size, cell_size, level_seed)

	var brushes := collect_brushes()
	var applied := 0
	for brush in brushes:
		if not brush.enabled:
			continue
		brush.apply(world)
		applied += 1
		if brush.affects_height():
			# The next brush down must see a consistent gradient, and whether
			# what this one built counts as a cliff is decided here rather than
			# by the brush - one rule for every piece of high ground.
			LandscapeStage.recompute_slope(world)
			_remark_cliffs()
		if not brush.note.is_empty():
			world.note("design", "%s: %s" % [brush.name, brush.note])

	# Trees may have been felled without the flags being refreshed by a brush
	# that only writes height; make the canopy field honest before rendering.
	ForestStage.refresh_forest_flags(world)
	LandscapeStage.recompute_slope(world)
	_remark_cliffs()

	WorldRenderer.apply_terrain(get_node_or_null(terrain_rect_path) as ColorRect,
		world, map_size)
	WorldRenderer.apply_trees(get_node_or_null(trees_path) as MultiMeshInstance2D,
		world, level_seed)
	WorldRenderer.apply_sectors(get_node_or_null(sectors_path), world,
		_editor_owner())

	# Assign the property rather than calling bind_world(). During the editor's
	# first import pass an @tool script can run before every sibling script is
	# registered, and the placeholder that stands in for WorldSampler answers
	# has_method() truthfully but cannot actually dispatch the call. set() on a
	# placeholder is a no-op, and the next rebuild binds it for real.
	var sampler := get_node_or_null(sampler_path)
	if sampler != null:
		sampler.set(&"world", world)

	_fingerprint = _tree_fingerprint()

	var elapsed := Time.get_ticks_msec() - started
	world.note("build", "%d brush(es) in %d ms" % [applied, elapsed])
	if verbose:
		print_rich("[b]%s[/b]" % name)
		for line in world.stage_log:
			print("  " + line)
	level_built.emit(world)


## Depth-first, so a brush inside a grouping Node2D paints in the position the
## Scene dock shows it in.
func collect_brushes(from: Node = null) -> Array[WorldBrush]:
	var found: Array[WorldBrush] = []
	var parent := from if from != null else self
	for child in parent.get_children():
		if child is WorldBrush:
			found.append(child)
		found.append_array(collect_brushes(child))
	return found


func _remark_cliffs() -> void:
	for i in world.slope.size():
		if world.slope[i] >= LandscapeStage.CLIFF_SLOPE \
				and (world.flags[i] & WorldData.RIVER) == 0:
			world.flags[i] |= WorldData.CLIFF
		else:
			world.flags[i] &= ~WorldData.CLIFF


func _tree_fingerprint() -> int:
	var values: Array = [map_size, cell_size, level_seed]
	for brush in collect_brushes():
		values.append(brush.fingerprint())
	return hash(values)


func _editor_owner() -> Node:
	if not Engine.is_editor_hint() or get_tree() == null:
		return null
	return get_tree().edited_scene_root


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if collect_brushes().is_empty():
		warnings.append("This level has no WorldBrush children, so nothing is painted.")
	if get_node_or_null(terrain_rect_path) == null:
		warnings.append("No ColorRect at terrain_rect_path; the ground will not draw.")
	return warnings
