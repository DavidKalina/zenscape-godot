extends RefCounted
## The dig's motion (docs/design/dig/spec-dig.md, loop `dig`), procedural on
## the pilot's rig: a STAND-IN until a Blender clip comes with the lock-in
## (AGENTS.md, Animation). Keyed poses of the spade in his frame (where its
## tip is, how its shaft leans), eased between; his body follows: the knees
## bend (the hips sink so the boots stay put), the chest and head bow and
## straighten, and both mitts reach the spade by two-bone IK, the right on
## the D grip, the left down the shaft.
##
## His frame: x his right, y up, z behind him (so ahead is -z), metres at
## size 1, from his feet.
##
## Soil: drawn off his back, raised (anticipation, a held beat at the top),
## driven down (the bite), levered back, the load flung off to his right;
## twice; a look at it; back on his back. Stone: raised and driven, the clank
## throws it back up and him with it, a wobble, back on his back.

const SpadeFigure = preload("res://scripts/dig/spade_figure.gd")

enum {LINEAR, IN, OUT, INOUT}

## [time, tip, lean (deg, the grip back toward him), side (deg, the tip
## swung to his right), twist (deg, about the shaft), hunch (deg, chest
## bowed), crouch (0 to 1), ease into this key].
const SOIL := [
	[0.16,Vector3(0.10,0.03,-0.50),26.0,0.0,0.0,14.0,0.35,OUT],
	[0.36,Vector3(0.13,0.36,-0.34),50.0,-6.0,0.0,-8.0,0.0,INOUT],
	[0.44,Vector3(0.13,0.39,-0.33),53.0,-7.0,0.0,-10.0,0.0,OUT],
	[0.50,Vector3(0.10,-0.10,-0.52),16.0,0.0,0.0,28.0,1.0,IN],
	[0.62,Vector3(0.10,-0.06,-0.47),44.0,0.0,0.0,20.0,0.75,INOUT],
	[0.74,Vector3(0.44,0.30,-0.36),38.0,38.0,55.0,8.0,0.3,OUT],
	[0.80,Vector3(0.46,0.32,-0.34),38.0,40.0,60.0,8.0,0.3,OUT],
	[0.92,Vector3(0.14,0.33,-0.36),48.0,-5.0,0.0,-6.0,0.0,INOUT],
	[0.98,Vector3(0.10,-0.10,-0.52),16.0,0.0,0.0,28.0,1.0,IN],
	[1.09,Vector3(0.10,-0.06,-0.47),44.0,0.0,0.0,20.0,0.75,INOUT],
	[1.21,Vector3(0.44,0.30,-0.36),38.0,38.0,55.0,8.0,0.3,OUT],
	[1.28,Vector3(0.46,0.32,-0.34),38.0,40.0,60.0,8.0,0.3,OUT],
	[1.44,Vector3(0.10,0.03,-0.48),24.0,0.0,0.0,16.0,0.3,INOUT],
	[1.62,Vector3(0.10,0.03,-0.48),24.0,0.0,0.0,18.0,0.3,LINEAR],
]
## The moments: the blade bites (dirt kicked up, the thunk) and the load
## flies (clods, the crumble).
const SOIL_EVENTS := [[0.50,"bite"],[0.76,"throw"],[0.98,"bite"],[1.23,"throw"]]
const STONE := [
	[0.16,Vector3(0.10,0.03,-0.50),26.0,0.0,0.0,14.0,0.35,OUT],
	[0.36,Vector3(0.13,0.36,-0.34),50.0,-6.0,0.0,-8.0,0.0,INOUT],
	[0.44,Vector3(0.13,0.39,-0.33),53.0,-7.0,0.0,-10.0,0.0,OUT],
	[0.50,Vector3(0.10,0.0,-0.52),18.0,0.0,0.0,26.0,0.9,IN],
	[0.60,Vector3(0.20,0.36,-0.38),62.0,-14.0,-10.0,-14.0,0.0,OUT],
	[0.74,Vector3(0.08,0.12,-0.46),36.0,6.0,4.0,8.0,0.2,INOUT],
	[0.84,Vector3(0.12,0.16,-0.45),40.0,-3.0,0.0,4.0,0.1,INOUT],
	[1.02,Vector3(0.10,0.10,-0.46),34.0,0.0,0.0,6.0,0.15,INOUT],
]
const STONE_EVENTS := [[0.50,"clank"]]
## Off his back before the first key, back on after the last.
const STOW := 0.18
## Knees: the thigh forward, the shin back twice that, at crouch 1 (deg).
const KNEE := 34.0
## The hunch's share on the chest; the rest bows the head.
const HEAD_SHARE := 0.45

var kind := "soil"
var keys: Array = SOIL
var events: Array = SOIL_EVENTS
var length := 0.0
## His frame (world), from the feet, scaled to his size.
var frame := Transform3D.IDENTITY
var size := 1.0

func _init(dig_kind: String, at: Transform3D, s: float) -> void:
	kind = dig_kind
	keys = SOIL if kind == "soil" else STONE
	events = SOIL_EVENTS if kind == "soil" else STONE_EVENTS
	frame = at
	size = s
	length = float(keys[-1][0])+STOW

## The pose at `t`: {spade (world xform, scaled), hunch, crouch, held (0
## to 1: the mitts on it)}; `back` is the spade's xform on his back now.
func pose(t: float, back: Transform3D) -> Dictionary:
	var first: Array = keys[0]
	var last: Array = keys[-1]
	if t <= float(first[0]):
		var u := smoothstep(0.0,1.0,t/float(first[0]))
		var p := _key_pose(first)
		p.spade = back.interpolate_with(p.spade,u)
		p.hunch *= u
		p.crouch *= u
		p.held = u
		return p
	var end := float(last[0])
	if t >= end:
		var u := smoothstep(0.0,1.0,clampf((t-end)/STOW,0.0,1.0))
		var p := _key_pose(last)
		p.spade = (p.spade as Transform3D).interpolate_with(back,u)
		p.hunch *= 1.0-u
		p.crouch *= 1.0-u
		p.held = 1.0-u
		return p
	for i in range(keys.size()-1):
		var a: Array = keys[i]
		var b: Array = keys[i+1]
		if t < float(b[0]):
			var u := _ease((t-float(a[0]))/(float(b[0])-float(a[0])),int(b[7]))
			var mixed := []
			for j in range(1,7):
				mixed.append(lerp(a[j],b[j],u))
			mixed.push_front(t)
			mixed.append(LINEAR)
			return _key_pose(mixed)
	return _key_pose(last)

static func _ease(u: float, how: int) -> float:
	u = clampf(u,0.0,1.0)
	match how:
		IN: return u*u*u
		OUT: return 1.0-pow(1.0-u,3.0)
		INOUT: return smoothstep(0.0,1.0,u)
	return u

func _key_pose(k: Array) -> Dictionary:
	var lean := deg_to_rad(float(k[2]))
	var side := deg_to_rad(float(k[3]))
	var twist := deg_to_rad(float(k[4]))
	var b := Basis(Vector3.BACK,side)*Basis(Vector3.RIGHT,lean)*Basis(Vector3.UP,twist)
	var world := Transform3D(frame.basis*b.scaled(Vector3.ONE*size),frame*((k[1] as Vector3)*size))
	return {"spade":world,"hunch":float(k[5]),"crouch":float(k[6]),"held":1.0}

## The events crossed going from `was` to `t`.
func crossed(was: float, t: float) -> Array:
	var out := []
	for e: Array in events:
		if float(e[0]) > was and float(e[0]) <= t: out.append(e[1])
	return out

# --- The body ---------------------------------------------------------------------

## His body to `p` (after the figure's own drive this frame): knees, chest,
## head, mitts.
static func apply(body: Node3D, p: Dictionary, frame_basis: Basis) -> void:
	var skel: Skeleton3D = body.get("_skeleton")
	if skel == null: return
	var right := frame_basis.x.normalized()
	_crouch(body,skel,right,float(p.crouch))
	var hunch := deg_to_rad(float(p.hunch))
	var spine := skel.find_bone("spine")
	var chest := skel.find_bone("chest")
	var head := skel.find_bone("head")
	if spine >= 0:
		_turn(skel,spine,right,-hunch*0.4)
		_turn(skel,chest,right,-hunch*(0.6-HEAD_SHARE*0.5))
	else: _turn(skel,chest,right,-hunch*(1.0-HEAD_SHARE*0.5))
	if head >= 0: _turn(skel,head,right,-hunch*HEAD_SHARE)
	var held := float(p.held)
	if held <= 0.001: return
	var spade: Transform3D = p.spade
	var top := spade*Vector3(0.0,SpadeFigure.LENGTH-0.015,0.0)
	var low := spade*Vector3(0.0,SpadeFigure.LENGTH*0.5,0.0)
	var up := frame_basis.y.normalized()
	var back := frame_basis.z.normalized()
	_reach(skel,"R",top,right*0.7-up*0.6+back*0.4,held)
	_reach(skel,"L",low,-right*0.7-up*0.5+back*0.5,held)

## Knees bent by `c` (0 to 1), the hips lowered so the boots stay where
## they stood.
static func _crouch(body: Node3D, skel: Skeleton3D, right: Vector3, c: float) -> void:
	if c <= 0.001: return
	var feet := [skel.find_bone("foot.L"),skel.find_bone("foot.R")]
	if feet.has(-1): return
	var was := (skel.global_transform*skel.get_bone_global_pose(feet[0]).origin).y
	var a := deg_to_rad(KNEE)*c
	for s in ["L","R"]:
		_turn(skel,skel.find_bone("thigh."+s),right,a)
		_turn(skel,skel.find_bone("shin."+s),right,-2.0*a)
		_turn(skel,skel.find_bone("foot."+s),right,a)
	var now := (skel.global_transform*skel.get_bone_global_pose(feet[0]).origin).y
	var pivot: Node3D = body.get("_pivot")
	if pivot == null: return
	var scale_y := pivot.get_parent_node_3d().global_basis.get_scale().y if pivot.get_parent_node_3d() != null else 1.0
	pivot.position.y -= (now-was)/maxf(scale_y,0.001)

## Turns `bone` by `angle` about the world axis `axis`, on its pose.
static func _turn(skel: Skeleton3D, bone: int, axis: Vector3, angle: float) -> void:
	if bone < 0 or absf(angle) < 0.0005: return
	var in_skel := (skel.global_basis.inverse()*axis).normalized()
	var local := (skel.get_bone_global_pose(bone).basis.inverse()*in_skel).normalized()
	skel.set_bone_pose_rotation(bone,skel.get_bone_pose_rotation(bone)*Quaternion(local,angle))

static func _aim(skel: Skeleton3D, bone: int, from: Vector3, to: Vector3, weight: float) -> void:
	var axis := from.cross(to)
	if axis.length() < 1e-6: return
	var angle := from.angle_to(to)*weight
	var local := (skel.get_bone_global_pose(bone).basis.inverse()*axis).normalized()
	skel.set_bone_pose_rotation(bone,skel.get_bone_pose_rotation(bone)*Quaternion(local,angle))

## The arm on side `s` ("L", "R") reaching `goal` (world) by two-bone IK,
## the elbow bent toward `pole` (a world way), `w` of the way.
static func _reach(skel: Skeleton3D, s: String, goal: Vector3, pole: Vector3, w: float) -> void:
	var upper := skel.find_bone("upper_arm."+s)
	var fore := skel.find_bone("forearm."+s)
	var hand := skel.find_bone("hand."+s)
	if upper < 0 or fore < 0 or hand < 0: return
	var to_skel := skel.global_transform.affine_inverse()
	var g := to_skel*goal
	var pole_s := (to_skel.basis*pole).normalized()
	var shoulder := skel.get_bone_global_pose(upper).origin
	var elbow := skel.get_bone_global_pose(fore).origin
	var wrist := skel.get_bone_global_pose(hand).origin
	var a := shoulder.distance_to(elbow)
	var b := elbow.distance_to(wrist)
	var to := g-shoulder
	var d := clampf(to.length(),0.01,(a+b)*0.999)
	var n := to.normalized()
	var along := (a*a-b*b+d*d)/(2.0*d)
	var out := sqrt(maxf(a*a-along*along,0.0))
	var bend := (pole_s-n*pole_s.dot(n)).normalized()
	_aim(skel,upper,elbow-shoulder,n*along+bend*out,w)
	elbow = skel.get_bone_global_pose(fore).origin
	wrist = skel.get_bone_global_pose(hand).origin
	_aim(skel,fore,wrist-elbow,shoulder+n*d-elbow,w)
