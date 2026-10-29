extends RefCounted
## The preview pan of a beat route (scripts/endless/beat_routes.gd): the
## chase camera handed over for PAN s while the flight is held. The eye
## rises from the chase to a high point behind the starter and drifts on
## over the route, while the look sweeps from the start through the beats
## in order to the finish, holding on it a moment; then BACK s blending
## back to the chase. Any fly input or Tab skips it straight to the blend.
## The menu's orbit (menu_stage.gd) was the model.

## The pan (s), the rise into it (s), the hold on the finish (s), the blend back (s).
const PAN := 5.0
const RISE := 1.2
const HOLD := 0.9
const BACK := 0.9
## The high point: UP m over the starter, BEHIND m back from the route.
const UP := 210.0
const BEHIND := 260.0
## How far on over the route the eye drifts (share of the way to its middle).
const DRIFT := 0.45

var phase := "off"
var t := 0.0
var _from := Transform3D.IDENTITY
var _left := Transform3D.IDENTITY
var _targets: Array = []
var _hi := Vector3.ZERO
var _on := Vector3.ZERO

## The pan from the camera at `from` over `targets` (the start, the beats in
## order, the finish).
func begin(from: Transform3D, targets: Array) -> void:
	_from = from
	_targets = targets
	var start: Vector3 = targets[0]
	var mid := Vector3.ZERO
	for p: Vector3 in targets: mid += p
	mid /= float(targets.size())
	var way := Vector3(mid.x-start.x,0.0,mid.z-start.z)
	if way.length() < 1.0: way = Vector3.FORWARD
	_hi = start-way.normalized()*BEHIND+Vector3.UP*UP
	_on = _hi+Vector3(way.x,0.0,way.z)*DRIFT
	phase = "pan"
	t = 0.0

func running() -> bool:
	return phase != "off"

## Skipped: straight on to the blend back from where the eye is.
func skip(now: Transform3D) -> void:
	if phase != "pan": return
	_left = now
	phase = "back"
	t = 0.0

## One frame: the camera's transform this frame, given the chase's own
## (`chase`, what the blend comes back to).
func step(delta: float, chase: Transform3D) -> Transform3D:
	t += delta
	if phase == "pan":
		var x := _pan_pose(t)
		if t >= PAN:
			_left = x
			phase = "back"
			t = 0.0
		return x
	if phase == "back":
		var u := smoothstep(0.0,1.0,t/BACK)
		var x := _blend(_left,chase,u)
		if t >= BACK: phase = "off"
		return x
	return chase

func _pan_pose(at: float) -> Transform3D:
	var rise := smoothstep(0.0,1.0,at/RISE)
	var eye := _from.origin.lerp(_hi,rise)
	eye = eye.lerp(_on,smoothstep(RISE,PAN,at)*rise)
	# The look: from where the chase looked, through the route in order, held
	# on the finish at the end.
	var sweep := clampf((at-RISE*0.5)/(PAN-HOLD-RISE*0.5),0.0,1.0)
	var look := _along(sweep)
	var ahead := _from.origin-_from.basis.z*80.0
	look = ahead.lerp(look,smoothstep(0.0,0.6,at/RISE))
	var x := Transform3D(Basis.IDENTITY,eye)
	if (look-eye).length() > 0.5: x = x.looking_at(look,Vector3.UP)
	return x

## A point along the targets at `u` (0 the start, 1 the finish), eased at each.
func _along(u: float) -> Vector3:
	var n := _targets.size()
	if n == 1: return _targets[0]
	var f := u*float(n-1)
	var i := mini(int(f),n-2)
	var k := smoothstep(0.0,1.0,f-float(i))
	return (_targets[i] as Vector3).lerp(_targets[i+1] as Vector3,k)

static func _blend(a: Transform3D, b: Transform3D, u: float) -> Transform3D:
	var qa := a.basis.get_rotation_quaternion()
	var qb := b.basis.get_rotation_quaternion()
	return Transform3D(Basis(qa.slerp(qb,u)),a.origin.lerp(b.origin,u))
