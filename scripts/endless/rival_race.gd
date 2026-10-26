extends Node
## The rival race (docs/design/endless-flight/rival-race-handoff.md): pick
## one of the traffic planes (scripts/endless/endless_traffic.gd), challenge
## it, catch it and pass it. The polish round
## (docs/design/endless-flight/rival-race-polish-handoff.md) gave it a
## start beat, the rival's intent in the world (rival_marks.gd) and a pass
## that counts from the side or above.
##
## Picking (ported from the cut lock-on, foot_lock.gd at archive/before-the-cut):
## the traffic plane nearest in PICK_RANGE m and within PICK_VIEW of the
## camera's aim, seen (the study's `_sight`) and ahead of the plane, gets a
## faint bracket (scripts/endless/rival_race_hud.gd). It lets go past
## LET_GO_RANGE or LET_GO_VIEW, or out of sight, after LOSE_AFTER s.
##
## The challenge: `fly_challenge` (Tab, the pad's R3) held HOLD_TIME s on a
## bracketed plane. While it is held the focus pulls onto it (the depth of
## field, below). Full, the plane accepts: it waggles its wings and speeds
## up (scripts/endless/rival_line.gd flies it from now on), and the race
## begins.
##
## The start: the rival takes its head start through a count of COUNT
## beats (COUNT_BEAT s each, a bell and a tap of rumble each), then GO (a
## brighter bell, a firmer rumble); the rule shows RULE_HOLD s from GO. The
## clock (TIME_LIMIT) runs from GO.
##
## The race: the rival carries PACE times the player's Boost (his pace
## preset's), times its skill's pace, eased up over RAMP s, jumping ahead
## at JUMP times that till it leads by START_GAP m; a mild catch-up
## eases it off by up to CATCH_UP when it is far ahead; and while his near-miss chain runs (scripts/endless/
## near_miss.gd, read only) it eases off by up to FLOW_EASE, so the better
## he flies the easier it is.
## - Won: ahead of its nose by WIN_LEAD m along its heading, within
##   PASS_OFF m of its line (aside or above), held WIN_HOLD s. Not holding,
##   the hold drains at LEAD_DRAIN; why it dropped is said.
## - Lost: it is LOSE_GAP m ahead for LOSE_HOLD s, or TIME_LIMIT s run out.
## - Called off: the button pressed again, flying away from it (turned more
##   than AWAY_ANGLE off it for AWAY_HOLD s, or past AWAY_RANGE m), or on
##   the ground GROUND_HOLD s.
## At the end the result shows big, with a bell and a rumble; the rival waggles and peels
## off back into the traffic, not offered again for REST s.
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
## (START_AHEAD m on, START_SIDE m aside) and skips the main menu;
## --rival-skill=X scales the rival's skill knobs (rival_line.gd);
## --rival-pace=X sets PACE.

const RivalLine = preload("res://scripts/endless/rival_line.gd")
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
## The race: its pace (times the player's Boost), the ramp up to it (s),
## the catch-up (share of the pace, from CATCH_FROM m ahead, full over
## CATCH_SPAN m more).
const PACE := 0.93
const RAMP := 1.5
## The jump: after the accept, until it is START_GAP m ahead (at least
## twice RAMP s, at most JUMP_TIME s), it flies JUMP times its pace, so every race starts with
## about the same gap to close.
const START_GAP := 150.0
const JUMP := 1.25
const JUMP_TIME := 10.0
## How quickly its speed follows the pace while it jumps (s).
const JUMP_EASE := 0.5
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
## The start: the count's beats, each beat (s), and how long the rule
## shows from GO (s).
const COUNT := 3
const COUNT_BEAT := 0.7
const RULE_HOLD := 4.5
## Won, lost and called off (m, s, rad). The lead's hold drains LEAD_DRAIN
## s a second once not held; why it dropped shows DROP_SAY s.
const WIN_LEAD := 6.0
const PASS_OFF := 150.0
const WIN_HOLD := 1.5
const LEAD_DRAIN := 1.0
const DROP_SAY := 2.0
const LOSE_GAP := 550.0
const LOSE_HOLD := 5.0
const TIME_LIMIT := 120.0
const AWAY_ANGLE := 1.65
const AWAY_HOLD := 3.0
const AWAY_RANGE := 1400.0
const GROUND_HOLD := 2.0
## A raced plane is not offered again for REST s; the result is held
## NOTE_HOLD s.
const REST := 20.0
const NOTE_HOLD := 3.5
## The marks (rival_marks.gd): the trail reaches TRAIL_TIME s of the
## rival's speed ahead (at least TRAIL_LEAST m), read again every
## INTENT_EVERY s.
const TRAIL_TIME := 6.0
const TRAIL_LEAST := 250.0
const INTENT_EVERY := 0.1
## The beats' rumble (weak, strong, seconds).
const RUMBLE_COUNT := Vector3(0.22,0.0,0.08)
const RUMBLE_GO := Vector3(0.5,0.6,0.3)
const RUMBLE_LEAD := Vector3(0.3,0.1,0.1)
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
## GO stays up this long past the count (s).
const GO_SHOW := 0.9

## "free" (offering), "racing", or "peeling" (the rival turning away).
var state := "free"
## The plane offered (its index in the traffic), -1 none; the hold (0..1).
var offered := -1
var hold := 0.0
## The race's rival line (rival_line.gd), its plane index, how long it has
## run, the gap (m the rival is ahead along its heading; < 0 he leads).
var line: RefCounted = null
var rival := -1
var race_t := 0.0
var gap := 0.0
var races := 0
## Every race's end: [{why, time, gap, history}].
var results: Array = []
## The lens' weight (0..1) and its blur now.
var weight := 0.0
var dof: CameraAttributesPractical = null
var skill := 1.0
## Its pace, times his Boost (PACE, or --rival-pace=X).
var pace := PACE
var _lost := 0.0
var _armed := true
var _ahead := 0.0
var _behind := 0.0
var _away := 0.0
var _grounded := 0.0
var _since_accept := INF
var _jumping := false
## How well he flies, eased (0..1; `_flow_of`).
var flow := 0.0
var _peel_left := 0.0
var _beat := -1
var _holding := false
var _drop_at := -INF
var _drop_text := ""
var _intent := {}
var _intent_at := -INF
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

## --race-near-start: a traffic plane ahead of `game`'s plane, in view.
func place_near_start(game: Node) -> void:
	if game.traffic == null or (game.traffic.planes as Array).is_empty(): return
	var p: Vector3 = game.plane.position
	var heading := float(game.plane.heading)
	var fwd := Vector3(-sin(heading),0.0,-cos(heading))
	var at := p+fwd*START_AHEAD+fwd.cross(Vector3.UP)*START_SIDE+Vector3.UP*START_UP
	at.y = maxf(at.y,maxf(float(game.field.height(at.x,at.z)),-40.0)+RivalLine.LOW*2.0)
	game.traffic.place(0,at,heading)

## One frame, after the traffic's step (the camera placed).
func step(delta: float, game: Node) -> void:
	_clock += delta
	_hud.step(delta)
	var traffic: Node = game.traffic
	if traffic == null or game.camera == null: return
	var pressed := Input.is_action_pressed(ACTION)
	if not pressed: _armed = true
	var tapped := pressed and _armed
	var flying: bool = game.stage == null and game.hand_landing.flying()
	_hud.offer = {}
	_hud.mark = {}
	_hud.tag = {}
	if state == "peeling":
		_peel_left -= delta
		if _peel_left <= 0.0: _release_rival(traffic)
	if state == "racing":
		if tapped:
			_armed = false
			_end(game,"off")
		else: _race(delta,game)
	if state != "racing":
		_offer(delta,game,flying,pressed)
	# Where it is going, in the world.
	if state == "racing" and line != null:
		if _clock-_intent_at >= INTENT_EVERY:
			_intent_at = _clock
			_intent = line.intent(maxf(float(traffic.planes[rival].flight.speed)*TRAIL_TIME,TRAIL_LEAST))
	else: _intent = {}
	_marks.step(delta,game.camera,_intent,1.0)
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
	line.pace = float(plane.cruise)
	line.start_waggle()
	plane.rival = line
	plane.goal = {"kind":"race","point":plane.flight.position}
	rival = n
	offered = -1
	hold = 0.0
	race_t = 0.0
	_ahead = 0.0
	_behind = 0.0
	_away = 0.0
	_grounded = 0.0
	_since_accept = 0.0
	_jumping = true
	flow = 0.0
	_beat = -1
	_holding = false
	_drop_at = -INF
	_intent_at = -INF
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
	var r_dir := Vector3(-sin(float(flight.heading)),0.0,-cos(float(flight.heading)))
	var player: Vector3 = game.plane.position
	var lead := (player-r_pos).dot(r_dir)
	# The gap: how far it is ahead (the distance), or how far he leads
	# along its heading (< 0).
	gap = player.distance_to(r_pos) if lead < 0.0 else -lead
	# Its pace: his Boost's, its skill's, eased up from cruise; the catch-up
	# eases it off far ahead.
	var full: float = float(game.plane.boost_speed())*pace*float(line.pace_scale())
	full *= 1.0-CATCH_UP*clampf((gap-CATCH_FROM)/CATCH_SPAN,0.0,1.0)
	full *= 1.0-FLOW_EASE*_flow_of(delta,game.near)
	if _jumping and ((gap >= START_GAP and race_t > RAMP*2.0) or race_t > JUMP_TIME): _jumping = false
	if _jumping: full *= JUMP
	line.speed_ease = JUMP_EASE if _jumping else RivalLine.EASE_SPEED
	line.pace = lerpf(float(plane.cruise),full,smoothstep(0.0,RAMP,race_t))
	_focus = r_pos
	# The start: the count, then GO.
	var go_t := race_t-go_at()
	var beat := mini(floori(race_t/COUNT_BEAT),COUNT)
	if beat > _beat:
		_beat = beat
		if beat < COUNT: _cue(game,"race-count",0.6,1.0,RUMBLE_COUNT)
		else: _cue(game,"race-go",0.85,1.0,RUMBLE_GO)
	# Won, lost, called off. Off its line: aside and above, square to its
	# heading.
	var off := player-r_pos
	var off_line := (off-r_dir*off.dot(r_dir)).length()
	var passing := go_t >= 0.0 and lead > WIN_LEAD and off_line < PASS_OFF
	if passing and not _holding: _cue(game,"race-count",0.35,1.5,RUMBLE_LEAD)
	if _holding and not passing:
		_drop_at = race_t
		_drop_text = "too wide · close on its line" if lead > WIN_LEAD else ("level · get clear of its nose" if lead > 0.0 else "it got back by · pass again")
	_holding = passing
	_ahead = _ahead+delta if passing else maxf(_ahead-delta*LEAD_DRAIN,0.0)
	var to := r_pos-player
	var fwd: Vector3 = game.plane.velocity
	var turned := Vector2(fwd.x,fwd.z).length() > 1.0 and absf(Vector2(fwd.x,fwd.z).angle_to(Vector2(to.x,to.z))) > AWAY_ANGLE
	_away = _away+delta if turned and gap > 0.0 and go_t >= 0.0 else 0.0
	# Turned away from it, he is calling it off, not losing.
	_behind = _behind+delta if gap > LOSE_GAP and not turned else 0.0
	_grounded = 0.0 if game.hand_landing.flying() else _grounded+delta
	if _ahead >= WIN_HOLD: _end(game,"won")
	elif _behind >= LOSE_HOLD: _end(game,"lost")
	elif go_t >= TIME_LIMIT: _end(game,"time")
	elif _away >= AWAY_HOLD or to.length() > AWAY_RANGE or _grounded >= GROUND_HOLD: _end(game,"off")
	if state != "racing": return
	# The marker over the rival.
	var camera: Camera3D = game.camera
	var shown := _screen(camera,r_pos)
	_hud.mark = {"at":shown.at,"on_screen":shown.on_screen,"dir":shown.dir,"far":r_pos.distance_to(player) > RaceHud.FAR,
		"text":"" if lead > 0.0 else "%d m" % roundi(maxf(gap,0.0)),"alpha":1.0}
	# The tag by the plane: the count, then what to do and the gap.
	var t := {"plane":_plane_screen(camera,player),"alpha":1.0}
	if go_t < GO_SHOW:
		t.count = COUNT-beat
		t.beat = fmod(race_t,COUNT_BEAT)/COUNT_BEAT if beat < COUNT else clampf(go_t/GO_SHOW,0.0,1.0)
		t.words = "head start" if beat < COUNT else "pass it, then hold the lead"
	else:
		t.big = "+%d m" % roundi(lead) if lead > 0.0 else "%d m" % roundi(maxf(gap,0.0))
		t.gold = lead > 0.0
		var words := "catch it"
		var warn := false
		if passing: words = "ahead · hold it"
		elif race_t-_drop_at < DROP_SAY:
			words = _drop_text
			warn = true
		elif lead > WIN_LEAD:
			words = "too wide · close on its line"
			warn = true
		elif lead > 0.0: words = "level · get clear of its nose"
		elif _behind > 0.0:
			words = "it's getting away"
			warn = true
		elif go_t < RULE_HOLD: words = "pass it, then hold the lead"
		var left := TIME_LIMIT-go_t
		if left < 20.0: words += "  ·  0:%02d" % ceili(left)
		t.words = words
		t.warn = warn
		t.lead = clampf(_ahead/WIN_HOLD,0.0,1.0) if passing or _ahead > 0.0 else -1.0
	_hud.tag = t

## The race clock's start: GO, after the count (s into the race).
static func go_at() -> float:
	return COUNT*COUNT_BEAT

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
	var plane: Dictionary = traffic.planes[rival]
	var clock := _clock_text(maxf(race_t-go_at(),0.0))
	var said := {"won":["RIVAL BEATEN","passed in %s" % clock],"lost":["IT GOT AWAY","it was %d m clear" % roundi(gap)],
		"time":["OUT OF TIME","%d m short" % roundi(maxf(gap,0.0))],"off":["RACE OFF",""]}
	_hud.say(String(said[why][0]),String(said[why][1]),why,NOTE_HOLD)
	if why == "won": _cue(game,"race-win",0.9,1.0,RUMBLE_WIN)
	elif why != "off": _cue(game,"race-lose",0.7,1.0,RUMBLE_LOSE)
	results.append({"why":why,"time":snappedf(race_t,0.01),"gap":roundi(gap),"history":(line.history as Array).duplicate(),"clips":int(line.clips),"clip_log":(line.clip_log as Array).duplicate()})
	print("rival race: %s after %.1f s, gap %.0f m, %d openings" % [why,race_t,gap,(line.history as Array).size()])
	line.start_peel(game.plane.position)
	line.pace = float(plane.cruise)
	_peel_left = RivalLine.PEEL_TIME
	_rest[rival] = _clock+REST
	state = "peeling"

## The peel done: back to the traffic's own flying, on a leg ahead.
func _release_rival(traffic: Node) -> void:
	if rival >= 0:
		var plane: Dictionary = traffic.planes[rival]
		plane.rival = null
		var flight: RefCounted = plane.flight
		plane.goal = traffic._leg(plane,flight.position,float(flight.heading))
		plane.turn = 0.0
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
	if state == "racing": return "\nrival race: plane %d, %.0f s, gap %.0f m, pace %.1f m/s, %d openings" % [rival,race_t,gap,float(line.pace),(line.history as Array).size()]
	return "\nrival race: %s%s" % [state,"" if offered < 0 else ", offering plane %d" % offered]
