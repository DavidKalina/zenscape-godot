extends Node3D
## The plane's cargo sling (docs/design/carry/spec-carry.md, the hitch): a
## rope net basket on a rope from the plane's belly. It is one point (the
## hook where the basket's four bridles meet) swung as a pendulum: gravity,
## the air's drag, the rope (never longer than LENGTH; slack, it sags) and
## the ground (the basket sits on what is under it, and drags on it).
## Parked, it lies on the turf behind the plane; taxiing it drags behind;
## off the edge it swings up under the plane and hangs and trails there,
## swinging with the plane's turns and pulls. Treasures loaded into it
## (scripts/carry/carry_host.gd) stand on its floor at `slot(i)`.
##
## It lives in the world (top_level), stepped by the carry host each frame
## with the plane's figure: `step(delta, plane_figure)`.

## The rope (m), where it is tied under the plane (the figure's own frame:
## toy units, times its scale), the hook's height over the basket's floor,
## the basket's radius at its rim and floor, its depth; gravity, the air's
## drag (1/s: trailing back at speed), the drag of the ground (1/s), a
## jump of the plane this far in one frame puts it back at rest.
const LENGTH := 2.6
const TIE := Vector3(0.0,-0.16,0.12)
const HOOK := 0.95
const RIM := 0.56
const FLOOR_R := 0.46
const DEPTH := 0.34
const GRAVITY := 9.8
const DRAG := 0.35
const SCUFF := 9.0
const JUMP := 8.0
## Where it rests behind a parked plane (m behind its middle).
const REST_BACK := 2.6
## The loaded treasures' spots on its floor (x, z out from the middle, m).
const SLOTS := [Vector2(-0.2,-0.2),Vector2(0.2,0.2),Vector2(0.2,-0.2),Vector2(-0.2,0.2)]
const SOLID_MASK := 1|(1 << 11)
const ROPE_BITS := 12
const ROPE := Color("9a7b52")
const NET := Color("6e5233")

## The hook (world) now and last frame; the basket's up; on the ground.
var hook := Vector3.ZERO
var _was := Vector3.ZERO
var up := Vector3.UP
var grounded := true
var _anchor := Vector3.INF
var _basket: Node3D = null
var _rope: Array[MeshInstance3D] = []
var _bridles: Array[MeshInstance3D] = []
var _rope_mat: StandardMaterial3D = null

func _init() -> void:
	name = "CargoSling"
	top_level = true
	_rope_mat = StandardMaterial3D.new()
	_rope_mat.albedo_color = ROPE
	_rope_mat.roughness = 0.9
	var net := StandardMaterial3D.new()
	net.albedo_color = NET
	net.roughness = 0.9
	_basket = Node3D.new()
	_basket.name = "Basket"
	add_child(_basket)
	# The floor: a flat round mat.
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = FLOOR_R
	floor_mesh.bottom_radius = FLOOR_R
	floor_mesh.height = 0.04
	floor_mesh.radial_segments = 12
	_part(_basket,floor_mesh,Transform3D(Basis.IDENTITY,Vector3(0.0,0.02,0.0)),net)
	# The net's walls: ribs up from the floor's edge to the rim, two rings.
	for i in range(12):
		var a := TAU*i/12.0
		var lo := Vector3(cos(a)*FLOOR_R,0.02,sin(a)*FLOOR_R)
		var hi := Vector3(cos(a)*RIM,DEPTH,sin(a)*RIM)
		_basket.add_child(_strand(lo,hi,0.014,net))
	for ring: Array in [[0.5,0.012],[1.0,0.022]]:
		var r := lerpf(FLOOR_R,RIM,float(ring[0]))
		var torus := TorusMesh.new()
		torus.inner_radius = r-float(ring[1])
		torus.outer_radius = r+float(ring[1])
		torus.rings = 24
		torus.ring_segments = 6
		_part(_basket,torus,Transform3D(Basis.IDENTITY,Vector3(0.0,DEPTH*float(ring[0]),0.0)),net)
	# Four bridles from the rim up to the hook (kept straight, in its frame).
	for i in range(4):
		var a := TAU*(i+0.5)/4.0
		var m := _strand(Vector3(cos(a)*RIM,DEPTH,sin(a)*RIM),Vector3(0.0,HOOK,0.0),0.012,_rope_mat)
		_basket.add_child(m)
		_bridles.append(m)
	var knot := SphereMesh.new()
	knot.radius = 0.05
	knot.height = 0.1
	_part(_basket,knot,Transform3D(Basis.IDENTITY,Vector3(0.0,HOOK,0.0)),_rope_mat)
	for i in range(ROPE_BITS):
		var bit := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.02
		c.bottom_radius = 0.02
		c.height = 1.0
		c.radial_segments = 5
		c.rings = 1
		bit.mesh = c
		bit.material_override = _rope_mat
		add_child(bit)
		_rope.append(bit)

static func _part(under: Node3D, mesh: Mesh, at: Transform3D, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = at
	under.add_child(mi)

## A thin rope from `a` to `b` (its parent's frame).
static func _strand(a: Vector3, b: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = 1.0
	c.radial_segments = 4
	c.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = mat
	mi.transform = _between(a,b)
	return mi

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
	var at := tie+back*REST_BACK
	var under := _floor(at,3.0,6.0)
	if under == Vector3.INF: hook = tie+Vector3.DOWN*LENGTH
	else: hook = under+Vector3.UP*HOOK
	_was = hook
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
	var v := (hook-_was)/delta
	v *= exp(-DRAG*delta)
	v += Vector3.DOWN*GRAVITY*delta
	_was = hook
	hook += v*delta
	# The rope: never longer than LENGTH.
	var off := hook-tie
	var taut := off.length() >= LENGTH-0.02
	if off.length() > LENGTH: hook = tie+off.normalized()*LENGTH
	# The ground under the basket.
	var under := _floor(hook,0.5,HOOK+1.5)
	grounded = false
	if under != Vector3.INF and hook.y < under.y+HOOK:
		hook.y = under.y+HOOK
		grounded = true
		# It scuffs along: most of its slide gone.
		var slide := hook-_was
		var keep := exp(-SCUFF*delta)
		_was = Vector3(hook.x-slide.x*keep,hook.y,hook.z-slide.z*keep)
	# The basket hangs along the rope when it pulls; stands up on the ground.
	var want := Vector3.UP
	if not grounded and taut: want = (tie-hook).normalized()
	up = up.slerp(want,1.0-exp(-8.0*delta)).normalized()
	_draw(pf)

## The basket's frame: its floor's middle, up its `up`, turned with the
## plane.
func basket_xform(pf: Node3D) -> Transform3D:
	var fwd := -pf.global_basis.z
	var x := up.cross(-fwd)
	if x.length() < 0.01: x = up.cross(Vector3.FORWARD)
	x = x.normalized()
	var z := x.cross(up).normalized()
	return Transform3D(Basis(x,up,z),hook-up*HOOK)

## Loaded spot `i` (world): the treasure's foot on the floor.
func slot(i: int, pf: Node3D) -> Transform3D:
	var b := basket_xform(pf)
	var s: Vector2 = SLOTS[i%SLOTS.size()]
	return Transform3D(b.basis,b*Vector3(s.x,0.04,s.y))

## The middle of its floor (world).
func middle() -> Vector3:
	return hook-up*HOOK

func _draw(pf: Node3D) -> void:
	_basket.global_transform = basket_xform(pf)
	# The rope from the tie to the hook: straight when taut, sagging slack.
	var tie := _anchor
	var gap := tie.distance_to(hook)
	var sag := sqrt(maxf(LENGTH*LENGTH-gap*gap,0.0))*0.45
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
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return Vector3.INF if hit.is_empty() else hit.position
