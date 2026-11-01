extends RefCounted
## The stomper as a solid (docs/design/endless-flight/spec-stomper.md): a few
## capsules carried by its bones, as the IK left them. The flight meets it where
## it meets stone: `ground` for the glide, `inside` for the wheels and the camera,
## one physics body a capsule for NearMiss's rays (layer 1), `face` for the way
## out of a hit (FlightContact, so a crash flies on off the limb, as off a tower).
##
## The limbs move and the plane doesn't get a say, so `before` looks first: a limb
## that has come over the plane since the last frame pushes it out, and hits it
## if it came at more than a scrape.
##   bind(stomper, study)    finds the bones and starts reading them
##   ground(p, h, pad)       the study's `plane_ground` over the land `h`
##   inside(p, pad)          in a capsule grown by `pad`
##   face(at, room)          the way out of the nearest capsule, or ZERO
##   before(delta, game)     {} or {"crash"}, before the plane's move

const LandHalls = preload("res://scripts/endless/land_halls.gd")
const FlightContact = preload("res://scripts/endless/flight_contact.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

## The capsules on the rest pose: bone, the ends and the radius (m in play, fitted
## to the mesh's extent round each bone), x mirrored for the limbs. The thumbs and
## the fingers' curl are left out.
const TRUNK := [
	["hips",Vector3(-33.0,88.0,-3.0),Vector3(33.0,88.0,-3.0),42.0],
	["spine",Vector3(-33.0,146.0,-5.0),Vector3(33.0,146.0,-5.0),54.0],
	["chest",Vector3(-33.0,196.0,-5.0),Vector3(33.0,196.0,-5.0),52.0],
	["chest",Vector3(-30.0,215.0,-5.0),Vector3(30.0,215.0,-5.0),34.0],
	["neck",Vector3(0.0,222.0,2.0),Vector3(0.0,228.0,2.0),22.0],
]
const LIMBS := [
	["thigh",Vector3(40.4,90.0,0.0),Vector3(40.4,49.0,0.0),27.0],
	["shin",Vector3(40.4,49.0,-1.0),Vector3(40.4,12.0,-1.0),26.0],
	["foot",Vector3(40.4,22.0,-27.0),Vector3(40.4,22.0,3.0),24.0],
	["upper_arm",Vector3(97.0,216.0,0.0),Vector3(97.0,156.0,0.0),29.0],
	["forearm",Vector3(94.0,156.0,0.0),Vector3(94.0,104.0,0.0),26.0],
	["hand",Vector3(94.0,100.0,0.0),Vector3(94.0,74.0,0.0),24.0],
]
const LAYER := 1
## How far off the bound the plane starts the capsules' physics (m).
const NEAR := 300.0
## How far out of the grown capsule a limb's push leaves the plane (m).
const PUSHED := 0.05

var live := false
## How many capsules; per capsule its bone, its ends on that bone, its radius,
## the ends now and at the last `before`.
var count := 0
var a := PackedVector3Array()
var b := PackedVector3Array()
var radius := PackedFloat32Array()
var _bone := PackedInt32Array()
var _from := PackedVector3Array()
var _to := PackedVector3Array()
var _was_a := PackedVector3Array()
var _was_b := PackedVector3Array()
## Each capsule's bounding sphere, whole body's as well.
var _mid := PackedVector3Array()
var _reach := PackedFloat32Array()
var _centre := Vector3.ZERO
var _bound := 0.0
var _bodies: Array[RID] = []
var _shapes: Array[RID] = []
var _stomper: Node3D
var _skeleton: Skeleton3D
var _study: Node

func bind(stomper: Node3D, skeleton: Skeleton3D, study: Node, size: float) -> void:
	_stomper = stomper
	_skeleton = skeleton
	_study = study
	for row: Array in TRUNK: _add(row,1.0,"",size)
	for row: Array in LIMBS:
		_add(row,-1.0,".L",size)
		_add(row,1.0,".R",size)
	count = _bone.size()
	a.resize(count)
	b.resize(count)
	_mid.resize(count)
	_reach.resize(count)
	var space: RID = study.get_world_3d().space
	for i in range(count):
		var shape := PhysicsServer3D.capsule_shape_create()
		var length := _from[i].distance_to(_to[i])
		PhysicsServer3D.shape_set_data(shape,{"radius":radius[i],"height":length+radius[i]*2.0})
		var rid := PhysicsServer3D.body_create()
		PhysicsServer3D.body_set_mode(rid,PhysicsServer3D.BODY_MODE_STATIC)
		PhysicsServer3D.body_add_shape(rid,shape)
		PhysicsServer3D.body_set_collision_layer(rid,LAYER)
		PhysicsServer3D.body_set_collision_mask(rid,0)
		PhysicsServer3D.body_attach_object_instance_id(rid,stomper.get_instance_id())
		PhysicsServer3D.body_set_space(rid,space)
		_shapes.append(shape)
		_bodies.append(rid)
	skeleton.skeleton_updated.connect(_read)

func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE: return
	for rid in _bodies: PhysicsServer3D.free_rid(rid)
	for rid in _shapes: PhysicsServer3D.free_rid(rid)

func _add(row: Array, side: float, suffix: String, size: float) -> void:
	var id := _skeleton.find_bone(str(row[0])+suffix)
	var rest := _skeleton.get_bone_global_rest(id).affine_inverse()
	var flip := Vector3(side,1.0,1.0)
	_bone.append(id)
	_from.append(rest*((row[1] as Vector3)*flip/size))
	_to.append(rest*((row[2] as Vector3)*flip/size))
	radius.append(float(row[3]))

## The capsules where the IK left the bones. Read here, not after the frame: the
## skeleton's own pose after it is the clip's.
func _read() -> void:
	if not _stomper.visible:
		live = false
		return
	var into: Transform3D = _skeleton.global_transform
	var low := Vector3.INF
	var high := -Vector3.INF
	for i in range(count):
		var bone: Transform3D = into*_skeleton.get_bone_global_pose(_bone[i])
		var from: Vector3 = bone*_from[i]
		var to: Vector3 = bone*_to[i]
		a[i] = from
		b[i] = to
		var mid := (from+to)*0.5
		_mid[i] = mid
		_reach[i] = from.distance_to(to)*0.5+radius[i]
		var grow := Vector3.ONE*radius[i]
		low = low.min(from-grow).min(to-grow)
		high = high.max(from+grow).max(to+grow)
	_centre = (low+high)*0.5
	_bound = low.distance_to(high)*0.5
	live = true
	var plane: RefCounted = _study.plane
	if plane == null or (plane.position as Vector3).distance_to(_centre) > _bound+NEAR: return
	for i in range(count):
		var y: Vector3 = (b[i]-a[i]).normalized()
		var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
		PhysicsServer3D.body_set_state(_bodies[i],PhysicsServer3D.BODY_STATE_TRANSFORM,Transform3D(Basis(x,y,x.cross(y)),_mid[i]))

## SkyGlide's `ground` at `p` over the land `h` (LandHalls `over`): what the body
## covers there, grown by `pad` (the wingtip's reach when not given).
func ground(p: Vector3, h: Variant, pad := -1.0) -> Variant:
	if not live or not h is float: return h
	if pad < 0.0: pad = WorldScale.span*0.5
	var gap := Vector2(p.x-_centre.x,p.z-_centre.z)
	var far := _bound+pad
	if gap.length_squared() > far*far: return h
	var list := []
	for i in range(count):
		var s := _stretch(i,p.x,p.z,radius[i]+pad)
		if s.x < s.y: list.append(s)
	if list.is_empty(): return h
	if list.size() > 1: list.sort_custom(func(l: Vector2, r: Vector2) -> bool: return l.x < r.x)
	return LandHalls.over(p,h,list)

## The world y a capsule grown to `r` covers on the upright through (x, z), as
## Vector2(low, high); low over high: none. A capsule is convex, so one stretch.
func _stretch(i: int, x: float, z: float, r: float) -> Vector2:
	var m := _mid[i]
	var off := _reach[i]-radius[i]+r
	var dx := x-m.x
	var dz := z-m.z
	var low := INF
	var high := -INF
	if dx*dx+dz*dz > off*off: return Vector2(low,high)
	var r2 := r*r
	var ends := [a[i],b[i]]
	for e: Vector3 in ends:
		var left := r2-(x-e.x)*(x-e.x)-(z-e.z)*(z-e.z)
		if left <= 0.0: continue
		var s := sqrt(left)
		low = minf(low,e.y-s)
		high = maxf(high,e.y+s)
	var axis: Vector3 = b[i]-a[i]
	var length := axis.length()
	if length < 0.001: return Vector2(low,high)
	axis /= length
	var w := Vector3(x-a[i].x,-a[i].y,z-a[i].z)
	var along := w.dot(axis)
	var flat := w-axis*along
	var up := Vector3.UP-axis*axis.y
	var aa := up.length_squared()
	var cc := flat.length_squared()-r2
	if aa < 0.000001:
		if cc < 0.0:
			low = minf(low,minf(a[i].y,b[i].y))
			high = maxf(high,maxf(a[i].y,b[i].y))
		return Vector2(low,high)
	var bb := flat.dot(up)
	var root := bb*bb-aa*cc
	if root <= 0.0: return Vector2(low,high)
	root = sqrt(root)
	var y0 := (-bb-root)/aa
	var y1 := (-bb+root)/aa
	if absf(axis.y) > 0.000001:
		var t0 := -along/axis.y
		var t1 := (length-along)/axis.y
		y0 = maxf(y0,minf(t0,t1))
		y1 = minf(y1,maxf(t0,t1))
	elif along < 0.0 or along > length:
		return Vector2(low,high)
	if y0 < y1:
		low = minf(low,y0)
		high = maxf(high,y1)
	return Vector2(low,high)

## In a capsule, grown by `pad` (the wingtip's reach when not given).
func inside(p: Vector3, pad := -1.0) -> bool:
	if not live: return false
	if pad < 0.0: pad = WorldScale.span*0.5
	var far := _bound+pad
	if p.distance_squared_to(_centre) > far*far: return false
	for i in range(count):
		var r := radius[i]+pad
		var off := _reach[i]+pad
		if p.distance_squared_to(_mid[i]) > off*off: continue
		if p.distance_squared_to(_nearest(i,p)) < r*r: return true
	return false

## The way out of the capsule nearest `at`, if `at` is within `room` of its skin,
## else ZERO.
func face(at: Vector3, room: float) -> Vector3:
	if not live: return Vector3.ZERO
	var far := _bound+room
	if at.distance_squared_to(_centre) > far*far: return Vector3.ZERO
	var best := room
	var out := Vector3.ZERO
	for i in range(count):
		var c := _nearest(i,at)
		var d := at.distance_to(c)
		if d-radius[i] < best and d > 0.001:
			best = d-radius[i]
			out = (at-c)/d
	return out

## The point of capsule `i`'s axis nearest `p`.
func _nearest(i: int, p: Vector3) -> Vector3:
	var axis: Vector3 = b[i]-a[i]
	var t := clampf((p-a[i]).dot(axis)/maxf(axis.length_squared(),0.000001),0.0,1.0)
	return a[i]+axis*t

## Before the plane's move: a limb come over the plane puts it back out on the
## limb's skin and, coming at it faster than CRASH_INTO, hits it. {} or {"crash"}
## as FlightContact's. The glide's own stops see only the plane's move, and would
## lift a plane a limb has reached to the top of that limb.
func before(delta: float, game: Node3D) -> Dictionary:
	var hit := {}
	var plane: RefCounted = game.plane
	var fresh := _was_a.size() == count
	if not live or not bool(plane.weighted) or not bool(game.hand_landing.flying()) or delta <= 0.0:
		_was_a = PackedVector3Array()
		return hit
	var p: Vector3 = plane.position
	var pad := float(game.solid_pad)
	var far := _bound+pad
	if p.distance_squared_to(_centre) > far*far:
		_was_a = PackedVector3Array()
		return hit
	for i in range(count):
		var r := radius[i]+pad
		var c := _nearest(i,p)
		var d := p.distance_to(c)
		if d >= r: continue
		var n := (p-c)/d if d > 0.001 else Vector3.UP
		p = c+n*(r+PUSHED)
		plane.position = p
		if not fresh or not hit.is_empty(): continue
		var axis: Vector3 = b[i]-a[i]
		var t := clampf((c-a[i]).dot(axis)/maxf(axis.length_squared(),0.000001),0.0,1.0)
		var moved: Vector3 = (a[i]-_was_a[i]).lerp(b[i]-_was_b[i],t)/delta
		var v: Vector3 = plane.velocity
		var into := (moved-v).dot(n)
		if into <= FlightContact.CRASH_INTO: continue
		hit = {"crash":{"at":c+n*radius[i],"normal":n,"what":"stone","into":into,"angle":PI*0.5,"speed":v.length(),"tower":true}}
	_was_a = a.duplicate()
	_was_b = b.duplicate()
	return hit
