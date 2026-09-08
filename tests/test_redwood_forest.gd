extends SceneTree
func _initialize() -> void: run.call_deferred()
func press(study: Node, code: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	study._unhandled_input(event)
func run() -> void:
	var study = load("res://studies/redwood_forest.tscn").instantiate()
	root.add_child(study)
	assert(study.ready_for_capture and study.tree_count>80)
	var ground: MeshInstance3D = study.get_child(2)
	var normals: PackedVector3Array = ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	assert(normals[0].y>0.9)
	assert(study.sun.shadow_enabled and study.environment.volumetric_fog_enabled)
	press(study,KEY_M)
	assert(float(study.mist_material.get_shader_parameter("floor_pockets"))==0.0)
	press(study,KEY_M)
	assert(float(study.mist_material.get_shader_parameter("floor_pockets"))==1.0)
	study._process(1.0)
	var before: float = study.clock
	press(study,KEY_P)
	study._process(2.0)
	assert(study.clock==before)
	press(study,KEY_P)
	study._process(0.5)
	assert(is_equal_approx(study.clock,before+0.5))
	press(study,KEY_F8)
	assert(not study.environment.volumetric_fog_enabled)
	press(study,KEY_F8)
	assert(study.environment.volumetric_fog_enabled)
	assert(study.camera.position.is_finite())
	print("REDWOOD VERIFIED: grove, volumetric light, pause/resume and atmosphere toggle")
	study.free()
	quit()
