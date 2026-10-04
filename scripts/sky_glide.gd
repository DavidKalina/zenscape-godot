extends RefCounted
## The glide: how the wanderer flies once it steps off the plate's edge
## (scripts/wanderer_eye.gd). A prototype tuned for feel over realism, under
## four rules: no stamina, no crashing, always a way up, and turns that come
## easily.
##
## The base glide is slow and floaty. Speed and height come from the air:
## jet streams carry it and thermals lift it (scripts/sky_currents.gd). In a
## jet, with no steering, it turns to face downstream.
##
## Speed runs along the path. Pointing down trades height for speed and
## pointing up trades it back, so a dive pulled out swings into a big rising
## arc. Near the top of the arc, where the speed has run out, the fall eases
## off for a moment (`hang`) before the nose tips over. That float is the
## stomach-drop moment. Speed always settles back to CRUISE and never drops
## below MIN, so the glide never stalls. Rise (held) climbs gently for as long
## as it is held. Dive (held) tucks the nose down and lets the speed run.
## Touching ground is a skim along it, never a crash (`skim`).
##
## Units are the diorama's toy metres: trees stand 3 to 5 m, the plate is 28 m.

## Speeds along the path, in metres a second: the speed it settles to, the
## floor it never drops below, and the cap a long dive reaches.
const CRUISE := 6.0
const MIN := 3.5
const MAX := 40.0
## How the speed answers the pitch (m/s² at straight down), and how fast it
## settles back to CRUISE (per second), on the glide and tucked.
const PULL := 10.0
const SETTLE := 0.32
const SETTLE_TUCK := 0.04
const PULL_TUCK := 1.35
## The steady sink of a level glide, in metres a second.
const SINK := 0.75
## Rise: the climb it eases into (m/s), how fast it eases in and out, and the
## wingbeat it pulses with (beats a second, share of the climb).
const RISE := 5.0
const EASE_RISE := 0.35
const BEAT := 1.4
const BEAT_SHARE := 0.45
## The pitch limits (radians, nose up positive), the pitch an untouched glide
## eases back to, and how fast.
const PITCH := Vector2(-1.45,1.0)
const GLIDE_PITCH := -0.07
const LEVEL := 0.55
## Tucked, the nose heads for TUCK_PITCH at TUCK_RATE.
const TUCK_PITCH := -1.2
const TUCK_RATE := 2.2
## Keys and stick: radians a second of turn and of pitch at full deflection.
const TURN := 1.7
const PITCH_RATE := 1.3
## The bank leans into the turn: radians per radian a second of turn, the
## most it leans, and how fast it follows.
const BANK := 0.34
const BANK_MAX := 0.8
const EASE_BANK := 0.16
const EASE_TURN := 0.1
## The hang: within HANG_SPEED m/s of MIN with the nose up, the sink and the
## pull ease by up to HANG, then the nose drops at TIP radians a second.
const HANG_SPEED := 3.0
const HANG := 0.75
const TIP := 0.7
## The first moments off the edge: a real drop at FALL m/s² for FALL_TIME
## seconds, then the glide catches it over CATCH seconds.
const FALL := 9.0
const FALL_TIME := 0.7
const CATCH := 0.9
## The skim: the eye rides SKIM m over whatever is under it, and the ground
## drags the speed by SKIM_DRAG m/s².
const SKIM := 0.9
const SKIM_DRAG := 1.4
## The band: below FLOOR the air lifts harder the deeper it goes (CUSHION m/s
## per metre, up to CUSHION_MAX), so a fall is always caught; above CEILING
## the rise fades out over CEILING_FADE metres.
const FLOOR := -55.0
const CUSHION := 0.35
const CUSHION_MAX := 14.0
const CATCH_DEPTH := 15.0
const CUSHION_PITCH := 0.2
const CEILING := 95.0
const CEILING_FADE := 25.0

## In a jet with no steering, the heading eases downstream over VANE
## seconds, if downstream is within VANE_REACH radians of it.
const VANE := 0.9
const VANE_REACH := 1.6
## How much of the glide's own way the jet takes over at its core.
const CARRIED := 0.65

## The eye's global position and heading (the scene's yaw: the camera looks
## down -Z turned by it), pitch (nose up positive) and bank.
var position := Vector3.ZERO
var heading := 0.0
var pitch := 0.0
var bank := 0.0
var speed := CRUISE
## The vertical climb Rise is giving now, and the extra lift of the air
## (updrafts, the cushion).
var climb := 0.0
var lift := 0.0
## The velocity of the last step.
var velocity := Vector3.ZERO
## How deep into the float at the top of an arc it is (0 to 1).
var hang := 0.0
## Seconds since leaving the edge.
var airborne := 0.0
## True while the eye rides along the ground.
var skimming := false
## The air it is in this step: the wind (m/s) and how far into a jet and a
## thermal it is (0 to 1).
var wind := Vector3.ZERO
var in_jet := 0.0
var in_thermal := 0.0
var _turn_rate := 0.0
var _beat := 0.0

## Steps off from `from` facing `towards` (the scene's yaw), at `pace` m/s.
func launch(from: Vector3, towards: float, pace: float) -> void:
	position = from
	heading = towards
	pitch = -0.2
	bank = 0.0
	speed = clampf(maxf(pace,MIN+1.0),MIN,MAX)
	climb = 0.0
	lift = 0.0
	hang = 0.0
	airborne = 0.0
	skimming = false
	_turn_rate = 0.0
	velocity = forward()*speed

## The way the eye looks.
func forward() -> Vector3:
	return Vector3(-sin(heading)*cos(pitch),sin(pitch),-cos(heading)*cos(pitch))

## One step. `input` holds:
##   turn, pitch: -1..1 held rates (keys, stick), right and nose-up positive;
##   look: Vector2 of radians to turn and pitch directly (the mouse);
##   rise, dive: bools (or 0..1 for triggers).
## `ground` is a Callable(Vector3) -> Variant: the height of whatever stands
## under a global point, or null over open air. `air`, if given, is a
## Callable(Vector3) -> Dictionary (SkyCurrents `air_at`).
func step(delta: float, input: Dictionary, ground: Callable, air := Callable()) -> void:
	airborne += delta
	var here: Dictionary = air.call(position) if air.is_valid() else {}
	wind = here.get("wind",Vector3.ZERO)
	in_jet = float(here.get("jet",0.0))
	in_thermal = float(here.get("thermal",0.0))
	var look: Vector2 = input.get("look",Vector2.ZERO)
	# Under the floor the cloud cushion takes over: the dive lets go and the
	# nose comes up, over CATCH_DEPTH metres.
	var deep := clampf((FLOOR-position.y)/CATCH_DEPTH,0.0,1.0)
	var dive := clampf(float(input.get("dive",0.0)),0.0,1.0)*(1.0-deep)
	var rise := clampf(float(input.get("rise",0.0)),0.0,1.0)
	var steer := clampf(float(input.get("pitch",0.0)),-1.0,1.0)
	# Turning: held rates and direct mouse turn both feed the bank.
	var turned := -float(input.get("turn",0.0))*TURN*delta-look.x
	heading += turned
	# Downstream in a jet, unless steering.
	var along: Vector3 = here.get("along",Vector3.ZERO)
	var flat := Vector2(along.x,along.z)
	if is_zero_approx(turned) and flat.length() > 0.05:
		var downstream := atan2(-flat.x,-flat.y)
		if absf(angle_difference(heading,downstream)) < VANE_REACH:
			heading = lerp_angle(heading,downstream,_ease(VANE,delta)*clampf(flat.length(),0.0,1.0))
	_turn_rate = lerpf(_turn_rate,turned/maxf(delta,0.0001),_ease(EASE_TURN,delta))
	bank = lerpf(bank,clampf(-_turn_rate*BANK,-BANK_MAX,BANK_MAX),_ease(EASE_BANK,delta))
	# Pitch: the mouse and stick steer it; tucked it heads down; let go it
	# eases back to a gentle glide.
	pitch += look.y+steer*PITCH_RATE*delta
	if dive > 0.0:
		pitch = move_toward(pitch,lerpf(pitch,TUCK_PITCH,dive),TUCK_RATE*delta)
	elif is_zero_approx(steer) and is_zero_approx(look.y):
		pitch = lerpf(pitch,GLIDE_PITCH,_ease(1.0/LEVEL,delta)*0.5)
	# The float: nose up, speed spent.
	var spent := 1.0-clampf((speed-MIN)/HANG_SPEED,0.0,1.0)
	var want_hang := spent*smoothstep(0.05,0.35,pitch)*(1.0-dive)
	hang = lerpf(hang,want_hang,_ease(0.12,delta))
	# Then it tips over, unless Rise is held.
	if spent > 0.6 and pitch > 0.0 and rise < 0.5:
		pitch -= TIP*spent*delta
	if deep > 0.0: pitch = lerpf(pitch,CUSHION_PITCH,_ease(0.5,delta)*deep)
	pitch = clampf(pitch,PITCH.x,PITCH.y)
	# Speed along the path.
	var pull := PULL*lerpf(1.0,PULL_TUCK,dive)*(1.0-HANG*hang*float(pitch > 0.0))
	var settle := lerpf(SETTLE,SETTLE_TUCK,dive)
	speed += (-pull*sin(pitch)-settle*(speed-CRUISE))*delta
	speed = clampf(speed,MIN,MAX)
	# Rise eases in with a wingbeat; the ceiling fades it.
	var ceiling := 1.0-clampf((position.y-CEILING)/CEILING_FADE,0.0,1.0)
	climb = lerpf(climb,rise*RISE*ceiling,_ease(EASE_RISE,delta))
	_beat += delta*BEAT*TAU*float(climb > 0.05)
	var beat := climb*(1.0+BEAT_SHARE*sin(_beat))
	# The air: the cushion below the floor.
	lift = clampf((FLOOR-position.y)*CUSHION,0.0,CUSHION_MAX)
	# The drop off the edge.
	var fall := FALL*minf(airborne,FALL_TIME)*(1.0-smoothstep(FALL_TIME,FALL_TIME+CATCH,airborne))
	var sink := SINK*(1.0-HANG*hang)*(1.0-dive*0.5)
	# In a jet the air does the flying: the glide's own way and sink count
	# for less and the core holds it, so it rides the stream rather than
	# sinking out of it. Steering lets go of both.
	var steering := clampf(absf(float(input.get("turn",0.0)))+absf(steer)+rise+look.length()*30.0,0.0,1.0)
	var own := 1.0-CARRIED*in_jet*(1.0-steering)
	var hold: Vector3 = here.get("hold",Vector3.ZERO)*(1.0-steering)
	velocity = forward()*speed*own+Vector3.UP*(beat+lift-sink*own-fall)+wind+hold
	position += velocity*delta
	_skim(delta,ground)

## No crashing: under the eye's skim height it rides up along the ground,
## keeps its way along it, and the ground drags a little speed off.
func _skim(delta: float, ground: Callable) -> void:
	var under: Variant = ground.call(position)
	skimming = false
	if under == null: return
	var floor_y := float(under)+SKIM
	if position.y >= floor_y: return
	skimming = true
	position.y = floor_y
	if velocity.y < 0.0: velocity.y = 0.0
	if pitch < 0.0: pitch = lerpf(pitch,0.0,_ease(0.15,delta))
	speed = maxf(MIN,speed-SKIM_DRAG*delta)

func _ease(rate: float, delta: float) -> float:
	return 1.0-exp(-delta/rate)
