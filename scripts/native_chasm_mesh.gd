extends RefCounted
## Cut the existing irregular triangulation, then close each bank independently.
## No bottom or collision face spans the fissure.
const Genome = preload("res://scripts/inland_genome.gd")

static func mask(points: PackedVector2Array, ids: PackedInt32Array, genome: Dictionary) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(ids.size()/3)
	for i in range(0,ids.size(),3):
		var low := INF
		var high := -INF
		for j in range(3):
			var d := Genome.chasm_distance(genome,points[ids[i+j]])
			low = minf(low,d)
			high = maxf(high,d)
		var half: float = genome.chasm.width*0.5
		result[i/3] = 1 if low<=half and high>=-half else 0
	return result

## `walled`, when given, holds the faces whose banks take a wall (the chasm's
## own, on an island with an outline, whose shore the earth sides close:
## scripts/island_shore.gd); left out, every open edge does.
static func build(source: ArrayMesh, removed: PackedByteArray, ids: PackedInt32Array, walled := PackedByteArray()) -> ArrayMesh:
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices := PackedInt32Array()
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	walls.set_custom_format(0,SurfaceTool.CUSTOM_RGB_FLOAT)
	var edges := {}
	var floor_y := minf(-4.5,source.get_aabb().position.y-3.0)
	for i in range(0,vertices.size(),3):
		if removed[i/3] != 0: continue
		for j in range(3):
			var k := i+j
			indices.append(k)
			var next := i+(j+1)%3
			var key := Vector2i(mini(ids[k],ids[next]),maxi(ids[k],ids[next]))
			if edges.has(key): edges.erase(key)
			else: edges[key] = [vertices[k],vertices[next]]
		var a := Vector3(vertices[i].x,floor_y,vertices[i].z)
		var b := Vector3(vertices[i+1].x,floor_y,vertices[i+1].z)
		var c := Vector3(vertices[i+2].x,floor_y,vertices[i+2].z)
		_triangle(walls,a,c,b)
	var banks := {}
	for i in range(0,walled.size()*3,3):
		if walled[i/3] == 0: continue
		for j in range(3): banks[Vector2i(mini(ids[i+j],ids[i+(j+1)%3]),maxi(ids[i+j],ids[i+(j+1)%3]))] = true
	for key: Vector2i in edges:
		if not walled.is_empty() and not banks.has(key): continue
		var edge: Array = edges[key]
		var a: Vector3 = edge[0]
		var b: Vector3 = edge[1]
		var c := Vector3(a.x,floor_y,a.z)
		var d := Vector3(b.x,floor_y,b.z)
		_triangle(walls,b,a,c)
		_triangle(walls,b,c,d)
	# Index the retained faces instead of rebuilding their vertex attributes.
	# This preserves every custom growth/palette channel byte-for-byte.
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	var flags := source.surface_get_format(0) & (Mesh.ARRAY_FORMAT_CUSTOM_MASK << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},flags)
	mesh.surface_set_material(0,source.surface_get_material(0))
	walls.commit(mesh)
	var earth := ShaderMaterial.new()
	earth.shader = preload("res://shaders/reference_surface.gdshader")
	earth.set_shader_parameter("terrain_growth",true)
	earth.set_shader_parameter("palette_role",4)
	mesh.surface_set_material(1,earth)
	return mesh

static func _triangle(tool: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
	var normal := (c-a).cross(b-a).normalized()
	for p in [a,b,c]:
		tool.set_normal(normal)
		var color := Color("665340").lerp(Color("998368"),clampf((p.y+4.5)/7.0,0.0,1.0)).srgb_to_linear()
		tool.set_color(color)
		tool.set_custom(0,color)
		tool.set_uv(Vector2.ZERO)
		tool.set_uv2(Vector2(0.5,p.y))
		tool.add_vertex(p)
