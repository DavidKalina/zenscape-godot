extends SceneTree
## Real-time wall-clock benchmark: warm up shaders, then sample a fixed orbit.
## Run with a real renderer, --disable-vsync, and -- --output=/path/report.json.

var scene: Node3D
var started := 0
var previous := 0
var samples: Array[float] = []
var output := "/tmp/zenscape-benchmark.json"
var initial_yaw := 0.0

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Benchmark requires a real graphics device.")
		quit(1)
		return
	RenderingServer.render_loop_enabled = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	_start.call_deferred()

func _start() -> void:
	root.size = Vector2i(1440, 900)
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene._ui.visible = false
	scene._auto_orbit = false
	initial_yaw = scene.yaw
	started = 0
	create_timer(45.0).timeout.connect(_timeout)
	process_frame.connect(_draw_frame)

func _draw_frame() -> void:
	RenderingServer.force_draw(false)
	_sample()

func _sample() -> void:
	var now := Time.get_ticks_usec()
	if started == 0:
		started = now
		previous = now
		return
	var seconds := float(now - started) / 1000000.0
	scene.yaw = initial_yaw + maxf(seconds - 5.0, 0.0) * 0.055
	scene._update_camera()
	if seconds > 5.0:
		if float(now - previous) / 1000.0 > 250.0:
			push_error("Benchmark was interrupted for over 250 ms; rerun without other GPU work.")
			quit(1)
			return
		samples.append(float(now - previous) / 1000.0)
	previous = now
	if seconds < 17.0:
		return
	process_frame.disconnect(_draw_frame)
	samples.sort()
	var total := 0.0
	for value in samples:
		total += value
	var report := {
		"renderer": RenderingServer.get_current_rendering_method(),
		"device": RenderingServer.get_video_adapter_name(),
		"resolution": [root.size.x, root.size.y],
		"render_resolution": [root.get_texture().get_width(), root.get_texture().get_height()],
		"quality": "beauty" if scene._environment.ssao_enabled else "balanced",
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"msaa_3d": root.msaa_3d,
		"measurement": "explicit offscreen draws without presentation; not gameplay FPS or GPU timestamps",
		"camera_path": "source pose during warmup, then 0.055 radians/second for 12 seconds",
		"warmup_seconds": 5, "sample_seconds": 12, "frames": samples.size(),
		"mean_draws_per_second": 1000.0 / (total / samples.size()),
		"median_ms": samples[samples.size() / 2],
		"p95_ms": samples[mini(samples.size() - 1, int(samples.size() * 0.95))],
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
	}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write benchmark: " + output)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit()

func _timeout() -> void:
	push_error("Benchmark timed out without enough drawn frames.")
	quit(1)
