extends "res://scripts/traps/trap.gd"
## Seesaw Slab (docs/design/roguelike/ideas-traps.md module 2; built to the
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
## counts), `creak_gap` (s between creaks).
const THICK := 0.4
const STONE := Color(0.42,0.41,0.4)
const STUMP := Color(0.5,0.47,0.42)
## The share of a jump height the raised end may rise.
const RISE_OF_JUMP := 0.9
const SPAN_OF_WALK := 2.5

## Tilt about the cross axis: positive raises the far (-z) end.
var tilt := 0.0
var spin := 0.0
var body: StaticBody3D
var stump: MeshInstance3D
var stump_mat: StandardMaterial3D
## RigidBody3Ds resting on it that a launch can fling.
var loads: Array = []
var launches := 0
var last_launch := Vector3.ZERO
var _rider_arm := 0.0
var _riding := false
var _creak_t := 0.0

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
	body = StaticBody3D.new()
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

## Tipped to the longer side when the pivot is off centre.
func rest_tilt() -> float:
	return clampf(float(knob("pivot_offset"))*2.0,-1.0,1.0)*float(knob("max_tilt"))*0.3

## Metres along the slab from the pivot, positive toward the far end.
func arm_of(local: Vector3) -> float:
	return pivot_z()-local.z

func _surface_y(local_z: float) -> float:
	return (local_z-pivot_z())*-tan(tilt)

## Is `feet` (world) on the slab?
func on_slab(feet: Vector3) -> bool:
	var l := to_local(feet)
	return absf(l.x) <= float(knob("width"))*0.5 and l.z <= 0.0 and l.z >= -length() and absf(l.y-_surface_y(l.z)) < 0.35

## The end that is up: +1 far, -1 near, 0 level.
func high_end() -> int:
	return 0 if absf(tilt) < 0.02 else (1 if tilt > 0.0 else -1)

func before(delta: float) -> void:
	if body == null or delta <= 0.0: return
	_riding = motor != null and motor.rider == null and not motor.swimming and (motor.grounded or motor.on_ledge()) and on_slab(motor.feet)
	var half := length()*0.5
	var target := rest_tilt()
	if _riding:
		_rider_arm = arm_of(to_local(motor.feet))
		target = -clampf(_rider_arm/half,-1.0,1.0)*float(knob("max_tilt"))
	var w := 2.2/maxf(float(knob("tip_time")),0.05)
	var zeta := float(knob("bounce"))
	var was := _transform()
	spin += (w*w*(target-tilt)-2.0*zeta*w*spin)*delta
	var cap := float(knob("max_tilt"))*1.15
	tilt = clampf(tilt+spin*delta,-cap,cap)
	_pose()
	if _riding:
		var moved := global_transform*(_transform()*was.affine_inverse())*global_transform.affine_inverse()
		motor.carry(moved,0.0)
		# Down the tilt, toward the low end.
		var down := global_transform.basis*Vector3(0.0,0.0,1.0)*(float(knob("slide"))*sin(tilt)*delta)
		motor.carry(Transform3D(Basis.IDENTITY,down),0.0)
	_creak(delta)
	tell_sight(clampf(absf(spin)/maxf(float(knob("max_tilt"))*w*0.4,0.01),0.0,1.0))

func after(_delta: float, events: Dictionary) -> void:
	if motor == null or not events.has("landed"): return
	if motor.rider != null or not on_slab(motor.feet): return
	var arm := arm_of(to_local(motor.feet))
	var speed := float(events.landed)
	# Hard on the high end: its side was the up one.
	if speed >= float(knob("hard")) and high_end() != 0 and signf(arm) == float(high_end()) and absf(tilt) > float(knob("max_tilt"))*0.25:
		impact(arm,speed)

## A blow of `speed` (m/s) at `arm` m from the pivot (+ far): that side
## goes down hard and whatever stands on the other side is flung.
func impact(arm: float, speed: float) -> void:
	var side := signf(arm)
	if side == 0.0: return
	var half := length()*0.5
	var up := minf(float(knob("launch"))*speed*clampf(absf(arm)/half,0.3,1.0),_launch_cap())
	spin += -side*speed/maxf(half,0.1)
	launches += 1
	# The low end's z direction away from the pivot: +z for the near end.
	var out := global_transform.basis*Vector3(0.0,0.0,side)*(up*0.3)
	last_launch = Vector3(out.x,up,out.z)
	tell_sound(&"creak",to_global(Vector3(0.0,0.0,pivot_z()-arm)))
	# The pilot on the low end.
	if motor != null and motor.rider == null and on_slab(motor.feet):
		var mine := arm_of(to_local(motor.feet))
		if signf(mine) == -side and absf(mine) > 0.3:
			motor.toss(last_launch)
	for r: Variant in loads:
		var rb := r as RigidBody3D
		if rb == null: continue
		if signf(arm_of(to_local(rb.global_position))) == -side:
			rb.apply_central_impulse(Vector3(0.0,up,0.0)*rb.mass)

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
	_creak_t = 0.0
	tilt = rest_tilt()
	if body != null: _pose()
