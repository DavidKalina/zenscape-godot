extends SceneTree
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in range(40):
		await process_frame
		RenderingServer.force_draw(false)
func run() -> void:
	var output := "res://docs/visual-lab/inland-worlds"
	DirAccess.make_dir_recursive_absolute(output)
	var scene = load("res://studies/prototype_inland_worlds.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.set_process(false)
	scene.set_process_unhandled_input(false)
	scene.lab_ui.hide()
	await create_timer(3.0).timeout
	root.mode = Window.MODE_WINDOWED
	root.content_scale_factor = 1.0
	root.size = Vector2i(1600,1000)
	await create_timer(2.0).timeout
	scene.cloud_drift = false
	scene.cloud_clock = 12.0
	var records: Array = []
	for composition in (["marsh"] if "--watercheck" in OS.get_cmdline_user_args() else scene.Genome.COMPOSITIONS):
		scene.choices = {"composition":composition}
		scene.set_scale_variant(0)
		scene.apply_mood(1 if scene.genome.habitat == "arid" else 4 if composition == "marsh" else 0)
		scene._process(0.0)
		for pond in scene._chunk_editor.data.ponds:
			assert(scene._chunk_editor.data.pond_surface(pond).size()>0,"Dry generated pool")
		print("WATER vertices=",scene._chunk_editor.content.pond_vertices.size()," hidden=",scene._chunk_editor.content._water_material.get_shader_parameter("hide_pool_surface"))
		await settle()
		root.get_texture().get_image().save_png(output.path_join(composition+".png"))
		records.append(scene.genome.duplicate(true))
		print("INLAND CAPTURE ",composition)
	scene.choices = {"composition":"valley","landform":"glacial-valley"}
	scene.set_scale_variant(0)
	scene.apply_mood(0)
	scene.lab_ui.show()
	await settle()
	root.get_texture().get_image().save_png(output.path_join("interactive.png"))
	FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	scene.free()
	quit()
