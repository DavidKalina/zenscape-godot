extends SceneTree
func _initialize() -> void:
	var ground=preload("res://scripts/reference_source_ground.gd").new()
	ground.setup()
	var strands: Array=preload("res://scripts/native_fall_strand.gd").landscape(ground.height_at,ground.pool,ground.g)
	var source=load("res://assets/zen_reference/geometry.scn").instantiate()
	var controls: Array=[]
	for node in source.get_children():
		if node is MeshInstance3D:
			var material=node.get_active_material(0)
			if material is ShaderMaterial and material.shader.resource_path=="res://shaders/reference_fall.gdshader": controls.append(node)
	var ok: bool=controls.size()==strands.size()
	for i in range(strands.size()):
		var node=preload("res://scripts/native_fall_renderer.gd").create(strands[i])
		var material=node.get_active_material(0)
		var expected=controls[i].get_active_material(0)
		var parameter_error:=0.0
		for parameter in ["ring_count","fall_seed","body_white","section_white","centers_tau","axis_a_width","axis_b_thick","aer_steep"]:
			var actual: Variant=material.get_shader_parameter(parameter)
			var control: Variant=expected.get_shader_parameter(parameter)
			if actual is float or actual is int:
				parameter_error=maxf(parameter_error,absf(actual-control))
			else:
				for j in range(actual.size()):
					parameter_error=maxf(parameter_error,absf(actual[j]-control[j]) if actual[j] is float else (actual[j]-control[j]).length())
		var a=node.mesh.surface_get_arrays(0)
		var b=controls[i].mesh.surface_get_arrays(0)
		var topology: bool=a[Mesh.ARRAY_TEX_UV]==b[Mesh.ARRAY_TEX_UV] and a[Mesh.ARRAY_TEX_UV2]==b[Mesh.ARRAY_TEX_UV2]
		print("Fall renderer vertices ",a[Mesh.ARRAY_VERTEX].size(),"; animation topology exact ",topology,"; shader state max error ",parameter_error)
		ok=ok and topology and parameter_error<0.000001
		node.free()
	source.free()
	quit(0 if ok else 1)
