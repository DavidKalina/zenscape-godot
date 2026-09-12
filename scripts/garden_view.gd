class_name GardenView
extends Node3D
signal instances_published()
## Render editable records with the original ZenScape tree/grass/flower meshes.
var data: RefCounted:
	set(value):
		if data != value: discard_cache()
		data = value
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
var _sources := {}
var _object_fire := {}
var _fire_parts := {}
signal object_fire_changed(id: int, value: Vector2)
## Bumped by every full rebuild, so consumers of the rendered ponds and streams
## can tell whether those meshes are the ones they last read.
var revision := 0
var last_water_usec := {}
var _view_ready := false
var _instance_generation := 0
var _instance_busy := false
var last_instance_usec := {}
var _view_heights := PackedFloat32Array()
var _view_signature := PackedByteArray()
var _water_signature := PackedByteArray()
var _stream_probe := {}
var _cascade_probe := {}

func _ready() -> void:
	var source: Node3D = preload("res://assets/zen_reference/geometry.scn").instantiate()
	for pair: Array in [["trunk", "mesh-8"], ["canopy", "mesh-9"], ["grass", "mesh-10"], ["stem", "flower-stems"], ["petal", "flowers-daisy"]]:
		var original: MultiMeshInstance3D = source.get_node(pair[1])
		_meshes[pair[0]] = original.multimesh.mesh
		_materials[pair[0]] = original.multimesh.mesh.surface_get_material(0).duplicate()
		if pair[0] in ["trunk", "canopy"]:
			_materials[pair[0]].set_shader_parameter("conifer_sway", true)
	for kind in preload("res://scripts/native_asset_catalog.gd").PARTS:
		_catalog_parts[kind] = []
		for node_name in preload("res://scripts/native_asset_catalog.gd").PARTS[kind]:
			var original: Node3D = NativeAssetCatalog.source_node(source,node_name)
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
	# Trunk and crown share a height so the restored wake bends them together.
	for keys in [["trunk","canopy"],["broadleaf:mesh-11","broadleaf:broadleaf-canopies"],["layered_tree:layered-trunk","layered_tree:layered-canopies"],["redwood:redwood-trunk","redwood:redwood-canopies"]]:
		var height := 0.1
		for key in keys: height = maxf(height,_meshes[key].get_aabb().end.y)
		for key in keys:
			_materials[key].set_shader_parameter("tree_tread",true)
			_materials[key].set_shader_parameter("tree_tread_height",height)
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
	_catalog_parts["leaf_bed"] = ["leaf_bed"]
	_catalog_poses["leaf_bed"] = Transform3D.IDENTITY
	_meshes["leaf_bed"] = preload("res://scripts/bigfoot_leaf_bed.gd").mesh()
	_materials["leaf_bed"] = rock_material.duplicate()
	_catalog_parts["explosive"] = ["explosive"]
	_catalog_poses["explosive"] = Transform3D.IDENTITY
	_meshes["explosive"] = preload("res://scripts/explosive_asset.gd").mesh()
	_materials["explosive"] = rock_material.duplicate()
	_meshes["explosive_leaves"] = _meshes["leaf_bed"]
	_materials["explosive_leaves"] = rock_material.duplicate()
	_catalog_poses["explosive_leaves"] = Transform3D.IDENTITY
	for key in _materials:
		FireMaterial.enable_instances(_materials[key])
		_materials[key].set_shader_parameter("palette_role",preload("res://scripts/scene_look.gd").part_role(key))
	_water = MeshInstance3D.new()
	_water.name = "Ponds"
	_water.material_override = _water_material
	add_child(_water)

## Brush dabs only lift instances near the stroke, so a refresh first tries to
## reuse the live batches and move just those. Anything the edit could not have
## reached - object records, water, painted cover - is verified unchanged before
## that shortcut is taken, and `force` skips it entirely.
func rebuild(force := false, frame_tree: SceneTree = null) -> bool:
	# Reuse and in-place lifts supersede pending preparation too.
	_instance_generation += 1
	if not force and _reuse():
		return true
	# Object commits do not alter shorelines, streams or waterfall geometry.
	# Keep those resources (and their revision) so surface maps stay cached too.
	if not force and _view_ready and data is NativeTerrainData and _view_heights == data.heights and _water_signature == _environment_signature():
		if not await _rebuild_instances(frame_tree): return false
		_view_signature = _signature()
		return true
	# Water can change without changing the instance recipes. Lift affected
	# plants and props in place instead of regenerating the entire meadow.
	var instance_region: Variant = data.moved_region(_view_heights) if not force and data is NativeTerrainData and _view_ready and _view_signature == _signature() else null
	if instance_region == null:
		if not await _rebuild_instances(frame_tree): return false
	elif instance_region is Rect2:
		_move_instances(instance_region)
	last_water_usec.clear()
	var water_began := Time.get_ticks_usec()
	for node in _stream_nodes: node.free()
	_stream_nodes.clear()
	_stream_probe = {}
	if data is NativeTerrainData:
		var gene: Dictionary=data._palette.noise.g.water
		var ramp:=preload("res://scripts/native_recipe_water.gd").water_ramp(gene)
		data.begin_probe()
		for course in data.streams:
			var geometry: Dictionary=preload("res://scripts/native_stream_geometry.gd").build(course,data.stream_ground_height,ramp)
			var node:=MeshInstance3D.new()
			node.name="Stream_%d" % _stream_nodes.size()
			node.mesh=preload("res://scripts/native_stream_geometry.gd").mesh(geometry)
			node.material_override=_stream_material
			add_child(node)
			_stream_nodes.append(node)
		_stream_probe = data.end_probe()
	last_water_usec["streams"] = Time.get_ticks_usec()-water_began
	water_began = Time.get_ticks_usec()
	for mist in _landscape_mists: mist.free()
	_landscape_mists.clear()
	if is_instance_valid(_landscape_foam): _landscape_foam.free()
	_landscape_foam=null
	for node in _landscape_falls: node.free()
	_landscape_falls.clear()
	_cascade_probe = {}
	if data is NativeTerrainData and data._recipe_settings.get("kind") == "formation":
		data.begin_probe()
		for course in data.streams:
			for cascade in preload("res://scripts/native_stream_cascades.gd").build(data,course):
				add_child(cascade)
				_landscape_falls.append(cascade)
		_cascade_probe = data.end_probe()
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
	last_water_usec["falls"] = Time.get_ticks_usec()-water_began
	water_began = Time.get_ticks_usec()
	pond_vertices.clear()
	var pond_depths:=PackedFloat32Array()
	var pond_colors:=PackedColorArray()
	var pond_fetch_a:=PackedColorArray()
	var pond_fetch_b:=PackedColorArray()
	# Adjacent triangles share vertices. Shore-distance sampling is identical at
	# those points within this rebuild, regardless of which triangle owns them.
	var fetch_by_vertex := {}
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
				if not fetch_by_vertex.has(point):
					fetch_by_vertex[point] = data.pond_fetch(Vector2(point.x,point.z),point.y)
				var fetch: PackedFloat32Array=fetch_by_vertex[point]
				pond_fetch_a.append(Color(fetch[0],fetch[1],fetch[2],fetch[3]))
				pond_fetch_b.append(Color(fetch[4],fetch[5],fetch[6],fetch[7]))
				pond_colors.append(Color("79ae9b").lerp(Color("245a5c"),1.0-exp(-depth/0.45)).srgb_to_linear())
	last_water_usec["pond_samples"] = Time.get_ticks_usec()-water_began
	water_began = Time.get_ticks_usec()
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
	last_water_usec["pond_publish"] = Time.get_ticks_usec()-water_began
	revision += 1
	if data is NativeTerrainData:
		_view_heights = data.heights.duplicate()
		_view_signature = _signature()
		_water_signature = _environment_signature()
		_view_ready = true

	return true

func _rebuild_instances(frame_tree: SceneTree = null) -> bool:
	last_instance_usec.clear()
	var stage_start := Time.get_ticks_usec()
	_instance_generation += 1
	var generation := _instance_generation
	# Empty/small gardens are cheaper than a worker round trip. Substantial
	# object sets or procedural cover retain the background calculation path.
	var substantial: bool = data is NativeTerrainData and (data.objects.size() >= 64 or data.blades.size()-data.blades.count(0.0)+data.meadow.size()-data.meadow.count(0.0) >= 64)
	var worker_tree: SceneTree = frame_tree if substantial else null
	if worker_tree != null:
		while _instance_busy:
			await worker_tree.process_frame
			if generation != _instance_generation: return false
		_instance_busy = true
	var provider := data
	var input := data
	# Small gardens sample synchronously but can still yield while staging GPU
	# resources. Their input and source records need the same isolation.
	if frame_tree != null:
		if data is NativeTerrainData:
			input = preload("res://scripts/native_terrain_snapshot.gd").for_queries(data)
		else:
			input = GardenData.new()
			input.heights = data.heights.duplicate()
			input.meadow = data.meadow.duplicate()
			input.objects.assign(data.objects.duplicate(true))
	var parts := _catalog_parts.duplicate(true)
	var poses := _catalog_poses.duplicate(true)
	var tints := _tints.duplicate(true)
	var environment := _environment_signature() if frame_tree != null and data is NativeTerrainData else PackedByteArray()
	var current := _instance_inputs_current.bind(generation,provider,input,parts,poses,tints,environment)
	var action := preload("res://scripts/garden_instance_samples.gd").build.bind(input,parts,poses,tints)
	var job = preload("res://scripts/background_work.gd").new()
	last_instance_usec.snapshot = Time.get_ticks_usec()-stage_start
	stage_start = Time.get_ticks_usec()
	var sampled: Dictionary = await job.run(action,worker_tree)
	if worker_tree != null: _instance_busy = false
	last_instance_usec.worker_elapsed = Time.get_ticks_usec()-stage_start
	stage_start = Time.get_ticks_usec()
	if not current.call(): return false
	var staging := Node3D.new()
	staging.visible = false
	add_child(staging)
	var transforms: Dictionary = sampled.transforms
	var instance_tints: Dictionary = sampled.tints
	var replacement: Array[MultiMeshInstance3D] = []
	var budget = preload("res://scripts/frame_work_budget.gd").new(frame_tree)
	for key: String in transforms:
		var placements: Array = transforms[key]
		if placements.is_empty():
			continue
		var batch := MultiMeshInstance3D.new()
		staging.add_child(batch)
		batch.name = key.capitalize()
		batch.set_meta("part", key)
		batch.multimesh = MultiMesh.new()
		batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batch.multimesh.use_colors = true
		batch.multimesh.use_custom_data = true
		batch.multimesh.mesh = _meshes[key]
		batch.multimesh.instance_count = placements.size()
		for i in range(placements.size()):
			batch.multimesh.set_instance_transform(i, placements[i])
			var color: Color = instance_tints[key][i] if i < instance_tints[key].size() else tints.get(key, Color.WHITE)
			sampled.sources[key][i]["color"] = color
			batch.multimesh.set_instance_color(i,color)
			if frame_tree != null and i%256 == 255:
				await budget.checkpoint()
				if generation != _instance_generation:
					staging.free()
					return false
		batch.material_override = _materials[key]
		replacement.append(batch)
		if frame_tree != null:
			await budget.checkpoint()
			if generation != _instance_generation:
				staging.free()
				return false

	if not current.call():
		staging.free()
		return false
	last_instance_usec.prepare_elapsed = Time.get_ticks_usec()-stage_start
	stage_start = Time.get_ticks_usec()
	# Keep the old visible batches until every replacement is ready. Consumers
	# see sources and instance indices change together on the main thread.
	for batch in _batches: batch.free()
	_batches = replacement
	_sources = sampled.sources
	for batch in _batches:
		staging.remove_child(batch)
		add_child(batch)
	staging.free()
	_index_fire_parts()
	instances_published.emit()
	last_instance_usec.swap = Time.get_ticks_usec()-stage_start
	return true

func _instance_inputs_current(generation: int, provider: RefCounted, input: RefCounted, parts: Dictionary, poses: Dictionary, tints: Dictionary, environment: PackedByteArray) -> bool:
	if generation != _instance_generation: return false
	if data == provider and data.heights == input.heights and data.meadow == input.meadow and data.objects == input.objects and (not data is NativeTerrainData or data.blades == input.blades) and _catalog_parts == parts and _catalog_poses == poses and _tints == tints and (environment.is_empty() or environment == _environment_signature()):
		return true
	# A direct input edit may not bump the object revision. Leave the visible
	# scene intact, but ensure the next ordinary rebuild repairs it.
	_view_ready = false
	return false

## Map every record to its part instances and re-apply the fire state the last
## push left, so a rebuild in the middle of a burn (or the snag swap at the end
## of one) comes back charred instead of freshly cut.
func _index_fire_parts() -> void:
	_fire_parts = {}
	for batch in _batches:
		var recipes: Array = _sources.get(batch.get_meta("part"),[])
		for i in range(recipes.size()):
			var item: Variant = recipes[i].item
			if item == null:
				continue
			var id := int(item.id)
			if not _fire_parts.has(id):
				_fire_parts[id] = []
			_fire_parts[id].append({"batch":batch,"index":i})
	for id: int in _object_fire.keys():
		if _fire_parts.has(id):
			var fire: Vector2 = _object_fire[id]
			_write_fire(id,fire.x,fire.y)
		else:
			# The record is gone - burnt away, deleted or undone.
			_object_fire.erase(id)

## Per-instance fire for one record without a rebuild: `char` 0..1 browns then
## skeletonises the foliage, `burn` 0..1 is live flame heat for the ember glow.
## (0, 0) is the untouched look and renders exactly as it did before fire.
func set_object_fire(id: int, char: float, burn: float) -> void:
	var value := Vector2(clampf(char,0.0,1.0),clampf(burn,0.0,1.0))
	if _object_fire.get(id,Vector2(-1.0,-1.0)) == value:
		return
	if value.is_zero_approx():
		_object_fire.erase(id)
	else:
		_object_fire[id] = value
	_write_fire(id,value.x,value.y)
	object_fire_changed.emit(id,value)

## Fire state for one record, (0, 0) when it never burnt.
func object_fire(id: int) -> Vector2:
	return _object_fire.get(id,Vector2.ZERO)

func _write_fire(id: int, char: float, burn: float) -> void:
	for part: Dictionary in _fire_parts.get(id,[]):
		var batch: MultiMeshInstance3D = part.batch
		if is_instance_valid(batch) and batch.multimesh != null and batch.multimesh.use_custom_data:
			batch.multimesh.set_instance_custom_data(part.index,Color(char,burn,0.0,0.0))

func discard_cache() -> void:
	cancel_rebuild()
	_view_ready = false

func cancel_rebuild() -> void:
	_instance_generation += 1

func _signature() -> PackedByteArray:
	return var_to_bytes([data.objects_revision,data.objects.size(),data.ponds,data.streams,data.landscape_waterfall,data.grass,data.blades,data.meadow,data.blank,data._recipe_settings])

func _environment_signature() -> PackedByteArray:
	return var_to_bytes([data.ponds,data.streams,data.landscape_waterfall,data.grass,data.blades,data.meadow,data.blank,data._recipe_settings])

func _stale(record: Dictionary) -> bool:
	return not record.is_empty() and data.probe_stale(record)

## Move the instances the edit could have lifted and leave every other batch,
## colour and water surface exactly as the last full rebuild left it.
func _reuse() -> bool:
	if not _view_ready or not data is NativeTerrainData or _view_signature != _signature():
		return false
	var region: Variant = data.moved_region(_view_heights)
	if region is bool:
		return true
	if region == null:
		return false
	if _stale(_stream_probe) or _stale(_cascade_probe) or _stale(data.waterfall_probe()):
		return false
	if not data.ponds.is_empty() and data.water_reaches(region):
		return false
	_move_instances(region)
	_view_heights = data.heights.duplicate()
	return true

func _move_instances(region: Rect2) -> void:
	for batch in _batches:
		var recipes: Array = _sources[batch.get_meta("part")]
		for i in range(recipes.size()):
			var recipe: Dictionary = recipes[i]
			if not region.has_point(Vector2(recipe.x,recipe.z)):
				continue
			var moved: Variant = _instance_transform(recipe)
			if moved != null:
				batch.multimesh.set_instance_transform(i,moved)

func _instance_transform(recipe: Dictionary) -> Variant:
	if recipe.item == null:
		var height: Variant = data.ground_height(Vector2(recipe.x,recipe.z))
		if height == null:
			return null
		return Transform3D(recipe.basis,Vector3(recipe.x,height,recipe.z))
	var transform := Transform3D(recipe.basis,data.object_position(recipe.item))
	if recipe.pose != null:
		return transform*recipe.pose
	transform.origin.y += recipe.lift
	return transform

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

## Preview one committed record during an editor gesture without rebuilding
## meadow batches, terrain or water. The normal rebuild reconciles on release.
func update_object_preview(record: Dictionary) -> void:
	_instance_generation += 1
	var basis := NativeObjectPose.decode_basis(record.pose) if record.has("pose") else Basis(Vector3.UP,record.angle).scaled(Vector3.ONE*record.scale)
	var tint: Variant = NativeObjectPose.decode_tint(record.tint) if record.has("tint") else null
	for batch in _batches:
		var key: String = batch.get_meta("part")
		var sources: Array = _sources.get(key,[])
		for i in range(sources.size()):
			var source: Dictionary = sources[i]
			if source.item == null or int(source.item.id) != int(record.id):
				continue
			source.item = record.duplicate(true)
			source.basis = basis
			source.x = record.x
			source.z = record.z
			if record.asset == "rock":
				source.lift = 0.24*record.scale
			batch.multimesh.set_instance_transform(i,_instance_transform(source))
			var colored := key in ["canopy","petal","rock"]
			if _catalog_parts.has(record.asset):
				colored = _catalog_parts[record.asset].size()==1 or "canopies" in key or "flowers-" in key or "fungus-caps" in key
			batch.multimesh.set_instance_color(i,tint if tint != null and colored else _tints.get(key,Color.WHITE))
