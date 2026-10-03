extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var sky = scene._celestial
	var samples = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/alpenglow-checks.json"))
	# The shade line (x, y) keeps the source's curves but runs ALPEN_LAG lower
	# in sun height (golden hour keeps its sun); the afterglow (z) is the source's.
	for sample in samples:
		var expected := Vector3(sample.value[0],sample.value[1],sample.value[2])
		for lag in [sky.ALPEN_LAG, 0.0]:
			var theta := asin((float(sample.e) - lag) / cos(sky._tilt))
			for angle in [theta, PI - theta]:
				sky.cloud = sample.cloud
				sky.set_phase(angle / TAU + 0.25)
				var got: Vector3 = sky.state.zs_alpen
				if lag > 0.0:
					check(Vector2(got.x, got.y).distance_to(Vector2(expected.x, expected.y)) < 0.00001, "Source shade line, lagged, at elevation " + str(sample.e))
				else:
					check(absf(got.z - expected.z) < 0.00001, "Source afterglow at elevation " + str(sample.e))
				check(absf(sky.state.zs_alpen_direction.length() - 1.0) < 0.00001, "Afterglow facing is normalized")
	sky.cloud = 0.0
	sky.set_phase(0.755)
	check(sky.state.zs_alpen.z > 0.9, "Clear sunset retains peak afterglow")
	sky.alpen_enabled = false
	sky.update_rig()
	check(sky.state.zs_alpen.x == 0.0 and sky.state.zs_alpen.z == 0.0, "Comparison control disables both terms")
	scene.queue_free()
	await process_frame
	print("PASS: source alpenglow curves, dawn/dusk, overcast and control" if failures == 0 else "FAIL: alpenglow")
	quit(1 if failures else 0)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
