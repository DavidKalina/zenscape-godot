extends SkeletonModifier3D
## The rune knight's procedural layers on top of his glb clips (trunk task 15):
##
## - Feet on the real ground: each foot's spot is raycast down; a foot over
##   lower ground reaches down to it (the hips sink so the leg can), a foot
##   over higher ground bends up. Two-bone IK, thigh -> shin -> foot, the knee
##   kept in the clip's own plane, the foot's clip rotation kept.
## - Head and chest to the real target: `aim` (world point, or INF) turns the
##   head and some of the chest toward it, in yaw and pitch, on clips that
##   face you; the chest's share is larger while catching (his hands go to the
##   shot) and gathering.
##
## Weights ease in and out, so nothing pops between clips.

## The body (rune_knight_body.gd) this rides: its clip and its base.
var body: Node3D
## Where he looks (world), INF for none.
var aim := Vector3.INF

const GROUND_MASK := 1 | (1 << 11)
## A foot reaches at most this far (of his height) down or up for the ground.
const REACH_DOWN := 0.18
const REACH_UP := 0.12
## How fast a foot's ground offset follows (1/s).
const FOOT_EASE := 14.0
## Clips with his feet planted on the ground.
const GROUNDED := ["idle","walk","turn","strafe","notice","gather","slash","throw","catch",
	"return","stagger","reel","skid","teeter","kneel","crumble"]
## Aim: clips that face you, with the chest's share; caps (rad).
const AIM_CLIPS := {"idle":0.3,"walk":0.25,"turn":0.25,"strafe":0.5,"notice":0.35,"gather":0.45,
	"throw":0.3,"slash":0.15,"catch":0.6,"return":0.3}
const AIM_YAW := 0.7
const AIM_PITCH := 0.4
const AIM_EASE := 5.0

var _legs := []   # [[thigh, shin, foot], ...] bone ids, left then right
var _head := -1
var _chest := -1
var _hips := -1
var _drop := [0.0,0.0]
var _foot_w := 0.0
var _aim_w := 0.0
var _aim_yaw := 0.0
var _aim_pitch := 0.0
var _chest_share := 0.3

func bind(skel: Skeleton3D) -> void:
	_legs = []
	for sd in ["l","r"]:
		_legs.append([skel.find_bone("thigh_"+sd),skel.find_bone("shin_"+sd),skel.find_bone("foot_"+sd)])
	_head = skel.find_bone("head")
	_chest = skel.find_bone("chest")
	_hips = skel.find_bone("hips")

func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null or body == null or _legs.is_empty() or not is_inside_tree(): return
	var dt := get_process_delta_time()
	var clip: String = body.get("clip")
	_foot_w = move_toward(_foot_w,1.0 if clip in GROUNDED and not body.get("broken") else 0.0,dt*4.0)
	_aim_layer(skel,clip,dt)
	if _foot_w > 0.001: _feet_layer(skel,dt)

# --- Feet ---------------------------------------------------------------------------

func _feet_layer(skel: Skeleton3D, dt: float) -> void:
	var tall: float = body.get("tall")
	var xf := skel.global_transform
	var base_y := body.global_position.y
	var space := skel.get_world_3d().direct_space_state
	var want := [0.0,0.0]
	for i in range(2):
		var foot: int = _legs[i][2]
		if foot < 0: continue
		var at: Vector3 = xf*skel.get_bone_global_pose(foot).origin
		var ray := PhysicsRayQueryParameters3D.create(Vector3(at.x,base_y+REACH_UP*tall+0.3,at.z),Vector3(at.x,base_y-REACH_DOWN*tall-0.3,at.z),GROUND_MASK)
		var hit := space.intersect_ray(ray)
		if not hit.is_empty():
			want[i] = clampf((hit.position as Vector3).y-base_y,-REACH_DOWN*tall,REACH_UP*tall)
		_drop[i] = lerpf(_drop[i],want[i],clampf(dt*FOOT_EASE,0.0,1.0))
	var d0: float = _drop[0]*_foot_w
	var d1: float = _drop[1]*_foot_w
	# Targets in the skeleton's space (its up may be scaled/turned: go via world).
	var inv := xf.affine_inverse()
	var targets := []
	for i in range(2):
		var foot: int = _legs[i][2]
		var at: Vector3 = xf*skel.get_bone_global_pose(foot).origin
		targets.append(inv*(at+Vector3.UP*(d0 if i == 0 else d1)))
	# The hips sink by the lower foot's drop, so that leg can reach.
	var sink := minf(minf(d0,d1),0.0)
	if sink < 0.0 and _hips >= 0:
		var hp := skel.get_bone_global_pose(_hips)
		hp.origin += inv.basis*(Vector3.UP*sink)
		skel.set_bone_global_pose(_hips,hp)
	for i in range(2):
		_two_bone(skel,_legs[i][0],_legs[i][1],_legs[i][2],targets[i])

## Thigh -> shin -> foot to `t` (skeleton space), the knee in its own plane.
func _two_bone(skel: Skeleton3D, a: int, b: int, c: int, t: Vector3) -> void:
	if a < 0 or b < 0 or c < 0: return
	var pa := skel.get_bone_global_pose(a)
	var pb := skel.get_bone_global_pose(b)
	var pc := skel.get_bone_global_pose(c)
	var foot_basis := pc.basis
	var h := pa.origin
	var k := pb.origin
	var f := pc.origin
	var l1 := h.distance_to(k)
	var l2 := k.distance_to(f)
	if l1 < 1e-4 or l2 < 1e-4: return
	var to_t := t-h
	var dist := clampf(to_t.length(),absf(l1-l2)+1e-3,(l1+l2)*0.999)
	var dir := to_t.normalized()
	var pole := (k-h)-(f-h).normalized()*(k-h).dot((f-h).normalized())
	pole = pole-dir*pole.dot(dir)
	if pole.length() < 1e-4: return
	pole = pole.normalized()
	var along := (l1*l1+dist*dist-l2*l2)/(2.0*dist)
	var up := sqrt(maxf(l1*l1-along*along,0.0))
	var k2 := h+dir*along+pole*up
	var f2 := h+dir*dist
	var qa := Quaternion((k-h).normalized(),(k2-h).normalized())
	pa.basis = Basis(qa)*pa.basis
	skel.set_bone_global_pose(a,pa)
	pb = skel.get_bone_global_pose(b)
	var cur_f: Vector3 = skel.get_bone_global_pose(c).origin
	var qb := Quaternion((cur_f-pb.origin).normalized(),(f2-pb.origin).normalized())
	pb.basis = Basis(qb)*pb.basis
	skel.set_bone_global_pose(b,pb)
	pc = skel.get_bone_global_pose(c)
	pc.basis = foot_basis
	skel.set_bone_global_pose(c,pc)

# --- Aim ----------------------------------------------------------------------------

func _aim_layer(skel: Skeleton3D, clip: String, dt: float) -> void:
	var on: bool = aim != Vector3.INF and AIM_CLIPS.has(clip) and not body.get("broken")
	_aim_w = move_toward(_aim_w,1.0 if on else 0.0,dt*3.0)
	if on:
		_chest_share = move_toward(_chest_share,float(AIM_CLIPS[clip]),dt*2.0)
		var head_at: Vector3 = skel.global_transform*skel.get_bone_global_pose(_head).origin if _head >= 0 else body.global_position
		# The way he faces: his look's -Z (the mind's forward), flat.
		var face: Node3D = body.get("look")
		var fwd := -face.global_transform.basis.z
		fwd = Vector3(fwd.x,0.0,fwd.z).normalized()
		var off := aim-head_at
		var flat := Vector3(off.x,0.0,off.z)
		var yaw := clampf(fwd.signed_angle_to(flat,Vector3.UP) if flat.length() > 0.01 else 0.0,-AIM_YAW,AIM_YAW)
		var pitch := clampf(atan2(off.y,maxf(flat.length(),0.01)),-AIM_PITCH,AIM_PITCH)
		var k := clampf(dt*AIM_EASE,0.0,1.0)
		_aim_yaw = lerpf(_aim_yaw,yaw,k)
		_aim_pitch = lerpf(_aim_pitch,pitch,k)
	if _aim_w < 0.001: return
	var yaw_t := _aim_yaw*_aim_w
	var pitch_t := _aim_pitch*_aim_w
	_turn(skel,_chest,yaw_t*_chest_share,pitch_t*_chest_share)
	_turn(skel,_head,yaw_t*(1.0-_chest_share),pitch_t*(1.0-_chest_share))

## Turn a bone (and so its children) by yaw about the world's up and pitch
## about his right (positive raises his face), keeping its origin.
func _turn(skel: Skeleton3D, bone: int, yaw: float, pitch: float) -> void:
	if bone < 0 or (absf(yaw) < 1e-4 and absf(pitch) < 1e-4): return
	var face: Node3D = body.get("look")
	var right := face.global_transform.basis.x
	right = Vector3(right.x,0.0,right.z).normalized()
	var w := Basis(Vector3.UP,yaw)*Basis(right,pitch)
	var b := skel.global_transform.basis.orthonormalized()
	var p := skel.get_bone_global_pose(bone)
	p.basis = (b.inverse()*w*b)*p.basis
	skel.set_bone_global_pose(bone,p)
