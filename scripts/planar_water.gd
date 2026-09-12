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
signal setup_frame

func _ready() -> void:
	get_tree().process_frame.connect(_advance_setup_frame)

func _advance_setup_frame() -> void:
	# Waiting on this node's signal makes pending setup disappear with its
	# owner. The tree's longer-lived signal must not resume a freed node.
	setup_frame.emit()

func sync(scene: Node3D, frame_tree: SceneTree = null) -> void:
	_scene = scene
	if _setup_busy:
		if frame_tree != null: return
		# Explicit synchronous callers supersede pending initial preparation.
		clear(true)
		revision = -1
	if not enabled:
		clear()
		revision = -1
		return
	var content: GardenView = scene._chunk_editor.content
	if revision != content.revision:
		# Geometry changes retain compiled clip shaders for surviving pond levels.
		clear(true)
		revision = content.revision
		objects_revision = scene._chunk_editor.data.objects_revision
		if content._water.mesh != null and not scene._chunk_editor.data.ponds.is_empty():
			# Only first-time setup needs to compile clipping programs. Keep the
			# original water visible while preparing all reflected levels.
			var initial_tree: SceneTree = frame_tree if not _initial_ready else null
			var generation := _setup_generation
			_setup_busy = true
			var accepted := await setup(scene,content._water,initial_tree)
			if generation != _setup_generation: return
			_setup_busy = false
			if not accepted or not enabled or revision != content.revision or objects_revision != scene._chunk_editor.data.objects_revision:
				clear(true)
				revision = -1
				return
			_initial_ready = true
		_prune_shaders()
	elif objects_revision != scene._chunk_editor.data.objects_revision:
		objects_revision = scene._chunk_editor.data.objects_revision
		_refresh_geometry(scene)
	var active: bool = enabled and RenderingServer.get_current_rendering_method() == "forward_plus" and scene._growth.terrain >= 0.995 and scene._growth.water >= 0.995 and scene.can_process()
	set_enabled(active)
	if active: update_views()

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
	_prune_shaders()

func clear(keep_shaders := false) -> void:
	_setup_generation += 1
	_setup_busy = false
	revision = -1
	objects_revision = -1
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
	if not keep_shaders:
		_shader_cache.clear()
		_initial_ready = false

func _prune_shaders() -> void:
	for key in _shader_cache.keys():
		if not _used_shaders.has(key): _shader_cache.erase(key)

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
	var levels := {}
	for pond in scene._chunk_editor.data.ponds:
		if levels.has(pond.level): continue
		levels[pond.level] = true
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
		_material_bindings["pond:" + str(level)] = {
			"material":water_node.material_override,"target":material,"values":{},
			"parameters":water_node.material_override.shader.get_shader_uniform_list().filter(func(parameter):
				return not parameter.name in ["hide_pool_surface","planar_enabled","planar_reflection","reflection_matrix","caustics_strength"])}
		surface.material_override = material
		add_child(surface)
		views.append({"viewport":viewport,"camera":mirror,"material":material,"level":level,"surface":surface,"environment":environment.environment,"lights":viewport.get_children().filter(func(n): return n is DirectionalLight3D)})
		await budget.checkpoint()
		if not _setup_current(generation,content_revision,props_revision): return false
	for view in views: view.surface.visible = true
	update_views()
	return true

func _setup_current(generation: int, content_revision: int, props_revision: int) -> bool:
	if generation != _setup_generation or not enabled or not is_instance_valid(_scene) or not is_instance_valid(source_water): return false
	return source_water.mesh != null and _scene._chunk_editor.content.revision==content_revision and _scene._chunk_editor.data.objects_revision==props_revision

func _copy_geometry(node: Node, parent: Node, level: float, frame_tree: SceneTree = null) -> bool:
	var generation := _setup_generation
	var pending: Array[Node] = [node]
	var budget = preload("res://scripts/frame_work_budget.gd").new(frame_tree,setup_frame)
	while not pending.is_empty():
		var current: Variant = pending.pop_back()
		if not is_instance_valid(current) or current == self: continue
		_copy_visual(current,parent,level)
		var children: Array[Node] = current.get_children()
		children.reverse()
		pending.append_array(children)
		await budget.checkpoint()
		if generation != _setup_generation: return false
	return true

func _copy_visual(node: Node, parent: Node, level: float) -> void:
	if node is GeometryInstance3D and node != source_water:
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
			if original is ShaderMaterial and original.shader != null and "world_position" in original.shader.code:
				var code: String = original.shader.code
				if "void fragment()" in code:
					var key := str(original.shader.get_instance_id()) + ":" + str(level)
					_used_shaders[key] = true
					if not _shader_cache.has(key) or _shader_cache[key].get_meta("source_code","") != code:
						var shader := Shader.new()
						shader.code = code.replace("void fragment() {", "void fragment() {\n if (world_position.y < %.5f) discard;" % (level+0.015))
						shader.set_meta("source_code",code)
						_shader_cache[key] = shader
					var material_key := str(original.get_instance_id()) + ":" + str(level)
					_used_material_bindings[material_key] = true
					if not _material_bindings.has(material_key):
						var target: ShaderMaterial = original.duplicate()
						target.shader = _shader_cache[key]
						_material_bindings[material_key] = {"material":original,"target":target,"parameters":original.shader.get_shader_uniform_list(),"values":{}}
					var material: ShaderMaterial = _material_bindings[material_key].target
					if material.shader != _shader_cache[key]: material.shader = _shader_cache[key]
					copy.material_override = material
					copy.transform = node.global_transform
					copy.extra_cull_margin = 2.0
					parent.add_child(copy)
					_bindings.append({"source":node,"copy":copy})
				else: copy.free()
			else: copy.free()

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

func update_views() -> void:
	for binding in _bindings:
		if not is_instance_valid(binding.source):
			binding.copy.visible = false
			continue
		binding.copy.visible = binding.source.is_visible_in_tree()
		binding.copy.transform = binding.source.global_transform
		if binding.source is MultiMeshInstance3D: binding.copy.multimesh = binding.source.multimesh
		elif binding.source is MeshInstance3D: binding.copy.mesh = binding.source.mesh
	for binding in _material_bindings.values():
		for parameter in binding.parameters:
			var value = binding.material.get_shader_parameter(parameter.name)
			if not binding.values.has(parameter.name) or binding.values[parameter.name] != value:
				binding.target.set_shader_parameter(parameter.name, value)
				binding.values[parameter.name] = value
	for view in views:
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
		view.viewport.size = Vector2i(384 if _scene._quality.selected == 1 else 512, maxi(1, roundi((384.0 if _scene._quality.selected == 1 else 512.0) / aspect)))
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
