extends Node
## The rival race (docs/design/endless-flight/rival-race-handoff.md): pick
## one of the traffic planes (scripts/endless/endless_traffic.gd), challenge
## it, land beside it, and race it round a course of gates. The polish round
## (rival-race-polish-handoff.md) gave it the count, the tag and the
## result; the course round (rival-race-course-handoff.md) the landing, the
## start from the ground, the fixed course and its ribbon (rival_marks.gd).
##
## Picking (ported from the cut lock-on, foot_lock.gd at archive/before-the-cut):
## the traffic plane nearest in PICK_RANGE m and within PICK_VIEW of the
## camera's aim, seen (the study's `_sight`) and ahead of the plane, gets a
## faint bracket (scripts/endless/rival_race_hud.gd). It lets go past
## LET_GO_RANGE or LET_GO_VIEW, or out of sight, after LOSE_AFTER s.
##
## The challenge: `fly_challenge` (Tab, the pad's R3) held HOLD_TIME s on a
## bracketed plane. While it is held the focus pulls onto it (the depth of
## field, below). Full, the plane accepts: it waggles its wings, and
## scripts/endless/rival_line.gd flies it from now on.
##
## The race's phases (`phase`):
## - "landing": it looks for a flat ahead (rival_strip.gd) and lands on it,
##   its lane and his side by side. Once the strip is picked the course is
##   planned from it (rival_course.gd) and shown, and his marks beside its
##   stop.
## - "waiting": it stands. He lands and rolls into his marks.
## - "count": in his marks and stopped (under STILL m/s), the count runs:
##   COUNT beats of COUNT_BEAT s (a bell and a tap of rumble each); out of
##   his marks or rolling again it stops ("wait for GO"). Then GO (a
##   brighter bell, a firmer rumble): both take off from rest, level.
## - "race": the gates in order, for both. A gate counts when one flies
##   through its mouth: across its plane the right way, within its span
##   (half_w and GATE_SLACK wingspans across, lo..hi and GATE_SLACK_UP m
##   up and down). A gate missed stays the next: he can't go on past it.
##   Won: he clears the last gate first. Lost: the rival does. Out of time:
##   TIME_LIMIT s from GO. His progress is how far along the course he is,
##   never past his next gate; ahead or behind is his progress less the
##   rival's.
## Called off: the button pressed again; it not stood LAND_TIME s after the
## accept, or he not lined up LINE_UP_TIME s after it stood, or LINE_UP_AWAY
## m further off the strip than it (once stood, off the strip) for AWAY_HOLD
## s; in the race
## OFF_COURSE m off the course for AWAY_HOLD s, or on the ground
## GROUND_HOLD s once he has flown.
##
## The pace: before GO the rival's own (rival_line.gd LAND_SPEED). From GO
## it carries PACE times the player's Boost (his pace preset's), times its
## skill's pace; a mild catch-up eases it off by up to CATCH_UP when it is
## far ahead along the course; and while his near-miss chain runs (scripts/
## endless/near_miss.gd, read only) it eases off by up to FLOW_EASE, so the
## better he flies the easier it is.
## At the end the result shows big, with a bell and a rumble; the rival
## waggles and peels off back into the traffic (off the ground first if it
## stood), not offered again for REST s.
##
## The depth of field (the lock-on's, for flight): the race gives the
## camera its own CameraAttributesPractical while its weight is up and
## hands back what the camera had once it is down; if something else took
## the lens meanwhile (the main menu's stage) it leaves it be. Only the far
## blur: the land near the plane is what is being flown. It starts past the
## rival: DOF_AIM strong while the button is held (and just after the
## accept), DOF_RACE light through the race so the land ahead reads.
##
## Flags: --race-near-start puts a traffic plane ahead in view at the start
## (START_AHEAD m on, START_SIDE m aside), finds its strip at once and skips
## the main menu;
## --rival-skill=X scales the rival's skill knobs (rival_line.gd);
## --rival-pace=X sets PACE.

const RivalLine = preload("res://scripts/endless/rival_line.gd")
const RivalStrip = preload("res://scripts/endless/rival_strip.gd")
const RivalCourse = preload("res://scripts/endless/rival_course.gd")
const RaceHud = preload("res://scripts/endless/rival_race_hud.gd")
const RivalMarks = preload("res://scripts/endless/rival_marks.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

const ACTION := &"fly_challenge"
## Picking (m, rad, s).
const PICK_RANGE := 520.0
const LET_GO_RANGE := 650.0
const PICK_VIEW := 0.45
const LET_GO_VIEW := 0.65
const LOSE_AFTER := 1.5
## The hold (s), and how fast an unfinished hold drains (share a second).
const HOLD_TIME := 0.7
const HOLD_DRAIN := 2.5
## The race: its pace (times the player's Boost); the catch-up (share of
## the pace, from CATCH_FROM m ahead along the course, full over CATCH_SPAN
## m more).
const PACE := 0.93
const CATCH_UP := 0.06
const CATCH_FROM := 150.0
const CATCH_SPAN := 300.0
## Flying well eases it too: while his near-miss chain is live it gives up
## to FLOW_EASE of its pace (a share for the chain being live, FLOW_LIVE,
## the rest by its multiplier; all of it while he surges), eased over
## FLOW_BLEND s.
const FLOW_EASE := 0.07
const FLOW_LIVE := 0.4
const FLOW_BLEND := 1.0
## The start: stopped is under STILL m/s; the count's beats, each beat (s);
## how long the rule shows from GO (s).
const STILL := 1.5
const COUNT := 3
const COUNT_BEAT := 0.7
const RULE_HOLD := 4.5
## A gate counts within its span and this much more (wingspans across, m
## up and down); one gone by outside within PASS_NEAR m of it is a miss;
## he is told so once MISSED_PAST m on past it.
const GATE_SLACK := 0.5
const GATE_SLACK_UP := 1.5
const PASS_NEAR := 160.0
const MISSED_PAST := 60.0
## The rival comes round to a gate it is this far past (m) without it.
const ROUND_PAST := 90.0
## Won, lost, called off (m, s). What was said shows DROP_SAY s.
const DROP_SAY := 2.0
const TIME_LIMIT := 240.0
const LAND_TIME := 120.0
const LINE_UP_TIME := 60.0
const LINE_UP_AWAY := 1800.0
const OFF_COURSE := 900.0
const AWAY_HOLD := 3.0
const GROUND_HOLD := 2.0
## A raced plane is not offered again for REST s; the result is held
## NOTE_HOLD s.
const REST := 20.0
const NOTE_HOLD := 3.5
## The beats' rumble (weak, strong, seconds).
const RUMBLE_COUNT := Vector3(0.22,0.0,0.08)
const RUMBLE_GO := Vector3(0.5,0.6,0.3)
const RUMBLE_GATE := Vector3(0.3,0.1,0.1)
const RUMBLE_WIN := Vector3(0.7,0.85,0.55)
const RUMBLE_LOSE := Vector3(0.15,0.45,0.45)
## The weight's ease (s).
const BLEND := 0.22
## The depth of field: blur amounts aiming and racing (Godot's
## dof_blur_amount); the strong blur lingers ACCEPT_LINGER s past the
## accept; where the far blur starts past the rival (m, plus a share of its
## distance) and how long it takes to come in (m, plus a share), aiming and
## racing.
const DOF_AIM := 0.06
const DOF_RACE := 0.016
const ACCEPT_LINGER := 1.2
const DOF_AIM_PAST := Vector2(40.0,0.3)
const DOF_RACE_PAST := Vector2(250.0,1.0)
const DOF_RAMP := Vector2(150.0,0.8)
## --race-near-start: the plane put ahead (m on, aside, up).
const START_AHEAD := 230.0
const START_SIDE := 18.0
const START_UP := 6.0
## The bracket frames this many wingspans.
const FRAME_SPANS := 2.4
## His marks' marker shows till he is down within SPOT_SHOW m of them.
const SPOT_SHOW := 60.0
## GO stays up this long past the count (s).
const GO_SHOW := 0.9

## "free" (offering), "racing", or "peeling" (the rival turning away).
var state := "free"
## While racing: "landing", "waiting", "count" or "race" (the header).
var phase := ""
## The plane offered (its index in the traffic), -1 none; the hold (0..1).
var offered := -1
var hold := 0.0
## The race's rival line (rival_line.gd), its plane index, how long since
## the accept, since GO (< 0 before it); the gap (m: the rival's progress
## less his, < 0 he leads).
var line: RefCounted = null
var rival := -1
var race_t := 0.0
var go_t := -1.0
var gap := 0.0
var races := 0
## The strip and the course (rival_strip.gd, rival_course.gd; {} none).
var strip: Dictionary = {}
var course: Dictionary = {}
## Each one's next gate and progress along the course (m).
var next_you := 0
var next_it := 0
var progress_you := 0.0
var progress_it := 0.0
## Every race's end: [{why, time, gap, gates_you, gates_it, history, clips, ...}].
var results: Array = []
## The gates gone through or by, for checks: [{who, gate, t, what, across, up}].
var gate_log: Array = []
## The lens' weight (0..1) and its blur now.
var weight := 0.0
var dof: CameraAttributesPractical = null
var skill := 1.0
## Its pace, times his Boost (PACE, or --rival-pace=X).
var pace := PACE
var _lost := 0.0
var _armed := true
var _away := 0.0
var _grounded := 0.0
var _flown := false
var _since_accept := INF
var _count_t := 0.0
var _stood_t := -1.0
var _you_raw := 0.0
var _prev_you := Vector3.INF
var _prev_it := Vector3.INF
## How well he flies, eased (0..1; `_flow_of`).
var flow := 0.0
var _beat := -1
var _said_at := -INF
var _said := ""
var _marks: Node3D
var _rest := {}
var _clock := 0.0
var _dof_before: CameraAttributes = null
var _dof_on := false
var _focus := Vector3.ZERO
var _hud: Control
var _seed := 1
var _amount := 0.0
var _past := Vector2.ZERO
## --race-near-start's strip, found at the start ({} none, or used).
var _near_strip: Dictionary = {}

## The flags: --rival-skill=X.
static func skill_wanted() -> float:
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--rival-skill="): return maxf(0.05,float(a.get_slice("=",1)))
	return 1.0

## --rival-pace=X: its pace, times his Boost (PACE).
static func pace_wanted() -> float:
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--rival-pace="): return clampf(float(a.get_slice("=",1)),0.3,2.0)
	return PACE

static func near_start_wanted() -> bool:
	return "--race-near-start" in LaunchArgs.user_args()

func setup(seed: int) -> void:
	name = "RivalRace"
	_seed = seed
	skill = skill_wanted()
	pace = pace_wanted()
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = RaceHud.new()
	layer.add_child(_hud)
	_marks = RivalMarks.new()
	add_child(_marks)

## --race-near-start: a traffic plane ahead of `game`'s plane, in view,
## and a strip for it already found ahead (it lands there once challenged,
## with no looking).
func place_near_start(game: Node) -> void:
	if game.traffic == null or (game.traffic.planes as Array).is_empty(): return
	var p: Vector3 = game.plane.position
	var heading := float(game.plane.heading)
	var fwd := Vector3(-sin(heading),0.0,-cos(heading))
	var at := p+fwd*START_AHEAD+fwd.cross(Vector3.UP)*START_SIDE+Vector3.UP*START_UP
	at.y = maxf(at.y,maxf(float(game.field.height(at.x,at.z)),-40.0)+RivalLine.LOW*2.0)
	game.traffic.place(0,at,heading)
	var probe: RefCounted = RivalLine.new(game,game.traffic.planes[0],skill,_seed,0)
	_near_strip = RivalStrip.find(probe,at,fwd,1600,true)
	print("rival race: near start, a strip %s" % ("found %.0f m on" % (_near_strip.touch as Vector3).distance_to(at) if not _near_strip.is_empty() else "not found; it will look"))

## One frame, after the traffic's step (the camera placed).
func step(delta: float, game: Node) -> void:
	_clock += delta
	_hud.step(delta)
	var traffic: Node = game.traffic
	if traffic == null or game.camera == null: return
	var pressed := Input.is_action_pressed(ACTION)
	if not pressed: _armed = true
	var tapped := pressed and _armed
	var flying: bool = game.stage == null and game.hand_landing.flying() and not (game.get("beats") != null and game.beats.running())
	_hud.offer = {}
	_hud.mark = {}
	_hud.spot = {}
	_hud.tag = {}
	if state == "peeling" and (line == null or bool(line.peeled())): _release_rival(traffic)
	if state == "racing":
		if tapped:
			_armed = false
			_end(game,"off")
		else: _race(delta,game)
	if state != "racing":
		_offer(delta,game,flying,pressed)
	var show := {"alpha":1.0 if state == "racing" else 0.0,"next":next_you,"progress":progress_you,
		"spot":state == "racing" and phase in ["landing","waiting","count"],"in_spot":phase == "count"}
	_marks.step(delta,game.camera,show)
	_lens(delta,game)

# --- Offering and challenging -----------------------------------------------------------

func _offer(delta: float, game: Node, flying: bool, pressed: bool) -> void:
	var traffic: Node = game.traffic
	var camera: Camera3D = game.camera
	if not flying:
		offered = -1
		hold = 0.0
		return
	var player: Vector3 = game.plane.position
	# Keep the one offered while it stays in reach and in view.
	if offered >= 0:
		var keep := _fits(traffic,offered,player,camera,LET_GO_RANGE,LET_GO_VIEW)
		_lost = 0.0 if keep else _lost+delta
		if _lost > LOSE_AFTER or not bool(traffic.planes[offered].up): offered = -1
	if offered < 0 or hold <= 0.0:
		var best := -1
		var best_score := INF
		for n in range((traffic.planes as Array).size()):
			if not _fits(traffic,n,player,camera,PICK_RANGE,PICK_VIEW,game): continue
			var pos: Vector3 = traffic.planes[n].flight.position
			var off := _off_view(camera,pos)
			var score := pos.distance_to(player)/PICK_RANGE+off/PICK_VIEW
			if score < best_score:
				best_score = score
				best = n
		if best >= 0 and best != offered:
			offered = best
			_lost = 0.0
			hold = 0.0
	if offered < 0:
		hold = 0.0
		return
	if pressed and _armed: hold = minf(hold+delta/HOLD_TIME,1.0)
	else: hold = maxf(hold-delta*HOLD_DRAIN,0.0)
	var target: Vector3 = traffic.planes[offered].flight.position
	_focus = target
	var shown := _screen(camera,target)
	if bool(shown.on_screen):
		_hud.offer = {"at":shown.at,"size":_frame_px(camera,target),"hold":hold,"alpha":1.0}
	if hold >= 1.0:
		_armed = false
		_start(game,offered)

## Whether traffic plane `n` can be offered: up, not resting, not racing,
## within `reach` m and `view` rad of the camera's aim, ahead of him, and
## (with `game`) seen.
func _fits(traffic: Node, n: int, player: Vector3, camera: Camera3D, reach: float, view: float, game: Node = null) -> bool:
	var plane: Dictionary = traffic.planes[n]
	if not bool(plane.up) or plane.get("rival") != null: return false
	if _clock < float(_rest.get(n,-INF)): return false
	var pos: Vector3 = plane.flight.position
	if pos.distance_to(player) > reach: return false
	if _off_view(camera,pos) > view: return false
	var fwd := -camera.global_basis.z
	if (pos-player).dot(fwd) <= 0.0: return false
	if game != null and float(game._sight(camera.global_position,pos)) < 0.98: return false
	return true

static func _off_view(camera: Camera3D, pos: Vector3) -> float:
	var fwd := -camera.global_basis.z
	return fwd.angle_to(pos-camera.global_position)

func _start(game: Node, n: int) -> void:
	var traffic: Node = game.traffic
	var plane: Dictionary = traffic.planes[n]
	races += 1
	line = RivalLine.new(game,plane,skill,_seed,races)
	line.pace = RivalLine.LAND_SPEED
	line.start_waggle()
	if n == 0 and not _near_strip.is_empty():
		line.land_on(_near_strip)
		_near_strip = {}
	plane.rival = line
	plane.goal = {"kind":"race","point":plane.flight.position}
	rival = n
	offered = -1
	hold = 0.0
	race_t = 0.0
	go_t = -1.0
	phase = "landing"
	_stood_t = -1.0
	strip = {}
	course = {}
	next_you = 0
	next_it = 0
	progress_you = 0.0
	progress_it = 0.0
	_you_raw = 0.0
	_prev_you = Vector3.INF
	_prev_it = Vector3.INF
	_away = 0.0
	_grounded = 0.0
	_flown = false
	_since_accept = 0.0
	flow = 0.0
	_beat = -1
	_said_at = -INF
	gate_log.clear()
	_marks.set_course({})
	_marks.set_spot({},game.field)
	state = "racing"
	print("rival race: challenged plane %d at %.0f m" % [n,(plane.flight.position as Vector3).distance_to(game.plane.position)])

# --- The race ---------------------------------------------------------------------------

func _race(delta: float, game: Node) -> void:
	var traffic: Node = game.traffic
	var plane: Dictionary = traffic.planes[rival]
	race_t += delta
	_since_accept += delta
	var flight: RefCounted = plane.flight
	var r_pos: Vector3 = flight.position
	var player: Vector3 = game.plane.position
	_focus = r_pos
	# The strip and the course follow the rival's: a new strip (or none),
	# a new course from it, shown at once.
	if not is_same(line.strip,strip) and phase == "landing":
		strip = line.strip
		_marks.set_spot(strip,game.field)
		if strip.is_empty(): course = {}
		else:
			var t0 := Time.get_ticks_usec()
			course = RivalCourse.plan(line,strip.start,strip.axis)
			line.set_course(course)
			print("rival race: strip at %s (%d tried), course %d gates, %.0f m, planned in %.0f ms" % [str((strip.stop as Vector3).round()),int(strip.get("tried",0)),(course.gates as Array).size(),float(course.length),(Time.get_ticks_usec()-t0)/1000.0])
		_marks.set_course(course)
	var ground: bool = game.hand_landing.on_ground()
	var rolling: float = float(game.hand_landing.roll_speed()) if ground else INF
	var in_spot := not strip.is_empty() and ground and RivalStrip.in_spot(strip,player)
	var still := in_spot and rolling < STILL
	var t := {"plane":_plane_screen(game.camera,player),"alpha":1.0}
	if phase == "landing" and line.mode == "rest":
		phase = "waiting"
		_stood_t = race_t
	if phase == "waiting" and still:
		phase = "count"
		_count_t = 0.0
		_beat = -1
	if phase == "count":
		if not still:
			phase = "waiting"
			_say("wait for GO")
		else:
			_count_t += delta
			var beat := mini(floori(_count_t/COUNT_BEAT),COUNT)
			if beat > _beat:
				_beat = beat
				if beat < COUNT: _cue(game,"race-count",0.6,1.0,RUMBLE_COUNT)
				else:
					_cue(game,"race-go",0.85,1.0,RUMBLE_GO)
					phase = "race"
					go_t = 0.0
					line.go()
	if phase in ["landing","waiting","count"]:
		line.pace = RivalLine.LAND_SPEED
		# Off: further from the strip than it is (while it flies there) by
		# LINE_UP_AWAY m.
		var to: Vector3 = strip.stop if not strip.is_empty() else r_pos
		var away := player.distance_to(to)-(r_pos.distance_to(to) if _stood_t < 0.0 else 0.0)
		_away = _away+delta if away > LINE_UP_AWAY else 0.0
		var late := race_t >= LAND_TIME if _stood_t < 0.0 else race_t-_stood_t >= LINE_UP_TIME
		if late or _away >= AWAY_HOLD:
			_end(game,"off")
			return
		_pre_tag(t,game,ground,in_spot,rolling)
	else: _course_race(delta,game,r_pos,player,t)
	if state != "racing": return
	# The marker over the rival.
	var camera: Camera3D = game.camera
	var shown := _screen(camera,r_pos)
	var far := r_pos.distance_to(player)
	_hud.mark = {"at":shown.at,"on_screen":shown.on_screen,"dir":shown.dir,"far":far > RaceHud.FAR,
		"text":"%d m" % roundi(far) if far > 120.0 else "","alpha":1.0}
	_hud.tag = t

## Before GO: what to do, and how far his marks are.
func _pre_tag(t: Dictionary, game: Node, ground: bool, in_spot: bool, rolling: float) -> void:
	var player: Vector3 = game.plane.position
	var warn := false
	var words := ""
	if phase == "count":
		var beat := mini(floori(_count_t/COUNT_BEAT),COUNT)
		t.count = COUNT-beat
		t.beat = fmod(_count_t,COUNT_BEAT)/COUNT_BEAT
		t.words = "hold still"
		return
	if strip.is_empty(): words = "it's looking for a flat"
	elif phase == "landing" and line.mode != "rest": words = "it's landing · land beside it"
	elif not ground: words = "land beside it · in the gold marks"
	elif not in_spot: words = "roll into the gold marks"
	else: words = "stop in the marks"
	if _clock-_said_at < DROP_SAY:
		words = _said
		warn = true
	var left := LINE_UP_TIME-(race_t-_stood_t)
	if _stood_t >= 0.0 and left < 20.0: words += "  ·  0:%02d" % ceili(left)
	t.words = words
	t.warn = warn
	if not strip.is_empty():
		var c: Vector3 = strip.spot.centre
		var d := Vector2(c.x-player.x,c.z-player.z).length()
		if d > 25.0 or not ground: t.big = "%d m" % roundi(d)
		# His marks' marker, till he is down near them.
		if not ground or d > SPOT_SHOW:
			var shown := _screen(game.camera,c+Vector3.UP*2.0)
			_hud.spot = {"at":shown.at,"on_screen":shown.on_screen,"dir":shown.dir,"alpha":1.0}

## The race from GO: the gates, the progress, won and lost, the tag.
func _course_race(delta: float, game: Node, r_pos: Vector3, player: Vector3, t: Dictionary) -> void:
	go_t += delta
	var gates: Array = course.gates
	var n := gates.size()
	# The gates, his and its.
	if _prev_you != Vector3.INF and next_you < n:
		var got := _through(gates[next_you],_prev_you,player)
		if got == "through":
			_log("you",next_you,player,gates[next_you])
			_marks.cleared(next_you)
			_hud.gate_flash()
			next_you += 1
			if next_you < n: _cue(game,"race-count",0.5,1.35,RUMBLE_GATE)
		elif got == "by": _say("missed gate %d · go back through" % (next_you+1))
	if _prev_it != Vector3.INF and next_it < n:
		var got := _through(gates[next_it],_prev_it,r_pos)
		if got == "through":
			_log("it",next_it,r_pos,gates[next_it])
			line.history.append({"t":snappedf(go_t,0.01),"id":String(gates[next_it].id),"kind":String(gates[next_it].kind),"what":"threaded"})
			next_it += 1
			line.gate_next = next_it
		elif got == "by":
			line.history.append({"t":snappedf(go_t,0.01),"id":String(gates[next_it].id),"kind":String(gates[next_it].kind),"what":"missed"})
			line.come_round(next_it)
	_prev_you = player
	_prev_it = r_pos
	# Progress: along the course, never past the next gate.
	_you_raw = RivalCourse.project(course,player,_you_raw)
	progress_you = minf(_you_raw,float(gates[next_you].s) if next_you < n else float(course.length))
	var it_raw := float(line._s)
	progress_it = minf(it_raw,float(gates[next_it].s) if next_it < n else float(course.length))
	if next_it < n and it_raw > float(gates[next_it].s)+ROUND_PAST: line.come_round(next_it)
	gap = progress_it-progress_you
	# Its pace: his Boost's, its skill's; the catch-up eases it off far ahead.
	var full: float = float(game.plane.boost_speed())*pace*float(line.pace_scale())
	full *= 1.0-CATCH_UP*clampf((gap-CATCH_FROM)/CATCH_SPAN,0.0,1.0)
	full *= 1.0-FLOW_EASE*_flow_of(delta,game.near)
	line.pace = full
	# Won, lost, called off.
	if game.hand_landing.flying(): _flown = true
	_grounded = 0.0 if game.hand_landing.flying() or not _flown else _grounded+delta
	var off := RivalCourse.off(course,player,_you_raw)
	_away = _away+delta if off > OFF_COURSE else 0.0
	if next_you >= n: _end(game,"won")
	elif next_it >= n: _end(game,"lost")
	elif go_t >= TIME_LIMIT: _end(game,"time")
	elif _away >= AWAY_HOLD or _grounded >= GROUND_HOLD: _end(game,"off")
	if state != "racing": return
	# The tag: GO, then the gate, ahead or behind.
	if go_t < GO_SHOW:
		t.count = 0
		t.beat = clampf(go_t/GO_SHOW,0.0,1.0)
		t.words = "through the gold gates"
		return
	var ahead := -gap
	t.big = "+%d m" % roundi(ahead) if ahead >= 0.0 else "%d m" % roundi(ahead)
	t.gold = ahead >= 0.0
	var words := "gate %d/%d  ·  %s" % [mini(next_you+1,n),n,"ahead" if ahead >= 0.0 else "behind"]
	if next_you == n-1: words = "last gate  ·  %s" % ("ahead" if ahead >= 0.0 else "behind")
	var warn := false
	if _you_raw > float(gates[next_you].s)+MISSED_PAST:
		words = "missed gate %d · go back through" % (next_you+1)
		warn = true
	elif _clock-_said_at < DROP_SAY:
		words = _said
		warn = true
	elif go_t < RULE_HOLD: words = "through the gold gates · first through the last wins"
	var left := TIME_LIMIT-go_t
	if left < 20.0: words += "  ·  0:%02d" % ceili(left)
	t.words = words
	t.warn = warn
	t.lead = float(next_you)/float(n)

## Whether the way from `a` to `b` went through gate `g`'s mouth
## ("through"), by it outside ("by"), or neither ("").
func _through(g: Dictionary, a: Vector3, b: Vector3) -> String:
	var p: Vector3 = g.p
	var dir: Vector3 = g.dir
	var da := (a-p).dot(dir)
	var db := (b-p).dot(dir)
	if not (da < 0.0 and db >= 0.0): return ""
	var x := a.lerp(b,da/(da-db))
	var across := absf((x-p).dot(dir.cross(Vector3.UP).normalized()))
	if across > PASS_NEAR: return ""
	if across <= float(g.half_w)+WorldScale.span*GATE_SLACK and x.y >= float(g.lo)-GATE_SLACK_UP and x.y <= float(g.hi)+GATE_SLACK_UP: return "through"
	return "by"

func _log(who: String, i: int, at: Vector3, g: Dictionary) -> void:
	var p: Vector3 = g.p
	var dir: Vector3 = g.dir
	gate_log.append({"who":who,"gate":i,"t":snappedf(go_t,0.01),"kind":String(g.kind),"across":snappedf((at-p).dot(dir.cross(Vector3.UP).normalized()),0.1),"y":snappedf(at.y-float(g.lo),0.1)})

func _say(text: String) -> void:
	_said = text
	_said_at = _clock

## A beat: `kind` on the flight sound (scripts/endless/flight_sound.gd)
## and a knock on the pad's rumble (flight_rumble.gd).
func _cue(game: Node, kind: String, gain: float, pitch: float, rumble: Vector3) -> void:
	if game.get("sound") != null: game.sound.shot(kind,gain,pitch)
	if game.get("rumble") != null: game.rumble.knock(rumble)

## The plane on screen, or null behind the camera.
func _plane_screen(camera: Camera3D, player: Vector3) -> Variant:
	if camera.is_position_behind(player): return null
	return camera.unproject_position(player)

func _end(game: Node, why: String) -> void:
	var traffic: Node = game.traffic
	var n := (course.get("gates",[]) as Array).size()
	var clock := _clock_text(maxf(go_t,0.0))
	var said := {"won":["RIVAL BEATEN","through the last gate first · %s" % clock],"lost":["IT GOT THERE FIRST","you made %d of %d gates" % [next_you,n]],
		"time":["OUT OF TIME","%d of %d gates" % [next_you,n]],"off":["RACE OFF",""]}
	_hud.say(String(said[why][0]),String(said[why][1]),why,NOTE_HOLD)
	if why == "won": _cue(game,"race-win",0.9,1.0,RUMBLE_WIN)
	elif why != "off": _cue(game,"race-lose",0.7,1.0,RUMBLE_LOSE)
	results.append({"why":why,"phase":phase,"time":snappedf(go_t,0.01),"gap":roundi(gap),"gates":n,"gates_you":next_you,"gates_it":next_it,
		"history":(line.history as Array).duplicate(),"clips":int(line.clips),"clip_log":(line.clip_log as Array).duplicate(),
		"ground_gap":snappedf(float(line.ground_gap),0.01),"gate_log":gate_log.duplicate()})
	print("rival race: %s (%s) after %.1f s from GO, gates %d/%d to its %d/%d" % [why,phase,go_t,next_you,n,next_it,n])
	line.start_peel(game.plane.position)
	line.pace = float(traffic.planes[rival].cruise)
	_rest[rival] = _clock+REST
	_marks.set_course({})
	_marks.set_spot({},game.field)
	state = "peeling"
	phase = ""

## The peel done: back to the traffic's own flying, on a leg ahead.
func _release_rival(traffic: Node) -> void:
	if rival >= 0:
		var plane: Dictionary = traffic.planes[rival]
		plane.rival = null
		var flight: RefCounted = plane.flight
		plane.goal = traffic._leg(plane,flight.position,float(flight.heading))
		plane.turn = 0.0
		flight.engine = 1.0
	line = null
	rival = -1
	state = "free"

## How well he is flying now (0..1): his chain live, its multiplier, the
## surge; eased.
func _flow_of(delta: float, near: RefCounted) -> float:
	var k := 0.0
	if near != null:
		if float(near.surge) > 0.0: k = 1.0
		elif float(near.chain_points) > 0.0: k = FLOW_LIVE+(1.0-FLOW_LIVE)*clampf((float(near.multiplier())-1.0)/(near.CHAIN_TOP-1.0),0.0,1.0)
	flow = lerpf(flow,k,1.0-exp(-delta/FLOW_BLEND))
	return flow

static func _clock_text(t: float) -> String:
	return "%d:%02d" % [floori(t/60.0),floori(fmod(t,60.0))]

# --- On screen ------------------------------------------------------------------------

## `pos` on screen: {at, on_screen, dir (from the middle, for the edge)}.
func _screen(camera: Camera3D, pos: Vector3) -> Dictionary:
	var view := get_viewport().get_visible_rect().size
	var mid := view*0.5
	var local := camera.global_transform.affine_inverse()*pos
	var dir := Vector2(local.x,-local.y)
	dir = dir.normalized() if dir.length() > 0.001 else Vector2.DOWN
	if not camera.is_position_behind(pos):
		var at := camera.unproject_position(pos)
		if Rect2(Vector2.ZERO,view).grow(-RaceHud.EDGE*0.5*float(_hud.ui())).has_point(at): return {"at":at,"on_screen":true,"dir":dir}
		dir = (at-mid).normalized() if (at-mid).length() > 0.001 else dir
	# Off the screen: at the edge, its way.
	var half := mid-Vector2.ONE*RaceHud.EDGE*float(_hud.ui())
	var k := minf(half.x/maxf(absf(dir.x),0.001),half.y/maxf(absf(dir.y),0.001))
	return {"at":mid+dir*k,"on_screen":false,"dir":dir}

## The bracket's half size for a plane at `pos` (px of a UI_HEIGHT
## window: the HUD scales it to the window).
func _frame_px(camera: Camera3D, pos: Vector3) -> float:
	var d := maxf(camera.global_position.distance_to(pos),1.0)
	var px := WorldScale.span*FRAME_SPANS*0.5/(d*tan(deg_to_rad(camera.fov)*0.5))*RaceHud.UI_HEIGHT*0.5
	return clampf(px,RaceHud.BRACKET.x,RaceHud.BRACKET.y)

# --- The lens -------------------------------------------------------------------------

## The far blur past the rival, eased by the weight; handed back at 0.
func _lens(delta: float, game: Node) -> void:
	var camera: Camera3D = game.camera
	var amount := 0.0
	var past := DOF_RACE_PAST
	if state == "racing":
		var linger := 1.0-smoothstep(0.0,ACCEPT_LINGER,_since_accept)
		amount = lerpf(DOF_RACE,DOF_AIM,linger)
		past = DOF_AIM_PAST.lerp(DOF_RACE_PAST,1.0-linger)
	elif offered >= 0 and hold > 0.0:
		amount = DOF_AIM*smoothstep(0.0,1.0,hold)
		past = DOF_AIM_PAST
	var goal := 1.0 if amount > 0.0 else 0.0
	if delta > 0.0: weight = lerpf(weight,goal,1.0-exp(-delta/BLEND))
	if absf(weight-goal) < 0.002: weight = goal
	if weight <= 0.0:
		if _dof_on:
			if camera.attributes == dof: camera.attributes = _dof_before
			_dof_on = false
			_dof_before = null
		return
	if not _dof_on:
		# The main menu's stage holds the lens while it runs: leave it be.
		if game.stage != null: return
		_dof_before = camera.attributes
		dof = CameraAttributesPractical.new() if _dof_before == null else _dof_before.duplicate() as CameraAttributesPractical
		camera.attributes = dof
		_dof_on = true
		_amount = amount
		_past = past
	elif camera.attributes != dof: return
	if amount > 0.0:
		_amount = amount
		_past = past
	var d := camera.global_position.distance_to(_focus)
	dof.dof_blur_near_enabled = false
	dof.dof_blur_far_enabled = true
	dof.dof_blur_far_distance = d+_past.x+d*_past.y
	dof.dof_blur_far_transition = DOF_RAMP.x+d*DOF_RAMP.y
	dof.dof_blur_amount = _amount*smoothstep(0.0,1.0,weight)

## A line for the numbers (F1).
func note() -> String:
	if state == "racing": return "\nrival race: plane %d, %s, %.0f s, gates %d/%d to its %d, gap %.0f m, pace %.1f m/s, rival %s" % [rival,phase,race_t,next_you,(course.get("gates",[]) as Array).size(),next_it,gap,float(line.pace),String(line.mode)]
	return "\nrival race: %s%s" % [state,"" if offered < 0 else ", offering plane %d" % offered]
