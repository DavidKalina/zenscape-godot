extends Node3D
## Live reflected pond views. Rebuild on content changes; synchronize moving
## geometry, local material settings, lighting and camera without duplicating gameplay.
var views: Array[Dictionary] = []
var source_water: MeshInstance3D
var camera: Camera3D
var _shader_cache := {}
var _bindings: Array[Dictionary] = []
var _material_bindings := {}
var revision := -1
var objects_revision := -1
var enabled := true
var _scene: Node3D

func sync(scene: Node3D) -> void:
	_scene = scene
	if not enabled:
		clear()
		revision = -1
		return
	var content: GardenView = scene._chunk_editor.content
	if revision != content.revision or objects_revision != scene._chunk_editor.data.objects_revision:
		clear()
		revision = content.revision
		objects_revision = scene._chunk_editor.data.objects_revision
		if content._water.mesh != null and not scene._chunk_editor.data.ponds.is_empty():
			setup(scene, content._water)
	var active: bool = enabled and RenderingServer.get_current_rendering_method() == "forward_plus" and scene._growth.terrain >= 0.995 and scene._growth.water >= 0.995
	set_enabled(active)
	if active: update_views()

func clear() -> void:
	if is_instance_valid(source_water):
		source_water.material_override.set_shader_parameter("hide_pool_surface", false)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	views.clear()
	_bindings.clear()
	_material_bindings.clear()
	_shader_cache.clear()

func _exit_tree() -> void:
	if is_instance_valid(source_water):
		source_water.material_override.set_shader_parameter("hide_pool_surface", false)


func setup(scene: Node3D, water_node: MeshInstance3D) -> void:
	_scene = scene
	camera = scene.camera
	source_water = water_node
	var levels := {}
	for pond in scene._chunk_editor.data.ponds:
		if levels.has(pond.level): continue
		levels[pond.level] = true
		var level: float = pond.level
		var pool := _pool_mesh(water_node.mesh, level)
		if pool == null: continue
		var viewport := SubViewport.new()
		viewport.size = Vector2i(512,320)
		viewport.own_world_3d = true
		viewport.msaa_3d = Viewport.MSAA_2X
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var environment := WorldEnvironment.new()
		environment.environment = scene._environment.duplicate()
		environment.environment.volumetric_fog_enabled = false
		environment.environment.ssr_enabled = false
		viewport.add_child(environment)
		_copy_geometry(scene, viewport, level)
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
		surface.mesh = pool
		surface.transform = water_node.global_transform
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
	update_views()

func _copy_geometry(node: Node, parent: Node, level: float) -> void:
	if node == self: return
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
					var key: String = original.shader.resource_path + str(level)
					if not _shader_cache.has(key):
						var shader := Shader.new()
						shader.code = code.replace("void fragment() {", "void fragment() {\n if (world_position.y < %.5f) discard;" % (level+0.015))
						_shader_cache[key] = shader
					var material_key := str(original.get_instance_id()) + ":" + str(level)
					if not _material_bindings.has(material_key):
						var target: ShaderMaterial = original.duplicate()
						target.shader = _shader_cache[key]
						_material_bindings[material_key] = {"material":original,"target":target,"parameters":original.shader.get_shader_uniform_list(),"values":{}}
					var material: ShaderMaterial = _material_bindings[material_key].target
					copy.material_override = material
					copy.transform = node.global_transform
					copy.extra_cull_margin = 2.0
					parent.add_child(copy)
					_bindings.append({"source":node,"copy":copy})
				else: copy.free()
			else: copy.free()
	for child in node.get_children(): _copy_geometry(child,parent,level)

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
