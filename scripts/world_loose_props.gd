extends "res://scripts/play_loose_props.gd"
var exchange: Node

func setup(owner_scene: Node) -> void:
	scene = owner_scene
	exchange = scene.get("exchange")

func register(body: RigidBody3D) -> void:
	bodies.append(body)
	_previous[body] = body.global_position
	body.water_probe = scene.water_play.surface_at
	body.splashed.connect(scene.water_play.splash)
	body.released.connect(func() -> void:
		_previous[body] = body.global_position
		_investigated.erase(body))

func held_at(mouse: Vector2) -> bool:
	if exchange == null: return false
	var body: RigidBody3D = exchange.held
	if not is_instance_valid(body) or scene._over_controls(mouse): return false
	var origin: Vector3 = scene.camera.project_ray_origin(mouse)
	var direction: Vector3 = scene.camera.project_ray_normal(mouse)
	var inverse: Transform3D = body.visual.global_transform.affine_inverse()
	var local_hit: Variant = body.visual.mesh.get_aabb().intersects_ray(inverse*origin,(inverse.basis*direction).normalized())
	if local_hit == null: return false
	var distance := origin.distance_to(body.visual.global_transform*local_hit)
	var ground: Variant = scene._ground_at(mouse)
	if ground != null and origin.distance_to(ground)<distance: return false
	var obstruction := super.pick(mouse)
	return obstruction == null or origin.distance_to(obstruction.global_position)-obstruction.reach>=distance

func pick(mouse: Vector2) -> RigidBody3D:
	if held_at(mouse): return exchange.held
	return super.pick(mouse)

func hover(_mouse: Vector2) -> void:
	# Hover must not allocate physics bodies for everything the cursor passes.
	pass

func _contact(body: RigidBody3D, previous: Vector3) -> void:
	if scene.owner_scene.resident_enabled and scene.creature.visible: super._contact(body,previous)

func _anticipate(body: RigidBody3D) -> void:
	if scene.owner_scene.resident_enabled and scene.creature.visible: super._anticipate(body)

func begin_grab(body: RigidBody3D, mouse: Vector2) -> void:
	if scene._paused or scene.gust_tool or scene._carrying or body not in bodies: return
	if exchange != null: exchange.cancel("player took the object")
	super.begin_grab(body,mouse)
	if exchange != null and exchange.accepts(body):
		scene._show_reaction("?","Hold near Bigfoot to offer · Scroll to raise or lower")

## Atomic ownership transfer: do not release/regrab or retain throw samples.
func take_offered(body: RigidBody3D) -> RigidBody3D:
	if grabbed != body or not body.held: return null
	grabbed = null
	_samples.clear()
	return body

func adjust_height(amount: float, mouse: Vector2) -> void:
	if grabbed == null or scene._over_controls(mouse): return
	var ground: Variant = scene._probe_ground(grabbed.global_position)
	if ground == null: return
	_plane.d = clampf(_plane.d+amount,ground.y+grabbed.radius+0.1,ground.y+3.6)
	move_grab(mouse)
