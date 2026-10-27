extends RefCounted
## A challenged rival's flying (scripts/endless/rival_race.gd): one traffic
## plane (scripts/endless/endless_traffic.gd) taken off its shy cruise. It
## lands on a flat to start the race (rival_strip.gd), stands, takes off at
## GO and flies the race's course (rival_course.gd) gate to gate, low and
## fast.
##
## Its modes (`mode`):
## - "air": no strip yet; on down the valleys ahead (`_open_aim`), looking
##   for one every STRIP_EVERY s.
## - "land": to its strip and down. It flies to the start of the final
##   approach on pursuit, at LAND_SPEED, and down the strip's glide
##   (RivalStrip `glide_y`, the same the approach was checked clear under);
##   RAIL m short of the touch it is on rails: onto the strip's line, its
##   speed easing to TOUCH_SPEED, the flare (the glide's last FLARE m) easing
##   its sink to nothing and lifting its nose to sit on its wheels; then it
##   rolls out to a stop on its lane, ROLL m on (RivalStrip ROLL).
## - "rest": stood on its wheels, the engine at IDLE, no smoke.
## - "takeoff": from rest at GO: TAKEOFF_ACCEL down the lane, its tail up
##   from TAIL_UP m/s, off at LIFT_SPEED, climbing CLIMB_RATE till CLIMB_DONE
##   m up, then the course (or, after a race that never began, the peel).
## - "course": the fixed course flown by pursuit (`_follow`): the aim
##   LOOK_TIME s of speed ahead along it, swung across by the wobble (never
##   past the opening's room), the heading turned toward it at a capped rate
##   and late by LATE s; its height the course's line (the ribbon), never
##   under LOW_LEAST over what stands just ahead. A gate it went by outside
##   (pushed off, say) it comes round to (`come_round`): out to the side, back
##   past it and in again.
## - "peel": the end; a waggle, a turn away from the player, climbing.
##
## Checked gates (DUCK, rolled from the seed and the gate's name): it lifts
## off harder for them (CHECK of its carry), so it loses time, not the gate.
##
## Skill (`skill`, --rival-skill=X): WOBBLE and LATE shrink with it, DUCK
## falls, what it gives up of CARRY and TURN_BLEED shrinks, and PACE (times
## the player's Boost, rival_race.gd) rises by PACE_PER_SKILL a step.
##
## Never into the player: in the air within SAFE_SPANS wingspans it is
## pushed off (the traffic's `_keep_off`), and when its line would close to
## within MISS_SPANS of him in the next MISS_LOOK s it steers off, up or
## aside. On the ground and on the way down and up again neither: his lane
## is beside it.
##
## `history` keeps what it did (the race notes each gate threaded or gone
## by); `clips` counts the frames it spent inside something solid.

const WorldScale = preload("res://scripts/world_scale.gd")
const SplitSites = preload("res://scripts/endless/split_sites.gd")
const Build = preload("res://scripts/endless/arch_build.gd")
const PlaneGroundScale = preload("res://scripts/plane_ground_scale.gd")
const RivalStrip = preload("res://scripts/endless/rival_strip.gd")
const RivalCourse = preload("res://scripts/endless/rival_course.gd")
const PlaneStrip = preload("res://scripts/plane_strip.gd")

## The skill knobs at skill 1 ("good, not expert").
## How far its line swings across (m, each way) and how late its heading
## follows the aim (s).
const WOBBLE := 3.0
const LATE := 0.22
## The chance it checks a gate (lifts off harder for it), and how much of
## its carry it keeps then.
const DUCK := 0.25
const CHECK := 0.85
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
## quickly its pitch and speed follow (s), and the most it gains a second
## (m/s²).
const TURN_MAX := 1.35
const TURN_GAIN := 2.6
const BANK := 0.85
const BANK_MAX := 1.05
const PITCH_MAX := 0.55
const PITCH_PER := 14.0
const EASE_PITCH := 0.22
const EASE_SPEED := 1.4
const ACCEL_MOST := 7.0
## Low and fast: the height it keeps over the ground (m, trees' crowns
## and in the open the arches' spans counted), the least over the ground
## just ahead (m), the ground read ahead (m) and to each side (m), and
## how much less is asked per metre further out.
const LOW := 13.0
const LOW_LEAST := 4.0
const READ := [0.0,20.0,45.0,75.0,110.0,150.0,200.0]
const READ_SIDE := 9.0
const CLIMB_SLOPE := 0.14
const FLOOR_EVERY := 0.1
## The least over what stands is read this far ahead on the course (m).
const GUARD := [0.0,15.0,35.0,60.0]
## A leg settles onto the next opening's height over its last this many m.
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
## An opening's candidates are gathered within REACH m (and a margin); the
## lead-in before an opening and the run out after it (m); the pursuit's
## look ahead (s of speed, at least LOOK_LEAST m).
const REACH := 1100.0
const APPROACH := 120.0
const EXIT := 80.0
const LOOK_TIME := 0.5
const LOOK_LEAST := 18.0

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
## A split's gate stands this far in from its foot (m), past the mouth's
## flare (split_sites.gd TYPES), or at its middle when shorter.
const SPLIT_GATE_IN := 110.0
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

## The player: pushed off within SAFE_SPANS wingspans; steered off when its
## line closes within MISS_SPANS wingspans in MISS_LOOK s, at CLOSING m/s
## or more (flying alongside it lets be).
const SAFE_SPANS := 3.0
const MISS_SPANS := 7.0
const MISS_LOOK := 1.5
const CLOSING := 3.0

## The waggle (accepting, and at the end): seconds, rate (Hz), bank (rad).
const WAGGLE_TIME := 1.5
const WAGGLE_HZ := 1.5
const WAGGLE_BANK := 0.6
## The peel off at the end: the turn away (rad) and its seconds.
const PEEL_TURN := 1.1
const PEEL_TIME := 3.0

## Landing: a strip looked for every STRIP_EVERY s while it has none,
## STRIP_BUDGET spots tried a frame; its
## speed to the final approach and down it (m/s), at the touch (m/s), the
## rails' length before the touch (m) and how quickly it settles onto the
## lane's line on them (s); its nose over the glide's slope on the
## approach (rad); the strip checked again for what has been built since,
## within RECHECK m of the touch.
const STRIP_EVERY := 1.0
const STRIP_BUDGET := 40
const LAND_SPEED := 44.0
const APPROACH_SPEED := 23.0
const TOUCH_SPEED := 13.0
const RAIL := 90.0
const RAIL_EASE := 0.7
const NOSE_UP := 0.06
const RECHECK := 380.0
## A go-round: when on the rails it is more than this far off the lane's
## line (m) or turned off it (rad), it climbs away and comes in again.
const RAIL_SIDE := 25.0
const RAIL_TURN := 0.6
## Stood: the engine's idle (0..1).
const IDLE := 0.3
## The takeoff: its push (m/s²), its tail up from TAIL_UP m/s, off at
## LIFT_SPEED m/s; its climb (m up a metre; steeper, to CLIMB_MOST, where
## what stands ahead asks it), its nose then (rad), and the height it hands
## over to the course at (m).
const TAKEOFF_ACCEL := 6.0
const TAIL_UP := 6.0
const TAIL_PITCH := 0.03
const LIFT_SPEED := 14.0
const CLIMB_RATE := 0.16
const CLIMB_MOST := 0.5
const CLIMB_PITCH := 0.2
const CLIMB_DONE := 7.0
## Coming round to a gate it went by: out this far to the side (m) and
## back this far before it (m).
const ROUND_SIDE := 170.0
const ROUND_BACK := 380.0

var game: Node
var plane: Dictionary
var skill := 1.0
## The speed it's asked to carry (m/s; rival_race.gd sets it while racing).
var pace := 0.0
var speed_ease := EASE_SPEED
## "air", "land", "rest", "takeoff", "course" or "peel" (the header).
var mode := "air"
## Its strip (rival_strip.gd) and the race's course (rival_course.gd), {}
## none yet.
var strip: Dictionary = {}
var course: Dictionary = {}
## The gate it is to go through next (the race keeps it, by its crossings).
var gate_next := 0
## What it did: [{t, id, kind, what, at, ...}].
var history: Array = []
var waggle := 0.0
var peel := 0.0
## The landing's stage: "to" (to the final), "rail", "roll"; the rails'
## sideways and height offsets eased out; the touch's speed.
var land_stage := "to"
var _rail_side := 0.0
var _rail_dy := 0.0
var _touch_speed := 0.0
var _rechecked := false
var _strip_search := 0.0
var _strip_queue: Array = []
var _strip_passes := 0
var _strip_qi := 0
## After the takeoff: "course" or "peel".
var _after := "course"
var _airborne := 0.0
var _climb := CLIMB_RATE
var _peel_side := 1.0
var _clock := 0.0
## Along the course (m), and the detour ({pts, lens, s, rejoin}) when
## coming round.
var _s := 0.0
var _detour: Dictionary = {}
var _openings := {}
var _turn := 0.0
var _floor := 0.0
var _floor_at := -1.0
var _course_h := 0.0
var _leg := Vector3.INF
var _rng := RandomNumberGenerator.new()
var _salt := 0
## Frames it spent inside something solid (the land, an arch, a hall, a
## tree), for checks; visual only, nothing stops it.
var clips := 0
var clip_log: Array = []
## The lowest it stood over the land under its wheels on the ground (m,
## for checks: its wheels' contact over the ground).
var ground_gap := INF
var _to_through := INF
## Metres to the next opening's middle along the course (< 0: past it).
var _to_go := INF

## `race_salt`: the race's own number, so each race rolls its own checks
## and legs from the seed.
func _init(host: Node, traffic_plane: Dictionary, rival_skill: float, seed: int, race_salt: int) -> void:
	game = host
	plane = traffic_plane
	skill = maxf(rival_skill,0.05)
	_salt = hash([seed,race_salt,"rival"])
	_rng.seed = _salt
	var flight: RefCounted = plane.flight
	_course_h = float(flight.heading)

static func safe_r() -> float:
	return WorldScale.span*SAFE_SPANS

## The keep-off's reach now: none on the ground and on the way down or up.
func keep_r() -> float:
	return safe_r() if mode in ["air","course","peel"] else 0.0

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

## True while its wheels are on the ground.
func on_ground() -> bool:
	return mode == "rest" or (mode == "land" and land_stage == "roll") or (mode == "takeoff" and _airborne <= 0.0)

## Whether it lays smoke: not on the ground nor on the rails down to it.
func smoking() -> bool:
	return not on_ground() and not (mode == "land" and land_stage == "rail")

## The waggle: starts now (accepting the challenge, or at the end).
func start_waggle() -> void:
	waggle = WAGGLE_TIME

## To its strip and down (`s` rival_strip.gd's).
func land_on(s: Dictionary) -> void:
	strip = s
	mode = "land"
	land_stage = "to"
	_rechecked = false

## The course laid; stood, it waits for `go`.
func set_course(c: Dictionary) -> void:
	course = c
	_s = 0.0
	gate_next = 0
	_detour = {}
	var gates: Array = c.gates
	for g: Dictionary in gates: g.checked = _roll(String(g.id)) < duck_chance()

## GO: off the ground and onto the course.
func go() -> void:
	if mode != "rest": return
	mode = "takeoff"
	_after = "course"
	_airborne = 0.0
	_climb = _climb_needed()

## The climb off the strip: CLIMB_RATE, or steeper (at most CLIMB_MOST)
## where what stands ahead now (built since the strip was picked) asks it.
func _climb_needed() -> float:
	var flight: RefCounted = plane.flight
	var heading := float(flight.heading)
	var fwd := Vector3(-sin(heading),0.0,-cos(heading))
	var y0 := float(flight.position.y)
	var lift := LIFT_SPEED*LIFT_SPEED/(2.0*TAKEOFF_ACCEL)
	var rate := CLIMB_RATE
	var side := fwd.cross(Vector3.UP)*WorldScale.span*0.6
	var d := lift+4.0
	while d <= RivalStrip.CLIMB_OUT:
		for k: float in [-1.0,0.0,1.0]:
			var top := _ground_top(Vector3(flight.position)+fwd*d+side*k,false)+RivalStrip.CLEAR
			rate = maxf(rate,(top-y0)/(d-lift))
		d += 4.0
	return minf(rate,CLIMB_MOST)

## The end: a waggle, then a turn away from the player (off the ground
## first if it stands).
func start_peel(player: Vector3) -> void:
	start_waggle()
	var flight: RefCounted = plane.flight
	var right := Vector3(cos(float(flight.heading)),0.0,-sin(float(flight.heading)))
	_peel_side = -1.0 if (player-flight.position).dot(right) > 0.0 else 1.0
	_detour = {}
	if on_ground():
		mode = "takeoff"
		_after = "peel"
		_airborne = 0.0
		_climb = _climb_needed()
		return
	mode = "peel"
	peel = PEEL_TIME

## Whether the peel is done (it may be released to the traffic).
func peeled() -> bool:
	return mode == "peel" and peel <= 0.0

## One frame of the rival's flying (the traffic's step calls it in place
## of its `_fly`).
func fly(traffic: Node, delta: float) -> void:
	_clock += delta
	var flight: RefCounted = plane.flight
	if mode == "land" and land_stage != "to": _land_rails(delta)
	elif mode == "rest": _rest()
	elif mode == "takeoff": _takeoff(delta)
	else: _air(traffic,delta)
	var bank := float(flight.bank)
	if waggle > 0.0:
		waggle -= delta
		var w := sin((WAGGLE_TIME-waggle)*TAU*WAGGLE_HZ)*WAGGLE_BANK*smoothstep(0.0,0.3,waggle)
		if on_ground(): w *= 0.25
		bank = clampf(bank+w,-BANK_MAX,BANK_MAX)
	var bore := not course.is_empty() and mode == "course" and _bore_here()
	var inside := _in_solid(flight.position,bore)
	if inside != "":
		clips += 1
		if clip_log.size() < 12: clip_log.append({"what":inside,"at":flight.position.round(),"mode":mode,"stage":land_stage,"t":snappedf(_clock,0.1)})
	if on_ground():
		var under := float(game.field.height(flight.position.x,flight.position.z))
		ground_gap = minf(ground_gap,float(flight.position.y)-PlaneStrip.contact(float(flight.pitch))-under)
	var mist := float(traffic.cloud_depth.call(flight.position)) if traffic.cloud_depth.is_valid() else 0.0
	plane.figure.update(delta,flight,0.0,Callable(),false,mist,bank)
	PlaneGroundScale.grow(plane.figure,traffic._size)

static func _ease(seconds: float, delta: float) -> float:
	return 1.0-exp(-delta/maxf(seconds,0.001))

# --- In the air ---------------------------------------------------------------------

## The air's flying: on the course, to the strip's final, or down the
## valleys; peeling off.
func _air(traffic: Node, delta: float) -> void:
	var flight: RefCounted = plane.flight
	var pos: Vector3 = flight.position
	var dir := Vector3(-sin(float(flight.heading)),0.0,-cos(float(flight.heading)))
	var aim := Vector3.ZERO
	var want_y := 0.0
	var room := INF
	var bore := false
	var speed := pace if pace > 0.0 else float(plane.cruise)
	_to_through = INF
	_to_go = INF
	var keep := true
	if mode == "air" and strip.is_empty():
		# A few spots a frame (RivalStrip `order`, `try`); none, again in a
		# while from where it is then.
		_strip_search -= delta
		if _strip_queue.is_empty() and _strip_search <= 0.0:
			# Ahead first; nothing there, out to the sides too.
			_strip_queue = RivalStrip.order(pos,dir,_strip_passes > 0)
			_strip_passes += 1
			_strip_qi = 0
		var budget := STRIP_BUDGET
		while budget > 0 and _strip_qi < _strip_queue.size():
			budget -= 1
			var s := RivalStrip.try(self,_strip_queue[_strip_qi],pos,dir)
			_strip_qi += 1
			if not s.is_empty():
				s.tried = _strip_qi
				_strip_queue = []
				land_on(s)
				break
		if not _strip_queue.is_empty() and _strip_qi >= _strip_queue.size():
			_strip_queue = []
			_strip_search = STRIP_EVERY
	if mode == "land":
		var r := _to_strip(pos,dir)
		aim = r.aim
		want_y = float(r.y)
		speed = float(r.speed)
		keep = false
		if mode == "land" and land_stage == "rail": return
	elif mode == "course" and not _detour.is_empty():
		var r := _follow(_detour.pts,_detour.lens,float(_detour.s),pos,float(flight.speed))
		_detour.s = r.s
		aim = r.aim
		want_y = _ground_ahead(pos,dir,true,INF)
		if float(r.s) >= (_detour.lens as PackedFloat32Array)[(_detour.lens as PackedFloat32Array).size()-1]-LOOK_LEAST:
			_s = float(_detour.rejoin)
			_detour = {}
	elif mode == "course":
		var r := _on_course(pos,dir,float(flight.speed))
		aim = r.aim
		want_y = float(r.y)
		room = float(r.room)
		bore = bool(r.bore)
	else:
		aim = _open_aim(pos,dir)
		want_y = _ground_ahead(pos,dir,true,INF)
	# The wobble: a slow swing across the line, inside the room.
	var t := _clock*TAU+float(plane.phase)
	var swing := (sin(t*0.21)+0.5*sin(t*0.57+1.3))/1.5*wobble()*smoothstep(WOBBLE_NEAR,WOBBLE_FAR,_to_through)
	if mode == "land": swing = 0.0
	if room < INF: swing = clampf(swing,-maxf(room-WorldScale.span*1.2,0.0),maxf(room-WorldScale.span*1.2,0.0))
	var to := aim-pos
	var flat := Vector3(to.x,0.0,to.z)
	if flat.length() > 0.5:
		var across := flat.normalized().cross(Vector3.UP)
		aim += across*swing
	if keep: aim = _keep_clear(traffic,aim,pos,float(flight.speed))
	to = aim-pos
	var want := atan2(-to.x,-to.z)
	if mode == "peel":
		peel -= delta
		want = float(flight.heading)+_peel_side*PEEL_TURN*0.5
		want_y = maxf(want_y,_ground_ahead(pos,dir,true,INF)+10.0)
	var rate := clampf(angle_difference(float(flight.heading),want)*TURN_GAIN,-TURN_MAX,TURN_MAX)
	_turn = lerpf(_turn,rate,_ease(late(),delta))
	flight.heading = wrapf(float(flight.heading)+_turn*delta,-PI,PI)
	var bank := clampf(-_turn*BANK,-BANK_MAX,BANK_MAX)
	flight.bank = lerpf(float(flight.bank),bank,_ease(0.15,delta))
	var pitch := clampf((want_y-pos.y)/PITCH_PER,-PITCH_MAX,PITCH_MAX)
	flight.pitch = lerpf(float(flight.pitch),pitch,_ease(EASE_PITCH,delta))
	flight.spin = 0.0
	flight.engine = 1.0
	# Lifting off for an opening, and the turn's bleed.
	if mode == "course":
		var near := 1.0-smoothstep(0.0,CARRY_FROM,_to_go) if _to_go >= 0.0 else 1.0-smoothstep(0.0,CARRY_BACK,-_to_go)
		var keep_share := carry()*(CHECK if _gate_checked() else 1.0)
		speed *= lerpf(1.0,keep_share,near)
		speed *= 1.0-TURN_BLEED/skill*clampf(absf(_turn)/TURN_MAX,0.0,1.0)
	var eased := lerpf(float(flight.speed),speed,_ease(speed_ease,delta))
	flight.speed = clampf(eased,float(flight.speed)-ACCEL_MOST*2.0*delta,float(flight.speed)+ACCEL_MOST*delta)
	flight.velocity = flight.forward()*float(flight.speed)
	flight.position += flight.velocity*delta
	# Never sunk into the ground under it (in a bore, the bore's floor is
	# the line's own).
	if not bore:
		var under := _ground_top(flight.position,mode == "air" or mode == "peel")
		flight.position.y = maxf(flight.position.y,under+(LOW_LEAST*0.5 if mode != "land" else 1.5))
	if mode == "land" and land_stage == "to": _maybe_rails()

## The course's next gate is a checked one.
func _gate_checked() -> bool:
	var gates: Array = course.get("gates",[])
	if gate_next < 0 or gate_next >= gates.size(): return false
	return bool(gates[gate_next].get("checked",false))

## On the course: {aim, y, room, bore}; where it is along it (`_s`), the
## next opening's middle (`_to_go`, `_to_through`).
func _on_course(pos: Vector3, dir: Vector3, speed: float) -> Dictionary:
	var pts: Array = course.points
	var lens: PackedFloat32Array = course.lens
	var r := _follow(pts,lens,_s,pos,speed)
	_s = maxf(_s,float(r.s))
	var gates: Array = course.gates
	# The next opening's middle along, the gate it is to take first.
	var through := INF
	for i in range(gates.size()):
		if i < gate_next: continue
		through = float(gates[i].through)
		break
	if through < INF:
		_to_go = through-_s
		_to_through = absf(_to_go)
	# A hall is built near the eye, a piece at a time: its height read
	# again from HALL_NEAR m out, never lower (the route only; the ribbon
	# was laid once).
	if gate_next < gates.size():
		var g: Dictionary = gates[gate_next]
		if String(g.kind) == "hall" and through-_s < HALL_NEAR and through-_s > 0.0 and _clock-float(g.get("read_at",-INF)) > HALL_EVERY:
			g.read_at = _clock
			_hall_reread(g)
	var look := maxf(speed*LOOK_TIME,LOOK_LEAST)
	var end := lens[lens.size()-1]
	var seg := int(r.seg)
	var a: Dictionary = pts[seg]
	var y := RivalCourse.at(course,minf(_s+look*0.4,end)).y
	var bore := bool(a.bore) and bool(pts[mini(seg+1,pts.size()-1)].bore)
	var room := float(pts[mini(seg+1,pts.size()-1)].room) if bool(a.lead) else minf(float(a.room),float(pts[mini(seg+1,pts.size()-1)].room))
	# Never under LOW_LEAST over what stands just ahead (what was built
	# after the line was laid: a tree's crown, an arch); on a leg and
	# through an air gate over the spans too, in an opening under them.
	if not bore:
		var guard := -INF
		var open := bool(a.lead) or bool(a.get("air",false))
		for d: float in (GUARD if open else [0.0,READ_IN]):
			guard = maxf(guard,_ground_top(pos+dir*d,open)+LOW_LEAST)
		y = maxf(y,guard)
	return {"aim":r.aim,"y":y,"room":room,"bore":bore}

func _bore_here() -> bool:
	var pts: Array = course.points
	var lens: PackedFloat32Array = course.lens
	for i in range(pts.size()-1):
		if lens[i+1] >= _s: return bool(pts[i].bore) and bool(pts[i+1].bore)
	return false

## The hall's height read again (rival_course.gd laid it from what was
## built then): the route's points through it raised, never lowered.
func _hall_reread(g: Dictionary) -> void:
	var pts: Array = course.points
	var at := int(g.get("at",-1))
	if at < 0 or not g.has("hall"): return
	var h: Array = g.hall
	var c: Vector3 = h[0]
	var fly := _hall_fly(c,h[1],float(h[2]))
	if fly < 0.0: return
	for i in range(at,mini(at+4,pts.size())):
		var p: Vector3 = pts[i].p
		p.y = maxf(p.y,c.y+fly)
		pts[i].p = p

## Pursuit along a polyline: projected onto it near `s0`, the aim LOOK
## ahead. {aim, s, seg}.
func _follow(pts: Array, lens: PackedFloat32Array, s0: float, pos: Vector3, speed: float) -> Dictionary:
	var best_s := s0
	var best_d := INF
	var seg := 0
	for i in range(pts.size()-1):
		if lens[i+1] < s0-40.0: continue
		if lens[i] > s0+400.0: break
		var a: Vector3 = pts[i].p
		var b: Vector3 = pts[i+1].p
		var ab := Vector2(b.x-a.x,b.z-a.z)
		var l2 := ab.length_squared()
		var u := clampf(Vector2(pos.x-a.x,pos.z-a.z).dot(ab)/l2,0.0,1.0) if l2 > 0.0001 else 0.0
		var d := (Vector2(a.x,a.z)+ab*u).distance_to(Vector2(pos.x,pos.z))
		if d < best_d:
			best_d = d
			best_s = lens[i]+u*(lens[i+1]-lens[i])
			seg = i
	var s := maxf(s0,best_s)
	var look := maxf(speed*LOOK_TIME,LOOK_LEAST)
	return {"aim":_point_on(pts,lens,minf(s+look,lens[lens.size()-1])),"s":s,"seg":seg}

static func _point_on(pts: Array, lens: PackedFloat32Array, s: float) -> Vector3:
	for i in range(pts.size()-1):
		if s <= lens[i+1] or i == pts.size()-2:
			var u := clampf((s-lens[i])/maxf(lens[i+1]-lens[i],0.001),0.0,1.0)
			return (pts[i].p as Vector3).lerp(pts[i+1].p,u)
	return pts[pts.size()-1].p

## Gone by gate `i` outside it: out to the side, back past it and in again
## (a loop), then on along the course from before it.
func come_round(i: int) -> void:
	var gates: Array = course.gates
	if i < 0 or i >= gates.size() or not _detour.is_empty(): return
	var g: Dictionary = gates[i]
	var flight: RefCounted = plane.flight
	var pos: Vector3 = flight.position
	var dir: Vector3 = g.dir
	var across := dir.cross(Vector3.UP)
	var gp: Vector3 = g.p
	# Round on the lower side.
	var side := 1.0
	if _ground_top(gp+across*ROUND_SIDE,true) > _ground_top(gp-across*ROUND_SIDE,true): side = -1.0
	var fwd := Vector3(-sin(float(flight.heading)),0.0,-cos(float(flight.heading)))
	var pts: Array = [{"p":pos},{"p":pos+fwd*90.0+across*side*ROUND_SIDE*0.6},{"p":gp+across*side*ROUND_SIDE},
		{"p":gp-dir*ROUND_BACK*0.6+across*side*ROUND_SIDE*0.7},{"p":gp-dir*ROUND_BACK},{"p":gp-dir*(APPROACH*0.5)}]
	var lens := PackedFloat32Array([0.0])
	for k in range(1,pts.size()):
		var a: Vector3 = pts[k-1].p
		var b: Vector3 = pts[k].p
		lens.append(lens[k-1]+Vector2(b.x-a.x,b.z-a.z).length())
	_detour = {"pts":pts,"lens":lens,"s":0.0,"rejoin":maxf(float(g.s)-APPROACH*0.5,0.0)}
	_s = minf(_s,float(_detour.rejoin))
	history.append({"t":snappedf(_clock,0.01),"id":String(g.id),"kind":String(g.kind),"what":"came round","at":pos.round()})

# --- Down to the strip --------------------------------------------------------------

## To the start of the final and down its glide: {aim, y, speed}.
func _to_strip(pos: Vector3, dir: Vector3) -> Dictionary:
	var axis: Vector3 = strip.axis
	var touch: Vector3 = strip.touch
	var final := touch-axis*RivalStrip.FINAL
	# How far it has to go to the touch: to the final's start, then down it.
	var along := (pos-touch).dot(axis)
	var side := absf((pos-touch).dot(axis.cross(Vector3.UP)))
	var on_final := along > -RivalStrip.FINAL*1.15 and side < 60.0 and dir.dot(axis) > 0.8
	var d := -along if on_final else Vector2(final.x-pos.x,final.z-pos.z).length()+RivalStrip.FINAL
	var aim := touch+axis*maxf(along+maxf(float(plane.flight.speed)*LOOK_TIME*2.0,LOOK_LEAST*2.0),-RivalStrip.FINAL) if on_final else final
	if not on_final and Vector2(final.x-pos.x,final.z-pos.z).length() < 90.0: aim = touch
	# The glide's height, or low over the land while far.
	var glide := float(touch.y)+PlaneStrip.contact(NOSE_UP)+RivalStrip.glide_y(d)
	var y := glide
	if d > RivalStrip.FINAL: y = maxf(glide,_ground_ahead(pos,dir,true,INF))
	else: y = maxf(glide,_ground_near(pos,dir)+1.5)
	var speed := lerpf(APPROACH_SPEED,LAND_SPEED,smoothstep(RivalStrip.FINAL*0.5,RivalStrip.FINAL*1.3,d))
	# Near the touch, what is built since is read again.
	if not _rechecked and d < RECHECK:
		_rechecked = true
		if not RivalStrip.still_clear(game,strip):
			history.append({"t":snappedf(_clock,0.01),"id":"strip","kind":"strip","what":"blocked","at":touch.round()})
			strip = {}
			mode = "air"
			_strip_search = 0.0
	return {"aim":aim,"y":y,"speed":speed}

## On to the rails: close in, lined up, low enough.
func _maybe_rails() -> void:
	var flight: RefCounted = plane.flight
	var axis: Vector3 = strip.axis
	var touch: Vector3 = strip.touch
	var o: Vector3 = flight.position-touch
	var along := o.dot(axis)
	if along < -RAIL or along > 0.0: return
	var across := axis.cross(Vector3.UP)
	var heading_axis := atan2(-axis.x,-axis.z)
	if absf(o.dot(across)) > RAIL_SIDE or absf(angle_difference(float(flight.heading),heading_axis)) > RAIL_TURN:
		_go_round()
		return
	land_stage = "rail"
	_rail_side = o.dot(across)
	var d := -along
	_rail_dy = float(flight.position.y)-(_ground_at(flight.position)+PlaneStrip.contact(NOSE_UP)+RivalStrip.glide_y(d))
	_rail_dy = clampf(_rail_dy,-1.0,12.0)

## Not lined up for the touch: on past it and round to look again.
func _go_round() -> void:
	var flight: RefCounted = plane.flight
	history.append({"t":snappedf(_clock,0.01),"id":"strip","kind":"strip","what":"went round","at":(flight.position as Vector3).round()})
	strip = {}
	mode = "air"
	_leg = Vector3(flight.position)+Vector3(-sin(float(flight.heading)),0.0,-cos(float(flight.heading)))*600.0
	_strip_search = 4.0

func _ground_at(p: Vector3) -> float:
	return float(game.field.height(p.x,p.z))

## On the rails: onto the lane's line, slowing, the flare, the touch; then
## the roll out to its stop.
func _land_rails(delta: float) -> void:
	var flight: RefCounted = plane.flight
	var axis: Vector3 = strip.axis
	var touch: Vector3 = strip.touch
	var across := axis.cross(Vector3.UP)
	var heading_axis := atan2(-axis.x,-axis.z)
	var along := (Vector3(flight.position)-touch).dot(axis)
	var speed := float(flight.speed)
	_rail_side *= 1.0-_ease(RAIL_EASE,delta)
	_rail_dy *= 1.0-_ease(RAIL_EASE,delta)
	flight.heading = lerp_angle(float(flight.heading),heading_axis,_ease(RAIL_EASE*0.6,delta))
	flight.engine = lerpf(float(flight.engine),IDLE,_ease(1.0,delta))
	if land_stage == "rail":
		var d := maxf(-along,0.0)
		speed = lerpf(speed,lerpf(TOUCH_SPEED,APPROACH_SPEED,clampf(d/RAIL,0.0,1.0)),_ease(0.3,delta))
		along += speed*delta
		d = maxf(-along,0.0)
		var flare := 1.0-clampf(d/RivalStrip.FLARE,0.0,1.0)
		var slope := RivalStrip.GLIDE*clampf(d/RivalStrip.FLARE,0.0,1.0)
		var rest := RivalStrip.rest(game,touch+axis*along+across*_rail_side,heading_axis)
		var pitch := lerpf(-atan(slope)+NOSE_UP,rest.y,smoothstep(0.0,1.0,flare))
		flight.pitch = lerpf(float(flight.pitch),pitch,_ease(0.15,delta))
		flight.bank = lerpf(float(flight.bank),clampf(_rail_side*0.02,-0.2,0.2),_ease(0.3,delta))
		var at := touch+axis*along+across*_rail_side
		at.y = rest.w+PlaneStrip.contact(float(flight.pitch))+RivalStrip.glide_y(d)+_rail_dy
		_place(at,speed,axis)
		if along >= 0.0:
			land_stage = "roll"
			_touch_speed = maxf(speed,1.0)
			history.append({"t":snappedf(_clock,0.01),"id":"strip","kind":"strip","what":"touched","at":at.round(),"speed":snappedf(speed,0.1)})
		return
	# The roll out: slowing to a stop at its stop.
	var left := maxf(RivalStrip.ROLL-along,0.5)
	var decel := speed*speed/(2.0*left)
	speed = maxf(speed-decel*delta,0.0)
	along += speed*delta
	var at := touch+axis*along+across*_rail_side
	var rest := RivalStrip.rest(game,at,heading_axis)
	flight.pitch = lerpf(float(flight.pitch),rest.y,_ease(0.25,delta))
	flight.bank = lerpf(float(flight.bank),rest.z,_ease(0.25,delta))
	at.y = rest.w+PlaneStrip.contact(float(flight.pitch))
	_place(at,speed,axis)
	if speed <= 0.15 or along >= RivalStrip.ROLL:
		mode = "rest"
		flight.speed = 0.0
		flight.velocity = Vector3.ZERO
		history.append({"t":snappedf(_clock,0.01),"id":"strip","kind":"strip","what":"stopped","at":at.round()})

func _place(at: Vector3, speed: float, axis: Vector3) -> void:
	var flight: RefCounted = plane.flight
	flight.velocity = axis*speed
	flight.position = at
	flight.speed = speed
	flight.spin = 0.0

## Stood: on its wheels, idling.
func _rest() -> void:
	var flight: RefCounted = plane.flight
	var r := RivalStrip.rest(game,flight.position,float(flight.heading))
	flight.position.y = r.x
	flight.pitch = r.y
	flight.bank = r.z
	flight.speed = 0.0
	flight.velocity = Vector3.ZERO
	flight.engine = IDLE

## From rest: down the lane, tail up, off, climbing; then the course or the
## peel.
func _takeoff(delta: float) -> void:
	var flight: RefCounted = plane.flight
	flight.engine = 1.0
	var heading := float(flight.heading)
	var fwd := Vector3(-sin(heading),0.0,-cos(heading))
	var speed := float(flight.speed)+TAKEOFF_ACCEL*delta
	var at: Vector3 = flight.position+fwd*speed*delta
	var r := RivalStrip.rest(game,at,heading)
	if _airborne <= 0.0 and speed < LIFT_SPEED:
		var tail := smoothstep(TAIL_UP,LIFT_SPEED,speed)
		flight.pitch = lerpf(r.y,TAIL_PITCH+(r.y-PlaneStrip.REST_PITCH),tail)
		flight.bank = r.z
		at.y = r.w+PlaneStrip.contact(float(flight.pitch))
	else:
		_airborne += delta
		flight.pitch = lerpf(float(flight.pitch),CLIMB_PITCH+atan(_climb-CLIMB_RATE),_ease(0.5,delta))
		flight.bank = lerpf(float(flight.bank),0.0,_ease(0.3,delta))
		var climb := speed*_climb*smoothstep(0.0,1.0,_airborne)
		at.y = maxf(float(flight.position.y)+climb*delta,r.w+PlaneStrip.contact(float(flight.pitch)))
	flight.position = at
	flight.speed = speed
	flight.velocity = fwd*speed+Vector3.UP*(at.y-float(flight.position.y))
	if _airborne > 0.0 and at.y-_ground_top(at,false) >= CLIMB_DONE:
		_turn = 0.0
		if _after == "peel":
			mode = "peel"
			peel = PEEL_TIME
		else:
			mode = "course"
			history.append({"t":snappedf(_clock,0.01),"id":"strip","kind":"strip","what":"off","at":at.round()})

# --- The ground ---------------------------------------------------------------------

## What solid `p` is in ("land", "arch", "hall", "tree"), or "".
func _in_solid(p: Vector3, bore: bool) -> String:
	if not bore and p.y < float(game.field.height(p.x,p.z)): return "land"
	if game.arches.inside(p): return "arch"
	if game.get("rocks") != null and game.rocks.inside(p): return "rock"
	if game.halls.inside(p): return "hall"
	if game.trees.inside(p): return "tree"
	return ""

## The top of what stands at `p`'s XZ: the land (or the sea), raised by a
## tree's crown, and with `spans` an arch's or hall's top too.
func _ground_top(p: Vector3, spans: bool) -> float:
	var h := maxf(float(game.field.height(p.x,p.z)),-40.0)
	# The rock shapes (LandRocks) it goes over, read READ_SIDE round.
	if game.get("rocks") != null: h = maxf(h,float(game.rocks.top_near(p,READ_SIDE)))
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

## A roll in [0, 1) from the seed, the race and `id`.
func _roll(id: String) -> float:
	return float(hash([_salt,id])%100000)/100000.0

## In the open: down the valleys ahead, near its course.
func _open_aim(pos: Vector3, dir: Vector3) -> Vector3:
	if _leg == Vector3.INF or Vector2(_leg.x-pos.x,_leg.z-pos.z).length() < LEG_ARRIVE or Vector3(_leg.x-pos.x,0.0,_leg.z-pos.z).dot(dir) < 0.0:
		_course_h = lerp_angle(_course_h,atan2(-dir.x,-dir.z),0.3)
		var low := INF
		for i in range(CANDIDATES):
			var a := _course_h+_rng.randf_range(-LEG_SPREAD,LEG_SPREAD)
			var p := pos+Vector3(-sin(a),0.0,-cos(a))*_rng.randf_range(LEG.x,LEG.y)
			var h := maxf(float(game.field.height(p.x,p.z)),-40.0)
			if h < low:
				low = h
				_leg = Vector3(p.x,h,p.z)
	return _leg

## Off the player: when its line would close within MISS_R of him in the
## next MISS_LOOK s, the aim moves off (up or aside). Alongside him (closing
## slower than CLOSING) it lets be.
func _keep_clear(traffic: Node, aim: Vector3, pos: Vector3, speed: float) -> Vector3:
	var player: Vector3 = traffic._player
	var off := pos-player
	var reach := WorldScale.span*MISS_SPANS
	if off.length() > reach+speed*MISS_LOOK*2.0: return aim
	var flight: RefCounted = plane.flight
	var rel: Vector3 = flight.velocity-traffic._player_fwd*float(traffic._player_speed)
	if -off.dot(rel)/maxf(off.length(),0.01) < CLOSING and off.length() > safe_r(): return aim
	var closest := off
	if rel.length_squared() > 0.01:
		var t := clampf(-off.dot(rel)/rel.length_squared(),0.0,MISS_LOOK)
		closest = off+rel*t
	var miss := closest.length()
	if miss >= reach: return aim
	var away := closest/maxf(miss,0.01) if miss > 0.5 else Vector3.UP
	return aim+away.normalized()*(reach-miss)*3.0

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
				out.append({"id":String(a.name),"kind":"arch","points":pts,"through":2,"mouth":2,"half_w":float(o.room),"lo":float(o.floor)-1.0,"hi":float(o.top)})
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
## enough; and its floor and the span's underside (world y): `floor`, `top`.
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
			best = {"centre":Vector3(o.x,0.0,o.z)+x*mid+Vector3.UP*y,"room":wide*0.5,"floor":fl,"top":fl+gap}
	_openings[name] = best
	return best
