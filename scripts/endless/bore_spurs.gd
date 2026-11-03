extends Node3D
## The spurs the burrower leaves in a sunk tunnel (docs/design/endless-flight/
## spec-burrower-chase.md). The layout is fixed per tunnel, drawn from its seed (`plan`):
## which spurs, how far along, how long; the angle is his line's there (BoreLine), so the
## ridge marks each spot. He reveals them as he passes, whichever way he runs, and they
## fire off him, not off the plane: `passing` starts a spur's clock and its tell (the crack,
## the grit, the light: scripts/endless/bore_tell.gd), HOLD_S later it snaps out of the
## bore. Each stays out for as long as its tunnel stays built. Nothing goes in the save,
## and a tunnel he hasn't run has none.
##
## A spur is a pooled rock (a shared mesh, its own convex collider) that slides out of the
## rock along its axis. The bore's own mesh and collision are never touched. It is stone
## twice over, as a hall's column is: a body on LandTunnels.LAYER for NearMiss's rays, and
## a run of spheres down its axis for the plane's middle and the camera (`stretches`,
## `inside`, through LandTunnels `ground`, `inside` and `sight`). FlightContact takes its
## normal from `face`. The bore overhead doesn't cancel a graze on one (NearMiss, `holds`).
##
## The gap: a spur stops short of the far rock by at least WorldScale.opening(TOY_PAST),
## measured against the bore's real ring at its spot (`_lay`); a spot that can't leave
## that and still stand REACH_LEAST m out has no spur.

const Tunnels = preload("res://scripts/endless/tunnel_sites.gd")
const LandTunnels = preload("res://scripts/endless/land_tunnels.gd")
const BoreLine = preload("res://scripts/endless/bore_line.gd")
const BoreTell = preload("res://scripts/endless/bore_tell.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const SPUR_SHADER = preload("res://shaders/burrower_bore_spur.gdshader")

## One spur about every this many metres of tunnel: the knob flying tunes.
const SPUR_EVERY := 85.0
## None this close to either mouth (m), and how far a spot wanders off its even place
## (a share of the spacing).
const SPUR_ENDS := 130.0
const SPUR_WANDER := 0.3
## The way left past a spur's tip, toy width (WorldScale `opening`).
const TOY_PAST := 4.0
## How far it stands out: a share of the way across the bore from its root, and the most
## and least (m). Its root's radius: a share of that.
const REACH_SHARE := Vector2(0.42,0.72)
const REACH_MOST := 18.0
const REACH_LEAST := 5.0
const GIRTH_SHARE := Vector2(0.17,0.25)
## Off the bore's middle in the section, and along the path (rad, the most either way).
const TILT := 0.3
const LEAN := 0.25
## No spur with its root or tip this close past a shaft's edge (m).
const SHAFT_ROOM := 6.0
## The hold from him passing to the snap (s), the snap's length (s).
const HOLD_S := 0.8
const SNAP_S := 0.16
## The snap's sound.
const SNAP_GAIN := 0.8
const SNAP_PITCH := 0.7
## Laid out this far ahead of him (m; one a frame), and counted near the plane this far (m).
const LAY_AHEAD := 170.0
const NEAR_M := 45.0
## How far under the rock a spur's tip lies before the snap (m).
const TUCK := 0.5
## The rock: rings up the unit spur, y up its length (0 at the rock, 1 the tip), radius
## as a share of the root's: in steps, so it reads as broken strata and not a cone. Below
## 0 it runs on into the rock, so a lump can't lift its foot into view.
const RING_Y := [-0.3,0.0,0.14,0.2,0.42,0.48,0.68,0.74,0.9,1.0]
const RING_R := [1.2,1.0,0.92,0.7,0.6,0.42,0.34,0.22,0.16,0.05]
const SIDES := 7
const SHAPES := 3
## How much a ring's points stray (a share of the radius), how far a ring turns against
## the last (rad) and how far the rock bends.
const JAG := 0.3
const TWIST := 0.3
const BEND := 0.12
## The spheres down a spur's axis (the plane's solid), and how far past them a touch
## still counts as on the spur (`face`).
const CHAIN := 9
const FACE_ROOM := 0.8

## One spur: its place in the layout, then, once laid (`_lay`), where it stands. `laid`
## with no body: no room here, no spur.
class Spur:
	var s := 0.0
	var share := 0.0
	var thick := 0.0
	var tilt := 0.0
	var lean := 0.0
	var roll := 0.0
	var shape := 0
	var laid := false
	var fired := false
	var clock := 0.0
	## How far out it is (0..1).
	var out := 0.0
	var root := Vector3.ZERO
	var axis := Vector3.UP
	var long := 0.0
	var girth := 0.0
	var left := 0.0
	var body: StaticBody3D
	## Its tell's patch (BoreTell).
	var crack: MeshInstance3D
	var basis := Basis.IDENTITY
	## Its solid: the spheres' centres from the root, their radii, the bound round them.
	var chain := PackedVector3Array()
	var radii := PackedFloat32Array()
	var bound_at := Vector3.ZERO
	var bound := 0.0

## One tunnel he has run.
class Group:
	var site: Tunnels.Site
	var grain: FastNoiseLite
	var spurs: Array[Spur] = []

var _tunnels: Node3D
var _groups := {}
var _run: Group
var _way := 1.0
## The next spur to lay and to fire, up or down `_run`'s list.
var _lay_i := 0
var _fire_i := 0
var _moving: Array[Spur] = []
var _near: Array[Spur] = []
var _spare: Array[StaticBody3D] = []
var _meshes: Array[ArrayMesh] = []
var _hulls: Array[PackedVector3Array] = []
var _mat: ShaderMaterial
var _tell: BoreTell
## For drivers: the worst frame's work (us), spurs fired, spots dropped.
var stats := {"worst_us": 0, "fired": 0, "dropped": 0}

func _init() -> void:
	name = "BoreSpurs"

func setup(tunnels: Node3D) -> void:
	_tunnels = tunnels
	_mat = ShaderMaterial.new()
	_mat.shader = SPUR_SHADER
	_mat.set_shader_parameter("hold",HOLD_S)
	_tell = BoreTell.new()
	add_child(_tell)
	_tell.setup(HOLD_S,SNAP_S)
	var rng := RandomNumberGenerator.new()
	for i in SHAPES:
		rng.seed = hash(["bore spur",i])
		_make_shape(rng)
	if tunnels != null: tunnels.spurs = self

## The spurs of `t` in order along the path, before any is placed: a plain function of its
## seed. Every spot draws all its numbers, so one with no room changes no other.
static func plan(t: Tunnels.Site) -> Array[Spur]:
	var out: Array[Spur] = []
	var n := int((t.length-2.0*SPUR_ENDS)/SPUR_EVERY)
	if n < 1: return out
	var every := (t.length-2.0*SPUR_ENDS)/n
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([t.seed,"bore spurs"])
	for i in n:
		var sp := Spur.new()
		sp.s = SPUR_ENDS+(i+0.5+rng.randf_range(-SPUR_WANDER,SPUR_WANDER))*every
		sp.share = rng.randf()
		sp.thick = rng.randf()
		sp.tilt = rng.randf_range(-TILT,TILT)
		sp.lean = rng.randf_range(-LEAN,LEAN)
		sp.roll = rng.randf_range(0.0,TAU)
		sp.shape = rng.randi()%SHAPES
		var hall := false
		for piece: Dictionary in t.pieces:
			if piece.kind == "hall" and sp.s >= float(piece.s0) and sp.s <= float(piece.s1): hall = true
		if not hall: out.append(sp)
	return out

## He's in `t`, going `way`: what's left of its layout is his to reveal. A tunnel he's run
## before keeps what came out then.
func begin(t: Tunnels.Site, way: float) -> void:
	var g: Group = _groups.get(t.name)
	if g == null:
		g = Group.new()
		g.site = t
		g.grain = LandTunnels.rock_grain(t)
		g.spurs = plan(t)
		_groups[t.name] = g
	_run = g
	_way = way
	_lay_i = 0 if way > 0.0 else g.spurs.size()-1
	_fire_i = _lay_i

## The chase is over: nothing more comes out, what's on its way still does.
func ended() -> void:
	_run = null

## He's at distance `at`: the next spur laid out ahead of him, and those he's passed fired.
func passing(at: float) -> void:
	if _run == null: return
	var began := Time.get_ticks_usec()
	var list := _run.spurs
	var n := list.size()
	var by := 1 if _way > 0.0 else -1
	if _lay_i >= 0 and _lay_i < n and (list[_lay_i].s-at)*_way < LAY_AHEAD:
		_lay(_run,list[_lay_i])
		_lay_i += by
	else:
		_tell.work()
	while _fire_i >= 0 and _fire_i < n and (at-list[_fire_i].s)*_way >= 0.0:
		var sp := list[_fire_i]
		_fire_i += by
		_lay(_run,sp)
		if sp.body == null or sp.fired: continue
		sp.fired = true
		sp.clock = 0.0
		_moving.append(sp)
		_tell.light(_run.site,_run.grain,sp)
		(sp.body.get_child(0) as MeshInstance3D).set_instance_shader_parameter("lit_at",_tell.now)
		stats.fired = int(stats.fired)+1
	stats.worst_us = maxi(int(stats.worst_us),Time.get_ticks_usec()-began)

## One frame, `at` the plane: the spurs under way, those near it, tunnels gone.
func step(delta: float, at: Vector3, sound: Node) -> void:
	if _groups.is_empty(): return
	_tell.step(delta)
	_mat.set_shader_parameter("now",_tell.now)
	for i in range(_moving.size()-1,-1,-1):
		var sp := _moving[i]
		sp.clock += delta
		var k := (sp.clock-HOLD_S)/SNAP_S
		if k <= 0.0: continue
		if not sp.body.visible:
			sp.body.visible = true
			sp.body.collision_layer = LandTunnels.LAYER
			sound.shot("crack",SNAP_GAIN,SNAP_PITCH,sp.root)
		var o := 1.0-minf(k,1.0)
		sp.out = 1.0-o*o*o
		_pose(sp)
		if k >= 1.0: _moving.remove_at(i)
	_near.clear()
	var flat := Vector2(at.x,at.z)
	for tunnel: String in _groups.keys():
		var g: Group = _groups[tunnel]
		if g != _run and _tunnels != null and not _tunnels.has_built(tunnel):
			_let_go(g)
			continue
		if not g.site.box.has_point(flat): continue
		for sp: Spur in g.spurs:
			if sp.out > 0.0 and Vector2(sp.root.x,sp.root.z).distance_to(flat) < NEAR_M+sp.long: _near.append(sp)

## Where its body stands, `out` of the way out.
func _pose(sp: Spur) -> void:
	sp.body.transform = Transform3D(sp.basis,sp.root+sp.axis*(sp.long*(sp.out-1.0)-TUCK*(1.0-sp.out)))

## Spur `sp` placed on the rock at its spot, against the gap: it stays in the rock till it fires.
func _lay(g: Group, sp: Spur) -> void:
	if sp.laid: return
	sp.laid = true
	var t := g.site
	var ring := BoreLine.ring(t,g.grain,sp.s)
	var metres := BoreLine.round_m(ring)
	var root := BoreLine.on_ring(ring,metres,fposmod(BoreLine.angle_at(t,sp.s)/TAU,1.0)*metres[metres.size()-1])
	var tg: Vector2 = Tunnels.at_s(t,sp.s)[1]
	var along := Vector3(tg.x,0.0,tg.y)
	var way := (BoreLine.middle(t,sp.s)-root).slide(along).normalized().rotated(along,sp.tilt)
	var across := BoreLine.across(ring,root,way,along)
	var long := minf(minf(lerpf(REACH_SHARE.x,REACH_SHARE.y,sp.share)*across,REACH_MOST),across-WorldScale.opening(TOY_PAST))
	var axis := way.rotated(way.cross(along).normalized(),sp.lean)
	var tip := root+axis*long
	if long < REACH_LEAST or Tunnels.shaft_at(t,root.x,root.z,-SHAFT_ROOM) >= 0 or Tunnels.shaft_at(t,tip.x,tip.z,-SHAFT_ROOM) >= 0:
		stats.dropped = int(stats.dropped)+1
		return
	sp.root = root
	sp.axis = axis
	sp.long = long
	sp.left = across-long
	sp.girth = long*lerpf(GIRTH_SHARE.x,GIRTH_SHARE.y,sp.thick)
	sp.basis = Basis(Quaternion(Vector3.UP,axis))*Basis(Vector3.UP,sp.roll)
	sp.chain.resize(CHAIN)
	sp.radii.resize(CHAIN)
	for i in CHAIN:
		var q := float(i)/(CHAIN-1)
		sp.chain[i] = axis*(q*long)
		sp.radii[i] = sp.girth*_radius(q)
	sp.bound_at = root+axis*(long*0.5)
	sp.bound = long*0.5+sp.girth
	sp.body = _take()
	var rock: MeshInstance3D = sp.body.get_child(0)
	rock.mesh = _meshes[sp.shape]
	rock.scale = Vector3(sp.girth,long,sp.girth)
	var cs: CollisionShape3D = sp.body.get_child(1)
	var hull := PackedVector3Array(_hulls[sp.shape])
	for i in hull.size(): hull[i] *= Vector3(sp.girth,long,sp.girth)
	(cs.shape as ConvexPolygonShape3D).points = hull
	_pose(sp)
	_tell.lay(g.site,g.grain,sp)

## The spur's radius `q` of the way up, a share of its root's.
static func _radius(q: float) -> float:
	for i in range(1,RING_Y.size()):
		if q <= RING_Y[i]: return lerpf(RING_R[i-1],RING_R[i],(q-RING_Y[i-1])/(RING_Y[i]-RING_Y[i-1]))
	return RING_R[RING_R.size()-1]

## A body from the pool: hidden and out of the world's way.
func _take() -> StaticBody3D:
	if not _spare.is_empty(): return _spare.pop_back()
	var body := StaticBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 0
	body.visible = false
	var rock := MeshInstance3D.new()
	rock.name = "Rock"
	rock.material_override = _mat
	rock.layers = LandTunnels.UNDER_LAYER
	rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(rock)
	var cs := CollisionShape3D.new()
	cs.shape = ConvexPolygonShape3D.new()
	body.add_child(cs)
	add_child(body)
	return body

## Tunnel `g` is gone, and its spurs with it.
func _let_go(g: Group) -> void:
	for sp: Spur in g.spurs:
		if sp.body == null: continue
		_tell.drop(sp)
		sp.body.visible = false
		sp.body.collision_layer = 0
		_spare.append(sp.body)
		sp.body = null
		_moving.erase(sp)
	_groups.erase(g.site.name)

## One rock of the pool: rings up the unit spur, flat faces.
func _make_shape(rng: RandomNumberGenerator) -> void:
	var rings: Array[PackedVector3Array] = []
	var hull := PackedVector3Array()
	var bend := Vector2(rng.randf_range(-BEND,BEND),rng.randf_range(-BEND,BEND))
	for r in RING_Y.size():
		var y: float = RING_Y[r]
		var at := bend*maxf(y,0.0)*maxf(y,0.0)
		var ring := PackedVector3Array()
		var turn := rng.randf_range(-TWIST,TWIST)
		for k in SIDES:
			var a := TAU*(k+rng.randf_range(-0.2,0.2))/SIDES+turn
			var w := float(RING_R[r])*(1.0+rng.randf_range(-JAG,JAG))
			ring.append(Vector3(at.x+cos(a)*w,y,at.y+sin(a)*w))
		rings.append(ring)
		if y >= 0.0: hull.append_array(ring)
	var tip := Vector3(bend.x,1.06,bend.y)
	hull.append(tip)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var tri := func(a: Vector3, b: Vector3, c: Vector3) -> void:
		var n := (b-a).cross(c-a).normalized()
		verts.append_array(PackedVector3Array([a,b,c]))
		normals.append_array(PackedVector3Array([n,n,n]))
	for r in rings.size()-1:
		var lo := rings[r]
		var hi := rings[r+1]
		for k in SIDES:
			var k1 := (k+1)%SIDES
			tri.call(lo[k],hi[k],lo[k1])
			tri.call(lo[k1],hi[k],hi[k1])
	var top := rings[rings.size()-1]
	for k in SIDES: tri.call(top[k],tip,top[(k+1)%SIDES])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_meshes.append(mesh)
	_hulls.append(hull)

## What of the spurs near the plane stands at (x, z), `p` the place asked, each `grow` m
## wider, added to `list` (world y, low to high, as LandHalls `stretches`).
func stretches(p: Vector3, grow: float, list: Array) -> void:
	if _near.is_empty(): return
	var flat := Vector2(p.x,p.z)
	var added := false
	for sp: Spur in _near:
		var reach := sp.bound+grow
		if Vector2(sp.bound_at.x,sp.bound_at.z).distance_squared_to(flat) > reach*reach: continue
		var from := sp.root+sp.axis*(sp.long*(sp.out-1.0))
		var lo := INF
		var hi := -INF
		for i in CHAIN:
			var c := from+sp.chain[i]
			var r := sp.radii[i]+grow
			var d2 := Vector2(c.x,c.z).distance_squared_to(flat)
			if d2 >= r*r: continue
			var h := sqrt(r*r-d2)
			lo = minf(lo,c.y-h)
			hi = maxf(hi,c.y+h)
		if lo < hi:
			list.append(Vector2(lo,hi))
			added = true
	if added: list.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)

## True inside a spur near the plane.
func inside(p: Vector3) -> bool:
	for sp: Spur in _near:
		if sp.bound_at.distance_squared_to(p) > sp.bound*sp.bound: continue
		var from := sp.root+sp.axis*(sp.long*(sp.out-1.0))
		for i in CHAIN:
			if (from+sp.chain[i]).distance_squared_to(p) < sp.radii[i]*sp.radii[i]: return true
	return false

## The way out of the spur `p` touches, grown by `grow` and FACE_ROOM (the plane's reach
## off its middle), or ZERO: off its axis, as FlightContact's walls and towers have theirs.
func face(p: Vector3, grow: float) -> Vector3:
	var best := INF
	var out := Vector3.ZERO
	for sp: Spur in _near:
		var from := sp.root+sp.axis*(sp.long*(sp.out-1.0))
		for i in CHAIN:
			var c := from+sp.chain[i]
			var d := c.distance_to(p)-sp.radii[i]-grow-FACE_ROOM
			if d < 0.0 and d < best:
				best = d
				out = (p-c).normalized()
	return out

## Whether `body` is a spur's.
func holds(body: Object) -> bool:
	return body is StaticBody3D and (body as Node).get_parent() == self

## The spurs of the tunnel called `tunnel` (for drivers).
func of(tunnel: String) -> Array:
	var g: Group = _groups.get(tunnel)
	return [] if g == null else g.spurs
