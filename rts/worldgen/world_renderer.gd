class_name WorldRenderer
extends RefCounted

## Turns a finished WorldData into what you see.
##
## Deliberately knows nothing about how the world was made. The procedural
## generator and a hand-authored LevelRoot both end up with the same grid, so
## they both end up here - which is the point of keeping the brushes purely
## about data.

const TREE_QUAD_SIZE := 44.0
const TERRAIN_SHADER := "res://worldgen/shaders/terrain.gdshader"
const TREE_SHADER := "res://worldgen/shaders/tree.gdshader"

static var _tree_atlas: ImageTexture


static func apply_terrain(rect: ColorRect, world: WorldData, map_size: Vector2i) -> void:
	if rect == null:
		return
	rect.size = Vector2(map_size)
	rect.position = Vector2.ZERO

	var material := rect.material as ShaderMaterial
	if material == null or material.shader == null:
		material = ShaderMaterial.new()
		material.shader = load(TERRAIN_SHADER)
		rect.material = material

	material.set_shader_parameter("field_map", TextureBaker.bake_field(world))
	material.set_shader_parameter("cover_map", TextureBaker.bake_cover(world))
	material.set_shader_parameter("map_size", Vector2(map_size))
	material.set_shader_parameter("grid_size", Vector2(world.cols, world.rows))


static func apply_trees(node: MultiMeshInstance2D, world: WorldData, tint_seed: int) -> void:
	if node == null:
		return

	# The atlas is drawn once per run and shared by every level in the session.
	if _tree_atlas == null:
		_tree_atlas = TextureBaker.bake_tree_atlas()

	var material := node.material as ShaderMaterial
	if material == null or material.shader == null:
		material = ShaderMaterial.new()
		material.shader = load(TREE_SHADER)
		node.material = material
	material.set_shader_parameter("atlas", _tree_atlas)
	material.set_shader_parameter("frames", 3.0)
	# The shader samples the atlas itself; the instance texture only has to give
	# the quad its UVs.
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
	jitter.seed = tint_seed ^ 0x5EED

	for i in count:
		var position := world.tree_positions[i]
		var transform := Transform2D(world.tree_rotations[i],
			Vector2.ONE * world.tree_scales[i], 0.0, position)
		multimesh.set_instance_transform_2d(i, transform)

		# Darker in the depths of the wood, so the canopy has internal depth.
		var c := world.cell_at(position)
		var neighbours := 0
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if world.has_flag(c.x + dx, c.y + dy, WorldData.FOREST):
					neighbours += 1
		var tint := lerpf(1.06, 0.72, clampf(float(neighbours) / 8.0, 0.0, 1.0))
		multimesh.set_instance_color(i, Color(tint, tint * 1.02, tint * 0.94, 1.0))

		multimesh.set_instance_custom_data(i, Color(
			float(world.tree_kinds[i]), jitter.randf(), jitter.randf(), 0.0))

	node.multimesh = multimesh


## Settlements become capture points. Rebuilt from scratch each time, because
## a brush may have moved, been renamed or been switched off.
static func apply_sectors(parent: Node, world: WorldData, editor_owner: Node = null) -> void:
	if parent == null:
		return
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

	for i in world.villages.size():
		var village: Dictionary = world.villages[i]
		var sector := TacticalSector.new()
		sector.name = "Sector%s" % String(village["name"]).replace(" ", "")
		sector.sector_id = village.get("sector_id", StringName("sector_%d" % i))
		sector.display_name = village["name"]
		sector.owner_faction = village.get("owner", TacticalSector.Faction.NEUTRAL)
		sector.capture_seconds = 20.0
		sector.reinforcement_bonus = 0.5
		sector.mission_critical = bool(village.get("on_ford", false))
		sector.collision_layer = 4
		sector.collision_mask = 48
		sector.position = village["position"]

		var shape := CollisionPolygon2D.new()
		var radius: float = float(village["radius"]) * 1.15
		var points := PackedVector2Array()
		for step in 12:
			var angle := TAU * float(step) / 12.0
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		shape.polygon = points
		sector.add_child(shape)

		parent.add_child(sector)
		if editor_owner != null:
			sector.owner = editor_owner
			shape.owner = editor_owner
