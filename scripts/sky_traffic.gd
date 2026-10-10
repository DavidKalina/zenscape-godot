extends Node
## Other planes in the sky (scripts/sky_islands.gd): a few little biplanes
## like the wanderer's own (scripts/plane_figure.gd), each in its own
## livery, flown by pilots enjoying themselves, so the sky is lived in
## before anyone has been helped.
##
## Each pilot always has somewhere to go (`_choose`): a lap or two round an
## island, a pass straight through a cloud, a low buzz over an islet. It
## steers there the way the wanderer's plane flies: the heading turns at a
## limited rate and the wings bank with the turn, the nose pitches toward
## the height it wants. On top of that the line wanders (two slow sines on
## the heading and the height), and now and then it shows off (`_trick`):
## a barrel roll, a loop, a swoop down and back up. Ahead of it the ground
## (SkyIslands `ground`: islands, islets, peaks) is read, and it climbs to
## keep CLEAR metres over it; no trick starts close to the ground.
##
## Islands are known by their slots in the currents' frame (the plate's
## first home at the origin); when the currents move (a claim's swap) the
## planes move with them, scarves too. No collisions and no landing:
## ambience only. Shown only while flying (SkyIslands `show_air`);
## --no-traffic leaves the sky empty.

const PlaneFigure = preload("res://scripts/plane_figure.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")

## Planes in the sky.
const COUNT := 4
## Cruise speed (m/s), lowest and highest, under the jets' 26; how much a
## swoop's dive adds; how quickly speed follows (seconds).
const SPEED := Vector2(12.0,16.0)
const SWOOP_SPEED := 7.0
const EASE_SPEED := 1.5
## Turning: radians a second at most, per radian of heading off the aim,
## how quickly the turn rate follows (seconds), bank per radian a second of
## turn, and the most it banks.
const TURN_MAX := 0.75
const TURN_GAIN := 1.4
const EASE_TURN := 0.5
const BANK := 1.3
const BANK_MAX := 0.95
## Pitch: the most it climbs or dives (radians), metres of height off the
## aim per radian, how quickly it follows (seconds).
const PITCH_MAX := 0.42
const PITCH_PER := 30.0
const EASE_PITCH := 0.6
## The wandering line: heading (radians) and height (m) swings, and their
## two rates (cycles a second).
const WANDER_TURN := 0.4
const WANDER_HEIGHT := 5.0
const WANDER_RATE := Vector2(0.045,0.11)
## Island laps: radius past the island's middle (m), height over its slot
## (m), laps; the aim leads round the circle by LEAD radians.
const LAP_RADIUS := Vector2(42.0,70.0)
const LAP_HEIGHT := Vector2(14.0,34.0)
const LAPS := Vector2(0.8,2.0)
const LEAD := 0.45
## Clouds and islets are looked for within REACH metres; reached within
## ARRIVE metres (a cloud is flown on through, PAST metres beyond); an
## islet is buzzed this high over its ground.
const REACH := 450.0
const ARRIVE := 18.0
const PAST := 60.0
const BUZZ := 9.0
## No cloud or islet is chosen further than this past the outermost
## island's middle, so the pilots stay among the islands.
const ROAM := 150.0
## Kinds of goal and how often each is chosen.
const GOALS := [["lap",0.45],["cloud",0.3],["islet",0.25]]
## Tricks: seconds between them, lowest and highest; a barrel roll's,
## a loop's and a swoop's seconds; a swoop's drop (m); the clearance a
## trick needs (m).
const TRICK_EVERY := Vector2(9.0,26.0)
const ROLL_TIME := 1.2
const LOOP_TIME := 3.4
const SWOOP_TIME := 6.0
const SWOOP_DROP := 22.0
const TRICK_CLEAR := 28.0
const TRICKS := [["roll",0.5],["loop",0.25],["swoop",0.25]]
## The ground read ahead (m), the height kept over it (m).
const AHEAD := [0.0,20.0,40.0,65.0]
const CLEAR := 14.0
## The liveries, muted to sit with the land: never the wanderer's own
## brown, cream and terracotta.
const LIVERIES := [
	{"body":Color("5f7f96"),"dark":Color("3e4f5c"),"trim":Color("e8d9a8"),"wing":Color("eef0ea"),"scarf":Color("e2b84a")},
	{"body":Color("6f8a5b"),"dark":Color("44543a"),"trim":Color("d98e4a"),"wing":Color("f0ead8"),"scarf":Color("cf6b4a")},
	{"body":Color("c9a24a"),"dark":Color("6d5530"),"trim":Color("8a4f3a"),"wing":Color("f3ecd9"),"scarf":Color("6f8fa8")},
	{"body":Color("8a5f78"),"dark":Color("4f3746"),"trim":Color("e6c48f"),"wing":Color("efe8e0"),"scarf":Color("7fa08a")},
]

## What a PlaneFigure reads of a glide (scripts/sky_glide.gd, sky_plane.gd).
class Flight extends RefCounted:
	var position := Vector3.ZERO
	var velocity := Vector3.ZERO
	var heading := 0.0
	var pitch := 0.0
	var bank := 0.0
	var spin := 0.0
	var speed := 0.0
	var engine := 1.0
	func forward() -> Vector3:
		return Vector3(-sin(heading)*cos(pitch),sin(pitch),-cos(heading)*cos(pitch))

## The height under a global point, or null over open air (SkyIslands
## `ground`); unset, nothing is climbed over.
var ground := Callable()
## The middle of the cloud nearest a global point within a reach, global,
## or null (SkyIslands `cloud_near`); unset, no cloud is flown through.
var cloud_near := Callable()
## How deep a global point is in cloud, 0 to 1 (SkyIslands `in_cloud`),
## for the vapour off the wingtips.
var cloud_depth := Callable()
## Each plane: {figure, flight, cruise, turn (rad/s), goal, trick, next
## (seconds to the next trick), phase, rng}.
var planes := []
## The islands' slots, in the currents' frame, their middle and how far
## out the farthest is (flat).
var _slots := []
var _middle := Vector3.ZERO
var _spread := 0.0
var _currents: Node3D
var _origin := Vector3.ZERO
var _shown := false
var _clock := 0.0

static func enabled() -> bool:
	return not "--no-traffic" in preload("res://scripts/launch_args.gd").user_args()

## Puts COUNT planes in the sky, each starting a lap round its own island
## of `slots` (the currents' frame); hidden till `show`.
func build(currents: Node3D, slots: Array) -> void:
	name = "SkyTraffic"
	clear()
	_currents = currents
	_slots = slots.duplicate()
	_middle = Vector3.ZERO
	for slot: Vector3 in _slots: _middle += slot
	_middle /= float(_slots.size())
	_spread = 0.0
	for slot: Vector3 in _slots: _spread = maxf(_spread,Vector2(slot.x-_middle.x,slot.z-_middle.z).length())
	_origin = _frame()
	for n in range(COUNT):
		var rng := RandomNumberGenerator.new()
		rng.seed = 7151+n*97
		var figure := PlaneFigure.new(LIVERIES[n%LIVERIES.size()])
		figure.name = "Traffic%d" % n
		figure.visible = _shown
		add_child(figure)
		var plane := {"figure":figure,"flight":Flight.new(),"rng":rng,
			"cruise":rng.randf_range(SPEED.x,SPEED.y),"turn":0.0,"trick":{},
			"next":rng.randf_range(TRICK_EVERY.x,TRICK_EVERY.y),"phase":rng.randf()*TAU}
		plane.goal = _lap(plane,(n*2+1)%_slots.size())
		var goal: Dictionary = plane.goal
		var flight: Flight = plane.flight
		var a: float = rng.randf()*TAU
		flight.position = _origin+goal.centre+Vector3(cos(a),0.0,sin(a))*float(goal.radius)+Vector3.UP*float(goal.height)
		# Facing along the lap.
		var along := Vector3(-sin(a),0.0,cos(a))*float(goal.turn)
		flight.heading = atan2(-along.x,-along.z)
		flight.speed = plane.cruise
		flight.velocity = flight.forward()*flight.speed
		planes.append(plane)
		figure.update(0.0,flight,0.0,Callable(),false)
		figure.reset(flight)

func clear() -> void:
	for plane: Dictionary in planes: plane.figure.queue_free()
	planes.clear()

## Shows or hides every plane (while flying, or not).
func show(on: bool) -> void:
	_shown = on
	for plane: Dictionary in planes: plane.figure.visible = on

func _process(delta: float) -> void:
	if not _shown or planes.is_empty() or _currents == null: return
	# The currents moved (a claim's swap): the planes, scarves too, go with.
	var origin := _frame()
	if origin != _origin:
		var by := origin-_origin
		_origin = origin
		for plane: Dictionary in planes:
			plane.flight.position += by
			plane.figure.shift(by)
			if plane.goal.has("point"): plane.goal.point += by
	if delta <= 0.0: return
	_clock += delta
	for plane: Dictionary in planes: _fly(plane,delta)

## Where the currents' frame stands, global.
func _frame() -> Vector3:
	return _currents.global_position if _currents.is_inside_tree() else _currents.position

# --- Flying -----------------------------------------------------------------------

## One step of a plane: its goal, its aim, its trick, and the figure drawn.
func _fly(plane: Dictionary, delta: float) -> void:
	var flight: Flight = plane.flight
	if _done(plane): plane.goal = _choose(plane)
	var aim := _aim(plane)
	var t := _clock*TAU+float(plane.phase)
	var floor_y := _floor(plane)
	var want_y := maxf(aim.y+sin(t*WANDER_RATE.y+1.3)*WANDER_HEIGHT,floor_y)
	var trick: Dictionary = plane.trick
	var pace := float(plane.cruise)
	if trick.is_empty():
		plane.next = float(plane.next)-delta
		if float(plane.next) <= 0.0 and flight.position.y-floor_y+CLEAR > TRICK_CLEAR:
			plane.trick = _trick(plane)
			trick = plane.trick
	if not trick.is_empty():
		trick.t = float(trick.t)+delta
	var looping: bool = not trick.is_empty() and trick.kind == "loop"
	if not trick.is_empty() and trick.kind == "swoop":
		var s := clampf(float(trick.t)/SWOOP_TIME,0.0,1.0)
		var dip := sin(s*PI)
		want_y = maxf(want_y-SWOOP_DROP*dip,floor_y)
		pace += SWOOP_SPEED*dip
	if not looping:
		# The heading turns toward the aim, wandering, at a limited rate.
		var to := aim-flight.position
		var wander := sin(t*WANDER_RATE.x)*WANDER_TURN+sin(t*WANDER_RATE.x*2.7+0.8)*WANDER_TURN*0.4
		var want := atan2(-to.x,-to.z)+wander
		var rate := clampf(angle_difference(flight.heading,want)*TURN_GAIN,-TURN_MAX,TURN_MAX)
		plane.turn = lerpf(float(plane.turn),rate,_ease(EASE_TURN,delta))
		flight.heading = wrapf(flight.heading+float(plane.turn)*delta,-PI,PI)
		flight.bank = clampf(-float(plane.turn)*BANK,-BANK_MAX,BANK_MAX)
		var pitch := clampf((want_y-flight.position.y)/PITCH_PER,-PITCH_MAX,PITCH_MAX)
		flight.pitch = lerpf(flight.pitch,pitch,_ease(EASE_PITCH,delta))
	else:
		# Round the loop: the nose comes up and over, the wings level.
		var s := clampf(float(trick.t)/LOOP_TIME,0.0,1.0)
		flight.pitch = float(trick.from)+TAU*_smooth(s)
		flight.bank = lerpf(flight.bank,0.0,_ease(0.2,delta))
		plane.turn = 0.0
	if not trick.is_empty() and trick.kind == "roll":
		flight.spin = TAU*_smooth(clampf(float(trick.t)/ROLL_TIME,0.0,1.0))
	if not trick.is_empty() and float(trick.t) >= float(trick.length):
		if trick.kind == "loop": flight.pitch = wrapf(flight.pitch,-PI,PI)
		flight.spin = 0.0
		plane.trick = {}
		plane.next = plane.rng.randf_range(TRICK_EVERY.x,TRICK_EVERY.y)
	flight.speed = lerpf(flight.speed,pace,_ease(EASE_SPEED,delta))
	flight.velocity = flight.forward()*flight.speed
	flight.position += flight.velocity*delta
	# Never sunk into the ground it is over.
	flight.position.y = maxf(flight.position.y,floor_y-CLEAR*0.5)
	var mist := float(cloud_depth.call(flight.position)) if cloud_depth.is_valid() else 0.0
	plane.figure.update(delta,flight,0.0,Callable(),false,mist,flight.bank)

## Where the plane steers for now (global): its goal's point, or round its
## island, leading along the lap.
func _aim(plane: Dictionary) -> Vector3:
	var goal: Dictionary = plane.goal
	if goal.kind != "lap": return goal.point
	var centre: Vector3 = _origin+goal.centre
	var at: Vector3 = plane.flight.position-centre
	var a := atan2(at.z,at.x)+LEAD*float(goal.turn)
	return centre+Vector3(cos(a),0.0,sin(a))*float(goal.radius)+Vector3.UP*float(goal.height)

## The lowest it may fly here: CLEAR over the highest ground ahead, or
## -INF over open air.
func _floor(plane: Dictionary) -> float:
	if not ground.is_valid(): return -INF
	var flight: Flight = plane.flight
	var ahead := Vector3(-sin(flight.heading),0.0,-cos(flight.heading))
	var lowest := -INF
	for d: float in AHEAD:
		var under: Variant = ground.call(flight.position+ahead*d)
		if under != null: lowest = maxf(lowest,float(under)+CLEAR)
	return lowest

## Whether the plane's goal is met: its laps flown, or its point reached
## (or passed).
func _done(plane: Dictionary) -> bool:
	var goal: Dictionary = plane.goal
	if goal.kind == "lap":
		var at: Vector3 = plane.flight.position-_origin-goal.centre
		var a := atan2(at.z,at.x)
		if goal.has("last"): goal.swept = float(goal.swept)+absf(angle_difference(float(goal.last),a))
		goal.last = a
		return float(goal.swept) >= float(goal.laps)*TAU
	var gap: Vector3 = goal.point-plane.flight.position
	return gap.length() < ARRIVE or (gap.length() < PAST and gap.dot(plane.flight.forward()) < 0.0)

## A new goal: weighted among the kinds, falling back to a lap when no
## cloud or islet is in reach.
func _choose(plane: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = plane.rng
	var kind := _pick(GOALS,rng)
	var at: Vector3 = plane.flight.position
	if kind == "cloud" and cloud_near.is_valid():
		var cloud: Variant = cloud_near.call(at+plane.flight.forward()*REACH*0.4,REACH)
		if cloud != null and _within(cloud-_origin):
			var c: Vector3 = cloud
			# Through its heart and on out the far side.
			var through := Vector3(c.x-at.x,0.0,c.z-at.z).normalized()
			return {"kind":"cloud","point":c+through*PAST}
	if kind == "islet":
		var islet: Variant = _islet_near(at-_origin,rng)
		if islet != null and _within(islet):
			var p: Vector3 = _origin+(islet as Vector3)
			var under: Variant = ground.call(p) if ground.is_valid() else null
			p.y = (float(under) if under != null else p.y)+BUZZ
			return {"kind":"islet","point":p}
	# A lap round one of the three islands nearest, not the one just left.
	var here := at-_origin
	var order := range(_slots.size())
	order.sort_custom(func(a: int, b: int) -> bool: return (_slots[a] as Vector3).distance_to(here) < (_slots[b] as Vector3).distance_to(here))
	if order.size() > 1: order.erase(int(plane.goal.get("island",-1)))
	return _lap(plane,order[rng.randi_range(0,mini(2,order.size()-1))])

## Whether a point in the currents' frame is among the islands.
func _within(at: Vector3) -> bool:
	return Vector2(at.x-_middle.x,at.z-_middle.z).length() < _spread+ROAM

func _lap(plane: Dictionary, island: int) -> Dictionary:
	var rng: RandomNumberGenerator = plane.rng
	return {"kind":"lap","island":island,"centre":_slots[island],
		"radius":rng.randf_range(LAP_RADIUS.x,LAP_RADIUS.y),
		"height":rng.randf_range(LAP_HEIGHT.x,LAP_HEIGHT.y),
		"laps":rng.randf_range(LAPS.x,LAPS.y),"swept":0.0,
		"turn":1.0 if rng.randf() < 0.5 else -1.0}

## An islet within REACH of a point in the currents' frame, at random, or null.
static func _islet_near(at: Vector3, rng: RandomNumberGenerator) -> Variant:
	var cell := Vector2i(floori(at.x/SkyIslets.CELL),floori(at.z/SkyIslets.CELL))
	var found := []
	var span := ceili(REACH/SkyIslets.CELL)
	for dx in range(-span,span+1):
		for dz in range(-span,span+1):
			var home: Variant = SkyIslets.raw(cell+Vector2i(dx,dz))
			if home == null: continue
			var d := (home as Vector3).distance_to(at)
			if d < REACH and d > ARRIVE*3.0: found.append(home)
	return found[rng.randi_range(0,found.size()-1)] if not found.is_empty() else null

## A trick to show off with.
func _trick(plane: Dictionary) -> Dictionary:
	var kind := _pick(TRICKS,plane.rng)
	var length: float = {"roll":ROLL_TIME,"loop":LOOP_TIME,"swoop":SWOOP_TIME}[kind]
	return {"kind":kind,"t":0.0,"length":length,"from":plane.flight.pitch}

static func _pick(weighted: Array, rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	for entry: Array in weighted:
		roll -= float(entry[1])
		if roll <= 0.0: return entry[0]
	return weighted[0][0]

static func _smooth(s: float) -> float:
	return s*s*(3.0-2.0*s)

static func _ease(seconds: float, delta: float) -> float:
	return 1.0-exp(-delta/seconds)
