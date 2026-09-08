extends Node3D
## Isolated rendering study. F8 compares the same composition with source rendering.
var scene: Node3D
var ready_for_capture := false
var enhanced := true
var mist: FogVolume
var water: Array[Dictionary] = []
var caption: Label
var reflection: ReflectionProbe

func _ready() -> void:
	process_priority = 100
	scene = load("res://studies/fidelity.tscn").instantiate()
	add_child(scene)
	scene._chunk_editor.save_path = "user://visual-benchmark.json"
	scene._paused = true
	scene._auto_orbit = false
	scene._ui.hide()
	await scene._chunk_editor.form_landscape("terraced_pools", "woodland", false)
	preload("res://scripts/scene_look_presets.gd").apply(scene, "golden_meadow")
	scene._atmosphere.set_fog(0.18)
	scene._atmosphere.set_haze(0.04)
	scene._atmosphere.summit_mist = 0.0
	scene.target = Vector3(1.0, 2.2, 3.5)
	scene.distance = 25.0
	scene.yaw = -0.45
	scene.polar = 1.12
	scene._update_camera()
	_collect_water(scene)
	reflection = ReflectionProbe.new()
	reflection.position = Vector3(2, 1.8, 6.5)
	reflection.size = Vector3(16, 18, 16)
	reflection.cull_mask = 1
	reflection.reflection_mask = 2
	reflection.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	reflection.enable_shadows = true
	reflection.intensity = 0.5
	add_child(reflection)
	mist = FogVolume.new()
	mist.size = Vector3(28, 20, 28)
	mist.position.y = 6.0
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/beauty_mist.gdshader")
	material.set_shader_parameter("ground_map", scene._precipitation.ground_texture)
	material.set_shader_parameter("stream_map", scene._precipitation.stream_texture)
	mist.material = material
	add_child(mist)
	var ui := CanvasLayer.new()
	add_child(ui)
	caption = Label.new()
	caption.position = Vector2(24, 20)
	caption.add_theme_font_size_override("font_size", 14)
	ui.add_child(caption)
	ready_for_capture = true
	set_enhanced(not "--control" in OS.get_cmdline_user_args())
	scene._paused = false
	print("VISUAL BENCHMARK READY water meshes=", water.size(), " ponds=", scene._chunk_editor.data.ponds)

func _collect_water(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null and node.is_visible_in_tree():
		var original = node.get_active_material(0)
		if original is ShaderMaterial and original.shader != null and "water" in original.shader.resource_path and original.get_shader_parameter("flowing") != true:
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/beauty_water.gdshader")
			node.layers = 2
			water.append({"node":node, "original":node.material_override, "material":material, "original_mesh":node.mesh, "surface_mesh":_front_facing_water(node.mesh)})
	for child in node.get_children(): _collect_water(child)

func _front_facing_water(source: ArrayMesh) -> ArrayMesh:
	# Source water uses Three.js winding and double-sided rendering. Godot
	# expects clockwise front faces; retain every vertex attribute and change
	# only the index order for the native material in this study.
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		for i in range(vertices.size()): indices.append(i)
	for i in range(0, indices.size(), 3):
		var a := vertices[indices[i]]
		var b := vertices[indices[i+1]]
		var c := vertices[indices[i+2]]
		if (b-a).cross(c-a).y > 0.0:
			var swap := indices[i+1]
			indices[i+1] = indices[i+2]
			indices[i+2] = swap
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, source.surface_get_format(0))
	return result

func set_enhanced(value: bool) -> void:
	enhanced = value
	reflection.visible = value
	for item in water:
		item.node.material_override = item.material if value else item.original
		item.node.mesh = item.surface_mesh if value else item.original_mesh
	scene._atmosphere.get_node("ValleyFog").visible = not value
	mist.visible = value
	scene._display_fog.visible = not value
	scene._environment.ssr_enabled = value
	scene._environment.ssr_max_steps = 512
	scene._environment.ssr_depth_tolerance = 0.3
	scene._environment.volumetric_fog_anisotropy = 0.55 if value else 0.45
	scene._environment.volumetric_fog_ambient_inject = 0.25 if value else 0.35
	for light in scene._lights: light.light_volumetric_fog_energy = 2.0 if value and light.shadow_enabled else 0.0
	caption.text = ("Luminous woodland" if value else "Original rendering") + "  ·  F8 compare  ·  drag to orbit  ·  P pause"

func _process(_delta: float) -> void:
	if ready_for_capture:
		# The source compositor disables native fog each frame; this study
		# owns the final environment choice after the source scene updates.
		scene._environment.volumetric_fog_enabled = enhanced

func _unhandled_key_input(event: InputEvent) -> void:
	if ready_for_capture and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		set_enhanced(not enhanced)
		get_viewport().set_input_as_handled()
