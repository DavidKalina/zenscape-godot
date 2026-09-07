extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var sky = scene._celestial
	sky.cloud = 0.06
	sky.wind = 0.4
	sky.set_phase(0.26)
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/inversion-checks.json"))
	check(absf(sky.state.zs_inversion.x - source.uInv) < 0.00001, "Source dawn inversion strength")
	check(absf(sky.state.zs_inversion.y - source.uInvLine) < 0.00001, "Source dawn lid altitude")
	for pair in [["zs_inversion_color", "uInvColor"], ["zs_cloud_sun", "uSunColor"], ["zs_cloud_sky", "uSkyColor"]]:
		var a = source[pair[1]]
		var expected := Vector3(a[0], a[1], a[2])
		check(sky.state[pair[0]].distance_to(expected) < 0.00002, "Source dawn color: " + pair[0] + " actual " + str(sky.state[pair[0]]) + " expected " + str(expected))
	sky.set_phase(0.74)
	check(sky.state.zs_inversion.x == 0.0, "Dusk has no cold-air inversion")
	sky.set_phase(0.35)
	check(sky.state.zs_inversion.x == 0.0, "Sun burns off the inversion")
	sky.set_phase(0.26)
	sky.wind = 2.0
	sky.update_rig()
	check(sky.state.zs_inversion.x == 0.0, "Strong wind breaks the inversion")
	sky.wind = 0.4
	sky.cloud = 1.0
	sky.update_rig()
	check(sky.state.zs_inversion.x == 0.0, "Overcast prevents the inversion")
	# Check the retained native-volume fallback; the compositor has separate GPU tests.
	scene._atmosphere.native_volume = true
	scene._atmosphere.set_fog(0.0)
	scene._atmosphere.set_haze(0.0)
	scene._atmosphere.set_inversion(0.8)
	check(scene._environment.volumetric_fog_enabled, "Inversion is independent of ordinary mist dial")
	scene._atmosphere.set_inversion(0.0)
	check(not scene._environment.volumetric_fog_enabled, "No residual volume when both fog sources are absent")
	scene.queue_free()
	await process_frame
	print("PASS: source inversion dawn colors, sun/wind/cloud gates and mist independence" if failures == 0 else "FAIL: inversion")
	quit(1 if failures else 0)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
