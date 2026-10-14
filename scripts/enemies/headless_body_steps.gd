extends RefCounted
## The headless body's feet and turns (round 4, docs/design/roguelike/
## headless-body-round4-anim-polish.md), for headless_body_look.gd.
##
## The body's `facing` (scripts/enemies/headless_body.gd) still turns as it
## always did; this is how the stone shows it. Standing, the figure (its
## `yaw`) holds still while its facing turns away, and once it is TRIGGER
## behind it takes a step round: one of the authored turn steps (the
## build's turn_open_* / turn_close_*, seeked by the step's time, trunk and
## legs only), the figure turned through the step's angle on a curve with
## anticipation, an overshoot and a settle, the swing foot carried from
## where it stood to under the turned hips, the other foot held where it
## stands (pivoting on its ball). A big turn alternates feet: out on the
## turn's side, then the other round; a small one is a single step, the
## other foot pivoting. A foot left too far from under the hips (a turn
## that stopped, a slide) gets a settling step.
##
## Walking, the figure follows its facing a beat ahead (the hips lead), the
## shoulders lag and the trunk leans into the turn; each foot is held where
## it came down while the walk has it planted and carried on to where the
## walk puts it as it swings, so it doesn't skate round as he turns.
##
## Left to the clips (climbing, leaping, landing ...), the figure catches
## its facing up quickly and the feet are the clips'.

enum {OFF, STAND, WALK}

## A step (s; the build's STEP), the swing foot up between these shares of
## it, then a held beat (s).
const STEP := 0.66
const LIFT := Vector2(0.18,0.6)
const HOLD := 0.1
## Behind its facing by this (rad) before a step; the most one step turns.
const TRIGGER := 0.14
const MOST := 0.8
## Olmec round 1 (olmec-turn-clip-round1.md): a stood turn is planned whole,
## toward where it is going (`want`), not chased step by step behind a
## facing that runs ahead. Under SMALL (rad) it is a correction: the hips
## ease round (SMALL_RATE rad/s), the feet pivot on their balls, no step.
## Over it, steps: as few as cover it, none more than BIG (rad), all the
## same size. The first step of a turn has a lead-in of ANTIC s (the weight
## onto the standing foot, the shoulders wound against the turn by
## WIND of it), the last a held settle of SETTLE s; the steps between run
## on with only CHAIN s between them.
const SMALL := 0.35
const SMALL_RATE := 0.5
const BIG := 1.15
const ANTIC := 0.22
const WIND := 0.1
const SETTLE := 0.3
const CHAIN := 0.03
## The shoulders' wind-up against the turn and their follow-through past
## it (rad of chest twist at most).
const WIND_TWIST := 0.16
const FOLLOW_TWIST := 0.08
## A standing foot this far (model m) off under its hip gets a step.
const SLIP := 0.45
## A planted foot turns on its ball this far (rad) at most.
const PIVOT := 0.35
## The turn step's say over the clip under it (its weight against 1).
const STEP_WEIGHT := 5.0
## The walks' planted share of a cycle (the build's gaits).
const WALK_STANCE := 0.56
const STRIDE_STANCE := 0.5
## Walking: the hips' lead (s of the turn's rate), the shoulders' lag and the
## lean (rad per rad/s), most of each (rad).
const LEAD := 0.12
const LAG := 0.16
const LEAN := 0.1
const MOST_TWIST := 0.22

## The figure's own yaw (world) and its turn steps taken (for checks).
var yaw := 0.0
var steps := 0
## The step now: its time (s; -1 none), clip, foot, start and angle.
var step_t := -1.0
var step_clip := ""
var step_foot := ""
var _from := 0.0
var _by := 0.0
## This step's lead-in (s; ANTIC on a turn's first step, else 0) and its
## held beat after (s), and whether a turn's steps are still to come.
var _lead := 0.0
var _hold := HOLD
var _want := NAN
## The turn going on (rad still to turn when the step began; 0 none).
var turning := 0.0
## How fast its steps go (1 calm; hunting, quicker: the body sets it).
var pace := 1.0
var _last_foot := ""
var _since := 9.0
var _look: Node3D
var _ready := false
var _facing := 0.0
var _rate := 0.0
var _mode := OFF
var _gait_u := 0.0
var _stance := WALK_STANCE
var _walk_k := 0.0
var feet := {"L":{},"R":{}}
## Set for a frame: the figure squares up to its facing at once (a quick
## pivot, its feet stepping after), not step by step: stood slantwise by a
## wall its turned shoulders would be in (headless_body.gd `_feel`).
var hurry := false

func _init(look: Node3D) -> void:
	_look = look
	for side: String in feet:
		feet[side] = {"lock":0.0,"plant":Vector3.INF,"yaw":0.0,"swing":false,"err":Vector3.ZERO,"yerr":0.0,
			"at":Vector3.ZERO,"at_yaw":0.0,"slip":0.0}

## Before the clips are blended: the figure's yaw this frame, a step begun or
## gone on with (its clip wanted), the figure turned off the body's facing.
## `mode` OFF, STAND or WALK; walking, `gait_u` is where in its two-step
## cycle it is and `striding` which gait.
func turn(facing: float, mode: int, delta: float, gait_u := 0.0, striding := false, want := NAN) -> void:
	_want = want if not is_nan(want) else facing
	if not _ready:
		_ready = true
		yaw = facing
		_facing = facing
	if delta > 0.0:
		var r := angle_difference(_facing,facing)/delta
		_rate = lerpf(_rate,r,1.0-exp(-6.0*delta))
	_facing = facing
	_mode = mode
	_gait_u = gait_u
	_stance = STRIDE_STANCE if striding else WALK_STANCE
	_since += delta
	_walk_k = move_toward(_walk_k,1.0 if mode == WALK else 0.0,delta/0.3)
	if step_t >= 0.0:
		if mode != STAND:
			step_t = -1.0
			turning = 0.0
		else:
			step_t += delta*pace
			var u := _u()
			yaw = _from+_by*(_curve(u) if step_t >= _lead else -WIND*smoothstep(0.0,1.0,step_t/_lead))
			if step_t >= _span():
				step_t = -1.0
				_since = 0.0
				if _hold >= SETTLE*0.9: turning = 0.0
			else:
				_look.want(step_clip,_clip_t(),STEP_WEIGHT)
	if hurry and mode == STAND:
		step_t = -1.0
		yaw = lerp_angle(yaw,facing,1.0-exp(-12.0*delta))
	elif step_t < 0.0:
		match mode:
			OFF: yaw = lerp_angle(yaw,facing,1.0-exp(-14.0*delta))
			WALK: yaw = lerp_angle(yaw,facing+clampf(_rate*LEAD,-0.3,0.3),1.0-exp(-8.0*delta))
			STAND: _maybe_step(_want,delta)
	hurry = false
	yaw = wrapf(yaw,-PI,PI)
	_look.model.rotation.y = angle_difference(facing,yaw)

## The figure's turn over a step (share of its angle at `u` of it): held a
## hair back, round past it, settled.
func _curve(u: float) -> float:
	# Wound back (a hair, or the lead-in's WIND held), round past it as the
	# foot plants, settled back.
	var back := WIND if _lead > 0.0 else 0.04
	if u < 0.15: return -back*(1.0 if _lead > 0.0 else smoothstep(0.0,0.15,u))
	if u < 0.6: return lerpf(-back,1.06,smoothstep(0.15,0.6,u))
	if u < 0.8: return lerpf(1.06,1.0,smoothstep(0.6,0.8,u))
	return 1.0

## Where in the step's clip time is now (s): through the lead-in, the clip's
## own anticipation (its first 0.15) slowed out to ANTIC; then on at its pace.
func _clip_t() -> float:
	return minf(_u()*STEP,STEP-0.001)

## The step's share done (0 to 1): a lead-in stretches its first 0.15.
func _u() -> float:
	if _lead <= 0.0: return clampf(step_t/STEP,0.0,1.0)
	if step_t < _lead: return 0.15*smoothstep(0.0,1.0,step_t/_lead)
	return clampf(0.15+(step_t-_lead)/STEP,0.0,1.0)

## The step's whole time, held beat and all (s).
func _span() -> float:
	return (_lead+0.85*STEP if _lead > 0.0 else STEP)+_hold

## A stood turn going on (a step being taken, or more to come): the body
## doesn't walk off till it is done.
func busy() -> bool:
	return turning != 0.0

func _maybe_step(want: float, delta: float) -> void:
	var lag := angle_difference(yaw,want)
	var worst := "L" if float(feet.L.slip) >= float(feet.R.slip) else "R"
	var slip: float = feet[worst].slip
	if absf(lag) < SMALL and slip < SLIP:
		# A correction: the hips ease round, the feet pivot under them.
		yaw += clampf(lag,-SMALL_RATE*delta,SMALL_RATE*delta)
		if absf(lag) < 0.01: turning = 0.0
		return
	var by := lag
	var foot := worst
	var first := turning == 0.0
	_lead = 0.0
	_hold = HOLD
	if absf(lag) >= SMALL:
		# As few steps as cover the turn, all alike: this one's share.
		var n := ceili(absf(lag)/BIG)
		by = lag/n
		_hold = SETTLE if n == 1 else CHAIN
		if first: _lead = ANTIC
		turning = lag
		var inside := "L" if by > 0.0 else "R"
		var outside := "R" if inside == "L" else "L"
		# Out on the turn's side first, then the other round.
		foot = outside if _last_foot == inside and _since < 0.5 else inside
	else:
		_hold = SETTLE*0.5
	var left := by > 0.0 if absf(by) > 0.03 else foot == "L"
	var opening := (foot == "L") == left
	step_clip = ("turn_open_" if opening else "turn_close_")+("l" if left else "r")
	step_foot = foot
	_last_foot = foot
	_from = yaw
	_by = by
	step_t = 0.0
	steps += 1
	_look.want(step_clip,0.0,STEP_WEIGHT)

## The planted feet moved with the body by `by` (global), a shuffle.
func carry(by: Vector3) -> void:
	for side: String in feet:
		var f: Dictionary = feet[side]
		if f.plant != Vector3.INF: f.plant += Vector3(by.x,0.0,by.z)
		f.at += Vector3(by.x,0.0,by.z)

## The planted feet kept `off` m (ankle to face) from the face through
## `at` facing `n` (global, flat): a toe planted into it slides back out.
func keep_off(at: Vector3, n: Vector3, off: float) -> void:
	for side: String in feet:
		var f: Dictionary = feet[side]
		if f.plant == Vector3.INF: continue
		var d: float = (f.plant-at).dot(n)
		if d < off:
			f.plant += n*(off-d)
			f.at += n*(off-d)

## Where in its step foot `side` is: -1 planted, else 0 to 1 through its swing.
func _swing(side: String) -> float:
	if _mode == WALK:
		var w := fposmod(_gait_u-(0.0 if side == "L" else 0.5),1.0)
		if w < _stance: return -1.0
		return (w-_stance)/(1.0-_stance)
	if step_t >= 0.0 and side == step_foot:
		var u := _u()
		if u > LIFT.x and u < LIFT.y: return (u-LIFT.x)/(LIFT.y-LIFT.x)
	return -1.0

## After the clips are posed: the trunk's walking twist and lean, then each
## foot held where it stands or carried to where the clip has it (the clip's
## height kept), by two-bone IK on the leg.
func plant(delta: float) -> void:
	if step_t >= 0.0 and _mode == STAND and absf(_by) > 0.05:
		# The shoulders wound against the turn through the lead-in, then
		# swung past as the foot plants, settling.
		var u := _u()
		var sgn := signf(_by)
		var wind := smoothstep(0.0,1.0,step_t/_lead) if _lead > 0.0 and step_t < _lead else (1.0-smoothstep(0.15,0.4,u) if _lead > 0.0 else 0.0)
		var follow := smoothstep(0.5,0.68,u)*(1.0-smoothstep(0.75,1.0,u))
		var size := clampf(absf(_by)/BIG,0.4,1.0)
		_look.twist("chest",sgn*size*(-WIND_TWIST*wind+FOLLOW_TWIST*follow))
	if _walk_k > 0.0:
		var r := _rate*_walk_k
		_look.twist("chest",clampf(-r*LAG,-MOST_TWIST,MOST_TWIST))
		_look.lean("spine",clampf(r*LEAN,-MOST_TWIST,MOST_TWIST))
	var k: float = _look.k
	for side: String in feet:
		var f: Dictionary = feet[side]
		var a: Vector3 = _look.ankle(side)
		f.lock = move_toward(f.lock,0.0 if _mode == OFF else 1.0,delta/0.2)
		if f.lock <= 0.0 or f.plant == Vector3.INF or Vector2(a.x-f.plant.x,a.z-f.plant.z).length() > 4.0*k:
			f.plant = a
			f.yaw = yaw
			f.swing = false
			f.slip = 0.0
			if f.lock <= 0.0: continue
		var u := _swing(side)
		var at: Vector3
		var at_yaw: float
		if u < 0.0:
			if f.swing:
				f.swing = false
				f.plant = f.at
				f.yaw = f.at_yaw
			at = Vector3(f.plant.x,a.y,f.plant.z)
			# Planted, it turns on its ball no further than PIVOT off the hips.
			var off := angle_difference(yaw,float(f.yaw))
			if absf(off) > PIVOT: f.yaw = wrapf(yaw+signf(off)*PIVOT,-PI,PI)
			at_yaw = f.yaw
		else:
			if not f.swing:
				f.swing = true
				f.err = Vector3(f.plant.x-a.x,0.0,f.plant.z-a.z)
				f.yerr = angle_difference(yaw,float(f.yaw))
			var e := 1.0-smoothstep(0.0,0.85,u)
			at = a+f.err*e
			at_yaw = yaw+float(f.yerr)*e
		f.at = at
		f.at_yaw = at_yaw
		f.slip = Vector2(at.x-a.x,at.z-a.z).length()/k
		_look.leg(side,a.lerp(at,f.lock),angle_difference(yaw,at_yaw)*f.lock)
