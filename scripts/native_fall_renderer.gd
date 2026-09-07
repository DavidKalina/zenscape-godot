extends RefCounted
## Render regenerated strand state through the fidelity waterfall shader.
static func create(strand: Dictionary) -> MeshInstance3D:
	var count: int=strand.centers.size()
	var material:=ShaderMaterial.new()
	material.shader=preload("res://shaders/reference_fall.gdshader")
	material.set_shader_parameter("ring_count",count)
	material.set_shader_parameter("fall_seed",strand.seed)
	material.set_shader_parameter("body_white",0.36*(1.0-smoothstep(0.15,0.8,strand.halfW[count/2])))
	var white:=PackedFloat32Array()
	for s in range(12): white.append(preload("res://scripts/native_recipe_water.gd")._hash(s*1.7+strand.seed,2.9))
	material.set_shader_parameter("section_white",white)
	for pair in [["centers_tau","centers","tau"],["axis_a_width","axA","halfW"],["axis_b_thick","axB","thick"]]:
		var values:=PackedVector4Array()
		values.resize(32)
		for r in range(count):
			var p: Array=strand[pair[1]][r]
			values[r]=Vector4(p[0],p[1],p[2],strand[pair[2]][r])
		material.set_shader_parameter(pair[0],values)
	var shape:=PackedVector2Array()
	shape.resize(32)
	for r in range(count): shape[r]=Vector2(strand.aer[r],strand.steep[r])
	material.set_shader_parameter("aer_steep",shape)
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(count-1):
		for s in range(12):
			# Same reversed source triangle order as the reference importer.
			for corner in [[r,s],[r+1,s+1],[r+1,s],[r,s],[r,s+1],[r+1,s+1]]:
				var ring: int=corner[0]
				var angle: float=float(corner[1])/12.0*PI*2.0
				var c: Array=strand.centers[ring]
				var a: Array=strand.axA[ring]
				var b: Array=strand.axB[ring]
				var vertex: Vector3=Vector3(c[0],c[1],c[2])+Vector3(a[0],a[1],a[2])*cos(angle)*strand.halfW[ring]+Vector3(b[0],b[1],b[2])*sin(angle)*strand.thick[ring]
				surface.set_uv(Vector2(ring,angle))
				surface.set_uv2(Vector2(r,s))
				surface.set_color(Color.WHITE)
				surface.add_vertex(vertex)
	surface.generate_normals()
	var node:=MeshInstance3D.new()
	node.mesh=surface.commit()
	node.mesh.surface_set_material(0,material)
	node.extra_cull_margin=1.0
	return node
