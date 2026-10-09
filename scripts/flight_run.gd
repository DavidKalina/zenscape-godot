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
## the line's way there. A token is seen the first tick it lies within CONE
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
## `finish` returns the run as plain data (FlightMetrics `summarise` reads
## it; scripts/flight_log.gd saves it).

const SkyPlane = preload("res://scripts/sky_plane.gd")
const RuinBump = preload("res://scripts/ruin_bump.gd")
const Course = preload("res://scripts/flight_course.gd")
const Metrics = preload("res://scripts/flight_metrics.gd")

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

## The first standing token, or -1.
func next_token() -> int:
	for i in range(state.size()):
		if state[i] == STANDING: return i
	return -1

func collected() -> int:
	return Array(state).count(TAKEN)

## One tick of `delta` s with `input` (SkyPlane.step's dict).
func tick(delta: float, input: Dictionary) -> void:
	if done: return
	t += delta
	var was := plane.position
	plane.step(delta,input,Callable(Course,"ground"))
	var bumped := RuinBump.bump(space,plane,was) if space != null else false
	if bumped and not bumping:
		bumps += 1
		events.append({"t":snappedf(t,0.0001),"kind":"bump"})
	bumping = bumped
	_tokens(was)
	_look()
	_knife()
	_live(delta,input)
	_thread()
	_flow()
	_record(input)
	if next_token() < 0: _end("done")
	elif t >= TIME_LIMIT: _end("timeout")
	elif plane.position.distance_to(tokens[next_token()]) > LOST: _end("lost")

func _tokens(was: Vector3) -> void:
	var at := plane.position
	for i in range(tokens.size()):
		if state[i] != STANDING: continue
		var near := Geometry3D.get_closest_point_to_segment(tokens[i],was,at)
		if near.distance_to(tokens[i]) < Course.REACH:
			for k in range(i):
				if state[k] == STANDING: _resolve(k,MISSED)
			_resolve(i,TAKEN)
	for i in range(tokens.size()):
		if state[i] == STANDING and ways[i].dot(at-tokens[i]) > PAST: _resolve(i,MISSED)

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
	return {"t":t,"collected":collected(),"total":tokens.size(),"next":i,"slack":slack,"since":since,"turn":live_turn,"pitch":live_pitch,
		"demand":demand,"need_turn":float(gaps[i].turn_peak) if i >= 0 else 0.0,"need_pitch":float(gaps[i].pitch_peak) if i >= 0 else 0.0,
		"reversals":reversals/span,"effort":travel/span,"full":float(full_ticks)/maxf(ticks.t.size(),1),"bumps":bumps,
		"threading":float(thread_ticks)/maxf(ticks.t.size(),1),"threading_now":threading_now,"openings":openings,"openings_per_s":openings/span,
		"still":float(still_ticks)/maxf(ticks.t.size(),1),"longest_straight":longest_straight,"straight_now":straight_from >= 0.0 and t-straight_from >= Metrics.FLOW_STRAIGHT,
		"knife_moments":zones.size(),"knife_clean":_knife_clean(),"knife_done":Array(knife_state).count(2),"on_edge_s":edge_ticks*t/maxf(ticks.t.size()-1,1),
		"on_edge":absf(plane.bank) >= Metrics.KNIFE_ON,"knife_next":_knife_next()}

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
		"tokens":token_list,"reach":snappedf(Course.REACH,0.001),"span":Course.SPAN,"rooms":room_list,"knife":zone_list,
		"ticks":ticks,"events":events,
		"result":{"duration":snappedf(t,0.001),"collected":collected(),"total":tokens.size(),"cleared":collected() == tokens.size(),"ended":ended},
	}
	run["metrics"] = Metrics.summarise(run,solids)
	return run
