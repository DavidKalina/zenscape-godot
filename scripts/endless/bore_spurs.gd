extends Node3D
## The spurs the burrower leaves in a sunk tunnel (docs/design/endless-flight/
## spec-burrower-chase.md). The layout is fixed per tunnel, drawn from its seed (`plan`):
## which spurs, how far along, how long; the angle is reckoned off his line's there
## (BoreLine), so the ridge marks each spot. He reveals them as he passes, whichever way he runs, and they
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
## A surge smashes a spur that's out (`struck`, `smash`; scripts/endless/surge_smash.gd): it
## bursts into rubble (scripts/endless/bore_rubble.gd), its body goes back to the pool and its
## crack stays on the rock, and it stays broken for as long as its tunnel stays built.
##
## The layout is spots, each one of a few patterns (`plan`): a **single** spur on the ridge; a
## **pair**, one on the ridge and one across the bore from it, out at once; a **gate**, two
## spurs side by side astride the ridge, standing parallel, his line the gap between them; a
## **corkscrew**, CORK_COUNT spurs in a run, each CORK_STEP m on and CORK_TURN of the way
## round past the last. Every spur keeps its own tell; a pair's and a gate's fire together,
## a corkscrew's ripple round the bore as he passes each.
##
## The gap: a spur stops short of the far rock by at least WorldScale.opening(TOY_PAST),
## measured against the bore's real ring at its spot (`_lay`); a spot that can't leave
## that and still stand REACH_LEAST m out has no spur. A pair's and a gate's second spur
## also stays that far off its first (a gate's, WorldScale.opening(TOY_GATE): the gate's
## gap is a way through), shortened till it does, or dropped.

const Tunnels = preload("res://scripts/endless/tunnel_sites.gd")
const LandTunnels = preload("res://scripts/endless/land_tunnels.gd")
const BoreLine = preload("res://scripts/endless/bore_line.gd")
const BoreTell = preload("res://scripts/endless/bore_tell.gd")
const BoreRubble = preload("res://scripts/endless/bore_rubble.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const SPUR_SHADER = preload("res://shaders/burrower_bore_spur.gdshader")

## None this close to either mouth (m), and how far the room after a spot wanders (a share
## of it).
const SPUR_ENDS := 130.0
const SPUR_WANDER := 0.2
## The patterns: how often a spot draws each (weights, summed), and the room after one
## before the next spot (m, from its last spur): the knobs flying tunes.
const SINGLE := "single"
const PAIR := "pair"
const GATE := "gate"
const CORKSCREW := "corkscrew"
const WEIGHT_SINGLE := 0.35
const WEIGHT_PAIR := 0.2
const WEIGHT_GATE := 0.25
const WEIGHT_CORKSCREW := 0.2
const AFTER_SINGLE := 85.0
const AFTER_PAIR := 110.0
const AFTER_GATE := 110.0
const AFTER_CORKSCREW := 130.0
## A corkscrew: how many spurs (least, most), how far apart along the path (m), and how far
## round each steps past the last (a share of a turn; which way is drawn).
const CORK_COUNT := Vector2i(3,5)
const CORK_STEP := 24.0
const CORK_TURN := 0.14
## A gate's gap, toy width (WorldScale `opening`), and how far each spur's root stands off
## its edge round the ring (m: a gate spur's girth and some, so on a curved wall the gap is
## mostly right before `_lay` trims the second spur). How far across a gate's spurs reach
## (a share; they leave TOY_PAST past their tips like any spur), and their girth (a share
## of the usual), thinner so the gap reads.
const TOY_GATE := 5.0
const GATE_ROOT := 6.0
const GATE_SHARE := Vector2(0.62,0.85)
const GATE_THIN := 0.75
## How far a pair's second spur stands round from its first (a share of a turn).
const PAIR_TURN := 0.5
## How much shorter a pattern's second spur gets each try at the gap (a share).
const TRIM := 0.92
## The way left past a spur's tip, toy width (WorldScale `opening`).
const TOY_PAST := 4.0
## How far it stands out: a share of the way across the bore from its root, and the most
## and least (m). The most is REACH_MOST, or the way to the bore's middle times
## REACH_MIDDLE if that's further, so a spur in a wide cavern still stands in the way and
## can't be ignored from the middle. Its root's radius: a share of that, and the most (m).
const REACH_SHARE := Vector2(0.42,0.72)
const REACH_MOST := 18.0
const REACH_MIDDLE := 1.0
const REACH_LEAST := 5.0
const GIRTH_SHARE := Vector2(0.17,0.25)
const GIRTH_MOST := 6.0
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
const CHAIN := 14
const FACE_ROOM := 0.8

## One spur: its place in the layout, then, once laid (`_lay`), where it stands. `laid`
## with no body: no room here, no spur.
class Spur:
	var s := 0.0
	## Its pattern, and where round the bore it stands off the ridge: a share of a turn,
	## then metres round the ring. A pair's or gate's second spur keeps its `first`.
	var kind := SINGLE
	var turn := 0.0
	var side := 0.0
	var first: Spur
	## Once laid: its root's share of the way round its ring (the tell's patch sits there).
	var round := 0.0
	var share := 0.0
	var thick := 0.0
	var tilt := 0.0
	var lean := 0.0
	var roll := 0.0
	var shape := 0
	var laid := false
	var fired := false
	## Smashed by a surge: gone for as long as its tunnel stays built.
	var broken := false
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
var _rubble: BoreRubble
## For drivers: the worst frame's work (us), spurs fired, spots dropped, spurs smashed.
var stats := {"worst_us": 0, "fired": 0, "dropped": 0, "smashed": 0}

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
	_rubble = BoreRubble.new()
	add_child(_rubble)
	_rubble.setup()
	var rng := RandomNumberGenerator.new()
	for i in SHAPES:
		rng.seed = hash(["bore spur",i])
		_make_shape(rng)
	if tunnels != null: tunnels.spurs = self

## The spurs of `t` in order along the path, before any is placed: a plain function of its
## seed. Every spot draws all its numbers, so one with no room changes no other.
static func plan(t: Tunnels.Site) -> Array[Spur]:
	var out: Array[Spur] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([t.seed,"bore spurs"])
	var s := SPUR_ENDS+AFTER_SINGLE*0.5
	var weights := [WEIGHT_SINGLE,WEIGHT_PAIR,WEIGHT_GATE,WEIGHT_CORKSCREW]
	var whole := 0.0
	for w: float in weights: whole += w
	while true:
		# The spot's numbers, all drawn whatever it turns out to be.
		var pick := rng.randf()*whole
		var wander := rng.randf_range(-SPUR_WANDER,SPUR_WANDER)
		var count := rng.randi_range(CORK_COUNT.x,CORK_COUNT.y)
		var hand := 1.0 if rng.randf() < 0.5 else -1.0
		var spurs: Array[Spur] = []
		for k in CORK_COUNT.y:
			var sp := Spur.new()
			sp.share = rng.randf()
			sp.thick = rng.randf()
			sp.tilt = rng.randf_range(-TILT,TILT)
			sp.lean = rng.randf_range(-LEAN,LEAN)
			sp.roll = rng.randf_range(0.0,TAU)
			sp.shape = rng.randi()%SHAPES
			spurs.append(sp)
		var kind := CORKSCREW
		for k in weights.size():
			if pick < weights[k]:
				kind = [SINGLE,PAIR,GATE,CORKSCREW][k]
				break
			pick -= weights[k]
		var n := {SINGLE: 1, PAIR: 2, GATE: 2, CORKSCREW: count}[kind] as int
		var span := CORK_STEP*(n-1) if kind == CORKSCREW else 0.0
		if s+span > t.length-SPUR_ENDS: break
		spurs.resize(n)
		for k in n:
			var sp := spurs[k]
			sp.kind = kind
			sp.s = s
			if kind == PAIR and k == 1:
				sp.turn = PAIR_TURN
				sp.first = spurs[0]
			elif kind == GATE:
				# Side by side astride the ridge, alike but for their rock.
				sp.side = (GATE_ROOT+WorldScale.opening(TOY_GATE)*0.5)*(1.0 if k == 0 else -1.0)
				sp.share = spurs[0].share
				sp.tilt = spurs[0].tilt
				sp.lean = spurs[0].lean
				if k == 1: sp.first = spurs[0]
			elif kind == CORKSCREW:
				sp.s = s+CORK_STEP*k
				sp.turn = CORK_TURN*k*hand
			if not _in_hall(t,sp.s): out.append(sp)
		s += span+{SINGLE: AFTER_SINGLE, PAIR: AFTER_PAIR, GATE: AFTER_GATE, CORKSCREW: AFTER_CORKSCREW}[kind]*(1.0+wander)
	return out

## Whether distance `at` along `t` is in a hall.
static func _in_hall(t: Tunnels.Site, at: float) -> bool:
	for piece: Dictionary in t.pieces:
		if piece.kind == "hall" and at >= float(piece.s0) and at <= float(piece.s1): return true
	return false

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
	_rubble.step(delta)
	if _groups.is_empty(): return
	_tell.step(delta)
	_mat.set_shader_parameter("now",_tell.now)
	var moved := not _moving.is_empty()
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
	var was := _near.duplicate()
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
	if moved or _near != was: _solid_moved()

## The near spurs changed or moved: LandTunnels' native sight reads them again.
func _solid_moved() -> void:
	if _tunnels != null and _tunnels.has_method(&"solid_moved"): _tunnels.solid_moved()

## The spheres a spur's solid is (`sight_pack`'s stride).
func sight_chain() -> int:
	return CHAIN

## The near spurs as `inside` reads them, for LandTunnels' native sight
## (ZenScapeBoreSight `set_spurs`): per spur its bound (x, y, z, r), then
## each of its CHAIN spheres (x, y, z, r), worked out as `inside` does.
func sight_pack() -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for sp: Spur in _near:
		out.append_array([sp.bound_at.x,sp.bound_at.y,sp.bound_at.z,sp.bound])
		var from := sp.root+sp.axis*(sp.long*(sp.out-1.0))
		for i in CHAIN:
			var c := from+sp.chain[i]
			out.append_array([c.x,c.y,c.z,sp.radii[i]])
	return out

## Where its body stands, `out` of the way out.
func _pose(sp: Spur) -> void:
	sp.body.transform = Transform3D(sp.basis,sp.root+sp.axis*(sp.long*(sp.out-1.0)-TUCK*(1.0-sp.out)))

## Spur `sp` placed on the rock at its spot, against the gap: it stays in the rock till it fires.
func _lay(g: Group, sp: Spur) -> void:
	if sp.laid: return
	sp.laid = true
	# A pattern's second spur fits round its first, so the first stands first.
	if sp.first != null: _lay(g,sp.first)
	var t := g.site
	var ring := BoreLine.ring(t,g.grain,sp.s)
	var metres := BoreLine.round_m(ring)
	var whole := metres[metres.size()-1]
	var on := (fposmod(BoreLine.angle_at(t,sp.s)/TAU,1.0)+sp.turn)*whole
	var u := fposmod(on+sp.side,whole)
	var root := BoreLine.on_ring(ring,metres,u)
	var tg: Vector2 = Tunnels.at_s(t,sp.s)[1]
	var along := Vector3(tg.x,0.0,tg.y)
	var mid := BoreLine.middle(t,sp.s)
	# A gate's two aim as the ridge between them does, so they stand parallel.
	var aim := BoreLine.on_ring(ring,metres,on) if sp.kind == GATE else root
	var way := (mid-aim).slide(along).normalized().rotated(along,sp.tilt)
	var across := BoreLine.across(ring,root,way,along)
	var long := 0.0
	if sp.kind == GATE:
		long = lerpf(GATE_SHARE.x,GATE_SHARE.y,sp.share)*across
	else:
		var most := maxf(REACH_MOST,(mid-root).dot(way)*REACH_MIDDLE)
		long = minf(lerpf(REACH_SHARE.x,REACH_SHARE.y,sp.share)*across,most)
	long = minf(long,across-WorldScale.opening(TOY_PAST))
	sp.root = root
	sp.axis = way.rotated(way.cross(along).normalized(),sp.lean)
	sp.round = u/whole
	_size(sp,long)
	if sp.first != null and sp.first.body != null:
		var need := WorldScale.opening(TOY_GATE if sp.kind == GATE else TOY_PAST)
		while sp.long >= REACH_LEAST and _apart(sp,sp.first) < need: _size(sp,sp.long*TRIM)
	var tip := root+sp.axis*sp.long
	if sp.long < REACH_LEAST or Tunnels.shaft_at(t,root.x,root.z,-SHAFT_ROOM) >= 0 or Tunnels.shaft_at(t,tip.x,tip.z,-SHAFT_ROOM) >= 0:
		stats.dropped = int(stats.dropped)+1
		return
	sp.left = across-sp.long
	sp.basis = Basis(Quaternion(Vector3.UP,sp.axis))*Basis(Vector3.UP,sp.roll)
	sp.body = _take()
	var rock: MeshInstance3D = sp.body.get_child(0)
	rock.mesh = _meshes[sp.shape]
	rock.scale = Vector3(sp.girth,sp.long,sp.girth)
	var cs: CollisionShape3D = sp.body.get_child(1)
	var hull := PackedVector3Array(_hulls[sp.shape])
	for i in hull.size(): hull[i] *= Vector3(sp.girth,sp.long,sp.girth)
	(cs.shape as ConvexPolygonShape3D).points = hull
	_pose(sp)
	_tell.lay(g.site,g.grain,sp)

## Spur `sp` `long` m out from its root along its axis: its girth and its solid.
func _size(sp: Spur, long: float) -> void:
	sp.long = long
	sp.girth = minf(long*lerpf(GIRTH_SHARE.x,GIRTH_SHARE.y,sp.thick)*(GATE_THIN if sp.kind == GATE else 1.0),GIRTH_MOST)
	sp.chain.resize(CHAIN)
	sp.radii.resize(CHAIN)
	for i in CHAIN:
		var q := float(i)/(CHAIN-1)
		sp.chain[i] = sp.axis*(q*long)
		sp.radii[i] = sp.girth*_radius(q)
	sp.bound_at = sp.root+sp.axis*(long*0.5)
	sp.bound = long*0.5+sp.girth

## The least room between spurs `a` and `b`, both all the way out (m, rock to rock).
static func _apart(a: Spur, b: Spur) -> float:
	var least := INF
	for i in CHAIN:
		var p := a.root+a.chain[i]
		for j in CHAIN:
			least = minf(least,p.distance_to(b.root+b.chain[j])-a.radii[i]-b.radii[j])
	return least

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
		_tell.drop(sp)
		if sp.body == null: continue
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

## The spur near the plane that's out (snapping or snapped; one still in its tell isn't
## there) and within `pad` m of the way from `p` along `way` (unit) for `look` m, or null.
func struck(p: Vector3, way: Vector3, look: float, pad: float) -> Spur:
	for sp: Spur in _near:
		if sp.body == null or sp.out <= 0.0: continue
		var to := sp.bound_at-p
		var t := clampf(to.dot(way),0.0,look)
		if (p+way*t).distance_to(sp.bound_at) > sp.bound+pad: continue
		var from := sp.root+sp.axis*(sp.long*(sp.out-1.0))
		for i in CHAIN:
			var c := from+sp.chain[i]
			var k := clampf((c-p).dot(way),0.0,look)
			var r := sp.radii[i]+pad
			if (p+way*k).distance_squared_to(c) < r*r: return sp
	return null

## Spur `sp` smashed by the plane going `blast` (m/s): it bursts, and it's gone.
func smash(sp: Spur, blast: Vector3) -> void:
	if sp.body == null: return
	var from := sp.root+sp.axis*(sp.long*(sp.out-1.0))
	_rubble.burst(from,sp.axis*(sp.long*sp.out),sp.girth,blast)
	sp.broken = true
	sp.out = 0.0
	sp.body.visible = false
	sp.body.collision_layer = 0
	_spare.append(sp.body)
	sp.body = null
	_moving.erase(sp)
	_near.erase(sp)
	_solid_moved()
	stats.smashed = int(stats.smashed)+1

## The tell and the rubble, shared with the plugs (scripts/endless/bore_plug.gd).
func tell() -> BoreTell:
	return _tell

func rubble() -> BoreRubble:
	return _rubble

## Whether `body` is a spur's.
func holds(body: Object) -> bool:
	return body is StaticBody3D and (body as Node).get_parent() == self

## The spurs of the tunnel called `tunnel` (for drivers).
func of(tunnel: String) -> Array:
	var g: Group = _groups.get(tunnel)
	return [] if g == null else g.spurs
