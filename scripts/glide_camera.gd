extends RefCounted
## The glide's camera (scripts/sky_glide.gd): a chase view behind the glider
## that breathes with the flight. At a cruise it trails a few metres back
## and above; at the float at the top of an arc it swings out wide and high,
## so the island hangs in the view; in a dive it pulls in close behind the
## shoulders, nearly first person. It hangs on a spring off the glider, so
## in a turn it swings out round the outside and catches up after.
##
## Held, the free look turns it round the glider without steering, to look
## at an island while circling it; let go, it swings back behind. It never
## goes inside an island: with `solid` it stops short of rock and ground.
## `first_person` puts the eye in the glider's head, as before.
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
## How much of the glider's bank it leans with, and how fast.
const ROLL := 0.55
const EASE_ROLL := 0.2
## Free look: the furthest it turns up and down (radians), and how fast it
## swings back once let go (seconds).
const FREE_PITCH := Vector2(-0.9,1.2)
const EASE_BACK := 0.45
## It keeps this far from rock and ground, and checks the way out in this
## many steps.
const KEEP := 0.45
const PROBES := 12

## The camera's eye and the point it looks at (global), and its roll.
var eye := Vector3.ZERO
var look := Vector3.ZERO
var roll := 0.0
var first_person := false
## The free look's turn (radians: round the glider, up and down), and
## whether it is held.
var free := Vector2.ZERO
var free_held := false
## How close in it is now (0 cruise, 1 tucked) and how wide (the float).
var tuck := 0.0
var float_out := 0.0
var _way := Vector3.FORWARD
var _offset := Vector3.ZERO
var _offset_v := Vector3.ZERO

## Starts at `from` (the eye it takes over from) behind a glide.
func reset(glide: RefCounted, from: Vector3) -> void:
	_way = glide.forward()
	_offset = from-glide.position
	_offset_v = Vector3.ZERO
	free = Vector2.ZERO
	free_held = false
	tuck = 0.0
	float_out = 0.0
	roll = -glide.bank*ROLL
	eye = from
	look = glide.position+_way*AHEAD

## Turns the free look by `by` radians (round, up).
func turn(by: Vector2) -> void:
	free.x = wrapf(free.x+by.x,-PI,PI)
	free.y = clampf(free.y+by.y,FREE_PITCH.x,FREE_PITCH.y)

## One frame behind `glide`, `dive` held 0..1. `solid`, if given, is a
## Callable(Vector3) -> bool: true inside rock or ground.
func step(delta: float, glide: RefCounted, dive: float, solid := Callable()) -> void:
	var at: Vector3 = glide.position
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
	var back := lerpf(lerpf(BACK.x,BACK.y,float_out),BACK.z,tuck)
	var up := lerpf(lerpf(UP.x,UP.y,float_out),UP.z,tuck)
	if not free_held: free = free.lerp(Vector2.ZERO,_ease(EASE_BACK,delta))
	# Behind along the flat of the way, lifted by its climb or dive, then
	# turned by the free look.
	var flat := Vector3(_way.x,0.0,_way.z)
	if flat.length() < 0.05: flat = Vector3(-sin(float(glide.heading)),0.0,-cos(float(glide.heading)))
	flat = flat.normalized()
	var behind := (-_way*back+Vector3.UP*up).rotated(Vector3.UP,free.x)
	var side := flat.cross(Vector3.UP).rotated(Vector3.UP,free.x)
	behind = behind.rotated(side.normalized(),free.y)
	# The spring it hangs on: critically damped, towards the goal.
	var accel := (behind-_offset)*SPRING*SPRING-_offset_v*2.0*SPRING
	_offset_v += accel*delta
	_offset += _offset_v*delta
	eye = at+_offset
	var ahead := AHEAD+AHEAD_SPEED*float(glide.speed)
	look = at.lerp(at+_way*ahead+Vector3.UP*LOOK_UP,1.0-smoothstep(0.3,1.0,absf(free.x)/PI))
	roll = lerpf(roll,-float(glide.bank)*ROLL,_ease(EASE_ROLL,delta))
	if solid.is_valid(): _keep_clear(at,solid)

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
