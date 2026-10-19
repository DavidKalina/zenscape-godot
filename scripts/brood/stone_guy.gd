extends RefCounted
## One stone guy of the brood (docs/design/brood/spec-brood.md): a cheap
## body, no physics body of its own. He walks the real ground by a ray down,
## sees a face ahead by a ray forward and climbs it (a ray into the face
## keeps him on it, over overhangs too), mantles over its top, lets himself
## drop off a ledge no deeper than DROP_MOST and will not go over a deeper
## one (the isle's rim, a gap between lands): he turns along it instead. He
## never jumps. Two or three rays a step; `step` is called by the host
## (scripts/brood/brood_host.gd) with the goal it picks.
##
## States: "wake" (hidden under the isle's lip, then fingers and head up
## over it, a look round: `wake_at`), "walk", "climb" (on a face), "mantle"
## (over a face's top), "cling" (hanging on the wanderer: `cling_at`, placed
## each frame by the host; `shake` throws him off), "fall", "lost" (fell
## off the world).
##
## The body is greybox: a squat block, a head, stub arms and legs on pivots,
## swung procedurally (the scurry, the reach up a face, the heave over).

const K = preload("res://scripts/brood/brood_knobs.gd")

var node: Node3D = null
var state := "walk"
## Feet on the ground ("walk", "fall"); the body's middle on a face.
var feet := Vector3.ZERO
var mid := Vector3.ZERO
## The face he is on: its normal (out of it).
var face_n := Vector3.BACK
var heading := Vector3.FORWARD
var velocity := Vector3.ZERO
var climbed := 0.0
## Up the face (1) or back down it (-1, after a top he can't get over).
var climb_dir := 1.0
var start_y := 0.0
## Turning along an edge: the turned way, its time left and the side.
var detour := Vector3.ZERO
var detour_t := 0.0
var side := 1.0
## Stopped at an edge this step (for the host and drivers).
var at_edge := false
## The mantle: from, over (the lip), to (the feet on top), its time.
var _m_from := Vector3.ZERO
var _m_lip := Vector3.ZERO
var _m_to := Vector3.ZERO
var _m_t := 0.0
## A mantle over a crest with its floor further down past it: where he
## drops to after (INF: none, he stands on top).
var _m_drop := Vector3.INF
## Crawling sideways along a face (s left), after a top he couldn't get
## over and no floor under him to climb back down to.
var _traverse_t := 0.0
## The floor a drop off a ledge aims at (INF: none; a fall's own ray finds
## where it lands): reached, he lands on it even where the ray, starting
## inside rubble, missed it.
var _drop_to := Vector3.INF
## The wake: the wait before he shows, the time since, the face spot under
## the lip (the face's point, out of it), the lip's height, the hold.
var _w_wait := 0.0
var _w_t := 0.0
var _w_at := Vector3.ZERO
var _w_lip := 0.0
var _w_hold := 0.0
## Clinging: his slot on the wanderer (-1 none) and, shaken off, the time
## left before he grabs again.
var slot := -1
var daze := 0.0
## The swing's phase and the body's look.
var _phase := 0.0
var _basis := Basis.IDENTITY
var _limbs := {}
var _ray := PhysicsRayQueryParameters3D.new()

var tall := 0.5
var radius := 0.2

func _init(at: Vector3, rng_side := 1.0) -> void:
	tall = K.tall()
	radius = K.RADIUS*K.s()
	feet = at
	start_y = at.y
	side = rng_side
	_ray.collision_mask = K.SOLID_MASK
	node = _build()
	_place_node(1.0)

## Wakes him on the face at `face_at` (a point on it, `n` out of it) under
## a lip at height `lip_y`: hidden `wait` s, then his stretched fingers come
## over the lip, then his head, he looks round `hold` s and climbs over.
func wake_at(face_at: Vector3, n: Vector3, lip_y: float, wait: float, hold: float) -> void:
	state = "wake"
	face_n = n
	_w_at = face_at+n*radius
	_w_lip = lip_y
	_w_wait = wait
	_w_hold = hold
	_w_t = 0.0
	mid = _w_mid(-1.0)
	feet = mid-Vector3.UP*tall*0.5
	start_y = lip_y
	if _flat(n).length() > 0.1: heading = -_flat(n).normalized()
	node.visible = false
	_place_node(1.0)

## His middle on the face, `under` of his height below the lip.
func _w_mid(under: float) -> Vector3:
	var at := _w_at
	at.y = _w_lip+under*tall
	return at

func _wake(dt: float) -> void:
	if _w_wait > 0.0:
		_w_wait -= dt
		return
	node.visible = true
	_w_t += dt
	var u := clampf(_w_t/K.WAKE_RISE,0.0,1.0)
	# Fingers first (to just under the lip, the arms stretched up over it),
	# a breath, then the head up over it.
	var under := -1.0
	if u < 0.45: under = lerpf(-1.05,-0.68,smoothstep(0.0,0.45,u))
	elif u < 0.6: under = -0.68
	else: under = lerpf(-0.68,-0.32,smoothstep(0.6,1.0,u))
	mid = _w_mid(under)
	_swing(0.0,dt)
	if _w_t >= K.WAKE_RISE+_w_hold:
		state = "climb"
		climb_dir = 1.0
		climbed = 0.0

# --- Rays ----------------------------------------------------------------------------

func _cast(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> Dictionary:
	_ray.from = a
	_ray.to = b
	return space.intersect_ray(_ray)

# --- The step ------------------------------------------------------------------------

## One step of `dt` toward `goal` (world; INF: stand).
func step(space: PhysicsDirectSpaceState3D, goal: Vector3, dt: float) -> void:
	at_edge = false
	daze = maxf(daze-dt,0.0)
	match state:
		"wake": _wake(dt)
		"walk": _walk(space,goal,dt)
		"climb": _climb(space,goal,dt)
		"mantle": _mantle(dt)
		"fall": _fall(space,dt)
		"cling": _swing(dt*9.0,dt)
	_place_node(dt)

## Hanging on at `at` (his middle), belly to the wanderer, `out` the way
## out of him; the host moves him with the wanderer each frame.
func cling_at(at: Vector3, out: Vector3) -> void:
	state = "cling"
	mid = at
	face_n = out
	feet = at-Vector3.UP*tall*0.5
	detour_t = 0.0

## Thrown off (a jump, the treasure knocked loose): falling away along
## `push` (m/s), dazed DAZE.
func shake(push: Vector3) -> void:
	slot = -1
	daze = K.DAZE
	_drop_to = Vector3.INF
	feet = mid-Vector3.UP*tall*0.5
	velocity = push
	start_y = minf(start_y,feet.y)
	state = "fall"

func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x,0.0,v.z)

func _walk(space: PhysicsDirectSpaceState3D, goal: Vector3, dt: float) -> void:
	var s := K.s()
	var want := Vector3.ZERO
	if goal != Vector3.INF:
		var to := _flat(goal-feet)
		if to.length() > K.NEAR*s: want = to.normalized()
	if detour_t > 0.0:
		detour_t -= dt
		want = detour
	if want == Vector3.ZERO:
		_swing(0.0,dt)
		return
	# Turn toward the way.
	var a := heading.signed_angle_to(want,Vector3.UP)
	heading = heading.rotated(Vector3.UP,clampf(a,-K.TURN*dt,K.TURN*dt)).normalized()
	var pace := K.SCURRY*s*clampf(1.0-absf(a)/PI,0.3,1.0)
	var go := pace*dt
	# A face ahead at his middle: climb it.
	var mid_at := feet+Vector3.UP*tall*0.5
	var wall := _cast(space,mid_at,mid_at+heading*(radius+go+0.05))
	if not wall.is_empty():
		var n: Vector3 = wall.normal
		if n.y < K.FLOOR and n.y > -0.7:
			face_n = n
			mid = (wall.position as Vector3)+n*radius
			state = "climb"
			climb_dir = 1.0
			climbed = 0.0
			detour_t = 0.0
			return
	# The ground under the next spot.
	var q := feet+heading*go
	var top := q.y+K.STEP_UP*s
	var hit := _cast(space,Vector3(q.x,top,q.z),Vector3(q.x,q.y-K.DROP_MOST*s,q.z))
	if hit.is_empty():
		_edge(want)
		_swing(0.0,dt)
		return
	var g: Vector3 = hit.position
	if (hit.normal as Vector3).y < K.FLOOR:
		# Only a steep face down there (a broken end, a keel): no floor to
		# drop to, so an edge.
		_edge(want)
		_swing(0.0,dt)
		return
	if g.y >= feet.y-K.STEP_DOWN*s:
		feet = g
		_swing(go,dt)
		return
	# A ledge down he can drop off: over it he goes, nearly straight down
	# onto the floor the ray found.
	state = "fall"
	velocity = heading*0.6*s
	feet = q
	_drop_to = g

## At an edge he won't go over: turn along it (the same side each time
## until he's clear), and hold the turned way a while.
func _edge(want: Vector3) -> void:
	at_edge = true
	detour = want.rotated(Vector3.UP,deg_to_rad(K.DETOUR_TURN)*side)
	if detour_t > 0.0: detour = detour.rotated(Vector3.UP,deg_to_rad(K.DETOUR_TURN)*side)
	detour_t = K.DETOUR_TIME
	heading = heading.rotated(Vector3.UP,deg_to_rad(K.DETOUR_TURN)*side*0.5).normalized()

## Up the face: along it upward, sideways toward the goal, held to it by a
## ray into it; over its top when the ray finds no face (or a floor).
func _climb(space: PhysicsDirectSpaceState3D, goal: Vector3, dt: float) -> void:
	var s := K.s()
	var up_along := (Vector3.UP-face_n*Vector3.UP.dot(face_n))
	if up_along.length() < 0.2:
		_let_go()
		return
	up_along = up_along.normalized()
	var across := up_along.cross(face_n).normalized()
	var lat := 0.0
	if goal != Vector3.INF: lat = clampf((goal-mid).dot(across),-1.0,1.0)
	if _traverse_t > 0.0:
		_traverse_t -= dt
		lat = side*2.0
	if climb_dir < 0.0:
		lat = 0.0
		# No floor under him he'd drop to (the isle's side over the void):
		# up again, crawling sideways to find another way over.
		var floor_under := _cast(space,mid,mid+Vector3.DOWN*K.DROP_MOST*s)
		if floor_under.is_empty() or (floor_under.normal as Vector3).y < K.FLOOR:
			climb_dir = 1.0
			_traverse_t = K.TRAVERSE_TIME
			return
		# Back down: off the face onto the floor under him, turned away.
		var under := _cast(space,mid,mid+Vector3.DOWN*(tall*0.5+0.15*s))
		if not under.is_empty() and (under.normal as Vector3).y >= K.FLOOR:
			feet = under.position
			heading = _flat(face_n).normalized() if _flat(face_n).length() > 0.1 else -heading
			side = -side
			detour = heading.rotated(Vector3.UP,deg_to_rad(K.DETOUR_TURN)*side)
			detour_t = K.DETOUR_TIME*1.5
			state = "walk"
			return
	var move := up_along*K.CLIMB*s*dt*climb_dir+across*lat*K.CLIMB*K.CLIMB_SIDE*s*dt
	if climb_dir > 0.0:
		# A steeper face above him (a slope run into a wall): onto it; a
		# ceiling over him: along under it sideways.
		var above := _cast(space,mid,mid+up_along*(radius+move.length()+0.05))
		if not above.is_empty():
			var an: Vector3 = above.normal
			if an.y > -0.7 and an.y < K.FLOOR and an.dot(face_n) < 0.95:
				face_n = an
				mid = (above.position as Vector3)+an*radius
				return
			if an.y <= -0.7 and _traverse_t <= 0.0: _traverse_t = K.TRAVERSE_TIME
	climbed += move.length()
	var c := mid+move
	var hit := _cast(space,c+face_n*0.35*s,c-face_n*(radius+0.45*s))
	if hit.is_empty() and climb_dir < 0.0:
		_let_go()
		return
	if hit.is_empty():
		if not _start_mantle(space,c): climb_dir = -1.0
		return
	var n: Vector3 = hit.normal
	if n.y >= K.FLOOR:
		# The face leans back into a floor: up onto it.
		# (A small ledge on a broken slope with no top to stand on past it:
		# on up over it as a face.)
		if climb_dir < 0.0:
			_let_go()
			return
		if _start_mantle(space,c): return
	if n.y < -0.7 or climbed > K.CLIMB_MOST*s:
		_let_go()
		return
	face_n = face_n.slerp(n,clampf(dt*12.0,0.0,1.0)).normalized()
	mid = (hit.position as Vector3)+n*radius
	_swing(move.length()*2.2,dt)

## Over the top from `c`: the floor just past the lip, else false.
func _start_mantle(space: PhysicsDirectSpaceState3D, c: Vector3) -> bool:
	var s := K.s()
	var into := _flat(-face_n)
	if into.length() < 0.1: into = _flat(heading)
	into = into.normalized()
	for reach: float in [radius+0.3*s,radius+0.7*s,radius+1.2*s]:
		var over := c+into*reach+Vector3.UP*tall*1.4
		var hit := _cast(space,over,over+Vector3.DOWN*(tall*3.3+K.DROP_MOST*s))
		if hit.is_empty() or (hit.normal as Vector3).y < K.FLOOR: continue
		_m_from = mid
		_m_to = hit.position
		_m_drop = Vector3.INF
		if _m_to.y < c.y-tall*1.2:
			# A crest: over it onto its top, then down to the floor past it.
			_m_drop = _m_to
			_m_to = Vector3(over.x,c.y-tall*0.3,over.z)
		_m_lip = Vector3(mid.x,maxf(_m_to.y,mid.y-tall*0.2)+tall*0.55,mid.z)
		_m_t = 0.0
		heading = into
		state = "mantle"
		return true
	return false

func _mantle(dt: float) -> void:
	_m_t += dt/K.MANTLE_TIME
	var k := minf(_m_t,1.0)
	# Up to the lip (the first part), then over onto the top.
	if k < 0.55:
		var u := k/0.55
		mid = _m_from.lerp(_m_lip,u*u*(3.0-2.0*u))
	else:
		var u := (k-0.55)/0.45
		mid = _m_lip.lerp(_m_to+Vector3.UP*tall*0.5,u*u*(3.0-2.0*u))
	_swing(dt*6.0,dt)
	if _m_t >= 1.0:
		feet = _m_to
		state = "walk"
		if _m_drop != Vector3.INF:
			state = "fall"
			velocity = heading*0.6*K.s()
			_drop_to = _m_drop
			_m_drop = Vector3.INF

func _let_go() -> void:
	_drop_to = Vector3.INF
	feet = mid-Vector3.UP*tall*0.5+face_n*0.05
	velocity = face_n*1.2
	state = "fall"

func _fall(space: PhysicsDirectSpaceState3D, dt: float) -> void:
	velocity.y -= K.GRAVITY*dt
	var next := feet+velocity*dt
	var hit := _cast(space,feet+Vector3.UP*0.2,next)
	if hit.is_empty() and _drop_to != Vector3.INF and next.y <= _drop_to.y:
		hit = {"position":Vector3(next.x,_drop_to.y,next.z),"normal":Vector3.UP}
	if not hit.is_empty() and (hit.normal as Vector3).y >= K.FLOOR:
		_drop_to = Vector3.INF
		feet = hit.position
		velocity = Vector3.ZERO
		state = "walk"
		return
	if not hit.is_empty():
		# A face: slide off it.
		var n: Vector3 = hit.normal
		next = (hit.position as Vector3)+n*radius*0.5
		velocity = velocity-n*velocity.dot(n)
	feet = next
	if feet.y < start_y-K.LOST_UNDER:
		state = "lost"
		node.visible = false

# --- The body ------------------------------------------------------------------------

static var _mat: StandardMaterial3D = null
static var _dark: StandardMaterial3D = null

static func _materials() -> void:
	if _mat != null: return
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = K.STONE
	_mat.roughness = 1.0
	# A little of their own light, so they read on a face in shade (the
	# isle's rock has its own ambient; a plain material goes black there).
	_mat.emission_enabled = true
	_mat.emission = K.STONE
	_mat.emission_energy_multiplier = K.GLOW
	_dark = StandardMaterial3D.new()
	_dark.albedo_color = K.STONE_DARK
	_dark.roughness = 1.0

func _box(parent: Node3D, called: String, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = called
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = at
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m

func _pivot(parent: Node3D, called: String, at: Vector3) -> Node3D:
	var p := Node3D.new()
	p.name = called
	p.position = at
	parent.add_child(p)
	_limbs[called] = p
	return p

## A squat block body on stub legs, a head a little forward, stub arms; the
## node's origin is the body's middle.
func _build() -> Node3D:
	_materials()
	var h := tall
	var root := Node3D.new()
	root.name = "StoneGuy"
	var body := _pivot(root,"body",Vector3.ZERO)
	var bw := h*0.72
	_box(body,"Trunk",Vector3(bw,h*0.46,h*0.52),Vector3(0.0,0.0,0.0),_mat).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var head := _pivot(body,"head",Vector3(0.0,h*0.23,-h*0.06))
	_box(head,"Head",Vector3(h*0.42,h*0.34,h*0.4),Vector3(0.0,h*0.15,-h*0.04),_mat)
	_box(head,"Brow",Vector3(h*0.44,h*0.07,h*0.12),Vector3(0.0,h*0.23,-h*0.2),_dark)
	for sd: float in [-1.0,1.0]:
		_box(head,"Eye",Vector3(h*0.06,h*0.05,h*0.03),Vector3(sd*h*0.1,h*0.15,-h*0.25),_dark)
		var arm := _pivot(body,"arm_%s" % ("l" if sd < 0.0 else "r"),Vector3(sd*bw*0.58,h*0.12,-h*0.04))
		_box(arm,"Arm",Vector3(h*0.16,h*0.4,h*0.16),Vector3(0.0,-h*0.17,0.0),_mat)
		var leg := _pivot(body,"leg_%s" % ("l" if sd < 0.0 else "r"),Vector3(sd*bw*0.28,-h*0.2,0.0))
		_box(leg,"Leg",Vector3(h*0.2,h*0.3,h*0.22),Vector3(0.0,-h*0.13,-h*0.02),_mat)
	return root

## The node where the body is, turned to how he moves: upright facing his
## heading on the ground; belly to the face, head up it, climbing.
func _place_node(dt: float) -> void:
	var up := Vector3.UP
	var fwd := heading
	var at := feet+Vector3.UP*tall*0.5
	match state:
		"climb","wake","cling":
			up = (Vector3.UP-face_n*Vector3.UP.dot(face_n))
			up = up.normalized() if up.length() > 0.1 else Vector3.UP
			fwd = -face_n
			at = mid
		"mantle":
			fwd = heading
			at = mid
	fwd = (fwd-up*fwd.dot(up))
	if fwd.length() < 0.05: fwd = heading
	fwd = fwd.normalized()
	var want := Basis(up.cross(-fwd).normalized(),up,-fwd).orthonormalized()
	_basis = _basis.slerp(want,clampf(dt*14.0,0.0,1.0)).orthonormalized() if dt < 1.0 else want
	node.transform = Transform3D(_basis,at)

## The limbs: a scurry on the ground (legs and arms swung against each
## other, a bob), the reach and pull on a face, the heave over a top.
func _swing(moved: float, dt: float) -> void:
	_phase += moved/(tall*0.55)
	var sw := sin(_phase)
	var body: Node3D = _limbs.body
	var al: Node3D = _limbs.arm_l
	var ar: Node3D = _limbs.arm_r
	var ll: Node3D = _limbs.leg_l
	var lr: Node3D = _limbs.leg_r
	var head: Node3D = _limbs.head
	var k := clampf(dt*16.0,0.0,1.0)
	var want := {}
	var stretch := 1.0
	var look := 0.0
	match state:
		"wake":
			# Arms reaching up over the lip and stretched (the fingers come
			# first), then holding it; the head turning to look round.
			var u := clampf(_w_t/K.WAKE_RISE,0.0,1.0)
			stretch = lerpf(1.0,1.7,smoothstep(0.0,0.4,u))
			var hold := _w_t-K.WAKE_RISE
			if hold > 0.0:
				look = 0.6*sin(hold*5.0+side)
				stretch = lerpf(1.7,1.0,clampf(hold/maxf(_w_hold,0.05),0.0,1.0))
			want = {"al":2.95,"ar":3.05,"ll":0.4,"lr":0.6,"pitch":0.0,"head":-0.3*u,"bob":0.0}
		"climb":
			# Arms up the face in turn, the legs pushing under them.
			want = {"al":2.4+0.6*sw,"ar":2.4-0.6*sw,"ll":0.5-0.5*sw,"lr":0.5+0.5*sw,"pitch":0.15,"head":-0.5,"bob":0.0}
		"cling":
			# Arms round him (up and in), legs kicking, the head pressed in.
			want = {"al":1.9+0.25*sw,"ar":1.9-0.25*sw,"ll":0.9+0.6*sw,"lr":0.9-0.6*sw,"pitch":0.1,"head":-0.4,"bob":0.0}
		"mantle":
			var u := clampf(_m_t,0.0,1.0)
			want = {"al":2.6-1.6*u,"ar":2.6-1.6*u,"ll":1.2*sin(u*PI),"lr":1.0*sin(u*PI),"pitch":0.7*sin(u*PI),"head":-0.3,"bob":0.0}
		"fall":
			want = {"al":2.2,"ar":2.0,"ll":0.6,"lr":-0.4,"pitch":-0.2,"head":0.2,"bob":0.0}
		_:
			var moving := moved > 0.0001
			var a := 0.8 if moving else 0.0
			want = {"al":a*sw,"ar":-a*sw,"ll":-a*sw,"lr":a*sw,"pitch":0.25 if moving else 0.0,"head":-0.2 if moving else 0.0,"bob":absf(cos(_phase))*tall*0.08 if moving else 0.0}
	al.scale.y = lerpf(al.scale.y,stretch,k)
	ar.scale.y = lerpf(ar.scale.y,stretch,k)
	head.rotation.y = lerpf(head.rotation.y,look,k)
	al.rotation.x = lerpf(al.rotation.x,want.al,k)
	ar.rotation.x = lerpf(ar.rotation.x,want.ar,k)
	ll.rotation.x = lerpf(ll.rotation.x,want.ll,k)
	lr.rotation.x = lerpf(lr.rotation.x,want.lr,k)
	body.rotation.x = lerpf(body.rotation.x,-float(want.pitch),k)
	head.rotation.x = lerpf(head.rotation.x,-float(want.head),k)
	body.position.y = lerpf(body.position.y,float(want.bob),k)
	if state == "climb" or state == "cling": body.rotation.z = 0.12*sw
	else: body.rotation.z = lerpf(body.rotation.z,0.0,k)
