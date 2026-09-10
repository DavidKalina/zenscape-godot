extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	create_timer(120).timeout.connect(func() -> void: quit(2))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440,900)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440,900)
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene = load("res://studies/diorama.tscn").instantiate()
	scene.title_seed = 37
	scene.library_path = "/private/tmp/zs-playable-visuals-library"
	scene.recent_file = scene.library_path+"/recent.cfg"
	viewport.add_child(scene)
	while not scene.title_loaded: await process_frame
	scene.new_diorama()
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
	var pool_arrays: Array = []
	for view in water.views: pool_arrays.append(var_to_bytes(view.surface.mesh.surface_get_arrays(0)))
	water.clear()
	water.revision = -1
	water.sync(scene,self)
	check(water._setup_busy,"Initial live reflections prepare over multiple frames")
	var hidden_until_ready := true
	while water._setup_busy:
		hidden_until_ready = hidden_until_ready and not editor.content._water.material_override.get_shader_parameter("hide_pool_surface")
		for view in water.views:
			hidden_until_ready = hidden_until_ready and not view.surface.visible and view.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED
		await process_frame
	check(hidden_until_ready,"Original water stays visible until every reflected level is ready")
	check(water.views.size()==pool_arrays.size(),"Budgeted setup publishes all reflected levels together")
	for i in range(mini(water.views.size(),pool_arrays.size())):
		check(var_to_bytes(water.views[i].surface.mesh.surface_get_arrays(0))==pool_arrays[i],"Budgeted reflected pool geometry matches synchronous bytes")
	# Clearing a partially constructed setup invalidates its resumed traversal.
	water.clear()
	water.revision = -1
	water.sync(scene,self)
	while water._setup_busy and water.get_child_count()==0: await process_frame
	check(water._setup_busy,"Cancellation exercises partially built reflection resources")
	water.clear()
	while water._setup_busy: await process_frame
	check(water.views.is_empty() and water.get_child_count()==0,"Cancelled reflection setup cannot republish partial views")
	water.sync(scene)
	for i in range(3): await process_frame
	check(water.views.size()==3,"Cancelled continuations cannot clear a newer synchronous reflection setup")
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
		water.sync(scene)
		material_binding = water._material_bindings.values()[0]
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
	var shaders: Dictionary = water._shader_cache.duplicate()
	var water_revision: int = water.revision
	editor.force_refresh()
	water.sync(scene)
	check(water.revision != water_revision,"Full refresh exercises replacement water geometry")
	check(shaders.keys().all(func(key): return water._shader_cache.get(key)==shaders[key]),"Changed terrain/water geometry preserves identical compiled reflection shaders")
	check(water._shader_cache.size()==water._used_shaders.size(),"Shader retention is bounded to active reflection sources and levels")
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
	check(water._shader_cache.is_empty(),"Removing all ponds releases retained reflection shaders")
	scene.free()
	await process_frame
	print("PLAYABLE VISUALS failures=",failures)
	quit(failures)
