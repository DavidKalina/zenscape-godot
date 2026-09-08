extends SceneTree
const Presets = preload("res://scripts/native_landscape_presets.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	create_timer(240).timeout.connect(func() -> void: push_error("Landscape capture timed out"); quit(2))
	DirAccess.make_dir_recursive_absolute("res://assets/landscapes")
	DirAccess.make_dir_recursive_absolute("res://docs/landscapes")
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene._paused = true
	scene._auto_orbit = false
	scene._ui.hide()
	scene.target = Vector3(0,2.0,0)
	scene.distance = 43.0
	scene.yaw = 0.35
	scene.polar = 0.80
	scene._update_camera()
	preload("res://scripts/scene_look_presets.gd").apply(scene,"alpine_morning")
	var only := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--preset="): only = argument.trim_prefix("--preset=")
	if "--ui-only" not in OS.get_cmdline_user_args():
		for id in Presets.PRESETS:
			if only != "" and id != only: continue
			await scene._chunk_editor.form_landscape(id,"",false)
			var picture := await shot()
			picture.save_png("res://docs/landscapes/"+id+".png")
			picture.resize(480,320,Image.INTERPOLATE_LANCZOS)
			picture.save_png("res://assets/landscapes/"+id+".png")
			if "--water-proof" in OS.get_cmdline_user_args():
				scene._chunk_editor.content._water.hide()
				(await shot()).save_png("res://docs/landscapes/"+id+"-dry.png")
				scene._chunk_editor.content._water.show()
			print("Captured ",id," objects=",scene._chunk_editor.data.objects.size()," pools=",scene._chunk_editor.data.ponds.size())
	else:
		await scene._chunk_editor.form_landscape("terraced_pools","",false)
		scene.edit_landscape_presets()
		(await shot()).save_png("res://docs/landscapes/gallery.png")
		root.size = Vector2i(960,640)
		(await shot()).save_png("res://docs/landscapes/gallery-small.png")
	scene.free()
	print("LANDSCAPE CAPTURES COMPLETE")
	quit()
func shot() -> Image:
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
