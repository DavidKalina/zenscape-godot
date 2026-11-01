extends SkeletonModifier3D
## The stomper's legs (stomper.gd): after the clip has posed the skeleton, each
## ankle is laid on its world goal by a two-bone solve, the knee bending the way
## the clip bends it. The clip's own twist and foot pitch are kept.

const BONES := [["thigh.L","shin.L","foot.L"],["thigh.R","shin.R","foot.R"]]

## The ankles' goals, world, and each foot's tilt to its ground (skeleton space).
var goals: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var tilts: Array[Quaternion] = [Quaternion.IDENTITY,Quaternion.IDENTITY]
var _ids: Array[PackedInt32Array] = []
var _upper := PackedFloat32Array()
var _lower := PackedFloat32Array()

## Its bones and their lengths, from the rest pose.
func bind(sk: Skeleton3D) -> void:
	for side in range(2):
		var ids := PackedInt32Array()
		for n: String in BONES[side]: ids.append(sk.find_bone(n))
		_ids.append(ids)
		_upper.append(sk.get_bone_global_rest(ids[0]).origin.distance_to(sk.get_bone_global_rest(ids[1]).origin))
		_lower.append(sk.get_bone_global_rest(ids[1]).origin.distance_to(sk.get_bone_global_rest(ids[2]).origin))

## The longest a leg goes, in the model's metres.
func reach(side: int) -> float:
	return _upper[side]+_lower[side]

func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or _ids.is_empty(): return
	var inv := sk.global_transform.affine_inverse()
	for side in range(2): _lay(sk,side,inv*goals[side],tilts[side])

func _lay(sk: Skeleton3D, side: int, goal: Vector3, tilt: Quaternion) -> void:
	var ids := _ids[side]
	var a := sk.get_bone_global_pose(ids[0])
	var b := sk.get_bone_global_pose(ids[1])
	var c := sk.get_bone_global_pose(ids[2])
	var la := _upper[side]
	var lb := _lower[side]
	var hip := a.origin
	var to := goal-hip
	var d := clampf(to.length(),absf(la-lb)+0.01,(la+lb)*0.999)
	var way := to.normalized()
	# The bend: the clip's knee off the hip-ankle line, and always some forward
	# (the model faces -Z), so a straight clip leg keeps its side.
	var bend := b.origin-hip
	bend -= way*bend.dot(way)
	var ahead := Vector3(0.0,0.0,-1.0)
	ahead -= way*ahead.dot(way)
	var pole := (bend+ahead*0.4).normalized()
	var along := (la*la-lb*lb+d*d)/(2.0*d)
	var knee := hip+way*along+pole*sqrt(maxf(la*la-along*along,0.0))
	var ankle := hip+way*d
	sk.set_bone_global_pose(ids[0],Transform3D(_aimed(a.basis,b.origin-a.origin,knee-hip),hip))
	sk.set_bone_global_pose(ids[1],Transform3D(_aimed(b.basis,c.origin-b.origin,ankle-knee),knee))
	sk.set_bone_global_pose(ids[2],Transform3D(Basis(tilt)*c.basis,ankle))

## `basis` turned by the least that takes `from` to `to`.
func _aimed(basis: Basis, from: Vector3, to: Vector3) -> Basis:
	var f := from.normalized()
	var t := to.normalized()
	if f.dot(t) > 0.99999: return basis
	return Basis(Quaternion(f,t))*basis
