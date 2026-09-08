extends RefCounted
## Two-bone correction layered after authored animation, used only near contact.
## The clip still owns the performance; targets compensate for prop/shore height.
static func palm(skeleton: Skeleton3D, side := "R") -> Vector3:
	var hand := skeleton.find_bone("Hand_"+side)
	return skeleton.to_global(skeleton.get_bone_global_pose(hand)*Vector3(0,0.10,0))

static func apply(skeleton: Skeleton3D, target: Vector3, weight: float, side := "R") -> void:
	if weight <= 0.0: return
	var upper := skeleton.find_bone("UpperArm_"+side)
	var lower := skeleton.find_bone("Forearm_"+side)
	var hand := skeleton.find_bone("Hand_"+side)
	if mini(upper,mini(lower,hand))<0: return
	var goal := skeleton.to_local(target)
	# Recompute wrist offset after rotating the arm so the palm, not wrist,
	# reaches the object. Two passes converge for this short palm offset.
	for pass_index in range(2):
		skeleton.force_update_all_bone_transforms()
		var shoulder := skeleton.get_bone_global_pose(upper).origin
		var elbow := skeleton.get_bone_global_pose(lower).origin
		var wrist_pose := skeleton.get_bone_global_pose(hand)
		var wrist := wrist_pose.origin
		var destination := goal-wrist_pose.basis*Vector3(0,0.10,0)
		var a := shoulder.distance_to(elbow)
		var b := elbow.distance_to(wrist)
		var offset := destination-shoulder
		var distance := clampf(offset.length(),absf(a-b)+0.001,a+b-0.001)
		var direction := offset.normalized()
		var bend := (elbow-shoulder)-direction*(elbow-shoulder).dot(direction)
		if bend.length_squared()<0.0001: bend = direction.cross(Vector3.UP)
		if bend.length_squared()<0.0001: bend = Vector3.RIGHT
		bend = bend.normalized()
		var along := (a*a+distance*distance-b*b)/(2.0*distance)
		var elbow_goal := shoulder+direction*along+bend*sqrt(maxf(0.0,a*a-along*along))
		_rotate(skeleton,upper,elbow-shoulder,elbow_goal-shoulder,weight)
		skeleton.force_update_all_bone_transforms()
		elbow = skeleton.get_bone_global_pose(lower).origin
		wrist = skeleton.get_bone_global_pose(hand).origin
		_rotate(skeleton,lower,wrist-elbow,destination-elbow,weight)

static func _rotate(skeleton: Skeleton3D, bone: int, from: Vector3, to: Vector3, weight: float) -> void:
	if from.length_squared()<0.000001 or to.length_squared()<0.000001: return
	var correction := Quaternion.IDENTITY.slerp(Quaternion(from.normalized(),to.normalized()),clampf(weight,0.0,1.0))
	var current := skeleton.get_bone_global_pose(bone)
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var desired := parent_basis.inverse()*Basis(correction)*current.basis
	skeleton.set_bone_pose_rotation(bone,desired.orthonormalized().get_rotation_quaternion())
