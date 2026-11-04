extends Node3D
## The plugs the burrower brings down behind him in a sunk tunnel (docs/design/endless-flight/
## spec-chase-smash.md): a wall of rubble across the whole bore with one hole in it. The
## layout is fixed per tunnel, drawn from its seed (`plan`): where along, and where the hole
## sits round the section and how far off the middle. He brings each down as he passes,
## whichever way he runs: the tell (a rumble, grit and dust falling over the tube, a crack
## glowing round it: the collar), HOLD_S later the rubble drops from the crown, DROP_S on
## it lands with a thump and seals the bore but for the hole. Each stays down for as long as
## its tunnel stays built. Nothing goes in the save.
##
## The hole is at least WorldScale.opening(TOY_PLUG_HOLE) across, off the middle at a seeded
## angle, so threading it is a line. The plug is stone: outside the hole it's a crash, as
## the bore is (`stretches`, `inside`, `face` through LandTunnels `ground`, `inside`,
## `sight` and FlightContact). Through the hole is a thread (`crossed`, NearMiss). A surge
## (scripts/endless/surge_smash.gd) smashes the whole plug, hole and all (`struck`, `smash`):
## it bursts into the spurs' rubble and stays gone while its tunnel is built.
##
## A plug is a pooled body (its mesh rebuilt once, when it's laid, on the bore's real ring;
## its collision the same triangles). The bore's own mesh and collision are never touched.
## Plugs keep off the mouths (PLUG_ENDS), the halls and shafts, and every spur (PLUG_ROOM:
## a corkscrew's spurs are closer than twice that, so none lands inside one).

const Tunnels = preload("res://scripts/endless/tunnel_sites.gd")
const LandTunnels = preload("res://scripts/endless/land_tunnels.gd")
const BoreLine = preload("res://scripts/endless/bore_line.gd")
const BoreSpurs = preload("res://scripts/endless/bore_spurs.gd")
const BoreTell = preload("res://scripts/endless/bore_tell.gd")
const BoreRubble = preload("res://scripts/endless/bore_rubble.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const PLUG_SHADER = preload("res://shaders/burrower_bore_plug.gdshader")

## The hole, toy width (WorldScale `opening`: its least width across).
const TOY_PLUG_HOLE := 6.0
## How many a tunnel gets (the most; fewer if there's no room), none this close to either
## mouth (m), none this close to a spur (m), none this close to another plug (m), none
## this close to a hall's ends or a shaft's edge (m).
const PLUG_COUNT := 2
const PLUG_ENDS := 170.0
const PLUG_ROOM := 60.0
const PLUG_APART := 600.0
const HALL_ROOM := 30.0
const SHAFT_ROOM := 12.0
## Where the hole sits: round the section (a share of a turn off the floor's middle, as
## BoreLine's angle; never straight down), how far out from the middle (a share of the
## most it can go and keep HOLE_RIM m of rubble between it and the bore's rock, and never
## more than HOLE_OFF_MOST m: in a cavern a hole up by the crown is a climb, not a line).
const HOLE_TURN := Vector2(0.14,0.86)
const HOLE_OFF := Vector2(0.45,0.9)
const HOLE_OFF_MOST := 8.0
const HOLE_RIM := 2.5
## The wall: its thickness along the path (m) at the hole's lip and the most it bulges
## to, how far its edge runs on into the rock (m), and its mesh: points round the hole and
## rings out from it.
const LIP := 3.0
const BULGE := 6.5
const PUSH := 1.5
const AROUND := 30
const RINGS := 5
## How much the rubble's points stray (m, along and across).
const JAG_ALONG := 1.1
const JAG_ACROSS := 0.6
## The collar, the crack round the bore where it comes down: how far past the plug's
## faces it runs (m), its rows along, how far off the rock (m).
const COLLAR := 2.5
const COLLAR_ROWS := 4
const COLLAR_OFF := 0.12
## The tell's hold from him passing (s), the drop (s), how high over the crown the rubble
## waits (m), the grit's patches (how many round the crown, their share of a turn apart,
## their radius and height, m).
const HOLD_S := 1.1
const DROP_S := 0.42
const WAIT_OVER := 1.5
const SHOWERS := 2
const SHOWER_TURN := 0.09
const SHOWER_WIDE := 9.0
const SHOWER_TALL := 4.0
## The sounds (scripts/endless/flight_sound.gd): the grind, pitched down, when he
## passes (`bore_tell`), a burst, lower and quieter than a spur's, when it lands
## (`bore_burst`).
const RUMBLE_GAIN := 1.2
const RUMBLE_PITCH := 0.7
const LAND_GAIN := 0.7
const LAND_PITCH := 0.8
## The rubble thrown as it lands: girth of the stick across the crown (a share of the
## bore's width), and how hard it's thrown down (m/s).
const LAND_GIRTH := 0.3
const LAND_THROW := 9.0
## Laid out this far ahead of him (m), counted near the plane this far (m), and a thread
## counts this far past the hole's edge (m: the plane's middle grazing its lip).
const LAY_AHEAD := 200.0
const NEAR_M := 60.0
const THREAD_SLACK := 0.5
## A smash's two bursts: one round the plane's line (its girth, m), and the wall's across
## the bore (its girth a share of the wall's reach), its stone as big as a burst SMASH_LUMP m
## round would throw, so a cavern's plug doesn't burst into boulders; the near one's stone
## and dust NEAR_LUMP of its girth's (it's carried with the plane, and the eye flies in it).
const SMASH_NEAR := 8.0
const NEAR_LUMP := 0.7
const SMASH_GIRTH := 0.75
const SMASH_LUMP := 8.0

## One plug: its place in the layout, then, once laid (`_lay`), where it stands.
class Plug:
	var s := 0.0
	var turn := 0.0
	var off := 0.0
	var seed := 0
	var laid := false
	var fired := false
	var clock := 0.0
	## How far down it's come (0..1): solid at 1.
	var down := 0.0
	var solid := false
	## Smashed by a surge (task 3b): gone for as long as its tunnel stays built.
	var broken := false
	## The frame at the bore's middle: along the path (flat), across it (+d), up.
	var mid := Vector3.ZERO
	var along := Vector3.FORWARD
	var side := Vector3.RIGHT
	## The hole: its middle (world), its radius (m). The wall: half its thickness at the
	## most (m), how far from the middle its edge reaches at the most (m), its top (world y).
	var hole := Vector3.ZERO
	var r := 0.0
	var half := 0.0
	var reach := 0.0
	var top := 0.0
	## Its section's outline round the hole: the rock's distance from the hole's middle
	## per point round (m, PUSH in), and the wall's half thickness per ring per point.
	var outer := PackedFloat32Array()
	var thick := PackedFloat32Array()
	var body: StaticBody3D

## One tunnel he has run.
class Group:
	var site: Tunnels.Site
	var grain: FastNoiseLite
	var plugs: Array[Plug] = []

var _tunnels: Node3D
var _groups := {}
var _run: Group
var _way := 1.0
var _near: Array[Plug] = []
var _moving: Array[Plug] = []
var _spare: Array[StaticBody3D] = []
var _mat: ShaderMaterial
var _tell: BoreTell
var _rubble: BoreRubble
var _sound: Node
var _now := 0.0
## For drivers: the worst frame's work (us), plugs laid, fired, landed.
var stats := {"worst_us": 0, "laid": 0, "fired": 0, "landed": 0, "smashed": 0}

func _init() -> void:
	name = "BorePlugs"

## `tell`, `rubble`: the spurs' (BoreSpurs), shared.
func setup(tunnels: Node3D, tell: BoreTell, rubble: BoreRubble) -> void:
	_tunnels = tunnels
	_tell = tell
	_rubble = rubble
	_mat = ShaderMaterial.new()
	_mat.shader = PLUG_SHADER
	_mat.set_shader_parameter("hold",HOLD_S)
	_mat.set_shader_parameter("drop",DROP_S)
	if tunnels != null: tunnels.plugs = self

## The plugs of `t` in order along the path, before any is placed: a plain function of its
## seed (and of the spurs' `plan`, itself one). Each plug draws all its numbers first.
static func plan(t: Tunnels.Site) -> Array[Plug]:
	var out: Array[Plug] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([t.seed,"bore plugs"])
	var draws: Array[Plug] = []
	var picks := PackedFloat32Array()
	for k in PLUG_COUNT:
		var pl := Plug.new()
		picks.append(rng.randf())
		pl.turn = lerpf(HOLE_TURN.x,HOLE_TURN.y,rng.randf())
		pl.off = rng.randf()
		pl.seed = rng.randi()
		draws.append(pl)
	var spur_s := PackedFloat32Array()
	for sp: BoreSpurs.Spur in BoreSpurs.plan(t): spur_s.append(sp.s)
	# Every place it could go, every 5 m.
	var room := PackedFloat32Array()
	var at := PLUG_ENDS
	while at <= t.length-PLUG_ENDS:
		if _clear(t,at,spur_s): room.append(at)
		at += 5.0
	for k in PLUG_COUNT:
		if room.is_empty(): break
		var pl := draws[k]
		pl.s = room[mini(int(picks[k]*room.size()),room.size()-1)]
		out.append(pl)
		var left := PackedFloat32Array()
		for a: float in room:
			if absf(a-pl.s) >= PLUG_APART: left.append(a)
		room = left
	out.sort_custom(func(a: Plug, b: Plug) -> bool: return a.s < b.s)
	return out

## Whether a plug can stand at distance `at` along `t`.
static func _clear(t: Tunnels.Site, at: float, spur_s: PackedFloat32Array) -> bool:
	for s: float in spur_s:
		if absf(s-at) < PLUG_ROOM: return false
	for piece: Dictionary in t.pieces:
		if piece.kind == "hall" and at >= float(piece.s0)-HALL_ROOM and at <= float(piece.s1)+HALL_ROOM: return false
	var c: Vector2 = Tunnels.at_s(t,at)[0]
	var w := Tunnels.section(t,at).x
	return Tunnels.shaft_at(t,c.x,c.y,-(w+SHAFT_ROOM)) < 0

## He's in `t`, going `way`.
func begin(t: Tunnels.Site, way: float) -> void:
	var g: Group = _groups.get(t.name)
	if g == null:
		g = Group.new()
		g.site = t
		g.grain = LandTunnels.rock_grain(t)
		g.plugs = plan(t)
		_groups[t.name] = g
	_run = g
	_way = way

## The chase is over: nothing more comes down, what's on its way still does.
func ended() -> void:
	_run = null

## He's at distance `at`: plugs ahead laid, those he's passed brought down.
func passing(at: float) -> void:
	if _run == null: return
	var began := Time.get_ticks_usec()
	for pl: Plug in _run.plugs:
		var ahead := (pl.s-at)*_way
		if not pl.laid and ahead < LAY_AHEAD:
			_lay(_run,pl)
			break
		if ahead <= 0.0 and pl.body != null and not pl.fired and not pl.broken: _fire(_run,pl)
	stats.worst_us = maxi(int(stats.worst_us),Time.get_ticks_usec()-began)

## The tell: the rumble, the collar's crack, grit off the crown.
func _fire(g: Group, pl: Plug) -> void:
	pl.fired = true
	pl.clock = 0.0
	_moving.append(pl)
	pl.body.visible = true
	(pl.body.get_child(0) as MeshInstance3D).set_instance_shader_parameter("lit_at",_now)
	stats.fired = int(stats.fired)+1
	if _sound != null: _sound.bore_tell(pl.mid,RUMBLE_GAIN,RUMBLE_PITCH)
	var crown := PI
	for k in SHOWERS:
		var a := crown+TAU*SHOWER_TURN*(float(k)-(SHOWERS-1)*0.5)*2.0
		var dir := pl.side*sin(a)+Vector3.UP*(-cos(a))
		var rock := pl.mid+dir*BoreLine.across(BoreLine.ring(g.site,g.grain,pl.s),pl.mid,dir,pl.along)
		_tell.shower(rock,(pl.mid-rock).normalized(),SHOWER_WIDE,SHOWER_TALL,maxf(HOLD_S-0.8,0.0))

## One frame, `at` the plane.
func step(delta: float, at: Vector3, sound: Node) -> void:
	_now += delta
	_sound = sound
	if _groups.is_empty(): return
	_mat.set_shader_parameter("now",_now)
	for i in range(_moving.size()-1,-1,-1):
		var pl := _moving[i]
		pl.clock += delta
		pl.down = clampf((pl.clock-HOLD_S)/DROP_S,0.0,1.0)
		if pl.down < 1.0: continue
		# It lands: solid, unless the plane is in its slab (it waits a frame).
		if _in_slab(pl,at,WorldScale.span*0.5): continue
		pl.solid = true
		pl.body.collision_layer = LandTunnels.LAYER
		_moving.remove_at(i)
		stats.landed = int(stats.landed)+1
		sound.bore_burst(pl.mid,LAND_GAIN,LAND_PITCH)
		var wide := pl.reach*1.4
		_rubble.burst(pl.mid+Vector3.UP*(pl.top-pl.mid.y-WAIT_OVER-1.0)-pl.side*wide*0.5,pl.side*wide,wide*LAND_GIRTH*0.5,Vector3.DOWN*LAND_THROW)
	var was := _near.duplicate()
	_near.clear()
	var flat := Vector2(at.x,at.z)
	for tunnel: String in _groups.keys():
		var g: Group = _groups[tunnel]
		if g != _run and _tunnels != null and not _tunnels.has_built(tunnel):
			_let_go(g)
			continue
		if not g.site.box.has_point(flat): continue
		for pl: Plug in g.plugs:
			if pl.solid and Vector2(pl.mid.x,pl.mid.z).distance_to(flat) < NEAR_M+pl.reach: _near.append(pl)
	if _near != was: _solid_moved()

## The near plugs changed: LandTunnels' native sight reads them again.
func _solid_moved() -> void:
	if _tunnels != null and _tunnels.has_method(&"solid_moved"): _tunnels.solid_moved()

## AROUND, RINGS and LIP, for `sight_pack`'s reader.
func sight_shape() -> Array:
	return [AROUND,RINGS,LIP]

## The near plugs as `inside` reads them, for LandTunnels' native sight
## (ZenScapeBoreSight `set_plugs`, with AROUND, RINGS and LIP): per plug
## its mid, along, side, hole, r, half, outer (AROUND) and thick
## (RINGS*AROUND).
func sight_pack() -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for pl: Plug in _near:
		out.append_array([pl.mid.x,pl.mid.y,pl.mid.z,pl.along.x,pl.along.y,pl.along.z,pl.side.x,pl.side.y,pl.side.z,
			pl.hole.x,pl.hole.y,pl.hole.z,pl.r,pl.half])
		var outer := pl.outer.duplicate()
		outer.resize(AROUND)
		var thick := pl.thick.duplicate()
		thick.resize(RINGS*AROUND)
		out.append_array(PackedFloat64Array(Array(outer)))
		out.append_array(PackedFloat64Array(Array(thick)))
	return out

## Plug `pl` placed at its spot on the bore's real ring: hidden, up in the crown, till he passes.
func _lay(g: Group, pl: Plug) -> void:
	if pl.laid: return
	pl.laid = true
	var t := g.site
	var ring := BoreLine.ring(t,g.grain,pl.s)
	var tg: Vector2 = Tunnels.at_s(t,pl.s)[1]
	pl.along = Vector3(tg.x,0.0,tg.y)
	pl.side = Vector3(-tg.y,0.0,tg.x)
	pl.mid = BoreLine.middle(t,pl.s)
	pl.r = WorldScale.opening(TOY_PLUG_HOLE)*0.5
	# The hole: off the middle at its angle, keeping HOLE_RIM of rubble to the rock.
	var a := pl.turn*TAU
	var dir := pl.side*sin(a)+Vector3.UP*(-cos(a))
	var room := BoreLine.across(ring,pl.mid,dir,pl.along)-pl.r-HOLE_RIM
	pl.hole = pl.mid+dir*minf(maxf(room,0.0),HOLE_OFF_MOST/HOLE_OFF.y)*lerpf(HOLE_OFF.x,HOLE_OFF.y,pl.off)
	var rng := RandomNumberGenerator.new()
	rng.seed = pl.seed
	pl.outer.resize(AROUND)
	pl.reach = 0.0
	pl.top = -INF
	for k in AROUND:
		var e := _round(pl,k)
		pl.outer[k] = BoreLine.across(ring,pl.hole,e,pl.along)+PUSH
		var tip := pl.hole+e*pl.outer[k]
		pl.reach = maxf(pl.reach,tip.distance_to(pl.mid))
		pl.top = maxf(pl.top,tip.y)
	pl.top += WAIT_OVER
	# The wall's thickness: thin at the lip, bulging out, each point strayed.
	pl.thick.resize(AROUND*RINGS)
	pl.half = 0.0
	for j in RINGS:
		var q := float(j)/(RINGS-1)
		for k in AROUND:
			var h := lerpf(LIP,BULGE,sin(q*PI*0.5))*0.5+rng.randf_range(-JAG_ALONG,JAG_ALONG)*q
			pl.thick[j*AROUND+k] = maxf(h,LIP*0.5)
			pl.half = maxf(pl.half,pl.thick[j*AROUND+k])
	pl.body = _take()
	pl.body.position = pl.mid
	_build(g,pl,rng)
	stats.laid = int(stats.laid)+1

## The way out from the hole's middle to point `k` round it.
static func _round(pl: Plug, k: int) -> Vector3:
	var a := TAU*float(k)/AROUND
	return pl.side*cos(a)+Vector3.UP*sin(a)

## The wall's point `k` round, ring `j` out, on its face `face` (-1 back along the path,
## 1 on along it), from the body's origin, strayed `jag` m out (the inner rings only).
func _point(pl: Plug, j: int, k: int, face: float, jag: float) -> Vector3:
	var q := float(j)/(RINGS-1)
	var d := lerpf(pl.r,pl.outer[k],q*q*0.35+q*0.65)
	if j > 0 and j < RINGS-1: d += jag
	return pl.hole+_round(pl,k)*d+pl.along*(pl.thick[j*AROUND+k]*face)-pl.mid

## The plug's mesh and collision: both faces, the hole's wall, and the collar.
func _build(g: Group, pl: Plug, rng: RandomNumberGenerator) -> void:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var tri := func(a: Vector3, b: Vector3, c: Vector3, collar: float) -> void:
		verts.append_array(PackedVector3Array([a,b,c]))
		var col := Color(collar,0.0,0.0)
		colors.append_array(PackedColorArray([col,col,col]))
	var jags := PackedFloat32Array()
	for i in AROUND*RINGS: jags.append(rng.randf_range(-JAG_ACROSS,JAG_ACROSS))
	var faces := PackedVector3Array()
	for face: float in [-1.0,1.0]:
		var pts := PackedVector3Array()
		for j in RINGS:
			for k in AROUND: pts.append(_point(pl,j,k,face,jags[j*AROUND+k]))
		for j in RINGS-1:
			for k in AROUND:
				var k1 := (k+1)%AROUND
				var a := pts[j*AROUND+k]
				var b := pts[j*AROUND+k1]
				var c := pts[(j+1)*AROUND+k]
				var d := pts[(j+1)*AROUND+k1]
				tri.call(a,c,b,0.0)
				tri.call(b,c,d,0.0)
		# The hole's wall, lip to lip.
		if face > 0.0:
			for k in AROUND:
				var k1 := (k+1)%AROUND
				var a := _point(pl,0,k,-1.0,0.0)
				var b := _point(pl,0,k1,-1.0,0.0)
				var c := _point(pl,0,k,1.0,0.0)
				var d := _point(pl,0,k1,1.0,0.0)
				tri.call(a,b,c,0.0)
				tri.call(b,d,c,0.0)
	faces = verts.duplicate()
	# The collar: a band on the rock round the bore, both sides of the plug.
	var t := g.site
	var rows: Array[PackedVector3Array] = []
	for r in COLLAR_ROWS:
		var at := clampf(pl.s+lerpf(-pl.half-COLLAR,pl.half+COLLAR,float(r)/(COLLAR_ROWS-1)),0.0,t.length)
		var ring := BoreLine.ring(t,g.grain,at)
		var mid := BoreLine.middle(t,at)
		var row := PackedVector3Array()
		for v: Vector3 in ring: row.append(v+(mid-v).normalized()*COLLAR_OFF-pl.mid)
		rows.append(row)
	for r in COLLAR_ROWS-1:
		var lo := rows[r]
		var hi := rows[r+1]
		for i in lo.size()-1:
			tri.call(lo[i],hi[i],lo[i+1],1.0)
			tri.call(lo[i+1],hi[i],hi[i+1],1.0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	var rock: MeshInstance3D = pl.body.get_child(0)
	var mesh: ArrayMesh = rock.mesh
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var box := AABB(verts[0],Vector3.ZERO)
	for v: Vector3 in verts: box = box.expand(v)
	mesh.custom_aabb = box.grow(1.0)
	rock.set_instance_shader_parameter("top",pl.top-pl.mid.y)
	rock.set_instance_shader_parameter("lit_at",-1000.0)
	var cs: CollisionShape3D = pl.body.get_child(1)
	(cs.shape as ConcavePolygonShape3D).set_faces(faces)

## A body from the pool: hidden and out of the world's way.
func _take() -> StaticBody3D:
	if not _spare.is_empty(): return _spare.pop_back()
	var body := StaticBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 0
	body.visible = false
	var rock := MeshInstance3D.new()
	rock.name = "Rock"
	rock.mesh = ArrayMesh.new()
	rock.material_override = _mat
	rock.layers = LandTunnels.UNDER_LAYER
	rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(rock)
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	return body

## Tunnel `g` is gone, and its plugs with it.
func _let_go(g: Group) -> void:
	_solid_moved()
	for pl: Plug in g.plugs:
		_near.erase(pl)
		_moving.erase(pl)
		if pl.body == null: continue
		pl.body.visible = false
		pl.body.collision_layer = 0
		_spare.append(pl.body)
		pl.body = null
	_groups.erase(g.site.name)

## Point `p` in plug `pl`'s frame: along the path from its middle, and the section's
## distance from the hole's middle.
static func _local(pl: Plug, p: Vector3) -> Vector2:
	var d := p-pl.mid
	var a := d.dot(pl.along)
	var h := pl.hole-pl.mid
	var x := d.dot(pl.side)-h.dot(pl.side)
	var y := d.y-h.y
	return Vector2(a,Vector2(x,y).length())

## The wall's half thickness at section distance `rho` from the hole's middle, its point
## `k` round (the least of the rings either side, so the solid sits inside the mesh).
func _half_at(pl: Plug, rho: float, k: int) -> float:
	if rho <= pl.r: return 0.0
	var q := clampf((rho-pl.r)/maxf(pl.outer[k]-pl.r,0.01),0.0,1.0)
	var j := mini(int(q*(RINGS-1)),RINGS-2)
	return minf(pl.thick[j*AROUND+k],pl.thick[(j+1)*AROUND+k])

## The point round the hole nearest the way to `p`.
static func _k_of(pl: Plug, p: Vector3) -> int:
	var d := p-pl.hole
	var a := atan2(d.y,d.dot(pl.side))
	return posmod(roundi(a/TAU*AROUND),AROUND)

## Whether `p` is in plug `pl`'s slab (its thickest), `grow` m wider, outside the hole.
func _in_slab(pl: Plug, p: Vector3, grow: float) -> bool:
	var l := _local(pl,p)
	return absf(l.x) < pl.half+grow and l.y > pl.r-grow and l.y < pl.outer[_k_of(pl,p)]

## The wall's half thickness where `p` is (by its place round the hole and out from it;
## the lip's in the hole), or -1 past the wall's edge in the rock.
func _thick_at(pl: Plug, p: Vector3) -> float:
	var k := _k_of(pl,p)
	var rho := _local(pl,p).y
	if rho > pl.outer[k]: return -1.0
	return maxf(_half_at(pl,rho,k),LIP*0.5)

## What of the plugs near the plane stands at (x, z), `p` the place asked, each `grow` m
## wider, added to `list` (world y, low to high, as LandHalls `stretches`). The wall is as
## thick all the way up as it is where `p` is.
func stretches(p: Vector3, grow: float, list: Array) -> void:
	if _near.is_empty(): return
	var added := false
	for pl: Plug in _near:
		var d := p-pl.mid
		if absf(d.dot(pl.side)) > pl.reach: continue
		var thick := _thick_at(pl,p)
		if thick < 0.0 or absf(d.dot(pl.along)) > thick+grow: continue
		var lo := pl.mid.y-pl.reach-1.0
		var x := d.dot(pl.side)-(pl.hole-pl.mid).dot(pl.side)
		var r := pl.r-grow
		if absf(x) < r:
			var h := sqrt(r*r-x*x)
			list.append(Vector2(lo,pl.hole.y-h))
			list.append(Vector2(pl.hole.y+h,pl.top))
		else:
			list.append(Vector2(lo,pl.top))
		added = true
	if added: list.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)

## True inside a plug near the plane.
func inside(p: Vector3) -> bool:
	for pl: Plug in _near:
		var l := _local(pl,p)
		if l.y <= pl.r or absf(l.x) > pl.half: continue
		if absf(l.x) < _thick_at(pl,p): return true
	return false

## The way out of the plug `p` touches, grown by `grow` and BoreSpurs.FACE_ROOM, or ZERO:
## toward the hole's middle on its lip, else straight off the face.
func face(p: Vector3, grow: float) -> Vector3:
	var room := grow+BoreSpurs.FACE_ROOM
	for pl: Plug in _near:
		var l := _local(pl,p)
		var thick := _thick_at(pl,p)
		if thick < 0.0: continue
		var into_face := thick+room-absf(l.x)
		var into_lip := l.y-(pl.r-room)
		if into_face <= 0.0 or into_lip <= 0.0: continue
		if into_lip < into_face:
			var to := pl.hole-p
			return (to-pl.along*to.dot(pl.along)).normalized()
		return pl.along*signf(l.x if l.x != 0.0 else 1.0)
	return Vector3.ZERO

## A plug that's down crossed between `from` and `to` through its hole: {room (m from
## the plane's middle to the hole's edge), half (the hole's radius), name}, else {}.
func crossed(from: Vector3, to: Vector3) -> Dictionary:
	for pl: Plug in _near:
		var d0 := (from-pl.mid).dot(pl.along)
		var d1 := (to-pl.mid).dot(pl.along)
		if (d0 > 0.0) == (d1 > 0.0): continue
		var at := from.lerp(to,d0/(d0-d1))
		var rho := _local(pl,at).y
		if rho > pl.r+THREAD_SLACK: continue
		return {"room":pl.r-rho,"half":pl.r,"name":"plug %.0f" % pl.s}
	return {}

## A plug that's down or coming down (not in its tell, not broken) whose slab the plane
## meets going from `p` along `way` (unit) within `look` m, `pad` m wider, or null. The
## whole wall counts, the hole too: a surge doesn't thread, it smashes.
func struck(p: Vector3, way: Vector3, look: float, pad: float) -> Plug:
	for list: Array in [_near,_moving]:
		for pl: Plug in list:
			if pl.broken or pl.body == null or (not pl.solid and pl.down <= 0.0): continue
			var a0 := (p-pl.mid).dot(pl.along)
			var a1 := a0+way.dot(pl.along)*look
			# Past its middle it's behind: a plug just threaded isn't smashed (and scored) too.
			if a0*way.dot(pl.along) > 0.0: continue
			var h := pl.half+pad
			if maxf(a0,a1) < -h or minf(a0,a1) > h: continue
			var k := 0.0 if absf(a1-a0) < 1e-4 else clampf(-a0/(a1-a0),0.0,1.0)
			var d := p+way*(look*k)-pl.mid
			if Vector2(d.dot(pl.side),d.y).length() > pl.reach+pad: continue
			return pl
	return null

## Plug `pl` smashed by the plane at `at` going `blast` (m/s): the whole wall bursts, and
## it's gone (its collar with it) for as long as its tunnel stays built.
func smash(pl: Plug, at: Vector3, blast: Vector3) -> void:
	if pl.body == null or pl.broken: return
	# Each burst's stone runs along the path through the wall, the root on the plane's side:
	# the wall's fills the section, the near one is the stone round the plane's line.
	var toward := signf(blast.dot(pl.along)) if blast.dot(pl.along) != 0.0 else 1.0
	var seg := pl.along*(2.0*pl.half*toward)
	var wide := pl.reach*SMASH_GIRTH
	_rubble.burst(pl.mid-seg*0.5,seg,wide,blast,minf(SMASH_LUMP/wide,1.0))
	var on := at-pl.along*(at-pl.mid).dot(pl.along)
	_rubble.burst(on-seg*0.5,seg,SMASH_NEAR,blast,NEAR_LUMP)
	pl.broken = true
	pl.solid = false
	pl.down = 0.0
	pl.body.visible = false
	pl.body.collision_layer = 0
	_spare.append(pl.body)
	pl.body = null
	_moving.erase(pl)
	_near.erase(pl)
	_solid_moved()
	stats.smashed = int(stats.smashed)+1

## Whether `body` is a plug's.
func holds(body: Object) -> bool:
	return body is StaticBody3D and (body as Node).get_parent() == self

## The plugs of the tunnel called `tunnel` (for drivers).
func of(tunnel: String) -> Array:
	var g: Group = _groups.get(tunnel)
	return [] if g == null else g.plugs
