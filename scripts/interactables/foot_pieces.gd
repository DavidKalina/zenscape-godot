extends Node3D
## The on-foot pieces of a scene (docs/design/foot-interactables.md): the
## bobbing and drifting slabs (scripts/interactables/bob_slab.gd,
## drift_slab.gd), the swing ropes (swing_rope.gd) and the balustrades
## (balustrade.gd), stepped round the pilot's motor (scripts/
## pilot_motor.gd) by the character study's frame (studies/
## character_study.gd `foot_pieces`; the kit isles and the yard extend it).
## It stands at the world's origin; its pieces are placed in the world's
## frame.
##
## `before` (ahead of the motor's step): every piece on a frame (the slabs
## to their new pose), then, stood on a slab (or hanging from its lip), he
## is carried by what it moved (PilotMotor `carry`: his feet, pace and
## facing turned with it), as the serpent ride carries him on its back.
## `after` (the step done): what he stands on now; landed on a slab it
## takes the blow; leaving one (jumped, walked off), its pace at his feet
## goes with him (its rise only up to RISE_KEEP, so a jump off a slab
## springing back goes higher); stood on it, it feels his weight; in the
## air a rope may take him (its `try_catch`: his hands or chest meeting
## it). A balustrade is only a surface: stood or sliding on its coping, he
## is `on_rail` (counted, its top pace kept for the HUD and tests), and
## the motor does everything else. The events of the step get "slab"
## (landed on one), "swing" (true on a rope) and "rail" (true onto a
## balustrade's coping, false off it). `pose` tilts the drawn body along a
## rope he swings on, and eases it back upright over UPRIGHT s after.
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const FootSlab = preload("res://scripts/interactables/foot_slab.gd")
const BobSlab = preload("res://scripts/interactables/bob_slab.gd")
const DriftSlab = preload("res://scripts/interactables/drift_slab.gd")
const SinkSlab = preload("res://scripts/interactables/sink_slab.gd")
const SwingRope = preload("res://scripts/interactables/swing_rope.gd")
const Balustrade = preload("res://scripts/interactables/balustrade.gd")

## The most of a slab's rise kept leaving it (m/s), and the seconds the
## body takes to stand upright off a rope.
const RISE_KEEP := 3.0
const UPRIGHT := 0.25
## Pieces this far from him (m) are still stepped but skip their catch.
const NEAR := 30.0

var study: Node3D
var motor: PilotMotor
var slabs: Array = []
var ropes: Array = []
var rails: Array = []
## The slab he stands on (or hangs from) now, or null; the body by RID.
var on: Node3D = null
var _ray := PhysicsRayQueryParameters3D.new()
var _tilt := Basis.IDENTITY
var _tilt_left := 0.0
## Counted for the HUD and tests: landings on slabs, rope catches, times on
## a balustrade's coping; the last rope release's pace and the fastest on
## the coping this time on it (or the last).
var counts := {"slab":0,"swing":0,"rail":0,"snag":0}
var last_release := Vector3.ZERO
## The last rope release's timing (SwingRope `timing`, 0 to 1).
var last_timing := 0.0
## The rope he hung from going into this frame's step.
var _held: Node3D = null
var last_rail_top := 0.0
## The balustrade whose coping he is on now, or null.
var on_rail: Node3D = null
## Other pieces stepped round the motor (the plane's hitch, scripts/
## interactables/plane_hitch.gd): each has `before(delta)`,
## `after(delta, events)` and `pose(figure)`.
var extras: Array = []

func _init() -> void:
	name = "FootPieces"

## Hooked into `scene` (a character study): stepped by its frame.
func attach(scene: Node3D) -> void:
	study = scene
	motor = scene.motor
	scene.foot_pieces = self

func bob_slab(at: Vector3, size := Vector3(2.4,0.7,2.2), yaw := 0.0, seed_value := 0) -> Node3D:
	var slab: Node3D = BobSlab.new()
	slab.setup(Transform3D(Basis(Vector3.UP,yaw),at),size,seed_value)
	_add_slab(slab)
	return slab

## A slab that sinks while he stands on it (scripts/interactables/
## sink_slab.gd).
func sink_slab(at: Vector3, size := Vector3(2.4,0.7,2.2), yaw := 0.0, seed_value := 0) -> Node3D:
	var slab: Node3D = SinkSlab.new()
	slab.setup(Transform3D(Basis(Vector3.UP,yaw),at),size,seed_value)
	_add_slab(slab)
	return slab

## A drifting slab along `points` (see scripts/interactables/drift_slab.gd).
func drift_slab(points: PackedVector3Array, period: float, loop := false, spin := 0.0, size := Vector3(2.4,0.6,2.0), yaw := 0.0, seed_value := 0, start := 0.0) -> Node3D:
	var slab: Node3D = DriftSlab.new()
	slab.setup(Transform3D(Basis(Vector3.UP,yaw),points[0]),size,seed_value)
	slab.drift(points,period,loop,spin,yaw,start)
	_add_slab(slab)
	return slab

func rope(anchor: Vector3, length: float) -> Node3D:
	var r: Node3D = SwingRope.new()
	r.setup(anchor,length)
	add_child(r)
	ropes.append(r)
	return r

## A trilithon to swing from (two standing stones and a lintel, the
## aqueduct isle's floating-stone look, studies/aqueduct_isle_art.gd): its
## middle's foot at `mid`, the lintel along `way` (x, z) over `span` m
## between the stones, its underside `height` over `mid`, the stones sunk
## `sunk` under it; the rope `length` m from the lintel's middle.
func rope_frame(mid: Vector3, way: Vector2, span: float, height: float, length: float, seed_value := 0, sunk := 0.4) -> Node3D:
	var w := way.normalized()
	var yaw := atan2(-w.y,w.x)
	var side := Vector3(w.x,0.0,w.y)
	var stones: Array = []
	for k: float in [-0.5,0.5]:
		stones.append({"name":"post","at":mid+side*span*k+Vector3.UP*height,"size":Vector3(1.0,height+sunk,0.9),"yaw":yaw,"kind":"sarsen","grounded":true})
	stones.append({"name":"lintel","at":mid+Vector3.UP*(height+0.75),"size":Vector3(span+1.3,0.75,1.0),"yaw":yaw,"kind":"lintel"})
	var frame := FootSlab.Art.floating_stones(seed_value,stones)
	frame.name = "RopeFrame"
	add_child(frame)
	var r := rope(mid+Vector3.UP*height,length)
	r.add_tag(mid+Vector3.UP*height+side*0.9,yaw,seed_value)
	r.set_meta("frame",frame)
	return r

## A rope taken away (and its frame, if `rope_frame` made it).
func remove_rope(r: Node3D) -> void:
	if motor != null and motor.rider == r: motor.toss(motor.velocity)
	ropes.erase(r)
	if r.has_meta("frame"): (r.get_meta("frame") as Node).queue_free()
	r.queue_free()

func balustrade(points: PackedVector3Array, seed_value := 0, weathered := 0.3, floor := PackedVector3Array()) -> Node3D:
	var r: Node3D = Balustrade.new()
	r.setup(points,seed_value,weathered,floor)
	add_child(r)
	rails.append(r)
	return r

func _add_slab(slab: Node3D) -> void:
	add_child(slab)
	slabs.append(slab)

## The slab whose body is `rid`, or null.
func slab_of(rid: RID) -> Node3D:
	if not rid.is_valid(): return null
	for slab: Node3D in slabs:
		if slab.rid() == rid: return slab
	return null

## Every piece on a frame; he is carried by the slab under him.
func before(delta: float) -> void:
	_held = motor.rider if motor.rider in ropes else null
	for slab: Node3D in slabs: slab.advance(delta)
	for r: Node3D in ropes: r.advance(delta)
	for x: Node in extras: x.before(delta)
	if on == null or motor.rider != null or motor.swimming: return
	if motor.grounded or motor.on_ledge(): motor.carry(on.moved(),on.turn())

## After the motor's step: what he is on, the slabs' weight and blows, his
## leaving pace, the catches.
func after(_delta: float, events: Dictionary) -> void:
	var under := RID()
	var now: Node3D = null
	if motor.rider == null and not motor.swimming:
		if motor.grounded:
			under = _under(motor.feet)
		elif motor.on_ledge():
			under = _under(motor.lip-Vector3(motor.lip_out.x,0.0,motor.lip_out.y)*0.1)
		now = slab_of(under)
	if now != null and events.has("landed"):
		now.land(motor.feet,float(events.landed))
		events["slab"] = true
		counts.slab += 1
	if on != null and now == null and not motor.grounded and not motor.on_ledge() and motor.rider == null and not motor.swimming:
		# Off it: its pace at his feet goes with him.
		var v: Vector3 = on.velocity_at(motor.feet)
		motor.velocity.x += v.x
		motor.velocity.z += v.z
		motor.velocity.y += clampf(v.y,0.0,RISE_KEEP)
	on = now
	if on != null and motor.grounded: on.weigh(motor.feet)
	if motor.rider == null and not motor.swimming:
		for r: Node3D in ropes:
			if r.anchor.distance_to(motor.feet) < NEAR and r.try_catch(motor,_delta):
				events["swing"] = true
				counts.swing += 1
				if motor.move == "tumble":
					# Snagged stunned.
					events["snag"] = true
					counts.snag += 1
				break
	# On a balustrade's coping: only noted.
	var rail: Node3D = null
	if under.is_valid():
		for r: Node3D in rails:
			if r.rid() == under: rail = r
	if rail != on_rail:
		events["rail"] = rail != null
		if rail != null:
			counts.rail += 1
			last_rail_top = 0.0
		on_rail = rail
	if on_rail != null: last_rail_top = maxf(last_rail_top,motor.speed())
	if events.has("rope_jump") or (events.has("swing") and not events.swing):
		last_release = motor.velocity
		if _held != null: last_timing = _held.last_timing
	for x: Node in extras: x.after(_delta,events)

## What is right under `p` (its body's RID), or none.
func _under(p: Vector3) -> RID:
	var space: PhysicsDirectSpaceState3D = study.get_world_3d().direct_space_state
	_ray.from = p+Vector3.UP*0.3
	_ray.to = p-Vector3.UP*0.35
	_ray.collision_mask = study.ground.mask
	var hit := space.intersect_ray(_ray)
	return hit.rid if not hit.is_empty() else RID()

## The drawn body along the rope he hangs from (its hands on the rope),
## eased back upright after letting go.
func pose(figure: Node3D) -> void:
	for x: Node in extras: x.pose(figure)
	for r: Node3D in ropes:
		if r.held():
			_tilt = r.tilt
			_tilt_left = UPRIGHT
			figure.basis = _tilt
			return
	if _tilt_left <= 0.0: return
	_tilt_left = maxf(_tilt_left-get_process_delta_time(),0.0)
	var upright := figure.basis
	figure.basis = upright.slerp(_tilt.orthonormalized(),_tilt_left/UPRIGHT).orthonormalized() if _tilt_left > 0.0 else upright

## The rope he rides now, or null.
func riding() -> Node3D:
	return motor.rider as Node3D if motor != null and motor.rider is Node3D else null
