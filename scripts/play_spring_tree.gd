class_name PlaySpringTree
extends Node3D
## One elastic tree. Rendering, picking and swept contact share this centerline.
const HEIGHT := 5.0
var tree_height := HEIGHT
const MAX_BEND := 1.65
var bend := Vector2.ZERO
var velocity := Vector2.ZERO
var held := false
var armed := false
var tension: float:
	get: return bend.length()/MAX_BEND
var _target := Vector2.ZERO
var _materials: Array[ShaderMaterial] = []
var _halo := MeshInstance3D.new()
var _halo_material := StandardMaterial3D.new()

func _ready() -> void:
	var source: Node3D = preload("res://assets/zen_reference/geometry.scn").instantiate()
	# Reference conifer parts retain their authored silhouettes and vertex colors.
	for name in ["mesh-8", "mesh-9"]:
		var original: MultiMeshInstance3D = source.get_node(name)
		var mesh := MeshInstance3D.new()
		mesh.mesh = original.multimesh.mesh
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/play_spring_tree.gdshader")
		material.set_shader_parameter("palette_role",4 if name == "mesh-8" else 2)
		material.set_shader_parameter("tint",Color(0.24,0.12,0.055) if name == "mesh-8" else Color(0.30,0.46,0.12))
		mesh.material_override = material
		_materials.append(material)
		add_child(mesh)
		mesh.custom_aabb = AABB(Vector3(-7,-1,-7),Vector3(14,9,14))
	source.free()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.36
	ring.outer_radius = 0.43
	_halo.mesh = ring
	_halo.position.y = 0.05
	_halo.material_override = _halo_material
	_halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	add_child(_halo)
	set_highlight(false)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.24
	shape.height = 0.8
	collider.shape = shape
	collider.position.y = 0.4
	body.add_child(collider)
	add_child(body)

func center(height: float, pose := bend) -> Vector3:
	var amount := pose.length()
	if amount < 0.0001: return global_position+Vector3.UP*height
	var theta := amount*height/tree_height
	var direction := Vector3(pose.x,0,pose.y)/amount
	return global_position + (direction*(1.0-cos(theta))+Vector3.UP*sin(theta))*tree_height/amount

func set_highlight(value: bool) -> void:
	_halo.visible = value or held
	_halo_material.albedo_color = Color(1.0,0.78-0.35*tension,0.36,0.85)
	for material in _materials: material.set_shader_parameter("attention",0.07 if value or held else 0.0)

func begin_grab() -> void:
	held = true
	armed = false
	_target = bend
	velocity = Vector2.ZERO

func drag_to(offset: Vector3) -> void:
	if held and offset.is_finite(): _target = Vector2(offset.x,offset.z).limit_length(5.0)*MAX_BEND/5.0

func release() -> void:
	if not held: return
	held = false
	armed = tension > 0.12

func cancel() -> void:
	held = false
	armed = false
	_target = Vector2.ZERO
	velocity = Vector2.ZERO

func reset() -> void:
	cancel()
	bend = Vector2.ZERO
	_sync()

func advance(delta: float) -> void:
	var dt := clampf(delta,0,0.03334)
	if held:
		bend = bend.lerp(_target,1.0-exp(-16.0*dt))
		velocity = Vector2.ZERO
	else:
		velocity += (-bend*38.0-velocity*2.5)*dt
		bend += velocity*dt
		if bend.length() < 0.003 and velocity.length() < 0.015:
			bend = Vector2.ZERO
			velocity = Vector2.ZERO
			armed = false
	_sync()

func _sync() -> void:
	for material in _materials: material.set_shader_parameter("bend",bend)
	set_highlight(_halo.visible)

func pick(camera: Camera3D, mouse: Vector2, max_distance := INF) -> bool:
	var origin := camera.project_ray_origin(mouse)
	var ray := camera.project_ray_normal(mouse)
	for height in [0.6,1.2,1.8,2.4,3.0,3.6,4.2,4.8]:
		var point := center(height)
		var along := (point-origin).dot(ray)
		var radius := 0.35 if height < 2.0 else 0.85
		if along > 0 and along < max_distance and (origin+ray*along).distance_to(point)<radius: return true
	return false

## Returns actual branch sweep velocity only when the released crown crosses
## the resident's torso. One impulse per release; held trees never cause damage.
func sweep_contact(previous: Vector2, torso: Vector3, delta: float, consume := true) -> Vector3:
	if not armed or held or delta <= 0: return Vector3.ZERO
	for height in [1.5,2.1,2.7,3.3,3.9]:
		var before := center(height,previous)
		var after := center(height)
		var movement := after-before
		var nearest := Geometry3D.get_closest_point_to_segment(torso,before,after)
		var radius := 0.65 if height < 2.0 else 1.25
		if nearest.distance_to(torso) < radius and movement.length()/delta > 1.4:
			if consume: armed = false
			return movement/delta
	return Vector3.ZERO
