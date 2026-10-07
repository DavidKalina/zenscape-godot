extends SceneTree
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func run() -> void:
	root.size = Vector2i(1440,900)
	var scene = load("res://studies/diorama.tscn").instantiate()
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	var trace: Node = scene._performance_trace
	trace.output_directory = "/tmp/zenscape-trace-test-%d" % OS.get_process_id()
	var paths: Array[String] = []
	trace.saved.connect(func(path: String): paths.append(path))
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_F9
	scene._input(event)
	check(trace.active,"F9 starts a capture")
	scene.target = Vector3(2,3,4)
	scene._panning = true
	for i in range(4): await process_frame
	scene._input(event)
	check(not trace.active and paths.size() == 1 and not paths[0].is_empty(),"F9 saves and stops a capture")
	if paths.size() == 1 and not paths[0].is_empty():
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(paths[0]))
		check(report.metadata.has("gpu") and report.metadata.has("driver"),"Capture identifies the GPU and graphics backend")
		check(report.samples.size() >= 3,"Capture contains real process-frame intervals")
		check(report.samples[0].has("scene_ms") and report.samples[0].has("PIPELINE_COMPILATIONS_DRAW"),"Capture includes script work and pipeline counters")
		check(report.samples[0].camera_target == [2.0,3.0,4.0] and report.samples[0].panning and not report.samples[0].orbiting,"Capture identifies camera pan position and gesture")
	var count: int = trace.samples.size()
	await process_frame
	check(trace.samples.size() == count,"Stopped capture adds no samples")
	trace.duration_seconds = 0.01
	scene._input(event)
	await create_timer(0.1).timeout
	check(not trace.active and paths.size() == 2,"Capture stops and saves automatically")
	for path in paths:
		if not path.is_empty(): DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(trace.output_directory)
	scene.free()
	print("PERFORMANCE TRACE failures=",failures)
	quit(failures)
