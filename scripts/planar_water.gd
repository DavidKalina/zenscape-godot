extends Node3D
## Live reflected pond views. Rebuild on content changes; synchronize moving
## geometry, local material settings, lighting and camera without duplicating gameplay.
var views: Array[Dictionary] = []
var source_water: MeshInstance3D
var camera: Camera3D
var _shader_cache := {}
var _used_shaders := {}
var _bindings: Array[Dictionary] = []
var _material_bindings := {}
var _used_material_bindings := {}
var revision := -1
var objects_revision := -1
var enabled := true
var _scene: Node3D
var _setup_busy := false
var _setup_generation := 0
var _initial_ready := false
## Each view renders the scene again, so only the ponds with the most surface
## get one; the rest keep the ordinary water surface.
const MAX_VIEWS := 2
## The views a re-setup replaces. They keep rendering and following the camera
## until the new set is ready, so a water change neither stalls a frame nor
## drops the reflections while the new views are prepared over a few frames.
var _retired := {}
## False restores the old synchronous re-setup, for before/after profiling.
var live_resetup := true
## GardenView.instances_revision last copied into the views.
var instances_revision := -1
## "setup" while views are prepared, "geometry" while their copies are.
var _busy_kind := ""
## Copies a live geometry refresh replaces, dropped once the new ones stand.
var _old_bindings: Array[Dictionary] = []
signal setup_frame
## Copied materials follow their sources without re-reading every parameter
## each frame (that was about 4.6 ms with ponds on the plain). Parameters
## seen to change are re-read every frame; the rest are checked a rolling
## DISCOVERY_READS at a time (about 20 frames round the plain's 84 sources),
## so a parameter's first change shows a moment late and later ones at once.
## Copies of one source share one record (`_material_groups`).
const DISCOVERY_READS := 300
var _material_groups: Array[Dictionary] = []
var _groups_dirty := true
## Group key -> {"values", "live", "cursor"}, kept across regroupings.
var _group_state := {}
var _discover_group := 0
## Source shader instance id -> whether copies of it clip (it has a fragment
## function reading world_position). Shader code does not change at runtime.
var _clips := {}
## Clip shaders compile ahead, in idle frames once the scene has grown, so the
## session's first pour does not pay 4-7 ms a shader while it settles.
var _warm_started := false
var warm_ready := false

func _ready() -> void:
	get_tree().process_frame.connect(_advance_setup_frame)

func _advance_setup_frame() -> void:
	# Waiting on this node's signal makes pending setup disappear with its
	# owner. The tree's longer-lived signal must not resume a freed node.
	setup_frame.emit()

func sync(scene: Node3D, frame_tree: SceneTree = null) -> void:
	_scene = scene
	var content: GardenView = scene._chunk_editor.content
	var data: NativeTerrainData = scene._chunk_editor.data
	var geometry_moved: bool = objects_revision != data.objects_revision or instances_revision != content.instances_revision
	if _setup_busy:
		if frame_tree == null:
			# Explicit synchronous callers supersede pending preparation.
			clear(true)
			revision = -1
		elif _busy_kind == "setup" or (revision == content.revision and not geometry_moved):
			# Keep what shows following the camera until the new work is ready.
			if enabled:
				if not _retired.is_empty(): _update_view_list(_retired.views,_retired.bindings)
				elif _busy_kind == "geometry": _update_view_list(views,_old_bindings)
			return
	if not enabled:
		clear()
		revision = -1
		return
	if revision != content.revision and scene._chunk_editor.water_pouring:
		_hold(data)
		return
	if revision != content.revision:
		# Geometry changes retain compiled clip shaders for surviving pond levels.
		# A live re-setup keeps the old views showing until the new ones are
		# ready; a synchronous caller or a first setup starts clean.
		if not live_resetup and _initial_ready: frame_tree = null
		if frame_tree != null and _initial_ready and (not views.is_empty() or not _retired.is_empty()):
			if _retired.is_empty(): _retire()
			else: _drop_partial()
		else: clear(true)
		revision = content.revision
		objects_revision = data.objects_revision
		instances_revision = content.instances_revision
		if content._water.mesh != null and not data.ponds.is_empty():
			# Setup is spread over frames whenever the caller is live. The first
			# keeps the original water visible while preparing all reflected
			# levels; later ones keep the previous views (see `_retired`).
			var generation := _setup_generation
			_setup_busy = true
			_busy_kind = "setup"
			var accepted := await setup(scene,content._water,frame_tree)
			if generation != _setup_generation: return
			_setup_busy = false
			if not accepted or not enabled or revision != content.revision:
				if enabled and frame_tree != null and not _retired.is_empty(): _drop_partial()
				else: clear(true)
				revision = -1
				return
			_release_retired()
			_initial_ready = true
		else:
			_release_retired()
		_prune_shaders()
	elif geometry_moved:
		objects_revision = data.objects_revision
		instances_revision = content.instances_revision
		if frame_tree != null and live_resetup and not views.is_empty():
			if not await _refresh_geometry_live(scene,frame_tree): return
		else: _refresh_geometry(scene)
	if not _warm_started and enabled and scene._growth.terrain >= 0.995:
		_warm_started = true
		_warm_shaders(scene)
	var active: bool = enabled and RenderingServer.get_current_rendering_method() == "forward_plus" and scene._growth.terrain >= 0.995 and scene._growth.water >= 0.995 and scene.can_process()
	set_enabled(active)
	if active: update_views()

## Props and plants replace instance batches, not the water or its views. A
## live refresh copies the new geometry over a few frames beside the old
## copies, then drops the old ones; a newer change restarts it.
func _refresh_geometry_live(scene: Node3D, frame_tree: SceneTree) -> bool:
	_setup_generation += 1
	var generation := _setup_generation
	if _old_bindings.is_empty(): _old_bindings = _bindings
	else:
		for binding in _bindings:
			if is_instance_valid(binding.copy): binding.copy.free()
	_bindings = []
	_used_material_bindings.clear()
	_used_shaders.clear()
	_setup_busy = true
	_busy_kind = "geometry"
	for view in views:
		if not await _copy_geometry(scene,view.viewport,view.level,frame_tree): return false
		if generation != _setup_generation: return false
	_setup_busy = false
	for binding in _old_bindings:
		if is_instance_valid(binding.copy): binding.copy.free()
	_old_bindings = []
	for key in _material_bindings.keys():
		if not str(key).begins_with("pond:") and not _used_material_bindings.has(key): _material_bindings.erase(key)
	_groups_dirty = true
	_prune_shaders()
	return true

## While a pour shows (NativeChunkEditor.water_pouring) its ponds change every
## replan, and a re-setup each time would never finish. The views keep the
## levels still standing; a pond whose level moved shows the ordinary surface
## until the pour closes and the views re-setup once.
func _hold(data: NativeTerrainData) -> void:
	var list: Array = views if not views.is_empty() else _retired.get("views",[])
	var marks := Vector2(-1000000.0,-1000000.0)
	for i in range(list.size()):
		var standing := false
		for pond: Dictionary in data.ponds: standing = standing or float(pond.level) == float(list[i].level)
		if list[i].surface.visible != standing: list[i].surface.visible = standing
		list[i].viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if standing and visible else SubViewport.UPDATE_DISABLED
		if standing and i < 2: marks[i] = list[i].level
	if is_instance_valid(source_water): source_water.material_override.set_shader_parameter("planar_levels",marks)
	if visible: _update_view_list(list,_bindings if is_same(list,views) else _retired.get("bindings",[]))

## Free a superseded re-setup's half-built views, keeping the retired ones.
func _drop_partial() -> void:
	_setup_generation += 1
	_setup_busy = false
	var keep := {}
	for node: Node in _retired.get("nodes",[]): keep[node] = true
	for child in get_children():
		if not keep.has(child):
			remove_child(child)
			child.queue_free()
	views = []
	_bindings = []

## Props replace instance batches, not the water or its render configuration.
## Preserve viewports and compiled shaders instead of paying pipeline creation
## costs again for every flower placement and every selected-object drag.
func _refresh_geometry(scene: Node3D) -> void:
	for binding in _bindings:
		if is_instance_valid(binding.copy): binding.copy.free()
	_bindings.clear()
	_used_material_bindings.clear()
	_used_shaders.clear()
	for view in views:
		_copy_geometry(scene,view.viewport,view.level)
	for key in _material_bindings.keys():
		if not str(key).begins_with("pond:") and not _used_material_bindings.has(key): _material_bindings.erase(key)
	_groups_dirty = true
	_prune_shaders()

## Set the current views aside, still rendering, for a re-setup to replace.
func _retire() -> void:
	_setup_generation += 1
	_setup_busy = false
	_retired = {"nodes":get_children(),"views":views,"bindings":_old_bindings+_bindings}
	views = []
	_bindings = []
	_old_bindings = []
	_used_material_bindings.clear()
	_used_shaders.clear()

func _release_retired() -> void:
	if _retired.is_empty(): return
	for node: Node in _retired.nodes:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	_retired = {}

func clear(keep_shaders := false) -> void:
	_release_retired()
	_setup_generation += 1
	_setup_busy = false
	revision = -1
	objects_revision = -1
	instances_revision = -1
	_old_bindings = []
	if is_instance_valid(source_water):
		source_water.material_override.set_shader_parameter("hide_pool_surface", false)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	views.clear()
	_bindings.clear()
	_material_bindings.clear()
	_used_material_bindings.clear()
	_used_shaders.clear()
	_groups_dirty = true
	if not keep_shaders:
		_shader_cache.clear()
		_initial_ready = false
		_warm_started = false
		warm_ready = false

## Compiled clip shaders stay while their source shader lives, so a pond that
## drains and fills again, or a stream that comes back, compiles nothing.
func _prune_shaders() -> void:
	for key in _shader_cache.keys():
		if not _used_shaders.has(key) and not is_instance_id_valid(int(key)): _shader_cache.erase(key)
	for key in _clips.keys():
		if not is_instance_id_valid(key): _clips.erase(key)

func _exit_tree() -> void:
	if is_instance_valid(source_water):
		source_water.material_override.set_shader_parameter("hide_pool_surface", false)


func setup(scene: Node3D, water_node: MeshInstance3D, frame_tree: SceneTree = null) -> bool:
	_scene = scene
	camera = scene.camera
	source_water = water_node
	var generation := _setup_generation
	var content_revision: int = scene._chunk_editor.content.revision
	var props_revision: int = scene._chunk_editor.data.objects_revision
	# Begin after the caller's first weather/audio/scene initialization frame.
	if frame_tree != null:
		await setup_frame
		if not _setup_current(generation,content_revision,props_revision): return false
	var budget = preload("res://scripts/frame_work_budget.gd").new(frame_tree,setup_frame)
	var source_mesh: ArrayMesh = water_node.mesh
	var levels := _view_levels(source_mesh,scene._chunk_editor.data.ponds)
	for level: float in levels:
		var pool := _pool_mesh(source_mesh, level)
		if pool == null: continue
		var viewport := SubViewport.new()
		viewport.size = Vector2i(512,320)
		viewport.own_world_3d = true
		# Godot tracks one MSAA level for pipeline precompilation. Mixed levels
		# make newly visible/placed geometry fall back to compiling while drawn.
		viewport.msaa_3d = scene.get_viewport().msaa_3d
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(viewport)
		var environment := WorldEnvironment.new()
		environment.environment = scene._environment.duplicate()
		environment.environment.volumetric_fog_enabled = false
		environment.environment.ssr_enabled = false
		viewport.add_child(environment)
		if not await _copy_geometry(scene,viewport,level,frame_tree): return false
		if not _setup_current(generation,content_revision,props_revision): return false
		for light in scene._lights:
			var copy := DirectionalLight3D.new()
			copy.transform = light.global_transform
			copy.light_color = light.light_color
			copy.light_energy = light.light_energy
			copy.shadow_enabled = false # Reflected silhouettes matter more than a second set of 8K shadow maps.
			copy.directional_shadow_mode = light.directional_shadow_mode
			copy.directional_shadow_max_distance = 80.0
			copy.shadow_normal_bias = light.shadow_normal_bias
			viewport.add_child(copy)
		var mirror := Camera3D.new()
		viewport.add_child(mirror)
		mirror.current = true
		var surface := MeshInstance3D.new()
		surface.visible = false
		surface.mesh = pool
		# The reflected surface lives under this node, including in parked chunks.
		surface.transform = global_transform.affine_inverse()*water_node.global_transform
		surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material: ShaderMaterial = water_node.material_override.duplicate()
		material.set_shader_parameter("hide_pool_surface", false)
		material.set_shader_parameter("planar_enabled", true)
		material.set_shader_parameter("caustics_strength", 0.45)
		material.set_shader_parameter("planar_reflection", viewport.get_texture())
		var names := PackedStringArray()
		for parameter in water_node.material_override.shader.get_shader_uniform_list():
			if not parameter.name in ["hide_pool_surface","planar_enabled","planar_reflection","reflection_matrix","caustics_strength"]: names.append(parameter.name)
		_bind_material("pond:" + str(level),"pond:" + str(water_node.material_override.get_instance_id()),water_node.material_override,material,names)
		surface.material_override = material
		add_child(surface)
		views.append({"viewport":viewport,"camera":mirror,"material":material,"level":level,"surface":surface,"environment":environment.environment,"lights":viewport.get_children().filter(func(n): return n is DirectionalLight3D)})
		await budget.checkpoint()
		if not _setup_current(generation,content_revision,props_revision): return false
	# The source water hides only the levels these views now draw.
	var marks := Vector2(-1000000.0,-1000000.0)
	for i in range(views.size()): marks[i] = views[i].level
	water_node.material_override.set_shader_parameter("planar_levels",marks)
	for view in views: view.surface.visible = true
	update_views()
	return true

func _setup_current(generation: int, content_revision: int, props_revision: int) -> bool:
	if generation != _setup_generation or not enabled or not is_instance_valid(_scene) or not is_instance_valid(source_water): return false
	# A live setup outlasts prop changes: the next sync refreshes their copies.
	return source_water.mesh != null and _scene._chunk_editor.content.revision==content_revision and (_setup_busy or _scene._chunk_editor.data.objects_revision==props_revision)

func _copy_geometry(node: Node, parent: Node, level: float, frame_tree: SceneTree = null) -> bool:
	var generation := _setup_generation
	var pending: Array[Node] = [node]
	var budget = preload("res://scripts/frame_work_budget.gd").new(frame_tree,setup_frame)
	while not pending.is_empty():
		var current: Variant = pending.pop_back()
		if not is_instance_valid(current) or current == self: continue
		# A clip shader the warm-up has not reached (a kind of plant or prop
		# that appeared after it) parses in 3-7 ms. Give it a frame of its own
		# rather than stacking it on a slice that has already spent its budget.
		if frame_tree != null and _uncompiled(current):
			await setup_frame
			if generation != _setup_generation or not is_instance_valid(current): return false
			_copy_visual(current,parent,level)
			await setup_frame
			if generation != _setup_generation: return false
			budget = preload("res://scripts/frame_work_budget.gd").new(frame_tree,setup_frame)
		else: _copy_visual(current,parent,level)
		var children: Array[Node] = current.get_children()
		children.reverse()
		pending.append_array(children)
		await budget.checkpoint()
		if generation != _setup_generation: return false
	return true

func _copy_visual(node: Node, parent: Node, level: float) -> void:
	# Geometry can opt out, e.g. dense grass, whose per-tile instance
	# parameters a copy would not carry and which would double its cost.
	if node is GeometryInstance3D and node != source_water and not node.has_meta("skip_reflection"):
		var copy: GeometryInstance3D
		var mesh: Mesh
		if node is MeshInstance3D and node.mesh != null:
			copy = MeshInstance3D.new()
			mesh = node.mesh
			copy.mesh = mesh
		elif node is MultiMeshInstance3D and node.multimesh != null:
			copy = MultiMeshInstance3D.new()
			copy.multimesh = node.multimesh
			mesh = node.multimesh.mesh
		if copy != null and mesh != null:
			var original = node.material_override if node.material_override != null else mesh.surface_get_material(0)
			if _clipped(original):
				# One clip shader per source shader, its level a uniform: a new
				# pond level only duplicates materials, never parses a shader.
				var key := str(original.shader.get_instance_id())
				_used_shaders[key] = true
				var shader := _clip_shader(original.shader)
				var material_key := str(original.get_instance_id()) + ":" + str(level)
				_used_material_bindings[material_key] = true
				if not _material_bindings.has(material_key):
					var target: ShaderMaterial = original.duplicate()
					target.shader = shader
					target.set_shader_parameter("zs_clip_level",level+0.015)
					var names := PackedStringArray()
					for parameter in original.shader.get_shader_uniform_list(): names.append(parameter.name)
					_bind_material(material_key,str(original.get_instance_id()),original,target,names)
				var material: ShaderMaterial = _material_bindings[material_key].target
				if material.shader != shader:
					material.shader = shader
					material.set_shader_parameter("zs_clip_level",level+0.015)
				copy.material_override = material
				copy.transform = node.global_transform
				copy.extra_cull_margin = 2.0
				parent.add_child(copy)
				_bindings.append({"source":node,"copy":copy})
			else: copy.free()

## Whether copying `node` would parse a clip shader this session has not made.
func _uncompiled(node: Node) -> bool:
	if not (node is GeometryInstance3D) or node == source_water or node.has_meta("skip_reflection"): return false
	var mesh: Mesh = null
	if node is MeshInstance3D: mesh = node.mesh
	elif node is MultiMeshInstance3D and node.multimesh != null: mesh = node.multimesh.mesh
	if mesh == null or mesh.get_surface_count() == 0: return false
	var original = node.material_override if node.material_override != null else mesh.surface_get_material(0)
	return _clipped(original) and not _shader_cache.has(str(original.shader.get_instance_id()))

## Whether a copy of geometry drawn with `original` gets a clip shader.
func _clipped(original: Variant) -> bool:
	if not (original is ShaderMaterial) or original.shader == null: return false
	var id: int = original.shader.get_instance_id()
	if not _clips.has(id):
		var code: String = original.shader.code
		_clips[id] = "world_position" in code and "void fragment()" in code
	return _clips[id]

## The clip variant of `source`, made and compiled once per session. Asking
## for its RID parses it now rather than when a material first takes it.
func _clip_shader(source: Shader) -> Shader:
	var key := str(source.get_instance_id())
	if not _shader_cache.has(key):
		var shader := Shader.new()
		shader.code = source.code.replace("void fragment() {", "uniform float zs_clip_level = -1000000.0;\nvoid fragment() {\n if (world_position.y < zs_clip_level) discard;")
		shader.get_rid()
		_shader_cache[key] = shader
	return _shader_cache[key]

## Walk the scene in small slices for the shaders its copies would clip, then
## compile one clip shader per idle frame. Frames while the hand paints, the
## world forms or a setup runs are skipped; a setup compiles what it needs.
func _warm_shaders(scene: Node3D) -> void:
	var sources := {}
	var pending: Array[Node] = [scene]
	var started := Time.get_ticks_usec()
	while not pending.is_empty():
		var node: Variant = pending.pop_back()
		if not is_instance_valid(node) or node == self: continue
		if node is GeometryInstance3D and node != source_water and not node.has_meta("skip_reflection"):
			var mesh: Mesh = null
			if node is MeshInstance3D: mesh = node.mesh
			elif node is MultiMeshInstance3D and node.multimesh != null: mesh = node.multimesh.mesh
			if mesh != null and mesh.get_surface_count() > 0:
				var original = node.material_override if node.material_override != null else mesh.surface_get_material(0)
				if _clipped(original): sources[original.shader.get_instance_id()] = original.shader
		pending.append_array(node.get_children())
		if Time.get_ticks_usec()-started > 1000:
			await setup_frame
			if not _warm_started or not is_instance_valid(scene): return
			started = Time.get_ticks_usec()
	for id: int in sources:
		while _warm_blocked(scene):
			await setup_frame
			if not _warm_started or not is_instance_valid(scene): return
		if is_instance_id_valid(id) and not _shader_cache.has(str(id)): _clip_shader(sources[id])
		await setup_frame
		if not _warm_started or not is_instance_valid(scene): return
	warm_ready = true

func _warm_blocked(scene: Node3D) -> bool:
	var editor: Node = scene._chunk_editor
	return _setup_busy or editor.forming or editor._painting or editor.refresh_pending > 0

## Record a copied material and snapshot its source's parameters: a fresh
## duplicate already matches them, so nothing is pushed until one changes.
func _bind_material(key: String, group: String, source: ShaderMaterial, target: ShaderMaterial, names: PackedStringArray) -> void:
	_material_bindings[key] = {"material":source,"target":target,"names":names,"group":group}
	_groups_dirty = true
	if not _group_state.has(group):
		var values := {}
		for name in names: values[name] = source.get_shader_parameter(name)
		_group_state[group] = {"values":values,"live":{},"cursor":0}

func _regroup() -> void:
	_groups_dirty = false
	var by_key := {}
	_material_groups.clear()
	for binding: Dictionary in _material_bindings.values():
		var key: String = binding.group
		if not by_key.has(key):
			var state: Dictionary = _group_state[key]
			by_key[key] = {"material":binding.material,"names":binding.names,"targets":[],"values":state.values,"live":state.live,"state":state}
			_material_groups.append(by_key[key])
		by_key[key].targets.append(binding.target)
	for key in _group_state.keys():
		if not by_key.has(key): _group_state.erase(key)
	_discover_group = 0
func _sync_materials() -> void:
	if _groups_dirty: _regroup()
	if _material_groups.is_empty(): return
	for group: Dictionary in _material_groups:
		if not is_instance_valid(group.material): continue
		for name: String in group.live: _sync_parameter(group,name)
	var reads := DISCOVERY_READS
	var visited := 0
	while reads > 0 and visited <= _material_groups.size():
		_discover_group %= _material_groups.size()
		var group: Dictionary = _material_groups[_discover_group]
		var state: Dictionary = group.state
		var names: PackedStringArray = group.names
		if is_instance_valid(group.material):
			while state.cursor < names.size() and reads > 0:
				_sync_parameter(group,names[state.cursor])
				state.cursor += 1
				reads -= 1
		if state.cursor >= names.size() or not is_instance_valid(group.material):
			state.cursor = 0
			_discover_group += 1
			visited += 1

func _sync_parameter(group: Dictionary, name: String) -> void:
	var value: Variant = group.material.get_shader_parameter(name)
	var values: Dictionary = group.values
	if values.has(name) and typeof(values[name]) == typeof(value) and values[name] == value: return
	values[name] = value
	group.live[name] = true
	for target: ShaderMaterial in group.targets: target.set_shader_parameter(name,value)

func _pool_mesh(source: ArrayMesh, level: float) -> ArrayMesh:
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var source_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if source_indices.is_empty():
		for i in range(vertices.size()): source_indices.append(i)
	var indices := PackedInt32Array()
	for i in range(0, source_indices.size(), 3):
		var a := source_indices[i]
		var b := source_indices[i+1]
		var c := source_indices[i+2]
		if absf(vertices[a].y-level) > 0.02 or absf(vertices[b].y-level) > 0.02 or absf(vertices[c].y-level) > 0.02: continue
		if arrays[Mesh.ARRAY_TEX_UV2][a].y > 0.5: continue
		if (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).y > 0.0:
			indices.append_array([a,c,b])
		else: indices.append_array([a,b,c])
	if indices.is_empty(): return null
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, source.surface_get_format(0))
	return result

func set_enabled(value: bool) -> void:
	visible = value
	if is_instance_valid(source_water): source_water.material_override.set_shader_parameter("hide_pool_surface", value and not views.is_empty())
	for view in views:
		view.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED

## The pond levels with the most surface, largest first, at most MAX_VIEWS.
func _view_levels(source: ArrayMesh, ponds: Array) -> Array:
	var faces := {}
	for pond in ponds: faces[pond.level] = 0
	if source != null and source.get_surface_count() > 0 and faces.size() > MAX_VIEWS:
		var vertices: PackedVector3Array = source.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for i in range(0,vertices.size(),3):
			for level: float in faces:
				if absf(vertices[i].y-level) <= 0.02:
					faces[level] += 1
					break
	var levels: Array = faces.keys()
	levels.sort_custom(func(a: float, b: float) -> bool: return faces[a] > faces[b] or (faces[a] == faces[b] and a < b))
	levels.resize(mini(levels.size(),MAX_VIEWS))
	return levels

func update_views() -> void:
	_update_view_list(views,_bindings)

func _update_view_list(view_list: Array, binding_list: Array) -> void:
	for binding in binding_list:
		if not is_instance_valid(binding.source):
			binding.copy.visible = false
			continue
		# Most copies stand still; only write what moved or was swapped.
		var copy: GeometryInstance3D = binding.copy
		var source: GeometryInstance3D = binding.source
		var shown := source.is_visible_in_tree()
		if copy.visible != shown: copy.visible = shown
		var placed := source.global_transform
		if copy.transform != placed: copy.transform = placed
		if source is MultiMeshInstance3D:
			if copy.multimesh != source.multimesh: copy.multimesh = source.multimesh
		elif source is MeshInstance3D:
			if copy.mesh != source.mesh: copy.mesh = source.mesh
	_sync_materials()
	for view in view_list:
		if view.viewport.msaa_3d != _scene.get_viewport().msaa_3d:
			view.viewport.msaa_3d = _scene.get_viewport().msaa_3d
		view.environment.sky = _scene._environment.sky
		view.environment.background_mode = _scene._environment.background_mode
		view.environment.background_color = _scene._environment.background_color
		view.environment.ambient_light_color = _scene._environment.ambient_light_color
		view.environment.ambient_light_energy = _scene._environment.ambient_light_energy
		for i in range(view.lights.size()):
			view.lights[i].transform = _scene._lights[i].global_transform
			view.lights[i].light_color = _scene._lights[i].light_color
			view.lights[i].light_energy = _scene._lights[i].light_energy
		var aspect := camera.get_viewport().get_visible_rect().size.aspect()
		var reflection_width: float = [512.0, 384.0, 768.0][clampi(_scene._quality.selected, 0, 2)]
		view.viewport.size = Vector2i(int(reflection_width), maxi(1, roundi(reflection_width / aspect)))
		var mirror: Camera3D = view.camera
		mirror.fov = camera.fov
		mirror.near = camera.near
		mirror.far = camera.far
		var position := camera.global_position
		position.y = 2.0 * view.level - position.y
		var forward := -camera.global_basis.z
		forward.y = -forward.y
		var up := camera.global_basis.y
		up.y = -up.y
		mirror.position = position
		mirror.look_at(position + forward, up)
		view.material.set_shader_parameter("reflection_matrix", mirror.get_camera_projection() * Projection(mirror.global_transform.affine_inverse()))
