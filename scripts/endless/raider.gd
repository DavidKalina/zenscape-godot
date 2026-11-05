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
## A hot surge roll (scripts/endless/surge_smash.gd) within KILL_R m (KILL_FLEE
## while it runs) kills it (`try_kill`): it breaks apart, and REST s later
## (`--raider-every=S`) another shows up.
##
## It flies by the traffic planes' rules (scripts/sky_traffic.gd): the heading
## turns at a limited rate, the wings bank with the turn, it keeps CLEAR m
## over the ground ahead. The figure is a PlaneFigure in wasp colours (LIVERY),
## a red ribbon trailing its tail (RIBBON_*).
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
##   MIX_TAIL_DEG of it, it flying away) for MIX_TAILED_S s, it runs whatever
##   the count: it can't ram you from there. Turning back for a head-on isn't
##   counted, so it gets its pass in.
## - Lost (the chase's rule: too far, or behind the view, for a while) after
##   MIX_GRACE s of running, or after MIX_CHASE_MOST s of running with the
##   plane more than MIX_NEAR_M m off, it turns and comes back at you: the
##   dogfight again, with a fresh count of passes. Lost sooner (it ran before
##   you could turn after it), it comes round ahead and runs again.
## - A kill ends either; the next one shows up for the dogfight.
##
## `chase` is the default (spec-raider-embers.md): each one arrives by a buzz
## (raider_chase.gd `buzz`: from behind, close overhead or beside, a whoosh)
## and runs. Locked on (lock_on.gd), it's `chased`. Round 2: no come-round;
## behind past GETAWAY_M for GETAWAY_S s it's gone, chased or not. Not chased and more than LET_GO_M m off
## (`--raider-let-go=M`) or out of view LET_GO_S s (`--raider-let-go-s=S`),
## it's gone for good (`_leave`), and the next buzzes in GAP s later
## (`--raider-gap=S`; a kill waits the same). In the chase it has no marker
## off screen: no arrow at the view's edge. While it runs it fires embers back
## at the plane (raider_embers.gd: --raider-ember-every, --raider-ember-speed,
## --raider-ember-seek), through the parry: it's a `parry_source`.

const LaunchArgs = preload("res://scripts/launch_args.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const PlaneGroundScale = preload("res://scripts/plane_ground_scale.gd")
const SkyTraffic = preload("res://scripts/sky_traffic.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const RaiderChase = preload("res://scripts/endless/raider_chase.gd")
const RaiderEmbers = preload("res://scripts/endless/raider_embers.gd")
const BodyDust = preload("res://scripts/breaks/body_dust.gd")
const FacetMesh = preload("res://scripts/facet_mesh.gd")

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
## Wasp colours (spec round 2 item 6): yellow wings and a black body, red
## trim, so it stands off rock, grass and sky; unlike the wanderer's rust,
## teal and cream.
const LIVERY := {"body":Color("1d1c20"),"dark":Color("0e0e10"),"trim":Color("e0281c"),"wing":Color("ffc21f"),"wear":0.2}
## Its ribbon: a coloured strip trailing its tail, to read its line far off
## and follow it. RIBBON points laid every RIBBON_EVERY s (so it trails
## RIBBON*RIBBON_EVERY s of its line), its width at the tail and the end
## (m, times SIZE), never under RIBBON_PX m per m from the eye (so it keeps
## a few pixels far off), its colour and alpha at the tail.
const RIBBON := 30
const RIBBON_EVERY := 0.05
const RIBBON_W := Vector2(1.8,0.5)
const RIBBON_PX := 0.006
const RIBBON_COLOR := Color(1.0,0.12,0.26,1.0)
## Faded inside these (m from the eye), so a ribbon you fly down doesn't
## sweep across the view.
const RIBBON_FADE := Vector2(6.0,30.0)
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
## The kill's reach while it runs (`flee`): it flies a few m over the crowns
## and the plane comes at it from behind and above, so a little more, and
## height off it counts FLEE_UP of itself (a surge over it reaches it).
const KILL_FLEE := 14.0
const FLEE_UP := 0.6

## The mix: rams before it breaks off and runs (picked between the two each
## time), how near ahead it breaks off (m), and the longest run (s).
## The chase let go: m off, s out of view (not locked on), before it's gone.
const LET_GO_M := 550.0
const LET_GO_S := 4.0
## Round 2 (spec-raider-embers.md, round 2): on its tail is the plane within
## ON_TAIL_M m behind it (`--raider-tail-m=`), its nose within ON_TAIL_DEG of it
## (`--raider-tail-deg=`), held TAIL_HOLD s after it slips off. On its tail it
## panics: it fires embers and jinks (raider_chase.gd). It keeps KEEP_M m
## ahead (`--raider-keep-near=`, `--raider-keep-far=`); behind past GETAWAY_M
## m (`--raider-getaway=`) for GETAWAY_S s (`--raider-getaway-s=`) it gets
## away for good, locked on or not. A parried ember home on it staggers it:
## no panic for STAGGER_S s (`--raider-stagger=`).
const ON_TAIL_M := 80.0
const ON_TAIL_DEG := 30.0
const TAIL_HOLD := 0.5
const KEEP_M := Vector2(40.0,150.0)
const GETAWAY_M := 200.0
const GETAWAY_S := 3.0
const STAGGER_S := 1.2

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
## Running (`flee`), a faint glow at its tail so it reads far off against
## the trees (the dark body alone is a speck past about 80 m).
const FLEE_GLOW := 0.3
const FLEE_GLOW_NEAR := 50.0

## The slow (spec-raider-embers.md item 4): each parried ember home on it
## takes SLOW off its pace (a fraction, `--raider-slow=`), stacked, held
## SLOW_S s after the last (`--raider-slow-s=`), then it shakes them all off.
## At HIT_CAP hits (`--raider-hit-cap=`) it's crippled for good: slowed by
## the cap, flown CRIPPLED_LOW times its low height, smoking hard. It
## trails smoke while slowed (SMOKE_*: particles, life s, size m).
const SLOW := 0.12
const SLOW_S := 4.0
const HIT_CAP := 3
const CRIPPLED_LOW := 0.75
const SMOKE_LIFE := 3.2
const SMOKE := {"amount":90,"size":3.2,"color":Color(0.5,0.49,0.5,0.8)}
const SMOKE_HARD := {"amount":160,"size":4.6,"color":Color(0.08,0.07,0.07,0.95)}

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
var mode := &"chase"
## The chase (null in the dogfight alone).
var chase: RefCounted
## Its embers in the chase (raider_embers.gd), null in the dogfight.
var embers: RefCounted
## The mix: rams flown since the dogfight began, and how many before it runs.
var passes := 0
var passes_want := 3
## The mix: seconds the plane has sat on its tail.
var tailed := 0.0
## The mix: seconds run with the plane not near.
var run_t := 0.0
var _rounds_seen := 0
## The chase: locked on, or the lock lost to distance or sight (not let go by
## a press). Chased, a lost raider comes round; else it leaves.
var chased := false
var _unseen_t := 0.0
## Round 2: the plane on its tail (held TAIL_HOLD s past slipping off), the
## seconds since it last was, the stagger's clock, the getaway's.
var on_tail := false
var _off_tail := INF
var stagger_t := 0.0
var _away_t := 0.0
## The slow: parried embers home on it now (to the cap), seconds the slow
## still holds (crippled at the cap: held for good).
var hits_home := 0
var slow_t := 0.0
var _smoke: CPUParticles3D
var _smoke_hard: CPUParticles3D

var _wait := FIRST_S
var _lost := 0.0
var _clock := 0.0
var _prev := Vector3.INF
var _plane_prev := Vector3.INF
var _plane_was: Object = null
var _glow: MeshInstance3D
var _ribbon: MeshInstance3D
var _ribbon_mesh: ImmediateMesh
var _ribbon_points := PackedVector3Array()
var _ribbon_clock := 0.0
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
	return &"chase"

static func _flag(flag: String, default: float) -> float:
	for a: String in LaunchArgs.user_args():
		if a.begins_with(flag+"="): return maxf(float(a.trim_prefix(flag+"=")),0.0)
	return default

func _init() -> void:
	name = "Raider"

func setup(g: Node3D) -> void:
	game = g
	_rng.seed = 4401
	tuning = {"every":_flag("--raider-gap",_flag("--raider-every",REST)),
		"let_go":_flag("--raider-let-go",LET_GO_M),"let_go_s":_flag("--raider-let-go-s",LET_GO_S),"ram":_flag("--raider-ram",RAM_OVER),
		"tell":maxf(_flag("--raider-tell",TELL_S),0.1),"hit":_flag("--raider-hit",HIT_R),
		"near":_flag("--raider-near",NEAR_R),"shove":_flag("--raider-shove",SHOVE),
		"fill":_flag("--raider-fill",DODGE_FILL.y),"turn":_flag("--raider-turn",TURN_MAX),
		"slow":minf(_flag("--raider-slow",SLOW),0.9),"slow_s":_flag("--raider-slow-s",SLOW_S),
		"cap":maxi(int(_flag("--raider-hit-cap",HIT_CAP)),1),
		"tail_m":_flag("--raider-tail-m",ON_TAIL_M),"tail_cos":cos(deg_to_rad(_flag("--raider-tail-deg",ON_TAIL_DEG))),
		"keep_near":_flag("--raider-keep-near",KEEP_M.x),"keep_far":_flag("--raider-keep-far",KEEP_M.y),
		"getaway":_flag("--raider-getaway",GETAWAY_M),"getaway_s":_flag("--raider-getaway-s",GETAWAY_S),
		"stagger":_flag("--raider-stagger",STAGGER_S)}
	flight = SkyTraffic.Flight.new()
	mode = mode_of(LaunchArgs.user_args())
	if mode != &"dogfight":
		chase = RaiderChase.new(self)
		embers = RaiderEmbers.new(self)
		add_to_group(&"parry_source")  # its embers (scripts/endless/parry.gd)
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
	_smoke = _smoke_trail(SMOKE)
	_smoke_hard = _smoke_trail(SMOKE_HARD)
	_ribbon_mesh = ImmediateMesh.new()
	_ribbon = MeshInstance3D.new()
	_ribbon.name = "RaiderRibbon"
	_ribbon.mesh = _ribbon_mesh
	_ribbon.top_level = true
	var band := StandardMaterial3D.new()
	band.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	band.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	band.vertex_color_use_as_albedo = true
	band.albedo_texture = FacetMesh.soft_band()
	band.cull_mode = BaseMaterial3D.CULL_DISABLED
	band.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	band.distance_fade_min_distance = RIBBON_FADE.x
	band.distance_fade_max_distance = RIBBON_FADE.y
	_ribbon.material_override = band
	_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ribbon.visible = false
	add_child(_ribbon)
	_ribbon_points.resize(RIBBON)
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
	# A crash relaunches a new plane, set back from where it hit (study
	# `crash`): no closest pass swept across the jump, and a tell or ram aimed
	# at the old one ends. It stalks the new one from where it flies.
	if plane != _plane_was:
		if _plane_was != null:
			_prev = Vector3.INF
			_plane_prev = Vector3.INF
			if state == &"tell" or state == &"ram": _go(&"stalk")
			stats.relaunches = int(stats.get("relaunches",0))+1
		_plane_was = plane
	match state:
		&"away", &"dead":
			if flying:
				_wait -= delta
				if _wait <= 0.0: _spawn()
			if chase != null: chase.idle()
			_ribbon.visible = false
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
			_slow_step(delta)
			chase.step(delta,p,rel,dist,ps)
			if mode == &"chase": _watch(delta,dist)
			if dist > MIX_NEAR_M: run_t += delta
			if mode == &"mix":
				# Lost early (it ran before you could turn after it), it comes round
				# ahead and runs again (the chase's own way); lost later, it fights.
				var lost_now: bool = int(chase.stats.rounds) > _rounds_seen
				_rounds_seen = int(chase.stats.rounds)
				if (lost_now and t > MIX_GRACE) or run_t > MIX_CHASE_MOST: _fight()
		&"tell":
			# Down (landed): no ram at a plane on the ground.
			if flying: _tell(delta,p,ps)
			else: _go(&"stalk")
		&"ram": _ram(delta,p,rel,dist,ps)
		&"over":
			_fly_to(flight.position+ram_dir*100.0,delta,tuning.turn*0.5,lerpf(speed,ps+STALK_NEAR,minf(t/OVER_S,1.0)))
			if _breaks_off(rel,dist): _run()
			elif t >= OVER_S: _go(&"stalk")
		&"peel":
			var away := Vector3(rel.x,0.0,rel.z).normalized() if dist > 1.0 else Vector3.FORWARD
			_fly_to(flight.position+away*120.0+Vector3.UP*40.0,delta,tuning.turn,ps+STALK_FAR)
			if t >= PEEL_S: _go(&"stalk")
	if not alive():
		_hud(false)
		return
	# The closest pass over the frame, both moving.
	sweep = rel.length()
	if _prev != Vector3.INF and _plane_prev != Vector3.INF:
		var r0 := _prev-_plane_prev
		var r1 := flight.position-p
		sweep = _seg_least(r0,r1)
	if state == &"ram": _settle(sweep,p,events)
	if embers != null: embers.step(delta,_plane_prev,p,events)
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
	chased = false
	_unseen_t = 0.0
	_untail()
	_unslow()
	if mode == &"chase":
		chase.buzz()
		figure.reset(flight)
		_prev = Vector3.INF
		_go(&"flee")
		return
	_go(&"stalk")

# --- The chase: let go ---------------------------------------------------------

## Chased or not, and gone for good when not: far off, or long out of view.
func _watch(delta: float, dist: float) -> void:
	_tail_step(delta,dist)
	# Behind past GETAWAY_M for GETAWAY_S s: it got away, locked on or not.
	_away_t = _away_t+delta if (chase.phase == &"run" and dist > float(tuning.getaway)) else 0.0
	if _away_t > float(tuning.getaway_s):
		stats.got_away = int(stats.get("got_away",0))+1
		_leave()
		return
	var lock: Node = game.get("lock_on")
	var locked: bool = lock != null and lock.target == figure
	if locked: chased = true
	elif chased and lock != null and String(lock.why) == "pressed": chased = false
	if locked or chased or chase.phase != &"run":
		_unseen_t = 0.0
		return
	_unseen_t = 0.0 if _in_view() else _unseen_t+delta
	if dist > float(tuning.let_go) or _unseen_t > float(tuning.let_go_s): _leave()

## On its tail: close behind it, its nose on it; held a moment past slipping off.
func _tail_step(delta: float, dist: float) -> void:
	stagger_t = maxf(stagger_t-delta,0.0)
	var now := false
	if chase.phase == &"run" and dist > 1.0 and bool(game.hand_landing.flying()) and dist <= float(tuning.tail_m):
		var to: Vector3 = (flight.position-game.plane.position)/dist
		now = flight.forward().dot(to) >= 0.3 and (game.plane.forward() as Vector3).dot(to) >= float(tuning.tail_cos)
	_off_tail = 0.0 if now else _off_tail+delta
	on_tail = _off_tail <= TAIL_HOLD
	if on_tail: stats.tail_s = float(stats.get("tail_s",0.0))+delta

## Panicking: on its tail and not staggered by a parried ember.
func panic() -> bool:
	return on_tail and stagger_t <= 0.0 and state == &"flee"

func _untail() -> void:
	on_tail = false
	_off_tail = INF
	stagger_t = 0.0
	_away_t = 0.0

func _in_view() -> bool:
	var cam: Camera3D = game.camera
	if cam.is_position_behind(flight.position): return false
	return cam.get_viewport().get_visible_rect().has_point(cam.unproject_position(flight.position))

## Let go: it's gone, the next one buzzes in after the gap.
func _leave() -> void:
	stats.gone = int(stats.get("gone",0))+1
	if embers != null: embers.clear()
	figure.visible = false
	_glow.visible = false
	_unslow()
	_untail()
	chase.idle()
	chased = false
	_wait = float(tuning.every)
	_go(&"away")

# --- The embers (raider_embers.gd) and the parry's calls (parry.gd header) ----

## Its pace's multiplier in the chase: pulling away after an ember's hit,
## held back by the embers home on it.
func pace_k() -> float:
	var k := float(embers.pace_k()) if embers != null else 1.0
	return k*(1.0-float(tuning.slow)*hits_home)

## Its low flying height's multiplier in the chase: lower crippled.
func low_k() -> float:
	return CRIPPLED_LOW if crippled() else 1.0

func crippled() -> bool:
	return hits_home >= int(tuning.cap)

## A parried ember came home onto it: one more slow, to the cap.
func ember_home(_at: Vector3) -> void:
	stats.embers_home = int(stats.get("embers_home",0))+1
	stagger_t = float(tuning.stagger)
	if crippled(): return
	hits_home += 1
	slow_t = float(tuning.slow_s)
	stats.slowed = int(stats.get("slowed",0))+1
	if crippled(): stats.crippled = int(stats.get("crippled",0))+1

## The slow's clock: past it, the hits shaken off (not once crippled).
func _slow_step(delta: float) -> void:
	if hits_home == 0 or crippled(): return
	slow_t -= delta
	if slow_t <= 0.0: _unslow()

func _unslow() -> void:
	hits_home = 0
	slow_t = 0.0
	if _smoke != null:
		_smoke.emitting = false
		_smoke_hard.emitting = false

## A smoke trail from its tail, in the world (left hanging as it flies on).
func _smoke_trail(k: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = int(k.amount)
	p.lifetime = SMOKE_LIFE
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0.0,0.6,0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0.0,0.4))
	grow.add_point(Vector2(1.0,3.2))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0,Color(1,1,1,1))
	fade.add_point(0.6,Color(1,1,1,0.7))
	fade.set_color(fade.get_point_count()-1,Color(1,1,1,0))
	p.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*float(k.size)*SIZE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = BodyDust._blob_texture()
	m.albedo_color = k.color  # on the material, as BodyDust (p.color read white)
	# Faded near the eye, so flying through its trail doesn't fill the view.
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 3.0
	m.distance_fade_max_distance = 12.0
	quad.material = m
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

func parry_shots() -> Array[Dictionary]:
	return embers.embers if embers != null else ([] as Array[Dictionary])

func parry_take(shot: Dictionary) -> void:
	embers.take(shot)

func parry_aim(_shot: Dictionary) -> Vector3:
	return embers.aim()

func parry_inside(q: Vector3) -> bool:
	return embers.inside(q)

func parry_moved(shot: Dictionary, a: Vector3, n: Vector3) -> void:
	embers.moved(shot,a,n)

func parry_landed(shot: Dictionary, at: Vector3, hit: bool) -> void:
	embers.landed(shot,at,hit)

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
	chased = true  # the mix: lost, it comes round (or fights) as before
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
		# Counted only while it flies away from the plane: turning back for a
		# head-on through the plane's nose isn't being tailed.
		var going := flight.forward().dot(rel/maxf(dist,0.1)) > MIX_AWAY
		var on_tail := ahead and going and dist < MIX_TAIL_M and fwd.dot(rel/maxf(dist,0.1)) > cos(deg_to_rad(MIX_TAIL_DEG))
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
	if state == &"flee":
		var off := flight.position-p
		d = minf(d,Vector3(off.x,off.y*FLEE_UP,off.z).length())
	if d > (KILL_FLEE if state == &"flee" else KILL_R): return Vector3.INF
	var at: Vector3 = flight.position
	_break(at)
	return at

func _break(at: Vector3) -> void:
	stats.kills = int(stats.kills)+1
	if embers != null: embers.clear()
	var v: Vector3 = flight.velocity
	var pv: Vector3 = game.plane.velocity
	figure.visible = false
	_glow.visible = false
	_unslow()
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
	chased = false
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
	var tail := flight.position-flight.forward()*1.4*SIZE
	_smoke.global_position = tail
	_smoke_hard.global_position = tail
	_smoke.emitting = hits_home > 0 and not crippled()  # crippled: the black alone
	_smoke_hard.emitting = crippled()
	_trail_ribbon(delta,tail)
	var glow := 0.0
	if state == &"tell": glow = clampf(t/float(tuning.tell),0.0,1.0)*(0.75+0.25*sin(t*TAU*8.0))
	elif state == &"ram": glow = 0.45
	elif state == &"flee" and chase.phase != &"buzz" and mode != &"chase": glow = FLEE_GLOW  # the chase: the ribbon reads it
	_glow.visible = glow > 0.01
	if _glow.visible:
		# Running, at its tail (an engine's glow, to follow); else at its nose.
		var end := -1.6 if state == &"flee" else 2.0
		_glow.global_position = flight.position+flight.forward()*end*SIZE
		# Never under about a hundredth of the distance, so it reads far off.
		var d := (game.camera as Camera3D).global_position.distance_to(flight.position)
		var far := d*0.022
		var near := lerpf(1.0,3.5,glow)*SIZE
		var alpha := 0.8*glow
		if state == &"flee":
			# Running and close, an engine's ember, not a lamp: small and
			# faint inside FLEE_GLOW_NEAR m, up to full by twice that.
			near = SIZE*0.9
			alpha *= lerpf(0.45,1.0,smoothstep(FLEE_GLOW_NEAR,FLEE_GLOW_NEAR*2.0,d))
		_glow.scale = Vector3.ONE*maxf(near,far*glow)
		_glow_mat.albedo_color.a = alpha

## The ribbon: the newest point at its tail each frame, the rest laid every
## RIBBON_EVERY s and shifted down; a strip turned to the eye, tapering and
## fading to its end. Hidden, then shown again (a spawn), it starts whole at
## the tail.
func _trail_ribbon(delta: float, tail: Vector3) -> void:
	if not figure.visible:
		_ribbon.visible = false
		return
	if not _ribbon.visible or _ribbon_points[0].distance_to(tail) > 80.0:
		_ribbon_points.fill(tail)
		_ribbon_clock = 0.0
	_ribbon.visible = true
	_ribbon_clock += delta
	if _ribbon_clock >= RIBBON_EVERY:
		_ribbon_clock = fmod(_ribbon_clock,RIBBON_EVERY)
		for i in range(RIBBON-1,0,-1): _ribbon_points[i] = _ribbon_points[i-1]
	_ribbon_points[0] = tail
	var eye := (game.camera as Camera3D).global_position
	_ribbon_mesh.clear_surfaces()
	_ribbon_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(RIBBON):
		var p := _ribbon_points[i]
		var age := float(i)/(RIBBON-1)
		var along := _ribbon_points[maxi(i-1,0)]-_ribbon_points[mini(i+1,RIBBON-1)]
		if along.length_squared() < 0.000001: along = flight.forward()
		var across := along.cross(eye-p)
		if across.length_squared() < 0.000001: across = Vector3.UP
		var w := maxf(lerpf(RIBBON_W.x,RIBBON_W.y,age)*SIZE,eye.distance_to(p)*RIBBON_PX)
		across = across.normalized()*w*0.5
		var c := RIBBON_COLOR
		c.a *= (1.0-age)*smoothstep(0.0,0.05,age+0.01)
		_ribbon_mesh.surface_set_color(c)
		_ribbon_mesh.surface_set_uv(Vector2(0.0,age))
		_ribbon_mesh.surface_add_vertex(p-across)
		_ribbon_mesh.surface_set_color(c)
		_ribbon_mesh.surface_set_uv(Vector2(1.0,age))
		_ribbon_mesh.surface_add_vertex(p+across)
	_ribbon_mesh.surface_end()

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
	# The chase: no arrow at the view's edge, only the mark on it.
	if mode == &"chase" and not m.on_screen:
		m.on = false
		m.queue_redraw()
		return
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
