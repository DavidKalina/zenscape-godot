extends Node3D
## Product gusts share one force field with ribbons, leaves and loose props.
var scene: Node3D
var field := preload("res://scripts/local_wind_field.gd").new()
var visuals := preload("res://scripts/wind_gust_visuals.gd").new()
var collision_root := Node3D.new()
var dirty := true
var _pending: Array[Dictionary] = []

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	process_physics_priority = -20
	add_child(field)
	add_child(visuals)
	visuals.setup(field)
	add_child(collision_root)
	scene._leaf_litter.local_wind = field
	scene._chunk_editor.play_geometry_changed.connect(func() -> void: dirty = true)
	scene._chunk_editor.formation_started.connect(func() -> void: dirty = true)

func send(center: Vector3, direction := Vector3.ZERO) -> void:
	if scene._paused: return
	if direction.is_zero_approx():
		var angle: float = scene._atmosphere._air_angle
		direction = Vector3(cos(angle),0,sin(angle))
		scene._atmosphere.send_gust(center)
	_pending.append({"center":center,"direction":direction.normalized()})

func ground(point: Vector3) -> Variant:
	return scene.navigation._ground(point)

func _physics_process(delta: float) -> void:
	if scene == null: return
	if scene._paused: return
	# Static collision is paid only when a gust needs it after an edit, not on
	# every brush dab. Publish forces on the following physics boundary.
	if dirty and not _pending.is_empty():
		_rebuild_collision()
		dirty = false
		return
	for request in _pending:
		field.emit_gust(request.center+Vector3.UP,request.direction,20.0,8.0,1.4)
	_pending.clear()
	field.advance(delta)

func _rebuild_collision() -> void:
	if scene.get("world_play") != null and scene.world_play.owner_scene != null:
		scene.world_play.ensure_collision()
		return
	for child in collision_root.get_children():
		child.collision_layer = 0
		collision_root.remove_child(child)
		child.queue_free()
	var shape: ConcavePolygonShape3D = scene._chunk_editor.terrain.mesh.create_trimesh_shape()
	shape.backface_collision = true
	_add_shape(shape,scene._chunk_editor.terrain.global_transform)
	# Habitat contains both imported scenery and objects authored in this world.
	for bounds: AABB in scene.habitat.solids:
		var box := BoxShape3D.new()
		box.size = bounds.size.max(Vector3.ONE*0.01)
		_add_shape(box,Transform3D(Basis.IDENTITY,bounds.get_center()))

func _add_shape(shape: Shape3D, pose: Transform3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	collision_root.add_child(body)
	body.global_transform = pose

func clear() -> void:
	_pending.clear()
	field.clear()
