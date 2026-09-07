extends SceneTree
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var sky = scene._celestial
	for phase in [0.02, 0.5]:
		sky.night_fill = 0.0
		sky.set_phase(phase)
		var before: Dictionary = sky.state.duplicate(true)
		sky.night_fill = 1.0
		sky.update_rig()
		for key in ["zs_sky_down", "zs_sky_up", "zs_sky_glow", "zs_cloud_sky", "zs_cloud_sun", "zs_key_irradiance"]:
			check(sky.state[key] == before[key], "Fill preserves sky and directional lighting: " + key)
		if phase == 0.5:
			check(sky.state.zs_hemi_sky == before.zs_hemi_sky and sky.state.zs_hemi_energy == before.zs_hemi_energy, "Daytime is unaffected")
		else:
			check(sky.state.zs_hemi_sky.length() > before.zs_hemi_sky.length() and sky.state.zs_hemi_energy > before.zs_hemi_energy, "Night surfaces receive additional fill")
	scene._paused = true
	sky.set_phase(0.02)
	sky.night_fill = 0.0
	sky.update_rig()
	var dark: float = sky.state.zs_hemi_energy
	sky.night_fill = 1.0
	sky.update_rig()
	check(sky.state.zs_hemi_energy > dark, "Explicit fill changes remain live while paused")
	scene.queue_free()
	await process_frame
	print("PASS: night fill preserves daytime, sky and paused controls" if failures == 0 else "FAIL: night fill")
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
