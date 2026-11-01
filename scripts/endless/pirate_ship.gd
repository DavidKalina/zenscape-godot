extends Node3D
## The gray box pirate ship (docs/design/endless-flight/pirate-ship-handoff.md):
## plain blocks sailing an oval over the deep water west of the Horn. Its
## broadsides fire on the plane; a surge roll breaks the crack in either end and
## the plane flies the gun deck down the ship's length and bursts out of the other.
## A hazard, not an enemy: no health, no damage, no crash from a ball.
##
## Its frame: origin at the waterline amidships, -z the bow, +z the stern, x
## starboard. Its solid is three records in LandArches `loose`, whose pos, cos and
## sin are rewritten each frame (`before`), so plane_ground, _blocked, the camera
## and SurgeSmash `_strike` all read the ship where it is now, and the plane is
## neither carried nor pushed: the ship's move is about 0.15 m a frame, inside
## the pad the solids are grown by. The wing rays get a StaticBody on layer 1
## that goes with the node.
##
## A record's `strike` is what SurgeSmash `_hit` calls for a plate. The other
## plate stays stone, but the surge is held hot while the plane is in the
## corridor, so it breaks too on the way out. Both plates come back once the
## plane is RESEAL_FAR m off (nothing is saved: fly it again).
##
## Her look is assets/models/pirate_ship.glb on the moving node (`_dress`), or the
## gray box's blocks with --ship-blocks. Either way `solids()` alone is what she
## collides by. Guns fire from the glb's `Gun_*` empties, and a burst throws the
## plate's `CrackPlug_*` shards (`_throw`), which a reseal puts back.
##
## Handles: `coast/ship` (the ship, moved by its route), `coast/ship-route` (the
## oval's middle; a move in the layout file carries the whole route). The relic
## is the finds row `ship-hold`, anchored to `coast/ship`.

const WorldScale = preload("res://scripts/world_scale.gd")
const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const SmashBreaks = preload("res://scripts/breaks/smash_breaks.gd")

## A plate broken (`stern` or `bow`).
signal broke(part: String)

const MODEL := "res://assets/models/pirate_ship.glb"
## Where the rigging stops drawing (m); the glb can't carry it.
const RIGGING_FAR := 450.0
## The model's sway, for the eye only: roll, pitch (rad), each one's period (s).
const SWAY := Vector2(0.014,0.005)
const SWAY_S := Vector2(9.0,13.0)
## A thrown shard: fall (m/s²), what a bounce keeps, how fast the floor stops it
## (1/s), its room from the gun deck's walls (m), still under this (m/s).
const SHARD_DROP := 16.0
const SHARD_BOUNCE := 0.35
const SHARD_RUB := 4.0
const SHARD_ROOM := 0.6
const SHARD_STILL := 1.0

const SEA_Y := -40.0
## The route: the oval's middle (world XZ), its straights' length and its ends'
## radius (m), the speed along it (m/s).
const ROUTE_AT := Vector2(2050.0,3850.0)
const ROUTE_LEG := 900.0
const ROUTE_R := 200.0
const SPEED := 9.0
## The gun deck, in toy widths (WorldScale `opening`): wide, high; long is by the
## clock, about 2 s at Boost's 57 m/s. Toy 7 by 4.5 is a cracked wall's room.
const TOY_WIDE := 8.0
const TOY_HIGH := 5.0
const LONG := 110.0
## Over the waterline: the gun deck's floor; the hull's draught; the plates', the
## side walls' and the top deck's thickness (m).
const FLOOR_Y := 3.0
const DRAUGHT := 6.0
const PLATE := 1.5
## How far from the gun deck's ends a touch stops being a glance.
const END_ROOM := 2.0
const WALL := 3.0
const DECK := 2.0
const GUNS_Z := [-40.0,-24.0,-8.0,8.0,24.0,40.0]
## Guns: over the waterline (m); firing from MIN to MAX m off, within ARC rad of
## abeam; a shot every EVERY s; TELL s of flash before it; a gun rests REST s.
const GUN_Y := 8.0
const RANGE := Vector2(60.0,520.0)
const ARC := 1.05
const EVERY := 1.15
const TELL := 0.85
const REST := 3.0
## Balls: m/s, drop (m/s²), radius (m), the most at once, seconds aloft.
const BALL_SPEED := 110.0
const BALL_DROP := 6.0
const BALL_R := 1.5
const BALLS := 24
const BALL_LIFE := 7.0
## How far past a touch of the plane (WorldScale.span*0.5 off its middle) a pass
## still scores (NearMiss `shot_pass`).
const PASS_REACH := 14.0
## A ball's hit: speed kept, the shove (m/s), the turn off line (rad), the view's
## shake and punch.
const HIT_KEEP := 0.8
const HIT_SHOVE := 11.0
const HIT_YAW := 0.3
const HIT_FEEL := Vector2(0.03,9.0)
## Skimming within SKIM_NEAR m of the ship pays this many times the rate.
const SKIM_NEAR := 500.0
const SKIM_SCALE := 8.0
## Past this far (m) the plates are back.
const RESEAL_FAR := 300.0
## Where --ship-start puts the plane: off the beam (m), over the sea (m).
const START_OFF := 240.0
const START_ALT := 16.0

const HULL_C := Color(0.27,0.24,0.22)
const DECK_C := Color(0.42,0.38,0.33)
const GUNDECK_C := Color(0.5,0.47,0.42)
const RIB_C := Color(0.2,0.18,0.17)
const PLATE_C := Color(0.72,0.67,0.56)
const CRACK_C := Color(1.0,0.45,0.1)
const SAIL_C := Color(0.82,0.8,0.74)
const GUN_C := Color(0.09,0.09,0.1)
const LAMP_C := Color(1.0,0.75,0.4)
const PORT_C := Color(0.65,0.8,1.0)

var game: Node3D
## The way along the route (m), and the frame now.
var along := 0.0
var way := Vector2.RIGHT
var yaw := 0.0
var _route := Transform3D.IDENTITY
var _inv := Transform3D.IDENTITY
var wide := 16.0
var high := 10.0
## Counted, for the drivers.
var fired := 0
var hits := 0
var passes := 0
var bursts := 0
## --full-meter: the meter filled again each time the plates come back.
var refill := false
## Live balls: {node, at, v, age, least, near (world, the plane there), done}.
var balls: Array[Dictionary] = []
var _pool: Array[Node3D] = []
var _splashes: Array[Dictionary] = []
var _chunks: Array[Dictionary] = []
var _chunk_pool: Array[MeshInstance3D] = []
var _hull: Dictionary
## The glb's instance, null with --ship-blocks.
var _model: Node3D
## Thrown shards: {node, off (its plug in her frame), v (her frame), spin}.
var _shards: Array[Dictionary] = []
## part ("stern", "bow") -> {record, body, shape, look (blocks), plug and shards
## (model: {node, home}), open}.
var plates := {}
var _guns: Array[Dictionary] = []
var _tells: Array[Dictionary] = []
var _every := 0.0
var _plane_was := Vector3.INF

## The oval at `s` m along: [Vector2 place (from its middle), Vector2 way]. 0 is
## the middle of the north straight, going +x.
static func route_pose(s: float) -> Array:
	var a := ROUTE_LEG
	var r := ROUTE_R
	var t := fposmod(s+a*0.5,2.0*a+TAU*r)
	if t < a: return [Vector2(t-a*0.5,-r),Vector2.RIGHT]
	t -= a
	if t < PI*r:
		var q := t/r
		return [Vector2(a*0.5+r*sin(q),-r*cos(q)),Vector2(cos(q),sin(q))]
	t -= PI*r
	if t < a: return [Vector2(a*0.5-t,r),Vector2.LEFT]
	t -= a
	var q := t/r
	return [Vector2(-a*0.5-r*sin(q),r*cos(q)),Vector2(-cos(q),-sin(q))]

## --ship-start: {at (XZ), heading, alt}, off the ship's beam, flying her way.
static func start_pose() -> Dictionary:
	var at := ROUTE_AT+(route_pose(0.0)[0] as Vector2)+Vector2(0.0,START_OFF)
	return {"at":at,"heading":atan2(-1.0,0.0),"alt":START_ALT}

## The ship's solids, in her frame: the hull's, then each plate's.
static func solids(w: float, h: float) -> Dictionary:
	var half := w*0.5
	var beam := half+WALL
	var roof := FLOOR_Y+h
	var top := roof+DECK
	var end := LONG*0.5+PLATE
	var hull: Array[AABB] = [
		_box(-beam,-DRAUGHT,-end, beam,FLOOR_Y,end),
		_box(-beam,FLOOR_Y,-end, -half,roof,end), _box(half,FLOOR_Y,-end, beam,roof,end),
		_box(-beam,roof,-end, beam,top,end),
		# The poop and the forecastle, the stem under the bow's exit, the masts.
		_box(-beam,top,30.0, beam,top+9.0,end), _box(-beam,top,-end, beam,top+5.0,-38.0),
		_box(-half,-DRAUGHT,-end-8.0, half,FLOOR_Y,-end), _box(-half*0.5,-DRAUGHT,-end-16.0, half*0.5,FLOOR_Y,-end-8.0),
		_box(-1.0,top,-23.0, 1.0,top+40.0,-21.0), _box(-1.0,top,5.0, 1.0,top+44.0,7.0), _box(-1.0,top+9.0,41.0, 1.0,top+36.0,43.0),
	]
	return {"hull":hull,"stern":[_box(-half,FLOOR_Y,LONG*0.5, half,roof,end)],"bow":[_box(-half,FLOOR_Y,-end, half,roof,-LONG*0.5)]}

static func _box(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float) -> AABB:
	return AABB(Vector3(x0,y0,z0),Vector3(x1-x0,y1-y0,z1-z0))

func setup(g: Node3D) -> void:
	game = g
	name = "PirateShip"
	wide = WorldScale.opening(TOY_WIDE)
	high = WorldScale.opening(TOY_HIGH)
	var middle := Transform3D(Basis.IDENTITY,Vector3(ROUTE_AT.x,SEA_Y,ROUTE_AT.y))
	_route = LayoutOverrides.xform("coast/ship-route",middle)
	var marker := Node3D.new()
	marker.name = "Route"
	marker.transform = _route
	get_parent().add_child(marker)
	LayoutOverrides.track("coast/ship-route",marker,"coast",middle)
	_pose()
	LayoutOverrides.track("coast/ship",self,"coast",transform)
	_build()
	_pose()
	refill = "--full-meter" in preload("res://scripts/launch_args.gd").user_args()

## The middle of the gun deck (her frame's y): the relic hangs here.
static func deck_mid(h: float) -> float:
	return FLOOR_Y+h*0.5

func _pose() -> void:
	var pose := route_pose(along)
	var p: Vector2 = pose[0]
	var d: Vector2 = pose[1]
	var wd: Vector3 = _route.basis*Vector3(d.x,0.0,d.y)
	way = Vector2(wd.x,wd.z)
	yaw = atan2(-wd.x,-wd.z)
	transform = Transform3D(Basis(Vector3.UP,yaw),_route*Vector3(p.x,0.0,p.y))
	_inv = transform.affine_inverse()
	if _model != null:
		var t := along/SPEED
		_model.rotation = Vector3(SWAY.y*sin(TAU*t/SWAY_S.y),0.0,SWAY.x*sin(TAU*t/SWAY_S.x))
	if _hull.is_empty(): return
	_place(_hull)
	for part: String in plates: _place(plates[part].record)

func _place(r: Dictionary) -> void:
	r.pos = position
	r.cos = cos(yaw)
	r.sin = sin(yaw)

## The world's moment in her frame.
func local(p: Vector3) -> Vector3:
	return _inv*p

## Within the gun deck's walls, and between its ends (`pad` m past them).
func in_corridor(p: Vector3, pad := 0.0) -> bool:
	var l := local(p)
	return absf(l.z) < LONG*0.5+pad and absf(l.x) < wide*0.5 and l.y > FLOOR_Y-1.0 and l.y < FLOOR_Y+high+1.0

## The way off the gun deck's nearest wall, roof or floor, in the world, for
## FlightContact: a touch in there is glanced off, never a crash. ZERO outside
## it, or within END_ROOM of its ends, where a shut plate still stops the plane.
func deck_way_off(p: Vector3) -> Vector3:
	var l := local(p)
	if not in_corridor(p) or absf(l.z) > LONG*0.5-END_ROOM: return Vector3.ZERO
	var side := wide*0.5-absf(l.x)
	var roof := FLOOR_Y+high-l.y
	var floor_gap := l.y-FLOOR_Y
	var off := Vector3(-signf(l.x),0.0,0.0)
	if roof < side and roof <= floor_gap: off = Vector3.DOWN
	elif floor_gap < side: off = Vector3.UP
	return (transform.basis*off).normalized()

## One frame, before the surge and the plane's: she sails, the plates come back,
## the guns aim and fire.
func before(delta: float) -> void:
	along += SPEED*delta
	_pose()
	var p: Vector3 = game.plane.position
	var d := p.distance_to(position)
	game.near.skim_scale = SKIM_SCALE if d < SKIM_NEAR else 1.0
	if d > RESEAL_FAR: _reseal()
	if bool(game.smash.hot) and in_corridor(p,12.0): game.smash.keep_hot(0.3)
	_guns_step(delta,p,d)

## One frame, after the plane's: the balls fly and meet it. `events` as the
## study's: "scrape", "lost".
func after(delta: float, events: Dictionary) -> void:
	var p: Vector3 = game.plane.position
	var was := p if _plane_was == Vector3.INF or _plane_was.distance_to(p) > 40.0 else _plane_was
	_plane_was = p
	_balls_step(delta,was,p,events)
	_bits_step(delta)

# --- The guns ----------------------------------------------------------------

func _guns_step(delta: float, p: Vector3, d: float) -> void:
	for g: Dictionary in _guns:
		g.rest = maxf(float(g.rest)-delta,0.0)
		var puff := float(g.puff)
		if puff > 0.0:
			puff = maxf(puff-delta,0.0)
			g.puff = puff
			(g.smoke as Node3D).scale = Vector3.ONE*(1.0+(1.2-puff)*2.6)
			(g.smoke as Node3D).visible = puff > 0.0
	var left: Array[Dictionary] = []
	for t: Dictionary in _tells:
		t.t = float(t.t)-delta
		var g: Dictionary = t.gun
		(g.flash as Node3D).scale = Vector3.ONE*(1.0+1.2*(1.0-float(t.t)/TELL))
		if float(t.t) > 0.0:
			left.append(t)
			continue
		(g.flash as Node3D).visible = false
		_fire(g)
	_tells = left
	_every = maxf(_every-delta,0.0)
	if _every > 0.0 or not game.plane.weighted or not bool(game.hand_landing.flying()) or game.stage != null: return
	if d < RANGE.x or d > RANGE.y: return
	var l := local(p)
	if absf(l.z) > absf(l.x)*tan(ARC): return
	var side := signf(l.x)
	var best: Dictionary = {}
	for g: Dictionary in _guns:
		if float(g.side) != side or float(g.rest) > 0.0: continue
		if best.is_empty() or absf(float(g.z)-l.z) < absf(float(best.z)-l.z): best = g
	if best.is_empty(): return
	_every = EVERY
	best.rest = REST
	(best.flash as Node3D).visible = true
	_tells.append({"gun":best,"t":TELL})

## Gun `g` fires at where the plane is headed: straight on its line now, the ball
## meeting it there, the drop allowed for. A dodge after the shot is what saves it.
func _fire(g: Dictionary) -> void:
	var from: Vector3 = transform*(g.at as Vector3)
	(g.smoke as Node3D).visible = true
	g.puff = 1.2
	game.sound.shot("thump",1.0,0.65,from)
	if balls.size() >= BALLS: return
	var to: Vector3 = (game.plane.position as Vector3)-from
	var v: Vector3 = game.plane.velocity
	var a := v.length_squared()-BALL_SPEED*BALL_SPEED
	var b := 2.0*to.dot(v)
	var c := to.length_squared()
	var root := b*b-4.0*a*c
	if root < 0.0 or absf(a) < 0.01: return
	var t := (-b-sqrt(root))/(2.0*a)
	if t <= 0.0: return
	var ball := _ball()
	ball.position = from
	ball.visible = true
	var at: Vector3 = to+v*t
	var shot := at/t+Vector3.UP*BALL_DROP*t*0.5
	balls.append({"node":ball,"at":from,"v":shot,"age":0.0,"least":INF,"near":from,"done":false})
	fired += 1

func _ball() -> Node3D:
	if not _pool.is_empty(): return _pool.pop_back()
	var n := Node3D.new()
	n.top_level = true
	add_child(n)
	var body := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = BALL_R
	s.height = BALL_R*2.0
	s.radial_segments = 12
	s.rings = 6
	body.mesh = s
	body.material_override = _mat(Color(0.12,0.1,0.09),Color(1.0,0.35,0.05),1.4)
	n.add_child(body)
	var tail := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.7,0.7,9.0)
	tail.mesh = box
	tail.position = Vector3(0.0,0.0,5.0)
	tail.material_override = _mat(Color(0.6,0.58,0.55),Color(0.6,0.58,0.55),0.5)
	n.add_child(tail)
	return n

func _balls_step(delta: float, was: Vector3, p: Vector3, events: Dictionary) -> void:
	var reach := WorldScale.span*0.5+BALL_R
	var hot: bool = game.smash.hot
	var flying: bool = game.hand_landing.flying()
	for i in range(balls.size()-1,-1,-1):
		var b: Dictionary = balls[i]
		var a: Vector3 = b.at
		var v: Vector3 = b.v
		v += Vector3.DOWN*BALL_DROP*delta
		var n: Vector3 = a+v*delta
		b.v = v
		b.at = n
		b.age = float(b.age)+delta
		(b.node as Node3D).position = n
		if v.length() > 1.0: (b.node as Node3D).basis = Basis.looking_at(v.normalized(),Vector3.UP if absf(v.normalized().y) < 0.99 else Vector3.RIGHT)
		# The closest pass this frame: both moved, so the segment's of the two apart.
		if flying and not bool(b.done):
			var r0 := a-was
			var r1 := n-p
			var k := clampf(-r0.dot(r1-r0)/maxf((r1-r0).length_squared(),0.0001),0.0,1.0)
			var gap := r0.lerp(r1,k).length()
			if gap < float(b.least):
				b.least = gap
				b.near = was.lerp(p,k)
			if float(b.least) <= reach:
				b.done = true
				if not hot: _struck(b,events)
			elif float(b.least) < reach+PASS_REACH and gap > float(b.least)+6.0:
				b.done = true
				_passed(b)
		var ground := maxf(float(game.field.height(n.x,n.z)),float(game.water_at(n)))
		if n.y <= ground or float(b.age) > BALL_LIFE:
			if not bool(b.done) and float(b.least) < reach+PASS_REACH: _passed(b)
			if n.y <= ground: _splash(Vector3(n.x,ground,n.z))
			(b.node as Node3D).visible = false
			_pool.append(b.node)
			balls.remove_at(i)

func _passed(b: Dictionary) -> void:
	passes += 1
	var clear := maxf(float(b.least)-WorldScale.span*0.5-BALL_R,0.0)
	game.near.shot_pass(clear,PASS_REACH,b.near)
	game.sound.shot("whoosh",0.7,1.3,b.near)

## Ball `b` hit: the unbanked chain gone, the plane off line. No crash, no
## damage, and the banked meter stays.
func _struck(b: Dictionary, events: Dictionary) -> void:
	hits += 1
	var plane = game.plane
	var at: Vector3 = b.near
	var v: Vector3 = b.v
	var flat := Vector3(v.x,0.0,v.z)
	flat = flat.normalized() if flat.length() > 0.1 else Vector3.ZERO
	var fwd: Vector3 = plane.forward()
	var turn := HIT_YAW*(1.0 if fwd.cross(flat).y >= 0.0 else -1.0)
	var speed := float(plane.speed)
	plane.knock(HIT_KEEP,flat*HIT_SHOVE+Vector3.UP*2.0,turn)
	var lost: float = game.near.lose()
	if lost > 0.0: events["lost"] = {"points":lost}
	events["scrape"] = {"at":at,"normal":-v.normalized(),"what":"stone","into":HIT_SHOVE,"angle":0.5,"speed":speed,"keep":HIT_KEEP}
	game.debris.hit("stone",at,-v.normalized())
	game.feel_hit(HIT_FEEL.x,HIT_FEEL.y)
	game.sound.shot("crash",1.0,0.8)
	(b.node as Node3D).visible = false

# --- The plates --------------------------------------------------------------

## The plane's breaking `r` (SurgeSmash `_hit`): it's gone till the plates come
## back, and the surge lasts to the far end.
func _strike(r: Dictionary, q: Vector3) -> void:
	var part := str(r.part)
	var plate: Dictionary = plates[part]
	if bool(plate.open): return
	plate.open = true
	game.arches.loose.erase(r)
	(plate.shape as CollisionShape3D).disabled = true
	game.smash.keep_hot(LONG/maxf(float(game.plane.velocity.length()),30.0)+0.5)
	if _model != null:
		_throw(plate,q)
	else:
		(plate.look as Node3D).visible = false
		_shatter(q)
	bursts += 1
	broke.emit(part)

func _reseal() -> void:
	var was := false
	for part: String in plates:
		var plate: Dictionary = plates[part]
		if not bool(plate.open): continue
		was = true
		plate.open = false
		game.arches.loose.push_front(plate.record)
		_place(plate.record)
		(plate.shape as CollisionShape3D).disabled = false
		if _model == null:
			(plate.look as Node3D).visible = true
			continue
		(plate.cover as Node3D).visible = true
		for shard: Dictionary in plate.shards:
			(shard.node as Node3D).transform = shard.home
			(shard.node as Node3D).visible = true
	_shards.clear()
	if was and refill: game.near.meter = 1.0

func _shatter(q: Vector3) -> void:
	var v: Vector3 = game.plane.velocity
	var d := v.normalized()
	for i in 14:
		var c: MeshInstance3D = _chunk_pool.pop_back() if not _chunk_pool.is_empty() else _new_chunk()
		var spread := Vector3(randf_range(-1.0,1.0),randf_range(-0.6,1.0),randf_range(-1.0,1.0))
		c.position = q+spread*3.0
		c.scale = Vector3.ONE*randf_range(0.5,1.6)
		c.visible = true
		_chunks.append({"node":c,"v":d*randf_range(20.0,55.0)+spread*14.0,"t":2.2})

## The plate's shards blown off the plane's line, as a smashed ruin's stone flies
## (SmashBreaks): on ahead with the plane, out from its line, up, spinning. So a
## plate hit from outside goes down the gun deck, one hit from inside goes out to
## sea. Drawn only; they stay under their plug, in her frame.
func _throw(plate: Dictionary, q: Vector3) -> void:
	var v: Vector3 = game.plane.velocity
	var d := v.normalized()
	var plug: Node3D = plate.plug
	(plate.cover as Node3D).visible = false
	for shard: Dictionary in plate.shards:
		var n: Node3D = shard.node
		var out := (transform*(plug.position+n.position)-q).slide(d)
		out = out.normalized() if out.length() > 0.05 else Vector3.UP
		var lin := v*randf_range(SmashBreaks.KEEP.x,SmashBreaks.KEEP.y)+out*randf_range(SmashBreaks.OUT.x,SmashBreaks.OUT.y)+Vector3.UP*randf_range(SmashBreaks.UP_V.x,SmashBreaks.UP_V.y)
		var spin := Vector3(randf_range(-1.0,1.0),randf_range(-1.0,1.0),randf_range(-1.0,1.0)).normalized()*randf_range(SmashBreaks.SPIN.x,SmashBreaks.SPIN.y)
		_shards.append({"node":n,"off":plug.position,"v":_inv.basis*lin,"spin":spin})

## Thrown shards on: inside the gun deck they're kept in it, and lie where they
## stop till the reseal; past her ends they fall into the sea.
func _shards_step(delta: float) -> void:
	for i in range(_shards.size()-1,-1,-1):
		var s: Dictionary = _shards[i]
		var n: Node3D = s.node
		var v: Vector3 = s.v
		v += Vector3.DOWN*SHARD_DROP*delta
		var at: Vector3 = (s.off as Vector3)+n.position+v*delta
		var low := false
		if absf(at.z) < LONG*0.5:
			var x := wide*0.5-SHARD_ROOM
			if absf(at.x) > x:
				at.x = signf(at.x)*x
				v.x *= -SHARD_BOUNCE
			if at.y > FLOOR_Y+high-SHARD_ROOM:
				at.y = FLOOR_Y+high-SHARD_ROOM
				v.y *= -SHARD_BOUNCE
			if at.y < FLOOR_Y+SHARD_ROOM:
				at.y = FLOOR_Y+SHARD_ROOM
				v.y = absf(v.y)*SHARD_BOUNCE
				v *= maxf(1.0-SHARD_RUB*delta,0.0)
				low = true
		s.v = v
		n.position = at-(s.off as Vector3)
		var spin: Vector3 = s.spin
		n.rotate(spin.normalized(),spin.length()*delta)
		if low and v.length() < SHARD_STILL:
			_shards.remove_at(i)
		elif at.y < -DRAUGHT:
			n.visible = false
			_shards.remove_at(i)

func _new_chunk() -> MeshInstance3D:
	var c := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(1.5,0.9,1.1)
	c.mesh = b
	c.material_override = _mat(PLATE_C)
	c.top_level = true
	add_child(c)
	return c

func _splash(at: Vector3) -> void:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.8
	c.bottom_radius = 2.6
	c.height = 1.0
	c.radial_segments = 8
	m.mesh = c
	m.material_override = _mat(Color(0.92,0.96,1.0),Color(0.8,0.85,0.9),0.5)
	m.top_level = true
	add_child(m)
	m.position = at
	_splashes.append({"node":m,"t":0.0})

func _bits_step(delta: float) -> void:
	_shards_step(delta)
	for i in range(_splashes.size()-1,-1,-1):
		var s: Dictionary = _splashes[i]
		s.t = float(s.t)+delta
		var k := float(s.t)/0.9
		var n: MeshInstance3D = s.node
		n.scale = Vector3(1.0+k*1.5,14.0*sin(minf(k,1.0)*PI)+0.01,1.0+k*1.5)
		if k >= 1.0:
			n.queue_free()
			_splashes.remove_at(i)
	for i in range(_chunks.size()-1,-1,-1):
		var c: Dictionary = _chunks[i]
		c.t = float(c.t)-delta
		var v: Vector3 = c.v
		v += Vector3.DOWN*16.0*delta
		c.v = v
		var n: MeshInstance3D = c.node
		n.position += v*delta
		n.rotate_x(delta*5.0)
		if float(c.t) <= 0.0 or n.position.y < SEA_Y:
			n.visible = false
			_chunk_pool.append(n)
			_chunks.remove_at(i)

# --- Her look and solids -------------------------------------------------------

func _build() -> void:
	var all := solids(wide,high)
	var blocks: bool = "--ship-blocks" in preload("res://scripts/launch_args.gd").user_args()
	if blocks: _blocks(all)
	else: _dress()
	# The solids: the plates first in `loose`, so a hit near a jamb finds the plate.
	_hull = _record("hull",all.hull)
	_hull["no_break"] = true
	_hull["adopted"] = 0
	game.arches.loose.append(_hull)
	_body("Hull",all.hull)
	for part: String in ["stern","bow"]:
		var box: AABB = (all[part] as Array)[0]
		var record := _record(part,all[part])
		record["strike"] = Callable(self,"_strike")
		record["part"] = part
		game.arches.loose.push_front(record)
		var body := _body(part.capitalize(),[box])
		var plate := {"record":record,"body":body,"shape":body.get_child(0),"open":false}
		if blocks: plate["look"] = _plate(box,part)
		else: _plug(plate,part)
		plates[part] = plate

## The model on the moving node, its guns' muzzles read off its empties.
func _dress() -> void:
	_model = (load(MODEL) as PackedScene).instantiate()
	_model.name = "Model"
	add_child(_model)
	(_model.find_child("Rigging",true,false) as GeometryInstance3D).visibility_range_end = RIGGING_FAR
	for i in GUNS_Z.size():
		var z: float = GUNS_Z[GUNS_Z.size()-1-i]
		for side: float in [-1.0,1.0]:
			var empty: Node3D = _model.find_child("Gun_%s_%02d" % ["L" if side < 0.0 else "R",i+1],true,false)
			_muzzle(side,z,to_local(empty.global_position))

## Plate `part`'s plug in the model, each shard's place kept for the reseal.
func _plug(plate: Dictionary, part: String) -> void:
	var plug: Node3D = _model.find_child("CrackPlug_"+part.capitalize(),true,false)
	var shards: Array[Dictionary] = []
	for shard: Node in plug.get_children():
		if shard.name.begins_with("Cover"):
			plate["cover"] = shard
			(shard as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			continue
		shards.append({"node":shard,"home":(shard as Node3D).transform})
	plate["plug"] = plug
	plate["shards"] = shards

func _blocks(all: Dictionary) -> void:
	var half := wide*0.5
	var beam := half+WALL
	var roof := FLOOR_Y+high
	var top := roof+DECK
	var end := LONG*0.5+PLATE
	var hull_m := _mat(HULL_C)
	var inside := _mat(GUNDECK_C,GUNDECK_C,0.4)
	# The hull's shell, and the gun deck's own lining so its inside reads.
	_look(_box(-beam,-DRAUGHT,-end, beam,FLOOR_Y,end),hull_m)
	_look(_box(-beam,FLOOR_Y,-end, -half,roof,end),hull_m)
	_look(_box(half,FLOOR_Y,-end, beam,roof,end),hull_m)
	_look(_box(-beam,roof,-end, beam,top,end),_mat(DECK_C))
	var skin := 0.04
	_look(_box(-half,FLOOR_Y,-end, half,FLOOR_Y+skin,end),inside)
	_look(_box(-half,FLOOR_Y,-end, -half+skin,roof,end),inside)
	_look(_box(half-skin,FLOOR_Y,-end, half,roof,end),inside)
	_look(_box(-half,roof-skin,-end, half,roof,end),_mat(RIB_C,RIB_C,0.5))
	for i in range(4,11): _look(all.hull[i],hull_m if i < 8 else _mat(RIB_C))
	# Sails: gray box, drawn only; the plane goes through them.
	var sail := _mat(SAIL_C,SAIL_C,0.15)
	for row: Array in [[-22.0,top+14.0,26.0],[6.0,top+16.0,28.0],[42.0,top+21.0,18.0]]:
		_look(_box(-float(row[2])*0.5,float(row[1]),float(row[0])-0.3, float(row[2])*0.5,float(row[1])+18.0,float(row[0])+0.3),sail)
	_look(_box(-0.4,top+1.0,-end-34.0, 0.4,top+1.8,-end),_mat(RIB_C))
	# Inside: ribs every so often to read the speed by, lamps, the guns at their ports.
	var rib := _mat(RIB_C,RIB_C,0.3)
	var z := -LONG*0.5+5.5
	while z < LONG*0.5:
		_look(_box(-half,FLOOR_Y,z-0.5, -half+0.15,roof,z+0.5),rib)
		_look(_box(half-0.15,FLOOR_Y,z-0.5, half,roof,z+0.5),rib)
		_look(_box(-half,roof-0.3,z-0.5, half,roof,z+0.5),rib)
		z += 11.0
	var lamp := _mat(LAMP_C,LAMP_C,3.0)
	var port := _mat(PORT_C,PORT_C,2.0)
	var gun := _mat(GUN_C)
	for gz: float in GUNS_Z:
		for side: float in [-1.0,1.0]:
			_look(AABB(Vector3(side*(half-0.5)-0.2,roof-1.2,gz-0.5),Vector3(0.4,0.9,1.0)),lamp)
			_look(AABB(Vector3(side*half-0.06,GUN_Y-1.1,gz-1.2),Vector3(0.12,2.2,2.4)),port)
			_look(AABB(Vector3(side*(half-0.5)-0.5,FLOOR_Y,gz-1.0),Vector3(1.0,1.1,2.0)),gun)
			_gun(side,gz,beam,gun)

func _record(part: String, boxes: Array) -> Dictionary:
	return {"name":"coast/ship/"+part,"kind":"ship","node":self,"pos":position,"cos":cos(yaw),"sin":sin(yaw),
		"solid":BoxSolid.build(boxes),"reach":LONG*0.5+45.0,"spec":{}}

func _body(label: String, boxes: Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = game.arches.LAYER
	body.collision_mask = 0
	for box: AABB in boxes:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		cs.shape = shape
		cs.position = box.get_center()
		body.add_child(cs)
	add_child(body)
	return body

## A plate's look: pale stone, a glowing crack down it on both faces.
func _plate(box: AABB, part: String) -> Node3D:
	var root := Node3D.new()
	root.name = part.capitalize()+"Look"
	add_child(root)
	_look(box,_mat(PLATE_C,PLATE_C,0.2),root)
	var crack := _mat(CRACK_C,CRACK_C,2.5)
	var c := box.get_center()
	var w := box.size.x
	var h := box.size.y
	var strokes := [[0.0,0.0,0.9,0.25],[-0.05,0.3,0.45,-0.6],[0.06,-0.28,0.5,0.7],[-0.2,-0.12,0.45,1.15],[0.22,0.12,0.5,-1.2],[0.12,0.34,0.3,0.9],[-0.14,-0.36,0.3,-0.9]]
	for z: float in [box.position.z-0.05,box.end.z+0.05]:
		for s: Array in strokes:
			var m := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.9,float(s[2])*h,0.1)
			m.mesh = b
			m.material_override = crack
			m.transform = Transform3D(Basis(Vector3.BACK,float(s[3])),Vector3(c.x+float(s[0])*w,c.y+float(s[1])*h,z))
			root.add_child(m)
	return root

## A broadside gun at (`side`, `gz`) in blocks: port, barrel, its muzzle.
func _gun(side: float, gz: float, beam: float, mat: Material) -> void:
	_look(AABB(Vector3(side*beam-(0.1 if side > 0.0 else 0.0),GUN_Y-1.0,gz-1.0),Vector3(0.1,2.0,2.0)),_mat(Color.BLACK))
	var x := side*(beam+1.2)
	_look(AABB(Vector3(x-1.2,GUN_Y-0.5,gz-0.5),Vector3(2.4,1.0,1.0)),mat)
	_muzzle(side,gz,Vector3(side*(beam+3.0),GUN_Y,gz))

## A gun's muzzle at `at`: its flash and smoke, and the record the guns fire by.
func _muzzle(side: float, gz: float, at: Vector3) -> void:
	var flash := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(2.2,2.2,2.2)
	flash.mesh = b
	flash.material_override = _mat(Color(1.0,0.8,0.3),Color(1.0,0.7,0.2),5.0)
	flash.position = at
	flash.visible = false
	add_child(flash)
	var smoke := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(4.0,4.0,4.0)
	smoke.mesh = sb
	smoke.material_override = _mat(Color(0.8,0.8,0.78),Color(0.5,0.5,0.48),0.4)
	smoke.position = at+Vector3(side*2.0,1.0,0.0)
	smoke.visible = false
	add_child(smoke)
	_guns.append({"side":side,"z":gz,"at":at,"flash":flash,"smoke":smoke,"puff":0.0,"rest":0.0})

func _look(box: AABB, mat: Material, under: Node3D = self) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = box.size
	m.mesh = b
	m.material_override = mat
	m.position = box.get_center()
	under.add_child(m)
	return m

func _mat(c: Color, glow := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = glow
		m.emission_energy_multiplier = energy
	return m
