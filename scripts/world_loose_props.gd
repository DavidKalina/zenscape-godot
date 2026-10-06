extends "res://scripts/play_loose_props.gd"
## The world's own stones, logs and boulders, promoted to bodies when touched
## (scripts/diorama_world_play.gd `promote`).

func setup(owner_scene: Node) -> void:
	scene = owner_scene

func register(body: RigidBody3D) -> void:
	bodies.append(body)
	_previous[body] = body.global_position
	body.water_probe = scene.water_play.surface_at
	body.splashed.connect(scene.water_play.splash)
	body.released.connect(func() -> void: _previous[body] = body.global_position)

func hover(_mouse: Vector2) -> void:
	# Hover must not allocate physics bodies for everything the cursor passes.
	pass

func begin_grab(body: RigidBody3D, mouse: Vector2) -> void:
	if scene._paused or scene.gust_tool or body not in bodies: return
	super.begin_grab(body,mouse)

func adjust_height(amount: float, mouse: Vector2) -> void:
	if grabbed == null or scene._over_controls(mouse): return
	var ground: Variant = scene._probe_ground(grabbed.global_position)
	if ground == null: return
	_plane.d = clampf(_plane.d+amount,ground.y+grabbed.radius+0.1,ground.y+3.6)
	move_grab(mouse)
