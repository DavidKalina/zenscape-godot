extends RefCounted
## Scene geometry visibility shared by camper sightings and refuge selection.
## Everything is held in the world's document-local frame, so a lamp on an
## island turned 180 degrees still asks about the ground under its own feet.
var world: CampsiteWorld
var parts: Array[Dictionary] = []
var faces_by_mesh := {}
func refresh(camp_world: CampsiteWorld) -> void:
	world = camp_world
	parts.clear()
	faces_by_mesh.clear()
	var into := world.frame.affine_inverse()
	# Use the authored placement recipe, avoiding GPU instance readback (which
	# returns identity transforms with Godot's headless renderer).
	if world.content != null:
		for batch in world.content._batches:
			for recipe in world.content._sources.get(batch.get_meta("part"),[]):
				if recipe.item == null: continue
				var pose: Variant = world.content._instance_transform(recipe)
				if pose != null: _add(batch.multimesh.mesh,into*batch.global_transform*pose)
	if world.landmarks != null:
		for record in world.data.objects:
			if record.asset not in NativeGardenLandmarks.KINDS: continue
			var node := world.landmarks.get_node_or_null("%s_%d" % [record.asset,record.id])
			if node == null: continue
			for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false): _add(mesh.mesh,into*mesh.global_transform)
	if world.reference != null and not world.data.blank:
		for node in world.reference.get_children():
			if not node is Node3D or not node.visible: continue
			if node is MultiMeshInstance3D:
				for i in range(node.multimesh.instance_count): _add(node.multimesh.mesh,into*node.global_transform*node.multimesh.get_instance_transform(i))
			elif node is MeshInstance3D and node.name != "terrain": _add(node.mesh,into*node.global_transform)
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
		var h: Variant = world.data.ground_height(Vector2(p.x,p.z))
		if h != null and float(h)>p.y: return true
	return false
## `feet` is document-local; the lamp is a scene node and is brought into the
## same frame here.
func exposure(lamp: SpotLight3D, feet: Vector3, height := 2.0, cone := true, require_light := true) -> float:
	if require_light and cone and not lamp.visible: return 0
	var into := world.frame.affine_inverse()
	var eye: Vector3 = into*lamp.global_position
	var aim: Vector3 = (into.basis*(-lamp.global_basis.z)).normalized()
	var samples := 0.0
	for fraction in [0.4,0.7,0.92]:
		var point: Vector3 = feet+Vector3.UP*height*fraction
		var direction: Vector3 = point-eye
		if direction.length()>lamp.spot_range: continue
		if cone and direction.normalized().dot(aim)<cos(deg_to_rad(lamp.spot_angle)): continue
		if not blocked(eye,point): samples += 1
	return samples/3
