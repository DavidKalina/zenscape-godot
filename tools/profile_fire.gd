extends SceneTree
## Real frame timings with fire idle and active. No frame readback during samples.
## Launch --windowed --resolution 1440x900. Forward+ at Balanced 1440x900; --gdscript-kernels exercises the fallback.
func _initialize() -> void: run.call_deferred()

func sample(scene: Node3D, label: String, count: int) -> void:
	var frames: Array[float] = []
	var gpu: Array[float] = []
	var max_cells := 0
	var previous := Time.get_ticks_usec()
	for i in range(count):
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now-previous)/1000.0)
		previous = now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		max_cells = maxi(max_cells,scene._fire_field.burning_cells().size())
	frames.sort()
	gpu.sort()
	print("FIRE_PROFILE ",JSON.stringify({"phase":label,"samples":count,"frame_p50_ms":frames[count/2],"frame_p95_ms":frames[int(count*0.95)],"frame_max_ms":frames[-1],"gpu_p95_ms":gpu[int(count*0.95)],"max_burning_cells":max_cells}))

func run() -> void:
	create_timer(120).timeout.connect(func(): quit(2))
	root.size = Vector2i(1440,900)
	var scene = load("res://studies/diorama.tscn").instantiate()
	scene.title_seed = 37
	scene.library_path = "/private/tmp/fire-profile-"+str(Time.get_ticks_usec())
	scene.recent_file = scene.library_path+"/recent.cfg"
	scene.set_meta("movie_capture",true)
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	scene.new_diorama()
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.start_flat()
	editor.data.grass.fill(1.0)
	editor.data.meadow.fill(0.45)
	editor.data.blades.fill(0.35)
	for point in [Vector2(2,0),Vector2(3.4,2.2),Vector2(3,-2.4),Vector2(6,0.6)]:
		editor.data.place("tree",point,0.4,1.1)
	editor.refresh()
	scene._precipitation.set_weather(0,true)
	scene._celestial.cycling = false
	scene._celestial.set_phase(0.46)
	scene._celestial.update_rig()
	scene._fire_field._weather = func(): return {"ground_wet":0.0,"snow_cover":0.0,"rain":0.0}
	scene._fire_field._wind = func(_p): return Vector3(4,0,0)
	scene._fire_field._rng.seed = 91127
	scene.target = Vector3(1.5,1,0)
	scene.distance = 25.0
	scene.polar = deg_to_rad(64.0)
	scene.yaw = deg_to_rad(-118.0)
	scene._auto_orbit = false
	scene._update_camera()
	scene.set_building(false)
	scene._set_quality(1)
	root.mode = Window.MODE_WINDOWED
	await create_timer(0.5).timeout
	root.size = Vector2i(1440,900)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for i in range(90): await process_frame
	# macOS may deliver a delayed restored-window size after startup. Settle
	# it before sampling, then reject any mismatch rather than comparing pixels.
	for attempt in range(120):
		if root.size == Vector2i(1440,900): break
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1440,900)
		await create_timer(0.05).timeout
	if root.size != Vector2i(1440,900):
		push_error("Fire viewport mismatch: "+str(root.size))
		quit(1)
		return
	print("FIRE_CONFIGURATION ",JSON.stringify({"quality":"balanced","pixels":[root.size.x,root.size.y],"gpu":RenderingServer.get_video_adapter_name(),"fallback":"--gdscript-kernels" in OS.get_cmdline_user_args()}))
	await sample(scene,"idle",240)
	scene._fire_field.ignite(Vector3(-4,0,0),1.2,1.0)
	await sample(scene,"active",600)
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/pr5-fire-active.png")
	scene.free()
	await process_frame
	quit()
