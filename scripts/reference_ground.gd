extends RefCounted
## Samples the imported triangulated surface without substituting a new terrain.

const CELL := 2.0
var _triangles: Array[PackedVector3Array] = []
var _buckets: Dictionary = {}
var _stream_channels: Array[PackedVector3Array] = []

func setup(mesh_node: MeshInstance3D) -> void:
	_triangles.clear()
	_buckets.clear()
	_stream_channels.clear()
	var arrays := mesh_node.mesh.surface_get_arrays(0)
	var material := mesh_node.get_active_material(0) as ShaderMaterial
	var is_stream: bool = material != null and material.get_shader_parameter("flowing") == true
	var vertices: PackedVector3Array = mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in range(0, vertices.size(), 3):
		var triangle := PackedVector3Array([mesh_node.transform * vertices[i], mesh_node.transform * vertices[i + 1], mesh_node.transform * vertices[i + 2]])
		var a := triangle[0]
		var b := triangle[1]
		var c := triangle[2]
		if absf((b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)) < 0.000001:
			continue
		var index := _triangles.size()
		_triangles.append(triangle)
		if is_stream:
			var custom: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var channels := PackedVector3Array()
			for j in range(3):
				channels.append(Vector3(custom[(i + j) * 4 + 3], uv[i + j].y, custom[(i + j) * 4 + 1] + mesh_node.position.y))
			_stream_channels.append(channels)
		for x in range(floori(minf(a.x, minf(b.x, c.x)) / CELL), floori(maxf(a.x, maxf(b.x, c.x)) / CELL) + 1):
			for z in range(floori(minf(a.z, minf(b.z, c.z)) / CELL), floori(maxf(a.z, maxf(b.z, c.z)) / CELL) + 1):
				var key := Vector2i(x, z)
				if not _buckets.has(key):
					_buckets[key] = []
				_buckets[key].append(index)

func height_at(x: float, z: float) -> Variant:
	var height := -INF
	for index: int in _buckets.get(Vector2i(floori(x / CELL), floori(z / CELL)), []):
		var triangle := _triangles[index]
		var a := triangle[0]
		var b := triangle[1]
		var c := triangle[2]
		var denominator := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
		var u := ((b.z - c.z) * (x - c.x) + (c.x - b.x) * (z - c.z)) / denominator
		var v := ((c.z - a.z) * (x - c.x) + (a.x - c.x) * (z - c.z)) / denominator
		if u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001:
			height = maxf(height, u * a.y + v * b.y + (1.0 - u - v) * c.y)
	return null if height == -INF else height

func stream_at(x: float, z: float) -> Vector4:
	if _stream_channels.is_empty():
		return Vector4.ZERO
	var height := -INF
	var result := Vector4.ZERO
	for index: int in _buckets.get(Vector2i(floori(x / CELL), floori(z / CELL)), []):
		var a := _triangles[index][0]
		var b := _triangles[index][1]
		var c := _triangles[index][2]
		var denominator := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
		var u := ((b.z - c.z) * (x - c.x) + (c.x - b.x) * (z - c.z)) / denominator
		var v := ((c.z - a.z) * (x - c.x) + (a.x - c.x) * (z - c.z)) / denominator
		var y := u * a.y + v * b.y + (1.0 - u - v) * c.y
		if u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001 and y > height:
			height = y
			var values := _stream_channels[index]
			var value := values[0] * u + values[1] * v + values[2] * (1.0 - u - v)
			result = Vector4(value.x, absf(value.y), value.z, 1.0)
	return result
