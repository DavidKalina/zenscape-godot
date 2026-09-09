extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene = load("res://studies/diorama.tscn").instantiate()
	scene.library_path = "/private/tmp/zenscape-integrated-captures"
	scene.recent_file = scene.library_path+"/no-recent.cfg"
	scene.title_seed = 37
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	var folder := ProjectSettings.globalize_path("res://docs/visual-lab/integration")
	DirAccess.make_dir_recursive_absolute(folder)
	for family in ["massif","valley","monuments","salt-basin"]:
		var choice := {}
		for seed_value in range(1000):
			choice = preload("res://scripts/title_showcase.gd").choose(seed_value)
			if choice.family == family and choice.has("terrain_recipe"): break
		scene._menu.hide()
		await scene._chunk_editor.form_inland(choice.terrain_recipe,true,false)
		scene.title_recipe = choice
		scene._frame_title()
		scene._notice.text = ""
		scene.show_menu()
		await create_timer(3.0).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/"+family+".png")
		print("CAPTURE ",family," ",choice.look)
	scene._has_world = true
	scene.close_menu()
	scene._frame_diorama()
	scene._ensure_landscape_editor()
	scene._landscape_editor.show()
	scene._landscape_editor.tabs.current_tab = 2
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/editor-landscapes.png")
	scene._landscape_editor.hide()
	scene._ensure_scene_look_editor()
	scene._look_editor.show()
	for i in scene._look_editor.tabs.get_tab_count():
		if scene._look_editor.tabs.get_tab_title(i) == "Atmosphere": scene._look_editor.tabs.current_tab = i
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/editor-atmosphere.png")
	scene.free()
	quit()
