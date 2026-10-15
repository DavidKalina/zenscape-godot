extends Node3D
## The linger threat, the serpent (docs/design/roguelike/linger-serpent-round1.md,
## linger-serpent-round2.md): the linger threat for the Olmec city. Stay on a
## layer and a colossal stone serpent with a feathered ruff (scripts/roguelike/
## linger_serpent.gd) climbs up out of the void toward you. No timer on the
## screen: the clock is read by looking back.
##
## 1. **Below** (from the start): its coils glimpsed deep in the haze under
##    the isles, rising slowly; a low scraping of stone on stone.
## 2. **Rising** (SEARCH s on): its head clears the haze and searches, a
##    slow deliberate sweep over the isles. Seen only in the open: cover
##    (stone between), a crouch, standing still or creeping keep him hidden
##    (`_sight`); a loud noise on the NoiseBus turns its search that way.
## 3. **It sees you**: the hunt (round 2). It climbs out of the void over
##    the rim of his isle nearest it and slithers after him across the
##    isle, its body on the ground (over low stone, round pillars and tall
##    walls: scripts/roguelike/linger_nav.gd), its front ON_ISLE m on the
##    isle and the rest draped over the rim into the void. It goes at about
##    his run (a little slower near him, faster far off), cutting the
##    corners he runs; its body is solid, a moving wall. Close, with a clear
##    line to him, it strikes: rears (the head drawn back and up, the jaw
##    dropping), holds, and lunges at where he stood as the hold began. A
##    running man is behind where it bites; a standing one is bitten (the
##    motor's `harm`, one heart, thrown toward the rim). Stone between stops
##    the strike. He crosses to another isle: it goes down over the rim and
##    climbs the next. In stage 3 it gives up if it doesn't see him for
##    GIVE_UP_T s, and sinks back into the void.
## 4. **Level** (LEVEL s on): it knows where he is, hunts faster, strikes
##    sooner and never gives up. Only the gate gets you away; every layer
##    begins it again (it lives on the layer's stage).
##
## On by default: `--no-linger` (or `--loot=off`) leaves it out,
## `--linger=colossus` is another agent's threat. Knobs:
##   --linger-at=<s>       start the clock this far on (100: rising, 150: level)
##   --linger-pace=<x>     it all runs x times as fast (a fast-forward)
##   --linger-scale=<x>    its size (the rune serpent's times x; 2.4)
##   --linger-chase=<x>    its pace near him as a share of his run (0.9)
##   --linger-debug        its stage and act changes in the log
const RunFeatures = preload("res://scripts/roguelike/run_features.gd")
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const Body = preload("res://scripts/roguelike/linger_serpent.gd")
const Nav = preload("res://scripts/roguelike/linger_nav.gd")
const Settle = preload("res://scripts/roguelike/linger_settle.gd")
const Shell = preload("res://scripts/roguelike/linger_shell.gd")

## The clock (s from the layer's start).
const STIR := 20.0
const SEARCH := 95.0
const LEVEL := 150.0
## Its head's height over his (m, eased) by the clock while it coils in the
## void.
const DEEP := -240.0
const CLEAR := -10.0
const HIGH := 22.0
const POISED := -6.0
## Crossing to a column further than this off (m), it goes under, DIVE m
## below him, so it never sweeps over an isle.
const CROSS := 40.0
const DIVE := 65.0
const SCALE := 2.4
const FAR_RING := [95.0,120.0,145.0]
const NEAR_RING := [48.0,58.0,70.0]
const COIL := 22.0
const COIL_TIGHT := 16.0
## Its head's pace (m/s) coiling calm and gathered; up out of the void and
## down into it.
const PACE := 6.0
const PACE_HUNT := 9.0
const CLIMB_PACE := 14.0
## Its tightest turn (m radius, world): the rings never fold on a turn's
## inside (round 1's distortion: it turned on the spot when slow).
const TURN_R := 8.0
const CLIMB := 0.5

## The hunt. Its body on the isle: the head's way rides this share of the
## body's girth over the ground; this much of it (m) lies on the isle, the
## rest draped over the rim.
const RIDE_K := 0.72
const ON_ISLE := 75.0
## Its pace (shares of his run): near him, far off (past CATCH_UP m), at
## level near him.
const CHASE_K := 0.9
const CHASE_FAR := 1.4
const CHASE_LEVEL := 1.0
const CATCH_UP := 38.0
## Paths asked again every REPLAN s; it steers at the furthest point of
## the path it can go straight to, up to LOOKAHEAD m on.
const REPLAN := 0.35
const LOOKAHEAD := 30.0
## He is on another isle this long (s): it goes down and climbs that one.
const SWITCH_T := 0.8
## The climb onto an isle: up from this far under the rim and out (m), up
## over it, in.
const RIM_DOWN := 26.0
## It comes up over a rim about this far from him (m), so it has the isle
## to cross; and slithers this far (m) on the ground before it may strike.
const ENTER_OFF := 28.0
const GROUND_FIRST := 12.0
const RIM_OUT := 15.0
## The strike. Begun with his chest within STRIKE_AT m of its snout, in
## front of it (STRIKE_CONE rad), a clear line. Rear (s, rising and level),
## drawn back REAR_BACK m and lifted REAR_LIFT m, the jaw half open; hold
## (s), the jaw wide, the aim taken as the hold begins; the lunge (m/s, at
## most LUNGE_REACH m); the bite held (s); a beat (s), drawn back (share of
## the lunge, m/s); no strike again for COOL s.
const STRIKE_AT := 13.0
const STRIKE_CONE := 1.2
const REAR := 0.55
const REAR_LEVEL := 0.4
const REAR_BACK := 4.0
const REAR_LIFT := 6.5
## The aim is taken this share of the way through the rear.
const COMMIT := 0.5
const HOLD := 0.22
const HOLD_LEVEL := 0.16
const LUNGE := 48.0
const LUNGE_REACH := 22.0
const BITE := 0.32
const BEAT := 0.45
const DRAW_SHARE := 0.3
const DRAW_PACE := 11.0
const COOL := 1.6
const COOL_LEVEL := 1.0
const COOL_HIT := 3.2
## The jaw (rad): reared, held wide.
const JAW_REAR := 0.32
const JAW_WIDE := 0.62
## A hit: his chest within BITE_R m of its mouth as it passes; thrown
## KNOCK (out, up m/s) toward the rim, down KNOCK_DOWN s.
const BITE_R := 2.0
## The mouth's place back from the snout's tip (local m).
const MOUTH_BACK := 1.4
## Stone this far (m) over the walkable ground under it is cover.
const COVER_TALL := 1.6
const KNOCK := Vector2(6.0,2.6)
const KNOCK_DOWN := 0.6
## In stage 3, unseen this long (s) on the isle, it gives up.
const GIVE_UP_T := 14.0
## Its body pushing him: how far off its girth he is kept (m), the most a
## frame (m).
const PUSH_SKIN := 0.4
const PUSH_RATE := 9.0

## Sight: its reach (m), its cone's half angle (rad), fully seen within
## NEAR m, FAR_SEEN of him at the reach; awareness filled a second at
## visibility 1 (FILL, LEVEL_FILL), drained (DRAIN) after GRACE s unseen;
## it hunts at 1. How plain he is: crouched, still, creeping, in the air.
const SIGHT := 175.0
const CONE := 0.8
const NEAR := 45.0
const FAR_SEEN := 0.35
const FILL := 0.55
const LEVEL_FILL := 1.1
const DRAIN := 0.12
const GRACE := 2.0
const SEEN_CROUCH := 0.35
const SEEN_STILL := 0.55
const SEEN_CREEP := 0.7
const SEEN_AIR := 1.2
const SWEEP := 0.95
const SWEEP_PERIOD := 9.0
const HEAR := 5.0
const NOISE_TURN := 5.0
const SCRAPE_DB := Vector2(-16.0,-3.0)
const KIT := "res://assets/audio/kit/"

## Its stage (1 below, 2 rising, 3 hunting you, 4 level) and what its head
## does ("coil", "climb", "chase", "rear", "hold", "lunge", "bite",
## "recover", "descend"); the clock; how aware of him it is (0..1).
var stage := 1
var act := "coil"
var clock := 0.0
var awareness := 0.0
var hunting := false
## Counts, for drivers: strikes, hits, times it saw him, isles climbed.
var strikes := 0
var hits := 0
var sightings := 0
var climbs := 0
## Strikes let go because stone came between in the rear.
var aborts := 0
## Round 3's body on (`--linger-settle=off` leaves it off).
var settled := true
## Waiting for his isle's bake before climbing it (s), at most BAKE_WAIT_MOST.
const BAKE_WAIT_MOST := 6.0
var _bake_wait := 0.0
## Times it steered round drawn stone in the air (round 3).
var avoids := 0
## Frames it was close enough to strike but stone stood between.
var covered := 0
## Its frame's cost (µs), the worst yet.
var last_usec := 0
var worst_usec := 0

var study: Node3D
var loop: Node
var layer: Dictionary
var body: Body
var nav: Nav
## The drawn world (round 3), its own physics space.
var shell: Shell
var _scale := SCALE
var _pace_k := 1.0
var _chase_k := CHASE_K
var _debug := false
var _head := Vector3.ZERO
var _dir := Vector3.FORWARD
var _speed := PACE
var _anchor := Vector3.ZERO
var _spin := 1.0
var _climb := CLIMB
var _act_t := 0.0
var _anchor_t := 0.0
var _sight_t := 0.0
var _unseen := 0.0
var _visible := 0.0
var _level_y := 0.0
var _noise_id := 0
var _noise_at := Vector3.INF
var _noise_t := 0.0
var _sweep_c := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _scrape: AudioStreamPlayer3D
var _grind: AudioStreamPlayer3D
var _voice: AudioStreamPlayer3D
var _breath_t := 3.0
## The hunt: its ride height (m), the waypoints it follows (climb,
## descend) and where it is in them, the isle it makes for, his last seen
## place, the path and when it is asked again, the isle-switch timer.
var _ride := 3.5
var _ways := PackedVector3Array()
var _way_i := 0
var _after := ""
var _isle_to := -1
var _seen_at := Vector3.INF
var _path := PackedVector3Array()
var _replan := 0.0
var _switch_t := 0.0
var _cool := 0.0
## Metres slithered on the ground since it last climbed onto an isle.
var _ground_m := 0.0
## The strike: its aim, the lunge's start and its way, how far it went,
## how far it was drawn back in the rear, this strike has bitten.
var _aim := Vector3.ZERO
var _lunge_from := Vector3.ZERO
var _lunged := 0.0
var _wound := 0.0
var _bit := false
var _committed := false
var _last_mouth := Vector3.ZERO
## The drape: its weight (0..1), the rim it goes over (world, its way out).
var _drape_w := 0.0
var _drape_rim := {}
var _drape_t := 0.0

## Cut from the run (2026-10-15): laid only with `--linger=serpent`.
static func lay(run_loop: Node, stage_node: Node3D, plan: Dictionary) -> Node3D:
	if not RunFeatures.on(&"linger") or RunFeatures.value("linger","") != "serpent": return null
	var l: Node3D = (load("res://scripts/roguelike/linger.gd") as GDScript).new()
	l.name = "Linger"
	stage_node.add_child(l)
	l.setup(run_loop,plan)
	return l

func setup(run_loop: Node, plan: Dictionary) -> void:
	loop = run_loop
	study = run_loop.study
	layer = plan
	_rng.seed = int(plan.get("seed",1))*7+3
	clock = maxf(float(RunFeatures.value("linger-at","0")),0.0)
	_pace_k = clampf(float(RunFeatures.value("linger-pace","1")),0.05,20.0)
	_scale = clampf(float(RunFeatures.value("linger-scale",str(SCALE))),0.5,6.0)
	_chase_k = clampf(float(RunFeatures.value("linger-chase",str(CHASE_K))),0.2,3.0)
	_debug = "--linger-debug" in LaunchArgs.user_args()
	_spin = 1.0 if _rng.randf() < 0.5 else -1.0
	body = Body.new()
	add_child(body)
	body.global_transform = Transform3D(Basis.from_scale(Vector3.ONE*_scale),Vector3.ZERO)
	body.build(study)
	_ride = Body.RADIUS*_scale*RIDE_K
	var skip: Array[RID] = [body.solid_rid()]
	nav = Nav.new(get_world_3d().direct_space_state,layer.get("isles",[]),skip)
	# Round 3: its rings settled off the drawn stone (its own space of the
	# layer's meshes) and off its own coils.
	var skips: Array[Node] = [self]
	var fig: Variant = study.get("figure")
	if fig is Node: skips.append(fig as Node)
	shell = Shell.new(study,skips)
	body.settle = Settle.new(shell,nav,Body.STATIONS)
	# `--linger-settle=off`: round 2's body (no settle, no steering round
	# stone in the air, any rim, the cliffs' feet not avoided), to compare.
	settled = not ("--linger-settle=off" in LaunchArgs.user_args())
	body.settle.on = settled
	nav.cliffs = settled
	_level_y = _feet().y
	_anchor = _pick_anchor(false,_feet())
	_lay_coiled()
	_sounds()
	_stage_now()

func _exit_tree() -> void:
	if shell != null: shell.free_all()

# --- Him ----------------------------------------------------------------------

func _motor() -> Object:
	return study.get("motor") if study != null else null

func _feet() -> Vector3:
	var m: Object = _motor()
	return m.feet if m != null else Vector3.ZERO

func _chest() -> Vector3:
	return _feet()+Vector3.UP*1.05

func _points() -> PackedVector3Array:
	var f := _feet()
	return PackedVector3Array([f+Vector3.UP*0.35,f+Vector3.UP*1.05,f+Vector3.UP*1.7])

func _run() -> float:
	var m: Object = _motor()
	return float(m.get("run")) if m != null and m.get("run") != null else 4.8

func _playing() -> bool:
	if loop == null: return true
	var st := String(loop.get("state"))
	if st != "play" and st != "arrive": return false
	var loading: Variant = study.get("loading")
	return not (loading != null and loading.active)

## The isle he is on (or just over), or -1.
func _his_isle() -> int:
	var c := nav.nearest(_feet(),4.5)
	return nav.isle_of(c) if c != Nav.NONE else -1

func _head_isle() -> int:
	var c := nav.nearest(_head,6.0)
	return nav.isle_of(c) if c != Nav.NONE else -1

# --- The clock ----------------------------------------------------------------

static func height_at(t: float) -> float:
	if t <= STIR: return DEEP
	if t <= SEARCH: return lerpf(DEEP,CLEAR,_ease((t-STIR)/(SEARCH-STIR)))
	if t <= LEVEL: return lerpf(CLEAR,HIGH,_ease((t-SEARCH)/(LEVEL-SEARCH)))
	return POISED

static func _ease(x: float) -> float:
	x = clampf(x,0.0,1.0)
	return x*x*(3.0-2.0*x)*0.5+x*0.5

func _stage_now() -> void:
	var was := stage
	if clock >= LEVEL: stage = 4
	elif hunting: stage = 3
	elif clock >= SEARCH: stage = 2
	else: stage = 1
	if was != stage and _debug: print("[linger] stage %d at %.1f s (%s)" % [stage,clock,act])

# --- A frame ------------------------------------------------------------------

func _process(delta: float) -> void:
	if body == null or delta <= 0.0: return
	var began := Time.get_ticks_usec()
	delta = minf(delta,0.1)*_pace_k
	nav.bake_step(_feet())
	shell.step(delta/_pace_k,_feet())
	var playing := _playing()
	if playing: clock += delta
	_level_y = lerpf(_level_y,_feet().y,1.0-exp(-0.5*delta))
	if playing:
		_hear()
		_sight_step(delta)
	_stage_now()
	_anchor_step(delta)
	_head_step(delta,playing)
	_drape_step(delta)
	if playing: _push_him(delta)
	_sound_step(delta)
	last_usec = Time.get_ticks_usec()-began
	worst_usec = maxi(worst_usec,last_usec)

func _anchor_step(delta: float) -> void:
	_anchor_t -= delta
	if _anchor_t > 0.0 or act != "coil": return
	_anchor_t = 4.0
	var near := hunting or stage >= 4
	var f := _feet()
	var flat := Vector2(_anchor.x-f.x,_anchor.z-f.z).length()
	var ring: Array = NEAR_RING if near else FAR_RING
	if flat < float(ring[0])*0.75 or flat > float(ring[ring.size()-1])*1.3 or not _clear(_anchor,8.0):
		_anchor = _pick_anchor(near,f)

# --- Its head ------------------------------------------------------------------

func _set_act(next: String) -> void:
	if _debug and next != act: print("[linger] %s -> %s at %.1f s (head %.1f m from him)" % [act,next,clock,_head.distance_to(_feet())])
	act = next
	_act_t = 0.0

func _head_step(delta: float, playing: bool) -> void:
	_act_t += delta
	_cool -= delta
	var b := body
	var snap := false
	var look_at := Vector3.INF
	var lift := 0.0
	b.fixed = hunting and act != "coil"
	b.look_hz = 0.0 if act == "coil" else (8.0 if act in ["lunge","bite"] else 2.2)
	match act:
		"coil":
			var tight := 1.0 if hunting or stage >= 4 else 0.0
			var r := lerpf(COIL,COIL_TIGHT,tight)*(1.0+0.22*sin(clock*0.05))
			var y := _level_y+height_at(clock)
			if stage >= 4: y += 18.0*sin(clock*0.12)
			var goal := _under(_helix(r,y),r+CROSS*0.5)
			var goal_speed := lerpf(PACE,PACE_HUNT,tight)
			if Vector2(_head.x-_anchor.x,_head.z-_anchor.z).length() > r+CROSS*0.5: goal_speed = CLIMB_PACE*0.8
			elif _head.y < y-12.0: goal_speed *= 1.5
			_speed = move_toward(_speed,goal_speed,delta*3.0)
			_climb = CLIMB
			_steer(goal,delta,false)
			look_at = _search_point(delta)
			b.jaw = 0.12 if hunting else 0.0
			if (hunting or stage >= 4) and playing and nav.ready(): _begin_climb()
		"climb", "descend":
			look_at = _chest() if act == "climb" else Vector3.INF
			b.jaw = 0.15
			_follow_ways(delta)
		"chase":
			_chase(delta,playing)
			look_at = _chest()
			lift = 0.6
			b.jaw = 0.1
		"rear":
			# Anticipation: drawn back along its own way and up, the jaw
			# dropping, squashed; still turning its head on him.
			var rear := REAR_LEVEL if stage >= 4 else REAR
			var k := _smooth(_act_t/rear)
			var want := REAR_BACK*k/_scale
			var back := minf(want-_wound,b.rewind_room())
			if back > 0.0:
				_wound += b.rewind(back)
				_head = b.to_global(b.live())
			# Its aim taken partway up the rear (COMMIT): from there it is
			# set, and a man running is no longer where it bites.
			if _act_t/rear >= COMMIT and not _committed:
				_committed = true
				_aim = _chest()+Vector3.UP*0.6
			look_at = _chest() if not _committed else _aim
			lift = REAR_LIFT*_back_out(k)
			b.jaw = JAW_REAR*k
			b.stretch = lerpf(1.0,0.86,k)
			_speed = 0.0
			if _act_t >= rear:
				if not _committed: _aim = _chest()+Vector3.UP*0.6
				_set_act("hold")
				_voice_play("dragon-growl-loop.wav",0.62,-4.0,0.5)
		"hold":
			# The held breath: the jaw wide, a tremble, the aim taken.
			look_at = _aim
			lift = REAR_LIFT*(1.0+0.04*sin(_act_t*70.0))
			b.jaw = JAW_WIDE
			b.stretch = 0.84
			if _act_t >= (HOLD_LEVEL if stage >= 4 else HOLD):
				# Stone between now (he ducked behind it): it lets the strike go.
				if _blocked(_head,_aim):
					aborts += 1
					_cool = 0.5
					_set_act("chase")
				else:
					_lunge()
		"lunge":
			snap = true
			var stepd := LUNGE*delta
			var to := _aim-_head
			_last_mouth = _mouth()
			if to.length() <= stepd: _head = _aim
			else: _head += to.normalized()*stepd
			var g := nav.height(_head)
			var flat_left := Vector2(_aim.x-_head.x,_aim.z-_head.z).length()
			if not is_nan(g) and flat_left > 5.0: _head.y = maxf(_head.y,g+_ride*0.5)
			_lunged += b.go_to(b.to_local(_head))
			b.jaw = JAW_WIDE
			b.stretch = 1.24
			lift = 0.0
			_check_hit()
			if _head.distance_to(_aim) < 0.05 or _act_t > 0.9:
				_set_act("bite")
				_bitten()
		"bite":
			b.jaw = 0.0
			b.stretch = lerpf(0.88,1.0,_smooth(_act_t/0.25))
			if _act_t < 0.1:
				_last_mouth = _mouth()
				_check_hit()
			if _act_t >= BITE: _set_act("recover")
		"recover":
			# A beat where it bit, then drawn back along its way, and on.
			b.jaw = 0.06
			b.stretch = 1.0
			look_at = _chest()
			if _act_t > BEAT:
				var go := minf(DRAW_PACE*delta/_scale,maxf(_lunged*DRAW_SHARE-_wound,0.0))
				var went: float = b.rewind(go)
				_wound += went
				_head = b.to_global(b.live())
				if went <= 0.0 or _wound >= _lunged*DRAW_SHARE-0.001:
					_dir = Vector3(b.global_transform.basis*b.way()).normalized()
					_dir.y = 0.0
					_dir = _dir.normalized()
					_cool = COOL_LEVEL if stage >= 4 else COOL
					# After a bite it lets him get up and run.
					if _bit: _cool = COOL_HIT
					_speed = _run()*_chase_k*0.6
					_set_act("chase")
	b.pace = _speed/_scale
	_look(look_at,lift)
	b.step(delta,snap)

## Ease of the rear: a quick start, held at the top.
static func _back_out(k: float) -> float:
	return 1.0-pow(1.0-clampf(k,0.0,1.0),3.0)

## Its mouth (world): a little back from the snout's tip.
func _mouth() -> Vector3:
	var s: Vector3 = body.to_global(body.way_snout())
	var h: Vector3 = body.to_global(body.way_head())
	return s.lerp(h,MOUTH_BACK/Body.HEAD)

## Its head steered toward `goal` (world) at `_speed`, turning at most a
## TURN_R circle (per metre, not per second: slow, it turns as gently as
## fast, so the rings never fold); `ground`: on the isle, flat, its height
## the ground's plus its ride.
func _steer(goal: Vector3, delta: float, ground: bool) -> void:
	var ds := _speed*delta
	if ds <= 1e-5:
		return
	var want := goal-_head
	if ground: want.y = 0.0
	if want.length() < 0.01: want = _dir
	want = want.normalized()
	if not ground:
		want.y = clampf(want.y,-_climb,_climb)
		var flat := Vector2(want.x,want.z)
		if flat.length() < 0.35:
			var keep := Vector2(_dir.x,_dir.z)
			if keep.length() < 0.01: keep = Vector2(1.0,0.0)
			flat = (flat+keep.normalized()*0.35).normalized()*0.35
			want = Vector3(flat.x,signf(want.y)*sqrt(1.0-0.35*0.35),flat.y)
		want = want.normalized()
		want = _avoid(want,goal,delta)
	var turn := ds/TURN_R
	var angle := _dir.angle_to(want)
	if angle > 1e-4:
		if angle > 3.0:
			_dir = _dir.rotated(Vector3.UP,turn*_spin).normalized()
		else:
			_dir = _dir.slerp(want,minf(turn/angle,1.0)).normalized()
	var next := _head+_dir*ds
	if ground:
		_dir.y = 0.0
		_dir = _dir.normalized()
		next = _head+_dir*ds
		var g := nav.height(next)
		if not is_nan(g): next.y = lerpf(_head.y,g+_ride,1.0-exp(-7.0*delta))
	else:
		var heave := Vector3.UP*0.05*sin(float(body.travelled)*_scale/38.0)
		next = _head+(_dir+heave).normalized()*ds
	_head = _path_clear(next,ds,ground)
	body.go_to(body.to_local(_head))

## Round 3: on the ground, the head's way kept out of the drawn stone (a
## ball of its ride pushed out, a little a frame: no kink in the way), so
## the rings that follow it are. In the air it steers round (`_avoid`):
## pushed there, it could not climb over a rim.
func _path_clear(next: Vector3, ds: float, ground: bool) -> Vector3:
	if not ground or not settled or body.settle == null or body.settle.space == null: return next
	var push: Vector3 = body.settle.out_of_stone(next,_ride)
	if push == Vector3.ZERO: return next
	return next+push.limit_length(maxf(ds*1.2,0.12))

## Round 3: in the air, round the drawn stone ahead (an isle's rock, a
## column's shaft, a pier): a ball its girth cast AVOID_LOOK m along its
## way; blocked, the nearest way round that is clear (turned, tilted).
## Not near its goal (the rim it climbs over is its goal).
const AVOID_LOOK := 30.0
const AVOID_NEAR := 140.0
const AVOID_DEEP := 85.0
const AVOID_EVERY := 0.1
const AVOID_YAW := [0.4,-0.4,0.8,-0.8,1.25,-1.25,1.7,-1.7]
const AVOID_PITCH := [0.0,0.5,-0.5]
var _avoid_t := 0.0
var _avoid_dir := Vector3.ZERO
var _cast := PhysicsShapeQueryParameters3D.new()
var _cast_ball := SphereShape3D.new()
func _avoid(want: Vector3, goal: Vector3, delta: float) -> Vector3:
	if shell == null or not settled or not _avoiding(): return want
	_avoid_t -= delta
	if _avoid_t > 0.0: return _avoid_dir if _avoid_dir != Vector3.ZERO else want
	_avoid_t = AVOID_EVERY
	# Inside a hollow of stone already (its casts would meet nothing): out
	# the nearest way.
	if body.settle != null and body.settle.space != null:
		var esc: Vector3 = body.settle._escape(_head,Body.RADIUS*_scale*Settle.BALL-Settle.SINK)
		if esc != Vector3.ZERO:
			_avoid_dir = (esc.normalized()+want*0.3).normalized()
			avoids += 1
			return _avoid_dir
	var reach := minf(AVOID_LOOK,_head.distance_to(goal)-TURN_R*0.5)
	_avoid_dir = Vector3.ZERO
	if reach < 4.0 or _clear_cast(_head,want*reach): return want
	var best := Vector3.ZERO
	var score := INF
	for pitch: float in AVOID_PITCH:
		for yaw: float in AVOID_YAW:
			var d := want.rotated(Vector3.UP,yaw*_spin)
			var side := d.cross(Vector3.UP)
			if pitch != 0.0 and side.length() > 0.01: d = d.rotated(side.normalized(),pitch)
			d = d.normalized()
			var s := d.angle_to(want)
			if s >= score: continue
			if _clear_cast(_head,d*reach):
				score = s
				best = d
		if best != Vector3.ZERO: break
	_avoid_dir = best
	avoids += 1
	return best if best != Vector3.ZERO else want

## Whether it avoids stone now: coiling, and climbing or going down but
## not at the rim (the last two of a climb, the first of a descent).
func _avoiding() -> bool:
	# Far off or deep in the haze it goes straight (its pace kept; its rings
	# still settle off what they meet).
	var f := _feet()
	if Vector2(_head.x-f.x,_head.z-f.z).length() > AVOID_NEAR or _head.y < f.y-AVOID_DEEP: return false
	match act:
		"coil": return true
		"climb": return _way_i < _ways.size()-2
		"descend": return _way_i >= 1
	return false

## A ball of its girth from `a` along `move`, clear of the drawn stone.
func _clear_cast(a: Vector3, move: Vector3) -> bool:
	var st := shell.state()
	if st == null: return true
	_cast_ball.radius = Body.RADIUS*_scale*0.95
	_cast.shape = _cast_ball
	_cast.transform = Transform3D(Basis.IDENTITY,a)
	_cast.motion = move
	var got := st.cast_motion(_cast)
	return got.size() < 1 or float(got[0]) >= 1.0

func _under(goal: Vector3, far: float) -> Vector3:
	if Vector2(goal.x-_head.x,goal.z-_head.z).length() <= far: return goal
	return Vector3(goal.x,minf(goal.y,_level_y-DIVE),goal.z)

func _helix(r: float, y: float) -> Vector3:
	var rel := Vector2(_head.x-_anchor.x,_head.z-_anchor.z)
	var a := atan2(rel.y,rel.x)+_spin*0.55
	return Vector3(_anchor.x+cos(a)*r,y,_anchor.z+sin(a)*r)

func _search_point(delta: float) -> Vector3:
	if stage <= 1: return Vector3.INF
	var f := _feet()
	_noise_t -= delta
	var centre := f
	if _noise_t > 0.0 and _noise_at != Vector3.INF: centre = _noise_at
	elif hunting: centre = f
	else:
		centre = f+Vector3(sin(clock*0.07)*22.0,0.0,cos(clock*0.053)*22.0)
	_sweep_c = _sweep_c.lerp(centre,1.0-exp(-0.6*delta)) if _sweep_c != Vector3.ZERO else centre
	var to := _sweep_c-_head
	var flat := Vector3(to.x,0.0,to.z)
	var sway := 0.0 if hunting else SWEEP*sin(TAU*clock/SWEEP_PERIOD)
	return _head+flat.rotated(Vector3.UP,sway)+Vector3.UP*to.y

## The look aimed at `p` (world), off its way; none: ahead. `lift` (m,
## world) raises its head on its neck.
func _look(p: Vector3, lift := 0.0) -> void:
	var b := body
	if p == Vector3.INF:
		b.look(0.0,0.0,0.0,lift/_scale)
		return
	var fwd: Vector3 = (b.global_transform.basis*(b.forward() as Vector3)).normalized()
	var to := (p-_head).normalized()
	var yaw := wrapf(atan2(to.x,to.z)-atan2(fwd.x,fwd.z),-PI,PI)
	if absf(yaw) > 2.3: yaw = 0.0
	var pitch := asin(clampf(to.y,-1.0,1.0))-asin(clampf(fwd.y,-1.0,1.0))
	b.look(yaw,pitch,0.0,lift/_scale)

# --- The hunt ---------------------------------------------------------------------

## Waypoints followed in the air (up out of the void, down into it); at
## the last, on to `_after`.
func _follow_ways(delta: float) -> void:
	if _way_i >= _ways.size():
		_ways_done()
		return
	var goal := _ways[_way_i]
	var last := _way_i == _ways.size()-1
	# The last of a climb is on the isle: its ground's height.
	if last and act == "climb":
		var g := nav.height(goal)
		if not is_nan(g): goal.y = g+_ride
	_speed = move_toward(_speed,CLIMB_PACE*(0.7 if last else 1.0),delta*6.0)
	_climb = 1.0
	_steer(goal,delta,false)
	var reach := TURN_R*(1.1 if not last else 0.8)
	if _head.distance_to(goal) < reach or _act_t > 30.0:
		if _debug: print("[linger] %s way %d/%d reached in %.1f s (%.1f m off, %d avoids)" % [act,_way_i+1,_ways.size(),_act_t,_head.distance_to(goal),avoids])
		_way_i += 1
		_act_t = 0.0
		if _way_i >= _ways.size(): _ways_done()

## The waypoints run out: on the isle (the chase), on to climb his, or
## back to coiling.
func _ways_done() -> void:
	match _after:
		"chase":
			climbs += 1
			_ground_m = 0.0
			_speed = _run()*_chase_k
			_dir.y = 0.0
			_dir = _dir.normalized()
			_path = PackedVector3Array()
			_set_act("chase")
		"climb_next":
			_begin_climb()
			if act != "climb": _set_act("coil")
		_:
			_set_act(_after)

## Up out of the void onto his isle, over the rim nearest it.
func _begin_climb() -> void:
	var to := _his_isle()
	if to < 0: to = _nearest_isle(_feet())
	if to < 0: return
	# Round 3: not over a rim the bake has not reached yet (a stale rim lies
	# inside the ground: its climb would run through the stone).
	if settled and not nav.settled(to) and _bake_wait < BAKE_WAIT_MOST:
		_bake_wait += get_process_delta_time()
		return
	_bake_wait = 0.0
	var r := {}
	# Round 3: of the best few rims, the first whose way up out of the void
	# and over the lip is clear of the drawn stone (a crossing's piers, a
	# spur of rock), else the best.
	var tries := nav.rim_offs(to,_head,_feet(),ENTER_OFF,RIM_TRIES if settled else 1)
	for c: Dictionary in tries:
		if _climb_clear(c):
			r = c
			break
	if r.is_empty() and not tries.is_empty(): r = tries[0]
	if r.is_empty(): return
	if _debug: print("[linger] climb isle %d over rim %s out %s (%d tried, clear %s)" % [to,str((r.at as Vector3).round()),str((r.out as Vector3).snapped(Vector3.ONE*0.01)),tries.size(),str(_climb_clear(r))])
	_isle_to = to
	var at: Vector3 = r.at
	var out: Vector3 = r.out
	_ways = PackedVector3Array()
	var low := at+out*float(r.get("low_out",RIM_OUT))+Vector3.DOWN*RIM_DOWN
	# From far off or high, under first (never over an isle).
	if Vector2(low.x-_head.x,low.z-_head.z).length() > CROSS and _head.y > low.y-20.0:
		_ways.append(Vector3(low.x+out.x*20.0,minf(low.y-30.0,_level_y-DIVE),low.z+out.z*20.0))
	_ways.append(low)
	_ways.append(at+out*6.0+Vector3.UP*(_ride+2.5))
	# In over the rim, toward him: its neck and body come up after it.
	var inward := Vector3(_feet().x-at.x,0.0,_feet().z-at.z)
	inward = (inward.normalized()-out).normalized() if inward.length() > 1.0 else -out
	_ways.append(at+inward*12.0+Vector3.UP*_ride)
	_way_i = 0
	_after = "chase"
	_switch_t = 0.0
	_set_act("climb")
	_voice_play("dragon-growl-loop.wav",0.5,-6.0,1.8)

## The way up from under rim `r` and over it, clear (round 3).
const RIM_TRIES := 6
const CLIMB_OUT := [15.0,22.0,30.0]
func _climb_clear(r: Dictionary) -> bool:
	if shell == null: return true
	var at: Vector3 = r.at
	var out: Vector3 = r.out
	var over := at+out*6.0+Vector3.UP*(_ride+2.5)
	var st: Settle = body.settle
	var r_in := Body.RADIUS*_scale*Settle.BALL-Settle.SINK
	# A cast begun inside a hollow (a pillar's body under its top) meets
	# nothing: the way's points are asked whether they are inside too. The
	# low point further out where the stone under the rim reaches out.
	for low_out: float in CLIMB_OUT:
		var low := at+out*low_out+Vector3.DOWN*RIM_DOWN
		if st != null and (st.inside(low,r_in) or st.inside(low.lerp(over,0.5),r_in)): continue
		if _clear_cast(low+Vector3.DOWN*20.0,Vector3.UP*20.0) and _clear_cast(low,over-low+Vector3.DOWN*2.0):
			r["low_out"] = low_out
			return true
	return false

## Down off its isle over the rim toward `toward`, then `after` ("climb"
## onto his, or "coil" to give up).
func _begin_descend(toward: Vector3, after: String) -> void:
	var from := _head_isle()
	if from < 0:
		_after = after
		if after == "climb": _begin_climb()
		else: _set_act(after)
		return
	var r := nav.rim(from,_head,toward,1.0)
	if r.is_empty(): return
	var at: Vector3 = r.at
	var out: Vector3 = r.out
	_ways = PackedVector3Array()
	_ways.append(at+out*2.0+Vector3.UP*_ride)
	_ways.append(at+out*11.0+Vector3.DOWN*8.0)
	_ways.append(at+out*15.0+Vector3.DOWN*RIM_DOWN)
	_way_i = 0
	_after = "climb_next" if after == "climb" else after
	_set_act("descend")

## The isle whose ground is nearest `p`, or -1.
func _nearest_isle(p: Vector3) -> int:
	var c := nav.nearest(p,40.0)
	return nav.isle_of(c) if c != Nav.NONE else -1

## After him across the isle: straight at him where the way is clear, else
## along the path round what stands between; at his run (faster far off);
## striking when it can.
func _chase(delta: float, playing: bool) -> void:
	var him := _feet()
	var seen := _visible > 0.05 or _seen_at == Vector3.INF or stage >= 4
	if seen: _seen_at = him
	var target := him if seen or _unseen < 3.0 else _seen_at
	# Not seen for long, it still knows: it smells him out.
	if _unseen > 6.0: target = him
	# He is on another isle: down and over to it.
	var his := _his_isle()
	var mine := _head_isle()
	if his >= 0 and mine >= 0 and his != mine:
		_switch_t += delta
		if _switch_t > SWITCH_T:
			_begin_descend(him,"climb")
			return
	else:
		_switch_t = 0.0
	if mine < 0:
		# Off its ground (pushed off, a rim crumbled): back up onto his.
		_begin_climb()
		return
	# Off the isle (a bridge, the air): the nearest of its own ground to him.
	if his != mine:
		var c := nav.nearest(target,24.0,mine)
		if c != Nav.NONE: target = nav.ground_point(c)
	var aim := target
	if not nav.clear_line(_head,target):
		_replan -= delta
		if _replan <= 0.0 or _path.is_empty():
			_replan = REPLAN
			_path = nav.path(_head,target)
		aim = _pursue(target)
	var d := Vector2(him.x-_head.x,him.z-_head.z).length()
	var k := CHASE_LEVEL if stage >= 4 else _chase_k
	if d > CATCH_UP: k = CHASE_FAR
	_speed = move_toward(_speed,_run()*k,delta*4.0)
	_steer(aim,delta,true)
	_ground_m += _speed*delta
	if playing and _cool <= 0.0 and _ground_m >= GROUND_FIRST and _can_strike(): _begin_rear()
	# Give up (stage 3 only): unseen too long.
	if stage == 3 and _unseen > GIVE_UP_T and act == "chase":
		hunting = false
		awareness = 0.35
		_begin_descend(_anchor,"coil")
		if _debug: print("[linger] gave up at %.1f s" % clock)

## The furthest point of the path it can slither straight to (string
## pulled), within LOOKAHEAD m.
func _pursue(target: Vector3) -> Vector3:
	if _path.is_empty(): return target
	var best := _path[0]
	var gone := 0.0
	var last := _head
	for i in range(_path.size()):
		var p := _path[i]
		gone += Vector2(p.x-last.x,p.z-last.z).length()
		last = p
		if gone > LOOKAHEAD: break
		if nav.clear_line(_head,p): best = p
	return best

## Close, in front, with a clear line to his chest.
func _can_strike() -> bool:
	var chest := _chest()
	var mouth := _mouth()
	if mouth.distance_to(chest) > STRIKE_AT: return false
	var fwd := Vector3(_dir.x,0.0,_dir.z).normalized()
	var to := Vector3(chest.x-_head.x,0.0,chest.z-_head.z)
	if to.length() > 1.0 and fwd.angle_to(to.normalized()) > STRIKE_CONE: return false
	if _blocked(_head,chest+Vector3.UP*0.6):
		covered += 1
		return false
	return true

func _begin_rear() -> void:
	_committed = false
	_wound = 0.0
	_bit = false
	_set_act("rear")
	_voice_play("serpent-breath-%d.wav" % _rng.randi_range(1,2),0.7,0.0)

## Let go at the aim (where he stood as the hold began), no further than
## LUNGE_REACH, short of stone between.
func _lunge() -> void:
	# The mouth is back of the snout's tip: the tip goes on past the aim
	# by that much, so the jaws close on it.
	var way := (_aim-_head).normalized()
	var flat := Vector3(way.x,0.0,way.z).normalized()
	# Stone between it and him stops it short (cover); what is past him
	# doesn't.
	if _blocked(_head,_aim):
		var hit := _ray(_head,_aim)
		if not hit.is_empty():
			_aim = (hit.position as Vector3)-way*2.0
			flat = Vector3.ZERO
	var tip := _aim+flat*MOUTH_BACK*_scale
	var to := tip-_head
	if to.length() > LUNGE_REACH: tip = _head+to.normalized()*LUNGE_REACH
	_aim = tip
	_lunge_from = _head
	_lunged = 0.0
	_wound = 0.0
	_last_mouth = _mouth()
	strikes += 1
	_set_act("lunge")
	_voice_play("whoosh-%d.wav" % _rng.randi_range(1,4),0.5,3.0)
	if _debug: print("[linger] lunge %.1f m, he is %.1f m off the aim" % [_head.distance_to(_aim),_chest().distance_to(_aim)])

## Its mouth passed from `_last_mouth` to now: within BITE_R of his chest,
## a bite.
func _check_hit() -> void:
	var m: Object = _motor()
	if m == null or _bit or not _playing(): return
	var chest := _chest()
	var mouth := _mouth()
	var snout: Vector3 = body.to_global(body.way_snout())
	var near := Geometry3D.get_closest_point_to_segment(chest,_last_mouth,mouth)
	var jaws := Geometry3D.get_closest_point_to_segment(chest,mouth,snout)
	if _debug and act == "bite" and _act_t < 0.02: print("[linger] bite check: chest %s mouth %s snout %s near %.2f jaws %.2f" % [str(chest.round()),str(mouth.round()),str(snout.round()),chest.distance_to(near),chest.distance_to(jaws)])
	if minf(chest.distance_to(near),chest.distance_to(jaws)) > BITE_R*sqrt(_scale/SCALE): return
	if bool(m.get("_seized")): return
	hits += 1
	_bit = true
	# Thrown on along the strike and toward the rim nearest him.
	var away := Vector3(chest.x-_lunge_from.x,0.0,chest.z-_lunge_from.z).normalized()
	var his := _his_isle()
	if his >= 0:
		var r := nav.rim(his,chest,chest,0.0)
		if not r.is_empty(): away = (away+(r.out as Vector3)*0.35).normalized()
	var v: Vector3 = m.knock_velocity(Vector2(away.x,away.z),KNOCK.x,KNOCK.y)
	m.knock(v,self,KNOCK_DOWN)
	m.harm("serpent",1,self)
	if act == "lunge":
		_set_act("bite")
		_bitten()

func _bitten() -> void:
	_voice_play("dragon-slam-%d.wav" % _rng.randi_range(1,2),0.8,-2.0)
	NoiseBus.make(self,_head,40.0,&"serpent_bite")

# --- Its body on him ----------------------------------------------------------------

## The body moving into him pushes him out of it (its capsules stop his
## own walking into it; this is it coming into him).
func _push_him(delta: float) -> void:
	var m: Object = _motor()
	if m == null: return
	var f: Vector3 = m.feet
	var chest := f+Vector3.UP*0.9
	var push := Vector3.ZERO
	var caps := body.capsules()
	# Not the head's: its bite is the strike's.
	caps.pop_back()
	for cap: Array in caps:
		var a: Vector3 = cap[0]
		var b: Vector3 = cap[1]
		var r := float(cap[2])
		var lo := minf(a.y,b.y)-r
		var hi := maxf(a.y,b.y)+r
		if chest.y < lo-1.0 or f.y > hi: continue
		var q := Geometry3D.get_closest_point_to_segment(chest,a,b)
		var off := chest-q
		var d := off.length()
		var need := r+PUSH_SKIN
		if d >= need: continue
		# On top of it (stood on its back): not pushed.
		if f.y > q.y+r*0.55: continue
		var flat := Vector3(off.x,0.0,off.z)
		if flat.length() < 0.01: flat = Vector3(_dir.z,0.0,-_dir.x)
		push += flat.normalized()*(need-d)
	if push.length() > 0.001:
		m.feet = f+push.limit_length(PUSH_RATE*delta)

# --- The drape ------------------------------------------------------------------------

## Round 3: how far further out (m) the drape hangs from the rim so that it
## clears the drawn stone under it; tried in DRAPE_OUT steps; eased at
## DRAPE_OUT_PACE m/s.
const DRAPE_OUT := [0.0,4.0,8.0,12.0,16.0]
const DRAPE_TRIES := 5
const DRAPE_EXTRA_COST := 2.5
const DRAPE_OUT_PACE := 4.0
var _drape_extra := 0.0
func _drape_clearance(r: Dictionary) -> float:
	if shell == null: return 0.0
	var at: Vector3 = r.at
	var out: Vector3 = r.out
	for extra: float in DRAPE_OUT:
		var over := at+out*(_ride*0.9+extra)+Vector3.UP*_ride*0.7
		var lip := over+out*6.0+Vector3.DOWN*4.0
		if _clear_cast(over,lip-over) and _clear_cast(lip,(Vector3.DOWN+out*0.4).normalized()*45.0): return extra
	return float(DRAPE_OUT[DRAPE_OUT.size()-1])

## Past ON_ISLE m of body on an isle, the rest of it laid from there over
## the nearest rim and down into the void.
func _drape_step(delta: float) -> void:
	var b := body
	var a0: float = float(b.travelled)-ON_ISLE/_scale
	var p0 := Vector3.INF
	var on := false
	if a0 > 0.0 and nav.ready():
		p0 = b.to_global(b.real_trail_at(a0)[0])
		var c := nav.nearest(p0,4.0)
		if c != Nav.NONE:
			var g := nav.height(p0)
			on = not is_nan(g) and absf(p0.y-(g+_ride)) < _ride*1.5
	_drape_w = move_toward(_drape_w,1.0 if on else 0.0,delta*1.2)
	if _drape_w <= 0.0:
		b.drape_w = 0.0
		return
	# The rim it goes over: nearest p0, kept unless another is much nearer.
	_drape_t -= delta
	if on and (_drape_rim.is_empty() or _drape_t <= 0.0):
		_drape_t = 0.5
		var isle := nav.isle_of(nav.nearest(p0,4.0))
		var r := nav.rim(isle,p0,p0,0.0)
		# Round 3: of the nearest few rims, the one it hangs clear from
		# soonest (out past a landing's corbel, a ledge, the rock's flare,
		# away from a crossing's columns), a little further off allowed.
		if settled and not r.is_empty():
			var best := INF
			for c: Dictionary in nav.rim_offs(isle,p0,p0,0.0,DRAPE_TRIES):
				var extra := _drape_clearance(c)
				var score := (c.at as Vector3).distance_to(p0)+extra*DRAPE_EXTRA_COST
				if score < best:
					best = score
					r = c
					r["extra"] = extra
		if not r.is_empty():
			var keep := not _drape_rim.is_empty() and float(_drape_rim.get("score",(_drape_rim.at as Vector3).distance_to(p0))) < (r.at as Vector3).distance_to(p0)+float(r.get("extra",0.0))*DRAPE_EXTRA_COST+14.0
			if keep: _drape_rim["score"] = (_drape_rim.at as Vector3).distance_to(p0)+float(_drape_rim.get("extra",0.0))*DRAPE_EXTRA_COST
			else: _drape_rim = r
	if _drape_rim.is_empty():
		b.drape_w = 0.0
		return
	var step := Body.DRAPE_STEP*_scale
	var back: Vector3 = b.to_global(b.real_trail_at(a0-2.0/_scale)[0])
	var t0 := (back-p0)
	t0.y = 0.0
	t0 = t0.normalized() if t0.length() > 0.01 else -_dir
	var rim_at: Vector3 = _drape_rim.at
	var out: Vector3 = _drape_rim.out
	_drape_extra = move_toward(_drape_extra,float(_drape_rim.get("extra",0.0)),delta*DRAPE_OUT_PACE)
	var over := rim_at+out*(_ride*0.9+_drape_extra)+Vector3.UP*_ride*0.7
	var span := Vector2(over.x-p0.x,over.z-p0.z).length()
	var pts := PackedVector3Array()
	var n := maxi(2,ceili(span*1.3/step))
	var m0 := t0*span*1.1
	var m1 := out*span*1.1
	var last := p0
	var arc := 0.0
	pts.append(b.to_local(p0))
	# Over the isle to the rim (on the ground), sampled finely and laid at
	# even steps.
	var fine: Array[Vector3] = [p0]
	for i in range(1,n*3+1):
		var t := float(i)/float(n*3)
		var p := Body._hermite(p0,m0,over,m1,t)
		var g := nav.height(p)
		if not is_nan(g): p.y = maxf(p.y,g+_ride*0.95)
		fine.append(p)
	# Then over the lip and down: a bend from out to down, straight down.
	var bend := 9.0
	for i in range(1,9):
		var a := float(i)/8.0*PI*0.39
		fine.append(over+out*sin(a)*bend+Vector3.DOWN*(1.0-cos(a))*bend)
	var bottom := fine[fine.size()-1]
	var rest := Body.LENGTH*_scale-ON_ISLE+20.0
	# Down, leaning out a little (a ring's frame needs a way across).
	fine.append(bottom+(Vector3.DOWN+out*0.4).normalized()*rest)
	for i in range(1,fine.size()):
		var p := fine[i]
		var seg := last.distance_to(p)
		while arc+seg >= step:
			var f := (step-arc)/seg
			last = last.lerp(p,f)
			seg = last.distance_to(p)
			arc = 0.0
			pts.append(b.to_local(last))
		arc += seg
		last = p
	b.drape = pts
	b.drape_a0 = a0
	b.drape_w = _smooth(_drape_w)

# --- Seeing and hearing ------------------------------------------------------------

func _sight_step(delta: float) -> void:
	_sight_t -= delta
	if _sight_t <= 0.0:
		_sight_t = 0.1
		_visible = _sight()
	var up := _head.y > _feet().y-70.0 and clock >= SEARCH*0.92
	var fill := (LEVEL_FILL if stage >= 4 else FILL)
	if up and _visible > 0.05:
		_unseen = 0.0
		awareness = minf(1.0,awareness+fill*_visible*delta)
	else:
		_unseen += delta
		if _unseen > GRACE: awareness = maxf(0.0,awareness-DRAIN*delta*(0.5 if stage >= 4 else 1.0))
	if not hunting and (awareness >= 1.0 or stage >= 4):
		hunting = true
		sightings += 1
		_unseen = 0.0
		if _debug: print("[linger] sees him at %.1f s" % clock)

## How plainly it sees him now (0..1). On the isle it looks all round
## (its whole head turns to him); from the void through its cone.
func _sight() -> float:
	var b := body
	var eye: Vector3 = b.to_global(b.snout())+Vector3.UP*1.5
	var look: Vector3 = (b.global_transform.basis*(b.look_dir() as Vector3)).normalized()
	var pts := _points()
	var got := 0
	var dist := eye.distance_to(pts[1])
	if dist > SIGHT: return 0.0
	var all_round := act != "coil"
	for p in pts:
		var to := p-eye
		if not all_round and look.angle_to(to) > CONE: continue
		if _blocked(eye,p): continue
		got += 1
	if got == 0: return 0.0
	var k := float(got)/pts.size()
	k *= lerpf(1.0,FAR_SEEN,clampf((dist-NEAR)/(SIGHT-NEAR),0.0,1.0))
	if all_round: return clampf(k,0.0,1.0)
	var m: Object = _motor()
	if m != null:
		var v: Vector3 = m.velocity
		var flat := Vector2(v.x,v.z).length()
		if not bool(m.grounded): k *= SEEN_AIR
		elif bool(m.crouch) or String(m.move) == "crouch" or String(m.move) == "slide": k *= SEEN_CROUCH
		elif flat < 0.4: k *= SEEN_STILL
		elif flat < 2.4: k *= SEEN_CREEP
	return clampf(k,0.0,1.0)

## Stone between `a` and `b` (its own body not counted), more than a
## step short of `b`.
func _blocked(a: Vector3, b: Vector3) -> bool:
	var from := a
	for i in range(3):
		var hit := _ray(from,b)
		if hit.is_empty(): return false
		var p: Vector3 = hit.position
		if p.distance_to(b) <= 0.6: return false
		# The isle's own ground rolling between is not cover (its head
		# goes over it); stone standing up off the ground is.
		var g := nav.height(p)
		if is_nan(g) or p.y > g+COVER_TALL or nav._tall.has(nav.cell_of(p)): return true
		from = p+(b-p).normalized()*0.8
	return false

func _ray(a: Vector3, b: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	if space == null: return {}
	var q := PhysicsRayQueryParameters3D.create(a,b,1)
	q.exclude = [body.solid_rid()]
	return space.intersect_ray(q)

func _hear() -> void:
	var bus := NoiseBus.of(get_tree())
	if bus == null: return
	for n: NoiseBus.Sound in bus.since(_noise_id):
		_noise_id = n.id
		if n.source == self or n.loudness < 9.0: continue
		var h := n.heard_at(_head,HEAR)
		if h <= 0.0: continue
		_noise_at = n.position
		_noise_t = NOISE_TURN
		if stage >= 2: awareness = minf(1.0,awareness+0.25*h)

# --- The void -------------------------------------------------------------------

func _clear(p: Vector3, r: float) -> bool:
	var space := get_world_3d().direct_space_state
	var top := _feet().y+160.0
	var bottom := float(layer.get("void_y",-200.0))-60.0
	for i in range(9):
		var q := Vector3(p.x,0.0,p.z)
		if i > 0:
			var a := TAU*float(i)/8.0
			q += Vector3(cos(a),0.0,sin(a))*r
		for isle: Dictionary in layer.get("isles",[]):
			var occ := LayerPlan.occ_at(isle,q.x,q.z)
			if occ.x < INF: return false
		if space != null:
			var ray := PhysicsRayQueryParameters3D.create(Vector3(q.x,top,q.z),Vector3(q.x,bottom,q.z),1)
			if body != null: ray.exclude = [body.solid_rid()]
			if not space.intersect_ray(ray).is_empty(): return false
	return true

func _pick_anchor(near: bool, f: Vector3) -> Vector3:
	var exit: Dictionary = layer.get("exit",{})
	var back := Vector2(0.0,1.0)
	if exit.has("at"):
		var e: Vector3 = exit.at
		back = Vector2(f.x-e.x,f.z-e.z)
		back = back.normalized() if back.length() > 1.0 else Vector2(0.0,1.0)
	var ring: Array = NEAR_RING if near else FAR_RING
	var best := Vector3.INF
	var score := -INF
	for r: float in ring:
		for i in range(20):
			var a := TAU*float(i)/20.0
			var dir := Vector2(cos(a),sin(a))
			var c := Vector3(f.x+dir.x*r,0.0,f.z+dir.y*r)
			var s := dir.dot(back)*1.0-(Vector2(c.x-_anchor.x,c.z-_anchor.z).length()/300.0 if _anchor != Vector3.ZERO else 0.0)
			if s <= score: continue
			if not _clear(c,COIL*0.7): continue
			score = s
			best = c
	if best == Vector3.INF:
		var far := Vector2(back.x,back.y)*200.0
		return Vector3(f.x+far.x,0.0,f.z+far.y) if _anchor == Vector3.ZERO else _anchor
	return best

func _lay_coiled() -> void:
	var y := _level_y+height_at(clock)
	var r := COIL
	var a0 := _rng.randf()*TAU
	_head = Vector3(_anchor.x+cos(a0)*r,y,_anchor.z+sin(a0)*r)
	var length := Body.LENGTH*_scale+30.0
	var pitch := 26.0
	var pts: Array[Vector3] = []
	var s := 0.0
	var a := a0
	while s <= length:
		var p := Vector3(_anchor.x+cos(a)*r,y-pitch*s/(TAU*r),_anchor.z+sin(a)*r)
		pts.push_front(p)
		a -= _spin*1.0/r
		s += 1.0
	var local := PackedVector3Array()
	for p in pts: local.append(body.to_local(p))
	body.lay(local)
	_dir = (pts[pts.size()-1]-pts[pts.size()-2]).normalized()

# --- Sound ------------------------------------------------------------------------

func _sounds() -> void:
	_scrape = _bed(KIT+"stone-grind-loop.wav",0.42)
	_grind = _bed(KIT+"serpent-scales-loop.wav",0.55)
	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 70.0
	_voice.max_distance = 900.0
	_voice.bus = _bus()
	add_child(_voice)

func _bus() -> StringName:
	return &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"

func _bed(path: String, pitch: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = load(path)
	p.pitch_scale = pitch
	p.unit_size = 60.0
	p.max_distance = 1000.0
	p.volume_db = -60.0
	p.bus = _bus()
	add_child(p)
	p.finished.connect(p.play)
	p.play()
	return p

func _voice_play(file: String, pitch: float, db: float, for_s := -1.0) -> void:
	if _voice == null: return
	_voice.stream = load(KIT+file)
	_voice.pitch_scale = pitch
	_voice.volume_db = db
	_voice.global_position = _head
	_voice.play()
	if for_s > 0.0:
		get_tree().create_timer(for_s).timeout.connect(func() -> void: if is_instance_valid(_voice) and _voice.stream != null and String(_voice.stream.resource_path).ends_with(file): _voice.stop())

## The scrape at the ring nearest him, louder as it rises and as it moves;
## its breath at the head now and then.
func _sound_step(delta: float) -> void:
	if _scrape == null: return
	var listen := _feet()
	var rings: PackedVector3Array = body.rings()
	var near := _head
	var best := INF
	for i in range(0,rings.size(),3):
		var p: Vector3 = body.to_global(rings[i])
		var d := p.distance_squared_to(listen)
		if d < best:
			best = d
			near = p
	var rise := clampf((clock-STIR*0.5)/(LEVEL-STIR*0.5),0.0,1.0)
	if act != "coil": rise = 1.0
	var moving := clampf(_speed/PACE,0.25,1.4)
	var db := lerpf(SCRAPE_DB.x,SCRAPE_DB.y,rise)+linear_to_db(moving)
	_scrape.global_position = near
	_grind.global_position = near
	_scrape.volume_db = move_toward(_scrape.volume_db,db,delta*20.0)
	_grind.volume_db = move_toward(_grind.volume_db,db-4.0,delta*20.0)
	_breath_t -= delta
	if _breath_t <= 0.0 and act in ["coil","chase"] and stage >= 2:
		_breath_t = _rng.randf_range(6.0,10.0)
		_voice_play("serpent-breath-%d.wav" % _rng.randi_range(1,2),0.55,-4.0)

static func _smooth(x: float) -> float:
	x = clampf(x,0.0,1.0)
	return x*x*(3.0-2.0*x)

# --- Probes (drivers) -------------------------------------------------------------

func head() -> Vector3:
	return _head

func anchor() -> Vector3:
	return _anchor

func mouth() -> Vector3:
	return _mouth()
