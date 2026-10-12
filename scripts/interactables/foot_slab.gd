extends Node3D
## A floating stone slab the pilot stands on (scripts/interactables/
## foot_pieces.gd carries him with it): one of the aqueduct isle's floating
## stones (studies/aqueduct_isle_art.gd `floating_stones`, its eroded
## basalt, worn arrises, the clod torn up under it and ivy hanging), on a
## clean walking box, its top's middle at this node's origin.
##
## Each frame (`advance`) it goes to its pose (`pose_at`, the time: still
## here; scripts/interactables/drift_slab.gd moves it along a path or turns
## it), then sags and tilts on a spring under his weight: stood on, it
## sinks SINK and tips TILT (radians at the edge) toward where he stands;
## landed on, it takes a kick down the harder he came (GIVE, m/s a m/s of
## his fall); let go of, it springs back, overshooting a little. With BOB
## and BOB_TIME it bobs gently on its own (scripts/interactables/
## bob_slab.gd). What it moved since the last frame (`moved`, one
## transform) carries him, and the pace of a point on it (`velocity_at`)
## goes with him when he leaves it.
##
## A slam (scripts/slam.gd: it joins its group) shoves it out
## and down from where it touched, by its share there and its strength:
## a kick down (SLAM_SINK), tipped away (SLAM_TIP) and pushed off sideways
## on a spring of its own (SLAM_SHOVE, the same spring), all coming back
## as a landing's does.
##
## Its feel is the subclass's: `sink`, `tilt`, `give`, `hz` (the spring,
## Hz), `damp` (its damping ratio), `bob`, `bob_time`.
const Art = preload("res://studies/aqueduct_isle_art.gd")
const Slam = preload("res://scripts/slam.gd")
## A full slam at its middle: m/s down, rad/s of tip, m/s aside.
const SLAM_SINK := 2.6
const SLAM_TIP := 0.9
const SLAM_SHOVE := 1.6

var size := Vector3(2.4,0.7,2.2)
var seed_value := 0
var sink := 0.05
var tilt := 0.02
var give := 0.03
var hz := 2.0
var damp := 0.5
var bob := 0.0
var bob_time := 5.0
## The stone and its body.
var stone: Node3D
var body: StaticBody3D
## The pose before the sag (the frame's).
var rest := Transform3D.IDENTITY
## The sag (m, down negative) and the tilt (axis times angle, x z), each on
## its spring.
var sag := 0.0
var sag_v := 0.0
var lean := Vector3.ZERO
var lean_v := Vector3.ZERO
## The shove aside (m, x z) and its pace, on the spring too.
var shove := Vector3.ZERO
var shove_v := Vector3.ZERO
## Slams that reached it.
var slammed := 0
## Where he stands on it this frame (its own frame), INF none.
var _load := Vector3.INF
var _time := 0.0
var _phase := 0.0
var _moved := Transform3D.IDENTITY
var _step := 1.0/60.0

## `at`: its rest pose (the top's middle); `stone_size` the block (m).
func setup(at: Transform3D, stone_size: Vector3, seed_in: int) -> void:
	rest = at
	size = stone_size
	seed_value = seed_in
	transform = at
	_phase = float(seed_in%97)*0.37

func _ready() -> void:
	add_to_group(Slam.GROUP)
	stone = Art.floating_stones(seed_value,[{"name":"slab","at":Vector3.ZERO,"size":size,"yaw":0.0,"kind":"block"}])
	add_child(stone)
	body = stone.get_node("Body")
	transform = _posed(pose_at(0.0))

## The pose at `t` seconds, before the sag (still, here).
func pose_at(_t: float) -> Transform3D:
	return rest

func rid() -> RID:
	return body.get_rid() if body != null else RID()

## Stood on at `p` (world) this frame.
func weigh(p: Vector3) -> void:
	_load = transform.affine_inverse()*p

## Landed on at `p`, coming down at `hard` m/s.
func land(p: Vector3, hard: float) -> void:
	sag_v -= hard*give
	var q := transform.affine_inverse()*p
	var flat := Vector3(q.x,0.0,q.z)
	if flat.length() > 0.05: lean_v += Vector3.UP.cross(flat).normalized()*hard*give*0.6

## A slam at `at` (scripts/slam.gd): shoved out and down.
func slam(at: Vector3, radius: float, strength: float) -> void:
	var s := Slam.share(at,radius,global_position)*strength
	if s <= 0.0: return
	slammed += 1
	sag_v -= SLAM_SINK*s
	var out := Vector3(global_position.x-at.x,0.0,global_position.z-at.z)
	if out.length() > 0.05:
		out = out.normalized()
		shove_v += out*SLAM_SHOVE*s
		lean_v += Vector3.UP.cross(out)*-SLAM_TIP*s
	else:
		# Square on its middle: straight down, a little tip off the way he
		# stands on it.
		var q := transform.affine_inverse()*at
		var flat := Vector3(q.x,0.0,q.z)
		if flat.length() > 0.05: lean_v += Vector3.UP.cross(flat).normalized()*SLAM_TIP*s*0.5

## One frame: to its pose, sagged and tilted on the spring.
func advance(delta: float) -> void:
	if delta <= 0.0: return
	_step = delta
	_time += delta
	var goal := bob*sin(TAU*_time/maxf(bob_time,0.1)+_phase)
	var lean_goal := Vector3.ZERO
	if _load != Vector3.INF:
		goal -= sink
		var flat := Vector3(_load.x,0.0,_load.z)
		var reach := maxf(minf(size.x,size.z)*0.5,0.3)
		if flat.length() > 0.02: lean_goal = Vector3.UP.cross(flat).normalized()*tilt*clampf(flat.length()/reach,0.0,1.0)
	elif bob > 0.0:
		lean_goal = Vector3(sin(_time*0.9+_phase),0.0,cos(_time*0.7+_phase*1.3))*tilt*0.25
	_load = Vector3.INF
	var w := TAU*hz
	# Semi-implicit, in small steps so a long frame stays stable.
	var left := delta
	while left > 0.0:
		var dt := minf(left,1.0/120.0)
		sag_v += (w*w*(goal-sag)-2.0*damp*w*sag_v)*dt
		sag += sag_v*dt
		lean_v += (w*w*(lean_goal-lean)-2.0*damp*w*lean_v)*dt
		lean += lean_v*dt
		shove_v += (-w*w*shove-2.0*damp*w*shove_v)*dt
		shove += shove_v*dt
		left -= dt
	var was := transform
	var now := _posed(pose_at(_time))
	transform = now
	# The body to its new place in the physics space now, not at the
	# tree's flush: the motor's rays this frame see it where it is drawn.
	if body != null: body.force_update_transform()
	_moved = now*was.affine_inverse()

func _posed(base: Transform3D) -> Transform3D:
	var tip := Basis(lean.normalized(),lean.length()) if lean.length() > 1e-6 else Basis.IDENTITY
	return Transform3D(tip*base.basis,base.origin+Vector3.UP*sag+shove)

## What it moved since the last frame (the frame's).
func moved() -> Transform3D:
	return _moved

## Its turn about up since the last frame (radians, as the motor's facing
## turns).
func turn() -> float:
	var z := _moved.basis.z
	return atan2(z.x,z.z) if Vector2(z.x,z.z).length() > 1e-4 else 0.0

## The pace of its point `p` (world, m/s) over the last frame.
func velocity_at(p: Vector3) -> Vector3:
	return (_moved*p-p)/_step if _step > 0.0 else Vector3.ZERO
