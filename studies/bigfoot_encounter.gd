extends Node3D
## Source rare encounter admission, concealment and manual sandbox preview.
## The captured seed has no encounter tree, so locate a dry, clear terrain patch.

const PEEK_SCALE := 2.85 / 2.52
var rig: Node3D
var ground: RefCounted
var age := 0.0
var active := false
var available := false
var _frame: Node3D
var _tree: Node3D
var _tree_rest: Transform3D
var _source_frame: Transform3D
var authored_tree := false
var _anchor: Dictionary
var automatic_enabled := true
var forced := false
var played := false
var check_in := 30.0
var silhouette := false
var random_value: Callable = randf
var now_msec: Callable = func(): return int(Time.get_unix_time_from_system() * 1000.0)
var reserve: Callable = _reserve
var cooldown_path := "user://bigfoot-cooldown.cfg"
const COOLDOWN_MSEC := 7 * 24 * 60 * 60 * 1000

func _reserve(next_at: int, now: int) -> bool:
	var config := ConfigFile.new()
	var error := config.load(cooldown_path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		return false
	if int(config.get_value("encounter", "next_at", 0)) > now:
		return false
	config.set_value("encounter", "next_at", next_at)
	return config.save(cooldown_path) == OK

func setup(geometry: Node3D) -> void:
	ground = preload("res://scripts/reference_ground.gd").new()
	ground.setup(geometry.get_node("terrain"))
	var wet: Array[RefCounted] = []
	for node in geometry.get_children():
		if node is MeshInstance3D:
			var material := node.mesh.surface_get_material(0) as ShaderMaterial
			if material != null and material.shader.resource_path.ends_with("reference_water.gdshader"):
				var surface := preload("res://scripts/reference_ground.gd").new()
				surface.setup(node)
				wet.append(surface)
	var obstacles: Array[Vector3] = []
	# These are the two trunk groups in the imported seed-7 fixture.
	for group_name in ["mesh-8", "mesh-11"]:
		var group := geometry.get_node(group_name) as MultiMeshInstance3D
		for i in range(group.multimesh.instance_count):
			obstacles.append(group.transform * group.multimesh.get_instance_transform(i).origin)
	var best := -INF
	var location := Vector3.ZERO
	var heading := 0.0
	for xi in range(-28, 29):
		for zi in range(-28, 29):
			var x := xi * 0.5
			var z := zi * 0.5
			var h: Variant = ground.height_at(x, z)
			if h == null:
				continue
			var valid := true
			var variation := 0.0
			for i in range(16):
				var p := Vector2(x, z) + Vector2.from_angle(i * TAU / 16.0) * 1.6
				var edge: Variant = ground.height_at(p.x, p.y)
				if edge == null:
					valid = false
				else:
					variation = maxf(variation, absf(edge - h))
				for water in wet:
					if water.height_at(p.x, p.y) != null:
						valid = false
			var room := 100.0
			for obstacle in obstacles:
				room = minf(room, Vector2(x - obstacle.x, z - obstacle.z).length())
			if not valid or variation > 0.18 or room < 1.7:
				continue
			var chosen_heading := INF
			for turn in [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5, PI]:
				var angle: float = atan2(-float(x), -float(z)) + turn
				var facing := Vector2(sin(angle), cos(angle))
				var clear := true
				for step in range(3, 14):
					var p := Vector2(x, z) + facing * step * 0.5
					var corridor: Variant = ground.height_at(p.x, p.y)
					for obstacle in obstacles:
						if p.distance_to(Vector2(obstacle.x, obstacle.z)) < 1.35:
							clear = false
					if corridor != null and corridor > h + 1.4:
						clear = false
				if clear:
					chosen_heading = angle
					break
			if chosen_heading == INF:
				continue
			var score := minf(room, 3.0) - Vector2(x, z).length() * 0.15
			if score > best:
				best = score
				location = Vector3(x, h, z)
				heading = chosen_heading
	if best == -INF:
		push_warning("No dry, level Bigfoot clearing in this capture")
		return
	available = true
	_frame = Node3D.new()
	add_child(_frame)
	_frame.position = location
	_frame.rotation.y = heading
	_frame.scale = Vector3.ONE * PEEK_SCALE
	_source_frame = _frame.transform
	var tree := preload("res://assets/bigfoot/old_tree.glb").instantiate()
	_tree = tree
	_tree_rest = tree.transform
	_frame.add_child(tree)
	for node in tree.find_children("*", "MeshInstance3D", true, false):
		var original := node.mesh.surface_get_material(0) as StandardMaterial3D
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/reference_surface.gdshader")
		material.set_shader_parameter("base_color", original.albedo_color)
		node.material_override = material
	rig = preload("res://scripts/reference_bigfoot.gd").new()
	_frame.add_child(rig)
	rig.position = Vector3(0, 0, -0.65)
	rig.scale = Vector3.ONE / PEEK_SCALE
	rig.setup()
	_anchor = {"grip": _frame.to_global(Vector3(0.455, 1.67, -0.356)), "rotation": _frame.global_basis.get_rotation_quaternion() * Basis.from_euler(Vector3(0, -PI / 3.0, PI / 2.0), EULER_ORDER_YXZ).get_rotation_quaternion()}
	_frame.visible = true
	rig.visible = false
	# The source seed has no encounter tree; show the native one only while
	# Bigfoot is out so it does not sit in every reference framing.
	_tree.visible = false
	print("Bigfoot clearing: ", location)

func set_authored_tree(pose: Variant) -> void:
	if not available:
		return
	var desired: Transform3D = _source_frame if pose == null else Transform3D(pose.basis.scaled(Vector3.ONE*PEEK_SCALE),pose.origin)
	if desired != _frame.transform:
		active = false
		rig.visible = false
		_frame.transform = desired
		_anchor = {"grip":_frame.to_global(Vector3(0.455,1.67,-0.356)),"rotation":_frame.global_basis.get_rotation_quaternion()*Basis.from_euler(Vector3(0,-PI/3.0,PI/2.0),EULER_ORDER_YXZ).get_rotation_quaternion()}
	authored_tree = pose != null
	_tree.visible = active and not authored_tree # The editor renders the saved tree itself.

func update_growth(terrain: float, foliage: float) -> void:
	if not available:
		return
	var grown := smoothstep(0.1,0.9,foliage) if terrain >= 0.995 else 0.0
	visible = grown > 0.001
	_tree.transform = Transform3D(_tree_rest.basis.scaled(Vector3.ONE*maxf(grown,0.0001)),_tree_rest.origin)

func summon(fog := false) -> void:
	if not available:
		return
	age = 0.0
	forced = true
	silhouette = fog
	rig.set_silhouette(silhouette)
	active = true
	rig.position = Vector3(1.05, 0, 1.05) if silhouette else Vector3(0, 0, -0.65)
	rig.visible = true
	_frame.visible = true
	_tree.visible = not authored_tree

func _pose(time: float, camera_position: Vector3) -> void:
	var mode := "look" if silhouette else "peek"
	rig.pose(mode, time, camera_position, _anchor)
	var heights := {}
	for leg in rig.LEGS:
		var ankle: Node3D = rig.joints[leg[3]]
		var sole := ankle.to_global(Vector3(0, -0.12, 0))
		var y: Variant = ground.height_at(sole.x, sole.z)
		if y != null:
			heights[leg[0]] = (y - _frame.global_position.y) / rig.actor.global_basis.y.length()
	rig.pose(mode, time, camera_position, _anchor, heights)

func concealed(camera: Camera3D) -> bool:
	var camera_local := _frame.to_local(camera.global_position)
	var view := camera.global_transform.affine_inverse()
	var viewport_rect := Rect2(Vector2.ZERO, camera.get_viewport().get_visible_rect().size)
	for mesh: MeshInstance3D in rig.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var world := mesh.to_global(vertex)
				var eye := view * world
				if eye.z > -camera.near or eye.z < -camera.far or not viewport_rect.has_point(camera.unproject_position(world)):
					continue
				var point := _frame.to_local(world)
				var direction := point - camera_local
				var length_squared := direction.x * direction.x + direction.z * direction.z
				if length_squared < 0.000001:
					return false
				var t := -(camera_local.x * direction.x + camera_local.z * direction.z) / length_squared
				var y := camera_local.y + t * direction.y
				var radius := (0.60 - 0.32 * y / 5.8) * cos(PI / 12.0)
				var nearest := Vector2(camera_local.x + t * direction.x, camera_local.z + t * direction.z)
				if not (t > 0 and t < 1 and y > 0 and y < 5.8 and nearest.length() < radius):
					return false
	return true

func advance(delta: float, paused: bool, camera_position: Vector3, camera: Camera3D = null, growth := 1.0, mist := 0.0) -> void:
	if not available:
		return
	_tree.visible = active and not authored_tree
	if growth < 0.99:
		active = false
		rig.visible = false
		_tree.visible = false
		age = 0.0
		return
	if paused:
		return
	var step := clampf(delta, 0.0, 0.1)
	if active:
		age += delta if forced else step
		_pose(age if forced else minf(age, 13.2), camera_position)
		if forced and age >= 16.0:
			active = false
			rig.visible = false
		elif not forced and age >= 13.2 and camera != null:
			check_in -= step
			if check_in <= 0:
				check_in = 1.0
				if concealed(camera):
					active = false
					rig.visible = false
		return
	if not automatic_enabled or played or camera == null:
		return
	check_in -= step
	if check_in > 0:
		return
	check_in = 30.0
	if random_value.call() >= 0.05:
		return
	var distance := camera_position.distance_to(_frame.global_position + Vector3.UP * 1.8)
	if distance < 4.0 or distance > 35.0:
		return
	silhouette = mist >= 0.65
	rig.set_silhouette(silhouette)
	rig.position = Vector3(1.05, 0, 1.05) if silhouette else Vector3(0, 0, -0.65)
	_pose(0.0, camera_position)
	if not concealed(camera):
		return
	var now: int = now_msec.call()
	if not reserve.call(now + COOLDOWN_MSEC, now):
		return
	age = 0.0
	forced = false
	played = true
	active = true
	check_in = 1.0
	rig.visible = true

func focus_point() -> Vector3:
	return _frame.global_position + Vector3.UP * 1.6 if available else Vector3.ZERO
