extends SceneTree
## Real placement entry point and camera rotation with frame intervals captured.
var scene: Node3D
var phase := "warmup"
var samples: Array[Dictionary] = []
var operations: Array[Dictionary] = []
var previous := 0
var preset := "cone"
var output := "/tmp/zs-interaction.json"
var reflections := true
var resident := false
var monitors := {}
var orbit_seconds := 8.0
var place_flowers := true
var camera_stress := false
var phase_started := 0

func _initialize() -> void: run.call_deferred()

func frame() -> void:
	var now := Time.get_ticks_usec()
	var record := {"phase":phase,"ms":float(now-previous)/1000.0}
	record["process_ms"] = Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
	record["render_cpu_ms"] = RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
	record["render_gpu_ms"] = RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
	record["objects_revision"] = scene._chunk_editor.data.objects_revision
	previous = now
	for key in monitors: record[key] = Performance.get_monitor(monitors[key])
	samples.append(record)
	if phase == "orbit" or phase.begins_with("fast_orbit"):
		scene._orbiting = true
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(-24.0,0) if phase.begins_with("fast_orbit") else Vector2(-2.0,0)
		scene._input(motion)
	elif phase.begins_with("zoom"):
		var wheel := InputEventMouseButton.new()
		wheel.pressed = true
		wheel.factor = 3.0
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP if (Time.get_ticks_msec()-phase_started) % 1400 < 700 else MOUSE_BUTTON_WHEEL_DOWN
		scene._unhandled_input(wheel)
	elif phase.begins_with("pan"):
		scene._panning = true
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(12.0,3.0) * (1.0 if (Time.get_ticks_msec()-phase_started) % 1400 < 700 else -1.0)
		scene._input(motion)

func run() -> void:
	root.size = Vector2i(1440,900)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preset="): preset = arg.trim_prefix("--preset=")
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg == "--no-reflections": reflections = false
		if arg == "--bigfoot": resident = true
		if arg == "--orbit-only": place_flowers = false
		if arg == "--camera-stress":
			camera_stress = true
			place_flowers = false
		if arg.begins_with("--orbit-seconds="): orbit_seconds = float(arg.trim_prefix("--orbit-seconds="))
	for key in ClassDB.class_get_integer_constant_list("Performance"):
		if "PIPELINE" in key: monitors[key] = ClassDB.class_get_integer_constant("Performance",key)
	scene = load("res://studies/diorama.tscn").instantiate()
	root.add_child(scene)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	scene.close_menu()
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	scene._auto_orbit = false
	scene._planar_water.enabled = reflections
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.set_process(false)
	await editor.form_landscape(preset,"",false)
	scene._has_world = true
	scene._frame_diorama()
	if resident: scene.invite_bigfoot(Vector3.ZERO)
	editor.set_active(true)
	editor.select_tool("flower")
	editor.placement_trail = false
	# The benchmark's scripted pointer is not blocked by the editor palette.
	scene._ui.hide()
	scene._build_palette.hide()
	await create_timer(2.0).timeout
	previous = Time.get_ticks_usec()
	process_frame.connect(frame)
	phase = "idle"
	await create_timer(2.0).timeout
	phase = "place"
	for i in range(4 if place_flowers else 0):
		var point := Vector2(-4.0+float(i),2.0)
		var height: Variant = editor.data.ground_height(point)
		assert(height != null)
		var mouse: Vector2 = scene.camera.unproject_position(Vector3(point.x,height,point.y))
		var count := editor.data.objects.size()
		var began := Time.get_ticks_usec()
		editor.place_at(mouse)
		editor.finish_stroke()
		operations.append({"operation":"place_flower","ms":float(Time.get_ticks_usec()-began)/1000.0,"added":editor.data.objects.size()-count})
		await create_timer(0.8).timeout
	phase = "orbit"
	await create_timer(orbit_seconds).timeout
	scene._orbiting = false
	if camera_stress:
		editor.set_active(false)
		for pass_index in range(2):
			for motion in ["fast_orbit","zoom","pan"]:
				scene._frame_diorama()
				scene._orbit_delta = Vector2.ZERO
				scene._pan_delta = Vector2.ZERO
				phase = motion+str(pass_index+1)
				phase_started = Time.get_ticks_msec()
				await create_timer(4.2).timeout
				scene._panning = false
				scene._orbiting = false
	phase = "settle"
	await create_timer(1.0).timeout
	process_frame.disconnect(frame)
	var report := {"preset":preset,"gpu":RenderingServer.get_video_adapter_name(),"reflections":reflections,"bigfoot":resident,"operations":operations,"samples":samples}
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	for name in ["idle","place","orbit","fast_orbit1","zoom1","pan1","fast_orbit2","zoom2","pan2"]:
		var gaps: Array = samples.filter(func(row): return row.phase == name).map(func(row): return row.ms)
		if gaps.is_empty(): continue
		gaps.sort()
		print("INTERACTION ",name," max=",gaps.back()," p95=",gaps[int(gaps.size()*0.95)]," >33ms=",gaps.filter(func(value): return value>33.33).size())
	print("OPERATIONS ",JSON.stringify(operations))
	quit()
