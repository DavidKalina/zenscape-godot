extends RefCounted
## The whole Olmec's eye contact (olmec-look lane): while he knows where you
## are (hunting, or seeing you), his head turns on the stump to hold your
## eyes, whatever way his body faces. A procedural layer over the clips:
## the body's `head_tilt()` (scripts/enemies/headless_body.gd) passes the
## stump's tilt through `over`, which turns the head's skin by the gaze. Only
## the skin turns: the head's `facing` (its draw's cone, `face_flat`) and
## the body's choices are untouched.
##
## How it moves, to read as wrong:
##   - It aims in saccades: the aim holds still, locked on you in the world
##     while the body sways and turns under it, and jumps on (fast, a small
##     overshoot) once you are SACCADE off it.
##   - So it leads the body: the head is round to you long before the body
##     comes about, and holds there while the body follows.
##   - Spotting you: a beat of stillness (SPOT_HOLD), then a snap to you
##     with an overshoot.
##   - Held far round (past TILT_FROM off the body for TILT_AFTER s), the
##     head cocks slowly over to one side, up to TILT.
##   - Clamped to MAX_YAW either way (past a living neck, short of
##     spinning round) and to PITCH_UP / PITCH_DOWN.
##     step(body, delta)   each frame, before the head reads its seat
##     over(body, tilt)    the stump's tilt (Euler) with the gaze on top

const MAX_YAW := deg_to_rad(125.0)
const PITCH_UP := deg_to_rad(40.0)
const PITCH_DOWN := deg_to_rad(32.0)
## The aim's jump: off by this much, the aim moves on to you.
const SACCADE := deg_to_rad(4.0)
## The head's spring on its aim (rad/s, damping): tracking, and the snap.
const TRACK := 13.0
const TRACK_DAMP := 0.62
const SNAP := 24.0
const SNAP_DAMP := 0.42
const SNAP_FOR := 0.6
## Spotted: the head holds still this long, then snaps.
const SPOT_HOLD := 0.12
## The slow cock of the head.
const TILT := deg_to_rad(15.0)
const TILT_FROM := deg_to_rad(50.0)
const TILT_AFTER := 0.7
const TILT_RATE := deg_to_rad(9.0)
## The share of the aim that goes to the camera (your eyes through the
## screen) rather than the wanderer's head.
const CAMERA_SHARE := 0.45
## States the gaze lets go in (the head does its own work or is held).
const OFF := ["suck","gulp","swat","smash","scope","triumph","reach","feel"]

## Now, off the stump (rad): yaw (+ left), pitch (+ up), roll.
var yaw := 0.0
var pitch := 0.0
var roll := 0.0
## How much the gaze holds (0 to 1).
var weight := 0.0
## The aim (world way, unit) the head is held on, and whether it has one.
var aim := Vector3.ZERO
var _yaw_v := 0.0
var _pitch_v := 0.0
## The look in the world: its yaw (as `facing`) and pitch (rad).
var _wy := 0.0
var _wp := 0.0
var _snap_t := 0.0
var _hold_t := 0.0
var _far_t := 0.0
var _roll_side := 1.0
var _knew := false
## Counted for drivers: spots snapped, saccades made.
var snaps := 0
var saccades := 0

## A frame: where to look, the spring toward it.
func step(body: Node3D, delta: float) -> void:
	if delta <= 0.0: return
	var target := _target(body)
	var on := target != Vector3.INF
	var knows := on and bool(body.get("hunting"))
	if knows and not _knew:
		# Spotted: still a beat, then the snap.
		_hold_t = SPOT_HOLD
		_snap_t = SPOT_HOLD+SNAP_FOR
		snaps += 1
	_knew = knows
	var frame := _stump(body)
	var ahead := frame*Vector3.FORWARD
	var fresh := weight <= 0.001
	weight = move_toward(weight,1.0 if on else 0.0,(6.0 if on else 4.0)*delta)
	if fresh:
		# Fresh: the look starts where the stump faces.
		_wy = atan2(-ahead.x,-ahead.z)
		_wp = asin(clampf(ahead.y,-1.0,1.0))
		_yaw_v = 0.0
		_pitch_v = 0.0
	var goal := ahead
	if on:
		var way := (target-_eye(body)).normalized()
		if _hold_t <= 0.0 and (aim == Vector3.ZERO or aim.angle_to(way) > SACCADE):
			if aim != Vector3.ZERO: saccades += 1
			aim = way
		if aim != Vector3.ZERO: goal = aim
	else:
		aim = Vector3.ZERO
	_hold_t = maxf(0.0,_hold_t-delta)
	_snap_t = maxf(0.0,_snap_t-delta)
	if _hold_t > 0.0:
		# The beat of stillness: the look held where it was.
		_yaw_v = 0.0
		_pitch_v = 0.0
	else:
		# The look sprung in the world (so the body turning under it doesn't
		# drag it off you), then read off the stump.
		var w := SNAP if _snap_t > 0.0 else TRACK
		var z := SNAP_DAMP if _snap_t > 0.0 else TRACK_DAMP
		var dy := wrapf(atan2(-goal.x,-goal.z)-_wy,-PI,PI)
		var dp := asin(clampf(goal.y,-1.0,1.0))-_wp
		_yaw_v += (w*w*dy-2.0*z*w*_yaw_v)*delta
		_pitch_v += (w*w*dp-2.0*z*w*_pitch_v)*delta
		_wy = wrapf(_wy+_yaw_v*delta,-PI,PI)
		_wp = clampf(_wp+_pitch_v*delta,-1.4,1.4)
	var look := Vector3(-sin(_wy)*cos(_wp),sin(_wp),-cos(_wy)*cos(_wp))
	var local := frame.inverse()*look
	var raw := atan2(-local.x,-local.z)
	# Olmec tune (`gaze_yaw` D degrees on the body): the turn eased into D
	# (a soft knee from KNEE of it, never a hard stop); `past` is how far
	# the look is past FOLLOW_AT of it, for the body to turn after.
	var limit := MAX_YAW
	var knobs: Variant = body.get("knobs")
	var soft := float((knobs as Dictionary).get("gaze_yaw",0.0)) if knobs is Dictionary else 0.0
	if soft > 0.0 and on:
		limit = deg_to_rad(soft)
		yaw = signf(raw)*_eased(absf(raw),limit)
		past = signf(raw)*maxf(absf(raw)-limit*FOLLOW_AT,0.0)
	else:
		yaw = clampf(raw,-MAX_YAW,MAX_YAW)
		past = 0.0
	pitch = clampf(atan2(local.y,Vector2(local.x,local.z).length()),-PITCH_DOWN,PITCH_UP)
	# Held far round: the slow cock to one side (away from the turn).
	var tilt_from := minf(TILT_FROM,limit*0.75)
	if on and absf(yaw) > tilt_from: _far_t += delta
	else: _far_t = 0.0
	if _far_t < 0.05: _roll_side = -signf(yaw) if yaw != 0.0 else 1.0
	var roll_goal := TILT*_roll_side*smoothstep(tilt_from,limit,absf(yaw))*2.0 if _far_t > TILT_AFTER else 0.0
	roll = move_toward(roll,clampf(roll_goal,-TILT,TILT),TILT_RATE*delta*(1.0 if absf(roll_goal) > absf(roll) else 2.5))

## `gaze_yaw`: the eased turn's knee (a share of the limit): under it the
## head turns as far as the look; over it, ever less, toward the limit.
const KNEE := 0.6
## The share of the limit past which the body turns after the look.
const FOLLOW_AT := 0.85
## How far (rad, signed as `yaw`) the look is past FOLLOW_AT of the limit
## (`gaze_yaw` on): the body's to turn after (`_gaze_follow`).
var past := 0.0

## `a` (rad, 0 up) eased into `limit`: itself to KNEE of it, then a tanh
## knee that meets the limit only far round.
static func _eased(a: float, limit: float) -> float:
	var k := limit*KNEE
	if a <= k: return a
	return k+(limit-k)*tanh((a-k)/(limit-k))

## The stump's tilt (Euler, off the body's facing) with the gaze on top.
func over(body: Node3D, tilt: Vector3) -> Vector3:
	if weight <= 0.001: return tilt
	var turn := Basis(Vector3.UP,yaw*weight)*Basis(Vector3.RIGHT,pitch*weight)*Basis(Vector3.BACK,roll*weight)
	return (Basis.from_euler(tilt)*turn).get_euler()

## Where he looks: your eyes (between the wanderer's head and the camera),
## or INF while he doesn't know where you are or his head is busy.
func _target(body: Node3D) -> Vector3:
	if not bool(body.get("whole")) or body.get("state") in OFF: return Vector3.INF
	var head: Node3D = body.get("head")
	if head == null or not is_instance_valid(head) or head.get("perch") != body: return Vector3.INF
	var field: Node = body.get("field")
	if field == null: return Vector3.INF
	var m: Object = field.get("motor")
	if m == null or bool(m.call("seized")): return Vector3.INF
	var sight: RefCounted = body.get("sight")
	var seeing: bool = sight != null and sight.has_method("seeing") and bool(sight.call("seeing"))
	if not bool(body.get("hunting")) and not seeing: return Vector3.INF
	var study: Node = field.get("study")
	var top := 1.6
	var ground: Object = study.get("ground") if study != null else null
	if ground != null: top = float(ground.get("head_top"))
	var eyes: Vector3 = (m.get("feet") as Vector3)+Vector3.UP*top*0.9
	var camera: Camera3D = study.get("camera") if study != null else null
	if camera != null and is_instance_valid(camera):
		eyes = eyes.lerp(camera.global_position,CAMERA_SHARE)
	return eyes

## Where the head looks from: its seat, a head up.
func _eye(body: Node3D) -> Vector3:
	var head: Node3D = body.get("head")
	return head.global_position+Vector3.UP*float(head.get("height"))*0.55

## The stump's frame (world basis the head sits in, before the gaze).
func _stump(body: Node3D) -> Basis:
	var look: Node3D = body.get("look")
	if look == null: return Basis(Vector3.UP,float(body.get("facing")))
	return (look.call("seat") as Transform3D).basis.orthonormalized()
