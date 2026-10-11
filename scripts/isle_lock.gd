extends RefCounted
## Locking onto an isle from the plane (R3 / Tab): the plane flies itself
## round the isle on a ring, neither drifting in to its stone nor out into
## open sky, so the isle can be looked over as it turns past. The ring is
## the isle's (`centre`, `extent`: the circle round its outlines) widened by
## CLEAR m; the plane goes round the way it was already turning, so locking
## never wheels it about.
##
## While locked the left stick no longer steers: left and right draw the
## ring in and out (between its least and most), up and down lower and
## raise it (W lowers, as W puts the nose down), all within the isle's band
## of sky. Boost, brake, the knife edge and the barrel roll still fly as
## ever. The mouse's direct steer is set aside. Free flight round an isle
## by hand is untouched: the lock is only ever asked for.
##
## `steer` turns the held input into the input that flies the ring;
## `framing` is how far in the lock is (0..1, eased), for the camera.

## The ring's least gap past the isle's edge, and how far in and out the
## stick moves it (m past the default, which is CLEAR).
const CLEAR := 45.0
const RING_IN := -25.0
const RING_OUT := 90.0
## The least ring across any isle (m, radius).
const RING_LEAST := 70.0
## How far from the ring the plane may be to lock on (times the ring), and
## past which the lock lets go by itself (bumped far off).
const REACH := 3.0
const LOSE := 4.0
## The band of sky the ring keeps (m over the isle's top), its default.
const BAND := Vector2(-6.0,70.0)
const HEIGHT := 22.0
## The stick's rates: m a second the ring widens, and rises.
const WIDEN_RATE := 22.0
const RISE_RATE := 10.0
## How hard it turns onto the ring: radians of heading error to a full
## stick, and how much a metre off the ring (per ring) bends the course in.
const TURN_GAIN := 2.6
const PULL_IN := 2.2
## How the nose follows the height: radians of pitch a metre off, at most,
## and the stick per radian off that pitch.
const CLIMB_GAIN := 0.03
const CLIMB_MOST := 0.32
const PITCH_GAIN := 3.0
## Seconds the camera takes to frame the isle (and to let go of it).
const EASE_FRAME := 0.9

var locked := false
var centre := Vector3.ZERO
var extent := 0.0
## +1 counter-clockwise seen from above, -1 clockwise.
var way := 1.0
## The ring's radius and height (world y) now.
var ring := 0.0
var height := 0.0
var framing := 0.0
## The isle's top, the band's datum.
var top := 0.0

## The isle to lock onto: its middle (x, z; y unused), the radius round
## its outlines, its top (world y).
func set_isle(middle: Vector3, radius: float, isle_top: float) -> void:
	centre = Vector3(middle.x,isle_top,middle.z)
	extent = radius
	top = isle_top

## The ring's default radius.
func ring_rest() -> float:
	return maxf(extent+CLEAR,RING_LEAST)

## Whether the plane at `at` is near enough to lock on.
func in_reach(at: Vector3) -> bool:
	return _flat(at-centre).length() < ring_rest()*REACH

## Locks on, going round the way `velocity` already turns about the isle.
func lock(at: Vector3, velocity: Vector3) -> void:
	locked = true
	var out := _flat(at-centre)
	var moving := _flat(velocity)
	way = 1.0 if out.cross(moving) >= 0.0 else -1.0
	ring = clampf(out.length(),ring_rest()+RING_IN,ring_rest()+RING_OUT)
	height = clampf(at.y,top+BAND.x,top+BAND.y) if at.y > top+BAND.x else top+HEIGHT

func release() -> void:
	locked = false

## The lock's own step: the ring moved by the stick, the framing eased,
## and let go if the plane is far off.
func advance(delta: float, at: Vector3, stick := Vector2.ZERO) -> void:
	if locked and _flat(at-centre).length() > ring_rest()*LOSE: locked = false
	if locked:
		ring = clampf(ring+stick.x*WIDEN_RATE*delta,ring_rest()+RING_IN,ring_rest()+RING_OUT)
		height = clampf(height+stick.y*RISE_RATE*delta,top+BAND.x,top+BAND.y)
	framing = move_toward(framing,1.0 if locked else 0.0,delta/EASE_FRAME)

## The input that flies the ring, from the input held (`input`, as the
## plane reads it) and the plane (heading, pitch, position).
func steer(input: Dictionary, plane: RefCounted) -> Dictionary:
	if not locked: return input
	var out := input.duplicate()
	var at: Vector3 = plane.position
	var off := _flat(at-centre)
	var dist := maxf(off.length(),0.001)
	var radial := off/dist
	# The tangent the way round, bent in or out by how far off the ring.
	var tangent := Vector2(-radial.y,radial.x)*way
	var bend := clampf((dist-ring)/ring*PULL_IN,-1.0,1.0)
	var course := (tangent-radial*bend).normalized()
	var want := atan2(-course.x,-course.y)
	var error := angle_difference(float(plane.heading),want)
	# Turn right (+) lowers the heading.
	out["turn"] = clampf(-error*TURN_GAIN,-1.0,1.0)
	var climb := clampf((height-at.y)*CLIMB_GAIN,-CLIMB_MOST,CLIMB_MOST)
	out["pitch"] = clampf((climb-float(plane.pitch))*PITCH_GAIN,-1.0,1.0)
	out["look"] = Vector2.ZERO
	return out

## How far the plane at `at` is off the ring now (m, in or out).
func off_ring(at: Vector3) -> float:
	return _flat(at-centre).length()-ring

func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x,v.z)
