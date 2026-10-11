extends RefCounted
## The glide's camera (scripts/sky_glide.gd): a chase view behind the glider
## that breathes with the flight. At a cruise it trails a few metres back
## and above; at the float at the top of an arc it swings out wide and high,
## so the island hangs in the view; in a dive it pulls in close behind the
## shoulders, nearly first person. It hangs on a spring off the glider, so
## in a turn it swings out round the outside and catches up after, and it
## leans a little with the bank, never far. Its view widens with speed and
## kicks open on entering a jet stream.
##
## Held, the free look turns it round the glider without steering, to look
## at an island while circling it; let go, it swings back behind, after
## `linger` seconds without a turn (none for the glide; the plane's pan holds
## a while, for the view). It never
## goes inside an island: with `solid` it stops short of rock and ground.
## `first_person` puts the eye in the glider's head, as before.
##
## A sequence can ask for a framing of its own (`cine`): the plane's landing
## (scripts/plane_landing.gd) swings it wider on final and round to a low
## side view at the touch, eased over EASE_CINE, on top of the free look.
##
## Like the glide, it is plain state and maths, so tests can step it.

## Metres back from the glider and up over it: at a cruise, at the float,
## and tucked in a dive.
const BACK := Vector3(5.2,9.0,1.7)
const UP := Vector3(1.4,3.0,0.45)
## How far ahead it looks (metres, plus seconds of speed), and how high.
const AHEAD := 2.5
const AHEAD_SPEED := 0.12
const LOOK_UP := 0.35
## How fast its idea of the flight's way follows the glide (seconds), and
## how stiff the spring it hangs on is (radians a second).
const EASE_WAY := 0.3
const SPRING := 4.5
## How fast it swings out at the float and back in after (seconds).
const FLOAT_IN := 0.15
const FLOAT_OUT := 1.2
## How much of the glider's bank it leans with, the most it ever leans
## (radians, 12 degrees; it eases into that softly rather than stopping hard), and how
## fast it follows. Flying straight the bank comes off, and it settles level.
const ROLL := 0.4
const ROLL_MAX := 0.21
const EASE_ROLL := 0.25
## The field of view (degrees): at a cruise, the most speed widens it by,
## and in first person. It widens between the airspeeds FOV_SPEED (m/s),
## opening fast at first and gently near the top, so a dive feels it early
## and a cruise's small swells don't breathe it. Entering a jet stream kicks it open a little more
## for a moment (JET_KICK, gone over JET_SETTLE seconds); at the float it
## narrows by FOV_FLOAT. It follows over EASE_FOV seconds.
const FOV := 70.0
const FOV_FAST := 10.0
const FOV_FIRST := 78.0
const FOV_FIRST_FAST := 26.0
const FOV_SPEED := Vector2(8.0,40.0)
const JET_KICK := 5.0
const JET_SETTLE := 0.8
const FOV_FLOAT := 4.0
const EASE_FOV := 0.3
## Free look: the furthest it turns up and down (radians), and how fast it
## swings back once let go (seconds).
const FREE_PITCH := Vector2(-0.9,1.2)
const EASE_BACK := 0.45
## It keeps this far from rock and ground, and checks the way out in this
## many steps.
const KEEP := 0.45
const PROBES := 12
## How fast it eases to a sequence's framing (seconds).
const EASE_CINE := 0.9

## The camera's eye and the point it looks at (global), its roll and its
## field of view (degrees).
var eye := Vector3.ZERO
var look := Vector3.ZERO
var roll := 0.0
var fov := FOV
var first_person := false
## The free look's turn (radians: round the glider, up and down), and
## whether it is held.
var free := Vector2.ZERO
var free_held := false
## Seconds the free look holds after its last turn before it swings back,
## and seconds since that turn.
var linger := 0.0
var _since_turn := INF
## The framing a sequence asks for: Vector3(how far round the plane it
## swings, radians, right positive; how far it tips down towards level,
## radians; how much further back and up it stands, a share), and where
## it has eased to.
var cine := Vector3.ZERO
var _cine := Vector3.ZERO
## A plane drawn bigger on its wheels (scripts/plane_ground_scale.gd): its
## distance and height times `size`, and the middle it frames lifted by
## `lift`. 1 and none in flight.
var size := 1.0
var lift := Vector3.ZERO
## Launch-flag trials: `--cam-distance=<x>` times the chase's back distance
## and height (on top of `size`), `--cam-fov=<deg>` its base view, and
## `--cam-speed-fov=<x>` times how much speed widens it. 1, FOV, 1 by default.
var distance_scale := _flag("--cam-distance=",1.0)
var base_fov := _flag("--cam-fov=",FOV)
var speed_fov := _flag("--cam-speed-fov=",1.0)
## How close in it is now (0 cruise, 1 tucked) and how wide (the float).
var tuck := 0.0
var float_out := 0.0
var _way := Vector3.FORWARD
var _offset := Vector3.ZERO
var _offset_v := Vector3.ZERO
## The jet as it was felt a moment ago: the kick is how far the jet now
## runs ahead of it.
var _jet_felt := 0.0

## Starts at `from` (the eye it takes over from) behind a glide, its view
## `view` degrees wide (the view it takes over), easing from there.
func reset(glide: RefCounted, from: Vector3, view := FOV) -> void:
	_way = glide.forward()
	_offset = from-glide.position
	_offset_v = Vector3.ZERO
	free = Vector2.ZERO
	free_held = false
	_since_turn = INF
	cine = Vector3.ZERO
	_cine = Vector3.ZERO
	tuck = 0.0
	float_out = 0.0
	roll = _lean(float(glide.bank))
	fov = view
	_jet_felt = float(glide.in_jet)
	eye = from
	look = glide.position+_way*AHEAD

## Turns the free look by `by` radians (round, up).
func turn(by: Vector2) -> void:
	free.x = wrapf(free.x+by.x,-PI,PI)
	free.y = clampf(free.y+by.y,FREE_PITCH.x,FREE_PITCH.y)
	_since_turn = 0.0

## One frame behind `glide`, `dive` held 0..1. `solid`, if given, is a
## Callable(Vector3) -> bool: true inside rock or ground.
func step(delta: float, glide: RefCounted, dive: float, solid := Callable()) -> void:
	var at: Vector3 = glide.position+lift
	_widen(delta,glide)
	if first_person:
		_way = glide.forward()
		_offset = Vector3.ZERO
		_offset_v = Vector3.ZERO
		eye = at
		look = at+_way*AHEAD
		roll = -glide.bank
		return
	# The way it flies: half where it points, half where it goes.
	var moving: Vector3 = glide.velocity
	var way: Vector3 = glide.forward()
	if moving.length() > 0.5: way = (way+moving.normalized()).normalized()
	_way = _way.slerp(way,_ease(EASE_WAY,delta)).normalized()
	var fast := clampf((float(glide.speed)-16.0)/14.0,0.0,1.0)
	tuck = lerpf(tuck,maxf(clampf(dive,0.0,1.0),fast*0.7),_ease(0.4,delta))
	# The float swings it out quickly and it lingers out there through the
	# tip-over.
	var hang := float(glide.hang)
	float_out = lerpf(float_out,hang,_ease(FLOAT_IN if hang > float_out else FLOAT_OUT,delta))
	_cine = _cine.lerp(cine,_ease(EASE_CINE,delta))
	var back := lerpf(lerpf(BACK.x,BACK.y,float_out),BACK.z,tuck)*(1.0+_cine.z)*size*distance_scale
	var up := lerpf(lerpf(UP.x,UP.y,float_out),UP.z,tuck)*(1.0+_cine.z*0.5)*size*distance_scale
	_since_turn += delta
	if not free_held and _since_turn >= linger: free = free.lerp(Vector2.ZERO,_ease(EASE_BACK,delta))
	var swing := free+Vector2(_cine.x,_cine.y)
	# Behind along the flat of the way, lifted by its climb or dive, then
	# turned by the free look.
	var flat := Vector3(_way.x,0.0,_way.z)
	if flat.length() < 0.05: flat = Vector3(-sin(float(glide.heading)),0.0,-cos(float(glide.heading)))
	flat = flat.normalized()
	var behind := (-_way*back+Vector3.UP*up).rotated(Vector3.UP,swing.x)
	var side := flat.cross(Vector3.UP).rotated(Vector3.UP,swing.x)
	behind = behind.rotated(side.normalized(),swing.y)
	# The spring it hangs on: critically damped, towards the goal.
	var accel := (behind-_offset)*SPRING*SPRING-_offset_v*2.0*SPRING
	_offset_v += accel*delta
	_offset += _offset_v*delta
	eye = at+_offset
	var ahead := AHEAD+AHEAD_SPEED*float(glide.speed)
	look = at.lerp(at+_way*ahead*size+Vector3.UP*LOOK_UP*size,1.0-smoothstep(0.3,1.0,absf(swing.x)/PI))
	roll = lerpf(roll,_lean(float(glide.bank)),_ease(EASE_ROLL,delta))
	if solid.is_valid(): _keep_clear(at,solid)

static func _flag(prefix: String, fallback: float) -> float:
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with(prefix): return maxf(0.0,float(arg.substr(prefix.length())))
	return fallback

## The roll for a bank: a share of it, eased softly into ROLL_MAX.
func _lean(bank: float) -> float:
	return -ROLL_MAX*tanh(bank*ROLL/ROLL_MAX)

## The field of view eases towards the speed's, the jet's kick and the
## float's narrowing.
func _widen(delta: float, glide: RefCounted) -> void:
	var t := clampf((glide.velocity.length()-FOV_SPEED.x)/(FOV_SPEED.y-FOV_SPEED.x),0.0,1.0)
	var fast := 1.0-(1.0-t)*(1.0-t)
	var jet := float(glide.in_jet)
	_jet_felt = lerpf(_jet_felt,jet,_ease(JET_SETTLE,delta))
	var kick := smoothstep(0.0,0.5,jet-_jet_felt)
	var want := (FOV_FIRST+FOV_FIRST_FAST*fast) if first_person else (base_fov+FOV_FAST*speed_fov*fast)
	want += JET_KICK*kick-FOV_FLOAT*float(glide.hang)
	fov = lerpf(fov,want,_ease(EASE_FOV,delta))

## Out from the glider towards the eye, it stops short of the first rock.
func _keep_clear(at: Vector3, solid: Callable) -> void:
	var out := eye-at
	var reach := out.length()
	if reach < 0.01: return
	var dir := out/reach
	for i in range(1,PROBES+1):
		var d := reach*float(i)/PROBES
		if solid.call(at+dir*(d+KEEP)):
			eye = at+dir*maxf(d-reach/PROBES,0.0)
			_offset = eye-at
			return

func _ease(rate: float, delta: float) -> float:
	return 1.0-exp(-delta/rate)
