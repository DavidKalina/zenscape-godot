extends SceneTree
const Presets = preload("res://scripts/scene_look_presets.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	create_timer(120).timeout.connect(func() -> void: push_error("Preset capture timed out"); quit(2))
	DirAccess.make_dir_recursive_absolute("res://assets/scene_looks")
	DirAccess.make_dir_recursive_absolute("res://docs/scene-look/presets")
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene._paused = true
	scene._auto_orbit = false
	scene._ui.hide()
	var only := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--preset="): only = argument.trim_prefix("--preset=")
	if "--ui-only" not in OS.get_cmdline_user_args():
		for id in Presets.PRESETS:
			if only != "" and id != only: continue
			Presets.apply(scene,id)
			var image := await shot()
			image.save_png("res://docs/scene-look/presets/"+id+".png")
			image.resize(480,320,Image.INTERPOLATE_LANCZOS)
			image.save_png("res://assets/scene_looks/"+id+".png")
			print("Captured ",id)
	else:
		Presets.apply(scene,"golden_meadow")
		scene._chunk_editor.set_active(true)
		scene.edit_scene_look()
		(await shot()).save_png("res://docs/scene-look/presets/gallery.png")
		root.size = Vector2i(960,640)
		(await shot()).save_png("res://docs/scene-look/presets/gallery-small.png")
	scene.free()
	print("CURATED LOOK CAPTURES COMPLETE")
	quit()
func shot() -> Image:
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
