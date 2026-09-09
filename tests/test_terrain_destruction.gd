extends SceneTree

const Blast = preload("res://scripts/terrain_blast.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var scene = load("res://studies/destruction_playground.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	var heights: PackedFloat32Array = scene.terrain.data.heights.duplicate()
	var meadow: PackedFloat32Array = scene.terrain.data.meadow.duplicate()
	var transforms: Array[Transform3D] = []
	for body in scene.props: transforms.append(body.transform)
	var target: Vector3 = scene.props[0].position
	target.y = scene.terrain.data.height_at(Vector2(target.x, target.z))
	var before: float = scene.terrain.data.height_at(Vector2(target.x, target.z))
	scene.detonate(target, 2.6)
	_check(scene.terrain.data.height_at(Vector2(target.x, target.z)) < before - 0.3, "Blast excavates the ground")
	_check(not scene.props[0].freeze, "Blast releases nearby props")
	_check(scene.debris.size() == 18, "Blast ejects physical fragments")
	_check(Blast.impulse(Vector3.ZERO, Vector3(30, 0, 0), 3) == Vector3.ZERO, "Distant objects receive no impulse")
	_check(Blast.impulse(Vector3.ZERO, Vector3.ZERO, 3).y > 0, "A direct hit launches upward")
	await physics_frame
	await physics_frame
	_check(scene.props[0].linear_velocity.length() > 1, "Released prop actually moves")
	# Picking and physics both see the rebuilt crater surface.
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(target + Vector3.UP * 15, target + Vector3.DOWN * 15, 1))
	_check(not hit.is_empty(), "Ground collider remains raycastable")
	if not hit.is_empty():
		_check(absf(hit.position.y - scene.terrain.data.height_at(Vector2(target.x, target.z))) < 0.02, "Collision matches deformed terrain")
	for i in range(7): scene.detonate(target, 4.5)
	_check(scene.debris.size() <= scene.MAX_DEBRIS, "Repeated explosions bound debris count")
	for height in scene.terrain.data.heights:
		_check(height >= LandscapeData.MIN_HEIGHT, "Repeated blasts respect the terrain floor")
	scene.plant_charge(target, 2)
	scene.reset_world()
	await physics_frame
	_check(scene.terrain.data.heights == heights, "Reset restores every original height")
	_check(scene.terrain.data.meadow == meadow, "Reset restores original grass")
	_check(scene.charges.is_empty() and scene.debris.is_empty(), "Reset removes explosives and fragments")
	_check(scene.effects.get_child_count() == 0, "Reset removes transient effects")
	for i in range(transforms.size()):
		_check(scene.props[i].transform == transforms[i] and scene.props[i].freeze, "Reset restores prop pose and anchored state")
	for i in range(20): scene.plant_charge(target, 1.3)
	_check(scene.charges.size() == scene.MAX_CHARGES, "Charges are bounded")
	scene.pending_reset = true
	scene.pending_detonation = true
	scene.pending_point = {"point": target, "radius": 3.0}
	await physics_frame
	await physics_frame
	_check(scene.blast_count == 0 and scene.terrain.data.heights == heights, "Reset cancels pending blasts")
	scene.queue_free()
	await process_frame
	# Let the audio mixer retire stopped WAV playbacks before shutting down.
	await create_timer(0.2).timeout
	if failures == 0: print("PASS: terrain destruction, physics, bounds, and exact reset")
	quit(1 if failures else 0)
