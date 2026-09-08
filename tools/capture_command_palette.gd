extends SceneTree
const OUTPUT := "res://docs/design/command-palette"
func _initialize() -> void: run.call_deferred()
func snap(file: String) -> void:
	for i in range(8): await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OUTPUT.path_join(file))
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size = Vector2i(1800,1200)
	var scene: Node3D = load("res://studies/nursery_preview.tscn").instantiate()
	root.add_child(scene)
	scene._paused = true
	var palette: NativeBuildPalette = scene._build_palette
	await snap("landscape.png")
	palette.open_palette()
	await snap("all.png")
	palette._browse("Cover")
	await snap("plants.png")
	palette._search.text = "pine"
	palette._refresh_results()
	await snap("search.png")
	palette.open_palette()
	palette._browse("Place")
	await snap("objects.png")
	root.size = Vector2i(960,640)
	await snap("compact.png")
	if "--film" in OS.get_cmdline_user_args():
		root.size = Vector2i(1800,1200)
		palette.close_palette()
		DirAccess.make_dir_recursive_absolute("/private/tmp/command-palette-frames")
		for frame in range(144):
			if frame == 24: palette.open_palette(); palette._browse("Cover")
			if frame == 72:
				palette._search.text = "pine"
				palette._refresh_results()
			if frame == 108: palette._activate_result()
			if frame == 124:
				scene._chunk_editor.place_at(root.get_visible_rect().size*Vector2(0.52,0.5))
			palette._animate_portraits(1.0/24.0)
			await process_frame
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_jpg("/private/tmp/command-palette-frames/%04d.jpg" % frame,0.92)
	print("Command palette capture complete")
	scene.queue_free()
	await process_frame
	quit()
