extends RefCounted
## Re-read rendered water after edits; bind each bed to the nearest real surface.
var points := {}
var refresh_in := 0.0
var _mesh_cache := {}
var _revision := -1

func update(delta: float, scene: Node) -> Dictionary:
	refresh_in -= delta
	if refresh_in > 0.0: return points
	refresh_in = 0.35
	points.clear()
	var editor = scene._chunk_editor
	if _revision != editor.content.revision:
		_mesh_cache.clear()
		_revision = editor.content.revision
	var listener: Vector3 = scene.camera.global_position
	for node in editor.falls.get_children():
		if node is MeshInstance3D: _mesh("fall",node,listener)
	for node in editor.content._landscape_falls: _mesh("fall",node,listener)
	for node in editor.content._stream_nodes: _mesh("stream",node,listener)
	if editor.content._water != null and not editor.content.pond_vertices.is_empty():
		_mesh("shore",editor.content._water,listener,editor.content.pond_vertices)
	if not editor.data.blank:
		for node in scene.get_node("Reference").get_children():
			if not node is MeshInstance3D or node.mesh == null: continue
			var material := node.mesh.surface_get_material(0) as ShaderMaterial
			if material == null or material.shader == null: continue
			var shader := material.shader.resource_path
			if shader.ends_with("reference_fall.gdshader"): _mesh("fall",node,listener)
			elif shader.ends_with("reference_water.gdshader"):
				_mesh("stream" if str(node.name) == "mesh-38" else "shore",node,listener)
	return points

func _mesh(kind: String, node: MeshInstance3D, listener: Vector3, known_vertices := PackedVector3Array()) -> void:
	if not node.is_visible_in_tree() or node.mesh == null: return
	# Cache deduplicated vertices; audio never pulls mesh arrays every frame.
	var key := node.mesh.get_instance_id()
	if not _mesh_cache.has(key):
		var unique := {}
		if not known_vertices.is_empty():
			# These are the exact vertices used to build the current pond mesh.
			# Reading its freshly uploaded GPU buffer can stall the first frame.
			for vertex in known_vertices: unique[vertex] = true
		else:
			for surface in range(node.mesh.get_surface_count()):
				var vertices: PackedVector3Array = node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex in vertices: unique[vertex] = true
		_mesh_cache[key] = PackedVector3Array(unique.keys())
	var best := listener.distance_squared_to(points[kind]) if points.has(kind) else INF
	for vertex in _mesh_cache[key]:
		var point := node.to_global(vertex)
		var distance := listener.distance_squared_to(point)
		if distance < best:
			best = distance
			points[kind] = point
