extends MultiMeshInstance3D
## Quiet independent flashes above the imported damp undergrowth.
var material := ShaderMaterial.new()
var called := false
var activity := 0.0
func setup(data: Dictionary) -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.instance_count = data.phase.size()
	var quad := QuadMesh.new()
	material.shader = preload("res://shaders/reference_fireflies.gdshader")
	quad.material = material
	multimesh.mesh = quad
	for i in range(multimesh.instance_count):
		var origin := Vector3(data.positions[i*3],data.positions[i*3+1],data.positions[i*3+2])
		multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,origin))
		multimesh.set_instance_custom_data(i,Color(data.phase[i],data.amplitude[i],data.rate[i],0))
	extra_cull_margin = 2.0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func update_conditions(daylight: float, rain: float, cold: float, growth: float) -> void:
	var dusk := maxf(smoothstep(0.45,0.12,daylight),1.0 if called else 0.0)
	activity = dusk*(1.0-clampf(rain,0.0,1.0)*0.85)*smoothstep(0.55,0.15,cold)*growth
	material.set_shader_parameter("activity",activity)
	visible = activity > 0.001
