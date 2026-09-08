extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440,900)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440,900)
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene = load("res://studies/diorama.tscn").instantiate()
	viewport.add_child(scene)
	scene.set_process(false)
	scene._paused = true
	scene._menu.get_parent().hide()
	scene._ui.hide()
	var editor = scene._chunk_editor
	await editor.form_landscape("terraced_pools", "woodland", false)
	scene._growth.terrain = 1.0
	scene._growth.foliage = 1.0
	scene._growth.water = 1.0
	scene._growth.publish()
	var water = scene._planar_water
	water.sync(scene)
	check(water.views.size() == 3, "Playable terraces reflect all three pond levels")
	for view in water.views:
		check(view.viewport.msaa_3d == viewport.msaa_3d, "Reflection MSAA matches the scene to share precompiled pipelines")
		check(view.material.get_shader_parameter("caustics_strength") > 0.0, "Every pond gets caustics")
		check(view.material.get_shader_parameter("planar_enabled"), "Shared water shader uses reflections")
	var binding: Dictionary = water._bindings[0]
	var before: Transform3D = binding.source.transform
	binding.source.position.x += 0.3
	binding.source.visible = false
	water.update_views()
	check(not binding.copy.visible and binding.copy.transform == binding.source.global_transform, "Reflection tracks transform and visibility")
	binding.source.transform = before
	binding.source.visible = true
	var material_binding: Dictionary = water._material_bindings.values()[0]
	material_binding.material.set_shader_parameter("roughness_value", 0.63)
	water.update_views()
	check(material_binding.target.get_shader_parameter("roughness_value") == material_binding.material.get_shader_parameter("roughness_value"), "Reflection tracks edited material")
	scene._redwood_mist.sync(scene)
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		check(scene._redwood_mist.active and not scene._redwood_mist.redwood, "Ordinary landscapes get native mist and rays")
		check(editor.content._water.material_override.get_shader_parameter("hide_pool_surface"), "Original surface avoids double rendering")
	scene.target = Vector3(1,2.2,3.5)
	scene.distance = 25
	scene.yaw = -0.45
	scene.polar = 1.12
	scene._update_camera()
	scene._process(0.0)
	water.update_views()
	if "--capture" in OS.get_cmdline_user_args():
		for i in range(12):
			await process_frame
			RenderingServer.force_draw(false)
		viewport.get_texture().get_image().save_png("/private/tmp/zs-playable-enhanced.png")
		water.views[0].viewport.get_texture().get_image().save_png("/private/tmp/zs-playable-reflection.png")
		water.enabled = false
		water.sync(scene)
		for i in range(8):
			await process_frame
			RenderingServer.force_draw(false)
		viewport.get_texture().get_image().save_png("/private/tmp/zs-playable-control.png")
		water.enabled = true
	var tree: Dictionary = editor.data.objects[0]
	var reflection_viewport: SubViewport = water.views[0].viewport
	var reflection_shader: Shader = water._shader_cache.values()[0]
	var reflection_material: Material = material_binding.target
	editor.select_object(tree.id)
	check(editor.update_selected({"x":tree.x + 0.2}), "Object edit succeeds with reflections active")
	water.sync(scene)
	check(water.views[0].viewport == reflection_viewport, "Object-only edit preserves reflection viewport")
	check(water._shader_cache.values().has(reflection_shader), "Object-only edit preserves compiled reflection shaders")
	check(water._material_bindings.values().any(func(value): return value.target == reflection_material), "Object-only edit preserves unchanged reflected materials")
	check(water.objects_revision == editor.data.objects_revision, "Reflection rebuild follows object-only edits")
	check(water._bindings.all(func(b): return is_instance_valid(b.source)), "No deleted source geometry remains after editing")
	editor.save_path = "/private/tmp/zs-playable-visuals-roundtrip.json"
	check(editor.save_garden(), "Effects allow normal garden save")
	check(editor.open_garden(), "Effects allow normal garden reload")
	water.sync(scene)
	check(water.views.size() == 3, "Reload restores every reflected pond")
	scene._atmosphere.set_fog(0.0)
	scene._redwood_mist.sync(scene)
	check(not scene._redwood_mist.active, "Mist control disables native fog")
	scene._growth.water = 0.3
	water.sync(scene)
	check(not water.visible and not editor.content._water.material_override.get_shader_parameter("hide_pool_surface"), "Water refill keeps original growth rendering")
	scene._growth.water = 1.0
	await editor.form_landscape("plateau", "", false)
	water.sync(scene)
	check(water.views.size() == 2, "Switching landscape rebuilds pond views")
	editor.start_flat()
	water.sync(scene)
	check(water.views.is_empty(), "Empty garden removes reflection viewports")
	scene.free()
	await process_frame
	print("PLAYABLE VISUALS failures=",failures)
	quit(failures)
