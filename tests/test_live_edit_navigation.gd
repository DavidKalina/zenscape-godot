extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func run() -> void:
	create_timer(120).timeout.connect(func() -> void: quit(2))
	var scene = load("res://studies/open_meadow.tscn").instantiate()
	root.add_child(scene)
	for argument in OS.get_cmdline_user_args():
		if argument == "--quality=beauty": scene._set_quality(0)
		if argument == "--quality=balanced": scene._set_quality(1)
	print("NAVIGATION_CONFIGURATION ",JSON.stringify({"quality":"beauty" if scene._environment.ssao_enabled else "balanced","pixels":[root.size.x,root.size.y],"msaa":root.msaa_3d,"render_scale":root.scaling_3d_scale,"gpu":RenderingServer.get_video_adapter_name()}))
	scene.set_process(false)
	scene._paused = false
	var editor = scene._chunk_editor
	scene.creature.walk_step(scene.creature.position+Vector3(0.5,0,0),0.85,1.0/60.0)
	var maximum := 0
	for i in range(12):
		editor.data.brush(Vector2(-3,2),2.0,0.02,"raise",0.0)
		editor.refresh()
		var before: Vector3 = scene.creature.position
		var time := Time.get_ticks_usec()
		scene._process(1.0/60.0)
		maximum = maxi(maximum,Time.get_ticks_usec()-time)
		check(scene.navigation.rebuilding,"Edit yields before completing the navigation scan")
		check(scene.creature.position==before,"Actor cannot move onto a partially rebuilt map")
	check(scene.creature.player.current_animation_position>0.1,"Repeated edits keep the idle animation advancing")
	while scene.navigation.rebuilding:
		await process_frame
		scene._refresh_habitat(true)
	var expected := CreatureNavigation.new()
	expected.rebuild(scene.habitat,scene.habitat.clear_at,0.35,0.3)
	check(scene.navigation._nodes==expected._nodes,"Latest edited terrain matches synchronous map")
	check(scene.navigation.is_safe(scene.creature.position),"Actor is reconciled to safe ground")
	print("LIVE EDIT NAVIGATION failures=",failures," maximum_slice_ms=",maximum/1000.0)
	if "--benchmark" in OS.get_cmdline_user_args():
		await benchmark(scene)
	scene.free()
	quit(1 if failures else 0)

## Measure the actual habitat refresh with the full meadow rendering. No edit
## geometry refresh is included; completion includes actor reconciliation.
func benchmark(scene: Node3D) -> void:
	for _frame in range(60): await process_frame
	var expected := CreatureNavigation.new()
	expected.rebuild(scene.habitat,scene.habitat.clear_at,0.35,0.3)
	for workers in [1,2,4,8]:
		for trial in range(3):
			scene.navigation.thread_workers = workers
			scene._habitat_changed = true
			var gaps: Array[float] = []
			var began := Time.get_ticks_usec()
			var previous := began
			var max_slice := 0
			while true:
				var slice := Time.get_ticks_usec()
				scene._refresh_habitat(true)
				max_slice = maxi(max_slice,Time.get_ticks_usec()-slice)
				await process_frame
				var now := Time.get_ticks_usec()
				gaps.append((now-previous)/1000.0)
				previous = now
				if not scene.navigation.rebuilding: break
				if now-began > 10000000:
					check(false,"Live navigation benchmark completes within ten seconds")
					return
			gaps.sort()
			check(scene.navigation._nodes==expected._nodes and scene.navigation._cells==expected._cells,"Rendered worker sweep retains exact map")
			check(scene.navigation.last_worker_executed,"Rendered rebuild executes on workers")
			print("LIVE_NAVIGATION_WORKERS ",JSON.stringify({"workers":scene.navigation.last_worker_count,"trial":trial,"completion_ms":(previous-began)/1000.0,"slice_max_ms":max_slice/1000.0,"submit_ms":scene.navigation.last_submit_usec/1000.0,"validation_ms":scene.navigation.last_validation_usec/1000.0,"frame_p95_ms":gaps[int(gaps.size()*0.95)],"frame_p99_ms":gaps[int(gaps.size()*0.99)],"frame_max_ms":gaps[-1]}))
			for _frame in range(10): await process_frame
