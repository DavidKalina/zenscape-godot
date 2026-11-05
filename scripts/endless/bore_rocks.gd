extends Node3D
## The rocks the burrower spits back down a sunk tunnel at the plane
## (docs/design/endless-flight/spec-burrower-rocks.md). Where they meet the plane is fixed
## per tunnel, drawn from its seed (`plan`), in the stretches between the spurs and clear of
## the plugs, so a rock never lands on the same stretch as either. He spits each so it
## meets the plane about there: the tell first (his glow flares, a grind, the rock swells
## at his head, TELL_S), then it flies back down the bore along the path at SPEED, from
## his spot on the rock to where the plane was in the section when it left, so a plane
## that holds its line is hit and one that moves off it isn't.
##
## Dodged: it flies on past and bursts behind. Hit: no crash; the plane is knocked (a
## shove, the view shaken), the unbanked chain lost, as a scrape. A surge (hot) smashes it
## for nothing. Parried (scripts/endless/parry.gd, group `parry_source`): it goes home onto
## him and he staggers (burrower_bore.gd `stagger`).
##
## Each rock is a pooled lump, rock-coloured with an ember glow and a small light so it
## reads in the dark bore. Nothing goes in the save.

const Tunnels = preload("res://scripts/endless/tunnel_sites.gd")
const LandTunnels = preload("res://scripts/endless/land_tunnels.gd")
const BoreLine = preload("res://scripts/endless/bore_line.gd")
const BoreSpurs = preload("res://scripts/endless/bore_spurs.gd")
const BorePlugs = preload("res://scripts/endless/bore_plug.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

## The plan: none meets the plane this close to either mouth (m), this close to a spur (m)
## or a plug (m); a step of FIRST_M from the mouth, then APART m (a seeded share of the
## range) between them.
const ENDS := 220.0
const SPUR_ROOM := 28.0
const PLUG_ROOM := 80.0
const APART := Vector2(220.0,340.0)
## The tell (s), the rock's speed back down the bore (m/s, the world's; it closes at
## this plus the plane's), its radius (m), how far in from the rock it leaves him (a
## share of the way out from the bore's middle).
const TELL_S := 0.55
const SPEED := 38.0
const ROCK_R := 1.5
const OUT_SHARE := 0.8
## How much of the plane's drift across the bore the aim leads by (1: all of it), read
## over AIM_PROBE s.
const AIM_LEAD := 0.85
const AIM_PROBE := 0.1
## The aim stays inside this share of the bore's section.
const AIM_ROOM := 0.65
## It stops steering this long before it meets the plane (s).
const COMMIT_S := 0.5
## Past the plane this far (m) it bursts; at most LIFE_S s in the air.
const BEHIND_M := 30.0
const LIFE_S := 6.0
## A hit: speed kept, the shove (m/s), the turn (rad), the view's shake and punch.
const HIT_KEEP := 0.85
const HIT_SHOVE := 9.0
const HIT_YAW := 0.22
const HIT_FEEL := Vector2(0.035,10.0)
## The look: an ember tint and its glow, the rock's own light (range m, energy).
const ROCK_TINT := Color(0.46,0.4,0.34)
const EMBER := Color(1.0,0.42,0.16)
const EMBER_ENERGY := 2.2
## The lump's look: stone, flat facets lit by a dim fill of their own so they read in
## the dark, and an ember rim round its edge.
const LUMP_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec3 tint : source_color;
uniform vec3 ember : source_color;
uniform float glow = 2.0;
void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 1.0;
	float face = clamp(dot(NORMAL, normalize(vec3(0.3, 0.8, 0.5))) * 0.5 + 0.5, 0.0, 1.0);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = tint * (0.12 + 0.35 * face) + ember * glow * rim;
}
"""
const LIGHT_RANGE := 14.0
const LIGHT_ENERGY := 3.0

## One rock: the spot it's planned to meet the plane, then its flight.
class Rock:
	var m := 0.0
	var spat := false
	var seed := 0
	## "tell", "fly", "home" (the parry's), "gone".
	var state := "tell"
	var clock := 0.0
	## Along the path (m), its section point leaving him and aimed at (x across, y up
	## from the bore's middle), the time the aim takes.
	var rs := 0.0
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var reach_s := 1.0
	var sec_v := Vector2.ZERO
	var shot := {}

## The plan by tunnel name (meet spots), the rocks of this chase, pooled nodes.
var _plans := {}
var _rocks: Array[Rock] = []
var _pool: Array[Node3D] = []
var _mesh: ArrayMesh
var _mat: ShaderMaterial
var _site: Tunnels.Site
var _way := 1.0
var _bore: Node3D
var _game: Node3D
## For drivers.
var stats := {"spat": 0, "dodged": 0, "hit": 0, "parried": 0, "home_hit": 0, "smashed": 0, "planned": 0}

func _init() -> void:
	name = "BoreRocks"
	top_level = true

func setup(bore: Node3D) -> void:
	_bore = bore
	add_to_group(&"parry_source")
	_mesh = _lump()
	var sh := Shader.new()
	sh.code = LUMP_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("tint",ROCK_TINT)
	_mat.set_shader_parameter("ember",EMBER)
	_mat.set_shader_parameter("glow",EMBER_ENERGY)

## The meet spots of `t`, along its path: a plain function of its seed.
static func plan(t: Tunnels.Site) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([t.seed,"bore rocks"])
	var spur_s := PackedFloat32Array()
	for sp: BoreSpurs.Spur in BoreSpurs.plan(t): spur_s.append(sp.s)
	var plug_s := PackedFloat32Array()
	for pl: BorePlugs.Plug in BorePlugs.plan(t): plug_s.append(pl.s)
	var at := ENDS+rng.randf()*(APART.y-APART.x)*0.5
	while at <= t.length-ENDS:
		if _clear(at,spur_s,SPUR_ROOM) and _clear(at,plug_s,PLUG_ROOM):
			out.append(at)
			at += lerpf(APART.x,APART.y,rng.randf())
		else:
			at += 5.0
	return out

static func _clear(at: float, list: PackedFloat32Array, room: float) -> bool:
	for s: float in list:
		if absf(s-at) < room: return false
	return true

## He's in `t`, going `way`.
func begin(t: Tunnels.Site, way: float) -> void:
	_clear_rocks()
	_site = t
	_way = way
	if not _plans.has(t.name): _plans[t.name] = plan(t)
	var spots: PackedFloat32Array = _plans[t.name]
	stats.planned = spots.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([t.seed,"bore rock lumps"])
	for m: float in spots:
		var r := Rock.new()
		r.m = m
		r.seed = rng.randi()
		_rocks.append(r)
	if way < 0.0: _rocks.reverse()

## The chase is over: no more spat; those in the air fly on.
func ended() -> void:
	for r: Rock in _rocks:
		if not r.spat: r.state = "gone"
	_site = null

## One frame: `s` his distance along, `plane_s` the plane's, `along` its eased speed
## along the bore, `lead` his lead (m).
func step(delta: float, game: Node3D, s: float, plane_s: float, along: float, lead: float) -> void:
	_game = game
	for i in range(_rocks.size()-1,-1,-1):
		var r := _rocks[i]
		if r.state == "gone":
			_drop(r)
			_rocks.remove_at(i)
			continue
		if not r.spat:
			if _site == null: continue
			var to_m := (r.m-plane_s)*_way
			if to_m < 0.0 or (s-r.m)*_way < 0.0:
				# Not reached him yet, or the plane's already past it.
				if to_m < 0.0: r.state = "gone"
				continue
			var fly := maxf(along,1.0)
			var meet := fly*(TELL_S+lead/(fly+SPEED))
			if meet >= to_m: _spit(r,s,plane_s,game)
			continue
		r.clock += delta
		if r.state == "tell": _tell_step(r,delta,s,game)
		elif r.state == "fly": _fly_step(r,delta,plane_s,game)

## Rock `r` is spat: it swells at his head while the tell runs.
func _spit(r: Rock, s: float, plane_s: float, game: Node3D) -> void:
	r.spat = true
	r.state = "tell"
	r.clock = 0.0
	r.rs = s
	var node := _take()
	node.scale = Vector3.ONE*0.05
	node.visible = true
	var light := node.get_child(1) as OmniLight3D
	light.light_energy = 0.0
	r.shot = {"node":node,"at":_place(r.rs,_from_of(s)),"v":Vector3.ZERO,"parry":false,"r":ROCK_R,"done":false,"rock":r}
	node.position = r.shot.at
	stats.spat = int(stats.spat)+1
	game.sound.shot("creak",0.9,0.5,r.shot.at)
	if _bore.has_method("flare"): _bore.flare(TELL_S)

## His spot, a little in off the rock, in section points at `s`.
func _from_of(s: float) -> Vector2:
	return _sect(_site,s,BoreLine.middle(_site,s).lerp(BoreLine.about(_site,s,BoreLine.angle_at(_site,s)),OUT_SHARE))

func _tell_step(r: Rock, _delta: float, s: float, game: Node3D) -> void:
	if _site == null:
		r.state = "gone"
		return
	var k := clampf(r.clock/TELL_S,0.0,1.0)
	r.rs = s
	r.from = _from_of(s)
	var at := _place(s,r.from)
	var node: Node3D = r.shot.node
	node.position = at
	r.shot.at = at
	# Swells, with a shiver at the end.
	node.scale = Vector3.ONE*(0.15+0.85*k*k)*(1.0+0.12*sin(r.clock*70.0)*k)
	(node.get_child(1) as OmniLight3D).light_energy = LIGHT_ENERGY*k
	if k < 1.0: return
	# Off it goes (`_fly_step` aims it).
	r.sec_v = Vector2.ZERO
	r.state = "fly"
	r.clock = 0.0
	r.shot.parry = true
	r.shot.v = Vector3.ZERO
	node.scale = Vector3.ONE
	game.sound.shot("thump",1.1,0.55,at)
	game.sound.shot("crack",0.6,0.8,at)

func _fly_step(r: Rock, delta: float, plane_s: float, game: Node3D) -> void:
	if _site == null and r.clock > LIFE_S:
		_burst(r,false)
		return
	var site: Tunnels.Site = _site if _site != null else r.shot.get("site")
	if site == null:
		r.state = "gone"
		return
	r.shot["site"] = site
	var a: Vector3 = r.shot.at
	r.rs = clampf(r.rs-_way*SPEED*delta,0.0,site.length)
	# Until COMMIT_S before it meets the plane it steers across the section for where the
	# plane will be then if it holds its way across the bore; after that it holds its
	# course, so holding a line is hit and changing it late isn't.
	var p0: Vector3 = game.plane.position
	var v0: Vector3 = game.plane.velocity
	var ps := Tunnels.local(site,p0.x,p0.z).x
	r.reach_s = (r.rs-ps)*_way/(maxf(v0.length(),1.0)+SPEED)
	if r.reach_s > COMMIT_S:
		r.to = _aim(site,p0,v0,ps,r.reach_s)
		r.sec_v = (r.to-r.from)/r.reach_s
	r.from += r.sec_v*delta
	var n := _place_on(site,r.rs,r.from)
	r.shot.v = (n-a)/maxf(delta,0.0001)
	r.shot.at = n
	var node: Node3D = r.shot.node
	node.position = n
	node.basis = Basis(Vector3(0.6,0.8,0.0).normalized(),r.clock*7.0)
	# The closest pass to the plane this frame.
	var plane = game.plane
	var flying: bool = bool(plane.weighted) and bool(game.hand_landing.flying())
	if flying and not bool(r.shot.done):
		var p: Vector3 = plane.position
		var was: Vector3 = p-(plane.velocity as Vector3)*delta
		var r0 := a-was
		var r1 := n-p
		var t := clampf(-r0.dot(r1-r0)/maxf((r1-r0).length_squared(),0.0001),0.0,1.0)
		if r0.lerp(r1,t).length() <= WorldScale.span*0.5+ROCK_R:
			r.shot.done = true
			if game.smash != null and bool(game.smash.hot):
				stats.smashed = int(stats.smashed)+1
				_burst(r,true)
			else:
				_struck(r,game)
				_burst(r,true)
			return
	var behind := (plane_s-r.rs)*_way
	if behind > BEHIND_M or r.clock > LIFE_S:
		if not bool(r.shot.done): stats.dodged = int(stats.dodged)+1
		r.shot.done = true
		_burst(r,false)

## The rock hit the plane: knocked off line, the unbanked chain lost. No crash.
func _struck(r: Rock, game: Node3D) -> void:
	stats.hit = int(stats.hit)+1
	var plane = game.plane
	var v: Vector3 = r.shot.v
	var flat := Vector3(v.x,0.0,v.z)
	var p: Vector3 = plane.position
	# Shoved away from where it struck, across the way.
	var off: Vector3 = p-(r.shot.at as Vector3)
	off = Vector3(off.x,0.0,off.z)
	var fwd: Vector3 = plane.forward()
	var side := off-fwd*off.dot(fwd)
	side = side.normalized() if side.length() > 0.2 else fwd.cross(Vector3.UP).normalized()
	var turn := HIT_YAW*(1.0 if fwd.cross(side).y >= 0.0 else -1.0)
	plane.knock(HIT_KEEP,side*HIT_SHOVE+flat.normalized()*2.0+Vector3.UP*1.5,turn)
	var lost: float = game.near.lose()
	# The HUD reads the frame's events; this frame's are already in.
	var ev: Variant = game.get("_events")
	if lost > 0.0 and ev is Dictionary: (ev as Dictionary)["lost"] = {"points":lost}
	game.debris.hit("stone",r.shot.at,-v.normalized())
	game.feel_hit(HIT_FEEL.x,HIT_FEEL.y)
	game.sound.shot("crack",1.0,1.25,r.shot.at)
	game.sound.shot("debris",0.8,1.2,r.shot.at)

## It's done: bursts into grit (`loud` near the plane) and back to the pool.
func _burst(r: Rock, loud: bool) -> void:
	var at: Vector3 = r.shot.at
	if _bore != null and _bore.spurs != null:
		var rub = _bore.spurs.rubble()
		if rub != null: rub.burst(at-Vector3.UP*ROCK_R*0.5,Vector3.UP*ROCK_R,ROCK_R,(r.shot.v as Vector3)*0.3,0.6)
	if loud and _game != null: _game.sound.shot("debris",0.5,1.4,at)
	r.state = "gone"

func _drop(r: Rock) -> void:
	if r.shot.is_empty(): return
	var node: Node3D = r.shot.get("node")
	if node != null and r.state != "home":
		node.visible = false
		if not _pool.has(node): _pool.append(node)

func _clear_rocks() -> void:
	for r: Rock in _rocks:
		if r.state != "home": _drop(r)
	_rocks.clear()

# --- Where -----------------------------------------------------------------------

## Where the plane will be in the section in `t` s, holding its way across the bore
## (AIM_LEAD of it), kept inside AIM_ROOM of the bore.
func _aim(site: Tunnels.Site, p: Vector3, v: Vector3, ps: float, t: float) -> Vector2:
	var q := p+v*AIM_PROBE
	var here := _sect(site,ps,p)
	var drift := (_sect(site,Tunnels.local(site,q.x,q.z).x,q)-here)/AIM_PROBE
	var to := here+drift*t*AIM_LEAD
	var pr := Tunnels.profile(site,ps)
	var half := (pr.x+pr.y)*0.5*AIM_ROOM
	return Vector2(clampf(to.x,-half,half),clampf(to.y,-pr.z*BoreLine.MIDDLE*AIM_ROOM,pr.z*(1.0-BoreLine.MIDDLE)*AIM_ROOM))

## World point `p` as section points at `s` (x across, y up from the bore's middle).
static func _sect(t: Tunnels.Site, s: float, p: Vector3) -> Vector2:
	var mid := BoreLine.middle(t,s)
	var tg: Vector2 = Tunnels.at_s(t,s)[1]
	var d := p-mid
	return Vector2(d.dot(Vector3(-tg.y,0.0,tg.x)),d.y)

func _place(s: float, sec: Vector2) -> Vector3:
	return _place_on(_site,s,sec)

static func _place_on(t: Tunnels.Site, s: float, sec: Vector2) -> Vector3:
	var tg: Vector2 = Tunnels.at_s(t,s)[1]
	return BoreLine.middle(t,s)+Vector3(-tg.y,0.0,tg.x)*sec.x+Vector3.UP*sec.y

# --- Parried (scripts/endless/parry.gd) -------------------------------------------

## The rocks in flight (the tell's aren't yet).
func parry_shots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Rock in _rocks:
		if r.state == "fly" and not bool(r.shot.done): out.append(r.shot)
	return out

## The parry has it: out of the flight and hit tests.
func parry_take(shot: Dictionary) -> void:
	var r: Rock = shot.rock
	r.state = "home"
	stats.parried = int(stats.parried)+1

## Home is his head, on the rock where he runs.
func parry_aim(_shot: Dictionary) -> Vector3:
	if _bore == null or _bore.site == null: return (_shot.at as Vector3)+Vector3.UP*20.0
	var s: float = _bore.s
	return BoreLine.middle(_bore.site,s).lerp(BoreLine.about(_bore.site,s,BoreLine.angle_at(_bore.site,s)),OUT_SHARE)

## In him: caught up with him along the bore.
func parry_inside(p: Vector3) -> bool:
	if _bore == null or _bore.site == null: return false
	var q := Tunnels.local(_bore.site,p.x,p.z)
	return (q.x-float(_bore.s))*float(_bore.way) > -6.0

func parry_moved(_shot: Dictionary, _a: Vector3, _n: Vector3) -> void:
	pass

## Its end: on him (he staggers) or spent.
func parry_landed(shot: Dictionary, at: Vector3, hit: bool) -> void:
	var r: Rock = shot.rock
	r.state = "gone"
	var node: Node3D = shot.node
	node.visible = false
	if not _pool.has(node): _pool.append(node)
	if hit:
		stats.home_hit = int(stats.home_hit)+1
		if _bore != null and _bore.has_method("stagger"): _bore.stagger(at)

# --- The lump --------------------------------------------------------------------

func _take() -> Node3D:
	if not _pool.is_empty(): return _pool.pop_back()
	var n := Node3D.new()
	n.top_level = true
	add_child(n)
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.material_override = _mat
	mi.layers = 1 | LandTunnels.UNDER_LAYER
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	var l := OmniLight3D.new()
	l.omni_range = LIGHT_RANGE
	l.light_color = EMBER
	l.light_energy = 0.0
	l.light_cull_mask = LandTunnels.UNDER_LAYER
	l.shadow_enabled = false
	n.add_child(l)
	return n

## A stylised lump: a low sphere pushed about, flat-shaded.
func _lump() -> ArrayMesh:
	var sph := SphereMesh.new()
	sph.radius = ROCK_R
	sph.height = ROCK_R*2.0
	sph.radial_segments = 9
	sph.rings = 5
	var src: Array = sph.get_mesh_arrays()
	var verts: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = src[Mesh.ARRAY_INDEX]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7151
	# Push each distinct point (the seam's twins alike) by its own amount.
	var push := {}
	var moved := PackedVector3Array()
	for v: Vector3 in verts:
		var key := Vector3i(roundi(v.x*100.0),roundi(v.y*100.0),roundi(v.z*100.0))
		if not push.has(key): push[key] = rng.randf_range(0.72,1.12)
		moved.append(v*float(push[key])*Vector3(1.15,0.85,1.0))
	var out := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(0,idx.size(),3):
		var a := moved[idx[i]]
		var b := moved[idx[i+1]]
		var c := moved[idx[i+2]]
		var nrm := (c-a).cross(b-a).normalized()
		if nrm.dot(a+b+c) < 0.0: nrm = -nrm
		for v: Vector3 in [a,b,c]:
			out.append(v)
			normals.append(nrm)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
