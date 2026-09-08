extends SceneTree
## Native integration checks for the authored study's controls and pool planes.
func _initialize() -> void: run.call_deferred()
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)
	await process_frame
func run() -> void:
	create_timer(120).timeout.connect(func(): push_error("Verification timeout"); quit(2))
	var study = load("res://studies/visual_benchmark.tscn").instantiate()
	root.add_child(study)
	while not study.ready_for_capture: await process_frame
	var original: Mesh = study.water_node.mesh
	assert(study.planar.views.size() == 3)
	assert(study.enhanced and not study.water_node.visible)
	var caustics: ShaderMaterial = study.get_meta("caustics_material")
	var enabled_pools := 0
	for view in study.planar.views:
		var strength: Variant = view.material.get_shader_parameter("caustics_strength")
		if strength != null and float(strength)>0.0: enabled_pools += 1
	assert(enabled_pools == 1)
	await key(KEY_C)
	assert(float(caustics.get_shader_parameter("caustics_strength")) == 0.0)
	await key(KEY_C)
	assert(is_equal_approx(float(caustics.get_shader_parameter("caustics_strength")),0.45))
	await key(KEY_P)
	assert(study.scene._paused)
	var motion: float = study.scene._motion_time
	await create_timer(0.15).timeout
	assert(study.scene._motion_time == motion)
	await key(KEY_F8)
	assert(not study.enhanced and study.water_node.visible)
	assert(study.water_node.mesh == original)
	for view in study.planar.views: assert(view.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	await key(KEY_F8)
	assert(study.enhanced and not study.water_node.visible)
	var surfaces := 0
	for child in study.planar.get_children():
		if not child is MeshInstance3D: continue
		surfaces += 1
		var arrays = child.mesh.surface_get_arrays(0)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		assert(not indices.is_empty())
		var height: float = positions[indices[0]].y
		for i in range(0,indices.size(),3):
			var a := positions[indices[i]]
			var b := positions[indices[i+1]]
			var c := positions[indices[i+2]]
			assert(absf(a.y-height)<0.02 and absf(b.y-height)<0.02 and absf(c.y-height)<0.02)
			assert((b-a).cross(c-a).y <= 0.0)
	assert(surfaces == 3)
	await key(KEY_P)
	assert(not study.scene._paused)
	await create_timer(0.1).timeout
	assert(study.scene._motion_time > motion)
	print("VISUAL BENCHMARK VERIFIED: pause/resume, F8 round trip, source mesh preserved, three front-facing pool planes")
	study.free()
	await process_frame
	quit()
