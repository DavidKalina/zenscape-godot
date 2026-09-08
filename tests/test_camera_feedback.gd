extends SceneTree

var failures := 0

func _initialize() -> void:
	_check_camera_feedback.call_deferred()

func _check_camera_feedback() -> void:
	var scene: Node3D = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.distance = 43.0
	scene.polar = 1.13
	scene.yaw = 1.8893
	scene.target = Vector3.ZERO
	scene._update_camera()

	# OrbitControls applies 5% of its pending pointer motion on each displayed
	# frame. Replay uneven frame durations: the visual step must still decay by
	# the same 0.95 ratio rather than pulse with the measured frame interval.
	scene._orbit_delta = Vector2(120.0, 0.0)
	var frame_times := [1.0 / 240.0, 1.0 / 30.0, 1.0 / 120.0, 1.0 / 60.0]
	var steps: Array[float] = []
	for frame_time: float in frame_times:
		var before: float = scene.yaw
		scene._ease_camera(frame_time)
		steps.append(absf(scene.yaw - before))
	for index in range(1, steps.size()):
		check(is_equal_approx(steps[index] / steps[index - 1], 0.95), "Orbit feedback decays by 0.95 per displayed frame")

	# Multiple input events arriving between frames are one accumulated pointer
	# displacement, matching OrbitControls' event queue semantics.
	scene._orbit_delta = Vector2.ZERO
	scene._orbiting = true
	for relative in [Vector2(3.0, -2.0), Vector2(7.0, 5.0), Vector2(-1.0, 4.0)]:
		var event := InputEventMouseMotion.new()
		event.relative = relative
		scene._input(event)
	var accumulated: Vector2 = scene._orbit_delta
	check(accumulated == Vector2(9.0, 7.0), "Mouse deltas accumulate exactly between displayed frames")

	scene.queue_free()
	await process_frame
	print("PASS: camera feedback replay" if failures == 0 else "FAIL: camera feedback replay")
	quit(1 if failures else 0)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
