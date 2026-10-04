class_name GardenView
extends Node3D
signal instances_published()
const HeroTrees := preload("res://scripts/hero_trees.gd")
const GrassTuft := preload("res://scripts/grass_tuft_mesh.gd")
const Undergrowth := preload("res://scripts/undergrowth_mesh.gd")
const RockVariants := preload("res://scripts/rock_variants.gd")
const Variety := preload("res://scripts/seeded_variety.gd")
## Seconds above every birth's rise (Emergence TREE_RISE and kin), where the
## instance custom a packs a stand's autumn. Mirrors ZS_RISE_SPAN.
const RISE_SPAN := 4.0
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
## This world's variant leanings (SeededVariety.world), set per rebuild.
var _variety := {}
var _sources := {}
var _object_fire := {}
var _fire_parts := {}
## The dandelion's round (scripts/dandelion_seeds.gd): record id -> its seed
## clock's state, written into its instances' colour alpha, which the flower
## material reads (`flower_cycle`). Kept across rebuilds, never saved.
var _flower_state := {}
signal object_fire_changed(id: int, value: Vector2)
## Bumped by every full rebuild, so consumers of the rendered ponds and streams
## can tell whether those meshes are the ones they last read.
var revision := 0
## Bumped whenever instance batches are replaced (new nodes), so views that
## copy scene geometry, such as planar reflections, know to copy again.
var instances_revision := 0
## The inputs the ponds, streams and falls were last built from. A rebuild
## that changes none of them (cover creeping in, say) keeps the water nodes
## and `revision`, so nothing downstream re-derives from unchanged water.
var _water_inputs := PackedByteArray()
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
var _lift_heights := PackedFloat32Array()

func _ready() -> void:
	var source: Node3D = preload("res://assets/zen_reference/geometry.scn").instantiate()
	for pair: Array in [["trunk", "mesh-8"], ["canopy", "mesh-9"], ["grass", "mesh-10"], ["stem", "flower-stems"], ["petal", "flowers-daisy"]]:
		var original: MultiMeshInstance3D = source.get_node(pair[1])
		_meshes[pair[0]] = GrassTuft.swap(pair[1], original.multimesh.mesh)
		_materials[pair[0]] = original.multimesh.mesh.surface_get_material(0).duplicate()
		if _meshes[pair[0]] != original.multimesh.mesh: GrassTuft.dress(_materials[pair[0]], _meshes[pair[0]])
		if pair[0] in ["trunk", "canopy"]:
			_materials[pair[0]].set_shader_parameter("conifer_sway", true)
	for kind in preload("res://scripts/native_asset_catalog.gd").PARTS:
		_catalog_parts[kind] = []
		for node_name in preload("res://scripts/native_asset_catalog.gd").PARTS[kind]:
			var original: Node3D = NativeAssetCatalog.source_node(source,node_name)
			var key: String = kind+":"+node_name
			_catalog_parts[kind].append(key)
			var source_mesh: Mesh = original.multimesh.mesh if original is MultiMeshInstance3D else original.mesh
			var mesh: Mesh = Undergrowth.swap(node_name,GrassTuft.swap(node_name,HeroTrees.swap(node_name,source_mesh)))
			_meshes[key] = mesh
			_materials[key] = mesh.surface_get_material(0).duplicate()
			if node_name == "mesh-10" and mesh != source_mesh: GrassTuft.dress(_materials[key], mesh)
			if node_name == "mesh-13" and mesh != source_mesh: Undergrowth.dress(_materials[key], mesh)
			_catalog_poses[key] = preload("res://scripts/native_asset_catalog.gd").part_pose(key,original,mesh)
			_tints[key] = HeroTrees.species_tint(node_name,Color.WHITE)
			if original is MultiMeshInstance3D and original.multimesh.use_colors and original.multimesh.instance_count > 0:
				_tints[key] = original.multimesh.get_instance_color(0)
	# Pines grow as the Blender spruce family: one batch pair per variant.
	var tread_pairs := [["trunk","canopy"],["broadleaf:mesh-11","broadleaf:broadleaf-canopies"],["layered_tree:layered-trunk","layered_tree:layered-canopies"],["redwood:redwood-trunk","redwood:redwood-canopies"],["birch:birch-trunk","birch:birch-canopies"],["willow:willow-trunk","willow:willow-canopies"],["juniper:juniper-trunk","juniper:juniper-deadwood","juniper:juniper-canopies"]]
	if HeroTrees.enabled():
		_catalog_parts["tree_variants"] = []
		var spruce := HeroTrees.spruce_keys()
		for i in range(spruce.size()):
			for part in range(2):
				var key: String = spruce[i][part]
				_meshes[key] = HeroTrees.spruce_mesh(i,part == 1,_materials["canopy" if part == 1 else "trunk"])
				_materials[key] = _meshes[key].surface_get_material(0)
				_tints[key] = _tints.canopy if part == 1 else Color.WHITE
				_catalog_parts["tree_variants"].append(key)
			tread_pairs.append(spruce[i])
		# Layered broadleaves grow as seeded siblings of the original tree.
		var layered: Array = ["layered_tree:layered-trunk","layered_tree:layered-canopies"]
		var seeds: Array = preload("res://scripts/layered_tree.gd").VARIANT_SEEDS
		for i in range(1,seeds.size()):
			var meshes: Array = preload("res://scripts/layered_tree.gd").variant_meshes(seeds[i])
			var pair := ["layered_tree:layered-v%d-trunk" % i,"layered_tree:layered-v%d-canopies" % i]
			for part in range(2):
				_meshes[pair[part]] = meshes[part]
				_materials[pair[part]] = meshes[part].surface_get_material(0).duplicate()
				_catalog_poses[pair[part]] = Transform3D.IDENTITY
				_tints[pair[part]] = _tints[layered[part]]
			layered.append_array(pair)
			tread_pairs.append(pair)
		_catalog_parts["layered_variants"] = layered
	_water_material = source.get_node("mesh-30").mesh.surface_get_material(0).duplicate()
	_stream_material=source.get_node("mesh-38").mesh.surface_get_material(0).duplicate()
	# Trunk and crown share a height so the restored wake bends them together.
	for keys in tread_pairs:
		var height := 0.1
		for key in keys: height = maxf(height,_meshes[key].get_aabb().end.y)
		for key in keys:
			_materials[key].set_shader_parameter("tree_tread",true)
			_materials[key].set_shader_parameter("tree_tread_height",height)
		# A trunk that does not sway bends with its swaying crown under the
		# wind tool (zs_blow_bend), so a strong gust never parts them.
		var crown: Variant = null
		for key in keys:
			if _materials[key].get_shader_parameter("sway_enabled") == true and _materials[key].get_shader_parameter("conifer_sway") != true: crown = _materials[key].get_shader_parameter("sway_shape")
		if crown != null:
			for key in keys:
				if _materials[key].get_shader_parameter("sway_enabled") != true and _materials[key].get_shader_parameter("conifer_sway") != true:
					_materials[key].set_shader_parameter("blow_enabled",true)
					_materials[key].set_shader_parameter("blow_shape",Vector2(crown.x,crown.y))
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
	# Rocks and boulders share one family of seeded faceted stones, one
	# batch per shape, all on the boulders' material.
	if RockVariants.enabled():
		var stone_material: Material = _materials["boulder_1:mesh-4"].duplicate()
		var stones := RockVariants.keys()
		for i in range(stones.size()):
			_meshes[stones[i]] = RockVariants.mesh(i,stone_material)
			_materials[stones[i]] = stone_material
			_tints[stones[i]] = Color.WHITE
		_catalog_parts["rock_variants"] = stones
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
	# The stone lamp (scripts/stone_lamp.gd): faceted stone on the stones'
	# material; its glow is scripts/stone_lamp_lights.gd's.
	_catalog_parts["stone_lamp"] = ["stone_lamp"]
	_catalog_poses["stone_lamp"] = Transform3D.IDENTITY
	_meshes["stone_lamp"] = preload("res://scripts/stone_lamp.gd").mesh()
	_materials["stone_lamp"] = rock_material.duplicate()
	# The campfire (scripts/campfire.gd): its ring of stones and laid sticks
	# on the same material; its fire is scripts/campfire_fire.gd's.
	_catalog_parts["campfire"] = ["campfire"]
	_catalog_poses["campfire"] = Transform3D.IDENTITY
	_meshes["campfire"] = preload("res://scripts/campfire.gd").mesh()
	_materials["campfire"] = rock_material.duplicate()
	# The cabin (scripts/cabin.gd): the log cabin model baked to vertex
	# colours on the same material; its windows and smoke are
	# scripts/cabin_lights.gd's.
	_catalog_parts["cabin"] = ["cabin"]
	_catalog_poses["cabin"] = Transform3D.IDENTITY
	_meshes["cabin"] = preload("res://scripts/cabin.gd").mesh()
	_materials["cabin"] = rock_material.duplicate()
	for key in _materials:
		FireMaterial.enable_instances(_materials[key])
		# Every batch has custom data; emerged instances read their birth there.
		if _materials[key] is ShaderMaterial: _materials[key].set_shader_parameter("instance_birth_enabled",true)
		_materials[key].set_shader_parameter("palette_role",preload("res://scripts/scene_look.gd").part_role(key))
		# Evergreens hold their colour; broadleaves blossom, turn and fall.
		_materials[key].set_shader_parameter("leaf_season",preload("res://scripts/scene_look.gd").leaf_season(key))
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
	_lift_heights = PackedFloat32Array()
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
	var water_inputs := var_to_bytes([data.heights,data.ponds,data.streams,data.landscape_waterfall,data.blank,data._recipe_settings]) if data is NativeTerrainData else PackedByteArray()
	if not force and _view_ready and not water_inputs.is_empty() and water_inputs == _water_inputs:
		_view_heights = data.heights.duplicate()
		_view_signature = _signature()
		_water_signature = _environment_signature()
		return true
	last_water_usec.clear()
	var water_began := Time.get_ticks_usec()
	# A yielding rebuild floods recipe ponds on a private copy first, before any
	# water node changes, so a superseded rebuild leaves the old water whole.
	# Its streams are laid on the same worker, against a private recipe.
	var recipe_water: Array = []
	var recipe_streams := {}
	if frame_tree != null and data is NativeTerrainData and data._recipe != null and ((not data.ponds.is_empty() and data._water_grid_h.size() == NativeRecipeWater.W*NativeRecipeWater.W) or (recipe_stream_worker and not data.streams.is_empty())):
		var generation := _instance_generation
		var sampled := {"heights":data.heights.duplicate(),"ponds":data.ponds.duplicate(true),"streams":data.streams.duplicate(true),"waterfall":data.landscape_waterfall}
		var built: Dictionary = await _sample_recipe_water(frame_tree)
		if generation != _instance_generation or data.heights != sampled.heights or data.ponds != sampled.ponds or data.streams != sampled.streams or data.landscape_waterfall != sampled.waterfall: return false
		recipe_water = built.ponds
		if built.has("streams"): recipe_streams = built
		last_water_usec["pond_worker"] = Time.get_ticks_usec()-water_began
		water_began = Time.get_ticks_usec()
	# A yielding rebuild of a world without a recipe (the Genesis plain) floods
	# its ponds and lays its streams on a worker too, from a detached copy.
	var plain_water := {}
	if plain_water_worker and frame_tree != null and data is NativeTerrainData and data._recipe == null and (not data.ponds.is_empty() or not data.streams.is_empty()):
		var generation := _instance_generation
		var sampled := {"heights":data.heights.duplicate(),"ponds":data.ponds.duplicate(true),"streams":data.streams.duplicate(true)}
		plain_water = await _sample_plain_water(frame_tree)
		if generation != _instance_generation or data.heights != sampled.heights or data.ponds != sampled.ponds or data.streams != sampled.streams: return false
		last_water_usec["plain_worker"] = Time.get_ticks_usec()-water_began
		water_began = Time.get_ticks_usec()
	for node in _stream_nodes: node.free()
	_stream_nodes.clear()
	_stream_probe = {}
	if data is NativeTerrainData:
		var worker_streams: Dictionary = plain_water if not plain_water.is_empty() else recipe_streams
		var geometries: Array = worker_streams.get("streams",[])
		if worker_streams.is_empty():
			var gene: Dictionary=data._palette.noise.g.water
			var ramp:=preload("res://scripts/native_recipe_water.gd").water_ramp(gene)
			data.begin_probe()
			for course in data.streams:
				geometries.append(preload("res://scripts/native_stream_geometry.gd").build(course,data.stream_ground_height,ramp))
			_stream_probe = data.end_probe()
		else:
			_stream_probe = worker_streams.probe
		for i in range(geometries.size()):
			var geometry: Dictionary = geometries[i]
			_stamp_stream_birth(geometry,data.streams[i])
			var node:=MeshInstance3D.new()
			node.name="Stream_%d" % _stream_nodes.size()
			node.mesh=preload("res://scripts/native_stream_geometry.gd").mesh(geometry)
			node.material_override=_stream_material
			add_child(node)
			_stream_nodes.append(node)
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
	var ponds: Dictionary = plain_water.get("ponds",{})
	if ponds.is_empty():
		ponds = sample_ponds(data,data.ponds,recipe_water)
	last_water_usec["pond_samples"] = Time.get_ticks_usec()-water_began
	water_began = Time.get_ticks_usec()
	pond_vertices = ponds.vertices
	_water.mesh = null
	if not pond_vertices.is_empty():
		var arrays: Array = plain_water.pond_arrays if plain_water.has("pond_arrays") else pond_arrays(ponds,_pond_births(data.ponds))
		var surface := ArrayMesh.new()
		surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},POND_FORMAT)
		_water.mesh = surface
	_water_material.set_shader_parameter("pond_fill_seconds",WaterBrush.FILL_SECONDS)
	last_water_usec["pond_publish"] = Time.get_ticks_usec()-water_began
	revision += 1
	_water_inputs = water_inputs
	if data is NativeTerrainData:
		_view_heights = data.heights.duplicate()
		_view_signature = _signature()
		_water_signature = _environment_signature()
		_view_ready = true

	return true

## Custom channels of the pond mesh: shore fetch in eight directions.
const POND_FORMAT := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
const WaterBrush := preload("res://scripts/water_brush.gd")
## Water the water brush has just laid down, keyed by `water_key(record)`:
## {"born", "drop"} for a pond rising `drop` metres from `born`, {"born",
## "seconds"} for a stream whose front runs its length in `seconds`. Times are
## on the emergence clock. Like cover births, these only animate: they are not
## saved or undone, and a missing one reads as full.
var water_births := {}
## False keeps a plain world's water on the main thread, for profiling.
var plain_water_worker := true
## False lays a recipe world's streams on the main thread again (the old path).
var recipe_stream_worker := true
var _worker_recipe: RefCounted
var _worker_recipe_key := PackedByteArray()

static func water_key(record: Dictionary) -> String:
	return var_to_bytes(record).hex_encode().md5_text()

## Every pond's surface triangles, depths, colours and shore fetch, with the
## vertex count of each pond. `recipe_water` may carry prepared recipe ponds.
static func sample_ponds(source: RefCounted, ponds: Array, recipe_water: Array = []) -> Dictionary:
	var vertices_out := PackedVector3Array()
	var pond_depths:=PackedFloat32Array()
	var pond_colors:=PackedColorArray()
	var pond_fetch_a:=PackedColorArray()
	var pond_fetch_b:=PackedColorArray()
	var counts := PackedInt32Array()
	# Adjacent triangles share vertices. Shore-distance sampling is identical at
	# those points within this rebuild, regardless of which triangle owns them.
	var fetch_by_vertex := {}
	for pond_index in range(ponds.size()):
		var pond: Dictionary = ponds[pond_index]
		var before := vertices_out.size()
		if source is NativeTerrainData and source._recipe != null:
			var water: Dictionary=recipe_water[pond_index] if not recipe_water.is_empty() else preload("res://scripts/native_recipe_water.gd").build(source,pond)
			vertices_out.append_array(water.vertices)
			pond_depths.append_array(water.depths)
			pond_colors.append_array(water.colors)
			pond_fetch_a.append_array(water.fetch_a)
			pond_fetch_b.append_array(water.fetch_b)
		else:
			var vertices: PackedVector3Array=source.pond_surface(pond)
			vertices_out.append_array(vertices)
			for point in vertices:
				var depth:=maxf(0.0,point.y-float(source.ground_height(Vector2(point.x,point.z))))
				pond_depths.append(depth)
				if not fetch_by_vertex.has(point):
					fetch_by_vertex[point] = source.pond_fetch(Vector2(point.x,point.z),point.y)
				var fetch: PackedFloat32Array=fetch_by_vertex[point]
				pond_fetch_a.append(Color(fetch[0],fetch[1],fetch[2],fetch[3]))
				pond_fetch_b.append(Color(fetch[4],fetch[5],fetch[6],fetch[7]))
				pond_colors.append(Color("79ae9b").lerp(Color("245a5c"),1.0-exp(-depth/0.45)).srgb_to_linear())
		counts.append(vertices_out.size()-before)
	return {"vertices":vertices_out,"depths":pond_depths,"colors":pond_colors,"fetch_a":pond_fetch_a,"fetch_b":pond_fetch_b,"counts":counts}

## Mesh arrays for sampled ponds. UV carries each pond's fill (x its birth,
## y how far it rises); a pond without one reads (0, 0) and stands full.
static func pond_arrays(sampled: Dictionary, fills: PackedVector2Array) -> Array:
	var vertices: PackedVector3Array = sampled.vertices
	var count := vertices.size()
	var normals := PackedVector3Array()
	normals.resize(count)
	normals.fill(Vector3.UP)
	var uv := PackedVector2Array()
	uv.resize(count)
	var uv2 := PackedVector2Array()
	uv2.resize(count)
	var custom0 := PackedFloat32Array()
	custom0.resize(count*4)
	var custom1 := PackedFloat32Array()
	custom1.resize(count*4)
	var depths: PackedFloat32Array = sampled.depths
	var fetch_a: PackedColorArray = sampled.fetch_a
	var fetch_b: PackedColorArray = sampled.fetch_b
	var counts: PackedInt32Array = sampled.counts
	var at := 0
	for pond_index in range(counts.size()):
		var fill := fills[pond_index] if pond_index < fills.size() else Vector2.ZERO
		for i in range(at,at+counts[pond_index]): uv[i] = fill
		at += counts[pond_index]
	for i in range(count):
		uv2[i] = Vector2(depths[i],0.0)
		var a := fetch_a[i]
		var b := fetch_b[i]
		custom0[i*4] = a.r
		custom0[i*4+1] = a.g
		custom0[i*4+2] = a.b
		custom0[i*4+3] = a.a
		custom1[i*4] = b.r
		custom1[i*4+1] = b.g
		custom1[i*4+2] = b.b
		custom1[i*4+3] = b.a
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = sampled.colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_CUSTOM0] = custom0
	arrays[Mesh.ARRAY_CUSTOM1] = custom1
	return arrays

## Per pond: its fill birth and rise, from `water_births`. Births long past are
## dropped, so the table only holds water still animating.
func _pond_births(ponds: Array) -> PackedVector2Array:
	var now: float = preload("res://scripts/emergence.gd").time
	for key in water_births.keys():
		if float(water_births[key].born) < now-30.0: water_births.erase(key)
	var fills := PackedVector2Array()
	for pond: Dictionary in ponds:
		var birth: Dictionary = water_births.get(water_key(pond),{}) if not water_births.is_empty() else {}
		fills.append(Vector2(float(birth.born),float(birth.drop)) if birth.has("drop") else Vector2.ZERO)
	return fills

## A new stream runs its front down its length from its birth: CUSTOM1 z/w
## (the stream shader reads them beside the global water growth).
func _stamp_stream_birth(geometry: Dictionary, course: Dictionary) -> void:
	if water_births.is_empty(): return
	var birth: Dictionary = water_births.get(water_key(course),{})
	if not birth.has("seconds"): return
	var run: PackedColorArray = geometry.run
	for i in range(run.size()):
		run[i].b = float(birth.born)
		run[i].a = float(birth.seconds)
	geometry.run = run

## Streams and ponds of a world without a recipe, sampled on a worker from a
## detached height copy. The stream probe records the same vertex reads a
## main-thread build would, so later reuse checks stay exact.
func _sample_plain_water(frame_tree: SceneTree) -> Dictionary:
	var detached: NativeTerrainData = preload("res://scripts/native_terrain_snapshot.gd").for_height(data)
	detached._recipe_heights = data._recipe_heights.duplicate()
	var ponds: Array = data.ponds.duplicate(true)
	var streams: Array = data.streams.duplicate(true)
	var ramp := NativeRecipeWater.water_ramp(data._palette.noise.g.water)
	var fills := _pond_births(ponds)
	var job = preload("res://scripts/background_work.gd").new()
	return await job.run(func() -> Dictionary:
		var geometries := []
		detached.begin_probe()
		for course: Dictionary in streams:
			geometries.append(preload("res://scripts/native_stream_geometry.gd").build(course,detached.stream_ground_height,ramp))
		var probe := detached.end_probe()
		var sampled := sample_ponds(detached,ponds)
		var arrays := pond_arrays(sampled,fills) if not sampled.vertices.is_empty() else []
		return {"streams":geometries,"probe":probe,"ponds":sampled,"pond_arrays":arrays},frame_tree)

## Every recipe pond's surface, built from a detached height copy on a worker.
## The impacts and colour ramp read the live recipe, so they are taken here.
## The streams are laid there too (they were 4.2 ms on the main thread), against
## a private recipe: recipes are pure functions of their settings, so its
## heights are the live recipe's to the bit, and the stream probe records the
## same vertex reads a main-thread build would. Returns {"ponds"} and, when
## streams were laid, {"streams", "probe"}.
func _sample_recipe_water(frame_tree: SceneTree) -> Dictionary:
	var detached: NativeTerrainData = preload("res://scripts/native_terrain_snapshot.gd").for_height(data)
	detached._recipe_heights = data._recipe_heights.duplicate()
	detached._water_grid_h = data._water_grid_h.duplicate()
	detached.streams.assign(data.streams.duplicate(true))
	var ponds: Array = data.ponds.duplicate(true) if data._water_grid_h.size() == NativeRecipeWater.W*NativeRecipeWater.W else []
	var prepared := {"impacts":data.waterfall_impacts(),"ramp":NativeRecipeWater.water_ramp(data._recipe.source.g.get("water",{}))}
	var settings: Dictionary = data._recipe_settings.duplicate(true)
	var key := var_to_bytes(settings)
	var lay_streams := recipe_stream_worker and not detached.streams.is_empty()
	# One private recipe is kept between rebuilds; a job checks it out, so two
	# overlapping jobs never share one (a second builds its own).
	var recipe: RefCounted = null
	if lay_streams and _worker_recipe_key == key:
		recipe = _worker_recipe
		_worker_recipe = null
	var stream_ramp := NativeRecipeWater.water_ramp(data._palette.noise.g.water)
	var job = preload("res://scripts/background_work.gd").new()
	var result: Dictionary = await job.run(func() -> Dictionary:
		var built := []
		for pond: Dictionary in ponds:
			built.append(NativeRecipeWater.build(detached,pond,prepared))
		var found := {"ponds":built}
		if lay_streams:
			detached._recipe = recipe if recipe != null else preload("res://scripts/native_terrain_recipe.gd").new(settings)
			var geometries := []
			detached.begin_probe()
			for course: Dictionary in detached.streams:
				geometries.append(preload("res://scripts/native_stream_geometry.gd").build(course,detached.stream_ground_height,stream_ramp))
			found.streams = geometries
			found.probe = detached.end_probe()
			found.recipe = detached._recipe
		return found,frame_tree)
	if result.has("recipe"):
		# Check the private recipe back in while it still matches this world.
		if data is NativeTerrainData and var_to_bytes(data._recipe_settings) == key:
			_worker_recipe = result.recipe
			_worker_recipe_key = key
		result.erase("recipe")
	return result

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
	_variety = Variety.world(data._recipe_settings if data is NativeTerrainData else {})
	var variety: Dictionary = _variety.duplicate(true)
	var action := func() -> Dictionary:
		var built: Dictionary = preload("res://scripts/garden_instance_samples.gd").build(input,parts,poses,tints,variety)
		built.buffers = GardenView._pack(built,tints)
		return built
	var job = preload("res://scripts/background_work.gd").new()
	last_instance_usec.snapshot = Time.get_ticks_usec()-stage_start
	stage_start = Time.get_ticks_usec()
	var sampled: Dictionary = await job.run(action,worker_tree)
	if worker_tree != null: _instance_busy = false
	last_instance_usec.worker_elapsed = Time.get_ticks_usec()-stage_start
	stage_start = Time.get_ticks_usec()
	if not current.call(): return false
	last_instance_usec.prepare_elapsed = Time.get_ticks_usec()-stage_start
	stage_start = Time.get_ticks_usec()
	# Publish in one frame: each part keeps its batch node and takes its new
	# instances as one buffer the worker packed. Consumers see sources and
	# instance indices change together, and views that share a batch's
	# MultiMesh (the water's reflection copies) follow without copying again.
	# Only a part appearing or going away changes the node set.
	var buffers: Dictionary = sampled.buffers
	var kept := {}
	for batch in _batches: kept[batch.get_meta("part")] = batch
	var published: Array[MultiMeshInstance3D] = []
	var nodes_changed := false
	for key: String in sampled.transforms:
		var count: int = (sampled.transforms[key] as Array).size()
		if count == 0: continue
		var batch: MultiMeshInstance3D = kept.get(key)
		if batch == null:
			batch = _new_batch(key)
			add_child(batch)
			nodes_changed = true
		kept.erase(key)
		batch.multimesh.instance_count = count
		batch.multimesh.buffer = buffers[key]
		published.append(batch)
	for batch: MultiMeshInstance3D in kept.values():
		batch.free()
		nodes_changed = true
	_batches = published
	_sources = sampled.sources
	_index_fire_parts()
	# The batches now draw every record, those painted this stroke too.
	clear_paint_preview()
	if nodes_changed: instances_revision += 1
	instances_published.emit()
	last_instance_usec.swap = Time.get_ticks_usec()-stage_start
	return true

## A batch for part `key`, not yet in the tree.
func _new_batch(key: String) -> MultiMeshInstance3D:
	var batch := MultiMeshInstance3D.new()
	batch.name = key.capitalize()
	batch.set_meta("part", key)
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.use_colors = true
	batch.multimesh.use_custom_data = true
	batch.multimesh.mesh = _meshes[key]
	batch.material_override = _materials[key]
	# The painted meadow tufts are many and small; their shadows would not
	# resolve, so they skip the shadow pass, as the dense grass does.
	if key == "grass": batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Meadow flowers (docs/scenic/flowers.md, Cost): only the tall kinds
	# cast a shadow that reads, and the low ones are specks in a pond.
	var flower_kind := preload("res://scripts/meadow_flower_mesh.gd").kind_of_part(key)
	if not flower_kind.is_empty():
		if not preload("res://scripts/meadow_flower_mesh.gd").casts_shadow(flower_kind): batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not preload("res://scripts/meadow_flower_mesh.gd").reflects(flower_kind): batch.set_meta("skip_reflection",true)
	return batch

# --- The paint preview ------------------------------------------------------------
## Flowers painted from the hand (scripts/flower_paint.gd) show the frame they
## are placed, without a rebuild: their records are drawn into small batches
## of their own (`_paint`, one per part, on the same meshes and materials,
## custom data and all, so they grow in as any birth does), and records thinned
## away are folded to nothing where they stand in the live batches. The next
## publish of the full batches draws (or drops) them there and clears this.
## Part -> {"batch": MultiMeshInstance3D, "buffer": PackedFloat32Array}.
var _paint := {}
## Record id -> [[batch, index]] for what the preview draws of it.
var _paint_parts := {}
var _paint_layer: Node3D
## Instances the preview has drawn and hidden, for probes.
var paint_drawn := 0
var paint_hidden := 0

## Draws `records` (object records already in `data`) at once.
func paint_preview(records: Array) -> void:
	if records.is_empty(): return
	if _paint_layer == null:
		_paint_layer = Node3D.new()
		_paint_layer.name = "PaintPreview"
		add_child(_paint_layer)
	const Flowers = preload("res://scripts/meadow_flower_mesh.gd")
	var remap := Flowers.remap_enabled() and _catalog_parts.has(Flowers.KINDS[0])
	var sampled := {"transforms":{},"tints":{},"sources":{}}
	for record: Dictionary in records:
		preload("res://scripts/garden_instance_samples.gd").add_item(record,data,_catalog_parts,_catalog_poses,_tints,_variety,remap,sampled.transforms,sampled.sources,sampled.tints)
	var buffers := GardenView._pack(sampled,_tints)
	for key: String in buffers:
		if not _meshes.has(key): continue
		var entry: Dictionary = _paint.get(key,{})
		if entry.is_empty():
			var batch := _new_batch(key)
			batch.name = "Paint"+batch.name
			_paint_layer.add_child(batch)
			entry = {"batch":batch,"buffer":PackedFloat32Array()}
			_paint[key] = entry
		var buffer: PackedFloat32Array = entry.buffer
		var first := buffer.size()/20
		buffer.append_array(buffers[key])
		entry.buffer = buffer
		var multimesh: MultiMesh = entry.batch.multimesh
		multimesh.instance_count = buffer.size()/20
		multimesh.buffer = buffer
		var sources: Array = sampled.sources[key]
		for i in range(sources.size()):
			var item: Variant = sources[i].item
			if item == null: continue
			_paint_parts.get_or_add(int(item.id),[]).append([entry.batch,first+i,sources[i].get("color",Color.WHITE)])
			if _flower_state.has(int(item.id)): _write_state(int(item.id))
		paint_drawn += sources.size()

## Folds the instances of records `ids` to nothing, in the live batches and
## the preview's, until the next publish drops them.
func paint_hide(ids: Array) -> void:
	var gone := Transform3D(Basis().scaled(Vector3.ZERO),Vector3.ZERO)
	for id in ids:
		for part: Dictionary in _fire_parts.get(int(id),[]):
			var batch: MultiMeshInstance3D = part.batch
			if is_instance_valid(batch) and batch.multimesh != null and int(part.index) < batch.multimesh.instance_count:
				batch.multimesh.set_instance_transform(int(part.index),gone)
				paint_hidden += 1
		for pair: Array in _paint_parts.get(int(id),[]):
			var batch: MultiMeshInstance3D = pair[0]
			if not is_instance_valid(batch): continue
			var entry: Dictionary = _paint.get(str(batch.get_meta("part")),{})
			if entry.is_empty(): continue
			var buffer: PackedFloat32Array = entry.buffer
			var o: int = int(pair[1])*20
			for k in range(12): buffer[o+k] = 0.0
			entry.buffer = buffer
			batch.multimesh.set_instance_transform(int(pair[1]),gone)
			paint_hidden += 1

## Instances the preview draws now.
func paint_preview_count() -> int:
	var count := 0
	for entry: Dictionary in _paint.values(): count += (entry.buffer as PackedFloat32Array).size()/20
	return count

func clear_paint_preview() -> void:
	for entry: Dictionary in _paint.values():
		if is_instance_valid(entry.batch): entry.batch.free()
	_paint.clear()
	_paint_parts.clear()

## Every part's instances as one MultiMesh buffer (transform, colour, custom
## data: 20 floats each), on the worker. Colours land in the sources as the
## per-instance writes left them; custom data carries emerged births.
static func _pack(sampled: Dictionary, tints: Dictionary) -> Dictionary:
	var buffers := {}
	for key: String in sampled.transforms:
		var placements: Array = sampled.transforms[key]
		if placements.is_empty(): continue
		var colors: Array = sampled.tints[key]
		var sources: Array = sampled.sources[key]
		var buffer := PackedFloat32Array()
		buffer.resize(placements.size()*20)
		for i in range(placements.size()):
			var t: Transform3D = placements[i]
			var color: Color = colors[i] if i < colors.size() else tints.get(key, Color.WHITE)
			sources[i]["color"] = color
			var custom := _custom(sources[i],Vector2.ZERO) if sources[i].has("born") or sources[i].has("autumn") else Color(0,0,0,0)
			var o := i*20
			buffer[o] = t.basis.x.x; buffer[o+1] = t.basis.y.x; buffer[o+2] = t.basis.z.x; buffer[o+3] = t.origin.x
			buffer[o+4] = t.basis.x.y; buffer[o+5] = t.basis.y.y; buffer[o+6] = t.basis.z.y; buffer[o+7] = t.origin.y
			buffer[o+8] = t.basis.x.z; buffer[o+9] = t.basis.y.z; buffer[o+10] = t.basis.z.z; buffer[o+11] = t.origin.z
			buffer[o+12] = color.r; buffer[o+13] = color.g; buffer[o+14] = color.b; buffer[o+15] = color.a
			buffer[o+16] = custom.r; buffer[o+17] = custom.g; buffer[o+18] = custom.b; buffer[o+19] = custom.a
		buffers[key] = buffer
	return buffers

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
	for id: int in _flower_state.keys():
		if _fire_parts.has(id): _write_state(id)
		else: _flower_state.erase(id)

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

## The seed clock `id`'s state in the dandelion's round (the flower
## material's `flower_cycle`): 1 whole, 1 + f with a share f of its seeds
## blown, 4 + t gone bare at t. Written into its instances without a rebuild.
func set_flower_state(id: int, state: float) -> void:
	if is_equal_approx(float(_flower_state.get(id,1.0)),state): return
	if is_equal_approx(state,1.0): _flower_state.erase(id)
	else: _flower_state[id] = state
	_write_state(id)

func flower_state(id: int) -> float:
	return float(_flower_state.get(id,1.0))

func _write_state(id: int) -> void:
	var state := float(_flower_state.get(id,1.0))
	for part: Dictionary in _fire_parts.get(id,[]):
		var batch: MultiMeshInstance3D = part.batch
		if not is_instance_valid(batch) or batch.multimesh == null or int(part.index) >= batch.multimesh.instance_count: continue
		var source: Dictionary = _sources[batch.get_meta("part")][part.index]
		var color: Color = source.get("color",Color.WHITE)
		batch.multimesh.set_instance_color(int(part.index),Color(color.r,color.g,color.b,state))
	for pair: Array in _paint_parts.get(id,[]):
		var batch: MultiMeshInstance3D = pair[0]
		if not is_instance_valid(batch): continue
		var color: Color = pair[2] if pair.size() > 2 else Color.WHITE
		batch.multimesh.set_instance_color(int(pair[1]),Color(color.r,color.g,color.b,state))

## Fire state for one record, (0, 0) when it never burnt.
func object_fire(id: int) -> Vector2:
	return _object_fire.get(id,Vector2.ZERO)

func _write_fire(id: int, char: float, burn: float) -> void:
	for part: Dictionary in _fire_parts.get(id,[]):
		var batch: MultiMeshInstance3D = part.batch
		if is_instance_valid(batch) and batch.multimesh != null and batch.multimesh.use_custom_data:
			var source: Dictionary = _sources[batch.get_meta("part")][part.index]
			batch.multimesh.set_instance_custom_data(part.index,_custom(source,Vector2(char,burn)))

## One instance's custom data: fire (char, burn) in rg, and the emerged birth
## (born, rise seconds) in ba. The birth comes from the source, never read back
## from the MultiMesh, which could stall on the GPU. An emerged tree's stand
## autumn rides in a above the rise, in whole RISE_SPANs of 1 + 15 * autumn, so
## a (no stand) is the rise alone (zs_instance_rise, zs_instance_autumn in
## shaders/reference_globals.gdshaderinc).
static func _custom(source: Dictionary, fire: Vector2) -> Color:
	var stand := 1.0+roundf(15.0*float(source.autumn)) if source.has("autumn") else 0.0
	return Color(fire.x,fire.y,float(source.get("born",0.0)),float(source.get("rise",0.0))+RISE_SPAN*stand)

func discard_cache() -> void:
	cancel_rebuild()
	_view_ready = false
	_water_inputs = PackedByteArray()

func cancel_rebuild() -> void:
	_instance_generation += 1

## What the instance batches are built from. The grass mask is not in it: it
## colours terrain faces (and the GPU-placed dense grass) but places no
## instance, so painting cover, a brush stroke or emergence's creep never
## rebuilds every MultiMesh. Standing blades and meadow tufts are instances.
func _signature() -> PackedByteArray:
	return var_to_bytes([data.objects_revision,data.objects.size(),data.ponds,data.streams,data.landscape_waterfall,data.blades,data.meadow,data.blank,data._recipe_settings])

## What the water, streams and falls are built from. Cover masks place no
## water, so a cover change rebuilds instances only and keeps `revision`
## (planar water, leaf litter and the surface maps key on it).
func _environment_signature() -> PackedByteArray:
	return var_to_bytes([data.ponds,data.streams,data.landscape_waterfall,data.blank,data._recipe_settings])

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

## A held brush lifts plants and props under each dab and leaves everything
## else - water, cover batches and the cached view state - for the rebuild at
## stroke end. That rebuild still diffs from the heights of the last full one,
## so it repeats these lifts over the whole stroke and lands where it would have.
func lift_instances() -> bool:
	if not _view_ready or not data is NativeTerrainData: return false
	var region: Variant = data.moved_region(_lift_heights if _lift_heights.size() == data.heights.size() else _view_heights)
	if region is Rect2: _move_instances(region)
	elif region == null: return false
	_lift_heights = data.heights.duplicate()
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
	if tint != null and preload("res://scripts/meadow_flower_mesh.gd").SPEC.has(record.asset):
		tint = preload("res://scripts/meadow_flower_mesh.gd").instance_color(record.asset,tint)
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
			if key.begins_with("boulder_stone:"):
				batch.multimesh.set_instance_color(i,RockVariants.color(record,tint,_variety))
				continue
			var colored := key in ["canopy","petal","rock"] or (key.begins_with("tree:") and "canopies" in key)
			if _catalog_parts.has(record.asset):
				colored = _catalog_parts[record.asset].size()==1 or "canopies" in key or "flowers-" in key or "fungus-caps" in key
			batch.multimesh.set_instance_color(i,tint if tint != null and colored else _tints.get(key,Color.WHITE))
