extends SceneTree
## Real-time process-frame intervals, including the configured FPS cap.
## Not GPU timings or proof of display presentation/input latency.
## Godot --path . --script res://tools/profile_frame_pacing.gd -- --size=2880x1800
## Scene flags (--garden, --garden-file, --phase, --fog, --cam) pass through.
var scene: Node3D
var samples: Array[float] = []
var phases := ["still", "orbit", "still-repeat"]
var phase := 0
var started := 0
var previous := 0
var duration := 8.0
var warmup := 3.0
var output := "/tmp/zs-frame-pacing.json"
var results: Array[Dictionary] = []
var shadow_compare := false
var presentation_compare := false

func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	var size := Vector2i(1440, 900)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			size = Vector2i(int(parts[0]), int(parts[1]))
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg == "--shadow-compare":
			shadow_compare = true
			phases = ["shadow-old", "shadow-filtered", "shadow-old-repeat"]
		if arg == "--presentation-compare":
			presentation_compare = true
			phases = ["timer-120", "display-sync", "timer-120-repeat"]
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
	scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	if shadow_compare: _set_shadow_phase()
	if presentation_compare: _set_presentation_phase()
	started = Time.get_ticks_usec()
	previous = started
	process_frame.connect(_frame)

func _frame() -> void:
	var now := Time.get_ticks_usec()
	var interval := float(now - previous) / 1000.0
	previous = now
	var elapsed := float(now - started) / 1000000.0
	if elapsed < warmup: return
	samples.append(interval)
	if elapsed < warmup + duration: return
	samples.sort()
	var total := 0.0
	var over_16 := 0
	var over_25 := 0
	for value in samples:
		total += value
		if value > 16.667: over_16 += 1
		if value > 25.0: over_25 += 1
	var result := {"phase": phases[phase], "frames": samples.size(),
		"mean_ms": total / samples.size(), "p50_ms": _percentile(0.5),
		"p95_ms": _percentile(0.95), "p99_ms": _percentile(0.99),
		"max_ms": samples.back(), "over_16_67_ms": over_16, "over_25_ms": over_25,
		"physical_size": [root.size.x, root.size.y], "fps_cap": Engine.max_fps,
		"vsync": DisplayServer.window_get_vsync_mode(), "msaa": root.msaa_3d,
		"reported_refresh_hz": DisplayServer.screen_get_refresh_rate()}
	results.append(result)
	print("PACING ", JSON.stringify(result))
	phase += 1
	if phase == phases.size():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file == null:
			push_error("Cannot write pacing report: " + output)
			quit(1)
			return
		file.store_string(JSON.stringify(results, "\t"))
		quit()
		return
	scene._auto_orbit = phases[phase] == "orbit"
	if shadow_compare: _set_shadow_phase()
	if presentation_compare: _set_presentation_phase()
	samples.clear()
	started = now

func _percentile(fraction: float) -> float:
	return samples[clampi(ceili(fraction * samples.size()) - 1, 0, samples.size() - 1)]

func _set_shadow_phase() -> void:
	var filtered: bool = phases[phase] == "shadow-filtered"
	RenderingServer.directional_soft_shadow_filter_set_quality(3 if filtered else 1)
	for light in scene._lights: light.shadow_blur = 0.5 if filtered else 0.2

func _set_presentation_phase() -> void:
	var synced: bool = phases[phase] == "display-sync"
	Engine.max_fps = 0 if synced else 120
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if synced else DisplayServer.VSYNC_DISABLED)
	scene._auto_orbit = true
