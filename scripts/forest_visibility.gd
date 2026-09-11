extends RefCounted
## Scene geometry visibility shared by camper sightings and refuge selection.
var scene: Node
var parts: Array[Dictionary] = []
var faces_by_mesh := {}
func refresh(owner_scene: Node) -> void:
	scene = owner_scene
	parts.clear()
	faces_by_mesh.clear()
	# Use the authored placement recipe, avoiding GPU instance readback (which
	# returns identity transforms with Godot's headless renderer).
	var editor: NativeChunkEditor = scene._chunk_editor
	for batch in editor.content._batches:
		for recipe in editor.content._sources.get(batch.get_meta("part"),[]):
			if recipe.item == null: continue
			var pose: Variant = editor.content._instance_transform(recipe)
			if pose != null: _add(batch.multimesh.mesh,batch.global_transform*pose)
	for record in editor.data.objects:
		if record.asset not in NativeGardenLandmarks.KINDS: continue
		for part in editor.selection.parts(int(record.id)): _add(part.mesh,part.transform)
	if not scene._chunk_editor.data.blank:
		for node in scene.get_node("Reference").get_children():
			if not node is Node3D or not node.visible: continue
			if node is MultiMeshInstance3D:
				for i in range(node.multimesh.instance_count): _add(node.multimesh.mesh,node.global_transform*node.multimesh.get_instance_transform(i))
			elif node is MeshInstance3D and node.name != "terrain": _add(node.mesh,node.global_transform)
func _add(mesh: Mesh, pose: Transform3D) -> void:
	var id := mesh.get_instance_id()
	if not faces_by_mesh.has(id): faces_by_mesh[id] = mesh.get_faces()
	parts.append({"inverse":pose.affine_inverse(),"bounds":mesh.get_aabb(),"faces":faces_by_mesh[id]})
func blocked(from: Vector3,to: Vector3) -> bool:
	for part in parts:
		var a: Vector3 = part.inverse*from
		var b: Vector3 = part.inverse*to
		if part.bounds.intersects_segment(a,b) == null: continue
		var faces: PackedVector3Array = part.faces
		for i in range(0,faces.size(),3):
			if Geometry3D.segment_intersects_triangle(a,b,faces[i],faces[i+1],faces[i+2]) != null: return true
	for i in range(1,32):
		var p := from.lerp(to,float(i)/32)
		var h: Variant = scene._chunk_editor.data.ground_height(Vector2(p.x,p.z))
		if h != null and float(h)>p.y: return true
	return false
func exposure(lamp: SpotLight3D, feet: Vector3, height := 2.0, cone := true, require_light := true) -> float:
	if require_light and cone and not lamp.visible: return 0
	var samples := 0.0
	for fraction in [0.4,0.7,0.92]:
		var point: Vector3 = feet+Vector3.UP*height*fraction
		var direction: Vector3 = point-lamp.global_position
		if direction.length()>lamp.spot_range: continue
		if cone and direction.normalized().dot(-lamp.global_basis.z)<cos(deg_to_rad(lamp.spot_angle)): continue
		if not blocked(lamp.global_position,point): samples += 1
	return samples/3
