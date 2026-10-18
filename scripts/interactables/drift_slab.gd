extends "res://scripts/interactables/foot_slab.gd"
## A drifting slab (docs/design/foot-interactables.md): a floating stone on
## the move, so the way across changes as he goes. Along `path` (its tops'
## middles, world): two or more points and not `closed`, it drifts there
## and back, easing to a stand at each end (a cosine, `period` s there and
## back); `closed`, it goes round them at an even pace, once a `period`.
## One point, it stays. `spin` (radians a second) turns it about its own
## middle as it goes (a long slab sweeping round is a turning bridge).
## `offset` (s) starts it partway. It sags a little under him (SINK, TILT)
## on a stiffer spring than a bob slab's. scripts/interactables/
## foot_pieces.gd carries him on it, turned as it turns, and its pace goes
## with him when he leaves it. `t_speed` (live, the yard's F4) scales every
## drifting slab's time.

const SINK := 0.06
const TILT := 0.025
const GIVE := 0.02
const HZ := 2.2
const DAMP := 0.45
static var t_speed := 1.0
static var t_sink := SINK
static var t_tilt := TILT

var path := PackedVector3Array()
var closed := false
var period := 8.0
var spin := 0.0
var yaw := 0.0
var offset := 0.0
var _clock := 0.0
var _lengths := PackedFloat32Array()

## Drifting along `points` (see the header), turned `yaw0` to begin with,
## `start` s along.
func drift(points: PackedVector3Array, period_s: float, loop := false, spin_rate := 0.0, yaw0 := 0.0, start := 0.0) -> void:
	path = points
	period = maxf(period_s,0.5)
	closed = loop
	spin = spin_rate
	yaw = yaw0
	offset = start
	_lengths.clear()
	var total := 0.0
	_lengths.append(0.0)
	var n := path.size()+(1 if closed else 0)
	for i in range(1,n):
		total += path[i-1].distance_to(path[i%path.size()])
		_lengths.append(total)

func _init() -> void:
	sink = SINK
	tilt = TILT
	give = GIVE
	hz = HZ
	damp = DAMP

func advance(delta: float) -> void:
	sink = t_sink
	tilt = t_tilt
	_clock += delta*t_speed
	super.advance(delta)

func pose_at(_t: float) -> Transform3D:
	var t := _clock+offset
	var turn := Basis(Vector3.UP,yaw+spin*t)
	if path.is_empty(): return Transform3D(turn,rest.origin)
	if path.size() == 1: return Transform3D(turn,path[0])
	var total: float = _lengths[_lengths.size()-1]
	var d := 0.0
	if closed: d = fposmod(t/period,1.0)*total
	else: d = (0.5-0.5*cos(TAU*t/period))*total
	return Transform3D(turn,_along(d))

## The point `d` m along the path.
func _along(d: float) -> Vector3:
	for i in range(1,_lengths.size()):
		if d <= _lengths[i] or i == _lengths.size()-1:
			var a := path[i-1]
			var b := path[i%path.size()]
			var span: float = _lengths[i]-_lengths[i-1]
			return a.lerp(b,clampf((d-_lengths[i-1])/maxf(span,1e-4),0.0,1.0))
	return path[0]

## Its rest pose for the layout editor (scripts/layout_overrides.gd): its
## path's start, turned its first yaw.
func layout_pose() -> Transform3D:
	return Transform3D(Basis(Vector3.UP,yaw),path[0] if not path.is_empty() else rest.origin)

## Moved to `t` (the layout editor): its whole path carried by the move
## (turned about its start), drawn there now.
func layout_place(t: Transform3D) -> void:
	var d := t*layout_pose().affine_inverse()
	for i in range(path.size()): path[i] = d*path[i]
	var f := d.basis*Vector3.FORWARD
	yaw += atan2(-f.x,-f.z)
	super.layout_place(Transform3D(Basis(Vector3.UP,yaw),t.origin))
