extends RefCounted
## The skydive's camera (scripts/sky_dive.gd): it rides over the pilot's
## shoulders falling, looking down past them at the land rushing up, the
## view widening with the fall and a soft tremor in it at full speed; under
## the canopy it eases back behind and a little under the canopy, looking
## ahead and down over the pilot's feet at where they are floating to.
## Kept gentle: no roll beyond a little lean, a tremor of centimetres.
##
## It hangs on a spring off the pilot, as the chase does (scripts/
## glide_camera.gd), so a turn swings it round after; the canopy's bite
## kicks it on down past the pilot a moment (`kick`). The free look (the
## mouse, the right stick) turns it round the pilot and it swings back
## behind after `linger` seconds. It keeps out of rock and ground (`solid`).
##
## Plain state and maths, so tests can step it.

const SkyDive = preload("res://scripts/sky_dive.gd")

## Falling: metres back and up from the pilot, and how far ahead and down
## it looks. Under the canopy: the same.
const FALL_BACK := 2.4
const FALL_UP := 3.6
const FALL_AHEAD := 2.0
const FALL_DOWN := 6.0
const CANOPY_BACK := 5.8
const CANOPY_UP := 0.6
const CANOPY_AHEAD := 6.0
const CANOPY_DOWN := 2.4
## The spring it hangs on (radians a second), and how fast its sense of
## the pilot's way follows a turn (s).
const SPRING := 4.0
const EASE_WAY := 0.35
## The field of view (degrees): at rest, the most the fall widens it by
## (at FAST m/s), under the canopy; how fast it follows (s).
const FOV := 66.0
const FOV_FAST := 22.0
const FAST := 34.0
const FOV_CANOPY := 64.0
const EASE_FOV := 0.4
## The tremor: from SHAKE_FROM m/s, up to SHAKE m at FAST.
const SHAKE_FROM := 16.0
const SHAKE := 0.06
## The lean with the pilot's bank, and its most (radians).
const ROLL := 0.25
const ROLL_MOST := 0.12
## The free look's reach up and down (radians), how fast it swings back (s).
const FREE_PITCH := Vector2(-0.9,0.9)
const EASE_BACK := 0.5
const KEEP := 0.45
const PROBES := 10

var eye := Vector3.ZERO
var look := Vector3.ZERO
var roll := 0.0
var fov := FOV
var free := Vector2.ZERO
var free_held := false
var linger := 1.5
var _since_turn := INF
var _way := 0.0
var _offset := Vector3.ZERO
var _offset_v := Vector3.ZERO
var _canopy := 0.0
var _clock := 0.0

## Takes over from an eye at `from`, its view `view` degrees wide.
func reset(dive: RefCounted, from: Vector3, view := FOV) -> void:
	_way = float(dive.heading)
	_offset = from-dive.position
	_offset_v = Vector3.ZERO
	free = Vector2.ZERO
	_since_turn = INF
	_canopy = 1.0 if dive.under_canopy() else 0.0
	fov = view
	roll = 0.0
	eye = from
	look = dive.position

func turn(by: Vector2) -> void:
	free.x = wrapf(free.x+by.x,-PI,PI)
	free.y = clampf(free.y+by.y,FREE_PITCH.x,FREE_PITCH.y)
	_since_turn = 0.0

## The canopy's bite: the camera carries on down a moment.
func kick() -> void:
	_offset_v += Vector3.DOWN*5.0

func step(delta: float, dive: RefCounted, solid := Callable()) -> void:
	_clock += delta
	var at: Vector3 = dive.position
	_way = lerp_angle(_way,float(dive.heading),_ease(EASE_WAY,delta))
	_canopy = lerpf(_canopy,clampf(float(dive.open)*float(dive.under_canopy()) if dive.phase != SkyDive.DOWN else 1.0,0.0,1.0),_ease(0.6,delta))
	_since_turn += delta
	if not free_held and _since_turn >= linger: free = free.lerp(Vector2.ZERO,_ease(EASE_BACK,delta))
	var forward := Vector3(-sin(_way),0.0,-cos(_way))
	var back := lerpf(FALL_BACK,CANOPY_BACK,_canopy)
	var up := lerpf(FALL_UP,CANOPY_UP,_canopy)
	var goal := (-forward*back+Vector3.UP*up).rotated(Vector3.UP,free.x)
	var side := forward.cross(Vector3.UP).rotated(Vector3.UP,free.x).normalized()
	goal = goal.rotated(side,free.y)
	var accel := (goal-_offset)*SPRING*SPRING-_offset_v*2.0*SPRING
	_offset_v += accel*delta
	_offset += _offset_v*delta
	var fall_speed := (dive.velocity as Vector3).length()
	var tremor := SHAKE*smoothstep(SHAKE_FROM,FAST,fall_speed)*(1.0-_canopy)
	var shake := Vector3(sin(_clock*23.0)+0.6*sin(_clock*37.0+1.3),sin(_clock*29.0+0.7)+0.5*sin(_clock*41.0),sin(_clock*19.0+2.1))*tremor*0.6
	eye = at+_offset+shake
	var ahead := lerpf(FALL_AHEAD,CANOPY_AHEAD,_canopy)
	var down := lerpf(FALL_DOWN,CANOPY_DOWN,_canopy)
	look = at+forward.rotated(Vector3.UP,free.x*0.5)*ahead+Vector3.DOWN*down
	roll = lerpf(roll,clampf(-float(dive.bank)*ROLL,-ROLL_MOST,ROLL_MOST),_ease(0.3,delta))
	var fast := clampf(fall_speed/FAST,0.0,1.0)
	var want := lerpf(FOV+FOV_FAST*(1.0-(1.0-fast)*(1.0-fast)),FOV_CANOPY,_canopy)
	fov = lerpf(fov,want,_ease(EASE_FOV,delta))
	if solid.is_valid(): _keep_clear(at,solid)

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
