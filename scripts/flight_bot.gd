extends RefCounted
## The flight study's CPU pilot (tools/flight_bench.gd, studies/flight_study.gd
## B key): it fills the same input dict a person's keys do (SkyPlane.step's
## turn, pitch, boost, brake, lean, roll), so its runs are recorded and
## measured the same way (scripts/flight_run.gd).
##
## It chases the next token with a look-ahead (pure pursuit): it aims at the
## point `look` metres on along the path from where it is through the tokens
## it knows, so near a token it is already swinging toward the one after.
## It knows a token once it has been seen for `reaction` seconds (the
## perfect reference knows every token from the start). It steers on a
## view of itself `lag` seconds old, its stick wanders by `noise` (a slow
## random drift, `drift` seconds long, half as much in pitch), and `gain` is how hard it corrects
## (per second of angle off). With `brake`, it closes the throttle when the
## way to the token swings more than BRAKE_OFF from its nose within
## BRAKE_NEAR m. No dodging and no rolls.
##
## The knife edge (VERSION 2): the run knows where the line needs it (its
## `zones`, FlightCourse `knife_zones`: where level wings don't fit but on
## edge they do, a slit). Once it has seen a zone for its reaction time (or
## knows all) and the zone is
## `knife_lead` s ahead at its speed, the bot holds `lean` to the side the
## line turns next (right if it goes straight on), and lets go once it is
## KNIFE_CLEAR m past the zone's end. From LINE_UP s before it leans until
## it lets go, it lines up: rather than cutting between tokens, it holds
## the smooth line itself (FlightMetrics `line`; `_track`), closing on it
## over `knife_look` m. Each zone, the lead wanders by
## `knife_jitter` s (gaussian), and with chance `knife_forget` it doesn't
## lean at all (its own random stream, so stations with no slit fly as in
## VERSION 1).
##
## Bonus tokens (a pack's optional tokens off the line, scripts/flight_run.gd):
## once it has seen one for its reaction time (the perfect reference knows
## them all, as on a second pass), and it lies ahead within BONUS_CONE of its
## nose, within BONUS_RANGE m, with a clear line to it, and nearer than the
## next token it needs (it never trades a token for a bonus; guides don't
## count), the bot goes for it: it chases it before the rest of its route. For a tight one (FlightCourse
## `tight`, a slit or a gap only a plane on edge fits) it leans on edge
## `knife_lead` s before it gets there (or forgets to, `knife_forget`). It
## gives a bonus up once it is taken or off past BONUS_GIVE_UP. With
## `"bonus": false` in its params (tools/flight_bench.gd --no-bonus) it
## ignores them. A station with no bonus tokens flies as before.
##
## Moments (a moments station, scripts/flight_pack_moments.gd: its line is
## all guides, the natural line, and its collectibles are its free ones, a
## starter and the challenge ones the starter brings): the bot flies the
## line and goes for every moment it sees, as for a bonus token, nearest
## first (the starter too, so it takes the challenge on whenever it sees
## it). After a grab it picks the line up at the first guide ahead of its
## nose. Its aim at a moment is off by `grab_aim` m (a gaussian miss across
## its way in, once per moment: pure pursuit would otherwise home on the
## point, so a moment's pickup reach would never matter). Pinned nose first
## on stone it turns hard toward the line (UNPIN). `"moments": false` in its
## params flies the bare line. A station without moments flies as before
## (`grab_aim` and the rest are only read on a moments station).
##
## Crashing (scripts/flight_crash.gd, opt-in): after the run puts the plane
## at a restart point the bot forgets what it was doing (its lagged view of
## itself, the moment or bonus it was going for, being pinned) and takes
## the line up from there. A moment or bonus token it has crashed going for
## GIVE_UP times it gives up for the rest of the run (a person learns; the
## perfect bot would otherwise crash the same way every time). With
## crashing off nothing changes.
##
## A skill is a dictionary of those numbers (SKILLS); a station's band is
## the least skill that clears it (FlightMetrics `band`).

const SkyPlane = preload("res://scripts/sky_plane.gd")
const Metrics = preload("res://scripts/flight_metrics.gd")
const Course = preload("res://scripts/flight_course.gd")

const SKILLS := {
	"sloppy":{"reaction":0.45,"lag":0.12,"look":4.0,"noise":0.12,"drift":0.35,"gain":2.0,"brake":false,
		"knife_lead":0.25,"knife_jitter":0.15,"knife_forget":0.25,"knife_look":6.0,"track_ff":0.5,"grab_aim":0.8},
	"decent":{"reaction":0.3,"lag":0.08,"look":6.0,"noise":0.08,"drift":0.35,"gain":2.6,"brake":true,
		"knife_lead":0.4,"knife_jitter":0.1,"knife_forget":0.05,"knife_look":6.0,"track_ff":0.5,"grab_aim":0.5},
	"sharp":{"reaction":0.18,"lag":0.04,"look":8.0,"noise":0.03,"drift":0.35,"gain":3.2,"brake":true,
		"knife_lead":0.5,"knife_jitter":0.05,"knife_forget":0.0,"knife_look":6.0,"track_ff":0.5,"grab_aim":0.3},
	"perfect":{"reaction":0.0,"lag":0.0,"look":8.0,"noise":0.0,"drift":0.35,"gain":3.5,"brake":true,"knows_all":true,
		"knife_lead":0.6,"knife_jitter":0.0,"knife_forget":0.0,"knife_look":6.0,"track_ff":0.5,"grab_aim":0.0},
}
## The perfect reference is flown at each of these look-aheads (m), and the
## best run kept.
const PERFECT_LOOKS := [3.0,5.0,7.0,9.0,12.0]
## The stick wanders less up and down than across (a share of `noise`).
const PITCH_NOISE := 0.5
const BRAKE_OFF := 0.6
## Bumped whenever SKILLS or the steering change, so the report keeps runs
## of different bots apart.
const VERSION := 2
const BRAKE_NEAR := 30.0
## The knife edge: let go this far (m) past a zone's end (about the
## plane's length), and line up this long (s) before leaning.
const KNIFE_CLEAR := 1.2
const LINE_UP := 1.5
## Bonus tokens: how far off the nose (rad) and how far away (m) one may
## be for the bot to go for it, and how far off the nose it gives it up.
const BONUS_CONE := deg_to_rad(45.0)
const BONUS_RANGE := 30.0
const BONUS_GIVE_UP := deg_to_rad(100.0)
## Back on a moments station's line after a grab: line less than this far
## ahead of its nose (m) is left, so it doesn't turn back for it.
const RESUME_AHEAD := 2.0
## Bumping this long without a break (s) on a moments station, it turns to
## get free.
const UNPIN := 0.3
const PIN_GAP := 0.15
## It turns to get free this long (s) at a time, then tries its aim again
## for UNPIN s.
const UNPIN_TURN := 0.5
## It never takes the line up again more than this far (m) back from the
## farthest it has been along it.
const PROGRESS_SLACK := 3.0
## Crashing on: a moment or bonus token is given up after this many crashes
## going for it.
const GIVE_UP := 2

var params := {}
## The bonus token it is going for (-1 none), and its plan per tight one
## ({forget}).
var _bonus := -1
var _bonus_plan := {}
## The moment it is going for (-1 none), and its plan per tight one.
var _moment := -1
var _moment_plan := {}
## How long it has been bumping without a break (s), and the way it turns to
## get free (0 not turning).
var _pinned := 0.0
var _unpin := 0.0
var _bumped_at := -INF
## The farthest sample of a moments station's line it has been beside.
var _progress := 0
var rng := RandomNumberGenerator.new()
## The knife edge's own random stream, its plan per zone ({lead, forget,
## side}), the zone it is on, and where on the line it last was.
var knife_rng := RandomNumberGenerator.new()
## Its aim at each moment it goes for: off by `grab_aim` m (gaussian, across
## the way it comes in), drawn once per moment from its own stream.
var aim_rng := RandomNumberGenerator.new()
var _aim_miss := {}
var _knife_plan := {}
var _zone := 0
var _line_i := 0
var _noise := Vector2.ZERO
var _past := []
## Restarts seen (the run's `respawns`), and crashes going for each moment
## ("m<i>") and bonus token ("b<i>").
var _respawns := 0
var _given_up := {}

func _init(skill: Dictionary, seed_value := 0) -> void:
	params = skill
	rng.seed = seed_value
	knife_rng.seed = hash([seed_value,"knife"])
	aim_rng.seed = hash([seed_value,"aim"])

## Skill `name`'s numbers, stamped with VERSION.
static func skill(name: String) -> Dictionary:
	var out := (SKILLS.get(name,{}) as Dictionary).duplicate()
	out["version"] = VERSION
	return out

## This tick's input for `run`'s plane.
func input(run: RefCounted, delta: float) -> Dictionary:
	var plane: SkyPlane = run.plane
	if run.get("respawns") != null and int(run.respawns) != _respawns: _respawned(run)
	_past.append({"t":run.t,"p":plane.position,"h":plane.heading,"pitch":plane.pitch})
	var lag := float(params.get("lag",0.0))
	var me: Dictionary = _past.back()
	while _past.size() > 1 and float(_past[1].t) <= run.t-lag: _past.pop_front()
	if lag > 0.0: me = _past.front()
	# The path through the tokens it knows, in order, from the next.
	var known: Array[Vector3] = []
	var reaction := float(params.get("reaction",0.0))
	var knows_all := bool(params.get("knows_all",false))
	# On a moments station it flies the natural line itself (the stone shows
	# it), picking it up again ahead after a grab.
	var moment_station: bool = run.get("moments") != null and not (run.moments as Array).is_empty()
	if moment_station:
		known = [_line_aim(run,me.p,float(me.h),float(me.pitch),float(params.get("look",6.0)))]
	else:
		for i in range(run.next_token(),run.tokens.size()):
			if i < 0: break
			if run.state[i] != run.STANDING: continue
			if not knows_all and (run.seen_at[i] < 0.0 or run.t-run.seen_at[i] < reaction): break
			known.append(run.tokens[i])
	var out := {"turn":0.0,"pitch":0.0,"boost":0.0,"brake":0.0,"lean":0.0,"roll":0.0}
	var drift := float(params.get("drift",0.35))
	var k := delta/maxf(drift,0.001)
	var sigma := float(params.get("noise",0.0))
	_noise += -_noise*k+Vector2(rng.randfn(),rng.randfn()*PITCH_NOISE)*sigma*sqrt(2.0*k)
	var chasing := _bonus_target(run,me)
	var grab := _moment_target(run,me) if chasing < 0 and moment_station else -1
	# Chasing a bonus it aims at that alone (its look-ahead would cut past it).
	if chasing >= 0: known = [run.bonus[chasing]]
	elif grab >= 0: known = [(run.moments[grab].at as Vector3)+_grab_miss(grab,me.p,run.moments[grab].at)]
	if known.is_empty():
		out.turn = clampf(_noise.x,-1.0,1.0)
		out.pitch = clampf(_noise.y,-1.0,1.0)
		return out
	var at: Vector3 = me.p
	var aim := _ahead(at,known,float(params.get("look",6.0)))
	var knife := _knife(run,plane,at)
	out.lean = knife.lean
	if chasing >= 0:
		knife.line_up = false
		out.lean = _bonus_lean(run,plane,chasing)
	elif grab >= 0:
		knife.line_up = false
		out.lean = _moment_lean(run,plane,grab)
	var gain := float(params.get("gain",3.0))
	if knife.line_up:
		var track := _track(run,at,float(me.h),float(me.pitch),float(plane.speed),gain*float(params.get("gain_line",1.0)))
		out.turn = clampf(track.x+_noise.x,-1.0,1.0)
		out.pitch = clampf(track.y+_noise.y,-1.0,1.0)
	else:
		var want := Metrics.angles(aim-at)
		var off := angle_difference(float(me.h),want.x)
		out.turn = clampf(-gain*off/SkyPlane.TURN_RATE+_noise.x,-1.0,1.0)
		out.pitch = clampf(gain*(want.y-float(me.pitch))/SkyPlane.PITCH_SPEED+_noise.y,-1.0,1.0)
	if bool(params.get("brake",false)):
		var to_token := known[0]-at
		var off_token := absf(angle_difference(float(me.h),Metrics.angles(to_token).x))
		if off_token > BRAKE_OFF and to_token.length() < BRAKE_NEAR: out.brake = 1.0
	# Pinned nose first on stone (a moments station: aiming past a column it
	# can't see round), it turns hard the way the line lies, as a person
	# would, until it is free.
	if moment_station:
		# A scrape bounces on and off stone tick by tick: one is a spell of
		# bumps under PIN_GAP s apart.
		if bool(run.bumping): _bumped_at = float(run.t)
		_pinned = _pinned+delta if float(run.t)-_bumped_at < PIN_GAP else 0.0
		if _pinned > UNPIN and fmod(_pinned-UNPIN,UNPIN_TURN+UNPIN) < UNPIN_TURN:
			var right := Vector3(cos(float(me.h)),0.0,-sin(float(me.h)))
			var to_line: Vector3 = (run.line[_nearest(run,at)].p as Vector3)-at
			if _unpin == 0.0: _unpin = 1.0 if to_line.dot(right) >= 0.0 else -1.0
			out.turn = _unpin
			out.pitch = 0.0
		else:
			_unpin = 0.0
	return out

## Put at a restart point by a crash: start afresh from there.
func _respawned(run: RefCounted) -> void:
	_respawns = int(run.respawns)
	for key: String in (["m%d" % _moment] if _moment >= 0 else [])+(["b%d" % _bonus] if _bonus >= 0 else []):
		_given_up[key] = int(_given_up.get(key,0))+1
	_past.clear()
	_bonus = -1
	_moment = -1
	_pinned = 0.0
	_unpin = 0.0
	_bumped_at = -INF
	_zone = 0
	_line_i = 0
	_line_i = _nearest(run,run.plane.position)
	_progress = _line_i

## The bonus token to go for this tick (see the header), or -1.
func _bonus_target(run: RefCounted, me: Dictionary) -> int:
	var bonus: Array = run.get("bonus") if run.get("bonus") != null else []
	if bonus.is_empty() or not bool(params.get("bonus",true)): return -1
	var at: Vector3 = me.p
	var nose := Metrics.forward(float(me.h),float(me.pitch))
	# It never trades a token it needs for a bonus: one is only worth going
	# for while it is nearer than the next standing token (guides aside).
	var need := INF
	for i in range(maxi(run.next_token(),0),run.tokens.size()):
		if run.state[i] == run.STANDING and run.guide[i] == 0:
			need = at.distance_to(run.tokens[i])
			break
	if _bonus >= 0:
		var d: Vector3 = (bonus[_bonus] as Vector3)-at
		if run.bonus_state[_bonus] != 0 or nose.angle_to(d) > BONUS_GIVE_UP or d.length() >= need: _bonus = -1
		else: return _bonus
	var reaction := float(params.get("reaction",0.0))
	var knows_all := bool(params.get("knows_all",false))
	var best := INF
	for i in range(bonus.size()):
		if run.bonus_state[i] != 0 or int(_given_up.get("b%d" % i,0)) >= GIVE_UP: continue
		if not knows_all and (run.bonus_seen[i] < 0.0 or run.t-run.bonus_seen[i] < reaction): continue
		var d: Vector3 = (bonus[i] as Vector3)-at
		if d.length() > BONUS_RANGE or d.length() >= need or nose.angle_to(d) > BONUS_CONE or d.length() >= best: continue
		if not Course.line_clear(run.space,at,bonus[i]): continue
		best = d.length()
		_bonus = i
	return _bonus

## The moment to go for this tick (a moments station's collectibles, see
## the header), or -1: as a bonus token, but there is no token to trade, so
## any moment there, known and ahead within BONUS_CONE and BONUS_RANGE with
## a clear line qualifies; the nearest is taken first.
func _moment_target(run: RefCounted, me: Dictionary) -> int:
	if not bool(params.get("moments",true)): return -1
	var at: Vector3 = me.p
	var nose := Metrics.forward(float(me.h),float(me.pitch))
	var list: Array = run.moments
	if _moment >= 0:
		var d: Vector3 = (list[_moment].at as Vector3)-at
		if run.moment_state[_moment] != 0 or run.moment_live[_moment] == 0 or nose.angle_to(d) > BONUS_GIVE_UP: _moment = -1
		else: return _moment
	var reaction := float(params.get("reaction",0.0))
	var knows_all := bool(params.get("knows_all",false))
	var best := INF
	for i in range(list.size()):
		if run.moment_state[i] != 0 or run.moment_live[i] == 0 or int(_given_up.get("m%d" % i,0)) >= GIVE_UP: continue
		if not knows_all and (run.moment_seen[i] < 0.0 or run.t-run.moment_seen[i] < reaction): continue
		var d: Vector3 = (list[i].at as Vector3)-at
		if d.length() > BONUS_RANGE or nose.angle_to(d) > BONUS_CONE or d.length() >= best: continue
		if not Course.line_clear(run.space,at,list[i].at): continue
		best = d.length()
		_moment = i
	return _moment

## How far off moment `i` it aims (see `aim_rng`): drawn the first time it
## goes for it, across the way from `at` to it (`at_moment`).
func _grab_miss(i: int, at: Vector3, at_moment: Vector3) -> Vector3:
	if not _aim_miss.has(i):
		var sigma := float(params.get("grab_aim",0.0))
		var way := (at_moment-at).normalized() if at.distance_to(at_moment) > 0.01 else Vector3.FORWARD
		var side := way.cross(Vector3.UP)
		side = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
		var up := side.cross(way).normalized()
		_aim_miss[i] = (side*aim_rng.randfn()+up*aim_rng.randfn())*sigma
	return _aim_miss[i]

## Where to aim on a moments station's natural line (the run's smooth `line`)
## from `at`: the sample `look` m on from the nearest one ahead of its nose,
## or the farthest one up to three times that with a clear line to it; with
## none clear (stone between it and the line), that first one anyway, and
## the bump slides it round.
func _line_aim(run: RefCounted, at: Vector3, heading: float, pitch: float, look: float) -> Vector3:
	var line: Array = run.line
	var nose := Metrics.forward(heading,pitch)
	var beside := maxi(_nearest(run,at),_progress-roundi(PROGRESS_SLACK/Metrics.STEP))
	_progress = maxi(_progress,beside)
	var i := beside
	# Ahead: never back for a stretch it has left behind.
	while i < line.size()-1 and nose.dot((line[i].p as Vector3)-at) < RESUME_AHEAD: i += 1
	_line_i = maxi(_line_i,i)
	var step := maxi(1,roundi(look/Metrics.STEP))
	var want := mini(i+step,line.size()-1)
	if Course.line_clear(run.space,at,line[want].p): return line[want].p
	# Hidden: the farthest it can see, back to the line beside it.
	for j in range(mini(i+3*step,line.size()-1),beside-1,-step/2-1):
		if Course.line_clear(run.space,at,line[j].p): return line[j].p
	return line[want].p

## The lean for moment `i`, as for a bonus token (`_bonus_lean`).
func _moment_lean(run: RefCounted, plane: RefCounted, i: int) -> float:
	if run.moment_tight[i] == 0 or float(params.get("knife_lead",0.0)) <= 0.0: return 0.0
	if not _moment_plan.has(i): _moment_plan[i] = {"forget":knife_rng.randf() < float(params.get("knife_forget",0.0))}
	if bool(_moment_plan[i].forget): return 0.0
	var to_go := (run.moments[i].at as Vector3).distance_to(plane.position)/maxf(float(plane.speed),1.0)
	return 1.0 if to_go <= float(params.get("knife_lead",0.0))+0.15 else 0.0

## The lean for bonus token `i`: on edge (to the right) from `knife_lead` s
## before a tight one, unless this pilot forgets; level otherwise.
func _bonus_lean(run: RefCounted, plane: RefCounted, i: int) -> float:
	if run.bonus_tight[i] == 0 or float(params.get("knife_lead",0.0)) <= 0.0: return 0.0
	if not _bonus_plan.has(i): _bonus_plan[i] = {"forget":knife_rng.randf() < float(params.get("knife_forget",0.0))}
	if bool(_bonus_plan[i].forget): return 0.0
	var to_go := (run.bonus[i] as Vector3).distance_to(plane.position)/maxf(float(plane.speed),1.0)
	return 1.0 if to_go <= float(params.get("knife_lead",0.0))+0.15 else 0.0

## The point `look` m on along the path from `at` through `known`.
static func _ahead(at: Vector3, known: Array[Vector3], look: float) -> Vector3:
	var left := look
	var from := at
	for p: Vector3 in known:
		var d := from.distance_to(p)
		if d >= left: return from+(p-from)/d*left if d > 0.0001 else p
		left -= d
		from = p
	# Past the last known token: on along the way to it.
	var last := known.back() as Vector3
	var before := at if known.size() < 2 else known[known.size()-2]
	var way := (last-before)
	if way.length() < 0.001: return last
	return last+way.normalized()*left

## The knife edge this tick (see the header): {"lean", "line_up"}.
func _knife(run: RefCounted, plane: RefCounted, at: Vector3) -> Dictionary:
	var out := {"lean":0.0,"line_up":false}
	var zones: Array = run.get("zones") if run.get("zones") != null else []
	while _zone < zones.size() and (plane.position-(zones[_zone].end as Vector3)).dot(zones[_zone].way) > KNIFE_CLEAR: _zone += 1
	if _zone >= zones.size(): return out
	var z: Dictionary = zones[_zone]
	# It knows a slit once it has seen it (the run's `knife_seen`) for its
	# reaction time, as it knows a token; the token in a slit is often hidden
	# behind the screen until it is lined up.
	if not bool(params.get("knows_all",false)):
		var saw := float(run.knife_seen[_zone])
		if saw < 0.0 or run.t-saw < float(params.get("reaction",0.0)): return out
	if not _knife_plan.has(_zone):
		_knife_plan[_zone] = {"lead":maxf(0.0,float(params.get("knife_lead",0.0))+knife_rng.randfn()*float(params.get("knife_jitter",0.0))),
			"forget":knife_rng.randf() < float(params.get("knife_forget",0.0)),"side":_side(run,z)}
	var plan: Dictionary = _knife_plan[_zone]
	var ahead := (z.start as Vector3)-at
	var to_go := maxf(0.0,ahead.dot(z.way))/maxf(float(plane.speed),1.0)
	if float(params.get("knife_lead",0.0)) <= 0.0: return out
	out.line_up = to_go <= float(plan.lead)+LINE_UP
	if not bool(plan.forget) and to_go <= float(plan.lead): out.lean = float(plan.side)
	return out

## The side to lean for zone `z`: the way the line turns past it (+1 right).
static func _side(run: RefCounted, z: Dictionary) -> float:
	var line: Array = run.line
	var last := int(z.last)
	var after := mini(last+12,line.size()-1)
	if after <= last: return 1.0
	var turn := angle_difference(Metrics.angles(z.way).x,Metrics.angles((line[after].p as Vector3)-(z.end as Vector3)).x)
	return -1.0 if turn > 0.02 else 1.0

## Lining up: the stick (turn, pitch) that holds the run's smooth line.
## It steers for the line's way a little ahead (the bank's lag), turned
## toward the line by its sideways and up-down miss over `knife_look` m,
## plus the line's own turn and climb rate there (so it doesn't lag a curve).
func _track(run: RefCounted, at: Vector3, heading: float, pitch: float, speed: float, gain: float) -> Vector2:
	var line: Array = run.line
	var i := _nearest(run,at)
	var n := line.size()
	if n < 6: return Vector2.ZERO
	var j := clampi(i+roundi(speed*SkyPlane.EASE_ROLL_IN/Metrics.STEP),2,n-3)
	var way := Metrics.angles((line[j+1].p as Vector3)-(line[j-1].p as Vector3))
	var before := Metrics.angles((line[j].p as Vector3)-(line[j-2].p as Vector3))
	var after := Metrics.angles((line[j+2].p as Vector3)-(line[j].p as Vector3))
	var ds := maxf((line[j+1].p as Vector3).distance_to(line[j-1].p),0.001)
	var yaw_rate := angle_difference(before.x,after.x)/ds*speed
	var pitch_rate := (after.y-before.y)/ds*speed
	var on: Vector3 = line[i].p
	var side := Vector3(cos(way.x),0.0,-sin(way.x))
	var reach := float(params.get("knife_look",4.0))
	var want_h := way.x-atan2((on-at).dot(side),reach)
	var want_p := way.y+atan2(on.y-at.y,reach)
	var ff := float(params.get("track_ff",1.0))
	var turn := -gain*angle_difference(heading,want_h)/SkyPlane.TURN_RATE-ff*yaw_rate/SkyPlane.TURN_RATE
	var climb := gain*(want_p-pitch)/SkyPlane.PITCH_SPEED+ff*pitch_rate/SkyPlane.PITCH_SPEED
	return Vector2(turn,climb)

## The index of the run's line sample nearest `at` (searched near where it
## last was, everywhere if that is far).
func _nearest(run: RefCounted, at: Vector3) -> int:
	var line: Array = run.line
	if line.is_empty(): return 0
	var best := INF
	var from := _line_i
	for i in range(maxi(0,_line_i-20),mini(line.size(),_line_i+60)):
		var d := at.distance_squared_to(line[i].p)
		if d < best:
			best = d
			from = i
	if best > 9.0:
		for i in range(line.size()):
			var d := at.distance_squared_to(line[i].p)
			if d < best:
				best = d
				from = i
	_line_i = from
	return from
