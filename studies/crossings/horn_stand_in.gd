extends Node3D
## The greybox wind horn:
## the stand-in for the stone wind horn (RuinKitHorn `wind_horn(seed,
## weathered)`, being built on feature/wind-horn), with the same nodes and
## methods, so the swap is one line (crossing_viaduct.gd `perch_piece`):
##   - "Head" (Node3D): turns to face the pilot;
##   - "Mouth" (Marker3D, under the head): where the ball leaves;
##   - `aim_at(world_point, delta)`, `tell(share 0..1)`, `fired()`,
##     `disabled(seconds)`, `is_disabled()`.
## Its foot is at its origin (stood on its perch's top); its mouth MOUTH_UP
## over it, facing -Z at rest. No collider: the perch's top under it is the
## stone he stands on.
##
## A box head on a squat base: it turns toward his middle (TURN rad/s), it
## shudders through the tell (SHUDDER m and rad at the full gather), it kicks
## back when it fires (RECOIL), and it tips over (TIP rad, DROP m) and goes
## grey while disabled, righting itself over RIGHT s as it comes back.

const MOUTH_UP := 1.2
const TURN := 2.5
const SHUDDER := 0.06
const RECOIL := 0.25
const RECOIL_BACK := 4.0
const TIP := 1.3
const DROP := 0.45
const RIGHT := 0.6
const HEAD := Vector3(0.8,0.7,1.2)
const BELL := Vector3(1.1,1.0,0.3)

var head: Node3D
var mouth: Marker3D
var _bell: MeshInstance3D
var _live_paint: Material
var _down_paint: Material
var _yaw := 0.0
var _pitch := 0.0
var _tell := 0.0
var _recoil := 0.0
var _down_left := 0.0
var _down := 0.0
var _clock := 0.0

## Built in the crossing's greybox colours (`paint`, the crossing's
## Callable(colour) -> Material).
func setup(paint: Callable) -> void:
	name = "WindHornStandIn"
	var base := MeshInstance3D.new()
	base.name = "Base"
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0,MOUTH_UP-HEAD.y*0.5,1.0)
	base.mesh = bm
	base.position = Vector3(0.0,bm.size.y*0.5,0.0)
	base.material_override = paint.call("dark")
	add_child(base)
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0,MOUTH_UP,0.0)
	add_child(head)
	var box := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = HEAD
	box.mesh = hm
	box.material_override = paint.call("dark")
	head.add_child(box)
	_bell = MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = BELL
	_bell.mesh = lm
	_bell.position = Vector3(0.0,0.0,-HEAD.z*0.5-BELL.z*0.5)
	_live_paint = paint.call("lane")
	_down_paint = paint.call("grey")
	_bell.material_override = _live_paint
	head.add_child(_bell)
	mouth = Marker3D.new()
	mouth.name = "Mouth"
	mouth.position = Vector3(0.0,0.0,-HEAD.z*0.5-BELL.z)
	head.add_child(mouth)

## Turned toward `p` (world) at TURN rad/s; disabled, it lies still.
func aim_at(p: Vector3, delta: float) -> void:
	if is_disabled() or head == null or not is_inside_tree(): return
	var from := head.global_position
	var d := p-from
	if d.length() < 0.1: return
	var local := global_basis.inverse()*d
	var want_yaw := atan2(-local.x,-local.z)
	var want_pitch := atan2(local.y,Vector2(local.x,local.z).length())
	var step := TURN*delta
	_yaw += clampf(wrapf(want_yaw-_yaw,-PI,PI),-step,step)
	_pitch += clampf(want_pitch-_pitch,-step,step)

## The tell's share done (0 none, 1 about to fire).
func tell(share: float) -> void:
	_tell = clampf(share,0.0,1.0)

func fired() -> void:
	_recoil = 1.0
	_tell = 0.0

func disabled(seconds: float) -> void:
	_down_left = maxf(_down_left,seconds)
	_tell = 0.0

func is_disabled() -> bool:
	return _down_left > 0.0

func _process(delta: float) -> void:
	_clock += delta
	_down_left = maxf(_down_left-delta,0.0)
	# Tipped over at once, righted over RIGHT s as it comes back.
	_down = 1.0 if _down_left > 0.0 else maxf(_down-delta/RIGHT,0.0)
	_recoil = maxf(_recoil-delta*RECOIL_BACK,0.0)
	if head == null: return
	var shake := _tell*_tell*SHUDDER
	var jitter := Vector3(sin(_clock*61.0),sin(_clock*47.0+1.3),sin(_clock*53.0+2.1))*shake
	var basis := Basis(Vector3.UP,_yaw+jitter.x*2.0)*Basis(Vector3.RIGHT,_pitch*(1.0-_down)+jitter.y*2.0)
	# Tipped forward off its base, onto its bell.
	basis = basis*Basis(Vector3.RIGHT,-TIP*_down)
	var back := basis*Vector3(0.0,0.0,RECOIL*_recoil)
	head.transform = Transform3D(basis,Vector3(0.0,MOUTH_UP-DROP*_down,0.0)+back+jitter)
	_bell.material_override = _down_paint if _down > 0.0 else _live_paint
