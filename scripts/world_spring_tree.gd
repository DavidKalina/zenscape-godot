extends PlaySpringTree
## Same authored meshes and materials, deformed in a common world-aligned frame.
var object_id := -1

func _ready() -> void:
	_halo.free()

func set_highlight(_value: bool) -> void:
	pass

func configure(parts: Array, root_position: Vector3) -> void:
	global_position = root_position
	var top := 0.0
	for part in parts:
		var mesh := MeshInstance3D.new()
		mesh.mesh = part.mesh
		add_child(mesh)
		mesh.global_transform = part.transform
		mesh.material_override = part.material
		var box: AABB = mesh.transform*mesh.mesh.get_aabb()
		top = maxf(top,box.end.y)
		if mesh.material_override is ShaderMaterial:
			var material: ShaderMaterial = mesh.material_override
			material.set_shader_parameter("play_to_tree",mesh.transform)
			material.set_shader_parameter("play_from_tree",mesh.transform.affine_inverse())
			_materials.append(material)
		mesh.extra_cull_margin = 100.0
	tree_height = maxf(0.5,top)
	for material in _materials: material.set_shader_parameter("play_height",tree_height)

func _sync() -> void:
	for material in _materials: material.set_shader_parameter("play_bend",bend)

func pick(camera: Camera3D, mouse: Vector2, max_distance := INF) -> bool:
	var origin := camera.project_ray_origin(mouse)
	var ray := camera.project_ray_normal(mouse)
	for i in range(1,13):
		var height := tree_height*float(i)/13.0
		var point := center(height)
		var along := (point-origin).dot(ray)
		var radius := maxf(0.18,tree_height*0.12)
		if along>0.0 and along<max_distance and (origin+ray*along).distance_to(point)<radius: return true
	return false
