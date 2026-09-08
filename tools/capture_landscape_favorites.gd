extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene = load("res://studies/diorama.tscn").instantiate()
	root.add_child(scene)
	# Isolated output: visual verification never writes the user's library.
	scene.library_path = "/private/tmp/zenscape-favorites-capture-worlds"
	scene.recent_file = "/private/tmp/zenscape-favorites-capture-recent.cfg"
	scene.new_diorama()
	scene._paused = true
	await scene._chunk_editor.form_landscape("terraced_pools","",false)
	preload("res://scripts/scene_look_presets.gd").apply(scene,"after_the_rain")
	scene.edit_landscape_presets()
	var panel = scene._landscape_editor
	panel.library.directory = "/private/tmp/zenscape-favorites-capture-"+str(Time.get_ticks_usec())
	panel.tabs.current_tab = 1
	panel.favorite_name.text = "Jade cascades"
	await panel.save_favorite()
	await scene._chunk_editor.another_landscape(false)
	preload("res://scripts/scene_look_presets.gd").apply(scene,"halloween_hollow")
	panel.favorite_name.text = "Haunted water garden"
	await panel.save_favorite()
	var entries: Array = panel.library.entries()
	await scene._chunk_editor.restore_landscape_favorite(panel.library,entries[1].id,false)
	panel.tabs.current_tab = 1
	panel.favorite_name.clear()
	panel.favorite_status.text = "Restored · Jade cascades"
	(await shot()).save_png("res://docs/landscapes/favorites.png")
	panel.tabs.current_tab = 0
	(await shot()).save_png("res://docs/landscapes/gallery.png")
	root.size = Vector2i(960,640)
	(await shot()).save_png("res://docs/landscapes/gallery-small.png")
	panel.tabs.current_tab = 1
	(await shot()).save_png("res://docs/landscapes/favorites-small.png")
	print("FAVORITES VISUAL WORKFLOW COMPLETE")
	scene.free()
	quit()
func shot() -> Image:
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
