extends SceneTree
func _initialize() -> void:
	var source=preload("res://scripts/reference_source_ground.gd").new()
	source.setup()
	var generator=preload("res://scripts/native_stream_geometry.gd")
	var ramp=preload("res://scripts/native_recipe_water.gd").water_ramp(source.g.water)
	var generated: Dictionary=generator.build(source.g.streams[0],source.height_at,ramp)
	var reference=load("res://assets/zen_reference/geometry.scn").instantiate()
	var stream: MeshInstance3D=reference.get_node("mesh-38")
	var arrays=stream.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	var count: int=indices.size() if not indices.is_empty() else vertices.size()
	var emitted: Array=generator.mesh(generated).surface_get_arrays(0)
	var color_error:=0.0
	var center_error:=0.0
	var error:=0.0
	var depth_error:=0.0
	var uv_error:=0.0
	if count==generated.vertices.size():
		for i in range(count):
			var j: int=indices[i] if not indices.is_empty() else i
			error=maxf(error,(stream.transform*vertices[j]).distance_to(generated.vertices[i]))
			depth_error=maxf(depth_error,absf(arrays[Mesh.ARRAY_TEX_UV2][j].x-generated.uv2[i].x))
			uv_error=maxf(uv_error,arrays[Mesh.ARRAY_TEX_UV][j].distance_to(generated.uv[i]))
			var a: Color=arrays[Mesh.ARRAY_COLOR][j]
			var b: Color=emitted[Mesh.ARRAY_COLOR][i]
			color_error=maxf(color_error,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
			for axis in range(4):
				center_error=maxf(center_error,absf(arrays[Mesh.ARRAY_CUSTOM0][j*4+axis]-emitted[Mesh.ARRAY_CUSTOM0][i*4+axis]))
	print("Stream vertices reference ",count," generated ",generated.vertices.size(),"; position error ",error,"; depth error ",depth_error,"; flow UV error ",uv_error)
	print("Stream color error ",color_error,"; growth center/progress error ",center_error)
	var ok: bool=count==generated.vertices.size() and count>100 and error<0.00001 and depth_error<0.00001 and uv_error<0.00001 and color_error<0.00001 and center_error<0.00001
	reference.free()
	quit(0 if ok else 1)
