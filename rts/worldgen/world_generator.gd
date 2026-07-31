@tool
class_name WorldGenerator
extends Node2D

## Builds the level in code, in the order the design calls for:
##
##   1. Forest    - blanket the whole map in wildwood.
##   2. River     - run water down it and clear the channel.
##   3. Landscape - raise cliffs and hills around the water, leaving flats.
##   4. Villages  - decide where people would have chosen to live.
##   5. Roads     - join those places by the cheapest ways to walk.
##
## Each stage may only subtract from or build on what came before, never
## reorder it. That constraint is the whole reason the map reads as a place
## with a history rather than as four noise fields stacked on each other: the
## river explains the valley, the valley explains the villages, and the
## villages explain the roads.

signal generation_finished(world: WorldData)

@export var map_size: Vector2i = Vector2i(1080, 1920):
	set(value):
		map_size = value
		_queue_regenerate()
@export var cell_size: int = 6:
	set(value):
		cell_size = maxi(value, 2)
		_queue_regenerate()
@export var world_seed: int = 20250731:
	set(value):
		world_seed = value
		_queue_regenerate()
## Tick in the inspector to rebuild; it resets itself immediately.
@export var regenerate: bool = false:
	set(value):
		if value:
			_queue_regenerate()
		regenerate = false
@export var randomise_seed_on_play: bool = false
## Print the stage log to the output panel after each build.
@export var verbose: bool = true

@export_group("Nodes")
@export var terrain_rect_path: NodePath = ^"Terrain"
@export var trees_path: NodePath = ^"Trees"
@export var sectors_path: NodePath = ^"Sectors"
@export var sampler_path: NodePath = ^"WorldSampler"

var world: WorldData

var _pending := false


func _ready() -> void:
	if not Engine.is_editor_hint() and randomise_seed_on_play:
		world_seed = int(Time.get_unix_time_from_system()) & 0x7FFFFFFF
	generate()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_R:
		world_seed = int(Time.get_ticks_usec()) & 0x7FFFFFFF
		generate()


func _queue_regenerate() -> void:
	# Setters fire during scene load, before children exist. Defer so the
	# rebuild happens once, with a complete tree.
	if _pending or not is_inside_tree():
		return
	_pending = true
	call_deferred(&"_deferred_regenerate")


func _deferred_regenerate() -> void:
	_pending = false
	generate()


func generate() -> void:
	var started := Time.get_ticks_msec()

	world = WorldData.new()
	world.configure(map_size, cell_size, world_seed)

	ForestStage.run(world)
	RiverStage.run(world)
	LandscapeStage.run(world)
	VillageStage.run(world)
	RoadStage.run(world)

	_apply_terrain()
	_apply_trees()
	_apply_sectors()
	_apply_sampler()

	var elapsed := Time.get_ticks_msec() - started
	world.note("build", "%d ms, seed %d" % [elapsed, world_seed])
	if verbose:
		print_rich("[b]World %d[/b]" % world_seed)
		for line in world.stage_log:
			print("  " + line)
	generation_finished.emit(world)


# --- presentation -----------------------------------------------------------
# All of it lives in WorldRenderer, shared with hand-authored LevelRoot scenes.
# A generated world and a hand-built one produce the same WorldData, so they
# have no business drawing it two different ways.

func _apply_terrain() -> void:
	WorldRenderer.apply_terrain(get_node_or_null(terrain_rect_path) as ColorRect,
		world, map_size)


func _apply_trees() -> void:
	WorldRenderer.apply_trees(get_node_or_null(trees_path) as MultiMeshInstance2D,
		world, world_seed)


func _apply_sectors() -> void:
	var editor_owner: Node = null
	if Engine.is_editor_hint() and get_tree() != null:
		editor_owner = get_tree().edited_scene_root
	WorldRenderer.apply_sectors(get_node_or_null(sectors_path), world, editor_owner)


func _apply_sampler() -> void:
	# Assign the property rather than calling bind_world(). During the editor's
	# first import pass an @tool script can run before every sibling script is
	# registered, and the placeholder that stands in for WorldSampler answers
	# has_method() truthfully but cannot actually dispatch the call. set() on a
	# placeholder is a no-op, and the next rebuild binds it for real.
	var sampler := get_node_or_null(sampler_path)
	if sampler != null:
		sampler.set(&"world", world)
