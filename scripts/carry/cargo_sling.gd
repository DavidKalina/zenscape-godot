extends Node3D
## The plane's cargo bag (docs/design/carry/spec-carry.md, the hitch and
## the bag): a sack, cloth at the bottom and rope net above, on a rope from
## the plane's belly. It is one point (the hook at its gathered neck) swung
## as a pendulum: gravity, the air's drag, the rope (never longer than its
## `length`; slack, it sags) and the ground (the bag sits on what is under
## it, and drags on it). Its belly swells and its rope pays out with what's
## in it (`set_load`, kg), so a full bag hangs low and swings wide. The
## belly is a ball swept against the world each frame: it stops on rock and
## stone, slides along it, and says how hard it hit (`hit`); the carry host
## spills treasure for it. Parked, it lies on the turf behind the plane;
## taxiing it drags behind; off the edge it swings up under the plane.
## Treasures loaded into it (scripts/carry/carry_host.gd) sit in it at
## `slot(i)`.
##
## It lives in the world (top_level), stepped by the carry host each frame
## with the plane's figure: `step(delta, plane_figure)`.

## The bag's numbers (rope, size, spill) live in scripts/carry/
## carry_weights.gd (BAG_*). Here: where the rope is tied under the plane
## (the figure's own frame: toy units, times its scale), gravity, the
## air's drag (1/s: trailing back at speed), the drag of the ground (1/s);
## a jump of the plane this far in one frame puts it back at rest.
const Weights = preload("res://scripts/carry/carry_weights.gd")
const TIE := Vector3(0.0,-0.16,0.12)
const GRAVITY := 9.8
const DRAG := 0.35
const SCUFF := 9.0
const JUMP := 8.0
## The sack's neck: from the top of its belly up to the hook (m).
const NECK := 0.3
## Its belly's height over its radius (a little squat), and how far up it
## the cloth comes (the rest is net, so the load shows through).
const SQUAT := 0.85
const CLOTH := 0.42
const MERIDIANS := 12
const SOLID_MASK := 1|(1 << 11)
const ROPE_BITS := 14
const ROPE := Color("9a7b52")
const NET := Color("6e5233")
const SACK := Color("8a7350")

## A hit on the bag: how hard (m/s into what it hit), where, the way out of
## it (the hit's normal) and the bag's velocity as it hit.
signal hit(speed: float, at: Vector3, normal: Vector3, vel: Vector3)

## The hook (world) now and last frame; the bag's up; on the ground.
var hook := Vector3.ZERO
var _was := Vector3.ZERO
var up := Vector3.UP
var grounded := true
var _anchor := Vector3.INF
var _basket: Node3D = null
var _rope: Array[MeshInstance3D] = []
var _rope_mat: StandardMaterial3D = null
var _net_mat: StandardMaterial3D = null
var _sack_mat: StandardMaterial3D = null
var _net: MeshInstance3D = null
var _cloth: MeshInstance3D = null
## What it holds (kg), the rope's length now and the length it eases to,
## the belly's radius now and the one it swells to; its velocity last
## frame (m/s); hits so far (drivers).
var load_kg := 0.0
var length := Weights.BAG_ROPE
var _length_to := Weights.BAG_ROPE
var radius := Weights.BAG_R
var _radius_to := Weights.BAG_R
var _drawn_r := -1.0
var vel := Vector3.ZERO
var hits := 0

func _init() -> void:
	name = "CargoSling"
	top_level = true
	_rope_mat = StandardMaterial3D.new()
	_rope_mat.albedo_color = ROPE
	_rope_mat.roughness = 0.9
	_net_mat = StandardMaterial3D.new()
	_net_mat.albedo_color = NET
	_net_mat.roughness = 0.9
	_sack_mat = StandardMaterial3D.new()
	_sack_mat.albedo_color = SACK
	_sack_mat.roughness = 1.0
	_sack_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_basket = Node3D.new()
	_basket.name = "Bag"
	add_child(_basket)
	_net = MeshInstance3D.new()
	_net.material_override = _net_mat
	_basket.add_child(_net)
	_cloth = MeshInstance3D.new()
	_cloth.material_override = _sack_mat
	_basket.add_child(_cloth)
	var knot := SphereMesh.new()
	knot.radius = 0.06
	knot.height = 0.12
	var k := MeshInstance3D.new()
	k.name = "Knot"
	k.mesh = knot
	k.material_override = _rope_mat
	_basket.add_child(k)
	for i in range(ROPE_BITS):
		var bit := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.022
		c.bottom_radius = 0.022
		c.height = 1.0
		c.radial_segments = 5
		c.rings = 1
		bit.mesh = c
		bit.material_override = _rope_mat
		add_child(bit)
		_rope.append(bit)
	_shape(radius)

## The hook's height over the bag's floor at radius `r`.
static func hook_of(r: float) -> float:
	return 2.0*SQUAT*r+NECK

## The middle of its belly over its floor at radius `r`.
static func belly_of(r: float) -> float:
	return SQUAT*r

## Its fill: `kg` of treasure in it. The belly swells and the rope pays out
## to suit (eased there).
func set_load(kg: float) -> void:
	load_kg = maxf(kg,0.0)
	_radius_to = Weights.BAG_R+Weights.BAG_R_KG*sqrt(load_kg)
	_length_to = Weights.BAG_ROPE+Weights.BAG_ROPE_KG*load_kg

## The bag's mesh at radius `r` (its frame: floor at the origin, up y): a
## cloth bowl up to CLOTH of the belly, rope net over the rest, gathered
## at the neck to the hook.
func _shape(r: float) -> void:
	_drawn_r = r
	var h := hook_of(r)
	var c := belly_of(r)
	var net := SurfaceTool.new()
	net.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lat := 10
	for m in range(MERIDIANS):
		var a := TAU*m/MERIDIANS
		var prev := Vector3.ZERO
		for j in range(1,lat+1):
			var p := _belly_at(r,c,a,float(j)/lat)
			_tube(net,prev,p,0.016)
			prev = p
		_tube(net,prev,Vector3(0.0,h,0.0),0.016)
	for ring: float in [0.5,0.68,0.84]:
		var prev := _belly_at(r,c,0.0,ring)
		for m in range(1,MERIDIANS*2+1):
			var p := _belly_at(r,c,TAU*m/(MERIDIANS*2),ring)
			_tube(net,prev,p,0.013)
			prev = p
	_net.mesh = net.commit()
	var cloth := SurfaceTool.new()
	cloth.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 5
	var cols := MERIDIANS*2
	for j in range(rows):
		for m in range(cols):
			var a0 := TAU*m/cols
			var a1 := TAU*(m+1)/cols
			var v0 := CLOTH*j/rows
			var v1 := CLOTH*(j+1)/rows
			var q := [_belly_at(r,c,a0,v0),_belly_at(r,c,a1,v0),_belly_at(r,c,a1,v1),_belly_at(r,c,a0,v1)]
			# A little give in the cloth: its rim sags between the ribs.
			for corner in [2,3]:
				var aa := a1 if corner == 2 else a0
				q[corner] += Vector3.DOWN*0.04*r*absf(sin(aa*MERIDIANS*0.5))
			for tri: Array in [[0,1,2],[0,2,3]]:
				for idx: int in tri:
					var pp: Vector3 = q[idx]
					cloth.set_normal(Vector3(pp.x,pp.y-c,pp.z).normalized())
					cloth.add_vertex(pp)
	_cloth.mesh = cloth.commit()
	(_basket.get_node("Knot") as Node3D).position = Vector3(0.0,h,0.0)

## A point on the belly (radius `r`, middle up `c`): round `a`, `v` of the
## way from its bottom (0) to its top (1), the top gathered in to the neck.
static func _belly_at(r: float, c: float, a: float, v: float) -> Vector3:
	var th := PI*v
	var rho := r*sin(th)
	if v > 0.5: rho *= lerpf(1.0,0.35,pow((v-0.5)/0.5,1.5))
	return Vector3(cos(a)*rho,c-c*cos(th),sin(a)*rho)

## A four-sided tube from `a` to `b` into `st`.
static func _tube(st: SurfaceTool, a: Vector3, b: Vector3, r: float) -> void:
	var d := b-a
	if d.length() < 0.0001: return
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()*r
	var z := y.cross(x).normalized()*r
	var ring := [x,z,-x,-z]
	for i in 4:
		var p0: Vector3 = ring[i]
		var p1: Vector3 = ring[(i+1)%4]
		var n := (p0+p1).normalized()
		for v: Vector3 in [a+p0,b+p0,b+p1,a+p0,b+p1,a+p1]:
			st.set_normal(n)
			st.add_vertex(v)

## A unit-tall cylinder's transform reaching from `a` to `b`.
static func _between(a: Vector3, b: Vector3) -> Transform3D:
	var d := b-a
	var l := d.length()
	if l < 0.0001: return Transform3D(Basis.IDENTITY.scaled(Vector3(1,0.0001,1)),a)
	var y := d/l
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x,y*l,z),(a+b)*0.5)

## Where it is tied on `pf` (world).
static func tie_of(pf: Node3D) -> Vector3:
	return pf.global_transform*TIE

## At rest on the ground behind the plane's figure `pf` (or hanging under
## the tie with no ground there).
func rest_behind(pf: Node3D) -> void:
	var back := pf.global_basis.z
	back.y = 0.0
	back = back.normalized() if back.length() > 0.01 else Vector3.BACK
	var tie := tie_of(pf)
	length = _length_to
	radius = _radius_to
	var at := tie+back*(Weights.BAG_REST+radius)
	var under := _floor(at,3.0,6.0)
	if under == Vector3.INF: hook = tie+Vector3.DOWN*length
	else: hook = under+Vector3.UP*hook_of(radius)
	_was = hook
	vel = Vector3.ZERO
	_anchor = tie
	up = Vector3.UP
	_draw(pf)

## One frame of the swing under `pf`.
func step(delta: float, pf: Node3D) -> void:
	var tie := tie_of(pf)
	if _anchor == Vector3.INF or tie.distance_to(_anchor) > JUMP:
		rest_behind(pf)
		return
	_anchor = tie
	if delta <= 0.0:
		_draw(pf)
		return
	# It swells and pays out rope as it fills (eased).
	radius = move_toward(radius,_radius_to,0.8*delta)
	length = move_toward(length,_length_to,1.5*delta)
	var hk := hook_of(radius)
	var v := (hook-_was)/delta
	v *= exp(-DRAG*delta)
	v += Vector3.DOWN*GRAVITY*delta
	_was = hook
	hook += v*delta
	# The rope: never longer than its length.
	var off := hook-tie
	var taut := off.length() >= length-0.02
	if off.length() > length: hook = tie+off.normalized()*length
	# The bag's belly swept from where it was: it stops on what it hits.
	_sweep(delta)
	# The ground under the bag.
	var under := _floor(hook,0.5,hk+1.5)
	grounded = false
	if under != Vector3.INF and hook.y < under.y+hk:
		hook.y = under.y+hk
		grounded = true
		# It scuffs along: most of its slide gone.
		var slide := hook-_was
		var keep := exp(-SCUFF*delta)
		_was = Vector3(hook.x-slide.x*keep,hook.y,hook.z-slide.z*keep)
	vel = (hook-_was)/delta
	# The bag hangs along the rope when it pulls; stands up on the ground.
	var want := Vector3.UP
	if not grounded and taut: want = (tie-hook).normalized()
	# Eased toward it (a lerp, not slerp: slerp's axis trips Basis's
	# normalized check when up has drifted a hair off unit length).
	var eased := up.lerp(want,1.0-exp(-8.0*delta))
	up = eased.normalized() if eased.length_squared() > 1e-6 else want
	_draw(pf)

## The belly as a ball, swept from last frame's spot to this one's (the
## hook moved by the swing and the rope). On a hit it stops there, loses
## its speed into what it hit (a little bounce), slides on along it, and
## `hit` says how hard. Pinned (the rope stretched past BAG_PIN by
## something holding it back), the rope wins and it pulls free.
func _sweep(delta: float) -> void:
	if not is_inside_tree(): return
	var down := up*(hook_of(radius)-belly_of(radius))
	var c0 := _was-down
	var c1 := hook-down
	var motion := c1-c0
	if motion.length() < 0.0005: return
	var space := get_world_3d().direct_space_state
	var ball := SphereShape3D.new()
	ball.radius = radius*Weights.BAG_BALL
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = ball
	q.collision_mask = SOLID_MASK
	q.transform = Transform3D(Basis.IDENTITY,c0)
	q.motion = motion
	var cast := space.cast_motion(q)
	if cast.size() < 2 or float(cast[1]) >= 1.0: return
	# Started inside something (lying in a dip, dragged on the turf): let it.
	if float(cast[0]) <= 0.0 and float(cast[1]) <= 0.0: return
	var safe := maxf(float(cast[0])-0.01,0.0)
	q.transform = Transform3D(Basis.IDENTITY,c0+motion*float(cast[1]))
	q.motion = Vector3.ZERO
	var info := space.get_rest_info(q)
	var n: Vector3 = info.normal if info.has("normal") else -motion.normalized()
	var at: Vector3 = info.point if info.has("point") else c0+motion*float(cast[1])
	var v := motion/delta
	var into := -v.dot(n)
	var c := c0+motion*safe
	# Slide on along what it hit with what's left of the move.
	var rest := motion*(1.0-safe)
	rest -= n*rest.dot(n)
	q.transform = Transform3D(Basis.IDENTITY,c)
	q.motion = rest
	var more := space.cast_motion(q)
	if more.size() >= 1: c += rest*maxf(float(more[0])-0.01,0.0)
	var was_hook := hook
	hook = c+down
	var tie := _anchor
	if tie.distance_to(hook) > length+Weights.BAG_PIN:
		hook = was_hook
		return
	# Its speed into the wall gone, a little of it back.
	var vout := v
	if into > 0.0: vout += n*into*(1.0+Weights.BAG_BOUNCE)
	_was = hook-vout*delta
	if into > 0.0:
		hits += 1
		hit.emit(into,at,n,v)

## The bag's frame: its floor's middle, up its `up`, turned with the
## plane.
func basket_xform(pf: Node3D) -> Transform3D:
	var fwd := -pf.global_basis.z
	var x := up.cross(-fwd)
	if x.length() < 0.01: x = up.cross(Vector3.FORWARD)
	x = x.normalized()
	var z := x.cross(up).normalized()
	return Transform3D(Basis(x,up,z),hook-up*hook_of(radius))

## Loaded spot `i` (world): the treasure's foot in the bag. The first sits
## in the middle of its floor, the rest round it up the bowl (a golden
## turn apart), every sixth a layer higher.
func slot(i: int, pf: Node3D) -> Transform3D:
	var b := basket_xform(pf)
	var r := radius
	var c := belly_of(r)
	var p := Vector3(0.0,0.04,0.0)
	if i > 0:
		var a := i*2.39996
		var rho := r*0.45
		var y := c-c*sqrt(maxf(1.0-(rho/r)*(rho/r),0.0))
		p = Vector3(cos(a)*rho,y+0.04+float(i/6)*0.3*r,sin(a)*rho)
	return Transform3D(b.basis,b*p)

## The middle of its floor (world).
func middle() -> Vector3:
	return hook-up*hook_of(radius)

## The middle of its belly (world).
func belly() -> Vector3:
	return hook-up*(hook_of(radius)-belly_of(radius))

func _draw(pf: Node3D) -> void:
	if absf(radius-_drawn_r) > 0.005: _shape(radius)
	_basket.global_transform = basket_xform(pf)
	# The rope from the tie to the hook: straight when taut, sagging slack.
	var tie := _anchor
	var gap := tie.distance_to(hook)
	var sag := sqrt(maxf(length*length-gap*gap,0.0))*0.45
	var prev := tie
	for i in range(ROPE_BITS):
		var k := float(i+1)/ROPE_BITS
		var p := tie.lerp(hook,k)+Vector3.DOWN*sag*4.0*k*(1.0-k)
		if grounded:
			# Lying on the turf, it can't sag under it.
			var g := _floor(p,0.3,1.0)
			if g != Vector3.INF and p.y < g.y+0.03: p.y = g.y+0.03
		_rope[i].global_transform = _between(prev,p)
		prev = p

func _floor(p: Vector3, over: float, under: float) -> Vector3:
	if not is_inside_tree(): return Vector3.INF
	var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*over,p+Vector3.DOWN*under,SOLID_MASK)
	var hit_at := get_world_3d().direct_space_state.intersect_ray(ray)
	return Vector3.INF if hit_at.is_empty() else hit_at.position
