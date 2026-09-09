extends "res://scripts/play_loose_props.gd"

func setup(owner_scene: Node) -> void:
	scene = owner_scene

func register(body: RigidBody3D) -> void:
	bodies.append(body)
	_previous[body] = body.global_position
	body.water_probe = scene.water_play.surface_at
	body.splashed.connect(scene.water_play.splash)
	body.released.connect(func() -> void:
		_previous[body] = body.global_position
		_investigated.erase(body))

func pick(mouse: Vector2) -> RigidBody3D:
	return super.pick(mouse)

func hover(_mouse: Vector2) -> void:
	# Hover must not allocate physics bodies for everything the cursor passes.
	pass

func _contact(body: RigidBody3D, previous: Vector3) -> void:
	if scene.owner_scene.resident_enabled and scene.creature.visible: super._contact(body,previous)

func _anticipate(body: RigidBody3D) -> void:
	if scene.owner_scene.resident_enabled and scene.creature.visible: super._anticipate(body)
