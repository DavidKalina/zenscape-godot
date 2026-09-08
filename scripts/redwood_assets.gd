extends RefCounted
## Reusable, batched native assets. Their origin is the planted ground contact.
static var cache := {}
static func mesh(part: String) -> ArrayMesh:
	if cache.has(part): return cache[part]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 82031
	if part == "redwood-trunk":
		for ring in range(8):
			for side in range(9):
				var tint := Color("79513a").lerp(Color("432f25"),rng.randf()*0.6).srgb_to_linear()
				for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
					var h: float = (ring+corner.y)/8.0
					var angle: float = (side+corner.x)*TAU/9.0
					var radius := 0.55*(1.0-h*0.85)*(1.0+0.6*exp(-h*18.0))
					st.set_color(tint)
					st.add_vertex(Vector3(cos(angle)*radius+0.2*h*h,h*15.0,sin(angle)*radius))
	elif part == "redwood-canopies":
		for tier in range(6):
			var h := 8.0+tier*1.05
			var radius := 2.0-tier*0.25
			var tip := h+3.0-tier*0.1
			for side in range(9):
				var a := side*TAU/9.0+tier*0.2
				var b := (side+1)*TAU/9.0+tier*0.2
				var tint := Color("315735").lerp(Color("577345"),rng.randf()*0.65).srgb_to_linear()
				for p in [Vector3(cos(a)*radius,h,sin(a)*radius),Vector3(cos(b)*radius,h,sin(b)*radius),Vector3(0.2,tip,0)]:
					st.set_color(tint)
					st.add_vertex(p)
	else:
		# Compound serrated fronds, sized to mix with the existing grass tufts.
		for frond in range(7):
			var angle := frond*TAU/7
			var direction := Vector3(cos(angle),0,sin(angle))
			var across := Vector3(-direction.z,0,direction.x)
			for segment in range(6):
				var t := float(segment+1)/7
				var center := direction*t*0.85+Vector3.UP*sin(t*PI*0.85)*0.55
				var tip := direction*(t+0.13)*0.85+Vector3.UP*sin((t+0.13)*PI*0.85)*0.55
				for sign in [-1.0,1.0]:
					for p in [center,center+across*sign*(1.0-t)*0.25-direction*0.07,tip]:
						st.set_color(Color("5a7f41").darkened(rng.randf()*0.18).srgb_to_linear())
						st.add_vertex(p)
	st.generate_normals()
	var result := st.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/reference_surface.gdshader")
	material.set_shader_parameter("flat_faces",true)
	material.set_shader_parameter("plant_growth",true)
	material.set_shader_parameter("conifer_sway",part != "redwood-fern")
	material.set_shader_parameter("conifer_height",15.0)
	if part == "redwood-fern":
		material.set_shader_parameter("sway_enabled",true)
		material.set_shader_parameter("sway_shape",Vector4(0,0.6,0.045,0.025))
	result.surface_set_material(0,material)
	cache[part] = result
	return result
