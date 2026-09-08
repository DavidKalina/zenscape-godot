class_name NativeObjectSelection
extends Node3D
## Picks authored mesh triangles, preserving the instance-to-record identity.
## The marker is transient editor feedback and never enters the garden document.
var editor: NativeChunkEditor
var _triangles := {}
var _marker := MeshInstance3D.new()

func setup(target: NativeChunkEditor) -> void:
	editor = target
	add_child(_marker)
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("f9d98b")
	material.no_depth_test = true
	_marker.material_override = material

func parts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for batch in editor.content._batches:
		var key: String = batch.get_meta("part")
		var sources: Array = editor.content._sources.get(key, [])
		for i in range(sources.size()):
			var item: Variant = sources[i].get("item")
			if item == null:
				continue
			result.append({"id":int(item.id), "mesh":batch.multimesh.mesh, "transform":batch.global_transform*batch.multimesh.get_instance_transform(i)})
	for item: Dictionary in editor.data.objects:
		if item.asset not in NativeGardenLandmarks.KINDS:
			continue
		var node := editor.landmarks.get_node_or_null("%s_%d" % [item.asset,item.id])
		if node == null:
			continue
		for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			result.append({"id":int(item.id), "mesh":mesh.mesh, "transform":mesh.global_transform})
	return result

func pick(mouse: Vector2) -> int:
	if not editor.pointer_in_world(mouse):
		return -1
	var camera: Camera3D = editor.scene.camera
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	var ground: Variant = editor.pick(mouse)
	var nearest := origin.distance_to(editor.terrain.to_global(ground))+0.03 if ground != null else INF
	var selected := -1
	for part in parts():
		var inverse: Transform3D = part.transform.affine_inverse()
		var local_origin: Vector3 = inverse*origin
		var local_direction: Vector3 = (inverse.basis*direction).normalized()
		var mesh: Mesh = part.mesh
		if mesh.get_aabb().intersects_ray(local_origin,local_direction) == null:
			continue
		if not _triangles.has(mesh):
			_triangles[mesh] = mesh.generate_triangle_mesh()
		var triangles: TriangleMesh = _triangles[mesh]
		if triangles == null:
			continue
		var hit := triangles.intersect_ray(local_origin,local_direction)
		if hit.is_empty():
			continue
		var distance := origin.distance_to(part.transform*hit.position)
		if distance < nearest:
			nearest = distance
			selected = part.id
	return selected

func update_marker(id: int) -> void:
	_marker.visible = editor.active and editor.mode == "select" and id > 0
	if not _marker.visible:
		return
	var bounds := AABB()
	var found := false
	for part in parts():
		if part.id != id:
			continue
		var box: AABB = part.transform*part.mesh.get_aabb()
		bounds = bounds.merge(box) if found else box
		found = true
	_marker.visible = found
	if not found:
		return
	bounds = bounds.grow(0.06)
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	# Small corner brackets leave the object itself unobstructed.
	for i in range(8):
		var corner := bounds.get_endpoint(i)
		for axis in range(3):
			var end := corner
			end[axis] += minf(bounds.size[axis]*0.22,0.35)*(1.0 if corner[axis] < bounds.get_center()[axis] else -1.0)
			lines.surface_add_vertex(to_local(corner))
			lines.surface_add_vertex(to_local(end))
	lines.surface_end()
	_marker.mesh = lines
