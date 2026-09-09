extends SceneTree
## Native captures and an offline matched orbit. No FPS claims from the film.
var scene: Node3D
var output := "res://docs/fidelity/deliberate-pond"
var records: Array[Dictionary] = []
var film_poses: Array[Transform3D] = []
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for frame in range(40):
		await process_frame
		RenderingServer.force_draw(false)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	scene = load("res://studies/prototype_deliberate_pond.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.set_canopy(false)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600,1000)
	root.content_scale_factor = 1.0
	scene.study_ui.hide()
	scene._paused = true
	scene.set_process(false)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	await create_timer(3.0).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600,1000)
	await create_timer(2.0).timeout
	print("CAPTURE SIZE ", root.size)
	if "--ui-only" in OS.get_cmdline_user_args():
		scene.set_process_unhandled_input(true)
		for key in [KEY_1,KEY_2,KEY_3]:
			var event := InputEventKey.new()
			event.keycode = key
			event.pressed = true
			scene._unhandled_input(event)
			assert(scene.variant == key-KEY_1)
		scene.study_ui.show()
		scene._process(0.0)
		await settle()
		root.get_texture().get_image().save_png(output.path_join("interactive.png"))
		scene.free()
		quit()
		return
	for index in [0,1,2,0]:
		scene.set_variant(index)
		scene._process(0.0)
		await settle()
		var label := ["original","tactile","afternoon"][index] as String
		if records.size() == 3: label = "original-repeat"
		assert(root.size == Vector2i(1600,1000))
		assert(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK)
		records.append({"variant":label,"camera":str(scene.camera.transform),"size":str(root.size),"phase":scene._celestial.phase})
		print("CAPTURED ", label)
	if "--study-film" in OS.get_cmdline_user_args():
		for index in [0,2]:
			scene.set_variant(index)
			scene._process(0.0)
			await settle()
			var directory := "/tmp/pond-film-%d" % index
			DirAccess.make_dir_recursive_absolute(directory)
			for frame in range(120):
				scene.yaw = 0.55 + 0.30 * sin(float(frame)/119.0 * TAU)
				scene._process(0.0)
				if index == 0: film_poses.append(scene.camera.transform)
				else: scene.camera.transform = film_poses[frame]
				scene._display_fog.update_view()
				scene._planar_water.update_views()
				await process_frame
				RenderingServer.force_draw(false)
				root.get_texture().get_image().save_jpg(directory.path_join("%04d.jpg" % frame),0.96)
				records.append({"variant":index,"frame":frame,"camera":str(scene.camera.transform),"size":str(root.size)})
	if "--study-profile" in OS.get_cmdline_user_args(): await profile()
	FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	scene.reset_study_camera()
	scene.set_variant(2)
	scene._process(0.0)
	scene.study_ui.show()
	await settle()
	root.get_texture().get_image().save_png(output.path_join("interactive.png"))
	scene.free()
	quit()

func profile() -> void:
	# Real-time wall intervals, sampled separately from image readback.
	var phases: Array[Dictionary] = []
	scene._paused = false
	scene._auto_orbit = true
	scene.set_process(true)
	for index in [0,2,0]:
		scene.reset_study_camera()
		scene._auto_orbit = true
		scene.set_variant(index)
		await create_timer(3.0).timeout
		var intervals: Array[float] = []
		var last := Time.get_ticks_usec()
		var start := last
		while Time.get_ticks_usec()-start < 5000000:
			await process_frame
			var now := Time.get_ticks_usec()
			intervals.append(float(now-last)/1000.0)
			last = now
		intervals.sort()
		var over := 0
		for value in intervals:
			if value > 16.67: over += 1
		phases.append({"variant":index,"frames":intervals.size(),"median_ms":intervals[intervals.size()/2],"p99_ms":intervals[int(intervals.size()*0.99)],"max_ms":intervals.back(),"over_16_67ms":over,"size":str(root.size),"vsync":DisplayServer.window_get_vsync_mode(),"fps_cap":Engine.max_fps})
		print("PACING ", phases.back())
	scene.set_process(false)
	FileAccess.open(output.path_join("pacing.json"),FileAccess.WRITE).store_string(JSON.stringify(phases,"\t"))
