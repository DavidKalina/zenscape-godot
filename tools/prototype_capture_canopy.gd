extends SceneTree
## Throwaway native canopy A/B. Frozen clock and exact camera replay.
var scene: Node3D
var output := "res://docs/fidelity/deliberate-pond/canopy"
var records: Array[Dictionary] = []
var poses: Array[Transform3D] = []
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for frame in range(36):
		await process_frame
		RenderingServer.force_draw(false)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	scene = load("res://studies/prototype_deliberate_pond.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene._paused = true
	scene.set_process(false)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	scene.study_ui.hide()
	await create_timer(3.0).timeout
	root.mode = Window.MODE_WINDOWED
	root.content_scale_factor = 1.0
	root.size = Vector2i(1600,1000)
	await create_timer(2.0).timeout
	for view in ["pond","close","backlit"]:
		scene.reset_study_camera()
		if view != "pond":
			scene.target = Vector3(-3.2,4.5,-1.8)
			scene.distance = 11.5
			scene.polar = 1.35
			if view == "backlit": scene.yaw = 3.55
		for enabled in [false,true]:
			scene.set_canopy(enabled)
			scene._process(0.0)
			await settle()
			assert(root.size == Vector2i(1600,1000))
			var label: String = view + ("-layered" if enabled else "-original")
			root.get_texture().get_image().save_png(output.path_join(label+".png"))
			records.append({"view":view,"layered":enabled,"camera":str(scene.camera.transform),"size":str(root.size),"phase":scene._celestial.phase})
			print("CANOPY CAPTURE ",label)
	if "--study-film" in OS.get_cmdline_user_args():
		scene.reset_study_camera()
		for enabled in [false,true]:
			scene.set_canopy(enabled)
			scene._process(0.0)
			await settle()
			var directory := "/tmp/canopy-film-" + ("layered" if enabled else "original")
			DirAccess.make_dir_recursive_absolute(directory)
			for frame in range(120):
				scene.yaw = 0.55+0.4*sin(float(frame)/119.0*TAU)
				scene._process(0.0)
				if not enabled: poses.append(scene.camera.transform)
				else: scene.camera.transform = poses[frame]
				scene._display_fog.update_view()
				scene._planar_water.update_views()
				await process_frame
				RenderingServer.force_draw(false)
				root.get_texture().get_image().save_jpg(directory.path_join("%04d.jpg" % frame),0.96)
				records.append({"frame":frame,"layered":enabled,"camera":str(scene.camera.transform),"size":str(root.size)})
	scene.reset_study_camera()
	scene.set_canopy(true)
	scene._process(0.0)
	scene.study_ui.show()
	await settle()
	root.get_texture().get_image().save_png(output.path_join("interactive.png"))
	FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	scene.free()
	quit()
