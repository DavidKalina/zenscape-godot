class_name NativePlayCollisions
extends Node3D
## Static play collision is rebuilt when authored terrain/objects change, never
## per frame. Foliage and water stay permeable; solid trunks/stones stop creatures.
const CATALOG = preload("res://scripts/native_asset_catalog.gd")
const POSE = preload("res://scripts/native_object_pose.gd")
var _bounds := {}
var _arch_faces := PackedVector3Array()
var _terrain_body: StaticBody3D
var _standing_query: PhysicsShapeQueryParameters3D

func rebuild(data: NativeTerrainData) -> void:
	# Disable old bodies immediately, before their deferred deletion, so a rebuild
	# cannot leave a frame of duplicate colliders in the physics world.
	for old in get_children():
		if old is CollisionObject3D:
			old.collision_layer = 0
			old.collision_mask = 0
		remove_child(old)
		old.queue_free()
	if _bounds.is_empty(): _load_bounds()
	var terrain := data.build_mesh().create_trimesh_shape()
	terrain.backface_collision = true
	_terrain_body = _add_shape("Terrain",terrain)
	for item: Dictionary in data.objects:
		var kind: String = item.asset
		var basis := POSE.decode_basis(item.pose) if item.has("pose") else Basis(Vector3.UP,float(item.angle)).scaled(Vector3.ONE*float(item.scale))
		var placement := Transform3D(basis,data.object_position(item))
		if kind == "arch":
			var shape := ConcavePolygonShape3D.new()
			shape.backface_collision = true
			var vertices := PackedVector3Array()
			for vertex in _arch_faces: vertices.append(placement*vertex)
			shape.set_faces(vertices)
			_add_shape("Arch_%d" % item.id,shape)
		elif _bounds.has(kind):
			var bounds: AABB = _bounds[kind]
			if kind == "rock": placement.origin.y += 0.24*float(item.scale)
			var corners := PackedVector3Array()
			for i in range(8): corners.append(placement*bounds.get_endpoint(i))
			var shape := ConvexPolygonShape3D.new()
			shape.points = corners
			_add_shape("Prop_%d" % item.id,shape)

## Feet are world coordinates. Ignore terrain contact here: the caller checks
## ground validity/slope, while this rejects intersecting authored solid props.
func can_stand(feet: Vector3) -> bool:
	if not feet.is_finite() or not is_inside_tree(): return false
	if _standing_query == null:
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.5
		capsule.height = 2.3
		_standing_query = PhysicsShapeQueryParameters3D.new()
		_standing_query.shape = capsule
		_standing_query.collision_mask = 1
		_standing_query.margin = 0.015
	_standing_query.transform = Transform3D(Basis.IDENTITY,feet+Vector3.UP*1.15)
	_standing_query.exclude = [_terrain_body.get_rid()] if is_instance_valid(_terrain_body) else []
	return get_world_3d().direct_space_state.intersect_shape(_standing_query,1).is_empty()

func _add_shape(label: String, shape: Shape3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = 1
	body.collision_mask = 2
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body

func _load_bounds() -> void:
	var source: Node3D = preload("res://assets/zen_reference/geometry.scn").instantiate()
	var trunk: MultiMeshInstance3D = source.get_node("mesh-8")
	_bounds.tree = trunk.multimesh.mesh.get_aabb()
	_bounds.rock = AABB(Vector3(-0.6,-0.425,-0.6),Vector3(1.2,0.85,1.2))
	for kind in ["broadleaf","log","stump","snag","boulder_1","boulder_2","boulder_3","boulder_4"]:
		# The first broadleaf part is its solid trunk, not the canopy.
		var node_name: String = CATALOG.PARTS[kind][0]
		var original: Node3D = source.get_node(node_name)
		var mesh: Mesh = original.multimesh.mesh if original is MultiMeshInstance3D else original.mesh
		_bounds[kind] = CATALOG.part_pose(kind+":"+node_name,original,mesh)*mesh.get_aabb()
	var arch: MeshInstance3D = source.get_node("landmark-arch")
	var arch_bounds := arch.mesh.get_aabb()
	var offset := -Vector3(arch_bounds.get_center().x,arch_bounds.position.y,arch_bounds.get_center().z)
	for point in arch.mesh.get_faces(): _arch_faces.append(point+offset)
	source.free()
	# The encounter tree uses a deliberately forgiving trunk proxy: branches and
	# its hollow remain visual. Other authored proportions are applied above.
	_bounds.bigfoot_tree = AABB(Vector3(-0.6,0,-0.6),Vector3(1.2,5.0,1.2))
