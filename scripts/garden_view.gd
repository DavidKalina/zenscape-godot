class_name GardenView
extends Node3D
## Render editable records with the original ZenScape tree/grass/flower meshes.
var data: GardenData
var _meshes := {}
var _tints := {"trunk": Color(0.1573, 0.0766, 0.0474), "canopy": Color(0.0652, 0.1788, 0.1081), "stem": Color(0.0782, 0.1946, 0.0452), "petal": Color(0.95, 0.78, 0.35)}
var _batches: Array[MultiMeshInstance3D] = []
var _water: MeshInstance3D
var _foliage: ShaderMaterial
var _solid: ShaderMaterial
var _water_material: ShaderMaterial
var pond_vertices := PackedVector3Array()

func _ready() -> void:
	_foliage = ShaderMaterial.new()
	_foliage.shader = preload("res://shaders/garden_foliage.gdshader")
	_solid = _foliage.duplicate()
	_solid.set_shader_parameter("sway", false)
	var source: Node3D = preload("res://assets/zen_reference/geometry.scn").instantiate()
	for pair: Array in [["trunk", "mesh-8"], ["canopy", "mesh-9"], ["grass", "mesh-10"], ["stem", "flower-stems"], ["petal", "flowers-daisy"]]:
		var original: MultiMeshInstance3D = source.get_node(pair[1])
		_meshes[pair[0]] = original.multimesh.mesh
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
	_water = MeshInstance3D.new()
	_water.name = "Ponds"
	_water_material = ShaderMaterial.new()
	_water_material.shader = preload("res://shaders/garden_water.gdshader")
	_water.material_override = _water_material
	add_child(_water)

func rebuild() -> void:
	for batch in _batches:
		batch.free()
	_batches.clear()
	var transforms := {"trunk": [], "canopy": [], "grass": [], "stem": [], "petal": [], "rock": []}
	for item: Dictionary in data.objects:
		var position := data.object_position(item)
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
	for z in range(LandscapeData.CELLS):
		for x in range(LandscapeData.CELLS):
			var index := z * LandscapeData.CELLS + x
			var count := int(data.meadow[index] * 8.0)
			var rng := RandomNumberGenerator.new()
			rng.seed = index * 7919 + 17041
			for i in range(count):
				var p := LandscapeData.grid_position(x, z) + Vector2(rng.randf(), rng.randf()) * LandscapeData.STEP
				var size := rng.randf_range(0.65, 1.3)
				var transform := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(p.x, data.height_at(p), p.y))
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
		batch.material_override = _solid if key in ["trunk", "rock"] else _foliage
		add_child(batch)
		_batches.append(batch)
	pond_vertices.clear()
	for pond: Dictionary in data.ponds:
		pond_vertices.append_array(GardenWater.surface(data, pond))
	_water.mesh = null
	if not pond_vertices.is_empty():
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_normal(Vector3.UP)
		for point in pond_vertices:
			surface.add_vertex(point)
		_water.mesh = surface.commit()
	set_weather()

func set_weather() -> void:
	for material: ShaderMaterial in [_foliage, _solid]:
		material.set_shader_parameter("snow", 0.8 if data.weather == "Snow" else 0.0)
		material.set_shader_parameter("wet", 1.0 if data.weather == "Rain" else 0.0)
		material.set_shader_parameter("wind", 1.4 if data.weather == "Rain" else 0.4)
	_water_material.set_shader_parameter("frozen", 1.0 if data.weather == "Snow" else 0.0)
