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
## balustrade's coping, false off it), "spring_coil" (slammed onto a
## springing slab: its spring coiled, the point) and "spring_launch" (its
## release threw him: the point, his rise m/s). `pose` tilts the drawn body along a
## rope he swings on, and eases it back upright over UPRIGHT s after.
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const FootSlab = preload("res://scripts/interactables/foot_slab.gd")
const BobSlab = preload("res://scripts/interactables/bob_slab.gd")
const DriftSlab = preload("res://scripts/interactables/drift_slab.gd")
const SinkSlab = preload("res://scripts/interactables/sink_slab.gd")
const SwingRope = preload("res://scripts/interactables/swing_rope.gd")
const Balustrade = preload("res://scripts/interactables/balustrade.gd")
const AirRing = preload("res://scripts/interactables/air_ring.gd")

## The most of a slab's rise kept leaving it (m/s), and the seconds the
## body takes to stand upright off a rope.
const RISE_KEEP := 3.0
const UPRIGHT := 0.25
## The spring (foot_slab.gd): a slam's touch landing on a springing slab
## coils it; let go with him still on it, he is launched (PilotMotor
## `launch`) the slab's SPRING_PUMPS of his pump high, his flat pace kept,
## the height forgiven by the fall stun on the way down.
## Pieces this far from him (m) are still stepped but skip their catch.
const NEAR := 30.0

var study: Node3D
var motor: PilotMotor
var slabs: Array = []
var ropes: Array = []
var rails: Array = []
## The air rings (scripts/interactables/air_ring.gd): passed through, the
## updraft's charge filled and its air chain started afresh (its `refill`),
## and he is thrown the ring's POP m along its axis as a spring launch
## throws him (`_take_ring`; the drop under him forgiven by the fall stun). The step gets "air_ring"
## (the ring's middle); `rings_taken` counts them.
var rings: Array = []
var rings_taken := 0
## Bounces off the rings' tops (the trampoline, AirRing `try_bounce`): each
## refills the charge and throws him AirRing.BOUNCE up; the step gets
## "ring_bounce" ({at, hard}).
var ring_bounces := 0
## The last ring's throw: {at, way, from (his velocity), to}.
var last_throw := {}
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
## Counted: spring launches, and the last one's rise (m/s) and height (m).
var launches := 0
var last_launch := {}
## Events from `before` (a launch) for the step's, given in `after`.
var _pending := {}

func _init() -> void:
	name = "FootPieces"

## Handles (AGENTS.md: placement code names its pieces). While `naming`
## holds a route's name, every piece a placer below makes is named
## `<route>/<kind>_<n>` (n counted per kind from 1, in placing order) or
## the one name `call_next` gave, through scripts/layout_overrides.gd: the
## layout file's move wins over the coded spot, a deleted name is taken
## away, and the world view (scripts/layout_edit.gd) can pick and move it.
## "" (the default) names nothing, for placers that name their own.
const Layout = preload("res://scripts/layout_overrides.gd")
var naming := ""
var _counts := {}
var _next := ""

## The routes's name the next pieces are placed under ("" none).
func name_under(route: String) -> void:
	naming = route

## The next piece placed is called `called` (under the route) instead of
## by its count.
func call_next(called: String) -> void:
	_next = called

## `node` (just placed, coded at `coded`) named and stood as the layout
## file has it; true if the file deleted it (it is freed: the caller may
## still dress it this frame).
func _handle(node: Node3D, kind: String, coded: Transform3D, extra := {}) -> bool:
	if naming == "":
		_next = ""
		return false
	var called := _next
	_next = ""
	if called == "":
		var counted := naming+"/"+kind
		_counts[counted] = int(_counts.get(counted,0))+1
		called = "%s_%d" % [kind,int(_counts[counted])]
	var key := naming+"/"+called
	if Layout.deleted(key):
		_drop(node)
		return true
	var t := Layout.xform(key,coded)
	var e := {"host":self}
	e.merge(extra)
	Layout.track(key,node,kind,coded,e)
	if not t.is_equal_approx(coded): Layout.apply(key,t)
	return false

## A piece taken out of the step lists and freed.
func _drop(node: Node3D) -> void:
	slabs.erase(node)
	ropes.erase(node)
	rails.erase(node)
	rings.erase(node)
	if on == node: on = null
	if motor != null and motor.rider == node: motor.toss(motor.velocity)
	node.queue_free()

## Floating stones (the aqueduct isle's look, Art.floating_stones) as one
## named piece (kind "stones"): a perch, a marker, a beam. Coded at the
## first stone's foot.
func stones(seed_value: int, list: Array, node_name := "Stones") -> Node3D:
	var s := FootSlab.Art.floating_stones(seed_value,list)
	s.name = node_name
	add_child(s)
	var at: Vector3 = (list[0] as Dictionary).at if not list.is_empty() else Vector3.ZERO
	_handle(s,"stones",Transform3D(Basis.IDENTITY,at))
	return s

## Hooked into `scene` (a character study): stepped by its frame.
func attach(scene: Node3D) -> void:
	study = scene
	motor = scene.motor
	scene.foot_pieces = self

func bob_slab(at: Vector3, size := Vector3(2.4,0.7,2.2), yaw := 0.0, seed_value := 0) -> Node3D:
	var slab: Node3D = BobSlab.new()
	slab.setup(Transform3D(Basis(Vector3.UP,yaw),at),size,seed_value)
	_add_slab(slab)
	_handle(slab,"bob_slab",Transform3D(Basis(Vector3.UP,yaw),at),{"pumps":float(slab.spring_pumps)})
	return slab

## A slab that sinks while he stands on it (scripts/interactables/
## sink_slab.gd).
func sink_slab(at: Vector3, size := Vector3(2.4,0.7,2.2), yaw := 0.0, seed_value := 0) -> Node3D:
	var slab: Node3D = SinkSlab.new()
	slab.setup(Transform3D(Basis(Vector3.UP,yaw),at),size,seed_value)
	_add_slab(slab)
	_handle(slab,"sink_slab",Transform3D(Basis(Vector3.UP,yaw),at))
	return slab

## A drifting slab along `points` (see scripts/interactables/drift_slab.gd).
func drift_slab(points: PackedVector3Array, period: float, loop := false, spin := 0.0, size := Vector3(2.4,0.6,2.0), yaw := 0.0, seed_value := 0, start := 0.0) -> Node3D:
	var slab: Node3D = DriftSlab.new()
	slab.setup(Transform3D(Basis(Vector3.UP,yaw),points[0]),size,seed_value)
	slab.drift(points,period,loop,spin,yaw,start)
	_add_slab(slab)
	_handle(slab,"drift_slab",slab.layout_pose())
	return slab

func rope(anchor: Vector3, length: float) -> Node3D:
	var r: Node3D = SwingRope.new()
	r.setup(anchor,length)
	add_child(r)
	ropes.append(r)
	_handle(r,"rope",Transform3D(Basis.IDENTITY,anchor))
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
	_handle(r,"balustrade",Transform3D(Basis.IDENTITY,(points[0]+points[points.size()-1])*0.5))
	return r

## An air ring lying flat at `at` (its middle), turned `yaw`, tipped `tip`
## (rad about its own x) if given; `radius` its size (m, AirRing.RADIUS).
func air_ring(at: Vector3, seed_value := 0, yaw := 0.0, tip := 0.0, radius := AirRing.RADIUS) -> Node3D:
	var r: Node3D = AirRing.new()
	r.setup(Transform3D(Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,tip),at),seed_value,radius)
	add_child(r)
	rings.append(r)
	_handle(r,"air_ring",Transform3D(Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,tip),at))
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
	var sprang: Node3D = null
	for slab: Node3D in slabs:
		slab.advance(delta)
		if slab.sprung(): sprang = slab
	for r: Node3D in ropes: r.advance(delta)
	for r: Node3D in rings: r.advance(delta)
	if on == null or motor.rider != null or motor.swimming: return
	if motor.grounded or motor.on_ledge(): motor.carry(on.moved(),on.turn())
	if sprang == on and motor.grounded and motor.move != "tumble": _launch(on)

## Thrown up off `slab`'s spring (see SPRING above).
func _launch(slab: Node3D) -> void:
	var height: float = slab.spring_pumps*float(motor.jumps[motor.jumps.size()-1])
	var up := motor.rise_for(height,true)
	motor.launch(Vector3(motor.velocity.x,up,motor.velocity.z),height)
	launches += 1
	last_launch = {"at":motor.feet,"rise":up,"height":height}
	_pending["spring_launch"] = last_launch
	on = null

## Through an air ring: the charge filled, thrown along its axis (AirRing
## `throw_way`: the half away from the ground) at the pop's pace (the pace
## that would rise POP m straight up), his pace across the axis kept and
## his pace along it kept if faster; his rise at least LIFT of POP's. A flat
## ring is the old straight pop up, his flat pace kept (see `rings`).
func _take_ring(r: Node3D) -> void:
	rings_taken += 1
	var drafts: Node = study.get("updraft")
	if drafts != null and drafts.has_method("refill"): drafts.refill(r.middle())
	var pop: float = float(r.pop)*motor.size
	var pace := motor.rise_for(pop,true)
	var way: Vector3 = r.throw_way(motor.velocity)
	var v: Vector3 = motor.velocity
	var along := v.dot(way)
	v += way*maxf(pace-along,0.0)
	v.y = maxf(v.y,motor.rise_for(pop*AirRing.LIFT,true))
	last_throw = {"at":r.middle(),"way":way,"from":motor.velocity,"to":v}
	var free := pop+_drop_under(motor.feet)+0.5
	motor.launch(v,free)
	on = null

## Down onto an air ring's stones: the charge filled, thrown BOUNCE m back
## up off its top (SLAM_BOUNCE m from a slam), his flat pace kept (see
## `rings`).
## `snap`: his feet set on its top (not when he fell back down inside it).
func _bounce_ring(r: Node3D, slammed := false, snap := true) -> void:
	ring_bounces += 1
	var drafts: Node = study.get("updraft")
	if drafts != null and drafts.has_method("refill"): drafts.refill(motor.feet)
	var top: float = r.top_at(motor.feet)
	if snap and motor.feet.y < top: motor.feet.y = top
	var h: float = (AirRing.SLAM_BOUNCE if slammed else AirRing.BOUNCE)*motor.size
	var up := motor.rise_for(h,true)
	motor.launch(Vector3(motor.velocity.x,up,motor.velocity.z),h+_drop_under(motor.feet)+0.5)
	on = null

## The drop from `p` to what is under it (m), or a long way if nothing is.
func _drop_under(p: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = study.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p,p-Vector3.UP*400.0,study.ground.mask)
	var hit := space.intersect_ray(q)
	return p.y-(hit.position as Vector3).y if not hit.is_empty() else 400.0

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
	events.merge(_pending)
	_pending = {}
	if now != null and events.has("landed"):
		now.land(motor.feet,float(events.landed))
		events["slab"] = true
		counts.slab += 1
		if events.has("slam") and now.coil(motor.feet): events["spring_coil"] = motor.feet
	if on != null and now == null and not motor.grounded and not motor.on_ledge() and motor.rider == null and not motor.swimming:
		# Off it: its pace at his feet goes with him.
		var v: Vector3 = on.velocity_at(motor.feet)
		motor.velocity.x += v.x
		motor.velocity.z += v.z
		motor.velocity.y += clampf(v.y,0.0,RISE_KEEP)
	on = now
	if on != null and motor.grounded: on.weigh(motor.feet)
	if motor.rider == null and not motor.swimming and not motor.rope_on:
		# A load in his hands (motor.rope_on off): a rope met is refused.
		for r: Node3D in ropes:
			if r.anchor.distance_to(motor.feet) < NEAR and r.would_catch(motor): motor.refuse("rope")
	elif motor.rider == null and not motor.swimming:
		for r: Node3D in ropes:
			if r.anchor.distance_to(motor.feet) < NEAR and r.try_catch(motor,_delta):
				events["swing"] = true
				counts.swing += 1
				if motor.move == "tumble":
					# Snagged stunned.
					events["snag"] = true
					counts.snag += 1
				break
	if motor.rider == null and not motor.swimming and motor.move != "tumble":
		var chest: Vector3 = motor.feet+Vector3.UP*AirRing.CHEST*motor.size
		var took := false
		for r: Node3D in rings:
			if r.middle().distance_to(chest) < NEAR and r.try_take(chest,motor.size):
				_take_ring(r)
				events["air_ring"] = r.middle()
				took = true
				break
		# Down onto a ring's stones: the trampoline (every time).
		for r: Node3D in rings:
			if r.middle().distance_to(motor.feet) >= NEAR: continue
			var fell: bool = r.fell_in
			r.fell_in = false
			if r.try_bounce(motor.feet,motor.velocity,motor.size):
				fell = false
			elif fell: r.flex_hit(motor.velocity)
			else: continue
			if not took and not motor.grounded:
				var slammed := motor.move == "slam"
				events["ring_bounce"] = {"at":r.middle(),"hard":-motor.velocity.y,"slam":slammed}
				_bounce_ring(r,slammed,not fell)
				took = true
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
