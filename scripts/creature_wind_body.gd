class_name CreatureWindBody
extends RigidBody3D
## One opt-in collision proxy. Forces are Newtons, wind velocity metres/second.
## Applying above the centre of mass produces real torque through the solver.
var field: Node
var active := false
var blast_flight := false
const CENTER_HEIGHT := 1.15

func _ready() -> void:
	mass = 32.0
	linear_damp = 1.1
	angular_damp = 1.8
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 8
	var material := PhysicsMaterial.new()
	material.friction = 0.85
	material.bounce = 0.03
	physics_material_override = material
	var shape := CapsuleShape3D.new()
	shape.radius = 0.5
	shape.height = 2.3
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	stop()

func start(feet: Transform3D) -> void:
	global_transform = Transform3D(feet.basis,feet.origin+feet.basis*Vector3.UP*CENTER_HEIGHT)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	collision_layer = 2
	# Terrain and props, plus flying blast debris (layer 4) so a tumbling
	# resident keeps getting hit instead of passing through the rockfall.
	collision_mask = 1|4
	freeze = false
	sleeping = false
	active = true
	reset_physics_interpolation()

func stop() -> void:
	blast_flight = false
	linear_damp = 1.1
	active = false
	freeze = true
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

func feet_transform() -> Transform3D:
	var pose := get_global_transform_interpolated()
	return Transform3D(pose.basis,pose.origin-pose.basis*Vector3.UP*CENTER_HEIGHT)

func _integrate_forces(body_state: PhysicsDirectBodyState3D) -> void:
	if not active or not is_instance_valid(field): return
	var wind: Vector3 = field.sample(body_state.transform.origin)
	var relative := wind-body_state.linear_velocity
	# Quadratic aerodynamic drag. Clamp extreme input without limiting normal gusts.
	var force := (relative*relative.length()*(0.12 if blast_flight else 2.0)).limit_length(2600.0)
	body_state.apply_force(force,body_state.transform.basis*Vector3.UP*0.70)
