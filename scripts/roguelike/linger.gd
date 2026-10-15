extends Node3D
## The linger threat, the serpent (docs/design/roguelike/linger-serpent-round1.md):
## Spelunky's ghost for the Olmec city. Stay on a layer and a colossal stone
## serpent with a feathered ruff (scripts/roguelike/linger_serpent.gd)
## climbs up out of the void toward you, coiling round a column of open air
## off the isles. No timer on the screen: the clock is read by looking back.
##
## 1. **Below** (from the start): its coils glimpsed deep in the haze under
##    the isles, rising slowly; a low scraping of stone on stone.
## 2. **Rising** (SEARCH s on): its head clears the haze and searches, a
##    slow deliberate sweep over the isles. Seen only in the open: cover
##    (stone between), a crouch, standing still or creeping keep him hidden
##    (`_sight`); a loud noise on the NoiseBus turns its search that way.
## 3. **It sees you**: it rises to a poise off your isle's edge, holds,
##    fixed on you (the dread beat), draws back with its jaw opening, holds,
##    and strikes: head and neck across onto your isle, a bite that hurts
##    (the motor's `harm`, one heart) and throws you. Then it recoils.
##    Dodgeable: the snap goes where you stood as it let go.
## 4. **Level** (LEVEL s on): poised at your height, it finds you sooner
##    and strikes faster. Only the gate gets you away; every layer begins
##    it again (it lives on the layer's stage).
##
## On by default: `--no-linger` (or `--loot=off`) leaves it out,
## `--linger=colossus` is another agent's threat. Knobs:
##   --linger-at=<s>       start the clock this far on (100: rising, 150: level)
##   --linger-pace=<x>     it all runs x times as fast (a fast-forward)
##   --linger-scale=<x>    its size (the rune serpent's times x; 2.4)
##   --linger-debug        its stage changes in the log
const RunFeatures = preload("res://scripts/roguelike/run_features.gd")
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const Body = preload("res://scripts/roguelike/linger_serpent.gd")

## The clock (s from the layer's start): its coils begin to rise (STIR),
## its head clears the haze and searches (SEARCH), it is level with you
## (LEVEL).
const STIR := 20.0
const SEARCH := 95.0
const LEVEL := 150.0
## Its head's height over his (m, eased) by the clock: deep in the haze
## (DEEP), clearing his level far off (CLEAR, at SEARCH), reared HIGH over
## it far off as it searches (by LEVEL), then near, coiling about POISED
## (give or take 18 m) and rearing up to strike.
const DEEP := -240.0
const CLEAR := -10.0
const HIGH := 22.0
const POISED := -6.0
## Crossing to a column further than this off (m), it goes under, DIVE m
## below him, so it never sweeps over an isle.
const CROSS := 40.0
const DIVE := 65.0
## Its size: the rune serpent's (90 m long, 4 m through) times SCALE.
const SCALE := 2.4
## The column of air it coils round: how far from him (m; far while it
## searches, near once it hunts), the coil's radius calm and gathered (m).
const FAR_RING := [95.0,120.0,145.0]
const NEAR_RING := [48.0,58.0,70.0]
const COIL := 22.0
const COIL_TIGHT := 16.0
## Its head's pace (m/s) coiling calm, gathered, and coming in to strike;
## its turn (rad/s) at most; its climb's slope at most (sine).
const PACE := 6.0
const PACE_HUNT := 9.0
const PACE_APPROACH := 15.0
## Swaying by its poise between strikes (m/s).
const SWAY_PACE := 3.0
const TURN := 0.55
const CLIMB := 0.5
## The strike: the poise off his isle's edge (m out from him, up over him),
## the hold fixed on him (s: first sight, after), the wind-up (s, m drawn
## back), the held breath (s), the snap's speed (m/s) and longest reach
## (m), the bite held (s), the recoil (m/s), the rest before the next (s,
## rising and level).
const POISE_OUT := 30.0
const POISE_UP := 13.0
## Rearing: the approach comes under the poise this far down and out (m)
## and rears up into it at most REAR_PACE m/s.
const REAR_DOWN := 24.0
const REAR_OUT := 18.0
const REAR_PACE := 9.0
const FIX := 1.9
const FIX_AGAIN := 1.0
const FIX_LEVEL := 0.7
const WIND := 0.75
const WIND_LEVEL := 0.55
const WIND_BACK := 7.0
const HOLD := 0.28
const HOLD_LEVEL := 0.18
const SNAP_SPEED := 72.0
## The jaw at its widest (rad).
const JAW_WIDE := 0.62
const REACH := 60.0
const BITE := 0.35
const RECOIL := 22.0
const REST := 4.5
const REST_LEVEL := 2.2
## A hit: within HIT m of its jaws as they pass; thrown KNOCK (out, up m),
## down KNOCK_DOWN s.
const HIT := 3.0
const KNOCK := Vector2(7.0,2.4)
const KNOCK_DOWN := 0.6
## Sight: its reach (m), its cone's half angle (rad), fully seen within
## NEAR m, FAR_SEEN of him at the reach; awareness filled a second at
## visibility 1 (FILL, LEVEL_FILL), drained (DRAIN) after GRACE s unseen;
## it hunts at 1 and gives up under GIVE_UP. How plain he is: crouched,
## still, creeping, in the air.
const SIGHT := 175.0
const CONE := 0.8
const NEAR := 45.0
const FAR_SEEN := 0.35
const FILL := 0.55
const LEVEL_FILL := 1.1
const DRAIN := 0.12
const GRACE := 2.0
const GIVE_UP := 0.3
const SEEN_CROUCH := 0.35
const SEEN_STILL := 0.55
const SEEN_CREEP := 0.7
const SEEN_AIR := 1.2
## Its search: the sweep (rad either side, period s); a noise heard within
## its loudness times HEAR m turns it there for NOISE_TURN s.
const SWEEP := 0.95
const SWEEP_PERIOD := 9.0
const HEAR := 5.0
const NOISE_TURN := 5.0
## Sounds (assets/audio/kit): the scrape's gain (dB) far below and level,
## its pitch.
const SCRAPE_DB := Vector2(-16.0,-3.0)
const KIT := "res://assets/audio/kit/"

## Its stage (1 below, 2 rising, 3 hunting you, 4 level) and what its head
## does ("coil", "approach", "fix", "wind", "hold", "snap", "bite",
## "recoil"); the clock; how aware of him it is (0..1).
var stage := 1
var act := "coil"
var clock := 0.0
var awareness := 0.0
var hunting := false
## Counts, for drivers: strikes, hits, times it saw him.
var strikes := 0
var hits := 0
var sightings := 0
## Its frame's cost (µs), the worst yet.
var last_usec := 0
var worst_usec := 0

var study: Node3D
var loop: Node
var layer: Dictionary
var body: Body
var _scale := SCALE
var _pace_k := 1.0
var _debug := false
## Its head (world), way, pace; the column it coils round (world, y unused)
## and its turning sense; the poise and the snap's target.
var _head := Vector3.ZERO
var _dir := Vector3.FORWARD
var _speed := PACE
var _anchor := Vector3.ZERO
var _spin := 1.0
var _poise := Vector3.ZERO
var _target := Vector3.ZERO
var _snap_from := Vector3.ZERO
var _snapped := 0.0
var _wound := 0.0
## This strike has bitten him (one bite a strike).
var _bit := false
## The approach's second leg (rearing up into the poise), its way out from
## him, the climb's slope allowed now.
var _rearing := false
var _poise_out := Vector3.ZERO
var _climb := CLIMB
var _act_t := 0.0
var _rest := 0.0
var _anchor_t := 0.0
var _sight_t := 0.0
var _unseen := 0.0
var _visible := 0.0
var _level_y := 0.0
var _noise_id := 0
var _noise_at := Vector3.INF
var _noise_t := 0.0
var _fix_for := FIX
var _sweep_c := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _scrape: AudioStreamPlayer3D
var _grind: AudioStreamPlayer3D
var _voice: AudioStreamPlayer3D
var _breath_t := 3.0

## Lays it on `stage` for `plan` (the run loop's layer just stood), unless
## it is off. Returns it, or null.
static func lay(run_loop: Node, stage_node: Node3D, plan: Dictionary) -> Node3D:
	if not RunFeatures.on(&"linger") or RunFeatures.value("linger","serpent") != "serpent": return null
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
	_debug = "--linger-debug" in LaunchArgs.user_args()
	_spin = 1.0 if _rng.randf() < 0.5 else -1.0
	body = Body.new()
	add_child(body)
	body.global_transform = Transform3D(Basis.from_scale(Vector3.ONE*_scale),Vector3.ZERO)
	body.build(study)
	_level_y = _feet().y
	_anchor = _pick_anchor(false,_feet())
	_lay_coiled()
	_sounds()
	_stage_now()

# --- Him ----------------------------------------------------------------------

func _motor() -> Object:
	return study.get("motor") if study != null else null

func _feet() -> Vector3:
	var m: Object = _motor()
	return m.feet if m != null else Vector3.ZERO

## His feet, chest and head (world).
func _points() -> PackedVector3Array:
	var f := _feet()
	return PackedVector3Array([f+Vector3.UP*0.35,f+Vector3.UP*1.05,f+Vector3.UP*1.7])

func _playing() -> bool:
	if loop == null: return true
	var st := String(loop.get("state"))
	if st != "play" and st != "arrive": return false
	var loading: Variant = study.get("loading")
	return not (loading != null and loading.active)

# --- The clock ----------------------------------------------------------------

## Its head's height over him (m) at `t` s.
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
	# The pace knob runs all of it faster (a fast-forward to judge it by).
	delta = minf(delta,0.1)*_pace_k
	var playing := _playing()
	if playing: clock += delta
	# His height, eased (a jump doesn't jerk it).
	_level_y = lerpf(_level_y,_feet().y,1.0-exp(-0.5*delta))
	if playing:
		_hear()
		_sight_step(delta)
	elif act in ["approach","fix","wind","hold"]:
		_set_act("coil")
	_stage_now()
	_anchor_step(delta)
	_head_step(delta)
	_sound_step(delta)
	last_usec = Time.get_ticks_usec()-began
	worst_usec = maxi(worst_usec,last_usec)

## Its column: re-picked now and then, near him once it hunts.
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
	if _debug and next != act: print("[linger] %s -> %s at %.1f s (head %.1f m from him, %.1f from its poise)" % [act,next,clock,_head.distance_to(_feet()),_head.distance_to(_poise)])
	if next == "wind": _wound = 0.0
	act = next
	_act_t = 0.0

func _head_step(delta: float) -> void:
	_act_t += delta
	var b := body
	var f := _feet()
	var chest := f+Vector3.UP*1.05
	var snap := false
	var goal_speed := PACE
	var goal := Vector3.ZERO
	var look_at := Vector3.INF
	b.fixed = act in ["fix","wind","hold","snap","bite"]
	match act:
		"coil":
			_rest -= delta
			_climb = CLIMB
			var tight := 1.0 if hunting or stage >= 4 else 0.0
			var r := lerpf(COIL,COIL_TIGHT,tight)*(1.0+0.22*sin(clock*0.05))
			var y := _level_y+height_at(clock)
			if stage >= 4: y += 18.0*sin(clock*0.12)
			goal = _under(_helix(r,y),r+CROSS*0.5)
			goal_speed = lerpf(PACE,PACE_HUNT,tight)
			if Vector2(_head.x-_anchor.x,_head.z-_anchor.z).length() > r+CROSS*0.5: goal_speed = PACE_APPROACH*0.8
			elif _head.y < y-12.0: goal_speed *= 1.5
			# Between strikes it stays by its poise, swaying, ready.
			if hunting and strikes > 0 and _head.distance_to(_poise) < 30.0:
				goal = _poise+Vector3(cos(clock*0.7)*7.0,-3.0+2.0*sin(clock*0.9),sin(clock*0.7)*7.0)
				goal_speed = SWAY_PACE
			if hunting and _rest <= 0.0 and _playing(): _begin_strike(f)
			look_at = _search_point(delta)
		"approach":
			# Under the poise and out from it first, then reared up into it,
			# so the neck stands out of the void behind the head.
			var low := _poise+_poise_out*REAR_OUT+Vector3.DOWN*REAR_DOWN
			if not _rearing and _head.distance_to(low) < 15.0: _rearing = true
			goal = _poise if _rearing else _under(low,CROSS)
			look_at = chest
			var d := _head.distance_to(goal)
			goal_speed = minf(PACE_APPROACH,2.0+d*0.9) if not _rearing else minf(REAR_PACE,1.5+d*0.5)
			# Slower while it turns toward it, so it never orbits the spot.
			var off := _dir.angle_to((goal-_head).normalized()) if _head.distance_to(goal) > 0.1 else 0.0
			goal_speed *= lerpf(1.0,0.3,clampf(off/PI*1.5,0.0,1.0))
			_climb = 0.8 if _rearing else CLIMB
			var flat_d := Vector2(_head.x-_poise.x,_head.z-_poise.z).length()
			if _rearing and (d < 3.5 or (_head.y > _poise.y-2.5 and flat_d < 5.0)):
				_fix_for = FIX if strikes == 0 else (FIX_LEVEL if stage >= 4 else FIX_AGAIN)
				_set_act("fix")
			elif _act_t > 25.0: _set_act("coil")
		"fix":
			# Nodding over toward him as it slows.
			goal_speed = 0.0
			var over := Vector3(chest.x-_head.x,0.0,chest.z-_head.z).normalized()
			goal = _head+over*10.0+Vector3.DOWN*2.0
			look_at = chest
			if _act_t >= _fix_for: _set_act("wind")
		"wind":
			goal_speed = 0.0
			look_at = chest
			var wind := WIND_LEVEL if stage >= 4 else WIND
			var k := _smooth(_act_t/wind)
			var want := WIND_BACK*k/_scale
			var room: float = b.rewind_room()
			var back := minf(want-_wound,room)
			if back > 0.0:
				_wound += b.rewind(back)
				_head = b.to_global(b.live())
			b.jaw = lerpf(0.15,JAW_WIDE,k)
			b.stretch = lerpf(1.0,0.84,k)
			if _act_t >= wind:
				_set_act("hold")
		"hold":
			goal_speed = 0.0
			look_at = chest
			b.jaw = JAW_WIDE
			b.stretch = 0.82
			if _act_t >= (HOLD_LEVEL if stage >= 4 else HOLD): _release(chest)
		"snap":
			snap = true
			var step := SNAP_SPEED*delta
			var to := _target-_head
			var last := _head
			if to.length() <= step:
				_head = _target
			else:
				_head += to.normalized()*step
			_snapped += b.go_to(b.to_local(_head))
			b.jaw = JAW_WIDE
			b.stretch = 1.28
			_check_hit(last)
			if act == "snap" and _head.distance_to(_target) < 0.05:
				_set_act("bite")
				_bitten()
			goal_speed = 0.0
		"bite":
			goal_speed = 0.0
			var k := clampf(_act_t/0.07,0.0,1.0)
			b.jaw = lerpf(JAW_WIDE,0.0,k)
			b.stretch = lerpf(0.8,1.0,_smooth((_act_t-0.05)/0.25))
			if _act_t < 0.12: _check_hit(_head)
			if _act_t >= BITE: _set_act("recoil")
		"recoil":
			goal_speed = 0.0
			var left: float = _snapped
			var go := minf(RECOIL*delta/_scale*lerpf(1.6,0.6,_smooth(_act_t/1.0)),left)
			var went: float = b.rewind(go)
			_snapped -= went
			_head = b.to_global(b.live())
			b.jaw = 0.1
			b.stretch = 1.0
			look_at = chest
			if _snapped <= 0.001 or went <= 0.0:
				_snapped = 0.0
				_rest = REST_LEVEL if stage >= 4 else REST
				_dir = (b.global_transform.basis*b.way()).normalized()
				_set_act("coil")
	if act in ["coil","approach","fix"]:
		if act != "fix":
			b.jaw = move_toward(float(b.jaw),0.12 if hunting else 0.0,delta*0.3)
			b.stretch = move_toward(float(b.stretch),1.0,delta*2.0)
		else:
			b.jaw = move_toward(float(b.jaw),0.18,delta*0.25)
			b.stretch = move_toward(float(b.stretch),1.0,delta*2.0)
		_speed = move_toward(_speed,goal_speed,delta*(6.0 if goal_speed < _speed else 3.0))
		if _speed > 0.01: _steer(goal,delta)
	elif act != "snap":
		_speed = 0.0
	b.pace = _speed/_scale
	_look(look_at)
	b.step(delta,snap)

## Its head steered toward `goal` (world): turning at most TURN rad/s
## (tighter at a slower pace), climbing at most CLIMB, and on along its way.
func _steer(goal: Vector3, delta: float) -> void:
	var want := goal-_head
	if want.length() < 0.01: want = _dir
	want = want.normalized()
	want.y = clampf(want.y,-_climb,_climb)
	want = want.normalized()
	var turn := TURN*clampf(_speed/PACE,0.6,1.6)*delta*(4.0 if act == "fix" else (2.0 if _rearing and act == "approach" else (1.5 if act == "approach" else 1.0)))
	var angle := _dir.angle_to(want)
	if angle > 1e-4:
		_dir = _dir.slerp(want,minf(turn/angle,1.0)).normalized()
	# A slow heave up and down, so even a flat coil rides on a wave.
	var heave := Vector3.UP*0.05*sin(float(body.travelled)*_scale/38.0)
	_head += (_dir+heave).normalized()*_speed*delta
	body.go_to(body.to_local(_head))

## `goal`, or under it (DIVE m below him) while its head is more than
## `far` m off it across: the way across goes under the isles.
func _under(goal: Vector3, far: float) -> Vector3:
	if Vector2(goal.x-_head.x,goal.z-_head.z).length() <= far: return goal
	return Vector3(goal.x,minf(goal.y,_level_y-DIVE),goal.z)

## The helix's point ahead of its head round the column at radius `r`,
## height `y`: the head chases it, so it circles and climbs.
func _helix(r: float, y: float) -> Vector3:
	var rel := Vector2(_head.x-_anchor.x,_head.z-_anchor.z)
	var a := atan2(rel.y,rel.x)+_spin*0.55
	return Vector3(_anchor.x+cos(a)*r,y,_anchor.z+sin(a)*r)

## Where it looks while coiling: its search's sweep over his isles (a noise
## heard turns it there), or the way ahead deep in the haze.
func _search_point(delta: float) -> Vector3:
	if stage <= 1: return Vector3.INF
	var f := _feet()
	_noise_t -= delta
	var centre := f
	if _noise_t > 0.0 and _noise_at != Vector3.INF: centre = _noise_at
	elif hunting: centre = f
	else:
		# Not him exactly: his isle, wandered round.
		centre = f+Vector3(sin(clock*0.07)*22.0,0.0,cos(clock*0.053)*22.0)
	_sweep_c = _sweep_c.lerp(centre,1.0-exp(-0.6*delta)) if _sweep_c != Vector3.ZERO else centre
	var to := _sweep_c-_head
	var flat := Vector3(to.x,0.0,to.z)
	var sway := 0.0 if hunting else SWEEP*sin(TAU*clock/SWEEP_PERIOD)
	return _head+flat.rotated(Vector3.UP,sway)+Vector3.UP*to.y

## The look springs aimed at `p` (world), off its way; none: ahead.
func _look(p: Vector3) -> void:
	var b := body
	if p == Vector3.INF:
		b.look(0.0,0.0,0.0,0.0)
		return
	var fwd: Vector3 = b.forward()
	var to := (p-_head).normalized()
	var yaw := wrapf(atan2(to.x,to.z)-atan2(fwd.x,fwd.z),-PI,PI)
	if absf(yaw) > 2.3: yaw = 0.0
	var pitch := asin(clampf(to.y,-1.0,1.0))-asin(clampf(fwd.y,-1.0,1.0))
	var lift := 1.2 if act in ["fix","approach"] else 0.0
	b.look(yaw,pitch,0.0,lift)

# --- The strike ------------------------------------------------------------------

## Seen: up to a poise off his isle's edge, then the hold and the strike.
func _begin_strike(f: Vector3) -> void:
	var p := _pick_poise(f)
	if p == Vector3.INF:
		_rest = 1.5
		return
	_poise = p
	_rearing = false
	# Already up by it (between strikes): it glides into it, no dive.
	if _head.distance_to(p) < 24.0 and _head.y > f.y-6.0:
		_rearing = true
		_set_act("approach")
		_voice_play("dragon-growl-loop.wav",0.5,-8.0,1.0)
		return
	_set_act("approach")
	_voice_play("dragon-growl-loop.wav",0.5,-6.0,1.8)

## Let go: at where he stands now (his chest, a little led), no further
## than REACH, short of any stone between.
func _release(chest: Vector3) -> void:
	var m: Object = _motor()
	var lead: Vector3 = (m.velocity as Vector3)*0.1 if m != null else Vector3.ZERO
	var aim := chest+lead
	var to := aim-_head
	if to.length() > REACH: aim = _head+to.normalized()*REACH
	var space := get_world_3d().direct_space_state
	if space != null:
		var q := PhysicsRayQueryParameters3D.create(_head,aim+(aim-_head).normalized()*1.0,1)
		var hit := space.intersect_ray(q)
		# Real cover (stone well short of him) stops it; a lip at his feet doesn't.
		if not hit.is_empty() and (hit.position as Vector3).distance_to(aim) > 4.0: aim = (hit.position as Vector3)-(aim-_head).normalized()*1.2
	_target = aim
	if _debug: print("[linger] snap from %.1f m, aim %.1f m short of him" % [_head.distance_to(chest),aim.distance_to(chest)])
	_snap_from = _head
	_snapped = 0.0
	_bit = false
	body.look_snap()
	strikes += 1
	_set_act("snap")
	_voice_play("whoosh-%d.wav" % _rng.randi_range(1,4),0.55,2.0)

## Its jaws passed from `last` to now: within HIT of his chest, a bite.
func _check_hit(last: Vector3) -> void:
	var m: Object = _motor()
	if m == null or _bit or not _playing(): return
	var chest := _feet()+Vector3.UP*1.05
	var jaw := Geometry3D.get_closest_point_to_segment(chest,last,_head)
	var snout: Vector3 = body.to_global(body.snout())
	var near := minf(chest.distance_to(jaw),chest.distance_to(snout))
	if near > HIT*(_scale/SCALE)**0.5: return
	if bool(m.get("_seized")): return
	hits += 1
	_bit = true
	var away := Vector2(chest.x-_snap_from.x,chest.z-_snap_from.z)
	if away.length() < 0.1: away = Vector2(_dir.x,_dir.z)
	var v: Vector3 = m.knock_velocity(away,KNOCK.x,KNOCK.y)
	m.knock(v,self,KNOCK_DOWN)
	m.harm("serpent",1,self)
	_set_act("bite")
	_bitten()

func _bitten() -> void:
	_voice_play("dragon-slam-%d.wav" % _rng.randi_range(1,2),0.8,-2.0)
	NoiseBus.make(self,_head,40.0,&"serpent_bite")

## A void column to poise in, POISE_OUT m out from him toward its column
## (in from there till clear), POISE_UP over him.
func _pick_poise(f: Vector3) -> Vector3:
	var out := Vector3(_anchor.x-f.x,0.0,_anchor.z-f.z)
	if out.length() < 1.0: out = Vector3(_head.x-f.x,0.0,_head.z-f.z)
	out = out.normalized()
	for i in range(14):
		var d := POISE_OUT+float(i)*4.0
		for side in [0.0,0.35,-0.35]:
			var o := out.rotated(Vector3.UP,float(side))
			var p := f+o*d
			if _clear(p,6.0):
				_poise_out = o
				return Vector3(p.x,f.y+POISE_UP,p.z)
	return Vector3.INF

# --- Seeing and hearing ------------------------------------------------------------

## What it sees of him, every tenth of a second: awareness filled, and at
## 1 it hunts. Only once its head is up out of the haze (stage 2 on).
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
	if not hunting and awareness >= 1.0:
		hunting = true
		sightings += 1
		_rest = 0.0
		if _debug: print("[linger] sees him at %.1f s" % clock)
	elif hunting and awareness < GIVE_UP and act == "coil":
		hunting = false
		if _debug: print("[linger] lost him at %.1f s" % clock)

## How plainly it sees him now (0..1): his points in its cone and reach
## with no stone between, by distance, his posture.
func _sight() -> float:
	var b := body
	var eye: Vector3 = b.to_global(b.snout())
	var look: Vector3 = (b.global_transform.basis*(b.look_dir() as Vector3)).normalized()
	var pts := _points()
	var space := get_world_3d().direct_space_state
	var got := 0
	var dist := eye.distance_to(pts[1])
	if dist > SIGHT: return 0.0
	for p in pts:
		var to := p-eye
		if look.angle_to(to) > CONE and not act in ["fix","wind","hold"]: continue
		if space != null:
			var q := PhysicsRayQueryParameters3D.create(eye,p,1)
			if not space.intersect_ray(q).is_empty(): continue
		got += 1
	if got == 0: return 0.0
	var k := float(got)/pts.size()
	k *= lerpf(1.0,FAR_SEEN,clampf((dist-NEAR)/(SIGHT-NEAR),0.0,1.0))
	var m: Object = _motor()
	if m != null:
		var v: Vector3 = m.velocity
		var flat := Vector2(v.x,v.z).length()
		if not bool(m.grounded): k *= SEEN_AIR
		elif bool(m.crouch) or String(m.move) == "crouch" or String(m.move) == "slide": k *= SEEN_CROUCH
		elif flat < 0.4: k *= SEEN_STILL
		elif flat < 2.4: k *= SEEN_CREEP
	return clampf(k,0.0,1.0)

## Noises on the bus: a loud one in hearing turns its search there (and,
## once up, makes it a little more aware).
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

## A column of open air round (x, z) of `p`, `r` m round: no isle of the
## plan there, and nothing solid straight down through it.
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
			if not space.intersect_ray(ray).is_empty(): return false
	return true

## A column on a ring round him (far or near), behind him from the gate
## (so it is there when he looks back), keeping near where it was.
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

## Its whole body laid coiled down round its column under its head, the
## head at its height on the clock.
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
	var moving := clampf(_speed/PACE,0.25,1.4)
	var db := lerpf(SCRAPE_DB.x,SCRAPE_DB.y,rise)+linear_to_db(moving)
	_scrape.global_position = near
	_grind.global_position = near
	_scrape.volume_db = move_toward(_scrape.volume_db,db,delta*20.0)
	_grind.volume_db = move_toward(_grind.volume_db,db-4.0,delta*20.0)
	_breath_t -= delta
	if _breath_t <= 0.0 and act == "coil" and stage >= 2:
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
