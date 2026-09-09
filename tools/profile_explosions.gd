extends SceneTree
## Fixed-seed real-game burst benchmark. Run graphically for frame/GPU timings.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	create_timer(120).timeout.connect(func() -> void: quit(2))
	root.size = Vector2i(1440,900)
	var scene = load("res://studies/diorama.tscn").instantiate()
	scene.title_seed = 37
	scene.library_path = "/private/tmp/explosion-profile"
	scene.recent_file = scene.library_path+"/recent.cfg"
	scene.set_meta("movie_capture",true)
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	scene.new_diorama()
	var editor: NativeChunkEditor = scene._chunk_editor
	await editor.form_landscape("horn","alpine",false,37)
	var top := 0
	for i in range(editor.data.heights.size()):
		if editor.data.heights[i]>editor.data.heights[top]: top = i
	var charge := editor.data.place("explosive",editor.data.points[top])
	editor.data.update_object(charge,{"blast_radius":3.5})
	editor.refresh()
	scene.target = Vector3(-1,5.5,-1)
	scene.distance = 29
	scene.polar = 0.95
	scene.yaw = 0.65
	scene._auto_orbit = false
	scene._update_camera()
	scene.set_building(false)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for trial in range(3):
		for i in range(90): await process_frame
		editor.explosives.target_id = charge
		var start := Time.get_ticks_usec()
		editor.explosives.request_detonation()
		var detonation_ms := 0.0
		var frames := []
		var gpu := []
		var previous := start
		for i in range(120):
			await process_frame
			var now := Time.get_ticks_usec()
			frames.append((now-previous)/1000.0)
			previous = now
			if detonation_ms == 0.0 and not editor.explosives.requested and not editor.explosives.firing:
				detonation_ms = (now-start)/1000.0
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		frames.sort()
		gpu.sort()
		print("EXPLOSION_PROFILE ",JSON.stringify({"trial":trial,"completion_ms":detonation_ms,"frame_p50_ms":frames[60],"frame_p95_ms":frames[114],"frame_max_ms":frames[-1],"gpu_p95_ms":gpu[114],"bodies":editor.explosives.bodies.size()}))
		editor.undo()
	scene.queue_free()
	await process_frame
	quit()
