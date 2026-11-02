extends SkeletonModifier3D
## The stomper's lift pose (head_lift.gd), after the legs: the back bent and turned,
## then each arm laid on its world goal by a two-bone solve. Procedural and rough,
## a placeholder for an authored clip. The capsules (stomper_solid.gd) read the
## bones after this, so they follow.

const ARMS := [["upper_arm.L","forearm.L","hand.L"],["upper_arm.R","forearm.R","hand.R"]]

## How far the back bends forward and turns to his left (rad), split over two bones.
var stoop := 0.0
var twist := 0.0
## 0: the clip's arms; 1: on `goals` (each wrist, world).
var arms := 0.0
var goals: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var _spine := -1
var _chest := -1
var _ids: Array[PackedInt32Array] = []
var _upper := PackedFloat32Array()
var _lower := PackedFloat32Array()

func bind(sk: Skeleton3D) -> void:
	_spine = sk.find_bone("spine")
	_chest = sk.find_bone("chest")
	for side in range(2):
		var ids := PackedInt32Array()
		for n: String in ARMS[side]: ids.append(sk.find_bone(n))
		_ids.append(ids)
		_upper.append(sk.get_bone_global_rest(ids[0]).origin.distance_to(sk.get_bone_global_rest(ids[1]).origin))
		_lower.append(sk.get_bone_global_rest(ids[1]).origin.distance_to(sk.get_bone_global_rest(ids[2]).origin))

## The longest an arm goes, in the model's metres.
func reach() -> float:
	return _upper[0]+_lower[0]

func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or _ids.is_empty() or (stoop == 0.0 and twist == 0.0 and arms == 0.0): return
	var bend := Basis(Quaternion(Vector3.UP,twist*0.5)*Quaternion(Vector3.RIGHT,-stoop*0.5))
	for id: int in [_spine,_chest]:
		var t := sk.get_bone_global_pose(id)
		sk.set_bone_global_pose(id,Transform3D(bend*t.basis,t.origin))
	if arms <= 0.0: return
	var inv := sk.global_transform.affine_inverse()
	for side in range(2): _lay(sk,side,inv*goals[side])

func _lay(sk: Skeleton3D, side: int, goal: Vector3) -> void:
	var ids := _ids[side]
	var a := sk.get_bone_global_pose(ids[0])
	var b := sk.get_bone_global_pose(ids[1])
	var c := sk.get_bone_global_pose(ids[2])
	var la := _upper[side]
	var lb := _lower[side]
	var shoulder := a.origin
	var to := c.origin.lerp(goal,arms)-shoulder
	var d := clampf(to.length(),absf(la-lb)+0.01,(la+lb)*0.999)
	var way := to.normalized()
	# The elbow out to his side and down.
	var pole := Vector3(-1.0 if side == 0 else 1.0,-0.8,0.3)
	pole = (pole-way*pole.dot(way)).normalized()
	var along := (la*la-lb*lb+d*d)/(2.0*d)
	var elbow := shoulder+way*along+pole*sqrt(maxf(la*la-along*along,0.0))
	var wrist := shoulder+way*d
	sk.set_bone_global_pose(ids[0],Transform3D(_aimed(a.basis,b.origin-a.origin,elbow-shoulder),shoulder))
	sk.set_bone_global_pose(ids[1],Transform3D(_aimed(b.basis,c.origin-b.origin,wrist-elbow),elbow))
	sk.set_bone_global_pose(ids[2],Transform3D(_aimed(c.basis,c.origin-b.origin,wrist-elbow)*Basis.IDENTITY,wrist))

func _aimed(basis: Basis, from: Vector3, to: Vector3) -> Basis:
	var f := from.normalized()
	var t := to.normalized()
	if f.dot(t) > 0.99999: return basis
	return Basis(Quaternion(f,t))*basis
