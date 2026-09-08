extends Node3D
## Opt-in study renderer: a clipped reflected view for each horizontal pond.
var views: Array[Dictionary] = []
var source_water: MeshInstance3D
var camera: Camera3D
var _shader_cache := {}

func setup(scene: Node3D, water_node: MeshInstance3D) -> void:
	camera = scene.camera
	source_water = water_node
	for pond in scene._chunk_editor.data.ponds:
		var level: float = pond.level
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
		surface.mesh = _pool_mesh(water_node.mesh, level)
		surface.transform = water_node.global_transform
		surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/benchmark_planar_water.gdshader")
		material.set_shader_parameter("planar_reflection", viewport.get_texture())
		surface.material_override = material
		add_child(surface)
		views.append({"viewport":viewport,"camera":mirror,"material":material,"level":level})
	update_views()

func _copy_geometry(node: Node, parent: Node, level: float) -> void:
	if node is GeometryInstance3D and node.is_visible_in_tree() and node != source_water:
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
					var material: ShaderMaterial = original.duplicate()
					material.shader = _shader_cache[key]
					copy.material_override = material
					copy.transform = node.global_transform
					copy.extra_cull_margin = 2.0
					parent.add_child(copy)
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
		if absf(vertices[a].y-level) > 0.02: continue
		if (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).y > 0.0:
			indices.append_array([a,c,b])
		else: indices.append_array([a,b,c])
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, source.surface_get_format(0))
	return result

func set_enabled(value: bool) -> void:
	visible = value
	source_water.visible = not value
	for view in views:
		view.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED

func update_views() -> void:
	for view in views:
		var aspect := camera.get_viewport().get_visible_rect().size.aspect()
		view.viewport.size = Vector2i(512, maxi(1, roundi(512.0 / aspect)))
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
