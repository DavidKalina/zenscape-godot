extends SceneTree
## Capture the real entry point without consulting or changing the player's library.
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440,900)
	var scene = load("res://studies/diorama.tscn").instantiate()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): scene.title_seed = int(args[0])
	scene.library_path = "/private/tmp/zenscape-title-capture"
	scene.recent_file = "/private/tmp/zenscape-title-capture/no-recent.cfg"
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	await create_timer(5.0).timeout
	await RenderingServer.frame_post_draw
	var destination := ProjectSettings.globalize_path("res://docs/visual-lab/title-screen/godot.png")
	root.get_texture().get_image().save_png(destination)
	print("TITLE CAPTURE ",destination)
	scene.free()
	quit()
