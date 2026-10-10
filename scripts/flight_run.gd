extends RefCounted
## One run of the flight study (studies/flight_study.gd, tools/flight_bench.gd):
## the game's plane (scripts/sky_plane.gd) flown through one station
## (scripts/flight_course.gd) by whoever fills its input dict, a person at
## the keys or the bot (scripts/flight_bot.gd), stepped the same way, and
## everything recorded: each tick's time, pose, speed and input, and the
## events (a token first seen, taken or missed; a bump off a solid).
##
## The plane is the game's own, stepped as the wanderer steps it
## (scripts/wanderer_eye.gd `_advance_flight`): SkyPlane.step over the
## floor, then RuinBump.bump off the station's solids, which stand on the
## ruins' collision layer. A token is taken as the game's are
## (scripts/sky_collectibles.gd `_touch`): the plane's path this tick passes
## within REACH of it. Taking a later token misses every one still standing
## before it, and a token is missed once the plane is PAST m beyond it along
## the line's way there (and, on a station with `miss_near`, within that
## many m of it). A token is seen the first tick it lies within CONE
## of the way the plane is going, within SIGHT, with a clear line to it.
## The run ends with every token taken or missed, after TIME_LIMIT, or once
## the plane strays LOST m from the next one.
##
## The knife edge: the station's knife zones (FlightCourse `knife_zones`,
## where the line threads a gap only a plane on edge fits) are tracked like
## tokens: `knife_seen` the first tick the point KNIFE_SEE m before a zone
## is in view (as a token is seen), `knife_in` when the plane reaches it
## (its bank then, and whether it is on edge, |bank| >= Metrics KNIFE_ON),
## `knife_out` when it is past it (`clean`: on edge all through and no
## bump), or `knife_skip` if it went by without coming within KNIFE_NEAR m.
##
## A pack's station may have guides and bonus tokens (FlightCourse `guides`,
## `bonus`). A guide is a point of the line among the tokens: taken and
## missed as they are (taking one misses what stands before it, as a token
## does), so the line and the bots' route stay whole, but not drawn and not
## counted in `collected` or the total. A bonus token stands off the line: taken whenever the
## plane's path passes within REACH of it, seen as a token is, never missed
## and not needed to clear.
##
## A moments station (FlightCourse `moments`, scripts/flight_pack_moments.gd)
## has no tokens to take: its line is all guides, and what it has to get are
## its moments, each taken (as a bonus token is) whenever the plane's path
## passes within the moment's own reach, seen as a token is, never missed:
##   free       standing from the start
##   starter    standing from the start; taking it starts the challenge
##   challenge  not there until the starter is taken (mode "all": all of
##              them; "chain": one, the next once that is taken)
## The challenge (FlightCourse `challenge`) ends `complete` once every
## challenge collectible is taken, `left` once the plane strays `area` m
## from the line, `timeout` after `time` s (0: never), or `over` when the
## run ends. Ending is never a penalty: the challenge collectibles go away
## and the starter stands again; taking it brings them all back. A pass
## yields how many free ones it got and the most challenge ones one try
## got (`free_taken`, `challenge_best`).
##
## Crash and restart (scripts/flight_crash.gd; `set_crash`, off by default):
## with a mode on, each bump's contact is looked at after RuinBump has bumped
## the plane out (RuinBump itself unchanged), and one that is a crash puts the
## plane back at the restart point at cruise along the line; the run then
## holds (its clock stopped) for FlightCrash HOLD s while the study's crash
## plays. Guides from the restart point on stand again; free collectibles
## taken stay taken; the challenge carries on (checkpoint), starts afresh
## (ring) or ends "crash" (entry). Events "crash" and "respawn"; the record
## carries "crash" (the rules), "cuts" (tick rows where it jumped to a
## restart point) and its station_hash tagged ("<hash>:crash-hard-checkpoint")
## so its runs pile up apart from bump-and-recover ones.
##
## `finish` returns the run as plain data (FlightMetrics `summarise` reads
## it; scripts/flight_log.gd saves it).

const SkyPlane = preload("res://scripts/sky_plane.gd")
const RuinBump = preload("res://scripts/ruin_bump.gd")
const Course = preload("res://scripts/flight_course.gd")
const Metrics = preload("res://scripts/flight_metrics.gd")
const Crash = preload("res://scripts/flight_crash.gd")

const FORMAT := 1
const SIGHT := 160.0
const CONE := deg_to_rad(40.0)
const PAST := 3.0
const TIME_LIMIT := 40.0
const LOST := 120.0
const KNIFE_SEE := 1.5
const KNIFE_NEAR := 4.0
## Standing, taken, missed.
enum {STANDING,TAKEN,MISSED}

var station: Dictionary
var pilot := "human"
## The bot's skill parameters, for the record (empty for a person).
var skill := {}
var plane := SkyPlane.new()
var space: PhysicsDirectSpaceState3D
var t := 0.0
var tokens: Array[Vector3] = []
var state := PackedInt32Array()
## When each token was first seen (s), or -1.
var seen_at := PackedFloat32Array()
var events := []
var ticks := {}
var done := false
var ended := ""
var bumping := false
var bumps := 0
## The line's way through each token, the line's needs per gap, the room.
var ways: Array[Vector3] = []
var gaps := []
var rooms := []
var entry := {}
var started := ""
## The smooth line through the tokens (FlightMetrics `line`) and the knife
## zones on it; per zone: when seen, when reached (or -1), its state (0
## ahead, 1 in it, 2 done), the least |bank| and whether it bumped in it.
var line := []
var zones := []
var knife_seen := PackedFloat32Array()
var knife_in := PackedFloat32Array()
var knife_state := PackedInt32Array()
var _knife_bank := PackedFloat32Array()
var _knife_bump := []
var edge_ticks := 0
## Guides (FlightCourse `guides`): is token i a guide.
var guide := PackedByteArray()
## Bonus tokens (FlightCourse `bonus`): where, taken (1) or standing (0), when
## first seen (s, or -1), and whether each sits where level wings don't fit
## (FlightCourse `tight`: the bot goes on edge for it).
var bonus: Array[Vector3] = []
var bonus_state := PackedInt32Array()
var bonus_seen := PackedFloat32Array()
var bonus_tight := PackedByteArray()
## Moments (FlightCourse `moments`): each one's {at, role, kind, reach},
## taken (1) or standing (0), there now (1: drawn, takeable) or not, when
## first seen (s, or -1), and tight (as bonus_tight). The challenge: "" not
## started, "on", or how the last try ended; when the try began, tries,
## challenge collectibles taken this try and the most any try took.
var moments := []
var moment_state := PackedInt32Array()
var moment_live := PackedByteArray()
var moment_seen := PackedFloat32Array()
var moment_tight := PackedByteArray()
var challenge := ""
var challenge_from := 0.0
var challenge_tries := 0
var challenge_now := 0
var challenge_best := 0
var challenge_rules := {}
## Live numbers for the overlay: the smoothed flown turn and pitch shares,
## stick travel and reversals so far.
var live_turn := 0.0
var live_pitch := 0.0
var travel := 0.0
var full_ticks := 0
var _last_in := Vector2.ZERO
var _rev_sign := Vector2.ZERO
var reversals := 0
var _last_heading := 0.0
var _last_pitch := 0.0
## Threading so far (FlightMetrics `threading_at`): the station's solids,
## ticks threading, openings passed, and whether this tick threads.
var solids := []
var thread_ticks := 0
var openings := 0
var threading_now := false
var _thread_last := -INF
## Flow so far (FlightMetrics `flow`): the last FLOW_SMOOTH s of heading and
## pitch, still ticks, the straight running now (from when, or -1) and the
## longest one.
var still_ticks := 0
var straight_from := -1.0
var longest_straight := 0.0
var _swing_past := []
## Crash and restart (FlightCrash): the rules ({} off), crashes so far, the
## hold left (s), where and how the last crash was ({position, heading,
## pitch, roll, velocity, normal, into, class}), restarts so far, the grace
## left, the line sample beside the plane and the tick rows cut by a restart.
var crash := {}
var crashes := 0
var crash_left := 0.0
var crash_pose := {}
var respawns := 0
var _grace := 0.0
var _beside := 0
var cuts := []

func _init(s: Dictionary, who := "human", params := {}, physics: PhysicsDirectSpaceState3D = null) -> void:
	station = s
	pilot = who
	skill = params
	space = physics
	entry = Course.entry(s)
	tokens = Course.tokens(s)
	state.resize(tokens.size())
	state.fill(STANDING)
	seen_at.resize(tokens.size())
	seen_at.fill(-1.0)
	guide.resize(tokens.size())
	guide.fill(0)
	for g in Course.guides(s): guide[g] = 1
	bonus = Course.bonus(s)
	bonus_state.resize(bonus.size())
	bonus_state.fill(0)
	bonus_seen.resize(bonus.size())
	bonus_seen.fill(-1.0)
	bonus_tight = Course.tight(s,bonus)
	moments = Course.moments(s)
	challenge_rules = Course.challenge(s)
	var spots: Array[Vector3] = []
	for m: Dictionary in moments:
		moment_state.append(0)
		moment_live.append(0 if m.role == "challenge" else 1)
		moment_seen.append(-1.0)
		spots.append(m.at)
	moment_tight = Course.tight(s,spots)
	line = Metrics.line(entry.position,entry.heading,tokens)
	gaps = Metrics.profile(line,tokens.size())
	rooms = Course.rooms(s,line)
	zones = Course.knife_zones(s,line)
	knife_seen.resize(zones.size())
	knife_seen.fill(-1.0)
	knife_in.resize(zones.size())
	knife_in.fill(-1.0)
	_knife_bank.resize(zones.size())
	_knife_bank.fill(-1.0)
	knife_state.resize(zones.size())
	knife_state.fill(0)
	_knife_bump.resize(zones.size())
	_knife_bump.fill(false)
	solids = Course.solids(s)
	for i in range(tokens.size()):
		var before: Vector3 = entry.position if i == 0 else tokens[i-1]
		var after: Vector3 = tokens[i+1] if i+1 < tokens.size() else tokens[i]+(tokens[i]-before)
		ways.append((after-before).normalized())
	for key: String in ["t","x","y","z","heading","pitch","bank","speed","in_turn","in_pitch","in_boost","in_brake","in_lean","in_roll","bump"]:
		ticks[key] = []
	started = Time.get_datetime_string_from_system(true)+"Z"
	plane.launch(entry.position,entry.heading,SkyPlane.CRUISE_SPEED,false)
	_last_heading = plane.heading
	_last_pitch = plane.pitch
	_record({})

## Crash and restart with rules `given` ({mode, restart, hard}; see
## FlightCrash `rules`); off (or {}) leaves the run as it always was.
func set_crash(given: Dictionary) -> void:
	crash = Crash.rules(given)

## The first standing token, or -1.
func next_token() -> int:
	for i in range(state.size()):
		if state[i] == STANDING: return i
	return -1

## Tokens taken, guides not counted.
func collected() -> int:
	var n := 0
	for i in range(state.size()):
		if state[i] == TAKEN and guide[i] == 0: n += 1
	return n

## The tokens to take to clear: all but the guides.
func required() -> int:
	return tokens.size()-Array(guide).count(1)

func bonus_taken() -> int:
	return Array(bonus_state).count(1)

## Moments of `role` there are, and taken (challenge: this try's).
func moment_count(role: String) -> int:
	return moments.filter(func(m: Dictionary) -> bool: return m.role == role).size()

func free_taken() -> int:
	var n := 0
	for i in range(moments.size()):
		if moments[i].role == "free" and moment_state[i] == 1: n += 1
	return n

## Seconds the challenge has left (INF with no limit, 0 when not on).
func challenge_left() -> float:
	if challenge != "on": return 0.0
	var limit := float(challenge_rules.time)
	return INF if limit <= 0.0 else maxf(0.0,limit-(t-challenge_from))

## One tick of `delta` s with `input` (SkyPlane.step's dict).
func tick(delta: float, input: Dictionary) -> void:
	if done: return
	# After a crash the run holds, its clock stopped, while the crash plays.
	if crash_left > 0.0:
		crash_left = maxf(0.0,crash_left-delta)
		return
	t += delta
	var was := plane.position
	plane.step(delta,input,Callable(Course,"ground"))
	if not crash.is_empty():
		if _crash_tick(was,delta):
			_record({})
			_check_end()
			return
	else:
		var bumped := RuinBump.bump(space,plane,was) if space != null else false
		if bumped and not bumping:
			bumps += 1
			events.append({"t":snappedf(t,0.0001),"kind":"bump"})
		bumping = bumped
	_tokens(was)
	if not moments.is_empty(): _moments(was)
	_look()
	_knife()
	_live(delta,input)
	_thread()
	_flow()
	_record(input)
	_check_end()

func _check_end() -> void:
	if next_token() < 0: _end("done")
	elif t >= TIME_LIMIT: _end("timeout")
	elif plane.position.distance_to(tokens[next_token()]) > LOST: _end("lost")

## The bump with crashing on: RuinBump bumps the plane out as ever, then its
## contact (FlightCrash `contact`, at the pose it had before) says how fast
## it went into which solid; a crash (FlightCrash `crashes`, never in the
## grace after a restart) puts it at the restart point. True if it crashed.
func _crash_tick(was: Vector3, delta: float) -> bool:
	_grace = maxf(0.0,_grace-delta)
	var pre := Crash.pose(plane)
	var bumped := RuinBump.bump(space,plane,was) if space != null else false
	_beside = _nearest_line(pre.position)
	if bumped:
		var hit := Crash.contact(space,pre,was)
		if hit.is_empty(): hit = {"normal":(plane.position-was).normalized(),"into":maxf(0.0,-(pre.velocity as Vector3).dot((plane.position-was).normalized())),"class":"stone","point":pre.position}
		if _grace <= 0.0 and Crash.crashes(crash,hit):
			_crash(pre,hit)
			return true
		if not bumping:
			bumps += 1
			events.append({"t":snappedf(t,0.0001),"kind":"bump","into":snappedf(float(hit.into),0.01),"speed":snappedf((pre.velocity as Vector3).length(),0.01),"solid":hit["class"]})
	bumping = bumped
	return false

## A crash: recorded, the plane put at the restart point, the challenge
## carried on, restarted or ended (see the header), the hold begun.
func _crash(pre: Dictionary, hit: Dictionary) -> void:
	crashes += 1
	crash_pose = pre.merged({"normal":hit.normal,"into":float(hit.into),"class":hit["class"]})
	events.append({"t":snappedf(t,0.0001),"kind":"crash","into":snappedf(float(hit.into),0.01),"solid":hit["class"],"at":Metrics.arr(pre.position),
		"speed":snappedf((pre.velocity as Vector3).length(),0.01),"line_s":snappedf(_beside*Metrics.STEP/SkyPlane.CRUISE_SPEED,0.01)})
	for k in range(zones.size()):
		if knife_state[k] == 1: _knife_bump[k] = true
	var how := str(crash.restart)
	var starter := -1
	for i in range(moments.size()):
		if moments[i].role == "starter": starter = i
	if how == "ring" and (challenge != "on" or starter < 0): how = "checkpoint"
	var at := 0
	match how:
		"entry":
			at = 0
			if challenge == "on": _challenge_end("crash")
		"ring":
			at = _nearest_line(moments[starter].at,true)
			_challenge_end("crash")
			moment_state[starter] = 1
			_challenge_start()
		_:
			at = _checkpoint(_beside)
	var p: Vector3 = entry.position if at == 0 else line[at].p
	var way := Metrics.angles((line[mini(at+1,line.size()-1)].p as Vector3)-(line[maxi(at-1,0)].p as Vector3))
	var heading := float(entry.heading) if at == 0 else way.x
	plane.launch(p,heading,SkyPlane.CRUISE_SPEED,false)
	plane.pitch = 0.0 if at == 0 else clampf(way.y,SkyPlane.PITCH_LIMIT.x,SkyPlane.PITCH_LIMIT.y)
	plane.velocity = plane.forward()*plane.speed
	# The line stands again from where it flies on: guides ahead of it.
	var gap := int(line[at].gap) if at < line.size() else 0
	for i in range(tokens.size()):
		if guide[i] == 1 and i >= gap and state[i] != STANDING:
			state[i] = STANDING
			seen_at[i] = -1.0
	_beside = at
	respawns += 1
	crash_left = Crash.HOLD
	_grace = Crash.GRACE
	bumping = false
	cuts.append(ticks.t.size())
	events.append({"t":snappedf(t,0.0001),"kind":"respawn","restart":how,"at":Metrics.arr(p),"line_s":snappedf(at*Metrics.STEP/SkyPlane.CRUISE_SPEED,0.01)})
	_last_heading = plane.heading
	_last_pitch = plane.pitch
	_swing_past.clear()
	straight_from = -1.0

## The restart point behind line sample `from`: BACK s back along the line,
## then on back to a sample SAFE m clear with no knife slit just ahead (0,
## the entry, if none).
func _checkpoint(from: int) -> int:
	var i := from-roundi(Crash.BACK*SkyPlane.CRUISE_SPEED/Metrics.STEP)
	var ahead := roundi(Crash.SLIT_AHEAD*SkyPlane.CRUISE_SPEED/Metrics.STEP)
	while i > 0:
		var ok := Course.clearance(solids,line[i].p) >= Crash.SAFE
		if ok:
			for z: Dictionary in zones:
				if int(z.first) > i and int(z.first)-i <= ahead: ok = false
		if ok: return i
		i -= 1
	return 0

## The line sample nearest `p`: near the last one (forward a little more
## than back), or anywhere with `anywhere` or if that is far.
func _nearest_line(p: Vector3, anywhere := false) -> int:
	var best := INF
	var at := _beside
	if not anywhere:
		for i in range(maxi(0,_beside-20),mini(line.size(),_beside+80)):
			var d := p.distance_squared_to(line[i].p)
			if d < best:
				best = d
				at = i
	if anywhere or best > 144.0:
		for i in range(line.size()):
			var d := p.distance_squared_to(line[i].p)
			if d < best:
				best = d
				at = i
	return at

func _tokens(was: Vector3) -> void:
	var at := plane.position
	var reach := Course.reach(station)
	# A station that curls back on itself (a spiral) misses a token by
	# passing it only within its `miss_near` m.
	var near_miss := float(station.get("miss_near",0.0))
	for i in range(tokens.size()):
		if state[i] != STANDING: continue
		var near := Geometry3D.get_closest_point_to_segment(tokens[i],was,at)
		if near.distance_to(tokens[i]) < reach:
			for k in range(i):
				if state[k] == STANDING: _resolve(k,MISSED)
			_resolve(i,TAKEN)
	for i in range(bonus.size()):
		if bonus_state[i] != 0: continue
		if Geometry3D.get_closest_point_to_segment(bonus[i],was,at).distance_to(bonus[i]) < reach:
			bonus_state[i] = 1
			events.append({"t":snappedf(t,0.0001),"bonus":i,"kind":"bonus"})
	for i in range(tokens.size()):
		if state[i] == STANDING and ways[i].dot(at-tokens[i]) > PAST and (near_miss <= 0.0 or at.distance_to(tokens[i]) < near_miss):
			_resolve(i,MISSED)

## Moments taken this tick, and the challenge started, carried on or ended.
func _moments(was: Vector3) -> void:
	var at := plane.position
	for i in range(moments.size()):
		if moment_state[i] != 0 or moment_live[i] == 0: continue
		var m: Dictionary = moments[i]
		if Geometry3D.get_closest_point_to_segment(m.at,was,at).distance_to(m.at) >= float(m.reach): continue
		moment_state[i] = 1
		events.append({"t":snappedf(t,0.0001),"moment":i,"role":m.role,"kind":"moment"})
		if m.role == "starter": _challenge_start()
		elif m.role == "challenge":
			challenge_now += 1
			challenge_best = maxi(challenge_best,challenge_now)
			if _challenge_next() < 0: _challenge_end("complete")
			elif str(challenge_rules.mode) == "chain": moment_live[_challenge_next()] = 1
	if challenge != "on": return
	if float(challenge_rules.time) > 0.0 and t-challenge_from >= float(challenge_rules.time): _challenge_end("timeout")
	elif _off_line(at) > float(challenge_rules.area): _challenge_end("left")

## The first challenge collectible still standing, or -1.
func _challenge_next() -> int:
	for i in range(moments.size()):
		if moments[i].role == "challenge" and moment_state[i] == 0: return i
	return -1

## The starter taken: every challenge collectible stands again (all of them
## there, or the first in "chain").
func _challenge_start() -> void:
	challenge = "on"
	challenge_from = t
	challenge_tries += 1
	challenge_now = 0
	var first := true
	for i in range(moments.size()):
		if moments[i].role != "challenge": continue
		moment_state[i] = 0
		moment_seen[i] = -1.0
		moment_live[i] = 1 if first or str(challenge_rules.mode) != "chain" else 0
		first = false
	events.append({"t":snappedf(t,0.0001),"kind":"challenge_start","try":challenge_tries})

## The try over (`why`): what's left of it goes away, and unless it was
## complete the starter stands again.
func _challenge_end(why: String) -> void:
	challenge = why
	for i in range(moments.size()):
		var role: String = moments[i].role
		if role == "challenge": moment_live[i] = 0
		elif role == "starter" and why != "complete":
			moment_state[i] = 0
			moment_seen[i] = -1.0
	events.append({"t":snappedf(t,0.0001),"kind":"challenge_end","why":why,"taken":challenge_now})

## How far (m) `p` is from the station's line (the polyline from the entry
## through its tokens).
func _off_line(p: Vector3) -> float:
	var best := INF
	var from: Vector3 = entry.position
	for q in tokens:
		best = minf(best,Geometry3D.get_closest_point_to_segment(p,from,q).distance_to(p))
		from = q
	return best

func _resolve(i: int, how: int) -> void:
	state[i] = how
	events.append({"t":snappedf(t,0.0001),"token":i,"kind":"hit" if how == TAKEN else "miss"})

## Tokens coming into view.
func _look() -> void:
	var way := plane.velocity.normalized() if plane.velocity.length() > 0.5 else plane.forward()
	for i in range(tokens.size()):
		if state[i] != STANDING or seen_at[i] >= 0.0: continue
		var d := tokens[i]-plane.position
		if d.length() > SIGHT or way.angle_to(d) > CONE: continue
		if not Course.line_clear(space,plane.position,tokens[i]): continue
		seen_at[i] = t
		events.append({"t":snappedf(t,0.0001),"token":i,"kind":"seen"})
	for i in range(bonus.size()):
		if bonus_state[i] != 0 or bonus_seen[i] >= 0.0: continue
		var d := bonus[i]-plane.position
		if d.length() > SIGHT or way.angle_to(d) > CONE: continue
		if not Course.line_clear(space,plane.position,bonus[i]): continue
		bonus_seen[i] = t
		events.append({"t":snappedf(t,0.0001),"bonus":i,"kind":"bonus_seen"})
	for i in range(moments.size()):
		if moment_state[i] != 0 or moment_live[i] == 0 or moment_seen[i] >= 0.0: continue
		var d: Vector3 = (moments[i].at as Vector3)-plane.position
		if d.length() > SIGHT or way.angle_to(d) > CONE: continue
		if not Course.line_clear(space,plane.position,moments[i].at): continue
		moment_seen[i] = t
		events.append({"t":snappedf(t,0.0001),"moment":i,"kind":"moment_seen"})

func _knife() -> void:
	var on_edge := absf(plane.bank) >= Metrics.KNIFE_ON
	if on_edge: edge_ticks += 1
	var way := plane.velocity.normalized() if plane.velocity.length() > 0.5 else plane.forward()
	for k in range(zones.size()):
		if knife_state[k] == 2: continue
		var z: Dictionary = zones[k]
		var at := plane.position
		if knife_seen[k] < 0.0:
			var spot: Vector3 = (z.start as Vector3)-(z.way as Vector3)*KNIFE_SEE
			var d := spot-at
			if d.length() < 0.5 or (d.length() <= SIGHT and way.angle_to(d) <= CONE and Course.line_clear(space,at,spot)):
				knife_seen[k] = t
				events.append({"t":snappedf(t,0.0001),"zone":k,"kind":"knife_seen"})
		var into := (at-(z.start as Vector3)).dot(z.way)
		var past := (at-(z.end as Vector3)).dot(z.way)
		var near := Geometry3D.get_closest_point_to_segment(at,z.start,z.end).distance_to(at) < KNIFE_NEAR
		if knife_state[k] == 0 and into >= -0.6 and near:
			knife_state[k] = 1
			knife_in[k] = t
			_knife_bank[k] = absf(plane.bank)
			events.append({"t":snappedf(t,0.0001),"zone":k,"kind":"knife_in","bank":snappedf(absf(plane.bank),0.001),"edge":on_edge})
		if knife_state[k] == 1:
			_knife_bank[k] = minf(_knife_bank[k],absf(plane.bank))
			if bumping: _knife_bump[k] = true
			if past > 0.6 or not near:
				knife_state[k] = 2
				var clean: bool = _knife_bank[k] >= Metrics.KNIFE_ON and not bool(_knife_bump[k])
				events.append({"t":snappedf(t,0.0001),"zone":k,"kind":"knife_out","clean":clean,"bank_min":snappedf(_knife_bank[k],0.001)})
		elif knife_state[k] == 0 and past > 3.0:
			knife_state[k] = 2
			events.append({"t":snappedf(t,0.0001),"zone":k,"kind":"knife_skip"})

func _live(delta: float, input: Dictionary) -> void:
	var k := 1.0-exp(-delta/Metrics.SMOOTH)
	live_turn = lerpf(live_turn,absf(angle_difference(_last_heading,plane.heading))/delta/Metrics.TURN_RATE,k)
	live_pitch = lerpf(live_pitch,absf(plane.pitch-_last_pitch)/delta/Metrics.PITCH_SPEED,k)
	_last_heading = plane.heading
	_last_pitch = plane.pitch
	var now := Vector2(float(input.get("turn",0.0)),float(input.get("pitch",0.0)))
	travel += absf(now.x-_last_in.x)+absf(now.y-_last_in.y)
	_last_in = now
	if maxf(absf(now.x),absf(now.y)) > Metrics.FULL: full_ticks += 1
	for a in range(2):
		var v := now[a]
		if absf(v) < Metrics.REVERSE_DEAD: continue
		if _rev_sign[a] != 0.0 and signf(v) != _rev_sign[a]: reversals += 1
		_rev_sign[a] = signf(v)

func _thread() -> void:
	threading_now = Metrics.threading_at(solids,plane.position,plane.heading)
	if not threading_now: return
	thread_ticks += 1
	if t-_thread_last > Metrics.THREAD_JOIN: openings += 1
	_thread_last = t

func _flow() -> void:
	_swing_past.append(Vector3(t,plane.heading,plane.pitch))
	while _swing_past.size() > 2 and float(_swing_past[1].x) <= t-Metrics.FLOW_SMOOTH+0.00001: _swing_past.pop_front()
	var old: Vector3 = _swing_past.front()
	var span := t-old.x
	var swing := 0.0
	if span > 0.0: swing = rad_to_deg(Vector2(angle_difference(old.y,plane.heading),plane.pitch-old.z).length()/span)
	if swing < Metrics.FLOW_STILL:
		still_ticks += 1
		if straight_from < 0.0: straight_from = t
		longest_straight = maxf(longest_straight,t-straight_from)
	else:
		straight_from = -1.0

func _record(input: Dictionary) -> void:
	var p := plane.position
	var row := [snappedf(t,0.0001),snappedf(p.x,0.001),snappedf(p.y,0.001),snappedf(p.z,0.001),snappedf(plane.heading,0.0001),snappedf(plane.pitch,0.0001),
		snappedf(plane.bank,0.0001),snappedf(plane.speed,0.001),snappedf(float(input.get("turn",0.0)),0.001),snappedf(float(input.get("pitch",0.0)),0.001),
		snappedf(float(input.get("boost",0.0)),0.001),snappedf(float(input.get("brake",0.0)),0.001),snappedf(float(input.get("lean",0.0)),0.001),
		float(input.get("roll",0.0)),1 if bumping else 0]
	var keys := ["t","x","y","z","heading","pitch","bank","speed","in_turn","in_pitch","in_boost","in_brake","in_lean","in_roll","bump"]
	for i in range(keys.size()): ticks[keys[i]].append(row[i])

func _end(why: String) -> void:
	for i in range(state.size()):
		if state[i] == STANDING: _resolve(i,MISSED)
	if challenge == "on": _challenge_end("over")
	ended = why
	done = true

## Ends the run now (a person restarting): what stands is missed.
func abandon() -> void:
	if not done: _end("abandoned")

## The live numbers: time, tokens, the next token's slack (s, or NAN if not
## seen yet) and when it was seen, the flown turn and pitch shares, the
## line's demand on this gap, reversals a second, stick travel a second and
## the share at full stick.
func live() -> Dictionary:
	var i := next_token()
	var slack := NAN
	var since := NAN
	var demand := 0.0
	if i >= 0:
		if seen_at[i] >= 0.0:
			slack = Metrics.slack(plane.position,plane.heading,plane.pitch,plane.speed,tokens[i])
			since = t-seen_at[i]
		var g: Dictionary = gaps[i]
		demand = Metrics.gap_demand(g.turn_peak,g.pitch_peak,slack if not is_nan(slack) else 0.0,float(rooms[i].room),Metrics.commit_time(g))
	var span := maxf(t,0.001)
	return {"t":t,"collected":collected(),"total":required(),"bonus":bonus_taken(),"bonus_total":bonus.size(),"next":i,"slack":slack,"since":since,"turn":live_turn,"pitch":live_pitch,
		"demand":demand,"need_turn":float(gaps[i].turn_peak) if i >= 0 else 0.0,"need_pitch":float(gaps[i].pitch_peak) if i >= 0 else 0.0,
		"reversals":reversals/span,"effort":travel/span,"full":float(full_ticks)/maxf(ticks.t.size(),1),"bumps":bumps,
		"threading":float(thread_ticks)/maxf(ticks.t.size(),1),"threading_now":threading_now,"openings":openings,"openings_per_s":openings/span,
		"still":float(still_ticks)/maxf(ticks.t.size(),1),"longest_straight":longest_straight,"straight_now":straight_from >= 0.0 and t-straight_from >= Metrics.FLOW_STRAIGHT,
		"knife_moments":zones.size(),"knife_clean":_knife_clean(),"knife_done":Array(knife_state).count(2),"on_edge_s":edge_ticks*t/maxf(ticks.t.size()-1,1),
		"on_edge":absf(plane.bank) >= Metrics.KNIFE_ON,"knife_next":_knife_next(),
		"moments":moments.size(),"free":free_taken(),"free_total":moment_count("free"),"challenge":challenge_now if challenge == "on" else challenge_best,
		"challenge_best":challenge_best,"challenge_total":moment_count("challenge"),"challenge_state":challenge,"challenge_left":challenge_left(),
		"crashes":crashes,"crash_mode":str(crash.get("mode","off")),"crash_restart":str(crash.get("restart","")),"crashing":crash_left > 0.0}

## Knife zones passed clean so far.
func _knife_clean() -> int:
	var n := 0
	for e: Dictionary in events:
		if str(e.kind) == "knife_out" and bool(e.clean): n += 1
	return n

## Seconds to the next knife zone not yet reached, once it has been seen
## (NAN otherwise).
func _knife_next() -> float:
	for k in range(zones.size()):
		if knife_state[k] != 0: continue
		if knife_seen[k] < 0.0: return NAN
		return maxf(0.0,((zones[k].start as Vector3)-plane.position).dot(zones[k].way))/maxf(plane.speed,1.0)
	return NAN

## The run as plain data, its numbers included.
func finish() -> Dictionary:
	if not done: abandon()
	var token_list := []
	for p in tokens: token_list.append(Metrics.arr(p))
	var room_list := []
	for r: Dictionary in rooms:
		var row := {"clearance":snappedf(float(r.clearance),0.001) if is_finite(float(r.clearance)) else 1.0e6,"room":snappedf(float(r.room),0.001)}
		if r.get("knife",false): row["knife"] = true
		room_list.append(row)
	var zone_list := []
	for z: Dictionary in zones:
		zone_list.append({"gap":z.gap,"start":Metrics.arr(z.start),"end":Metrics.arr(z.end),"room":snappedf(float(z.room),0.001)})
	var run := {
		"format":FORMAT,"station":station.id,"station_hash":Course.station_hash(station),"station_name":station.name,"intent":station.intent,
		"pilot":pilot,"skill":skill,"started":started,"dt":snappedf(t/maxf(ticks.t.size()-1,1),0.00001),
		"entry":{"position":Metrics.arr(entry.position),"heading":entry.heading},
		"tokens":token_list,"reach":snappedf(Course.reach(station),0.001),"span":Course.SPAN,"rooms":room_list,"knife":zone_list,
		"ticks":ticks,"events":events,
		"result":{"duration":snappedf(t,0.001),"collected":collected(),"total":required(),"cleared":collected() == required(),"ended":ended},
	}
	if guide.has(1):
		var g := []
		for i in range(guide.size()):
			if guide[i] == 1: g.append(i)
		run["guides"] = g
	if station.has("bonus"):
		var b := []
		for p in bonus: b.append(Metrics.arr(p))
		run["bonus"] = b
		run.result["bonus"] = bonus_taken()
	if not moments.is_empty():
		var list := []
		for m: Dictionary in moments:
			list.append({"at":Metrics.arr(m.at),"role":m.role,"kind":m.kind,"reach":snappedf(float(m.reach),0.001)})
		run["moments"] = list
		run["challenge"] = challenge_rules.duplicate()
		run.result["free"] = free_taken()
		run.result["free_total"] = moment_count("free")
		run.result["challenge"] = challenge_best
		run.result["challenge_total"] = moment_count("challenge")
		run.result["challenge_tries"] = challenge_tries
		run.result["challenge_ended"] = challenge
	if not crash.is_empty():
		run["crash"] = crash.duplicate()
		run["cuts"] = cuts.duplicate()
		run.station_hash = str(run.station_hash)+":"+Crash.tag(crash)
		run.result["crashes"] = crashes
	run["metrics"] = Metrics.summarise(run,solids)
	return run
