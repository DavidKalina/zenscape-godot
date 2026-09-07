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
	for sample in samples:
		var theta := asin(float(sample.e) / cos(sky._tilt))
		for angle in [theta, PI - theta]:
			sky.cloud = sample.cloud
			sky.set_phase(angle / TAU + 0.25)
			var expected := Vector3(sample.value[0],sample.value[1],sample.value[2])
			check(sky.state.zs_alpen.distance_to(expected) < 0.00001, "Source dawn/dusk paint at elevation " + str(sample.e))
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
