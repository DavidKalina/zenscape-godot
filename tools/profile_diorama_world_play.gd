extends SceneTree
var scene: Node3D
var rows := []
func _initialize() -> void: run.call_deferred()
func measure(label: String, count := 240) -> void:
	var intervals := []
	var cpu := []
	var gpu := []
	var slow := []
	var last := Time.get_ticks_usec()
	for i in range(count):
		await process_frame
		var now := Time.get_ticks_usec()
		var frame_ms := float(now-last)/1000.0
		intervals.append(frame_ms)
		if frame_ms>16.7: slow.append({"frame":i,"ms":frame_ms,"activity":scene.world_play.mischief.active,"phase":scene.world_play.mischief.phase,"resident_state":scene.creature.state,"scene_ms":scene._performance_trace.last_scene_usec/1000.0})
		last = now
		cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	intervals.sort()
	cpu.sort()
	gpu.sort()
	var row := {"phase":label,"median_ms":intervals[count/2],"p95_ms":intervals[int(count*0.95)],"max_ms":intervals[-1],"cpu_median_ms":cpu[count/2],"gpu_median_ms":gpu[count/2],"slow_frames":slow}
	rows.append(row)
	print("PROFILE ",JSON.stringify(row))
func run() -> void:
	create_timer(120).timeout.connect(func(): quit(2))
	scene = load("res://studies/diorama.tscn").instantiate()
	scene.title_seed = 37
	scene.library_path = "/private/tmp/world-play-profile-library"
	scene.recent_file = scene.library_path+"/recent.cfg"
	scene.set_meta("movie_capture",true)
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440,960)
	root.content_scale_factor = 1.0
	root.always_on_top = true
	root.grab_focus()
	scene.new_diorama()
	await scene._chunk_editor.form_landscape("redwood_grove","",false,37)
	scene.set_building(false)
	scene._auto_orbit = false
	scene.target = Vector3(0,4,0)
	scene.distance = 34.0
	scene.polar = 0.95
	scene._update_camera()
	var play = scene.world_play
	play.mischief.autonomous = false
	scene._performance_trace.active = true
	play.rebuild_registry()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for i in range(120): await process_frame
	play.owner_scene = null
	await measure("interactions_disabled")
	play.owner_scene = scene
	await measure("interactions_idle")
	var id := -1
	for key in play._records:
		if play._records[key].asset in play.TREES:
			id = key
			break
	var start := Time.get_ticks_usec()
	var tree: Node3D = play.promote(id)
	print("PROFILE promotion_ms=",float(Time.get_ticks_usec()-start)/1000.0," objects=",play._records.size())
	tree.begin_grab()
	tree.drag_to(Vector3(4,0,2))
	await measure("tree_bending")
	tree.release()
	await measure("tree_recoil")
	if scene.invite_bigfoot(Vector3.ZERO):
		for i in range(120): await process_frame
		play.owner_scene = null
		await measure("bigfoot_without_interactions",600)
		play.owner_scene = scene
		play.mischief.autonomous = true
		await measure("bigfoot_active",600)
	FileAccess.open("/private/tmp/diorama-world-profile.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	quit()
