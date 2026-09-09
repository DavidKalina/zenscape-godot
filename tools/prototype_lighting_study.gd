extends SceneTree
## Throwaway controlled lighting study. No saved world or production defaults.
var scene: Node3D
var output := "res://docs/fidelity/lighting-study"
var records: Array[Dictionary] = []
var labels := ["control", "less-fill", "contact", "indirect", "ambient-path", "ambient-contact", "ambient-indirect"]
var surface: Shader = load("res://shaders/reference_surface.gdshader")
var original_code: String

func _initialize() -> void:
	_run.call_deferred()

func apply_variant(index: int) -> void:
	var code := original_code
	if index >= 4:
		code = code.replace("EMISSION = emissive_color + tint * mix(zs_hemi_ground, zs_hemi_sky, face_normal.y * 0.5 + 0.5) * zs_hemi_energy / PI;", "EMISSION = emissive_color;\n\tIRRADIANCE = vec4(mix(zs_hemi_ground, zs_hemi_sky, face_normal.y * 0.5 + 0.5) * zs_hemi_energy / PI, 1.0);")
	if surface.code != code: surface.code = code
	scene._celestial.look.settings.ambient_energy = 1.0 if index == 0 or index >= 4 else 0.55
	scene._process(0.0)
	var e: Environment = scene._environment
	e.ssao_enabled = index in [2, 3, 5, 6]
	e.ssao_radius = 0.65
	e.ssao_intensity = 0.7
	e.ssao_light_affect = 0.12
	e.ssil_enabled = index in [3, 6]
	e.ssil_radius = 3.0
	e.ssil_intensity = 0.5
	e.glow_enabled = false
	if scene._display_fog != null: scene._display_fog.forget()
	print("LIGHTING ", labels[index], " ambient=", scene._celestial.look.settings.ambient_energy, " ssao=", e.ssao_enabled, " ssil=", e.ssil_enabled)

func _run() -> void:
	original_code = surface.code
	DirAccess.make_dir_recursive_absolute(output)
	scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene._ui.hide()
	scene._paused = true
	scene._auto_orbit = false
	scene._orbit_delta = Vector2.ZERO
	scene._pan_delta = Vector2.ZERO
	scene._process(0.0)
	scene.set_process(false)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	await create_timer(3.0).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920, 1200)
	await create_timer(3.0).timeout
	print("STUDY ROOT ", root.get_children(), " current=", current_scene, " size=", root.size)
	if "--study-film" in OS.get_cmdline_user_args():
		await film()
		surface.code = original_code
		scene.free()
		quit()
		return
	for pose in ["wide", "close"]:
		scene.distance = 43.0 if pose == "wide" else 18.0
		scene.target = Vector3(0, 3, 0)
		scene.polar = 1.13
		scene.yaw = 1.8893
		for step in range(labels.size() + 1):
			var index := step % labels.size()
			apply_variant(index)
			for frame in range(32):
				await process_frame
				RenderingServer.force_draw(false)
			var label: String = labels[index] if step < labels.size() else "control-repeat"
			var path: String = output.path_join(pose + "-" + label + ".png")
			var result := root.get_texture().get_image().save_png(path)
			assert(root.size == Vector2i(1920, 1200), "Study viewport changed")
			assert(result == OK)
			records.append({"pose": pose, "variant": label, "size": str(root.size), "camera": str(scene.camera.transform), "phase": scene._celestial.phase, "ambient": scene._celestial.look.settings.ambient_energy, "ssao": scene._environment.ssao_enabled, "ssil": scene._environment.ssil_enabled})
			print("SAVED ", path)
	FileAccess.open(output.path_join("captures.json"), FileAccess.WRITE).store_string(JSON.stringify(records, "\t"))
	surface.code = original_code
	scene.free()
	quit()

func film() -> void:
	# Offline visual check only. The world stays frozen; camera poses match.
	var control_transforms: Array[Transform3D] = []
	for index in [0, 6]:
		var directory: String = "/tmp/zenscape-lighting-" + labels[index]
		DirAccess.make_dir_recursive_absolute(directory)
		scene.distance = 25.0
		scene.target = Vector3(0, 3, 0)
		scene.polar = 1.13
		scene.yaw = 1.8893
		apply_variant(index)
		for frame in range(32):
			await process_frame
			RenderingServer.force_draw(false)
		for frame in range(90):
			scene.yaw = 1.8893 + 0.12 * sin(float(frame) / 89.0 * TAU)
			scene._process(0.0)
			if index == 0:
				control_transforms.append(scene.camera.transform)
			else:
				scene.camera.transform = control_transforms[frame]
			await process_frame
			RenderingServer.force_draw(false)
			assert(root.size == Vector2i(1920, 1200))
			root.get_texture().get_image().save_jpg(directory.path_join("%04d.jpg" % frame), 0.97)
			records.append({"variant": labels[index], "frame": frame, "camera": str(scene.camera.transform), "size": str(root.size)})
	FileAccess.open(output.path_join("film-poses.json"), FileAccess.WRITE).store_string(JSON.stringify(records, "\t"))
