extends Node3D
## A raider plane (greybox experiment, docs/design/endless-flight/
## raider-handoff.md): one dark plane that fights the player by ramming.
##
## `--raider` turns it on. A few seconds into a flight it shows up SPAWN_M m
## off, in view. It stalks (`stalk`): ahead of the plane it turns back onto the
## plane's line to meet it head-on, behind it closes on the tail. Lined up, it
## telegraphs (`tell`: TELL_S s of rocking wings, a red glow at its nose, the
## marker red and pulsing, a horn), then rams (`ram`): a lunge at RAM_OVER m/s
## over the plane's speed at where the plane will be, nearly straight
## (RAM_TURN), past it and on (`over`), then round for another pass. Head-on
## and tail runs alternate on their own: a head-on pass ends behind the plane,
## a tail run ends ahead of it.
##
## A ram that comes within HIT_R m of the plane, it not rolling, hits: a shove
## (SHOVE m/s), the nose knocked YAW rad off line, a one-turn tumble, the
## unbanked line lost and HIT_DRAIN of the meter gone (NearMiss `lose`); then
## it peels off (`peel`). A ram that misses within NEAR_R m (a barrel roll
## through it counts at any distance under NEAR_R) is a dodge: a ball's pass
## on the line (NearMiss `shot_pass`) and DODGE_FILL of the meter at once.
## A hot surge roll (scripts/endless/surge_smash.gd) within KILL_R m kills it
## (`try_kill`): it breaks apart, and REST s later (`--raider-every=S`) another
## shows up.
##
## It flies by the traffic planes' rules (scripts/sky_traffic.gd): the heading
## turns at a limited rate, the wings bank with the turn, it keeps CLEAR m
## over the ground ahead. The figure is a dark PlaneFigure.
##
## Tuning flags (each a number): --raider-every, --raider-ram (RAM_OVER),
## --raider-tell (TELL_S), --raider-hit (HIT_R), --raider-near (NEAR_R),
## --raider-shove (SHOVE), --raider-fill (DODGE_FILL), --raider-turn (TURN_MAX).
##
## `--raider-mode=` picks the fight. `dogfight` is the above alone. `chase`
## is the chase alone (scripts/endless/raider_chase.gd, state `flee`): it
## shows up ahead and runs low through trees and arches, and skimming builds
## the plane's speed. `mix` (the default) moves between them:
## - It shows up for the dogfight. After MIX_PASSES rams (hits, dodges and
##   misses alike) it breaks off the next time it's ahead of the plane or
##   abeam, within MIX_BREAK_M m and flying away from it, and runs (`flee`;
##   the marker reads "RUNS" for a moment).
## - Sat on its tail (ahead within MIX_TAIL_M m, the plane's nose within
##   MIX_TAIL_DEG of it) for MIX_TAILED_S s, it runs whatever the count: it
##   can't ram you from there.
## - Lost (the chase's rule: too far, or behind the view, for a while) after
##   MIX_GRACE s of running, or after MIX_CHASE_MOST s of running with the
##   plane more than MIX_NEAR_M m off, it turns and comes back at you: the
##   dogfight again, with a fresh count of passes. Lost sooner (it ran before
##   you could turn after it), it comes round ahead and runs again.
## - A kill ends either; the next one shows up for the dogfight.

const LaunchArgs = preload("res://scripts/launch_args.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const PlaneGroundScale = preload("res://scripts/plane_ground_scale.gd")
const SkyTraffic = preload("res://scripts/sky_traffic.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const RaiderChase = preload("res://scripts/endless/raider_chase.gd")

signal killed(at: Vector3)
signal rammed(at: Vector3)
signal dodged(at: Vector3, clear: float)

## Seconds of flight before the first one; between a kill and the next.
const FIRST_S := 4.0
const REST := 20.0
## Where it shows up: m off, degrees off the view's axis, m over the plane.
const SPAWN_M := 320.0
const SPAWN_OFF := 22.0
const SPAWN_UP := 12.0
## Its size against the player's plane.
const SIZE := 1.3
const LIVERY := {"body":Color("2b2a2e"),"dark":Color("141416"),"trim":Color("9c2a1e"),"wing":Color("3b3a40"),"wear":0.55}
## Flying: rad/s of turn at most, per rad off the aim, the ease (s), bank per
## rad/s of turn and the most it banks; pitch most (rad) and its rate (rad/s).
const TURN_MAX := 1.3
const TURN_GAIN := 2.0
const EASE_TURN := 0.25
const BANK := 0.9
const BANK_MAX := 1.2
const PITCH_MAX := 0.7
const PITCH_RATE := 0.9
## m over the ground ahead it keeps (samples m ahead), and the least in a ram.
const CLEAR := 22.0
const AHEAD := [0.0,40.0,90.0,150.0]
const RAM_FLOOR := 4.0
## Stalking: m/s over the plane's speed far and near, the least s between
## passes, the most before it takes any line it has, how far behind the tail
## it sets up (m), how far off it's lost (m) and for how long (s).
const STALK_FAR := 28.0
const STALK_NEAR := 10.0
const STALK_LEAST := 1.6
const STALK_MOST := 9.0
const TAIL_SET := 90.0
const LOST_M := 950.0
const LOST_S := 3.0
## Lining up: a head-on run starts between HEAD_M m (least, most) with the nose
## within HEAD_DEG of the meeting point; a tail run within TAIL_M, TAIL_DEG.
## After STALK_MOST, within ANY_M and ANY_DEG.
const HEAD_M := Vector2(140.0,340.0)
const HEAD_DEG := 35.0
const TAIL_M := Vector2(40.0,160.0)
const TAIL_DEG := 28.0
const ANY_M := 380.0
const ANY_DEG := 75.0
## The tell: seconds, the wing rock (rad, Hz), its turn onto the line (rad/s).
const TELL_S := 0.9
const TELL_ROCK := Vector2(0.45,4.0)
const TELL_TURN := 2.2
## The ram: m/s over the plane's speed (and the least), its turn while far (rad/s;
## none within RAM_STRAIGHT m), the most s, and how long it overshoots (s).
const RAM_OVER := 45.0
const RAM_LEAST := 75.0
const RAM_TURN := 0.2
const RAM_STRAIGHT := 50.0
const RAM_MOST := 4.0
const OVER_S := 1.3
## A hit: within HIT_R m; speed kept, the shove (m/s), the nose off line (rad),
## the tumble (turns, s), the meter drained, the view's shake and punch.
const HIT_R := 6.0
const HIT_KEEP := 0.8
const SHOVE := 14.0
const YAW := 0.35
const TUMBLE := Vector2(1.0,0.7)
const HIT_DRAIN := 0.4
const HIT_FEEL := Vector2(0.04,12.0)
## A dodge: within NEAR_R m; the meter's fill at the edge and at a touch, and
## a barrel roll's on top.
const NEAR_R := 18.0
const DODGE_FILL := Vector2(0.2,0.38)
const ROLL_FILL := 0.08
## Peeling off after a hit: s, climb (m/s of the aim over).
const PEEL_S := 3.0
## A hot surge roll within KILL_R m of it kills it.
const KILL_R := 10.0

## The mix: rams before it breaks off and runs (picked between the two each
## time), how near ahead it breaks off (m), and the longest run (s).
const MIX_PASSES := Vector2i(2,3)
const MIX_BREAK_M := Vector2(40.0,450.0)
const MIX_TAIL_M := 220.0
const MIX_TAIL_DEG := 30.0
const MIX_TAILED_S := 4.0
const MIX_CHASE_MOST := 30.0
const MIX_NEAR_M := 150.0
const MIX_AWAY := 0.2
const MIX_GRACE := 10.0
const MIX_ABEAM := 0.2
const RUNS_S := 1.6
## The broken plane: pieces, their speed out (m/s), life (s).
const PIECES := 16
const PIECE_OUT := 22.0
const PIECE_LIFE := 3.2
const GRAVITY := 22.0

var game: Node3D
var figure: Node3D
var flight: SkyTraffic.Flight
## away, stalk, tell, ram, over, peel, dead
var state := &"away"
var t := 0.0
var turn := 0.0
var speed := 0.0
## The next attack's kind (head, tail) and its direction once locked.
var kind := &""
var ram_dir := Vector3.FORWARD
## Counted, for the drivers.
var stats := {"spawns":0,"tells":0,"rams":0,"hits":0,"dodges":0,"misses":0,"kills":0,"head":0,"tail":0,"breaks":0,"returns":0}
## The last ram's closest pass (m), and whether the plane was rolling at it.
var least := INF
var least_rolled := false
var least_at := Vector3.ZERO
## The closest the plane came over the last frame (m), for `try_kill`.
var sweep := INF
var tuning := {}
## The fight: &"dogfight", &"chase" or &"mix" (`--raider-mode=`).
var mode := &"mix"
## The chase (null in the dogfight alone).
var chase: RefCounted
## The mix: rams flown since the dogfight began, and how many before it runs.
var passes := 0
var passes_want := 3
## The mix: seconds the plane has sat on its tail.
var tailed := 0.0
## The mix: seconds run with the plane not near.
var run_t := 0.0
var _rounds_seen := 0

var _wait := FIRST_S
var _lost := 0.0
var _clock := 0.0
var _prev := Vector3.INF
var _plane_prev := Vector3.INF
var _glow: MeshInstance3D
var _glow_mat: StandardMaterial3D
var _pieces: Array[Dictionary] = []
var _flash: MeshInstance3D
var _flash_t := INF
var _layer: CanvasLayer
var _mark: Control
var _rng := RandomNumberGenerator.new()

static func wanted() -> bool:
	return "--raider" in LaunchArgs.user_args()

static func mode_of(args: PackedStringArray) -> StringName:
	for a: String in args:
		if a.begins_with("--raider-mode="):
			var m := StringName(a.trim_prefix("--raider-mode="))
			if m in [&"dogfight",&"chase",&"mix"]: return m
	return &"mix"

static func _flag(flag: String, default: float) -> float:
	for a: String in LaunchArgs.user_args():
		if a.begins_with(flag+"="): return maxf(float(a.trim_prefix(flag+"=")),0.0)
	return default

func _init() -> void:
	name = "Raider"

func setup(g: Node3D) -> void:
	game = g
	_rng.seed = 4401
	tuning = {"every":_flag("--raider-every",REST),"ram":_flag("--raider-ram",RAM_OVER),
		"tell":maxf(_flag("--raider-tell",TELL_S),0.1),"hit":_flag("--raider-hit",HIT_R),
		"near":_flag("--raider-near",NEAR_R),"shove":_flag("--raider-shove",SHOVE),
		"fill":_flag("--raider-fill",DODGE_FILL.y),"turn":_flag("--raider-turn",TURN_MAX)}
	flight = SkyTraffic.Flight.new()
	mode = mode_of(LaunchArgs.user_args())
	if mode != &"dogfight": chase = RaiderChase.new(self)
	figure = PlaneFigure.new(LIVERY)
	figure.name = "RaiderPlane"
	figure.visible = false
	add_child(figure)
	figure.add_to_group(&"lock_on")  # a lock-on target (scripts/endless/lock_on.gd)
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.albedo_color = Color(1.0,0.3,0.05,0.0)
	_glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glow_mat.no_depth_test = false
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 16
	ball.rings = 8
	_glow = MeshInstance3D.new()
	_glow.mesh = ball
	_glow.material_override = _glow_mat
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow.visible = false
	add_child(_glow)
	_flash = MeshInstance3D.new()
	_flash.mesh = ball
	var fm := _glow_mat.duplicate() as StandardMaterial3D
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.albedo_color = Color(1.0,0.55,0.2,1.0)
	_flash.material_override = fm
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false
	add_child(_flash)
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_mark = Marker.new()
	_layer.add_child(_mark)

func alive() -> bool:
	return state != &"away" and state != &"dead"

## One frame, after the plane's: the raider flown, a ram's hit or dodge
## settled into `events` (as a ball's hit, pirate_ship.gd).
func step(delta: float, g: Node3D, events: Dictionary) -> void:
	game = g
	_clock += delta
	_pieces_step(delta)
	var plane = game.plane
	var flying: bool = game.hand_landing.flying()
	match state:
		&"away", &"dead":
			if flying:
				_wait -= delta
				if _wait <= 0.0: _spawn()
			if chase != null: chase.idle()
			_hud(false)
			_prev = Vector3.INF
			return
	var p: Vector3 = plane.position
	var rel: Vector3 = flight.position-p
	var dist := rel.length()
	var ps := maxf(float(plane.speed),float(plane.cruise()))
	t += delta
	match state:
		&"stalk": _stalk(delta,p,rel,dist,ps,flying)
		&"flee":
			chase.step(delta,p,rel,dist,ps)
			if dist > MIX_NEAR_M: run_t += delta
			if mode == &"mix":
				# Lost early (it ran before you could turn after it), it comes round
				# ahead and runs again (the chase's own way); lost later, it fights.
				var lost_now: bool = int(chase.stats.rounds) > _rounds_seen
				_rounds_seen = int(chase.stats.rounds)
				if (lost_now and t > MIX_GRACE) or run_t > MIX_CHASE_MOST: _fight()
		&"tell": _tell(delta,p,ps)
		&"ram": _ram(delta,p,rel,dist,ps)
		&"over":
			_fly_to(flight.position+ram_dir*100.0,delta,tuning.turn*0.5,lerpf(speed,ps+STALK_NEAR,minf(t/OVER_S,1.0)))
			if _breaks_off(rel,dist): _run()
			elif t >= OVER_S: _go(&"stalk")
		&"peel":
			var away := Vector3(rel.x,0.0,rel.z).normalized() if dist > 1.0 else Vector3.FORWARD
			_fly_to(flight.position+away*120.0+Vector3.UP*40.0,delta,tuning.turn,ps+STALK_FAR)
			if t >= PEEL_S: _go(&"stalk")
	# The closest pass over the frame, both moving.
	sweep = rel.length()
	if _prev != Vector3.INF and _plane_prev != Vector3.INF:
		var r0 := _prev-_plane_prev
		var r1 := flight.position-p
		sweep = _seg_least(r0,r1)
	if state == &"ram": _settle(sweep,p,events)
	_prev = flight.position
	_plane_prev = p
	_draw_figure(delta)
	_hud(true)

func _go(s: StringName) -> void:
	state = s
	t = 0.0

func _spawn() -> void:
	var plane = game.plane
	var p: Vector3 = plane.position
	var cam: Camera3D = game.camera
	var look := -cam.global_basis.z
	var flat := Vector3(look.x,0.0,look.z)
	if flat.length() < 0.1: flat = Vector3(plane.forward().x,0.0,plane.forward().z)
	flat = flat.normalized()
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	var way := flat.rotated(Vector3.UP,deg_to_rad(SPAWN_OFF)*side)
	var at := p+way*SPAWN_M
	at.y = maxf(p.y+SPAWN_UP,_floor_at(at,Vector3.ZERO))
	flight.position = at
	# Facing back across the plane's line, so it comes round onto it.
	var back := (p-at).normalized().rotated(Vector3.UP,deg_to_rad(50.0)*side)
	flight.heading = atan2(-back.x,-back.z)
	flight.pitch = 0.0
	flight.bank = 0.0
	flight.spin = 0.0
	speed = maxf(float(plane.speed),float(plane.cruise()))
	flight.speed = speed
	flight.velocity = flight.forward()*speed
	turn = 0.0
	_lost = 0.0
	_prev = Vector3.INF
	figure.visible = true
	figure.update(0.0,flight,0.0,Callable(),false)
	PlaneGroundScale.grow(figure,WorldScale.plane*SIZE)
	figure.reset(flight)
	stats.spawns = int(stats.spawns)+1
	_count_from()
	if mode == &"chase":
		chase.spawn()
		figure.reset(flight)
		_prev = Vector3.INF
		_go(&"flee")
		return
	_go(&"stalk")

# --- The mix ------------------------------------------------------------------

## A fresh count of passes before it runs.
func _count_from() -> void:
	passes = 0
	tailed = 0.0
	passes_want = _rng.randi_range(MIX_PASSES.x,MIX_PASSES.y)

## Off the dogfight: it runs from where it flies.
func _run() -> void:
	stats.breaks = int(stats.breaks)+1
	run_t = 0.0
	chase.begin()
	_rounds_seen = int(chase.stats.rounds)
	game.sound.shot("whoosh",0.8,0.7,flight.position)
	_go(&"flee")

## The mix's break-off: its passes flown, within MIX_BREAK_M m, ahead of the
## plane or abeam (no more than MIX_ABEAM behind; in front of the camera) and
## flying away from it (as a tail run's overshoot, or coming round wide).
func _breaks_off(rel: Vector3, dist: float) -> bool:
	if mode != &"mix" or passes < passes_want or dist < MIX_BREAK_M.x or dist > MIX_BREAK_M.y: return false
	var fwd: Vector3 = game.plane.forward()
	var flat := Vector3(fwd.x,0.0,fwd.z).normalized()
	if rel.dot(flat) < -MIX_ABEAM*dist: return false
	if (game.camera as Camera3D).is_position_behind(flight.position): return false
	return flight.forward().dot(rel/maxf(dist,0.1)) > MIX_AWAY

## Off the chase: it turns and comes back at you.
func _fight() -> void:
	stats.returns = int(stats.returns)+1
	chase.idle()
	_count_from()
	_lost = 0.0
	_go(&"stalk")

# --- The passes ---------------------------------------------------------------

func _stalk(delta: float, p: Vector3, rel: Vector3, dist: float, ps: float, flying: bool) -> void:
	var plane = game.plane
	var fwd: Vector3 = plane.forward()
	var pf := Vector3(fwd.x,0.0,fwd.z).normalized()
	var ahead := rel.dot(pf) > 0.0
	var aim: Vector3
	if ahead: aim = p+pf*clampf(dist*0.5,60.0,300.0)
	else: aim = p-pf*TAIL_SET+(plane.velocity as Vector3)*0.5
	aim.y = p.y
	_fly_to(aim,delta,tuning.turn,ps+(STALK_FAR if dist > 350.0 else STALK_NEAR))
	# Lost far behind: back in view.
	_lost = _lost+delta if dist > LOST_M else 0.0
	if _lost > LOST_S:
		_spawn()
		return
	if not flying: return
	if mode == &"mix":
		var on_tail := ahead and dist < MIX_TAIL_M and fwd.dot(rel/maxf(dist,0.1)) > cos(deg_to_rad(MIX_TAIL_DEG))
		tailed = tailed+delta if on_tail else 0.0
		if _breaks_off(rel,dist) or tailed > MIX_TAILED_S:
			_run()
			return
	if t < STALK_LEAST: return
	var meet := _meet(p,ps+float(tuning.ram))
	var nose: Vector3 = flight.forward()
	var on := nose.dot((meet-flight.position).normalized())
	if ahead and dist > HEAD_M.x and dist < HEAD_M.y and on > cos(deg_to_rad(HEAD_DEG)): _tell_start(&"head")
	elif not ahead and dist > TAIL_M.x and dist < TAIL_M.y and on > cos(deg_to_rad(TAIL_DEG)): _tell_start(&"tail")
	elif t > STALK_MOST and dist < ANY_M and on > cos(deg_to_rad(ANY_DEG)): _tell_start(&"head" if ahead else &"tail")

func _tell_start(k: StringName) -> void:
	kind = k
	stats.tells = int(stats.tells)+1
	stats[str(k)] = int(stats[str(k)])+1
	game.sound.shot("whoosh",0.9,0.45,flight.position)
	_go(&"tell")

func _tell(delta: float, p: Vector3, ps: float) -> void:
	var meet := _meet(p,ps+float(tuning.ram))
	_fly_to(meet,delta,TELL_TURN,ps*0.95,true)
	if t >= float(tuning.tell):
		ram_dir = (meet-flight.position).normalized()
		speed = maxf(ps+float(tuning.ram),RAM_LEAST)
		least = INF
		least_rolled = false
		stats.rams = int(stats.rams)+1
		game.sound.shot("swish",1.0,0.6,flight.position)
		_go(&"ram")

func _ram(delta: float, p: Vector3, rel: Vector3, dist: float, ps: float) -> void:
	var rs := maxf(ps+float(tuning.ram),RAM_LEAST)
	if dist > RAM_STRAIGHT:
		var want := (_meet(p,rs)-flight.position).normalized()
		var a := ram_dir.angle_to(want)
		if a > 0.0001: ram_dir = ram_dir.slerp(want,minf(RAM_TURN*delta/a,1.0)).normalized()
	speed = rs
	_set_dir(ram_dir,delta)
	flight.velocity = ram_dir*speed
	flight.position += flight.velocity*delta
	var ground := _ground_at(flight.position)
	flight.position.y = maxf(flight.position.y,ground+RAM_FLOOR)
	flight.speed = speed
	# Past the plane and going away, or out of time: over.
	var past := rel.dot(ram_dir) > 0.0 and dist > least+8.0
	if past or t > RAM_MOST: _ram_over(p)

## The pass settled as it comes: a hit at once, a dodge when it's past.
func _settle(d: float, p: Vector3, events: Dictionary) -> void:
	if d < least:
		least = d
		least_rolled = bool(game.plane.rolling)
		least_at = p
	var hot: bool = game.smash != null and bool(game.smash.hot)
	if d < float(tuning.hit) and not bool(game.plane.rolling) and not hot: _hit(p,events)

func _ram_over(p: Vector3) -> void:
	if least < float(tuning.near) or (least_rolled and least < float(tuning.near)*1.5):
		_dodge(least_at)
	else:
		stats.misses = int(stats.misses)+1
	passes += 1
	_go(&"over")

func _dodge(at: Vector3) -> void:
	stats.dodges = int(stats.dodges)+1
	var near := float(tuning.near)
	var k := clampf(1.0-least/near,0.0,1.0)
	var fill := lerpf(DODGE_FILL.x*float(tuning.fill)/DODGE_FILL.y,float(tuning.fill),k)
	if least_rolled: fill += ROLL_FILL
	game.near.meter = minf(1.0,float(game.near.meter)+fill)
	var clear := maxf(least-WorldScale.span*0.5*(1.0+SIZE),0.0)
	game.near.shot_pass(clear,near,at)
	game.sound.shot("whoosh",1.0,1.2,flight.position)
	game.feel_hit(0.012,4.0)
	dodged.emit(at,least)

func _hit(p: Vector3, events: Dictionary) -> void:
	stats.hits = int(stats.hits)+1
	var plane = game.plane
	var flat := Vector3(ram_dir.x,0.0,ram_dir.z)
	flat = flat.normalized() if flat.length() > 0.1 else Vector3.ZERO
	var fwd: Vector3 = plane.forward()
	var side := 1.0 if fwd.cross(flat).y >= 0.0 else -1.0
	var speed_was := float(plane.speed)
	plane.knock(HIT_KEEP,flat*float(tuning.shove)+Vector3.UP*3.0,YAW*side)
	plane.surge_roll(-side,TUMBLE.x,TUMBLE.y)
	var lost: float = game.near.lose()
	if lost > 0.0: events["lost"] = {"points":lost}
	game.near.meter = maxf(0.0,float(game.near.meter)-HIT_DRAIN)
	events["scrape"] = {"at":p,"normal":-ram_dir,"what":"stone","into":float(tuning.shove),"angle":0.5,"speed":speed_was,"keep":HIT_KEEP}
	game.debris.hit("stone",p,-ram_dir)
	game.feel_hit(HIT_FEEL.x,HIT_FEEL.y)
	game.sound.shot("crash",1.0,0.9)
	game.sound.shot("thump",1.0,0.8)
	rammed.emit(p)
	passes += 1
	_go(&"peel")

## Each frame of a hot surge roll (SurgeSmash `before`): the plane within
## KILL_R of it, now or over the last frame, kills it. Where it broke, or INF.
func try_kill(g: Node3D) -> Vector3:
	game = g
	if not alive() or figure == null: return Vector3.INF
	var p: Vector3 = game.plane.position
	var d := minf(sweep,flight.position.distance_to(p))
	if d > KILL_R: return Vector3.INF
	var at: Vector3 = flight.position
	_break(at)
	return at

func _break(at: Vector3) -> void:
	stats.kills = int(stats.kills)+1
	var v: Vector3 = flight.velocity
	var pv: Vector3 = game.plane.velocity
	figure.visible = false
	_glow.visible = false
	for i in PIECES:
		var m := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(_rng.randf_range(0.25,0.8),_rng.randf_range(0.06,0.2),_rng.randf_range(0.25,0.7))*SIZE
		m.mesh = box
		var mat := StandardMaterial3D.new()
		mat.emission_enabled = true
		mat.emission = Color(0.12,0.1,0.1)
		mat.albedo_color = (LIVERY.trim as Color) if i%3 == 0 else Color(0.32,0.31,0.34)
		m.material_override = mat
		add_child(m)
		var lead := pv.normalized()*6.0 if pv.length() > 1.0 else Vector3.ZERO
		m.global_position = at+lead+Vector3(_rng.randf_range(-1,1),_rng.randf_range(-0.5,0.5),_rng.randf_range(-1,1))*1.5
		# Out to the sides and up, ahead of the plane: none thrown back at the view.
		var out := Vector3(_rng.randf_range(-1,1),_rng.randf_range(-0.2,1),_rng.randf_range(-1,1)).normalized()
		var ahead := pv.normalized() if pv.length() > 1.0 else Vector3.ZERO
		out = (out-ahead*minf(out.dot(ahead),0.0)+ahead*0.4).normalized()
		_pieces.append({"node":m,"v":pv*1.1+out*PIECE_OUT*_rng.randf_range(0.5,1.0),
			"spin":Vector3(_rng.randf_range(-9,9),_rng.randf_range(-9,9),_rng.randf_range(-9,9)),"life":PIECE_LIFE})
	_flash.global_position = at
	_flash.visible = true
	_flash_t = 0.0
	game.debris.burst("wood",at,-v.normalized() if v.length() > 1.0 else Vector3.UP,true)
	game.debris.burst("dust",at,Vector3.UP,true)
	killed.emit(at)
	_wait = float(tuning.every)
	_go(&"dead")

func _pieces_step(delta: float) -> void:
	if _flash_t != INF:
		_flash_t += delta
		var k := _flash_t/0.4
		_flash.scale = Vector3.ONE*lerpf(2.0,11.0,minf(k,1.0))
		(_flash.material_override as StandardMaterial3D).albedo_color.a = 0.7*maxf(1.0-k,0.0)
		if k >= 1.0:
			_flash.visible = false
			_flash_t = INF
	for i in range(_pieces.size()-1,-1,-1):
		var pc: Dictionary = _pieces[i]
		pc.life = float(pc.life)-delta
		var n := pc.node as MeshInstance3D
		if float(pc.life) <= 0.0:
			n.queue_free()
			_pieces.remove_at(i)
			continue
		var v: Vector3 = pc.v
		v.y -= GRAVITY*delta
		v *= exp(-0.4*delta)
		pc.v = v
		n.global_position += v*delta
		var ground := _ground_at(n.global_position)
		if n.global_position.y < ground:
			n.global_position.y = ground
			pc.v = Vector3(v.x*0.4,absf(v.y)*0.2,v.z*0.4)
		n.rotation += (pc.spin as Vector3)*delta
		# Not in the view's face.
		n.visible = (game.camera as Camera3D).global_position.distance_to(n.global_position) > 4.0
		if float(pc.life) < 0.5: n.scale = Vector3.ONE*maxf(float(pc.life)/0.5,0.01)

# --- Flying -------------------------------------------------------------------

## Where the plane will be when a ram at `rs` m/s from here meets it.
func _meet(p: Vector3, rs: float) -> Vector3:
	var pv: Vector3 = game.plane.velocity
	var at := p
	for i in 3:
		var tt := flight.position.distance_to(at)/maxf(rs,1.0)
		at = p+pv*minf(tt,4.0)
	return at

## Steers toward `aim` at `pace` m/s: the heading at a limited rate, the
## wings banked with it, the nose toward the aim's height over the floor.
func _fly_to(aim: Vector3, delta: float, turn_max: float, pace: float, rock := false) -> void:
	var to := aim-flight.position
	var want := atan2(-to.x,-to.z)
	var rate := clampf(angle_difference(flight.heading,want)*TURN_GAIN,-turn_max,turn_max)
	turn = lerpf(turn,rate,_ease(EASE_TURN,delta))
	flight.heading = wrapf(flight.heading+turn*delta,-PI,PI)
	flight.bank = clampf(-turn*BANK,-BANK_MAX,BANK_MAX)
	if rock: flight.bank += sin(t*TAU*TELL_ROCK.y)*TELL_ROCK.x
	var flat := Vector2(to.x,to.z).length()
	var floor_y := _floor_at(flight.position,flight.forward())
	var want_y := maxf(aim.y,floor_y)
	var pitch := clampf(atan2(want_y-flight.position.y,maxf(flat,30.0)),-PITCH_MAX,PITCH_MAX)
	if flight.position.y < floor_y: pitch = maxf(pitch,0.35)
	flight.pitch = move_toward(flight.pitch,pitch,PITCH_RATE*delta)
	speed = lerpf(speed,pace,_ease(1.0,delta))
	flight.speed = speed
	flight.velocity = flight.forward()*speed
	flight.position += flight.velocity*delta
	flight.position.y = maxf(flight.position.y,_ground_at(flight.position)+RAM_FLOOR)

## Heading and pitch onto `dir` (a ram's line), the wings levelling.
func _set_dir(dir: Vector3, delta: float) -> void:
	var want := atan2(-dir.x,-dir.z)
	var d := angle_difference(flight.heading,want)
	flight.heading = wrapf(flight.heading+clampf(d,-TELL_TURN*delta,TELL_TURN*delta),-PI,PI)
	flight.pitch = move_toward(flight.pitch,asin(clampf(dir.y,-1.0,1.0)),PITCH_RATE*2.0*delta)
	turn = 0.0
	flight.bank = lerpf(flight.bank,0.0,_ease(0.15,delta))

func _ground_at(at: Vector3) -> float:
	return maxf(float(game.field.height(at.x,at.z)),float(game.water_at(at)))

## The height it keeps here: CLEAR over the ground ahead.
func _floor_at(at: Vector3, fwd: Vector3) -> float:
	var flat := Vector3(fwd.x,0.0,fwd.z)
	flat = flat.normalized() if flat.length() > 0.01 else Vector3.ZERO
	var top := -INF
	for a: float in AHEAD: top = maxf(top,_ground_at(at+flat*a))
	return top+CLEAR

func _draw_figure(delta: float) -> void:
	figure.update(delta,flight,0.0,Callable(),false,0.0,flight.bank)
	PlaneGroundScale.grow(figure,WorldScale.plane*SIZE)
	var glow := 0.0
	if state == &"tell": glow = clampf(t/float(tuning.tell),0.0,1.0)*(0.75+0.25*sin(t*TAU*8.0))
	elif state == &"ram": glow = 0.45
	_glow.visible = glow > 0.01
	if _glow.visible:
		_glow.global_position = flight.position+flight.forward()*2.0*SIZE
		# Never under about a hundredth of the distance, so it reads far off.
		var far := (game.camera as Camera3D).global_position.distance_to(flight.position)*0.022
		_glow.scale = Vector3.ONE*maxf(lerpf(1.0,3.5,glow)*SIZE,far*glow)
		_glow_mat.albedo_color.a = 0.8*glow

static func _seg_least(a: Vector3, b: Vector3) -> float:
	var d := b-a
	var l := d.length_squared()
	if l < 0.000001: return a.length()
	var k := clampf(-a.dot(d)/l,0.0,1.0)
	return (a+d*k).length()

static func _ease(seconds: float, delta: float) -> float:
	return 1.0-exp(-delta/maxf(seconds,0.001))

# --- The marker ---------------------------------------------------------------

func _hud(on: bool) -> void:
	var m := _mark as Marker
	if not on or game.camera == null:
		m.on = false
		m.queue_redraw()
		return
	var cam: Camera3D = game.camera
	var at: Vector3 = flight.position+Vector3.UP*3.0*SIZE
	var size := m.get_viewport_rect().size
	if size.x < Marker.EDGE*4.0 or size.y < Marker.EDGE*4.0:
		m.on = false
		return
	var mid := size*0.5
	var behind := cam.is_position_behind(at)
	var sp := cam.unproject_position(at)
	if behind: sp = mid-(sp-mid)*1000.0
	var inset := Rect2(Vector2.ONE*Marker.EDGE,size-Vector2.ONE*Marker.EDGE*2.0)
	m.on = true
	m.on_screen = not behind and inset.has_point(sp)
	m.dir = (sp-mid).normalized() if (sp-mid).length() > 0.5 else Vector2.UP
	if m.on_screen: m.at = sp
	else:
		var hx := mid.x-Marker.EDGE
		var hy := mid.y-Marker.EDGE
		var k := minf(hx/maxf(absf(m.dir.x),0.001),hy/maxf(absf(m.dir.y),0.001))
		m.at = mid+m.dir*k
	m.tell = state == &"tell" or state == &"ram"
	m.pulse = _clock
	m.text = "%d m" % int(flight.position.distance_to(game.plane.position))
	if state == &"tell": m.text = "RAM!"
	elif state == &"flee" and mode == &"mix" and t < RUNS_S: m.text = "RUNS"
	m.queue_redraw()

class Marker extends Control:
	const EDGE := 40.0
	var on := false
	var on_screen := true
	var at := Vector2.ZERO
	var dir := Vector2.UP
	var tell := false
	var pulse := 0.0
	var text := ""

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if not on: return
		var col := Color(0.95,0.22,0.12,0.9)
		var s := 12.0
		if tell:
			var k := 0.5+0.5*sin(pulse*TAU*6.0)
			col = Color(1.0,0.2+0.3*k,0.1,1.0)
			s = 16.0+6.0*k
		var font := ThemeDB.fallback_font
		if on_screen:
			var p := at+Vector2(0.0,-10.0)
			var w := PackedVector2Array([p,p+Vector2(-s*0.7,-s),p+Vector2(s*0.7,-s),p])
			draw_polyline(w,Color(0.05,0.03,0.03,0.8),4.0)
			draw_colored_polygon(w,col)
			_label(font,p+Vector2(-60.0,-s-8.0),col)
		else:
			var n := Vector2(-dir.y,dir.x)
			var tip := at+dir*s*0.5
			var w := PackedVector2Array([tip,tip-dir*s*1.4+n*s*0.8,tip-dir*s*1.4-n*s*0.8,tip])
			draw_polyline(w,Color(0.05,0.03,0.03,0.8),4.0)
			draw_colored_polygon(w,col)
			_label(font,at-dir*s*2.6+Vector2(-60.0,6.0),col)

	func _label(font: Font, p: Vector2, col: Color) -> void:
		var size := 22 if tell else 18
		draw_string_outline(font,p,text,HORIZONTAL_ALIGNMENT_CENTER,120.0,size,5,Color(0.05,0.03,0.03,0.8))
		draw_string(font,p,text,HORIZONTAL_ALIGNMENT_CENTER,120.0,size,col)
