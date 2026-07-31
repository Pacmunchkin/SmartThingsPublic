extends SceneTree

## Renders the generated world to a PNG so the map can be looked at without
## opening the editor. Also handy in CI: a seed that used to produce a valley
## and now produces a lake is a regression you want to see, not read about.
##
## Usage:
##   godot --path rts --rendering-driver opengl3 --resolution 1080x1920 \
##         --script tools/capture_preview.gd -- --seed 12345 --out preview.png
##
## Runs under xvfb-run on a headless box; needs a GL context, so plain
## --headless will not do.

const DEFAULT_SCENE := "res://worldgen/generated_world.tscn"
const WARMUP_FRAMES := 12


func _initialize() -> void:
	var options := _parse_arguments()
	var path: String = options.get("scene", DEFAULT_SCENE)
	var scene: Node = load(path).instantiate()

	# Works for either kind of level: the procedural generator or a
	# brush-authored LevelRoot. Both expose map_size and both build in _ready.
	var generator := scene as WorldGenerator
	if generator != null:
		generator.verbose = true
		if options.has("seed"):
			generator.world_seed = int(options["seed"])
	var level := scene as LevelRoot
	if level != null:
		level.verbose = true
		if options.has("seed"):
			level.level_seed = int(options["seed"])
	root.add_child(scene)

	# Frame the whole map rather than whatever the scene's camera was left on.
	var camera := scene.get_node_or_null("Camera") as Camera2D
	var extent := Vector2(1080, 1920)
	if generator != null:
		extent = Vector2(generator.map_size)
	elif level != null:
		extent = Vector2(level.map_size)
	if camera != null:
		camera.position = extent * 0.5
		camera.zoom = Vector2.ONE

	_capture.call_deferred(options.get("out", "preview.png"))


func _capture(path: String) -> void:
	# Let the shaders compile and the first frames settle before grabbing.
	for _i in WARMUP_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw

	var image := root.get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		printerr("could not write %s (error %d)" % [path, error])
	else:
		print("wrote %s (%d x %d)" % [path, image.get_width(), image.get_height()])
	quit(0 if error == OK else 1)


func _parse_arguments() -> Dictionary:
	var options := {}
	var arguments := OS.get_cmdline_user_args()
	var i := 0
	while i < arguments.size():
		var key := String(arguments[i]).lstrip("-")
		if i + 1 < arguments.size():
			options[key] = arguments[i + 1]
			i += 2
		else:
			i += 1
	return options
