extends RefCounted
## A challenged rival's flying (scripts/endless/rival_race.gd): one traffic
## plane (scripts/endless/endless_traffic.gd) taken off its shy cruise and
## flown low and fast through the land's openings, one after another.
##
## The line (`_plan`, every SEARCH_EVERY s while it has none): the nearest
## threadable opening ahead, within REACH m and CONE of its heading and
## faced roughly its way (ALIGN): an arch's opening (LandArches `standing`,
## the opening read off its solid columns, `_arch_opening`), a split
## mountain's slot (LandField `splits_in`, split_sites.gd's centre line), a
## slot hall's nave (`halls_in`) or a tunnel's bore (`tunnels_in`). The route
## is a polyline: from where it is, to a lead-in APPROACH m before the
## opening, through it on its centre line, and EXIT m out. It is flown by
## pursuit: the aim LOOK_TIME s of speed ahead along the line, swung across
## by the wobble (never past the opening's room), the heading turned toward
## it at a capped rate and late by LATE s. In an opening the height is the
## line's; on the way in and in the open it reads the ground ahead (trees'
## crowns too, and in the open the arches' spans) and keeps LOW m over it.
## With no opening in reach it flies low down the valleys ahead (`_leg`),
## never far off its course.
##
## Ducking: some threads (DUCK, rolled from the seed and the opening's
## name) it lines up for and then, DUCK_AT s short, goes over or round.
##
## Skill (`skill`, --rival-skill=X): WOBBLE and LATE shrink with it, DUCK
## falls, what it gives up of CARRY and TURN_BLEED shrinks, and PACE (times the player's Boost, rival_race.gd) rises by
## PACE_PER_SKILL a step.
##
## Never into the player: within SAFE_R m it is pushed off (the traffic's
## `_keep_off`), and when its line would pass within MISS_R m of him in the
## next MISS_LOOK s it steers off, up or aside.
##
## `history` keeps what it did: each opening threaded or ducked, with when and
## where, for drivers and the handoff.

const WorldScale = preload("res://scripts/world_scale.gd")
const SplitSites = preload("res://scripts/endless/split_sites.gd")
const Build = preload("res://scripts/endless/arch_build.gd")
const PlaneGroundScale = preload("res://scripts/plane_ground_scale.gd")

## The skill knobs at skill 1 ("good, not expert").
## How far its line swings across (m, each way) and how late its heading
## follows the aim (s).
const WOBBLE := 3.0
const LATE := 0.22
## The chance it ducks a thread and goes over or round.
const DUCK := 0.25
## The speed it carries through an opening (share of its pace): it lifts
## off from CARRY_FROM m short of the opening's middle and is back on
## the pace CARRY_BACK m past it; and the share of its speed a full-rate
## turn bleeds.
const CARRY := 0.84
const CARRY_FROM := 200.0
const CARRY_BACK := 60.0
const TURN_BLEED := 0.08
## How much faster a step of skill flies it (share of its pace).
const PACE_PER_SKILL := 0.06

## Its flying: the most it turns (rad/s), radians a second per radian off
## the aim, bank per radian a second of turn and the most it banks; the
## most it climbs or dives (rad), metres off its height per radian, how
## quickly its pitch and speed follow (s).
const TURN_MAX := 1.35
const TURN_GAIN := 2.6
const BANK := 0.85
const BANK_MAX := 1.05
const PITCH_MAX := 0.55
const PITCH_PER := 14.0
const EASE_PITCH := 0.22
const EASE_SPEED := 1.4
## Low and fast: the height it keeps over the ground (m, trees' crowns
## and in the open the arches' spans counted), the least over the ground
## right under it (m), the ground read ahead (m) and to each side (m), and
## how much less is asked per metre further out.
const LOW := 13.0
const LOW_LEAST := 4.0
const READ := [0.0,20.0,45.0,75.0,110.0,150.0,200.0]
const READ_SIDE := 9.0
const CLIMB_SLOPE := 0.14
const FLOOR_EVERY := 0.1
## On the way in it keeps low over the land till this far (m) from the
## lead-in's end, then settles onto the opening's height.
const LEAD_SETTLE := 260.0
## In an opening only the ground this near ahead is read (m).
const READ_IN := 8.0
## An arch is flown only along a way whose ground stays under its
## opening's height (less LOW_LEAST) at these distances (m) before (-)
## and after its middle.
const LEVEL_AT := [-70.0,-45.0,-25.0,25.0,45.0]

## The wobble fades out toward an opening: none within WOBBLE_NEAR m of
## its middle, all of it from WOBBLE_FAR m.
const WOBBLE_NEAR := 40.0
const WOBBLE_FAR := 220.0
## The route: an opening looked for every SEARCH_EVERY s, from NEAR to
## REACH m off, within CONE of its heading, its way within ALIGN (cos) of
## the heading; the lead-in before it and the run out after it (m); the
## pursuit's look ahead (s of speed, at least LOOK_LEAST m).
const SEARCH_EVERY := 1.2
const NEAR := 160.0
const REACH := 1100.0
const CONE := 0.95
const ALIGN := 0.45
const APPROACH := 120.0
const EXIT := 80.0
const LOOK_TIME := 0.5
const LOOK_LEAST := 18.0
## A duck: decided this many s of speed short of the opening; round a
## ridge it veers this far (rad) for VEER_TIME s.
const DUCK_AT := 2.0
const DUCK_TURN := 0.75
const VEER_TIME := 4.0

## An opening is threadable with this much room (m, at plane scale 1:
## wingspans), across and under the span.
const NEED_WIDE := 2.6
const NEED_GAP := 3.0
## Its height in an opening: this share of the gap over the floor.
const GAP_SHARE := 0.42
## Heights over the floor (m) through a split mountain's slot, a hall's
## nave (under its roof, if lower) and a tunnel's bore; the slot's centre
## line sampled every SPLIT_STEP m.
const SPLIT_FLY := 9.0
const HALL_FLY := 6.0
const TUNNEL_FLY := 7.0
const SPLIT_STEP := 30.0
## A hall's nave read every HALL_PROBE m along its middle; what
## stands within HALL_STEP m of the floor (or of what stands on it) is
## stood on, not flown under; re-read every HALL_EVERY s within
## HALL_NEAR m (it is built near the eye, a piece at a time).
const HALL_PROBE := 3.0
const HALL_STEP := 1.5
const HALL_NEAR := 450.0
const HALL_EVERY := 0.4

## The valleys in the open: a point LEG m ahead, within LEG_SPREAD (rad)
## of its course, the lowest of CANDIDATES; reached within LEG_ARRIVE m.
const LEG := Vector2(420.0,700.0)
const LEG_SPREAD := 0.5
const CANDIDATES := 5
const LEG_ARRIVE := 160.0

## The player: pushed off within SAFE_R wingspans; steered off when its
## line passes within MISS_R wingspans in MISS_LOOK s.
const SAFE_SPANS := 3.0
const MISS_SPANS := 7.0
const MISS_LOOK := 1.5

## The waggle (accepting, and at the end): seconds, rate (Hz), bank (rad).
const WAGGLE_TIME := 1.5
const WAGGLE_HZ := 1.5
const WAGGLE_BANK := 0.6
## The peel off at the end: the turn away (rad) and its seconds.
const PEEL_TURN := 1.1
## The marks (`intent`): the trail's point spacing (m), the share of the
## asked length it shows down an open valley, the gate's share of the
## opening's room and its most half width (m).
const TRAIL_STEP := 6.0
const OPEN_TRAIL := 0.6
const GATE_FILL := 0.8
const GATE_MOST := 40.0
## A split's gate stands this far in from its foot (m), past the mouth's
## flare (split_sites.gd TYPES), or at its middle when shorter.
const SPLIT_GATE_IN := 110.0
const PEEL_TIME := 3.0

var game: Node
var plane: Dictionary
var skill := 1.0
## The speed it's asked to carry (m/s; rival_race.gd sets it each frame).
var pace := 0.0
## How quickly its speed follows the pace (s; rival_race.gd quickens it
## for the jump off the line).
var speed_ease := EASE_SPEED
## What it did: [{t, id, kind, what ("threaded", "ducked", "missed"), at}].
var history: Array = []
## The route ([{p, room, bore}]) and the opening it is for ({} none).
var route: Array = []
var feature: Dictionary = {}
var waggle := 0.0
var peel := 0.0
var _peel_side := 1.0
var _clock := 0.0
var _search := 0.0
var _s := 0.0
var _lens := PackedFloat32Array()
var _used := {}
var _openings := {}
var _turn := 0.0
var _floor := 0.0
var _floor_at := -1.0
var _veer := 0.0
var _veer_left := 0.0
var _course := 0.0
var _leg := Vector3.INF
var _rng := RandomNumberGenerator.new()
var _salt := 0
## Frames it spent inside something solid (the land, an arch, a hall, a
## tree), for checks; visual only, nothing stops it.
var clips := 0
var clip_log: Array = []
var _to_through := INF
## Metres to the opening's middle along the route (< 0: past it; INF: none).
var _to_go := INF

## `race_salt`: the race's own number, so each race rolls its own ducks
## and legs from the seed.
func _init(host: Node, traffic_plane: Dictionary, rival_skill: float, seed: int, race_salt: int) -> void:
	game = host
	plane = traffic_plane
	skill = maxf(rival_skill,0.05)
	_salt = hash([seed,race_salt,"rival"])
	_rng.seed = _salt
	var flight: RefCounted = plane.flight
	_course = float(flight.heading)

static func safe_r() -> float:
	return WorldScale.span*SAFE_SPANS

func wobble() -> float:
	return WOBBLE/skill

func late() -> float:
	return LATE/skill

func duck_chance() -> float:
	return clampf(DUCK/skill,0.0,1.0)

## The share of its pace it keeps through an opening.
func carry() -> float:
	return 1.0-(1.0-CARRY)/skill

func pace_scale() -> float:
	return 1.0+PACE_PER_SKILL*(skill-1.0)

## The waggle: starts now (accepting the challenge, or at the end).
func start_waggle() -> void:
	waggle = WAGGLE_TIME

## The end: a waggle, then a turn away from the player.
func start_peel(player: Vector3) -> void:
	start_waggle()
	peel = PEEL_TIME
	var flight: RefCounted = plane.flight
	var right := Vector3(cos(float(flight.heading)),0.0,-sin(float(flight.heading)))
	_peel_side = -1.0 if (player-flight.position).dot(right) > 0.0 else 1.0
	route.clear()
	feature = {}

## One frame of the rival's flying (the traffic's step calls it in place
## of its `_fly`).
func fly(traffic: Node, delta: float) -> void:
	_clock += delta
	var flight: RefCounted = plane.flight
	var pos: Vector3 = flight.position
	var dir := Vector3(-sin(float(flight.heading)),0.0,-cos(float(flight.heading)))
	if peel <= 0.0 and route.is_empty():
		_search -= delta
		if _search <= 0.0:
			_search = SEARCH_EVERY
			_plan(pos,dir)
	var aim := Vector3.ZERO
	var want_y := 0.0
	var room := INF
	var bore := false
	var in_open := true
	if not route.is_empty():
		var r := _pursue(pos,float(flight.speed))
		if not route.is_empty():
			aim = r.aim
			room = float(r.room)
			bore = bool(r.bore)
			in_open = bool(r.lead)
			want_y = float(r.y)
			if in_open:
				# Low over the land on the way in, onto the line's height
				# over its last LEAD_SETTLE m.
				var low := _ground_ahead(pos,dir,false,float(r.left))
				want_y = maxf(lerpf(low,want_y,1.0-smoothstep(LEAD_SETTLE*0.25,LEAD_SETTLE,float(r.left))),_ground_near(pos,dir)+LOW_LEAST)
			else: want_y = maxf(want_y,_ground_near(pos,dir)+LOW_LEAST) if not bore else want_y
	if route.is_empty():
		_to_through = INF
		_to_go = INF
		aim = _open_aim(pos,dir)
		want_y = _ground_ahead(pos,dir,true,INF)
	# The wobble: a slow swing across the line, inside the room.
	var t := _clock*TAU+float(plane.phase)
	var swing := (sin(t*0.21)+0.5*sin(t*0.57+1.3))/1.5*wobble()*smoothstep(WOBBLE_NEAR,WOBBLE_FAR,_to_through)
	if room < INF: swing = clampf(swing,-maxf(room-WorldScale.span*1.2,0.0),maxf(room-WorldScale.span*1.2,0.0))
	var to := aim-pos
	var flat := Vector3(to.x,0.0,to.z)
	if flat.length() > 0.5:
		var across := flat.normalized().cross(Vector3.UP)
		aim += across*swing
	aim = _keep_clear(traffic,aim,pos,float(flight.speed))
	to = aim-pos
	var want := atan2(-to.x,-to.z)
	if peel > 0.0:
		peel -= delta
		want = float(flight.heading)+_peel_side*PEEL_TURN*0.5
		want_y = maxf(want_y,_ground_ahead(pos,dir,true,INF)+10.0)
	elif _veer_left > 0.0:
		_veer_left -= delta
		want += _veer
	var rate := clampf(angle_difference(float(flight.heading),want)*TURN_GAIN,-TURN_MAX,TURN_MAX)
	_turn = lerpf(_turn,rate,_ease(late(),delta))
	flight.heading = wrapf(float(flight.heading)+_turn*delta,-PI,PI)
	var bank := clampf(-_turn*BANK,-BANK_MAX,BANK_MAX)
	if waggle > 0.0:
		waggle -= delta
		var w := sin((WAGGLE_TIME-waggle)*TAU*WAGGLE_HZ)*WAGGLE_BANK*smoothstep(0.0,0.3,waggle)
		bank = clampf(bank+w,-BANK_MAX,BANK_MAX)
	flight.bank = lerpf(float(flight.bank),bank,_ease(0.15,delta))
	var pitch := clampf((want_y-pos.y)/PITCH_PER,-PITCH_MAX,PITCH_MAX)
	flight.pitch = lerpf(float(flight.pitch),pitch,_ease(EASE_PITCH,delta))
	flight.spin = 0.0
	var speed := pace if pace > 0.0 else float(plane.cruise)
	# Lifting off for an opening, and the turn's bleed.
	if peel <= 0.0:
		var near := 1.0-smoothstep(0.0,CARRY_FROM,_to_go) if _to_go >= 0.0 else 1.0-smoothstep(0.0,CARRY_BACK,-_to_go)
		speed *= lerpf(1.0,carry(),near)
		speed *= 1.0-TURN_BLEED/skill*clampf(absf(_turn)/TURN_MAX,0.0,1.0)
	flight.speed = lerpf(float(flight.speed),speed,_ease(speed_ease,delta))
	flight.velocity = flight.forward()*float(flight.speed)
	flight.position += flight.velocity*delta
	# Never sunk into the ground under it (in a bore, the bore's floor is
	# the line's own).
	if not bore:
		var under := _ground_top(flight.position,in_open and route.is_empty())
		flight.position.y = maxf(flight.position.y,under+LOW_LEAST*0.5)
	var inside := _in_solid(flight.position,bore)
	if inside != "":
		clips += 1
		if clip_log.size() < 12: clip_log.append({"what":inside,"at":flight.position.round(),"route":String(feature.get("id","open")),"t":snappedf(_clock,0.1)})
	var mist := float(traffic.cloud_depth.call(flight.position)) if traffic.cloud_depth.is_valid() else 0.0
	plane.figure.update(delta,flight,0.0,Callable(),false,mist,float(flight.bank))
	PlaneGroundScale.grow(plane.figure,traffic._size)

static func _ease(seconds: float, delta: float) -> float:
	return 1.0-exp(-delta/maxf(seconds,0.001))

# --- The ground ---------------------------------------------------------------------

## What solid `p` is in ("land", "arch", "hall", "tree"), or "".
func _in_solid(p: Vector3, bore: bool) -> String:
	if not bore and p.y < float(game.field.height(p.x,p.z)): return "land"
	if game.arches.inside(p): return "arch"
	if game.halls.inside(p): return "hall"
	if game.trees.inside(p): return "tree"
	return ""

## The top of what stands at `p`'s XZ: the land (or the sea), raised by a
## tree's crown, and with `spans` an arch's or hall's top too.
func _ground_top(p: Vector3, spans: bool) -> float:
	var h := maxf(float(game.field.height(p.x,p.z)),-40.0)
	if spans:
		var g: Variant = game.plane_ground(Vector3(p.x,h+400.0,p.z))
		if g is Vector2: return maxf(h,(g as Vector2).x)
		if g != null: return maxf(h,float(g))
		return h
	if game.trees != null:
		var t: Variant = game.trees.ground(Vector3(p.x,h+400.0,p.z),h)
		if not t is Vector2 and t != null: h = maxf(h,float(t))
	return h

## The lowest it may fly in the open: LOW over the ground ahead (and to
## each side), asking less the further out, read every FLOOR_EVERY s and
## no further than `most` m.
func _ground_ahead(pos: Vector3, dir: Vector3, spans: bool, most: float) -> float:
	if _clock-_floor_at < FLOOR_EVERY: return _floor
	_floor_at = _clock
	var side := dir.cross(Vector3.UP)
	var lowest := -INF
	for d: float in READ:
		if d > most and d > 0.0: break
		for k: float in [-1.0,0.0,1.0]:
			var p := pos+dir*d+side*READ_SIDE*k
			lowest = maxf(lowest,_ground_top(p,spans)+LOW-d*CLIMB_SLOPE)
	_floor = lowest
	return lowest

## In an opening: the ground right ahead (READ_IN m), no spans.
func _ground_near(pos: Vector3, dir: Vector3) -> float:
	return maxf(_ground_top(pos,false),_ground_top(pos+dir*READ_IN,false))

# --- The route ----------------------------------------------------------------------

## Looks for the nearest opening ahead and lays the route through it.
func _plan(pos: Vector3, dir: Vector3) -> void:
	var best: Dictionary = {}
	var best_score := INF
	for c: Dictionary in _candidates(pos):
		if _used.has(c.id): continue
		var pts: Array = c.points
		var entry: Vector3 = pts[0].p
		var to := Vector3(entry.x-pos.x,0.0,entry.z-pos.z)
		var d := to.length()
		if d < NEAR or d > REACH: continue
		var off := absf(Vector2(dir.x,dir.z).angle_to(Vector2(to.x,to.z)))
		if off > CONE: continue
		var nxt: Vector3 = pts[1].p
		var way := Vector3(nxt.x-entry.x,0.0,nxt.z-entry.z).normalized()
		if way.dot(dir) < ALIGN: continue
		var score := d*(1.0+off/CONE)
		if score < best_score:
			best_score = score
			best = c
	if best.is_empty(): return
	feature = best
	feature["duck"] = _roll(String(best.id)) < duck_chance()
	feature["decided"] = false
	route = [{"p":pos,"room":INF,"bore":false,"lead":true}]
	route.append_array(best.points)
	_lens = PackedFloat32Array([0.0])
	for i in range(1,route.size()):
		var a: Vector3 = route[i-1].p
		var b: Vector3 = route[i].p
		_lens.append(_lens[i-1]+Vector2(b.x-a.x,b.z-a.z).length())
	feature["s_through"] = _lens[int(best.through)+1]
	_s = 0.0

## A roll in [0, 1) from the seed, the race and `id`.
func _roll(id: String) -> float:
	return float(hash([_salt,id])%100000)/100000.0

## Where it is on the route and where it aims: {aim, y, room, bore, lead
## (still on the lead-in), left (m of lead-in left)}. Ends the route past
## its last point; logs the opening threaded as it passes it, or drops the
## route when it ducks.
func _pursue(pos: Vector3, speed: float) -> Dictionary:
	# Project onto the polyline, near where it was.
	var best_s := _s
	var best_d := INF
	for i in range(route.size()-1):
		if _lens[i+1] < _s-40.0: continue
		var a: Vector3 = route[i].p
		var b: Vector3 = route[i+1].p
		var ab := Vector2(b.x-a.x,b.z-a.z)
		var l2 := ab.length_squared()
		var u := clampf(Vector2(pos.x-a.x,pos.z-a.z).dot(ab)/l2,0.0,1.0) if l2 > 0.0001 else 0.0
		var q := Vector2(a.x,a.z)+ab*u
		var d := q.distance_to(Vector2(pos.x,pos.z))
		if d < best_d:
			best_d = d
			best_s = _lens[i]+u*(_lens[i+1]-_lens[i])
	_s = maxf(_s,best_s)
	var through := float(feature.s_through)
	# A hall is built near the eye, a piece at a time: its height read
	# again every HALL_EVERY s from HALL_NEAR m out till it is through,
	# never lower than read before.
	if String(feature.kind) == "hall" and through-_s < HALL_NEAR and through-_s > 0.0 and _clock-float(feature.get("read_at",-INF)) > HALL_EVERY:
		feature.read_at = _clock
		var h: Array = feature.hall
		var fly := _hall_fly(h[0],h[1],h[2])
		if fly > float(feature.get("fly",-1.0)):
			feature.fly = fly
			var pts := _hall_points(h[0],h[1],h[2],h[3],fly)
			for i in range(pts.size()): route[i+1].p = pts[i].p
	_to_through = absf(through-_s)
	_to_go = through-_s
	# The duck, decided once, DUCK_AT s short of the opening.
	if not bool(feature.decided) and _s > through-speed*DUCK_AT-APPROACH*0.5:
		feature.decided = true
		if bool(feature.duck):
			_note("ducked")
			if String(feature.kind) != "arch":
				_veer = DUCK_TURN*(-1.0 if _roll(String(feature.id)+"side") < 0.5 else 1.0)
				_veer_left = VEER_TIME
			_end_route()
			return {}
	if not feature.has("passed") and _s >= through:
		feature["passed"] = true
		var flight: RefCounted = plane.flight
		var c: Vector3 = _at(through).p
		var off := Vector2(flight.position.x-c.x,flight.position.z-c.z).length()
		_note("threaded" if off < _room_at(through)+WorldScale.span else "missed",{"off":snappedf(off,0.1),"room":snappedf(_room_at(through),0.1),"dy":snappedf(float(flight.position.y)-c.y,0.1)})
	if _s >= _lens[_lens.size()-1]-1.0:
		_end_route()
		_search = 0.0
		return {}
	var look := maxf(speed*LOOK_TIME,LOOK_LEAST)
	var here := _at(_s)
	var ahead := _at(minf(_s+look,_lens[_lens.size()-1]))
	var lead := _s < _lens[1]
	# The height: the line's, a little ahead of where it is.
	var y := float(_at(minf(_s+look*0.4,_lens[_lens.size()-1])).y)
	return {"aim":ahead.p,"y":y,"room":minf(float(here.room),float(ahead.room)),"bore":bool(here.bore),"lead":lead,"left":_lens[1]-_s}

func _room_at(s: float) -> float:
	return float(_at(s).room)

## The route's point at `s` along: {p, y, room, bore}.
func _at(s: float) -> Dictionary:
	for i in range(route.size()-1):
		if s <= _lens[i+1] or i == route.size()-2:
			var span := maxf(_lens[i+1]-_lens[i],0.001)
			var u := clampf((s-_lens[i])/span,0.0,1.0)
			var a: Dictionary = route[i]
			var b: Dictionary = route[i+1]
			var p: Vector3 = (a.p as Vector3).lerp(b.p,u)
			# The lead-in's room is the opening's, from where it begins.
			return {"p":p,"y":p.y,"room":float(b.room) if i == 0 else minf(float(a.room),float(b.room)),"bore":bool(a.bore) and bool(b.bore)}
	var last: Dictionary = route[route.size()-1]
	return {"p":last.p,"y":(last.p as Vector3).y,"room":float(last.room),"bore":bool(last.bore)}

func _end_route() -> void:
	if not feature.is_empty(): _used[feature.id] = true
	route.clear()
	feature = {}

func _note(what: String, more := {}) -> void:
	var flight: RefCounted = plane.flight
	var h := {"t":snappedf(_clock,0.01),"id":String(feature.id),"kind":String(feature.kind),"what":what,"at":flight.position.round()}
	h.merge(more)
	history.append(h)

## In the open: down the valleys ahead, near its course.
func _open_aim(pos: Vector3, dir: Vector3) -> Vector3:
	if _leg == Vector3.INF or Vector2(_leg.x-pos.x,_leg.z-pos.z).length() < LEG_ARRIVE or Vector3(_leg.x-pos.x,0.0,_leg.z-pos.z).dot(dir) < 0.0:
		_course = lerp_angle(_course,atan2(-dir.x,-dir.z),0.3)
		var low := INF
		for i in range(CANDIDATES):
			var a := _course+_rng.randf_range(-LEG_SPREAD,LEG_SPREAD)
			var p := pos+Vector3(-sin(a),0.0,-cos(a))*_rng.randf_range(LEG.x,LEG.y)
			var h := maxf(float(game.field.height(p.x,p.z)),-40.0)
			if h < low:
				low = h
				_leg = Vector3(p.x,h,p.z)
	return _leg

## Off the player: when its line would pass within MISS_R of him in the
## next MISS_LOOK s, the aim moves off (up or aside).
func _keep_clear(traffic: Node, aim: Vector3, pos: Vector3, speed: float) -> Vector3:
	var player: Vector3 = traffic._player
	var off := pos-player
	var reach := WorldScale.span*MISS_SPANS
	if off.length() > reach+speed*MISS_LOOK*2.0: return aim
	var flight: RefCounted = plane.flight
	var rel: Vector3 = flight.velocity-traffic._player_fwd*float(traffic._player_speed)
	var closest := off
	if rel.length_squared() > 0.01:
		var t := clampf(-off.dot(rel)/rel.length_squared(),0.0,MISS_LOOK)
		closest = off+rel*t
	var miss := closest.length()
	if miss >= reach: return aim
	var away := closest/maxf(miss,0.01) if miss > 0.5 else Vector3.UP
	return aim+away.normalized()*(reach-miss)*3.0

# --- Its intent, for the race's marks ---------------------------------------------------

## Where it is going, for the marks (scripts/endless/rival_marks.gd): {trail
## (points every TRAIL_STEP m along where it will fly, from where it is, up
## to `ahead` m on), open (true: down a valley, no opening), gate ({} or the
## opening's mouth: {p, dir, half_w, half_h, kind, left (m to it)})}; {} while
## it peels off.
func intent(ahead: float) -> Dictionary:
	if peel > 0.0: return {}
	var flight: RefCounted = plane.flight
	var pos: Vector3 = flight.position
	var trail := PackedVector3Array()
	if route.is_empty() or _lens.size() < 2:
		if _leg == Vector3.INF: return {}
		var to := Vector3(_leg.x-pos.x,0.0,_leg.z-pos.z)
		var most := minf(to.length(),ahead*OPEN_TRAIL)
		var way := to.normalized()
		var d := 0.0
		while d <= most:
			var q := pos+way*d
			q.y = maxf(lerpf(pos.y,_ground_top(q,true)+LOW,smoothstep(0.0,120.0,d)),_ground_top(q,true)+LOW_LEAST)
			trail.append(q)
			d += TRAIL_STEP
		return {"trail":trail,"open":true,"gate":{}}
	var end := _lens[_lens.size()-1]
	var s := _s
	while s <= minf(_s+ahead,end):
		var q: Vector3 = _at(s).p
		# On the lead-in it flies low over the land, not the straight line.
		if s < _lens[1]: q.y = maxf(q.y,_ground_top(q,false)+LOW_LEAST*2.0)
		trail.append(q)
		s += TRAIL_STEP
	var gate := {}
	var m := int(feature.get("mouth",-1))+1
	if m >= 1 and m < route.size() and _s < _lens[m]:
		var a: Vector3 = route[maxi(m-1,0)].p
		var b: Vector3 = route[mini(m+1,route.size()-1)].p
		var dir := Vector3(b.x-a.x,0.0,b.z-a.z).normalized()
		var room := float(route[m].room)
		var half_w := clampf(room*GATE_FILL if room < INF else WorldScale.span*3.0,WorldScale.span*1.2,GATE_MOST)
		gate = {"p":route[m].p,"dir":dir,"half_w":half_w,"half_h":clampf(half_w*0.6,WorldScale.span*0.9,GATE_MOST*0.6),"kind":String(feature.kind),"left":_lens[m]-_s}
	return {"trail":trail,"open":false,"gate":gate}

# --- The openings -------------------------------------------------------------------

## Every opening near `pos`, each both ways: {id, kind, points: [{p, room,
## bore}], through (the index of the point in the opening's middle), mouth
## (the index of the point where it goes in)}.
func _candidates(pos: Vector3) -> Array:
	var out: Array = []
	var r := REACH+200.0
	var field: RefCounted = game.field
	if game.arches != null:
		for a: Dictionary in game.arches.standing():
			var at: Vector3 = a.pos
			if Vector2(at.x-pos.x,at.z-pos.z).length() > r: continue
			var o := _arch_opening(a)
			if o.is_empty(): continue
			var z := Vector3(float(a.sin),0.0,float(a.cos))
			var c: Vector3 = o.centre
			for sgn: float in [1.0,-1.0]:
				var w := z*sgn
				if not _level_way(c,w): continue
				var pts: Array = [_pt(c-w*APPROACH,o.room,false),_pt(c-w*20.0,o.room,false),_pt(c,o.room,false),_pt(c+w*EXIT,INF,false)]
				out.append({"id":String(a.name),"kind":"arch","points":pts,"through":2,"mouth":2})
	for s: PackedFloat32Array in field.splits_in(pos.x-r,pos.z-r,pos.x+r,pos.z+r):
		var id := "split/%d_%d" % [roundi(s[0]),roundi(s[1])]
		var hl := s[4]
		var room := s[5]
		for sgn: float in [1.0,-1.0]:
			var pts: Array = []
			var u := -hl-APPROACH
			var through := 0
			var mouth := -1
			while u <= hl+EXIT+0.1:
				var p := SplitSites.point(s,u*sgn)
				var inside := absf(u) <= hl
				p.y += SPLIT_FLY
				if not inside: p.y = maxf(p.y,float(field.height(p.x,p.z))+SPLIT_FLY)
				if absf(u) < SPLIT_STEP*0.5: through = pts.size()
				# The gate goes where the walls have closed in, past the flare.
				if absf(u) <= maxf(hl-SPLIT_GATE_IN,SPLIT_STEP*0.5) and mouth < 0: mouth = pts.size()
				pts.append(_pt(p,room if absf(u) <= hl+20.0 else INF,false))
				u += SPLIT_STEP
			out.append({"id":id,"kind":"split","points":pts,"through":through,"mouth":maxi(mouth,0)})
	if float(field.halls) > 0.0:
		for s: PackedFloat32Array in field.halls_in(pos.x-r,pos.z-r,pos.x+r,pos.z+r):
			var id := "hall/%d_%d" % [roundi(s[0]),roundi(s[1])]
			var way := Vector3(s[2],0.0,s[3])
			var c := Vector3(s[0],s[6],s[1])
			var fly := _hall_fly(c,way,s[4])
			for sgn: float in [1.0,-1.0]:
				var w := way*sgn
				out.append({"id":id,"kind":"hall","points":_hall_points(c,w,s[4],s[5],fly),"through":2,"mouth":1,"hall":[c,w,s[4],s[5]],"fly":fly})
	if float(field.tunnels) > 0.0:
		for t: RefCounted in field.tunnels_in(pos.x-r,pos.z-r,pos.x+r,pos.z+r):
			var id := "tunnel/"+String(t.name)
			var path: PackedVector2Array = t.pts
			if path.size() < 2: continue
			var fy: float = float(t.floor_y)+TUNNEL_FLY
			var room: float = WorldScale.span*NEED_WIDE*1.5
			for sgn: float in [1.0,-1.0]:
				var pts: Array = []
				var a2: Vector2 = t.origin if sgn > 0.0 else t.mouth_b
				var in_way: Vector2 = t.way if sgn > 0.0 else -(t.out_b as Vector2)
				var out_way: Vector2 = t.out_b if sgn > 0.0 else -(t.way as Vector2)
				var b2: Vector2 = t.mouth_b if sgn > 0.0 else t.origin
				var lead := a2-in_way*APPROACH
				pts.append(_pt(Vector3(lead.x,fy,lead.y),room,false))
				var n := path.size()
				var step := maxi(1,n/24)
				var i := 0
				while i < n:
					var q := path[i] if sgn > 0.0 else path[n-1-i]
					pts.append(_pt(Vector3(q.x,fy,q.y),room,true))
					i += step
				var tail := b2+out_way*EXIT
				pts.append(_pt(Vector3(tail.x,fy,tail.y),INF,false))
				out.append({"id":id,"kind":"tunnel","points":pts,"through":pts.size()/2,"mouth":1})
	return out

## Whether the way `w` through an opening at `c` is level enough: the
## ground along it (LEVEL_AT) under the opening's height.
func _level_way(c: Vector3, w: Vector3) -> bool:
	for d: float in LEVEL_AT:
		if _ground_top(c+w*d,false)+LOW_LEAST > c.y: return false
	return true

static func _pt(p: Vector3, room: float, bore: bool) -> Dictionary:
	return {"p":p,"room":room,"bore":bore,"lead":false}

## A hall's route: the lead-in, its ends, its middle and the run out, at
## `fly` m over its floor (HALL_FLY while it is not built yet).
func _hall_points(c: Vector3, w: Vector3, half: float, room: float, fly: float) -> Array:
	var over := fly if fly >= 0.0 else HALL_FLY
	var pts: Array = []
	for k: float in [-half-APPROACH,-half,0.0,half,half+EXIT]:
		var p := c+w*k
		p.y = c.y+over
		if absf(k) > half: p.y = maxf(p.y,float(game.field.height(p.x,p.z))+over)
		pts.append(_pt(p,room if absf(k) <= half else INF,false))
	return pts

## A hall's flying height over its floor (m), read off what stands in its
## nave (LandHalls `stretches`, built only near the eye): over the highest
## thing on the floor (rubble, a step), GAP_SHARE of the way up to the
## lowest roof; -1 while the hall is not built.
func _hall_fly(c: Vector3, way: Vector3, half: float) -> float:
	if game.halls == null: return -1.0
	var top := c.y
	var roof := INF
	var seen := false
	var n := ceili(half/HALL_PROBE)
	for k in range(-n,n+1):
		var p := c+way*half*float(k)/n
		var ground := c.y
		for st: Vector2 in game.halls.stretches(Vector3(p.x,c.y+1.0,p.z)):
			seen = true
			if st.x <= ground+HALL_STEP: ground = maxf(ground,st.y)
			else:
				roof = minf(roof,st.x)
				break
		top = maxf(top,ground)
	if not seen: return -1.0
	if roof == INF: return top-c.y+HALL_FLY
	return top-c.y+clampf((roof-top)*GAP_SHARE,WorldScale.span,HALL_FLY*2.0)

## An arch's widest opening (its solid's columns, LandArches `stretches`,
## read across its span at three depths): {centre (world, at its flying
## height), room (half its width, m)}, or {} if none is wide and tall
## enough.
func _arch_opening(a: Dictionary) -> Dictionary:
	var name := String(a.name)
	if _openings.has(name): return _openings[name]
	var o: Vector3 = a.pos
	var x := Vector3(float(a.cos),0.0,-float(a.sin))
	var z := Vector3(float(a.sin),0.0,float(a.cos))
	var spec: Dictionary = a.spec
	var depth := float(spec.get("depth",6.0))
	var need_gap := WorldScale.span*NEED_GAP
	var need_wide := WorldScale.span*NEED_WIDE
	var runs: Array = []
	var run := []
	var x0 := float(a.x0)
	var n := int(a.n)
	for j in range(n+1):
		var ok := false
		var gap := INF
		var floor_y := -INF
		if j < n:
			var lx := x0+(j+0.5)*Build.BIN
			ok = true
			for lz: float in [-depth*0.35,0.0,depth*0.35]:
				var p := o+x*lx+z*lz
				var h := maxf(float(game.field.height(p.x,p.z)),-40.0)
				var list: Array = game.arches.stretches(Vector3(p.x,h+need_gap*0.5,p.z))
				if list.is_empty():
					ok = false
					break
				var under := INF
				for s: Vector2 in list:
					if s.y > h+0.6:
						under = s.x
						break
				if under-h < need_gap:
					ok = false
					break
				gap = minf(gap,under-h)
				floor_y = maxf(floor_y,h)
		if ok: run.append([x0+(j+0.5)*Build.BIN,gap,floor_y])
		elif not run.is_empty():
			runs.append(run)
			run = []
	var best: Dictionary = {}
	var best_score := -INF
	for r: Array in runs:
		var wide := float(r.size())*Build.BIN
		if wide < need_wide: continue
		# The middle third's least gap and highest floor.
		var gap := INF
		var fl := -INF
		for k in range(r.size()/3,maxi(r.size()*2/3,r.size()/3+1)):
			gap = minf(gap,float(r[k][1]))
			fl = maxf(fl,float(r[k][2]))
		var mid := (float(r[0][0])+float(r[r.size()-1][0]))*0.5
		var score := minf(wide,gap)
		if score > best_score:
			best_score = score
			var y := fl+clampf(gap*GAP_SHARE,WorldScale.span,gap-WorldScale.span*1.5)
			best = {"centre":Vector3(o.x,0.0,o.z)+x*mid+Vector3.UP*y,"room":wide*0.5}
	_openings[name] = best
	return best
