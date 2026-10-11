extends "res://scripts/sky_glide.gd"
## The little plane: how the wanderer flies (scripts/wanderer_eye.gd), a
## toy prop plane in the spirit of an island
## flyover rather than a flight sim. It keeps the glide's rules and its
## shape, so the chase camera, the vapour, the sky and the landing read it
## the same: no stamina, no crashing (it skims the ground, slides under an
## island and is turned aside by its sides, as the glide is), always a way
## up, and the cloud cushion under the floor.
##
## It always has its engine. It cruises at a steady CRUISE_SPEED, quicker
## than the glide, so an island goes by in a few seconds; Boost (held) opens
## the throttle and Brake (held) closes it, never below SLOW, so it never
## stalls. Left and right roll it into a bank and the bank turns it, so a
## turn leans in first and comes round after; let go, it rolls level by
## itself. Up and down pitch it, and let go the nose eases back level.
## Climbing costs a little speed and diving gains some, but the engine
## always pulls it back to the throttle's speed.
##
## Holding a lean (`lean`: -1 left, 1 right) tips it up on a wingtip,
## KNIFE_BANK over, to slip through a gap narrower than its wings; the knife
## edge does not turn it, so it flies on straight, and let go it rolls back
## to its bank.
##
## Turn while on the knife edge and it drifts: the turn comes round
## DRIFT_TURN more again than a banked one, the nose swings in ahead of its
## path (a slip of up to DRIFT_SLIP seconds of turn), and the drift bleeds
## DRIFT_BLEED m/s² off its speed as the price. A small stick (under
## DRIFT_ONSET) is only a correction and doesn't drift, so threading a slit
## stays steady; turning against the lean drifts DRIFT_COUNTER as hard.
## Coming out of a drift held DRIFT_MIN seconds or more gives back up to
## DRIFT_BOOST m/s (full after DRIFT_CHARGE seconds), which the engine
## eases away again. `--drift=<x>` scales all of it (`drift_strength`,
## 1 by default, 0 off). docs/design/knife-drift.md.
##
## A barrel roll (`roll`: -1 left, 1 right, on the frame it is asked for)
## turns it a whole way round its length over ROLL_TIME seconds, with a
## little hop sideways, and it comes out level on the heading it went in
## on. The roll is its own angle (`spin`), on top of the bank: the plane
## is drawn turned by both, while the camera leans only with the bank, so
## the view never spins with it. Each roll counts as a flap, for the whoosh.
##
## Coming in to land (`approach`) it throttles back to LANDING_SPEED and
## comes down as the glide does; a touch slow enough lands, and Boost, a
## lean or a roll calls it off. The wanderer's F lands it by its own sequence
## instead (scripts/plane_landing.gd), which flies it from outside and
## hands it back with `resume`; `engine` spins down when it is parked.
##
## Flaps (`flaps`, 0 up to 1 down; only the hand-flown landing,
## scripts/manual_landing.gd, lowers them) let it fly slower than SLOW for a
## short field: the throttle's speed comes down to FLAP_SPEED, the floor to
## FLAP_SLOW, and it sinks FLAP_SINK m/s more, so an approach with flaps is
## slower and steeper. Boost overrides them, for a go-around.

## Speeds along the path, in metres a second: the cruise the engine holds,
## Boost's and Brake's, the floor it never drops below, the cap a long dive
## reaches, and the speed it comes in to land at.
const CRUISE_SPEED := 14.0
const BOOST_SPEED := 22.0
const BRAKE_SPEED := 8.0
const SLOW := 7.0
const FAST := 30.0
const LANDING_SPEED := 8.0
## Flaps down: the speed the engine holds, the floor it never drops below
## (m/s), and the extra sink (m/s).
const FLAP_SPEED := 5.5
const FLAP_SLOW := 5.0
const FLAP_SINK := 0.5
## How the speed answers the pitch (m/s² at straight down), and how fast
## the engine brings it back to the throttle's speed (per second).
const SWING := 6.0
const THROTTLE := 0.8
## The bank: the most a held turn leans it (radians), the most it ever
## leans in a turn, and how fast it rolls in and out (seconds). The turn,
## radians a second at a full held bank, follows the bank.
const BANK_HELD := 1.0
const BANK_TOP := 1.2
const EASE_ROLL_IN := 0.16
const TURN_RATE := 1.6
## The mouse turns it directly, and banks it by MOUSE_BANK radians per
## radian a second of turn.
const MOUSE_BANK := 0.35
## The pitch: radians a second at full stick, its limits, and how fast it
## eases level when let go (seconds).
const PITCH_SPEED := 1.4
const PITCH_LIMIT := Vector2(-1.3,1.2)
const EASE_LEVEL := 1.4
## The knife edge: how far over a held lean tips it (radians) and how fast
## it tips in and out (seconds).
const KNIFE_BANK := PI*0.5
const EASE_KNIFE := 0.12
## The drift (a turn on the knife edge): the turn rate's extra share at a
## full drift, the stick it starts at and is full by, how hard a turn against
## the lean drifts, the speed it bleeds (m/s²), the nose's lead over its
## path (seconds of turn), how fast it comes and goes (seconds), and the
## release: the boost (m/s), the hold before any and the hold to the full.
const DRIFT_TURN := 0.5
const DRIFT_ONSET := 0.3
const DRIFT_FULL := 0.8
const DRIFT_COUNTER := 0.5
const DRIFT_BLEED := 1.6
const DRIFT_SLIP := 0.12
const EASE_DRIFT := 0.15
const DRIFT_BOOST := 2.5
const DRIFT_MIN := 0.4
const DRIFT_CHARGE := 1.2
## The barrel roll: seconds round, and the sideways hop (m/s at its middle).
const ROLL_TIME := 0.7
const JINK := 3.0
## Over CEILING the nose is held down to level by CEILING_FADE metres more.
const CEILING_NOSE := -0.05

## The barrel roll's own angle (radians, right positive like the bank),
## whether one is under way, and which way.
var spin := 0.0
var rolling := false
var roll_dir := 0.0
## How far it is tipped up on a wingtip, -1 left to 1 right.
var knife := 0.0
## The drift's strength (`--drift=<x>`, 0 off), how far into one it is now
## (0 to 1), the nose's lead over its path (radians, the travel is at
## heading+slip), and how long this one has been held (seconds).
var drift_strength := drift_flag(preload("res://scripts/launch_args.gd").user_args())
var drift := 0.0
var slip := 0.0
var drift_held := 0.0
## The throttle held now: 1 boosting, -1 braking, 0 cruising (for the
## figure's propeller and the hum).
var throttle := 0.0
## The engine running, 0 to 1: the propeller and the hum spin down to
## nothing when it is parked (scripts/plane_landing.gd).
var engine := 1.0
## The lean the keys and stick hold (radians), which turns it, and the
## mouse's and the approach's turn rate, which only lean it.
var _lean := 0.0
var _mouse_rate := 0.0
var _roll_time := 0.0
## The bank the turn alone would give it, under the knife edge.
var _free_bank := 0.0

func launch(from: Vector3, towards: float, pace: float, drop := true) -> void:
	super.launch(from,towards,pace,drop)
	speed = clampf(maxf(pace,CRUISE_SPEED*0.8),SLOW,FAST)
	pitch = 0.0
	spin = 0.0
	rolling = false
	roll_dir = 0.0
	throttle = 0.0
	engine = 1.0
	_roll_time = 0.0
	_lean = 0.0
	_mouse_rate = 0.0
	knife = 0.0
	drift = 0.0
	slip = 0.0
	drift_held = 0.0
	_free_bank = 0.0
	velocity = forward()*speed

## Flying on from a pose set from outside (a landing called off, a
## takeoff's lift; scripts/plane_landing.gd): at `pace` m/s, the nose at
## `nose`, level, the engine on, nothing turning it.
func resume(pace: float, nose: float) -> void:
	speed = clampf(pace,SLOW,FAST)
	pitch = clampf(nose,PITCH_LIMIT.x,PITCH_LIMIT.y)
	spin = 0.0
	rolling = false
	roll_dir = 0.0
	approach = false
	airborne = FALL_TIME+CATCH
	engine = 1.0
	_lean = 0.0
	_mouse_rate = 0.0
	knife = 0.0
	drift = 0.0
	slip = 0.0
	drift_held = 0.0
	_free_bank = 0.0
	_roll_time = 0.0
	velocity = forward()*speed

## The drift strength asked for on the command line (`--drift=<x>`), else 1.
static func drift_flag(args: PackedStringArray) -> float:
	for arg in args:
		if arg.begins_with("--drift="): return maxf(0.0,float(arg.substr(8)))
	return 1.0

## The direction it travels: the nose's, swung back by the drift's slip.
func travel() -> Vector3:
	var h := heading+slip
	return Vector3(-sin(h)*cos(pitch),sin(pitch),-cos(h)*cos(pitch))

## One step. `input` holds:
##   turn, pitch: -1..1 held rates (keys, stick), right and nose-up positive;
##   look: Vector2 of radians to turn and pitch directly (the mouse);
##   boost, brake: bools (or 0..1 for triggers);
##   lean: -1..1 held, a knife edge to that side;
##   roll: -1 or 1 on the frame a barrel roll is asked for, else 0;
##   flaps: 0 up to 1 down (absent: up).
## `ground` and `air` are as for the glide.
func step(delta: float, input: Dictionary, ground: Callable, air := Callable()) -> void:
	airborne += delta
	var here: Dictionary = air.call(position) if air.is_valid() else {}
	wind = here.get("wind",Vector3.ZERO)
	in_jet = float(here.get("jet",0.0))
	in_thermal = float(here.get("thermal",0.0))
	var look: Vector2 = input.get("look",Vector2.ZERO)
	var deep := clampf((floor_y-position.y)/CATCH_DEPTH,0.0,1.0)
	var boost := clampf(float(input.get("boost",0.0)),0.0,1.0)
	var brake := clampf(float(input.get("brake",0.0)),0.0,1.0)
	throttle = boost-brake
	var turn := clampf(float(input.get("turn",0.0)),-1.0,1.0)
	var steer := clampf(float(input.get("pitch",0.0)),-1.0,1.0)
	var asked := signf(float(input.get("roll",0.0)))
	if approach and (boost > 0.0 or asked != 0.0 or float(input.get("lean",0.0)) != 0.0): approach = false
	# The barrel roll: once round, eased in and out, then level again.
	if asked != 0.0 and not rolling:
		rolling = true
		roll_dir = asked
		_roll_time = 0.0
		flaps += 1
	var hop := 0.0
	if rolling:
		_roll_time += delta
		var t := clampf(_roll_time/ROLL_TIME,0.0,1.0)
		spin = roll_dir*TAU*smoothstep(0.0,1.0,t)
		hop = roll_dir*JINK*sin(PI*t)
		if t >= 1.0:
			rolling = false
			spin = 0.0
	# Roll to turn: the keys and stick lean it over and the lean turns it;
	# the mouse turns it directly and leans it a little; coming in to land
	# it turns itself to the target.
	var aim := _aim(delta) if approach and is_zero_approx(turn) and is_zero_approx(look.x) else 0.0
	_lean = lerpf(_lean,turn*BANK_HELD,_ease(EASE_ROLL_IN,delta))
	# On the knife edge a real turn of the stick drifts: tighter, nose in.
	var lean_in := clampf(float(input.get("lean",0.0)),-1.0,1.0)
	var want := 0.0
	if drift_strength > 0.0 and absf(knife) > 0.5 and absf(lean_in) > 0.5 and not rolling:
		want = smoothstep(DRIFT_ONSET,DRIFT_FULL,absf(turn))
		if signf(turn) != signf(knife): want *= DRIFT_COUNTER
	drift = lerpf(drift,want,_ease(EASE_DRIFT,delta))
	var rate := -_lean/BANK_HELD*TURN_RATE*(1.0+DRIFT_TURN*drift_strength*drift)
	heading += rate*delta-look.x+aim
	slip = lerpf(slip,-rate*DRIFT_SLIP*drift,_ease(EASE_DRIFT,delta))
	var boost_out := 0.0
	if want > 0.25: drift_held += delta
	elif drift_held > 0.0:
		if drift_held >= DRIFT_MIN: boost_out = DRIFT_BOOST*drift_strength*clampf(drift_held/DRIFT_CHARGE,0.0,1.0)
		drift_held = 0.0
	_mouse_rate = lerpf(_mouse_rate,(look.x-aim)/maxf(delta,0.0001),_ease(EASE_TURN,delta))
	_free_bank = lerpf(_free_bank,clampf(_lean+_mouse_rate*MOUSE_BANK,-BANK_TOP,BANK_TOP),_ease(EASE_TURN,delta))
	# The knife edge tips it up on a wingtip over the turn's bank.
	knife = lerpf(knife,clampf(float(input.get("lean",0.0)),-1.0,1.0),_ease(EASE_KNIFE,delta))
	bank = lerpf(_free_bank,signf(knife)*KNIFE_BANK,absf(knife))
	# Pitch: the stick and mouse steer it; let go, it eases level, or down
	# the approach's slope; under the floor the cushion lifts the nose.
	pitch += look.y+steer*PITCH_SPEED*delta
	if is_zero_approx(steer) and is_zero_approx(look.y):
		pitch = lerpf(pitch,approach_pitch(ground) if approach else 0.0,_ease(EASE_LEVEL,delta))
	if deep > 0.0: pitch = lerpf(pitch,CUSHION_PITCH,_ease(0.5,delta)*deep)
	var over := clampf((position.y-CEILING)/CEILING_FADE,0.0,1.0)
	pitch = clampf(pitch,PITCH_LIMIT.x,lerpf(PITCH_LIMIT.y,CEILING_NOSE,over))
	# Speed: the engine pulls it to the throttle's speed; the climb and the
	# dive swing it either side.
	var target := CRUISE_SPEED+boost*(BOOST_SPEED-CRUISE_SPEED)-brake*(CRUISE_SPEED-BRAKE_SPEED)
	if approach: target = minf(target,LANDING_SPEED)
	# Flaps down slow it and lower its floor; Boost takes them over.
	var flap := clampf(float(input.get("flaps",0.0)),0.0,1.0)*(1.0-boost)
	target = lerpf(target,minf(target,FLAP_SPEED),flap)
	var slow := lerpf(SLOW,FLAP_SLOW,flap)
	speed += (-SWING*sin(pitch)-THROTTLE*(speed-target)-DRIFT_BLEED*drift_strength*drift)*delta+boost_out
	speed = clampf(speed,slow,FAST)
	lift = clampf((floor_y-position.y)*CUSHION,0.0,CUSHION_MAX)
	var fall := FALL*minf(airborne,FALL_TIME)*(1.0-smoothstep(FALL_TIME,FALL_TIME+CATCH,airborne))
	var drop := approach_drop(ground) if approach else 0.0
	var side := Vector3(cos(heading),0.0,-sin(heading))
	velocity = travel()*speed+side*hop+Vector3.UP*(lift-fall-drop-FLAP_SINK*flap)+wind
	var was := position
	position += velocity*delta
	_skim(delta,ground,was)
	_water(delta)
	speed = maxf(speed,slow)
