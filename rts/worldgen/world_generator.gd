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

const TREE_QUAD_SIZE := 44.0

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

var _terrain_material: ShaderMaterial
var _tree_material: ShaderMaterial
var _tree_atlas: ImageTexture
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

func _apply_terrain() -> void:
	var rect := get_node_or_null(terrain_rect_path) as ColorRect
	if rect == null:
		return
	rect.size = Vector2(map_size)
	rect.position = Vector2.ZERO

	if _terrain_material == null:
		_terrain_material = ShaderMaterial.new()
		_terrain_material.shader = load("res://worldgen/shaders/terrain.gdshader")
	rect.material = _terrain_material

	_terrain_material.set_shader_parameter("field_map", TextureBaker.bake_field(world))
	_terrain_material.set_shader_parameter("cover_map", TextureBaker.bake_cover(world))
	_terrain_material.set_shader_parameter("map_size", Vector2(map_size))
	_terrain_material.set_shader_parameter("grid_size", Vector2(world.cols, world.rows))


func _apply_trees() -> void:
	var node := get_node_or_null(trees_path) as MultiMeshInstance2D
	if node == null:
		return

	if _tree_atlas == null:
		_tree_atlas = TextureBaker.bake_tree_atlas()
	if _tree_material == null:
		_tree_material = ShaderMaterial.new()
		_tree_material.shader = load("res://worldgen/shaders/tree.gdshader")
	_tree_material.set_shader_parameter("atlas", _tree_atlas)
	_tree_material.set_shader_parameter("frames", 3.0)
	node.material = _tree_material
	# The atlas is sampled by the shader; the instance texture only has to
	# supply UVs for the quad.
	node.texture = _tree_atlas

	var quad := QuadMesh.new()
	quad.size = Vector2(TREE_QUAD_SIZE, TREE_QUAD_SIZE)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = quad

	var count := world.tree_positions.size()
	multimesh.instance_count = count
	multimesh.visible_instance_count = count

	var jitter := RandomNumberGenerator.new()
	jitter.seed = world_seed ^ 0x5EED

	for i in count:
		var position := world.tree_positions[i]
		var scale := world.tree_scales[i]
		var transform := Transform2D(world.tree_rotations[i], Vector2.ONE * scale,
			0.0, position)
		multimesh.set_instance_transform_2d(i, transform)

		# Darker in the depths of the wood, and a touch cooler in the shade of
		# the valley, so the canopy has some internal depth.
		var c := world.cell_at(position)
		var neighbours := _canopy_neighbours(c)
		var depth := clampf(float(neighbours) / 8.0, 0.0, 1.0)
		var tint := lerpf(1.06, 0.72, depth)
		multimesh.set_instance_color(i, Color(tint, tint * 1.02, tint * 0.94, 1.0))

		multimesh.set_instance_custom_data(i, Color(
			float(world.tree_kinds[i]),
			jitter.randf(),
			jitter.randf(),
			0.0))

	node.multimesh = multimesh


func _canopy_neighbours(c: Vector2i) -> int:
	var count := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if world.has_flag(c.x + dx, c.y + dy, WorldData.FOREST):
				count += 1
	return count


## Villages become the map's capture points, so the mission layer has
## something to fight over without anyone hand-placing it.
func _apply_sectors() -> void:
	var parent := get_node_or_null(sectors_path)
	if parent == null:
		return
	for child in parent.get_children():
		child.queue_free()

	for i in world.villages.size():
		var village: Dictionary = world.villages[i]
		var sector := TacticalSector.new()
		sector.name = "Sector%s" % String(village["name"]).replace(" ", "")
		sector.sector_id = StringName("sector_%d" % i)
		sector.display_name = village["name"]
		sector.owner_faction = TacticalSector.Faction.NEUTRAL
		sector.capture_seconds = 20.0
		sector.reinforcement_bonus = 0.5
		sector.mission_critical = bool(village["on_ford"])
		sector.collision_layer = 4
		sector.collision_mask = 48
		sector.position = village["position"]

		var shape := CollisionPolygon2D.new()
		var radius: float = village["radius"] * 1.15
		var points := PackedVector2Array()
		for step in 12:
			var angle := TAU * float(step) / 12.0
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		shape.polygon = points
		sector.add_child(shape)

		parent.add_child(sector)
		if Engine.is_editor_hint() and get_tree() != null:
			var root := get_tree().edited_scene_root
			if root != null:
				sector.owner = root
				shape.owner = root


func _apply_sampler() -> void:
	var sampler := get_node_or_null(sampler_path) as WorldSampler
	if sampler != null:
		sampler.bind(world)
