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
## A skill is a dictionary of those numbers (SKILLS); a station's band is
## the least skill that clears it (FlightMetrics `band`).

const SkyPlane = preload("res://scripts/sky_plane.gd")
const Metrics = preload("res://scripts/flight_metrics.gd")

const SKILLS := {
	"sloppy":{"reaction":0.45,"lag":0.12,"look":4.0,"noise":0.12,"drift":0.35,"gain":2.0,"brake":false,
		"knife_lead":0.25,"knife_jitter":0.15,"knife_forget":0.25,"knife_look":6.0,"track_ff":0.5},
	"decent":{"reaction":0.3,"lag":0.08,"look":6.0,"noise":0.08,"drift":0.35,"gain":2.6,"brake":true,
		"knife_lead":0.4,"knife_jitter":0.1,"knife_forget":0.05,"knife_look":6.0,"track_ff":0.5},
	"sharp":{"reaction":0.18,"lag":0.04,"look":8.0,"noise":0.03,"drift":0.35,"gain":3.2,"brake":true,
		"knife_lead":0.5,"knife_jitter":0.05,"knife_forget":0.0,"knife_look":6.0,"track_ff":0.5},
	"perfect":{"reaction":0.0,"lag":0.0,"look":8.0,"noise":0.0,"drift":0.35,"gain":3.5,"brake":true,"knows_all":true,
		"knife_lead":0.6,"knife_jitter":0.0,"knife_forget":0.0,"knife_look":6.0,"track_ff":0.5},
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

var params := {}
var rng := RandomNumberGenerator.new()
## The knife edge's own random stream, its plan per zone ({lead, forget,
## side}), the zone it is on, and where on the line it last was.
var knife_rng := RandomNumberGenerator.new()
var _knife_plan := {}
var _zone := 0
var _line_i := 0
var _noise := Vector2.ZERO
var _past := []

func _init(skill: Dictionary, seed_value := 0) -> void:
	params = skill
	rng.seed = seed_value
	knife_rng.seed = hash([seed_value,"knife"])

## Skill `name`'s numbers, stamped with VERSION.
static func skill(name: String) -> Dictionary:
	var out := (SKILLS.get(name,{}) as Dictionary).duplicate()
	out["version"] = VERSION
	return out

## This tick's input for `run`'s plane.
func input(run: RefCounted, delta: float) -> Dictionary:
	var plane: SkyPlane = run.plane
	_past.append({"t":run.t,"p":plane.position,"h":plane.heading,"pitch":plane.pitch})
	var lag := float(params.get("lag",0.0))
	var me: Dictionary = _past.back()
	while _past.size() > 1 and float(_past[1].t) <= run.t-lag: _past.pop_front()
	if lag > 0.0: me = _past.front()
	# The path through the tokens it knows, in order, from the next.
	var known: Array[Vector3] = []
	var reaction := float(params.get("reaction",0.0))
	var knows_all := bool(params.get("knows_all",false))
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
	if known.is_empty():
		out.turn = clampf(_noise.x,-1.0,1.0)
		out.pitch = clampf(_noise.y,-1.0,1.0)
		return out
	var at: Vector3 = me.p
	var aim := _ahead(at,known,float(params.get("look",6.0)))
	var knife := _knife(run,plane,at)
	out.lean = knife.lean
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
	return out

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
