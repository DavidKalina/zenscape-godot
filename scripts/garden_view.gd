class_name GardenView
extends Node3D
## Render editable records with the original ZenScape tree/grass/flower meshes.
var data: RefCounted
var _meshes := {}
var _tints := {"canopy": Color(0.0652, 0.1788, 0.1081), "petal": Color(0.95, 0.78, 0.35)}
var _batches: Array[MultiMeshInstance3D] = []
var _water: MeshInstance3D
var _materials := {}
var _water_material: ShaderMaterial
var pond_vertices := PackedVector3Array()

func _ready() -> void:
	var source: Node3D = preload("res://assets/zen_reference/geometry.scn").instantiate()
	for pair: Array in [["trunk", "mesh-8"], ["canopy", "mesh-9"], ["grass", "mesh-10"], ["stem", "flower-stems"], ["petal", "flowers-daisy"]]:
		var original: MultiMeshInstance3D = source.get_node(pair[1])
		_meshes[pair[0]] = original.multimesh.mesh
		_materials[pair[0]] = original.multimesh.mesh.surface_get_material(0).duplicate()
	source.free()
	# A faceted stone in the same muted palette as the ground.
	var sphere := SphereMesh.new()
	sphere.radial_segments = 7
	sphere.rings = 3
	sphere.radius = 0.6
	sphere.height = 0.85
	var arrays := sphere.get_mesh_arrays()
	var colors := PackedColorArray()
	colors.resize(arrays[Mesh.ARRAY_VERTEX].size())
	colors.fill(Color("969986").srgb_to_linear())
	arrays[Mesh.ARRAY_COLOR] = colors
	var stone := ArrayMesh.new()
	stone.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes["rock"] = stone
	var rock_material := ShaderMaterial.new()
	rock_material.shader = preload("res://shaders/reference_surface.gdshader")
	rock_material.set_shader_parameter("flat_faces", true)
	rock_material.set_shader_parameter("wet_ground", true)
	_materials["rock"] = rock_material
	_water = MeshInstance3D.new()
	_water.name = "Ponds"
	_water_material = ShaderMaterial.new()
	_water_material.shader = preload("res://shaders/lake_reference_water.gdshader")
	_water_material.set_shader_parameter("lake_swell", 0.2)
	_water_material.set_shader_parameter("lake_algae_amount", 0.2)
	_water.material_override = _water_material
	add_child(_water)

func rebuild() -> void:
	for batch in _batches:
		batch.free()
	_batches.clear()
	var transforms := {"trunk": [], "canopy": [], "grass": [], "stem": [], "petal": [], "rock": []}
	for item: Dictionary in data.objects:
		var position: Vector3 = data.object_position(item)
		var basis := Basis(Vector3.UP, item.angle).scaled(Vector3.ONE * item.scale)
		var transform := Transform3D(basis, position)
		match item.asset:
			"tree":
				transforms.trunk.append(transform)
				transforms.canopy.append(transform)
			"flower":
				transforms.stem.append(transform)
				transforms.petal.append(transform)
			"rock":
				transform.origin.y += 0.24 * item.scale
				transforms.rock.append(transform)
	var cells: int = data.meadow_side()
	for z in range(cells):
		for x in range(cells):
			var index := z * cells + x
			var count := int(data.meadow[index] * 8.0)
			var rng := RandomNumberGenerator.new()
			rng.seed = index * 7919 + 17041
			for i in range(count):
				var p: Vector2 = data.meadow_position(x,z) + Vector2(rng.randf(), rng.randf()) * data.meadow_step()
				var height: Variant = data.ground_height(p)
				if height == null:
					continue
				var size := rng.randf_range(0.65, 1.3)
				var transform := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(p.x, height, p.y))
				transforms.grass.append(transform)
				if i % 4 == 0:
					transforms.stem.append(transform)
					transforms.petal.append(transform)
	for key: String in transforms:
		var placements: Array = transforms[key]
		if placements.is_empty():
			continue
		var batch := MultiMeshInstance3D.new()
		batch.name = key.capitalize()
		batch.multimesh = MultiMesh.new()
		batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batch.multimesh.use_colors = true
		batch.multimesh.mesh = _meshes[key]
		batch.multimesh.instance_count = placements.size()
		for i in range(placements.size()):
			batch.multimesh.set_instance_transform(i, placements[i])
			batch.multimesh.set_instance_color(i, _tints.get(key, Color.WHITE))
		batch.material_override = _materials[key]
		add_child(batch)
		_batches.append(batch)
	pond_vertices.clear()
	for pond: Dictionary in data.ponds:
		pond_vertices.append_array(data.pond_surface(pond))
	_water.mesh = null
	if not pond_vertices.is_empty():
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_normal(Vector3.UP)
		surface.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
		surface.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)
		for point in pond_vertices:
			var depth := maxf(0.0, point.y - float(data.ground_height(Vector2(point.x, point.z))))
			surface.set_uv2(Vector2(depth, 0.0))
			var fetch: PackedFloat32Array = data.pond_fetch(Vector2(point.x, point.z), point.y)
			surface.set_custom(0, Color(fetch[0], fetch[1], fetch[2], fetch[3]))
			surface.set_custom(1, Color(fetch[4], fetch[5], fetch[6], fetch[7]))
			surface.set_color(Color("79ae9b").lerp(Color("245a5c"), 1.0-exp(-depth/0.45)).srgb_to_linear())
			surface.add_vertex(point)
		_water.mesh = surface.commit()
