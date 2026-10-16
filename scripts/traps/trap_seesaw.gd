extends "res://scripts/traps/trap.gd"
## Seesaw Slab (built to the
## contract in scripts/traps/trap.gd): a long stone slab on a central pivot
## spanning the gap between two ledges, route along -z. The pilot's weight
## tips it toward his side, more the further he is from the pivot (the tilt
## chases a target of -arm/half x `max_tilt`, a spring of `tip_time` seconds
## and `bounce` damping, so a quick run is across before it is done and a
## slow crossing is pitched or slid along). While tilted it slides what
## stands on it toward the low end (`slide`, m/s at full tilt: the friction
## feel). He is carried with it as foot_pieces.gd carries a slab
## (`motor.carry`).
##
## The launch: land hard (`hard`, m/s of fall) on the high end and the low
## end flings: what stands on the low end (the pilot, or a RigidBody3D in
## `loads`) is thrown up `launch` x the fall pace, capped, and a little
## away from the pivot. `impact(arm, speed)` is the same blow from anything
## else (a thrown stone, a rolling drum).
##
## The tell: the pivot stump is greybox grey and warms to orange as the slab
## moves; a `creak` sound (tell_sound) while it tips. Cost 3 over a drop.
##
## Knobs: `length` (m, the span), `width`, `pivot_offset` (share of length
## the pivot sits toward the far end, 0 centred; off-centre it rests tipped
## to the longer side), `max_tilt` (rad), `tip_time` (s the tilt takes: its
## inertia), `bounce` (damping ratio; under 1 it overshoots), `slide`
## (m/s down the tilt), `launch` (x fall pace), `hard` (m/s fall that
## counts), `creak_gap` (s between creaks), `grip` (friction of the slab and
## its blocks: 0.5 holds a block at full tilt, under tan(max_tilt) = 0.25 it
## slides down the tilt).
##
## Weight (round 2b): the tilt is a balance of moments, the pilot's
## `pilot_mass` x his arm plus each load's mass x its arm over the slab
## (`pilot_mass` x half length), so a heavy block on one end keeps that end
## down and the pilot alone on the other end cannot lift it. A blow flings a
## load by the blow's pace x `launch` (capped `load_cap` x the pilot's own
## cap) x 2 pilot/(pilot+load) mass: a plain landing barely moves a heavy
## block, a slam (the motor's "slammed" event, 20+ m/s against a jump's 6)
## sends it far. A load goes up at v, and `load_along` x (v less `shove`, a first jump's takeoff: a hop goes nowhere) along (the pilot `along` x up) toward its own end's
## outside (z), `veer` x that sideways (+x). `cap_mul` scales the pilot's
## own launch cap (a heavy drop kicks harder than a jump).
## `drop_hit(block, fall)` is a falling block's blow, momentum-scaled.
##
## Physics (the fix of 2026-10-12, "Blocks fell
## through"): the slab is an AnimatableBody3D, its tilt stepped and posed in
## `_physics_process`, once per physics step, so Jolt moves it kinematically
## and what rests on it gets the deck's real contact velocity. The pilot (a
## kinematic motor stepped per frame in `before`) is carried by how far the
## slab moved since his last frame. A throw is an impulse on the load at the
## blow; the load is never excused from colliding with the slab. Blocks are
## RigidBody3Ds with continuous collision, gripping the slab with `grip`
## (friction: they slide down a tilt steeper than atan(grip)).
const THICK := 0.4
const STONE := Color(0.42,0.41,0.4)
const STUMP := Color(0.5,0.47,0.42)
## The share of a jump height the raised end may rise.
const RISE_OF_JUMP := 0.9
const SPAN_OF_WALK := 2.5
## Most a blow spins the slab (rad/s): its rising tip (x half the length, 3.6
## m/s on 6 m) stays slower than a slam's throw, so the throw, not the
## deck's shove, sends a load, and a plain landing only nudges it.
const SPIN_KICK := 1.2

## Tilt about the cross axis: positive raises the far (-z) end.
var tilt := 0.0
var spin := 0.0
var body: AnimatableBody3D
var stump: MeshInstance3D
var stump_mat: StandardMaterial3D
## RigidBody3Ds resting on it that a launch can fling.
var loads: Array = []
var launches := 0
var last_launch := Vector3.ZERO
var _rider_arm := 0.0
var _riding := false
var _creak_t := 0.0
## Loads' (RigidBody3D) glow materials, by instance id.
var _glow: Dictionary = {}
## The slab's pose the pilot was last carried from (local to the trap).
var _carried := Transform3D.IDENTITY

func _init() -> void:
	super()
	trap_name = "seesaw"
	cost = 3
	under = "layer"
	verbs = PackedStringArray(["run","jump"])

func defaults() -> Dictionary:
	var p := pilot()
	var span := p.walk*SPAN_OF_WALK
	var rise: float = p.jumps[0]*RISE_OF_JUMP
	return {
		"length":span,"width":p.run*0.5,"pivot_offset":0.0,
		"max_tilt":asin(clampf(rise/(span*0.5),0.0,0.9)),"tip_time":0.8,"bounce":0.55,
		"slide":p.run*0.5,"launch":1.1,"hard":sqrt(2.0*p.gravity*p.jumps[0]*0.5),"creak_gap":0.45,
		"pilot_mass":80.0,"load_cap":2.2,"cap_mul":1.0,"along":0.3,"load_along":1.6,"shove":sqrt(2.0*p.gravity*p.jumps[0]),"veer":0.0,
		"grip":0.5,
	}

func length() -> float:
	return float(knob("length"))

func footprint() -> Rect2:
	var w := float(knob("width"))
	return Rect2(-w*0.5,-length(),w,length())

## The pivot's z (local).
func pivot_z() -> float:
	return -length()*(0.5+float(knob("pivot_offset")))

func build() -> void:
	var wide := float(knob("width"))
	body = AnimatableBody3D.new()
	# Posed in _physics_process; Jolt moves it kinematically from there.
	body.sync_to_physics = false
	var pm := PhysicsMaterial.new()
	pm.friction = float(knob("grip"))
	pm.bounce = 0.0
	body.physics_material_override = pm
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(wide,THICK,length()-0.1)
	shape.shape = box
	shape.position = Vector3(0.0,-THICK*0.5,-length()*0.5)
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box.size
	mesh.mesh = bm
	mesh.position = shape.position
	mesh.material_override = paint(STONE)
	body.add_child(mesh)
	# The stump: an axle-like drum across, under the slab.
	stump = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = wide*0.2
	cyl.bottom_radius = wide*0.2
	cyl.height = wide+0.6
	stump.mesh = cyl
	stump_mat = paint(STUMP)
	stump.material_override = stump_mat
	stump.position = Vector3(0.0,-THICK-wide*0.2,pivot_z())
	stump.rotation.z = PI*0.5
	add_child(stump)
	tilt = rest_tilt()
	_pose()
	_carried = body.transform

## Tipped to the longer side when the pivot is off centre.
func rest_tilt() -> float:
	return clampf(float(knob("pivot_offset"))*2.0,-1.0,1.0)*float(knob("max_tilt"))*0.3

## Metres along the slab from the pivot, positive toward the far end.
func arm_of(local: Vector3) -> float:
	return pivot_z()-local.z

func _surface_y(local_z: float) -> float:
	return (local_z-pivot_z())*-tan(tilt)

## Is `feet` (world) on the slab (as it stands, or as posed at `pose`, local)?
func on_slab(feet: Vector3, pose: Variant = null) -> bool:
	if body == null: return false
	var l: Vector3 = ((pose if pose != null else body.transform) as Transform3D).affine_inverse()*to_local(feet)
	return absf(l.x) <= float(knob("width"))*0.5 and l.z <= 0.0 and l.z >= -length() and absf(l.y) < 0.35

## The end that is up: +1 far, -1 near, 0 level.
func high_end() -> int:
	return 0 if absf(tilt) < 0.02 else (1 if tilt > 0.0 else -1)

## The pilot's frame: is he on the slab (his weight counts from the next
## physics step), and carried by how far the slab moved since his last frame
## and slid down its tilt.
func before(delta: float) -> void:
	if body == null or delta <= 0.0: return
	# Where he stood when he last stepped: on the slab as it was then.
	_riding = motor != null and motor.rider == null and not motor.swimming and (motor.grounded or motor.on_ledge()) and on_slab(motor.feet,_carried)
	if _riding:
		_rider_arm = arm_of(to_local(motor.feet))
		var moved := global_transform*(body.transform*_carried.affine_inverse())*global_transform.affine_inverse()
		motor.carry(moved,0.0)
		# Down the tilt, toward the low end.
		var down := global_transform.basis*Vector3(0.0,0.0,1.0)*(float(knob("slide"))*sin(tilt)*delta)
		motor.carry(Transform3D(Basis.IDENTITY,down),0.0)
	_carried = body.transform
	_prime_glow()

## The slab, once per physics step: the balance of moments sets the tilt it
## chases, the spring moves it there, and the body is posed so Jolt moves it
## (kinematically: what rests on it rides it).
func _physics_process(delta: float) -> void:
	if body == null or delta <= 0.0: return
	var half := length()*0.5
	var target := rest_tilt()
	var moment := 0.0
	var weighed := false
	if _riding:
		moment += float(knob("pilot_mass"))*_rider_arm
		weighed = true
	for r: Variant in loads:
		var rb := r as RigidBody3D
		if rb != null and load_on(rb):
			moment += rb.mass*arm_of(to_local(rb.global_position))
			weighed = true
	if weighed:
		target = -clampf(moment/(float(knob("pilot_mass"))*half),-1.0,1.0)*float(knob("max_tilt"))
	var w := 2.2/maxf(float(knob("tip_time")),0.05)
	var zeta := float(knob("bounce"))
	spin += (w*w*(target-tilt)-2.0*zeta*w*spin)*delta
	var cap := float(knob("max_tilt"))*1.15
	var next := tilt+spin*delta
	tilt = clampf(next,-cap,cap)
	# At a stop the slab stops (a spin pushing past it is spent).
	if tilt != next: spin = 0.0
	_pose()
	_creak(delta)
	tell_sight(clampf(absf(spin)/maxf(float(knob("max_tilt"))*w*0.4,0.01),0.0,1.0))

func after(_delta: float, events: Dictionary) -> void:
	if motor == null or not events.has("landed"): return
	if motor.rider != null or not on_slab(motor.feet): return
	var arm := arm_of(to_local(motor.feet))
	var speed := float(events.get("slammed",events.landed))
	# Hard on the high end: its side was the up one.
	if speed >= float(knob("hard")) and high_end() != 0 and signf(arm) == float(high_end()) and absf(tilt) > float(knob("max_tilt"))*0.25:
		impact(arm,speed)

## Is the load `rb` resting on the slab (over it, near its surface)?
func load_on(rb: RigidBody3D) -> bool:
	var l := to_local(rb.global_position)
	return absf(l.x) <= float(knob("width"))*0.5+0.3 and l.z <= 0.0 and l.z >= -length() and l.y-_surface_y(l.z) < 1.6 and l.y-_surface_y(l.z) > -0.5

## Is a load held down on the low end, the high end up (a slam would fling it)?
func primed() -> float:
	if absf(tilt) < float(knob("max_tilt"))*0.25: return 0.0
	for r: Variant in loads:
		var rb := r as RigidBody3D
		if rb != null and load_on(rb) and signf(arm_of(to_local(rb.global_position))) == -float(high_end()):
			return clampf(absf(tilt)/float(knob("max_tilt")),0.0,1.0)
	return 0.0

func _prime_glow() -> void:
	var amount := primed()
	for r: Variant in loads:
		var rb := r as RigidBody3D
		if rb == null: continue
		for c in rb.get_children():
			var mi := c as MeshInstance3D
			if mi != null and mi.material_override is StandardMaterial3D:
				var m := mi.material_override as StandardMaterial3D
				if not _glow.has(m): _glow[m] = m.albedo_color
				m.albedo_color = (_glow[m] as Color).lerp(TELL,amount*0.7)

## A falling block (`rb`, RigidBody3D) hit the slab at `fall` m/s: the blow
## of its momentum against the pilot's (heavy ones always launch).
func drop_hit(rb: RigidBody3D, fall: float) -> void:
	var arm := arm_of(to_local(rb.global_position))
	impact(arm,fall*rb.mass/float(knob("pilot_mass")))

## A blow of `speed` (m/s, as the pilot's own landing) at `arm` m from the
## pivot (+ far): that side goes down hard and whatever stands on the other
## side is flung.
func impact(arm: float, speed: float) -> void:
	var side := signf(arm)
	if side == 0.0: return
	var half := length()*0.5
	var share := clampf(absf(arm)/half,0.3,1.0)
	var pull := float(knob("launch"))*speed*share
	var up := minf(pull,_launch_cap()*float(knob("cap_mul")))
	spin += -side*minf(speed/maxf(half,0.1),SPIN_KICK)
	launches += 1
	var way := global_transform.basis*Vector3(0.0,0.0,side)
	var out := way*(up*float(knob("along")))+global_transform.basis*Vector3(float(knob("veer"))*up,0.0,0.0)
	last_launch = Vector3(out.x,up,out.z)
	tell_sound(&"thunk",to_global(Vector3(0.0,0.0,pivot_z()-arm)))
	tell_sound(&"creak",to_global(Vector3(0.0,0.0,pivot_z()-arm)))
	# The pilot on the low end.
	if motor != null and motor.rider == null and on_slab(motor.feet):
		var mine := arm_of(to_local(motor.feet))
		if signf(mine) == -side and absf(mine) > 0.3:
			motor.toss(last_launch)
	var mp := float(knob("pilot_mass"))
	for r: Variant in loads:
		var rb := r as RigidBody3D
		if rb == null: continue
		var there := arm_of(to_local(rb.global_position))
		if signf(there) == -side:
			# Up and along its own end's outside, lighter flies faster.
			var v := minf(pull,_launch_cap()*float(knob("load_cap")))*2.0*mp/(mp+rb.mass)
			var dir := global_transform.basis*Vector3(float(knob("veer")),0.0,side)
			# Thrown now: the deck under it rises slower than this (SPIN_KICK).
			rb.sleeping = false
			rb.apply_central_impulse((Vector3(0.0,v,0.0)+dir*(maxf(v-float(knob("shove")),0.0)*float(knob("load_along"))))*rb.mass)

## A heavy greybox block (RigidBody3D) of `mass`, `side` m a side, falling
## and flung at the pilot's own gravity; its glow material is its mesh's.
func make_block(mass: float, side: float, colour: Color) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.mass = mass
	rb.gravity_scale = pilot().gravity/float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	rb.set_meta("half",side*0.5)
	rb.contact_monitor = true
	rb.max_contacts_reported = 6
	# A flung block crosses its own size in a step or two: no tunnelling.
	rb.continuous_cd = true
	var pm := PhysicsMaterial.new()
	pm.friction = float(knob("grip"))
	pm.bounce = 0.0
	rb.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE*side
	cs.shape = box
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box.size
	mi.mesh = bm
	mi.material_override = paint(colour)
	rb.add_child(mi)
	return rb

func _launch_cap() -> float:
	var p := pilot()
	return sqrt(2.0*p.gravity*p.jumps[1]*1.5)

func _transform() -> Transform3D:
	var pv := Vector3(0.0,0.0,pivot_z())
	return Transform3D(Basis.IDENTITY,pv)*Transform3D(Basis(Vector3.RIGHT,tilt),Vector3.ZERO)*Transform3D(Basis.IDENTITY,-pv)

func _pose() -> void:
	body.transform = _transform()

func _creak(delta: float) -> void:
	_creak_t -= delta
	if absf(spin) > 0.25 and _creak_t <= 0.0:
		_creak_t = float(knob("creak_gap"))
		tell_sound(&"creak",to_global(Vector3(0.0,0.0,pivot_z())))

func tell_sight(amount: float) -> void:
	if stump_mat != null: stump_mat.albedo_color = STUMP.lerp(TELL,amount)

func reset() -> void:
	super()
	spin = 0.0
	launches = 0
	for m: Variant in _glow: (m as StandardMaterial3D).albedo_color = _glow[m]
	_glow.clear()
	_creak_t = 0.0
	tilt = rest_tilt()
	teleport()

## The slab set to `tilt` at once (a reset, not a swing).
func teleport() -> void:
	if body == null: return
	_pose()
	_carried = body.transform
