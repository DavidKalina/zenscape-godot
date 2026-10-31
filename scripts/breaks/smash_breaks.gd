extends "res://scripts/breaks/kit_breaks.gd"
## KitBreaks for a plane at speed (scripts/endless/surge_smash.gd), not a
## walking giant: a hit doesn't lean a piece over, it blows it out the way the
## plane is going (`blast_dir`, `blast_v`, set before each hit), the pieces
## flying on ahead of it. Kept in ready mode (`ready_all`): a cut is made on a
## worker, never in the frame of the hit. A piece grown in the land (a scale on
## its node) falls at its size, its bodies at scale 1.

## A piece longer than this (m, its own frame) stays whole: the plane can't
## hole a colosseum.
const MOST_LONG := 34.0
## The blast: of the plane's speed each stone keeps (from, to), out from the
## hit (m/s), up (m/s) and its spin (rad/s).
const KEEP := Vector2(0.45,0.95)
const OUT := Vector2(3.0,11.0)
const UP_V := Vector2(1.0,7.0)
const SPIN := Vector2(1.5,6.0)
## Flying stone is off layer 1, so the near misses' rays and the wheels don't
## read it.
const STONE_LAYER := 1 << 12

var blast_dir := Vector3.FORWARD
var blast_v := Vector3.ZERO

func _init() -> void:
	super._init()
	ready_all = true

func add(node: Node3D, kind: String, rebuild := Callable(), seed_value := -1) -> int:
	var long := _box_of(node).size
	if maxf(long.x,long.z) > MOST_LONG: return -1
	return super.add(node,kind,rebuild,seed_value)

## True if a live piece strong enough to break stands within `radius` m of `at`.
func in_reach(at: Vector3, radius: float, strength: float) -> bool:
	for t: Dictionary in targets:
		if not t.alive or not is_instance_valid(t.node) or strength < float(t.tough): continue
		if _nearest(t,at).distance_to(at) <= radius: return true
	return false

func _break(i: int, at: Vector3, dir: Vector3, push: Vector3, his: Variant) -> bool:
	return super._break(i,at,blast_dir,blast_v if push == Vector3.ZERO else push,his)

## A piece's stacks don't go over: each part flies, out of the plane's way.
func _topple(parts: Array, xf: Transform3D, box: AABB, at: Vector3, dir: Vector3, push: Vector3, his: Variant, group: Dictionary) -> void:
	for part: Dictionary in parts:
		var pat: Vector3 = xf*(part.at as Vector3)
		var out := pat-at
		out = out.normalized() if out.length() > 0.05 else Vector3.UP
		var high := clampf(((part.at as Vector3).y-box.position.y)/maxf(box.size.y,0.5),0.0,1.0)
		var lin := push*_rng.randf_range(KEEP.x,KEEP.y)+out*_rng.randf_range(OUT.x,OUT.y)+Vector3.UP*_rng.randf_range(UP_V.x,UP_V.y)
		var ang := Vector3(_rng.randf_range(-1.0,1.0),_rng.randf_range(-1.0,1.0),_rng.randf_range(-1.0,1.0)).normalized()*_rng.randf_range(SPIN.x,SPIN.y)
		var rb := _body_of([{"mesh":part.mesh,"shape":part.shape,"local":Transform3D.IDENTITY,"kg":float(part.kg)}],Transform3D(xf.basis,pat))
		rb.angular_damp = 0.4
		if his is PhysicsBody3D: rb.add_collision_exception_with(his)
		for other: Variant in group.pieces:
			if is_instance_valid(other): rb.add_collision_exception_with(other as RigidBody3D)
		_go_piece(rb,group,str(part.kind),lin,ang,0.0,dir,high)

## `subs` on a body at scale 1, the scale of `xf` put on each one's place.
func _body_of(subs: Array, xf: Transform3D) -> RigidBody3D:
	var s := xf.basis.get_scale()
	var grown: Array = []
	for sub: Dictionary in subs:
		var one := sub.duplicate()
		var l: Transform3D = sub.local
		one.local = Transform3D(Basis.from_scale(s)*l.basis,l.origin*s)
		grown.append(one)
	var rb := super._body_of(grown,Transform3D(xf.basis.orthonormalized(),xf.origin))
	rb.collision_layer = STONE_LAYER
	rb.collision_mask = 1|STONE_LAYER
	return rb
