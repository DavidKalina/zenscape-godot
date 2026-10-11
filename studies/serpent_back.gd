extends RefCounted
## The rune serpent's body as ground for the pilot on foot
## (studies/serpent_ride.gd): its skin between every two rings
## (scripts/rune_serpent.gd `ring_frame`, `ring_corners`) as a convex hull
## each, and its head the same way between its sections (`head_frame`,
## `head_corners`: each section a ring on the head's frame, the collar the
## skin between the head's back and the first ring), all rebuilt as posed
## every frame, on the layer the physics bridge
## (scripts/pilot_physics_ground.gd) reads. So its back (and its head) is
## ground, its flanks are wall and its shoulders' edges are lips, all where
## they are drawn. Jolt takes a hull's new points at once, so the motor's
## rays that frame see the body where it is now.
##
## A place on the body is held in the body's own terms (`locate`): its arc
## (m back from the snout), and where it lies across (x) and up (y) in the
## frame blended between the rings either side, as the skin between them
## is blended between their corners. Placed again after the serpent has
## moved (`place`), it is where that same place on the body has gone: along
## the path, turned as the body curves, rolled as it banks, up and down as
## it dives. Every ring keeps its arc and travels along the head's own
## trail, so this is the body's exact carry. `moved` gives the move near a
## place since the last `update` as one transform (for everything a rider
## keeps), and `turn` gives its turn about up.
const RuneSerpent = preload("res://scripts/rune_serpent.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")

## The physics layer its hulls are on (the bridge's).
const LAYER := 1
## The share of a ring's corner a place may lie past the ends (the collar's
## ring, the tail's last) and still be placed, as a share of the last
## segment's length.
const PAST_END := 0.6

var serpent: Node3D
var body: StaticBody3D
## Each ring's arc (m back from the snout).
var _arc := PackedFloat32Array()
## How many of the head's sections stand ahead of the rings.
var _heads := 0
## Each ring's corners in its own frame, and its frame now and at the last
## update (the head's sections first, snout first, then the body's rings).
var _corners: Array = []
var _now: Array[Transform3D] = []
var _then: Array[Transform3D] = []
var _hulls: Array[ConvexPolygonShape3D] = []
var _world := PackedVector3Array()

## Its hulls under `parent`, laid on the serpent as it is posed now.
func _init(on: Node3D, parent: Node3D) -> void:
	serpent = on
	_heads = RuneSerpent.HEAD_SECTIONS.size()
	for h in range(_heads):
		var i := _heads-1-h
		_arc.append(RuneSerpent.HEAD*(1.0-float(RuneSerpent.HEAD_SECTIONS[i][2])))
		_corners.append(serpent.head_corners(i))
	var rings: PackedFloat32Array = serpent.stations()
	for k in range(rings.size()):
		_arc.append(rings[k])
		_corners.append(serpent.ring_corners(k))
	_now.resize(_arc.size())
	_world.resize(_arc.size()*8)
	body = StaticBody3D.new()
	body.name = "SerpentBack"
	body.collision_layer = LAYER
	body.collision_mask = 0
	parent.add_child(body)
	for k in range(_arc.size()-1):
		var hull := ConvexPolygonShape3D.new()
		# Sharp: a rounded edge would dip the back where two hulls meet.
		hull.margin = 0.0
		var shape := CollisionShape3D.new()
		shape.shape = hull
		body.add_child(shape)
		_hulls.append(hull)
	reset()

## The rings as posed now read, and every hull laid on them; the last
## update's kept, for the move since.
func update() -> void:
	_then = _now.duplicate()
	var head: Transform3D = serpent.head_frame()
	for k in range(_arc.size()):
		var frame: Transform3D = serpent.ring_frame(k-_heads) if k >= _heads else head.translated_local(Vector3(0.0,0.0,RuneSerpent.HEAD-_arc[k]))
		_now[k] = frame
		var corners: Array = _corners[k]
		for j in range(8): _world[k*8+j] = frame*(corners[j] as Vector3)
	for k in range(_hulls.size()): _hulls[k].points = _world.slice(k*8,k*8+16)

## As `update`, with no move since (after the serpent is set down anew).
func reset() -> void:
	update()
	_then = _now.duplicate()

func rid() -> RID:
	return body.get_rid()

## The snout's section's arc and the last ring's (m back from the snout).
func first_arc() -> float:
	return _arc[0]

func last_arc() -> float:
	return _arc[_arc.size()-1]

## The segment at arc `a`: the ring ahead (x) and the share toward the one
## behind (y), past the ends a little either way.
func _segment(a: float) -> Vector2:
	var n := _arc.size()
	var lo := 0
	var hi := n-2
	while lo < hi:
		var mid := (lo+hi+1)/2
		if _arc[mid] <= a: lo = mid
		else: hi = mid-1
	var f := (a-_arc[lo])/maxf(_arc[lo+1]-_arc[lo],1e-4)
	return Vector2(lo,clampf(f,-PAST_END,1.0+PAST_END))

## The frame between rings `k` and `k`+1 at share `f`, now or at the last
## update: each axis and the place blended, as the skin's corners are.
func _blend(k: int, f: float, then := false) -> Transform3D:
	var rings: Array[Transform3D] = _then if then else _now
	var a: Transform3D = rings[k]
	var b: Transform3D = rings[k+1]
	return Transform3D(Basis(a.basis.x.lerp(b.basis.x,f),a.basis.y.lerp(b.basis.y,f),a.basis.z.lerp(b.basis.z,f)),a.origin.lerp(b.origin,f))

## The body's frame at arc `a` (x across, y up, z along toward the head).
func frame(a: float, then := false) -> Transform3D:
	var seg := _segment(a)
	return _blend(int(seg.x),seg.y,then)

## The body's place (arc, across, up) at world point `p`; `near` an arc to
## start looking from (-1: from the nearest ring).
func locate(p: Vector3, near := -1.0) -> Vector3:
	var n := _arc.size()
	var k := 0
	if near >= 0.0: k = int(_segment(near).x)
	else:
		var best := INF
		for i in range(n):
			var d := p.distance_squared_to(_now[i].origin)
			if d < best:
				best = d
				k = i
		k = mini(k,n-2)
	# Behind ring k's plane and ahead of ring k+1's.
	var ahead := 0.0
	var behind := 0.0
	for guard in range(n):
		ahead = _along(k,p)
		behind = _along(k+1,p)
		if ahead > 0.0 and k > 0: k -= 1
		elif behind < 0.0 and k < n-2: k += 1
		else: break
	# The share between them whose blended plane holds p, then where across
	# and up in it.
	var f := clampf(ahead/minf(ahead-behind,-1e-4),-PAST_END,1.0+PAST_END)
	for i in range(4):
		var g := _off_plane(k,f,p)
		var slope := (_off_plane(k,f+0.001,p)-g)/0.001
		if absf(slope) < 1e-6: break
		f = clampf(f-g/slope,-PAST_END,1.0+PAST_END)
	var at := _blend(k,f)
	var r := p-at.origin
	var x := at.basis.x
	var y := at.basis.y
	var xx := x.dot(x)
	var xy := x.dot(y)
	var yy := y.dot(y)
	var det := xx*yy-xy*xy
	var u := (yy*x.dot(r)-xy*y.dot(r))/det
	var v := (xx*y.dot(r)-xy*x.dot(r))/det
	return Vector3(lerpf(_arc[k],_arc[k+1],f),u,v)

## How far ahead of ring `k`'s plane `p` lies (m, toward the head).
func _along(k: int, p: Vector3) -> float:
	return (p-_now[k].origin).dot(_now[k].basis.z.normalized())

## How far off the blended plane at share `f` `p` lies.
func _off_plane(k: int, f: float, p: Vector3) -> float:
	var at := _blend(k,f)
	return (p-at.origin).dot(at.basis.x.cross(at.basis.y).normalized())

## Where the body's place `c` (arc, across, up) is now, or was at the last
## update.
func place(c: Vector3, then := false) -> Vector3:
	var at := frame(c.x,then)
	return at.origin+at.basis.x*c.y+at.basis.y*c.z

## The body's move near place `c` since the last update, as one transform
## (its place there is carried exactly; anything near it, nearly).
func moved(c: Vector3) -> Transform3D:
	return frame(c.x)*frame(c.x,true).affine_inverse()

## The body's turn about up near arc `a` since the last update (radians, as
## the motor's facing turns).
func turn(a: float) -> float:
	var now := frame(a).basis.z
	var then := frame(a,true).basis.z
	return wrapf(PilotMotor.facing_of(Vector2(now.x,now.z))-PilotMotor.facing_of(Vector2(then.x,then.z)),-PI,PI)

## The way along the body toward the head at arc `a`, flat (x, z).
func ahead(a: float) -> Vector2:
	var z := frame(a).basis.z
	return Vector2(z.x,z.z).normalized()

## The middle of its back's top at arc `a`, as a place on the body: between
## the crest's two corners of the rings either side.
func top(a: float) -> Vector3:
	var seg := _segment(a)
	var k := int(seg.x)
	var crest_a: Vector3 = ((_corners[k][0] as Vector3)+(_corners[k][1] as Vector3))*0.5
	var crest_b: Vector3 = ((_corners[k+1][0] as Vector3)+(_corners[k+1][1] as Vector3))*0.5
	var c := crest_a.lerp(crest_b,seg.y)
	return Vector3(a,c.x,c.y)

## Its back's half width at arc `a` (m, to the shoulders' outer edge).
func half_width(a: float) -> float:
	var seg := _segment(a)
	var k := int(seg.x)
	return lerpf(absf((_corners[k][7] as Vector3).x),absf((_corners[k+1][7] as Vector3).x),seg.y)
