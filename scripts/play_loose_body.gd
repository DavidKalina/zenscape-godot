extends RigidBody3D
## A small physical prop. The controller owns gestures and character responses;
## the solver owns flight, contact, rolling, and buoyancy.
signal splashed(point: Vector3, strength: float)
signal released()
var kind := "stone"
var radius := 0.22
var reach := 0.22
var home := Transform3D.IDENTITY
var held := false
var paused := false
var parked := false
var launched := false
var skip_count := 0
var water_entries := 0
var hit_cooldown := 0.0
var age_since_release := 0.0
var water_probe: Callable
var _water_cooldown := 0.0
var _wet := false
var visual := MeshInstance3D.new()

func setup(type: String, mesh: Mesh, source_material: Material) -> void:
	kind = type
	parked = kind == "boulder"
	freeze = parked
	mass = {"stone":0.8,"log":8.0,"boulder":48.0}[kind]
	radius = {"stone":0.22,"log":0.38,"boulder":0.8}[kind]
	reach = 1.15 if kind == "log" else radius
	continuous_cd = true
	collision_layer = 1
	collision_mask = 3
	linear_damp = 0.12
	angular_damp = 0.15
	var material := PhysicsMaterial.new()
	material.friction = 0.65
	material.bounce = 0.22 if kind == "stone" else 0.08
	physics_material_override = material
	var shape: Shape3D
	if kind == "log":
		var capsule := CapsuleShape3D.new()
		capsule.radius = radius
		capsule.height = reach*2.0
		shape = capsule
	else:
		var ball := SphereShape3D.new()
		ball.radius = radius
		shape = ball
	var collision := CollisionShape3D.new()
	collision.shape = shape
	if kind == "log": collision.rotation.z = PI*0.5
	add_child(collision)
	visual.mesh = mesh
	var bounds := mesh.get_aabb()
	var size := Vector3(2.3,0.76,0.76) if kind == "log" else Vector3.ONE*radius*2.0
	visual.scale = size/bounds.size
	visual.position = -bounds.get_center()*visual.scale
	visual.material_override = source_material.duplicate()
	add_child(visual)

func set_highlight(enabled: bool) -> void:
	if enabled and visual.material_overlay == null:
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.albedo_color = Color(1.0,0.83,0.4,0.17)
		visual.material_overlay = glow
	elif not enabled: visual.material_overlay = null

func set_paused(value: bool) -> void:
	paused = value
	freeze = paused or held or parked

func grab() -> void:
	parked = false
	held = true
	freeze = true
	collision_layer = 0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	launched = false

func release(velocity: Vector3, strength := 1.0) -> void:
	parked = false
	held = false
	freeze = paused
	collision_layer = 1
	sleeping = false
	linear_velocity = velocity.limit_length({"stone":17.0,"log":11.0,"boulder":6.0}[kind]*clampf(strength,1.0,2.0))
	angular_velocity = Vector3(0.4,0.7,-linear_velocity.x)*0.7
	launched = true
	age_since_release = 0.0
	skip_count = 0
	hit_cooldown = 0.0
	released.emit()

func restore(pose: Transform3D) -> void:
	held = false
	launched = false
	collision_layer = 1
	freeze = paused or parked
	global_transform = pose
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false
	_wet = false
	_water_cooldown = 0.0
	skip_count = 0
	reset_physics_interpolation()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if held or paused: return
	var dt := state.step
	age_since_release += dt
	hit_cooldown = maxf(0.0,hit_cooldown-dt)
	_water_cooldown = maxf(0.0,_water_cooldown-dt)
	var point := state.transform.origin
	var surface: Variant = water_probe.call(point) if water_probe.is_valid() else null
	if surface != null:
		var bottom := point.y-radius
		var entering: bool = bottom<=surface.y and not _wet
		if entering and _water_cooldown<=0.0:
			water_entries += 1
			splashed.emit(surface,0.4 if kind == "stone" else 0.9)
			_water_cooldown = 0.14
			var horizontal := Vector2(state.linear_velocity.x,state.linear_velocity.z).length()
			if kind == "stone" and horizontal>2.4 and state.linear_velocity.y<0.0 and state.linear_velocity.y>-6.0 and skip_count<4:
				skip_count += 1
				var pose := state.transform
				pose.origin.y = surface.y+radius+0.015
				state.transform = pose
				state.linear_velocity = Vector3(state.linear_velocity.x*0.78,1.1+horizontal*0.05,state.linear_velocity.z*0.78)
				_wet = false
				return
		_wet = bottom<surface.y
		if kind == "log" and bottom<surface.y:
			# Two buoyancy points settle the long axis toward the water surface.
			for sign in [-1.0,1.0]:
				var arm: Vector3 = state.transform.basis.x*reach*0.65*sign
				var depth := clampf(surface.y-(point.y+arm.y-radius),0.0,radius*2.0)
				state.apply_force(Vector3.UP*mass*9.8*depth/(radius*1.1),arm)
			state.linear_velocity *= exp(-1.7*dt)
			state.angular_velocity *= exp(-2.6*dt)
		elif _wet:
			state.linear_velocity *= exp(-1.8*dt)
	else: _wet = false
