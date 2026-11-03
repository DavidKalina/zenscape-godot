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
## Both plates open with no ring left aboard sinks her (`state`, `_sink`): the
## ring taken, or a ship that never had it. A miss of the ring leaves her to
## reseal. She settles by the end broken last, lists away from the plane and goes
## under in SINK_S s (`sink_pose`). Her guns stop at once. In a sink the `loose`
## record is off and `wreck_ground`, `wreck_inside` and the StaticBody follow her
## true tilt, and a touch of her is a glance (`deck_way_off`), never a crash.
## RETURN_S s after she's gone a fresh ship comes up on the route where the eye
## can't see it happen (`_return_spot`). The ring is one find in the book: ships
## after it carry none, and sinking one pays SINK_POINTS (NearMiss `prize`).
##
## Her look is assets/models/pirate_ship.glb on the moving node (`_dress`), or the
## gray box's blocks with --ship-blocks. Either way `solids()` alone is what she
## collides by. Guns fire from the glb's `Gun_*` empties, and a burst throws the
## plate's `CrackPlug_*` shards (`_throw`), which a reseal puts back.
##
## Two sail at once (CoastSites `ships`), each one of these on its own route, with
## its own guns, plates, sink and return. They share meshes and materials (`twin`),
## and each keeps its own BALLS. What only one may set is CoastSites' to pick: the
## near miss's `skim_scale` (`skim`, the most of them) and the eye (`watch`, newest
## sink).
##
## Handles: `coast/ship` (the ship, moved by its route), `coast/ship-route` (the
## oval's middle; a move in the layout file carries the whole route); the second's
## are `coast/ship2` and `coast/ship2-route`. The relic is the finds row `ship-hold`,
## anchored to `coast/ship`, so she alone carries it (`carries`).

const WorldScale = preload("res://scripts/world_scale.gd")
const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const SmashBreaks = preload("res://scripts/breaks/smash_breaks.gd")
const LandHalls = preload("res://scripts/endless/land_halls.gd")

## A plate broken (`stern` or `bow`).
signal broke(part: String)
## She has started down / a fresh ship is back on the route.
signal sinking
signal returned

const MODEL := "res://assets/models/pirate_ship.glb"
const ShipSails = preload("res://scripts/endless/ship_sails.gd")
## The cast ball (art/blender/ship/ball_build.py), and how fast it tumbles (rad/s):
## look only, so the iron's marks turn over in flight.
const BALL_MODEL := "res://assets/models/pirate_ball.glb"
const BALL_TUMBLE := 3.0
## The ball's wisp of smoke, look only: its shader, how far back it runs (m), its
## radius at the ball and at the end, its opacity at the thickest.
const SMOKE_SHADER := "res://assets/models/pirate_ship/ball_smoke.gdshader"
const SMOKE_LONG := 18.0
const SMOKE_THIN := 0.45
const SMOKE_WIDE := 3.6
const SMOKE_OPACITY := 0.42
## A gun's flash and smoke puff (look only): their shader, the flash's core radius
## (m, readable from 300 m) and the puff's reach.
const PUFF_SHADER := "res://assets/models/pirate_ship/muzzle_puff.gdshader"
const FLASH_R := 3.8
const PUFF_R := 2.0
## Where the rigging stops drawing (m); the glb can't carry it.
const RIGGING_FAR := 450.0
## Where what can't be told from outside stops drawing (m): the gun deck's inside and
## guns, a plate's shards. 111 draw calls at 2 km on a ship 40 px long, most of them
## these (handoff, What it costs).
const INNER_FAR := 700.0
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
## The second ship's oval: its middle, its straights' length (m), its turn (rad) off
## the first's: the deep basin south-east of her past the isles off the Horn, which
## the first's length doesn't fit.
const ROUTE2_AT := Vector2(3500.0,4700.0)
const ROUTE2_LEG := 500.0
const ROUTE2_TURN := -PI*0.25
## The gun deck, in toy widths (WorldScale `opening`): wide, high; long is by the
## clock, about 2 s at Boost's 57 m/s. Toy 7 by 4.5 is a cracked wall's room.
const TOY_WIDE := 9.0
const TOY_HIGH := 5.0
const LONG := 110.0
## Over the waterline: the gun deck's floor; the hull's draught; the plates', the
## side walls' and the top deck's thickness (m).
const FLOOR_Y := 3.0
const DRAUGHT := 6.0
const PLATE := 1.5
## How far from the gun deck's ends a touch stops being a glance.
const END_ROOM := 2.0
const WALL := 3.375
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
## The finds row aboard her.
const RELIC := "ship-hold"
## Paid for sinking a ship with no ring: a line of its own, no multiplier, past
## the corridor's own line (about 15,000); METER_FULL is 4000, so it fills the meter.
const SINK_POINTS := 25000.0
## When the points land (s into the sink): the corridor's line has banked by then.
const SINK_PAY_AT := 4.0
## The toast at the start of a sink, with the ring just taken and without.
const SINK_WORDS := "The ring is yours. She's going down"
const SINK_WORDS_BARE := "She's going down"
## The prize's name on the read-out.
const SINK_LINE := "Ship sunk"
## The sink, seconds: the least till she's gone (she's gone when she's under, about
## 20 s), how long she keeps any way on.
const SINK_S := 19.0
const SINK_WAY_S := 9.0
## Her pose: [t s, m down, pitch, roll (degrees)], eased through (`sink_pose`). A
## lurch and a recovery, a slow settle by one end, the list growing, then the plunge.
const SINK_KEYS := [
	[-4.0,0.0,0.0,0.0],[0.0,0.0,0.0,0.0],[0.8,0.7,0.7,1.8],[2.4,0.5,0.9,0.7],[6.0,3.0,2.8,4.5],
	[10.5,8.5,6.5,10.0],[14.5,16.0,11.5,17.0],[18.0,31.0,19.0,25.0],[20.5,50.0,27.0,31.0],[22.5,78.0,33.0,36.0],[26.0,120.0,38.0,40.0],
]
## Her shudder on the lurch: rad, rad/s, how fast it dies (1/s).
const SHUDDER := Vector3(0.006,27.0,0.7)
## Water and wreckage: seconds between beats; how far off (m) the wash is bothered with.
const SINK_BEAT := 0.35
const SINK_NEAR := 1500.0
## What breaks in her as she goes: [t s, sound, gain, pitch].
const SINK_CUES := [
	[1.2,"creak",1.0,0.5],[3.4,"thump",1.0,0.5],[5.6,"creak",1.0,0.42],[8.2,"crash",0.6,0.5],[9.8,"creak",1.1,0.38],
	[12.6,"thump",1.1,0.45],[14.2,"crash",0.8,0.42],[16.0,"creak",1.2,0.34],[18.2,"crash",1.0,0.36],[20.0,"thump",1.3,0.36],
]
## Sound's reach: flat gain at 0 m, halved every this far (m).
const SINK_HEARD := 350.0
## Mist off her waterline: how many at once; radius (m), rise (m/s), life (s).
const MISTS := 16
const MIST_R := Vector2(0.9,2.4)
const MIST_RISE := 5.0
const MIST_LIFE := 4.5
## Planks left afloat: how many, how long they stay (s), how fast they go down (m/s).
const PLANKS := 22
const PLANK_LIFE := 40.0
const PLANK_SINK := 0.5
const PLANK_TURNS := 5
## The wreck's reach from her middle (m): past it nothing of her is met.
const WRECK_REACH := 125.0
## Her far points (her frame), the mast tops and poop, for "all under".
const HIGH_POINTS := [Vector3(0.0,59.0,6.0),Vector3(0.0,55.0,-22.0),Vector3(0.0,51.0,42.0),Vector3(0.0,24.0,56.0),Vector3(0.0,20.0,-56.0)]
## Her return: least seconds after she's gone (--ship-return=S), how often it's tried
## (s), how many spots round the route. A spot is good at RETURN_ANY m off the eye,
## or at RETURN_NEAR m off and outside the view (RETURN_CONE: the cosine off its axis).
const RETURN_S := 60.0
const RETURN_POLL := 0.5
const RETURN_SPOTS := 24
const RETURN_ANY := 4000.0
const RETURN_NEAR := 600.0
const RETURN_CONE := 0.17
## Nor within this far (m) of the other ship: past both broadsides' reach.
const RETURN_APART := 1050.0
## The eye in a sink (`watch`): from when (s), how slowly it eases over and back (s),
## how far off her axis she sits so the plane doesn't hide her (rad), past how far
## off (m) it gives up, how far ahead it checks the plane's way (s).
const WATCH_FROM := 1.0
const WATCH_EASE := 1.3
const WATCH_OFF := 0.16
const WATCH_FAR := 1300.0
const WATCH_AHEAD: Array[float] = [1.5,3.0,4.5]
const WATCH_ROOM := 10.0
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
const PLANK_C := Color(0.56,0.43,0.3)
const GUN_C := Color(0.09,0.09,0.1)
const LAMP_C := Color(1.0,0.75,0.4)
const PORT_C := Color(0.65,0.8,1.0)

enum {AFLOAT,SINKING,GONE}

var game: Node3D
## Her name in the layout file, the way her route's is `handle`-route.
var handle := "coast/ship"
## The other ship, or null: its meshes are hers, and she comes back clear of it.
var twin: Node3D
## What she'd have the near miss's skim rate at this frame (CoastSites `before`).
var skim := 1.0
## AFLOAT, SINKING (`sink_t` s in) or GONE (`gone_t` s since).
var state := AFLOAT
var sink_t := -1.0
var gone_t := 0.0
## The least wait in GONE (s).
var return_wait := RETURN_S
## The way along the route (m), and the frame now.
var along := 0.0
var way := Vector2.RIGHT
var yaw := 0.0
var _route := Transform3D.IDENTITY
var _leg := ROUTE_LEG
var _inv := Transform3D.IDENTITY
var wide := 18.0
var high := 10.0
## Counted, for the drivers.
var fired := 0
var hits := 0
var passes := 0
var bursts := 0
var sinks := 0
var returns := 0
var paid := 0.0
## --full-meter: the meter filled again each time the plates come back, and once
## when the plane leaves a sinking ship, whose plates won't.
var refill := false
var _refilled := false
## Live balls: {node, at, v, age, least, near (world, the plane there), done}.
var balls: Array[Dictionary] = []
var _pool: Array[Node3D] = []
var _splashes: Array[Dictionary] = []
var _chunks: Array[Dictionary] = []
var _chunk_pool: Array[MeshInstance3D] = []
var _hull: Dictionary
## The glb's instance, null with --ship-blocks.
var _model: Node3D
## The one mesh every ball draws, its material on it; null with --ship-blocks.
var _ball_mesh: Mesh
## The one wisp every ball trails, its material on it; null with --ship-blocks.
var _smoke: Mesh
## Thrown shards: {node, off (its plug in her frame), v (her frame), spin}.
var _shards: Array[Dictionary] = []
## part ("stern", "bow") -> {record, body, shape, look (blocks), plug and shards
## (model: {node, home}), open}.
var plates := {}
var _guns: Array[Dictionary] = []
var _tells: Array[Dictionary] = []
## The one flash and the one smoke puff every gun draws; null with --ship-blocks.
var _flash_mesh: Mesh
var _puff_mesh: Mesh
var _every := 0.0
var _plane_was := Vector3.INF
## The hull's StaticBody, off while she's gone.
var _hull_body: StaticBody3D
## This run: the ring aboard when its first plate broke; the plate broken last.
var _carried := false
var _last := "bow"
## The sink: bow (1) or stern (-1) down, the side she lists to (1 starboard), the
## next wash and cue, the plane past her solids (the deck flooded round it), the
## points yet to land, the moment's news for the frame's events.
var _end := 1.0
var _list := 1.0
var _beat := 0.0
var _cue := 0
var _ghost := false
var _pay := false
var _poll := 0.0
## The eye: looking on her now; the player has turned it (right stick, or the right
## mouse button) in this sink; it's handed back for the rest of this sink.
var watching := false
var _panned := false
var _handed_back := false
## What's left on the water, beside her so it stays when she's gone.
var _wake: Node3D
var _mist_mesh: Mesh
var _plank_mat: Material
## Hands the sails her way (null with --ship-blocks).
var _sails: RefCounted
var _mists: Array[Dictionary] = []
var _planks: Array[Dictionary] = []

## The oval at `s` m along: [Vector2 place (from its middle), Vector2 way]. 0 is
## the middle of the north straight, going +x. `a` is the straights' length.
static func route_pose(s: float, a := ROUTE_LEG) -> Array:
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

## `at`, `leg` and `turn` are her route's middle, straights and turn; `first`, the
## ship built before her, if any.
func setup(g: Node3D, at := ROUTE_AT, label := "coast/ship", first: Node3D = null, leg := ROUTE_LEG, turn := 0.0) -> void:
	game = g
	name = "PirateShip"
	handle = label
	twin = first
	_leg = leg
	if first != null: first.twin = self
	wide = WorldScale.opening(TOY_WIDE)
	high = WorldScale.opening(TOY_HIGH)
	var middle := Transform3D(Basis(Vector3.UP,turn),Vector3(at.x,SEA_Y,at.y))
	_route = LayoutOverrides.xform(handle+"-route",middle)
	var marker := Node3D.new()
	marker.name = "Route"
	marker.transform = _route
	get_parent().add_child(marker)
	LayoutOverrides.track(handle+"-route",marker,"coast",middle)
	_pose()
	LayoutOverrides.track(handle,self,"coast",transform)
	_build()
	_pose()
	var args: PackedStringArray = preload("res://scripts/launch_args.gd").user_args()
	refill = "--full-meter" in args
	for a: String in args:
		if a.begins_with("--ship-return="): return_wait = a.trim_prefix("--ship-return=").to_float()

## The middle of the gun deck (her frame's y): the relic hangs here.
static func deck_mid(h: float) -> float:
	return FLOOR_Y+h*0.5

func _pose() -> void:
	var pose := route_pose(along,_leg)
	var p: Vector2 = pose[0]
	var d: Vector2 = pose[1]
	var wd: Vector3 = _route.basis*Vector3(d.x,0.0,d.y)
	way = Vector2(wd.x,wd.z)
	yaw = atan2(-wd.x,-wd.z)
	transform = Transform3D(Basis(Vector3.UP,yaw),_route*Vector3(p.x,0.0,p.y))
	var shake := 0.0
	if sink_t >= 0.0:
		var s := sink_pose(sink_t)
		transform.basis = transform.basis*Basis.from_euler(Vector3(deg_to_rad(s.y)*-_end,0.0,deg_to_rad(s.z)*-_list))
		transform.origin.y -= s.x
		shake = SHUDDER.x*exp(-sink_t*SHUDDER.z)*sin(sink_t*SHUDDER.y)
	_inv = transform.affine_inverse()
	if _model != null:
		var t := along/SPEED
		_model.rotation = Vector3(SWAY.y*sin(TAU*t/SWAY_S.y)+shake,0.0,SWAY.x*sin(TAU*t/SWAY_S.x)+shake*0.6)
	if _hull.is_empty(): return
	_place(_hull)
	for part: String in plates: _place(plates[part].record)

func _place(r: Dictionary) -> void:
	r.pos = position
	r.cos = cos(yaw)
	r.sin = sin(yaw)
	GroundNative.bump_loose()

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
func deck_way_off(p: Vector3, what := "") -> Vector3:
	var l := local(p)
	if state == SINKING and not in_corridor(p): return _wreck_way_off(p,l,what)
	if state == GONE: return Vector3.ZERO
	if not in_corridor(p) or (state == AFLOAT and absf(l.z) > LONG*0.5-END_ROOM): return Vector3.ZERO
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
	if state == GONE:
		skim = 1.0
		_wait(delta)
		return
	if state == SINKING: sink_t += delta
	along += SPEED*delta*(1.0 if state == AFLOAT else clampf(1.0-sink_t/SINK_WAY_S,0.0,1.0))
	_pose()
	if _sails != null: _sails.step(delta,position,way,state == SINKING)
	var p: Vector3 = game.plane.position
	var d := p.distance_to(position)
	skim = SKIM_SCALE if state == AFLOAT and d < SKIM_NEAR else 1.0
	if state == AFLOAT:
		if _all_open() and not carries(): _sink()
		elif d > RESEAL_FAR: _reseal()
	elif refill and not _refilled and d > RESEAL_FAR:
		_refilled = true
		game.near.meter = 1.0
	if bool(game.smash.hot) and in_corridor(p,12.0): game.smash.keep_hot(0.3)
	_guns_step(delta,p,d)
	if state == SINKING: _sink_step(delta,p,d)

## One frame, after the plane's: the balls fly and meet it. `events` as the
## study's: "scrape", "lost".
func after(delta: float, events: Dictionary) -> void:
	var p: Vector3 = game.plane.position
	var was := p if _plane_was == Vector3.INF or _plane_was.distance_to(p) > 40.0 else _plane_was
	_plane_was = p
	_balls_step(delta,was,p,events)
	_bits_step(delta)
	_wake_step(delta)

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
			if _puff_mesh != null:
				var u := 1.2-puff
				(g.smoke as Node3D).position = (g.at as Vector3)+Vector3(float(g.side)*(2.0+u*4.0),1.0+u*1.5,0.0)
				(g.smoke as GeometryInstance3D).set_instance_shader_parameter("fade",smoothstep(0.0,0.8,puff))
	if state != AFLOAT: return
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
	if _ball_mesh != null:
		body.mesh = _ball_mesh
	else:
		var s := SphereMesh.new()
		s.radius = BALL_R
		s.height = BALL_R*2.0
		s.radial_segments = 12
		s.rings = 6
		body.mesh = s
		body.material_override = _mat(Color(0.12,0.1,0.09),Color(1.0,0.35,0.05),1.4)
	n.add_child(body)
	var tail := MeshInstance3D.new()
	if _smoke != null:
		tail.mesh = _smoke
		tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		var box := BoxMesh.new()
		box.size = Vector3(0.7,0.7,9.0)
		tail.mesh = box
		tail.position = Vector3(0.0,0.0,5.0)
		tail.material_override = _mat(Color(0.6,0.58,0.55),Color(0.6,0.58,0.55),0.5)
	n.add_child(tail)
	return n

## Discs strung back along +z, closer where they are thin, each collapsed on its
## centre for ball_smoke.gdshader to turn to the eye.
func _smoke_mesh() -> ArrayMesh:
	var at := PackedVector3Array()
	var uv := PackedVector2Array()
	var size := PackedVector2Array()
	var index := PackedInt32Array()
	var z := BALL_R*0.7
	while z < SMOKE_LONG:
		var t := z/SMOKE_LONG
		var r := lerpf(SMOKE_THIN,SMOKE_WIDE,pow(t,0.7))
		var centre := Vector3(sin(z*0.45)*0.3*r,cos(z*0.31)*0.3*r,z)
		var first := at.size()
		for corner: Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
			at.append(centre)
			uv.append(corner)
			size.append(Vector2(r,SMOKE_OPACITY*smoothstep(0.0,0.2,t)*pow(1.0-t,1.4)+0.04*(1.0-t)))
		index.append_array([first,first+1,first+2,first,first+2,first+3])
		z += r*0.5
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = at
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = size
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.custom_aabb = AABB(Vector3(-SMOKE_WIDE*1.3,-SMOKE_WIDE*1.3,-SMOKE_WIDE),Vector3(SMOKE_WIDE*2.6,SMOKE_WIDE*2.6,SMOKE_LONG+SMOKE_WIDE*2.0))
	var mat := ShaderMaterial.new()
	mat.shader = load(SMOKE_SHADER)
	mesh.surface_set_material(0,mat)
	return mesh

## A cluster of `n` soft discs for muzzle_puff.gdshader: one core disc of radius
## `r` then the rest scattered round it (`spread` x r), tinted from `tints`,
## `opacity` at the core. `fall` thins the outer ones; 0 keeps them as bright.
func _cluster_mesh(r: float, tints: Array, opacity: float, n: int, spread: float, fall: float) -> ArrayMesh:
	var at := PackedVector3Array()
	var uv := PackedVector2Array()
	var size := PackedVector2Array()
	var col := PackedColorArray()
	var index := PackedInt32Array()
	for i in n:
		var core := i == 0
		var dir := Vector3(sin(i*2.4+1.0),cos(i*1.7)*0.8,sin(i*3.1+0.5)*0.9).normalized()
		var centre := Vector3.ZERO if core else dir*r*spread*(0.5+0.5*fmod(i*0.37,1.0))
		var rad := r if core else r*(0.55+0.35*fmod(i*0.61,1.0))
		var o := opacity*(1.0 if core else lerpf(1.0,0.55,fall)*(0.6+0.4*fmod(i*0.43,1.0)))
		var first := at.size()
		for corner: Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
			at.append(centre)
			uv.append(corner)
			size.append(Vector2(rad,o))
			col.append(tints[0] if core else tints[1+i%(tints.size()-1)])
		index.append_array([first,first+1,first+2,first,first+2,first+3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = at
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = size
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.custom_aabb = AABB(Vector3.ONE*-r*8.0,Vector3.ONE*r*16.0)
	var mat := ShaderMaterial.new()
	mat.shader = load(PUFF_SHADER)
	mesh.surface_set_material(0,mat)
	return mesh

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
		if _ball_mesh != null: ((b.node as Node3D).get_child(0) as Node3D).basis = Basis(Vector3(0.6,0.8,0.0),float(b.age)*BALL_TUMBLE)
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
	if not bool(plates.stern.open) and not bool(plates.bow.open): _carried = carries()
	_last = part
	plate.open = true
	game.arches.loose.erase(r)
	GroundNative.bump_loose()
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
		GroundNative.bump_loose()
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

# --- The sink ------------------------------------------------------------------

## True while she has the ring aboard: its row is in the table, anchored to her, not
## yet found.
func carries() -> bool:
	var finds: Node = game.get("finds")
	if finds == null: return false
	var row: Dictionary = finds.row(RELIC)
	return not row.is_empty() and str(row.get("anchor","")) == handle and not bool(finds.is_found(row))

func _all_open() -> bool:
	return bool(plates.stern.open) and bool(plates.bow.open)

## Her pose `t` s into a sink: Vector3(m down, pitch, roll in degrees).
static func sink_pose(t: float) -> Vector3:
	var n := SINK_KEYS.size()
	var i := 1
	while i < n-2 and t >= float(SINK_KEYS[i+1][0]): i += 1
	var a: Array = SINK_KEYS[i-1]
	var b: Array = SINK_KEYS[i]
	var c: Array = SINK_KEYS[i+1]
	var d: Array = SINK_KEYS[mini(i+2,n-1)]
	var k := clampf((t-float(b[0]))/(float(c[0])-float(b[0])),0.0,1.0)
	var out := Vector3.ZERO
	for j in 3: out[j] = cubic_interpolate(float(b[j+1]),float(c[j+1]),float(a[j+1]),float(d[j+1]),k)
	return out

## She's hit her last: everything stops but her going. The plane may well be in
## her, so the hull's flat record goes and her true tilt takes over.
func _sink() -> void:
	state = SINKING
	sink_t = 0.0
	sinks += 1
	_beat = 0.0
	_cue = 0
	_ghost = false
	_panned = false
	_handed_back = false
	_refilled = false
	_pay = not _carried
	_end = 1.0 if _last == "bow" else -1.0
	var l := local(game.plane.position)
	_list = -1.0 if l.x > 0.0 else 1.0
	game.arches.loose.erase(_hull)
	GroundNative.bump_loose()
	for t: Dictionary in _tells: (t.gun.flash as Node3D).visible = false
	_tells.clear()
	game.feel_hit(0.045,12.0)
	game.sound.shot("thump",1.4,0.42)
	game.sound.shot("crash",1.1,0.55)
	var finds: Node = game.get("finds")
	if finds != null:
		finds.beat.play("landing",position+Vector3.UP*20.0,0.0)
		finds.hud.found({"title":SINK_WORDS if _carried else SINK_WORDS_BARE},int(finds.got()),int(finds.of()))
	for z: float in [LONG*0.5,-LONG*0.5]:
		var at: Vector3 = transform*Vector3(0.0,8.0,z)
		var out: Vector3 = (transform.basis*Vector3(0.0,0.2,signf(z))).normalized()
		game.debris.burst("wood",at,out,true)
		game.debris.burst("dust",at,out,true)
		_mist(at)
	sinking.emit()

## The time-keyed part of a sink: the wash, the groans, the points, the end.
func _sink_step(delta: float, p: Vector3, d: float) -> void:
	if not _ghost and in_corridor(p,2.0) and (transform*Vector3(0.0,deck_mid(high),0.0)).y < float(game.water_at(position)):
		# The gun deck has flooded round the plane: it's let go, not shut in.
		_ghost = true
		_hull_body.collision_layer = 0
	if _pay and sink_t >= SINK_PAY_AT:
		_pay = false
		paid += SINK_POINTS
		game.near.prize(SINK_POINTS,SINK_LINE,position)
	while _cue < SINK_CUES.size() and sink_t >= float(SINK_CUES[_cue][0]):
		var c: Array = SINK_CUES[_cue]
		_cue += 1
		_loud(str(c[1]),float(c[2]),float(c[3]),d)
	_beat -= delta
	if _beat <= 0.0:
		_beat = SINK_BEAT
		if d < SINK_NEAR: _wash(d)
	if sink_t >= SINK_S and _under(): _gone()

## True while she'd have the eye: CoastSites `watch` picks among the ships.
func wants_eye() -> bool:
	return state == SINKING and sink_t >= WATCH_FROM and not _handed_back

## A newer sink has the eye: this one lets it be for the rest of hers, and leaves the
## camera to that one.
func give_up_eye() -> void:
	watching = false
	_handed_back = true

## The chase camera in a sink, each frame (the study's `_frame`): the free look, eased
## round so she's in frame past the plane, which flies on under its own controls. The
## player's turn of it pans on from there, and letting go hands the normal camera
## back after its linger; so does the end of the sink, her being far off, or land or
## sea coming up on the plane's way. Outside a sink it sets nothing but ZERO.
func watch(chase: RefCounted) -> void:
	var on := state == SINKING and sink_t >= WATCH_FROM and not _handed_back
	if on:
		if chase.free_held: _panned = true
		elif _panned: _handed_back = true
		if position.distance_to(game.plane.position) > WATCH_FAR or _way_shut(): _handed_back = true
		if not game.hand_landing.flying(): _handed_back = true
		on = not _handed_back
	if on:
		var v: Vector3 = game.plane.velocity
		var to: Vector3 = position-(game.plane.position as Vector3)
		var ahead := Vector3(v.x,0.0,v.z)
		if ahead.length() < 1.0: ahead = game.plane.forward()
		chase.free_to = Vector2(wrapf(ahead.signed_angle_to(Vector3(to.x,0.0,to.z),Vector3.UP)+WATCH_OFF,-PI,PI),0.0)
		chase.free_ease = WATCH_EASE
	elif watching:
		chase.free_to = Vector2.ZERO
		chase.free_ease = chase.EASE_BACK
	else:
		return
	watching = on

## True with land or sea coming up on the plane's way in the next few seconds: the
## player, looking back, has to see where it's going.
func _way_shut() -> bool:
	var p: Vector3 = game.plane.position
	var v: Vector3 = game.plane.velocity
	for s: float in WATCH_AHEAD:
		var q := p+v*s
		if q.y < maxf(float(game.field.height(q.x,q.z)),SEA_Y)+WATCH_ROOM*(0.5 if v.y >= 0.0 else 1.0) and float(game.field.height(q.x,q.z)) > SEA_Y: return true
		if v.y < -1.0 and q.y < SEA_Y+2.0: return true
	return false

## A flat shot, softer with distance: 3D shots die at 70 m and she's 130 long.
func _loud(kind: String, gain: float, pitch: float, d: float) -> void:
	game.sound.shot(kind,gain/(1.0+d/SINK_HEARD),pitch,position,&"SFX",true)

## True with every high point of her under the sea.
func _under() -> bool:
	var sea := float(game.water_at(position))
	for h: Vector3 in HIGH_POINTS:
		if (transform*h).y > sea-1.0: return false
	return true

## Where a hull side's line at `z` on `side` crosses the sea, or INF.
func _waterline(z: float, side: float) -> Vector3:
	var a: Vector3 = transform*Vector3(side*(wide*0.5+WALL),-DRAUGHT,z)
	var b: Vector3 = transform*Vector3(side*(wide*0.5+WALL),FLOOR_Y+high+DECK,z)
	var sea := float(game.water_at(a))
	if (a.y-sea)*(b.y-sea) > 0.0: return Vector3.INF
	return a.lerp(b,(sea-a.y)/(b.y-a.y))

## One wash: foam along her waterline, a burst of mist and spray, and something
## let go, strongest where she's going in fastest.
func _wash(d: float) -> void:
	var low := -_end*(LONG*0.5)
	for i in 5:
		var z := lerpf(low,-low,randf()*randf())
		var at := _waterline(z,1.0 if i%2 == 0 else -1.0)
		if at == Vector3.INF: continue
		if game.water != null: game.water.wash(at,1.0,6.0+sink_t*0.25)
		if i == 0: _mist(at)
		if i == 1: game.debris.burst("spray",at,Vector3.UP,true)
		if i == 2 and randf() < 0.5: game.debris.burst("wood",at,Vector3.UP,true)
		if i == 3: _plank(at)
	# The boil as she drives under: over where she was, wide and getting wider.
	if sink_t > 14.0:
		var sea := float(game.water_at(position))
		var r := 25.0+(sink_t-14.0)*7.0
		var at := Vector3(position.x+randf_range(-r,r),sea,position.z+randf_range(-r,r))
		_mist(at)
		_plank(at)
		if game.water != null:
			game.water.wash(at,1.0,16.0)
			if d < SINK_NEAR*0.4 and randf() < 0.3: game.water.splash(at,1.6)

## She's under: hidden and out of the world till her return.
func _gone() -> void:
	var sea := float(game.water_at(position))
	var at := Vector3(position.x,sea,position.z)
	_loud("splash",1.4,0.5,at.distance_to(game.plane.position))
	if game.water != null:
		for i in 12:
			var r := Vector3(randf_range(-1.0,1.0),0.0,randf_range(-1.0,1.0))*70.0
			game.water.wash(at+r,1.0,20.0)
	for i in 6: _mist(at+Vector3(randf_range(-45.0,45.0),0.0,randf_range(-45.0,45.0)))
	for i in 8: _plank(at+Vector3(randf_range(-55.0,55.0),0.0,randf_range(-55.0,55.0)))
	state = GONE
	sink_t = -1.0
	gone_t = 0.0
	_poll = 0.0
	visible = false
	_hull_body.collision_layer = 0
	_plane_was = Vector3.INF

## Gone: the clock, then the route tried for a spot out of sight. Only the wash on
## the water is left to step, and the balls fired before she went are long down.
func _wait(delta: float) -> void:
	gone_t += delta
	if gone_t < return_wait: return
	_poll -= delta
	if _poll > 0.0: return
	_poll = RETURN_POLL
	var s := _return_spot()
	if not is_nan(s): _come_back(s)

## The way along the route to come back at, farthest from the eye of those out of
## its sight; NAN if none is. Never within RETURN_NEAR m of the plane either, nor
## RETURN_APART m of the other ship.
func _return_spot() -> float:
	var eye: Vector3 = game.camera.global_position
	var look: Vector3 = -game.camera.global_basis.z
	var plane: Vector3 = game.plane.position
	var lap := 2.0*_leg+TAU*ROUTE_R
	var best := NAN
	var far := -1.0
	for i in RETURN_SPOTS:
		var s := along+lap*float(i)/float(RETURN_SPOTS)
		var q: Vector2 = route_pose(s,_leg)[0]
		var at: Vector3 = _route*Vector3(q.x,0.0,q.y)
		if at.distance_to(plane) < RETURN_NEAR: continue
		if twin != null and twin.state != GONE and at.distance_to(twin.position) < RETURN_APART: continue
		var d := at.distance_to(eye)
		if unseen(at,eye,look) and d > far:
			far = d
			best = s
	return best

## True if a ship at `at` is out of the eye's sight.
static func unseen(at: Vector3, eye: Vector3, look: Vector3) -> bool:
	var d := at.distance_to(eye)
	if d >= RETURN_ANY: return true
	return d >= RETURN_NEAR and look.dot((at-eye)/d) < RETURN_CONE

## A fresh ship at `s` along the route: plates whole, guns live.
func _come_back(s: float) -> void:
	state = AFLOAT
	along = s
	visible = true
	_ghost = false
	_every = EVERY
	for g: Dictionary in _guns: g.rest = 0.0
	_pose()
	_hull_body.collision_layer = game.arches.LAYER
	game.arches.loose.append(_hull)
	GroundNative.bump_loose()
	_place(_hull)
	_reseal()
	returns += 1
	returned.emit()

## SkyGlide's `ground` at `p` over `h`, in a sink: her solid at its true tilt, each
## stretch at the plane's own spot in her frame, so it's exact at the plane's height
## and a little out far above or below it.
func wreck_ground(p: Vector3, h: Variant, pad: float) -> Variant:
	if state != SINKING or _ghost or not h is float: return h
	if p.distance_squared_to(position) > WRECK_REACH*WRECK_REACH: return h
	var l := _inv*p
	var list: Array = []
	BoxSolid.stretches(_hull.solid,l.x,l.z,pad,0.0,list)
	if list.is_empty(): return h
	for i in list.size():
		var s: Vector2 = list[i]
		var a: float = (transform*Vector3(l.x,s.x,l.z)).y
		var b: float = (transform*Vector3(l.x,s.y,l.z)).y
		list[i] = Vector2(minf(a,b),maxf(a,b))
	return LandHalls.over(p,float(h),BoxSolid.joined(list))

## True in her solid, grown by `pad`, in a sink.
func wreck_inside(p: Vector3, pad: float) -> bool:
	if state != SINKING or _ghost: return false
	if p.distance_squared_to(position) > WRECK_REACH*WRECK_REACH: return false
	return BoxSolid.inside(_hull.solid,_inv*p,pad)

## Off the wreck's nearest outside, in the world, for FlightContact: her top if the
## plane is over her, else her side or end, never down (her list would throw it at
## the sea). Up for a touch of the water right beside her; ZERO away from her.
func _wreck_way_off(p: Vector3, l: Vector3, what: String) -> Vector3:
	if _ghost or p.distance_squared_to(position) > WRECK_REACH*WRECK_REACH: return Vector3.ZERO
	var beam := wide*0.5+WALL
	var end := LONG*0.5+PLATE
	if absf(l.x) > beam+10.0 or absf(l.z) > end+20.0 or l.y > 70.0 or l.y < -DRAUGHT-4.0: return Vector3.ZERO
	if what == "water": return Vector3.UP
	var off := Vector3.UP
	if l.y < FLOOR_Y+high+DECK:
		off = Vector3(signf(l.x),0.0,0.0) if beam-absf(l.x) < end-absf(l.z) else Vector3(0.0,0.0,signf(l.z))
	var way: Vector3 = transform.basis*off
	way.y = maxf(way.y,0.1)
	return way.normalized()

## A puff of white off the water at `at`.
func _mist(at: Vector3) -> void:
	var m: Dictionary = {}
	if _mists.size() < MISTS:
		var n := MeshInstance3D.new()
		n.mesh = _mist_mesh
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_wake.add_child(n)
		m = {"node":n,"t":0.0,"r":1.0}
		_mists.append(m)
	else:
		var oldest := -1.0
		for o: Dictionary in _mists:
			if float(o.t) > oldest:
				oldest = float(o.t)
				m = o
	m.t = 0.0
	m.r = randf_range(MIST_R.x,MIST_R.y)
	(m.node as Node3D).position = at
	(m.node as Node3D).visible = true

## A plank let go on the water at `at`.
func _plank(at: Vector3) -> void:
	if _planks.size() >= PLANKS: return
	var n := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(randf_range(5.0,16.0),0.7,randf_range(0.8,1.8))
	n.mesh = b
	n.material_override = _plank_mat
	_wake.add_child(n)
	n.position = at
	n.rotation.y = randf()*TAU
	_planks.append({"node":n,"t":0.0,"drift":Vector3(randf_range(-1.0,1.0),0.0,randf_range(-1.0,1.0))*1.5,"seed":randf()*TAU})

## What's on the water: the mist lifts and thins, the planks ride the swell, then
## go down. Nothing here costs anything once they're done.
func _wake_step(delta: float) -> void:
	for m: Dictionary in _mists:
		if not (m.node as Node3D).visible: continue
		m.t = float(m.t)+delta
		var k := float(m.t)/MIST_LIFE
		var n: MeshInstance3D = m.node
		if k >= 1.0:
			n.visible = false
			continue
		n.position.y += MIST_RISE*(1.0-k)*delta
		n.scale = Vector3.ONE*float(m.r)*(1.0+k*2.4)
		n.set_instance_shader_parameter("fade",(1.0-k)*smoothstep(0.0,0.08,k))
	for i in range(_planks.size()-1,-1,-1):
		var w: Dictionary = _planks[i]
		w.t = float(w.t)+delta
		var n: MeshInstance3D = w.node
		n.position += (w.drift as Vector3)*delta
		var t := float(w.t)
		var down := maxf(t-PLANK_LIFE,0.0)*PLANK_SINK
		# The swell's read for a few a frame: it's slow, and it isn't free.
		if (i+Engine.get_process_frames())%PLANK_TURNS == 0: n.position.y = SEA_Y+float(game.sea_height(n.position))-0.05-down
		n.rotation.x = 0.1*sin(t*0.9+float(w.seed))
		n.rotation.z = 0.08*sin(t*0.7+float(w.seed)*2.0)
		if down > 3.0:
			n.queue_free()
			_planks.remove_at(i)

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
	GroundNative.bump_loose()
	_hull_body = _body("Hull",all.hull)
	_wake = Node3D.new()
	_wake.name = "ShipWake"
	get_parent().add_child(_wake)
	_mist_mesh = twin._mist_mesh if twin != null else _cluster_mesh(4.0,[Color(0.96,0.97,0.98),Color(0.88,0.9,0.92),Color(0.8,0.83,0.86)],0.75,9,1.0,1.0)
	_plank_mat = twin._plank_mat if twin != null else _mat(PLANK_C)
	for part: String in ["stern","bow"]:
		var box: AABB = (all[part] as Array)[0]
		var record := _record(part,all[part])
		record["strike"] = Callable(self,"_strike")
		record["part"] = part
		game.arches.loose.push_front(record)
		GroundNative.bump_loose()
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
	_sails = ShipSails.new(_model)
	if twin != null:
		_ball_mesh = twin._ball_mesh
		_smoke = twin._smoke
		_flash_mesh = twin._flash_mesh
		_puff_mesh = twin._puff_mesh
	else:
		var ball: Node3D = (load(BALL_MODEL) as PackedScene).instantiate()
		_ball_mesh = (ball.find_child("Ball",true,false) as MeshInstance3D).mesh
		ball.free()
		_smoke = _smoke_mesh()
		_flash_mesh = _cluster_mesh(FLASH_R,[Color(1.0,0.95,0.7),Color(1.0,0.72,0.28),Color(1.0,0.5,0.1)],1.0,5,0.5,0.0)
		_puff_mesh = _cluster_mesh(PUFF_R,[Color(0.78,0.79,0.8),Color(0.68,0.69,0.7),Color(0.84,0.84,0.84)],0.55,9,1.0,1.0)
	(_model.find_child("Rigging",true,false) as GeometryInstance3D).visibility_range_end = RIGGING_FAR
	for part: String in ["Interior","Cannons"]: (_model.find_child(part,true,false) as GeometryInstance3D).visibility_range_end = INNER_FAR
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
		(shard as GeometryInstance3D).visibility_range_end = INNER_FAR
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
	return {"name":handle+"/"+part,"kind":"ship","node":self,"pos":position,"cos":cos(yaw),"sin":sin(yaw),
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
	var smoke := MeshInstance3D.new()
	if _flash_mesh != null:
		flash.mesh = _flash_mesh
		smoke.mesh = _puff_mesh
		for m: GeometryInstance3D in [flash,smoke]: m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		var b := BoxMesh.new()
		b.size = Vector3(2.2,2.2,2.2)
		flash.mesh = b
		flash.material_override = _mat(Color(1.0,0.8,0.3),Color(1.0,0.7,0.2),5.0)
		var sb := BoxMesh.new()
		sb.size = Vector3(4.0,4.0,4.0)
		smoke.mesh = sb
		smoke.material_override = _mat(Color(0.8,0.8,0.78),Color(0.5,0.5,0.48),0.4)
	flash.position = at
	flash.visible = false
	add_child(flash)
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
