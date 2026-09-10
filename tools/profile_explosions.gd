extends SceneTree
## Fixed-seed real-game burst benchmark. Run graphically for frame/GPU timings.
func _initialize() -> void: run.call_deferred()
## Readback changes frame timing; this mode is visual evidence only.
func capture_transition(editor: NativeChunkEditor, charge: int) -> void:
	var directory := "/private/tmp/zs-blast-transition"
	DirAccess.make_dir_recursive_absolute(directory)
	for i in range(90): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory+"/00-before.png")
	var original_mesh := editor.terrain.mesh.get_instance_id()
	var began := Time.get_ticks_usec()
	var entries: Array = []
	var previous := ""
	var settled := 0
	editor.explosives.target_id = charge
	editor.explosives.request_detonation()
	for frame in range(180):
		await RenderingServer.frame_post_draw
		var blast = editor.explosives
		var label: String = blast.phase+"-"+editor.refresh_stage
		if not blast.requested and not blast.firing: settled += 1
		if label != previous or settled in [1,8,30]:
			var filename := "%02d-%s.png" % [entries.size()+1,label]
			root.get_texture().get_image().save_png(directory+"/"+filename)
			var moving := 0
			var visible_chunks := 0
			var visible_bodies := 0
			for body in blast.bodies:
				if not body.freeze: moving += 1
				if body.visible:
					visible_bodies += 1
					if body.get_meta("mountain_chunk",false): visible_chunks += 1
			entries.append({"file":filename,"frame":frame,"elapsed_ms":(Time.get_ticks_usec()-began)/1000.0,"phase":blast.phase,"refresh":editor.refresh_stage,"terrain_replaced":editor.terrain.mesh.get_instance_id()!=original_mesh,"bodies":blast.bodies.size(),"visible_bodies":visible_bodies,"visible_chunks":visible_chunks,"unfrozen":moving})
		previous = label
		if settled>=30: break
	var file := FileAccess.open(directory+"/timeline.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(entries,"\t"))
	print("EXPLOSION_CAPTURE ",JSON.stringify(entries))
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
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
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
	# macOS can restore a previous maximized window after scene startup. Apply
	# the benchmark dimensions after loading, and verify them after warmup.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	# Window-mode changes are asynchronous on macOS; let the restored size
	# arrive before assigning the benchmark size.
	for _frame in range(3): await process_frame
	root.size = Vector2i(1440,900)
	for argument in OS.get_cmdline_user_args():
		if argument == "--quality=beauty": scene._set_quality(0)
		if argument == "--quality=balanced": scene._set_quality(1)
	if "--capture" in OS.get_cmdline_user_args():
		await capture_transition(editor,charge)
		scene.queue_free()
		await process_frame
		quit()
		return
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for trial in range(3):
		for i in range(90): await process_frame
		if root.size != Vector2i(1440,900):
			push_error("Explosion viewport mismatch: "+str(root.size))
			scene.free()
			quit(1)
			return
		if trial == 0:
			print("EXPLOSION_CONFIGURATION ",JSON.stringify({"quality":"beauty" if scene._environment.ssao_enabled else "balanced","pixels":[root.size.x,root.size.y],"msaa":root.msaa_3d,"render_scale":root.scaling_3d_scale,"gpu":RenderingServer.get_video_adapter_name()}))
		editor.explosives.target_id = charge
		var start := Time.get_ticks_usec()
		editor.explosives.request_detonation()
		var detonation_ms := 0.0
		var frames := []
		var gpu := []
		var physics := []
		var gaps := []
		var flash_ms := 0.0
		var previous := start
		for i in range(120):
			await process_frame
			var now := Time.get_ticks_usec()
			frames.append((now-previous)/1000.0)
			gaps.append({"ms":frames[-1],"phase":editor.explosives.phase})
			if flash_ms == 0 and editor.explosives.effects.get_child_count()>1: flash_ms = (now-start)/1000.0
			previous = now
			if detonation_ms == 0.0 and not editor.explosives.requested and not editor.explosives.firing:
				detonation_ms = (now-start)/1000.0
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		gaps.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.ms>b.ms)
		frames.sort()
		gpu.sort()
		physics.sort()
		print("EXPLOSION_PHYSICS ",JSON.stringify({"trial":trial,"engine_physics_p95_ms":physics[114],"engine_physics_max_ms":physics[-1]}))
		print("EXPLOSION_PROFILE ",JSON.stringify({"trial":trial,"flash_ms":flash_ms,"worst_frames":gaps.slice(0,4),"refresh_stages":editor.last_refresh_usec,"instances":editor.content.last_instance_usec,"surface_maps":editor.last_surface_profile,"mesh":editor.data.last_mesh_profile,"water":editor.content.last_water_usec,"stages_usec":editor.explosives.last_stage_usec,"frame_p99_ms":frames[118],"completion_ms":detonation_ms,"frame_p50_ms":frames[60],"frame_p95_ms":frames[114],"frame_max_ms":frames[-1],"gpu_p95_ms":gpu[114],"bodies":editor.explosives.bodies.size()}))
		editor.undo()
	scene.queue_free()
	await process_frame
	quit()
