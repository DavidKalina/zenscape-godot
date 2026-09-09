extends RefCounted
## Conservative head clearance for a skinned tree peek. The upper-body pose
## yields before the head can enter bark; feet and hand contacts keep their owners.
var _head_points := PackedVector3Array()
var last_correction := Vector3.ZERO

func _cache(actor: CreatureActor) -> void:
	if not _head_points.is_empty(): return
	var skeleton := actor.skeleton
	var head := skeleton.find_bone("Head")
	if head<0: return
	for node: MeshInstance3D in actor.actor.find_children("*","MeshInstance3D",true,false):
		if "_n5_" not in node.name: continue
		var box := node.mesh.get_aabb().grow(0.015)
		var into_head := skeleton.get_bone_global_rest(head).affine_inverse()*skeleton.global_transform.affine_inverse()*node.global_transform
		for corner in range(8): _head_points.append(into_head*box.get_endpoint(corner))

func head_bounds(actor: CreatureActor) -> AABB:
	_cache(actor)
	if _head_points.is_empty(): return AABB()
	var pose := actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone("Head"))
	var result := AABB(pose*_head_points[0],Vector3.ZERO)
	for point in _head_points: result = result.expand(pose*point)
	return result

func offset_upper_body(actor: CreatureActor, world_offset: Vector3) -> void:
	var skeleton := actor.skeleton
	var spine := skeleton.find_bone("Spine")
	var parent := skeleton.get_bone_parent(spine)
	var parent_basis := skeleton.global_basis*skeleton.get_bone_global_pose(parent).basis
	skeleton.set_bone_pose_position(spine,skeleton.get_bone_pose_position(spine)+parent_basis.inverse()*world_offset)
	skeleton.force_update_all_bone_transforms()

func correct_head_clearance(actor: CreatureActor, motion: Dictionary) -> void:
	last_correction = Vector3.ZERO
	if not motion.has("tree_center"): return
	var box := head_bounds(actor)
	var center: Vector3 = motion.tree_center
	if box.size == Vector3.ZERO or box.position.y>float(motion.tree_top) or box.end.y<center.y: return
	var closest := Vector2(clampf(center.x,box.position.x,box.end.x),clampf(center.z,box.position.z,box.end.z))
	var away := closest-Vector2(center.x,center.z)
	var clearance: float = motion.tree_radius+0.035
	var distance := away.length()
	if distance>=clearance: return
	if distance<0.0001: away = -Vector2(actor.global_basis.z.x,actor.global_basis.z.z).normalized()
	else: away /= distance
	last_correction = Vector3(away.x,0,away.y)*(clearance-distance)
	offset_upper_body(actor,last_correction)
