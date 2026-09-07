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
var _stream_material: ShaderMaterial
var _foam_template: Mesh
var _landscape_foam: Node3D
var _landscape_mists: Array[CanvasLayer]=[]
var _landscape_falls: Array[MeshInstance3D]=[]
var _stream_nodes: Array[MeshInstance3D]=[]
var pond_vertices := PackedVector3Array()
var _catalog_parts := {}
var _catalog_poses := {}

func _ready() -> void:
	var source: Node3D = preload("res://assets/zen_reference/geometry.scn").instantiate()
	for pair: Array in [["trunk", "mesh-8"], ["canopy", "mesh-9"], ["grass", "mesh-10"], ["stem", "flower-stems"], ["petal", "flowers-daisy"]]:
		var original: MultiMeshInstance3D = source.get_node(pair[1])
		_meshes[pair[0]] = original.multimesh.mesh
		_materials[pair[0]] = original.multimesh.mesh.surface_get_material(0).duplicate()
	for kind in preload("res://scripts/native_asset_catalog.gd").PARTS:
		_catalog_parts[kind] = []
		for node_name in preload("res://scripts/native_asset_catalog.gd").PARTS[kind]:
			var original: Node3D = source.get_node(node_name)
			var key: String = kind+":"+node_name
			_catalog_parts[kind].append(key)
			var mesh: Mesh = original.multimesh.mesh if original is MultiMeshInstance3D else original.mesh
			_meshes[key] = mesh
			_materials[key] = mesh.surface_get_material(0).duplicate()
			_catalog_poses[key] = preload("res://scripts/native_asset_catalog.gd").part_pose(key,original,mesh)
			_tints[key] = Color.WHITE
			if original is MultiMeshInstance3D and original.multimesh.use_colors and original.multimesh.instance_count > 0:
				_tints[key] = original.multimesh.get_instance_color(0)
	_water_material = source.get_node("mesh-30").mesh.surface_get_material(0).duplicate()
	_stream_material=source.get_node("mesh-38").mesh.surface_get_material(0).duplicate()
	_foam_template=source.get_node("mesh-31").mesh
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
	_water.material_override = _water_material
	add_child(_water)

func rebuild() -> void:
	for batch in _batches:
		batch.free()
	_batches.clear()
	var transforms := {"trunk": [], "canopy": [], "grass": [], "stem": [], "petal": [], "rock": []}
	for kind in _catalog_parts:
		for key in _catalog_parts[kind]:
			transforms[key] = []
	var instance_tints := {}
	for key in transforms: instance_tints[key] = []
	for item: Dictionary in data.objects:
		var tint: Variant = preload("res://scripts/native_object_pose.gd").decode_tint(item.tint) if item.has("tint") else null
		var position: Vector3 = data.object_position(item)
		var basis := preload("res://scripts/native_object_pose.gd").decode_basis(item.pose) if item.has("pose") else Basis(Vector3.UP, item.angle).scaled(Vector3.ONE * item.scale)
		var transform := Transform3D(basis, position)
		if _catalog_parts.has(item.asset):
			for key in _catalog_parts[item.asset]:
				transforms[key].append(transform*_catalog_poses[key])
				var colored: bool = _catalog_parts[item.asset].size()==1 or "canopies" in key or "flowers-" in key or "fungus-caps" in key
				instance_tints[key].append(tint if tint != null and colored else _tints.get(key,Color.WHITE))
		match item.asset:
			"tree":
				transforms.trunk.append(transform)
				instance_tints.trunk.append(Color.WHITE)
				transforms.canopy.append(transform)
				instance_tints.canopy.append(tint if tint != null else _tints.canopy)
			"flower":
				transforms.stem.append(transform)
				instance_tints.stem.append(Color.WHITE)
				transforms.petal.append(transform)
				instance_tints.petal.append(tint if tint != null else _tints.petal)
			"rock":
				transform.origin.y += 0.24 * item.scale
				transforms.rock.append(transform)
				instance_tints.rock.append(tint if tint != null else Color.WHITE)
	var cells: int = data.meadow_side()
	for z in range(cells):
		for x in range(cells):
			var index := z * cells + x
			var count := int(data.grass_density(index) * 8.0)
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
				if i < int(data.meadow[index] * 8.0) and i % 4 == 0:
					transforms.stem.append(transform)
					transforms.petal.append(transform)
	for key: String in transforms:
		var placements: Array = transforms[key]
		if placements.is_empty():
			continue
		var batch := MultiMeshInstance3D.new()
		batch.name = key.capitalize()
		batch.set_meta("part", key)
		batch.multimesh = MultiMesh.new()
		batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batch.multimesh.use_colors = true
		batch.multimesh.mesh = _meshes[key]
		batch.multimesh.instance_count = placements.size()
		for i in range(placements.size()):
			batch.multimesh.set_instance_transform(i, placements[i])
			batch.multimesh.set_instance_color(i, instance_tints[key][i] if i < instance_tints[key].size() else _tints.get(key, Color.WHITE))
		batch.material_override = _materials[key]
		add_child(batch)
		_batches.append(batch)
	for node in _stream_nodes: node.free()
	_stream_nodes.clear()
	if data is NativeTerrainData:
		var gene: Dictionary=data._palette.noise.g.water
		var ramp:=preload("res://scripts/native_recipe_water.gd").water_ramp(gene)
		for course in data.streams:
			var geometry: Dictionary=preload("res://scripts/native_stream_geometry.gd").build(course,data.stream_ground_height,ramp)
			var node:=MeshInstance3D.new()
			node.name="Stream_%d" % _stream_nodes.size()
			node.mesh=preload("res://scripts/native_stream_geometry.gd").mesh(geometry)
			node.material_override=_stream_material
			add_child(node)
			_stream_nodes.append(node)
	for mist in _landscape_mists: mist.free()
	_landscape_mists.clear()
	if is_instance_valid(_landscape_foam): _landscape_foam.free()
	_landscape_foam=null
	for node in _landscape_falls: node.free()
	_landscape_falls.clear()
	if data is NativeTerrainData and data.landscape_waterfall:
		var strands: Array=data.waterfall_strands()
		_landscape_foam=preload("res://scripts/native_fall_foam.gd").new()
		_landscape_foam.name="LandscapeFoam"
		_landscape_foam.transform=data.waterfall_transform()
		add_child(_landscape_foam)
		_landscape_foam.setup(strands,data._recipe.source.g.chute.flow,_foam_template)
		var mist_recipe: Dictionary=preload("res://scripts/native_fall_mist.gd").build(strands,data._recipe.source.g.chute.flow)
		for batch in preload("res://scripts/native_fall_mist.gd").batches(mist_recipe,data.waterfall_transform()):
			var mist:=preload("res://studies/fall_mist.gd").new()
			add_child(mist)
			mist.setup(batch)
			_landscape_mists.append(mist)
		for strand in strands:
			var node: MeshInstance3D=preload("res://scripts/native_fall_renderer.gd").create(strand)
			node.name="LandscapeWaterfall_%d" % _landscape_falls.size()
			node.transform=data.waterfall_transform()
			add_child(node)
			_landscape_falls.append(node)
	pond_vertices.clear()
	var pond_depths:=PackedFloat32Array()
	var pond_colors:=PackedColorArray()
	var pond_fetch_a:=PackedColorArray()
	var pond_fetch_b:=PackedColorArray()
	for pond: Dictionary in data.ponds:
		if data is NativeTerrainData and data._recipe != null:
			var water: Dictionary=preload("res://scripts/native_recipe_water.gd").build(data,pond)
			pond_vertices.append_array(water.vertices)
			pond_depths.append_array(water.depths)
			pond_colors.append_array(water.colors)
			pond_fetch_a.append_array(water.fetch_a)
			pond_fetch_b.append_array(water.fetch_b)
		else:
			var vertices: PackedVector3Array=data.pond_surface(pond)
			pond_vertices.append_array(vertices)
			for point in vertices:
				var depth:=maxf(0.0,point.y-float(data.ground_height(Vector2(point.x,point.z))))
				pond_depths.append(depth)
				var fetch: PackedFloat32Array=data.pond_fetch(Vector2(point.x,point.z),point.y)
				pond_fetch_a.append(Color(fetch[0],fetch[1],fetch[2],fetch[3]))
				pond_fetch_b.append(Color(fetch[4],fetch[5],fetch[6],fetch[7]))
				pond_colors.append(Color("79ae9b").lerp(Color("245a5c"),1.0-exp(-depth/0.45)).srgb_to_linear())
	_water.mesh = null
	if not pond_vertices.is_empty():
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_normal(Vector3.UP)
		surface.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
		surface.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)
		for i in range(pond_vertices.size()):
			var point:=pond_vertices[i]
			var depth:=pond_depths[i]
			surface.set_uv2(Vector2(depth, 0.0))
			surface.set_custom(0,pond_fetch_a[i])
			surface.set_custom(1,pond_fetch_b[i])
			surface.set_color(pond_colors[i])
			surface.add_vertex(point)
		_water.mesh = surface.commit()

func _process(_delta: float) -> void:
	if not is_instance_valid(_landscape_foam): return
	var scene:=get_parent()
	_landscape_foam.animator.advance(scene._motion_time,scene._paused,scene._precipitation.surface_weather.ice,smoothstep(0.0,0.5,scene._growth.water),scene._growth.terrain>=0.995)

	var depth: CompositorEffect
	if scene._display_fog!=null:
		depth=scene._display_fog.depth
	else:
		var original: CanvasLayer=scene.get_node("WaterfallSpray")
		original.update_view(scene.camera)
		depth=original.fallback_depth
	for mist in _landscape_mists:
		mist.visible=scene._growth.terrain>=0.995 and scene._growth.water>=0.5
		mist.update_view(scene.camera,depth)
