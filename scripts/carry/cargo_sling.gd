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
## A loot bag hitched on in its place (scripts/carry/loot_bag.gd): its
## belly's radius (m) the sling's while it rides, -1 none (`hitch_bag`).
var bag_r := -1.0
## No basket (--loot-bag, docs/design/bag-hitch/): its own sack gone, a
## bare rope with an iron hook at its end; a hitched bag is the cargo
## (`set_bare`). The hook's ball radius (m) while nothing is hitched.
var bare := false
const HOOK_R := 0.1
const IRON := Color("3d3a36")
## The bare hook: drawn this much bigger than its modelled size, in worn
## bright iron, with a glint, so it shows in the grass behind the tail.
const HOOK_LOOK := 1.7
const HOOK_IRON := Color("a7a294")
var _hook: Node3D = null
var _hook_glint: Node3D = null
## The rope as a light chain (verlet): ROPE_BITS+1 points from the tie to
## the drawn hook, gravity, the air's drag, the turf under it (it lies on
## it and drags on it, so in a turn it swings wide and lags).
var _pts := PackedVector3Array()
var _pts_was := PackedVector3Array()
var taut := false
const ROPE_AIR := 1.2
const ROPE_SCUFF := 10.0
const ROPE_ITERS := 14
const ROPE_THICK := 0.025
## The dragged look (drawn only, round the physics point `hook`): taxiing
## on the turf it wanders side to side, swings out in a turn, hops on
## bumps, tumbles a little, catches and jerks free; on takeoff the rope's
## pull up makes it hop before it leaves the turf. `_d_off` (world,
## level), `_d_hop` (up), `_d_roll` round the drag line, `_d_pitch`
## across it; `_d_rot` / `_d_shift` what `basket_xform` draws with.
var _d_off := Vector3.ZERO
var _d_v := Vector3.ZERO
var _d_hop := 0.0
var _d_hop_v := 0.0
var _d_roll := 0.0
var _d_roll_v := 0.0
var _d_pitch := 0.0
var _d_pitch_v := 0.0
var _d_catch := 0.0
var _d_dist := 0.0
var _d_tie_v := Vector3.ZERO
var _d_tie_was := Vector3.INF
var _d_rot := Basis.IDENTITY
var _d_shift := Vector3.ZERO
var _d_rng := RandomNumberGenerator.new()
## Hops, catches so far (drivers).
var hops := 0
var catches := 0
const D_SPRING := 16.0
const D_DAMP := 3.2
const D_SWING := 0.09
const D_WANDER := 0.35
const D_HOP_RATE := 0.45
const D_CATCH_RATE := 0.08

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
	_d_rng.seed = 7177

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
	_radius_to = bag_r if bag_r > 0.0 else (HOOK_R if bare else Weights.BAG_R+Weights.BAG_R_KG*sqrt(load_kg))
	_length_to = Weights.BAG_ROPE+Weights.BAG_ROPE_KG*load_kg

## A loot bag on the rope in its own sack's place (radius `r`, m; -1 off):
## the sling's sack hidden, its belly sized to the bag (the caller draws
## the bag at `basket_xform` and refills the kg).
func hitch_bag(r: float) -> void:
	bag_r = r
	_show()
	set_load(load_kg)

## No basket (`on`): the rope ends in a bare hook till a bag is hitched.
func set_bare(on: bool) -> void:
	bare = on
	if on and _hook == null: _make_hook()
	_show()
	set_load(load_kg)
	if on and bag_r <= 0.0:
		radius = _radius_to

func _show() -> void:
	_basket.visible = bag_r <= 0.0 and not bare
	if _hook != null: _hook.visible = bare and bag_r <= 0.0

## The iron hook: a shank from the rope's end down to a curl, its point
## up (its frame: the rope's end at the origin, up y).
func _make_hook() -> void:
	_hook = Node3D.new()
	_hook.name = "Hook"
	add_child(_hook)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = HOOK_IRON
	iron.metallic = 0.7
	iron.roughness = 0.35
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shank := 0.22
	_tube(st,Vector3(0.0,0.0,0.0),Vector3(0.0,-shank,0.0),0.018)
	# The curl: a half turn under the shank's foot, up to the point.
	var rr := 0.07
	var c := Vector3(rr,-shank,0.0)
	var prev := Vector3(0.0,-shank,0.0)
	for i in range(1,11):
		var a := PI+PI*float(i)/10.0
		var p := c+Vector3(cos(a)*rr,sin(a)*rr,0.0)
		_tube(st,prev,p,0.018)
		prev = p
	_tube(st,prev,prev+Vector3(-0.015,0.06,0.0),0.012)
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = iron
	_hook.add_child(m)
	var eye := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.02
	tor.outer_radius = 0.04
	eye.mesh = tor
	eye.material_override = iron
	eye.rotation = Vector3(PI*0.5,0.0,0.0)
	eye.position = Vector3(0.0,0.02,0.0)
	_hook.add_child(eye)
	var g: Sprite3D = (load("res://scripts/kit_isle/kit_cache_glint.gd") as GDScript).new()
	g.name = "HookGlint"
	g.set_instance_shader_parameter("tint",Color(0.9,0.95,1.0))
	g.rng.seed = 4421
	add_child(g)
	_hook_glint = g

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
	_dress_reset()
	_pts.clear()
	_draw(pf,0.0)

## One frame of the swing under `pf`.
func step(delta: float, pf: Node3D) -> void:
	var tie := tie_of(pf)
	if _anchor == Vector3.INF or tie.distance_to(_anchor) > JUMP:
		rest_behind(pf)
		return
	_anchor = tie
	if delta <= 0.0:
		_draw(pf,0.0)
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
	taut = off.length() >= length-0.02
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
	_dress(delta,tie)
	_draw(pf,delta)

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
	var b := Transform3D(Basis(x,up,z),hook-up*hook_of(radius))
	var piv := belly()
	return Transform3D(_d_rot*b.basis,piv+_d_rot*(b.origin-piv)+_d_shift)

## The hook where it is drawn (the dragged look round `hook`).
func drawn_hook() -> Vector3:
	var piv := belly()
	return piv+_d_rot*(hook-piv)+_d_shift

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

func _draw(pf: Node3D, delta: float) -> void:
	if absf(radius-_drawn_r) > 0.005: _shape(radius)
	var b := basket_xform(pf)
	_basket.global_transform = b
	var end := drawn_hook()
	if _hook != null and _hook.visible:
		# The bare hook hangs off the rope's end; lying, it falls over on
		# the turf and the rope runs down to it.
		if grounded: end = b.origin+b.basis.y*0.03
		var lie := Basis(Vector3.FORWARD,PI*0.5) if grounded else Basis.IDENTITY
		_hook.global_transform = Transform3D((b.basis*lie).scaled_local(Vector3.ONE*HOOK_LOOK),end)
		# The glint on its curl, facing up (seen from anywhere above).
		_hook_glint.global_transform = Transform3D(Basis(Vector3.RIGHT,-PI*0.5),_hook.global_transform*Vector3(0.07,-0.22,0.0)+Vector3.UP*0.03)
	if _hook_glint != null: _hook_glint.visible = _hook != null and _hook.visible
	_rope_step(delta,_anchor,end)
	for i in range(ROPE_BITS):
		_rope[i].global_transform = _between(_pts[i],_pts[i+1])

## The rope, a chain of ROPE_BITS bits pinned at the tie and at `end`:
## each point keeps its swing (less the air's drag), falls, is held to
## its neighbours' spacing, and lies on and drags along the turf.
func _rope_step(delta: float, tie: Vector3, end: Vector3) -> void:
	var n := ROPE_BITS+1
	var gap := tie.distance_to(end)
	var rest := maxf(length,gap)/ROPE_BITS
	if _pts.size() != n:
		_pts.resize(n)
		_pts_was.resize(n)
		# Laid along the line, sagging to the turf.
		var sag := sqrt(maxf(length*length-gap*gap,0.0))*0.45
		for i in range(n):
			var k := float(i)/ROPE_BITS
			var p := tie.lerp(end,k)+Vector3.DOWN*sag*4.0*k*(1.0-k)
			var g := _floor(p,0.6,1.5)
			if g != Vector3.INF and p.y < g.y+ROPE_THICK: p.y = g.y+ROPE_THICK
			_pts[i] = p
			_pts_was[i] = p
	_pts[0] = tie
	_pts[n-1] = end
	if delta > 0.0:
		var keep := exp(-ROPE_AIR*delta)
		var fall := Vector3.DOWN*GRAVITY*delta*delta
		for i in range(1,n-1):
			var p := _pts[i]
			var v := (p-_pts_was[i])*keep
			# A frame's jump past this is a teleport: settle, don't fling.
			if v.length() > 3.0: v = Vector3.ZERO
			_pts_was[i] = p
			_pts[i] = p+v+fall
		for it in range(ROPE_ITERS):
			for i in range(n-1):
				var a := _pts[i]
				var c := _pts[i+1]
				var d := c-a
				var l := d.length()
				if l < 1e-5: continue
				var fix := d*((l-rest)/l)
				if i == 0: _pts[1] = c-fix
				elif i+1 == n-1: _pts[i] = a+fix
				else:
					_pts[i] = a+fix*0.5
					_pts[i+1] = c-fix*0.5
		# The turf: it lies on it, and drags along it.
		var scuff := exp(-ROPE_SCUFF*delta)
		for i in range(1,n-1):
			var p := _pts[i]
			var g := _floor(p,0.4,0.6)
			if g != Vector3.INF and p.y < g.y+ROPE_THICK:
				p.y = g.y+ROPE_THICK
				var w := _pts_was[i]
				var slide := Vector3(p.x-w.x,0.0,p.z-w.z)*scuff
				_pts_was[i] = Vector3(p.x-slide.x,p.y,p.z-slide.z)
				_pts[i] = p

## The dragged look back to rest.
func _dress_reset() -> void:
	_d_off = Vector3.ZERO
	_d_v = Vector3.ZERO
	_d_hop = 0.0
	_d_hop_v = 0.0
	_d_roll = 0.0
	_d_roll_v = 0.0
	_d_pitch = 0.0
	_d_pitch_v = 0.0
	_d_catch = 0.0
	_d_tie_was = Vector3.INF
	_d_tie_v = Vector3.ZERO
	_d_rot = Basis.IDENTITY
	_d_shift = Vector3.ZERO

## One frame of the dragged look: on the turf and pulled along, it
## wanders, swings out, hops, tumbles and catches; off it, it eases back
## onto the physics point.
func _dress(delta: float, tie: Vector3) -> void:
	var tv := Vector3.ZERO if _d_tie_was == Vector3.INF else (tie-_d_tie_was)/delta
	if tv.length() > 60.0: tv = _d_tie_v
	var acc := ((tv-_d_tie_v)/delta).limit_length(40.0)
	_d_tie_was = tie
	_d_tie_v = tv
	var flat := Vector3(tie.x-hook.x,0.0,tie.z-hook.z)
	var dir := flat.normalized() if flat.length() > 0.05 else Vector3.FORWARD
	var side := dir.cross(Vector3.UP).normalized()
	var spd := Vector2(vel.x,vel.z).length()
	var s := clampf(radius/0.3,0.5,1.6)
	var on := grounded or _d_hop > 0.0
	var go := clampf((spd-0.6)/4.0,0.0,1.0) if grounded else 0.0
	# The rope pulls up (takeoff, a climb off the turf): it hops.
	var lift := 0.0
	if grounded and taut: lift = clampf(((tie-hook).normalized().y-0.05)*3.0,0.0,1.0)
	_d_dist += spd*delta
	if on:
		# Side to side: a slow wander by the ground covered, and out in a
		# turn (against the tie's sideways pull).
		var wander := (sin(_d_dist*0.9)+0.6*sin(_d_dist*2.3+1.7)+0.4*sin(_d_dist*0.37+4.0))*D_WANDER*s*go
		var f := -_d_off*D_SPRING-_d_v*D_DAMP
		f += side*wander*D_SPRING
		f += -side*acc.dot(side)*D_SWING*D_SPRING*s
		if _d_catch > 0.0:
			# Caught on the turf: it stops while the rope runs on.
			_d_catch -= delta
			f = f-dir*f.dot(dir)
			_d_v = _d_v-dir*_d_v.dot(dir)-dir*spd*0.9
			if _d_catch <= 0.0 or _d_off.dot(dir) < -0.45*s:
				# Jerked free: a hop and a twist.
				_d_catch = 0.0
				_kick(1.3*s,0.8)
				_d_v += dir*spd*0.5
		elif grounded and spd > 2.0 and _d_hop <= 0.0 and _d_rng.randf() < D_CATCH_RATE*go*spd*delta:
			_d_catch = _d_rng.randf_range(0.12,0.3)
			catches += 1
		_d_v += f*delta
		_d_off += _d_v*delta
		_d_off.y = 0.0
		_d_v.y = 0.0
		_d_off = _d_off.limit_length(0.9*s)
		# Hops: bumps by the speed, more as the rope pulls up.
		if grounded and _d_hop <= 0.0 and _d_catch <= 0.0:
			var rate := D_HOP_RATE*spd*go*(1.0+4.0*lift)
			if _d_rng.randf() < rate*delta: _kick(_d_rng.randf_range(0.6,1.4)*clampf(spd/3.5,0.0,2.2)*(1.0+1.2*lift),0.5)
		_d_hop_v -= GRAVITY*delta
		_d_hop += _d_hop_v*delta
		if _d_hop <= 0.0:
			_d_hop = 0.0
			if _d_hop_v < -0.8:
				_d_roll_v += _d_rng.randf_range(-3.0,3.0)
				_d_hop_v = -_d_hop_v*0.3
			else: _d_hop_v = 0.0
		# Tumbles: rolls with its slew, pitches with its hop, eased back up.
		var roll_to := -_d_v.dot(side)*0.25/s
		_d_roll_v += ((roll_to-_d_roll)*24.0-_d_roll_v*3.5)*delta
		_d_roll += _d_roll_v*delta
		_d_roll = clampf(_d_roll,-0.8,0.8)
		var pitch_to := _d_hop_v*0.12+go*0.12
		_d_pitch_v += ((pitch_to-_d_pitch)*24.0-_d_pitch_v*4.0)*delta
		_d_pitch += _d_pitch_v*delta
		_d_pitch = clampf(_d_pitch,-0.7,0.7)
	else:
		var k := 1.0-exp(-4.0*delta)
		_d_off = _d_off.lerp(Vector3.ZERO,k)
		_d_v = Vector3.ZERO
		_d_hop = lerpf(_d_hop,0.0,k)
		_d_hop_v = 0.0
		_d_roll = lerpf(_d_roll,0.0,k)
		_d_roll_v = 0.0
		_d_pitch = lerpf(_d_pitch,0.0,k)
		_d_pitch_v = 0.0
		_d_catch = 0.0
	# A rumble on the turf while it slides.
	var rumble := absf(sin(_d_dist*6.0))*0.025*s*go
	_d_shift = _d_off+Vector3.UP*(_d_hop+rumble)
	_d_rot = Basis(dir,_d_roll)*Basis(side,-_d_pitch)

## A hop off the turf at `v` m/s, with a twist of `twist` rad/s.
func _kick(v: float, twist: float) -> void:
	hops += 1
	_d_hop_v = maxf(_d_hop_v,v)
	_d_hop = maxf(_d_hop,0.001)
	_d_roll_v += _d_rng.randf_range(-1.0,1.0)*twist*3.0
	_d_pitch_v += _d_rng.randf_range(0.5,1.0)*twist*2.0

func _floor(p: Vector3, over: float, under: float) -> Vector3:
	if not is_inside_tree(): return Vector3.INF
	var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*over,p+Vector3.DOWN*under,SOLID_MASK)
	var hit_at := get_world_3d().direct_space_state.intersect_ray(ray)
	return Vector3.INF if hit_at.is_empty() else hit_at.position
