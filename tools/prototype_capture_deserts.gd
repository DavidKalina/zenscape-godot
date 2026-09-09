extends SceneTree
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in range(40):
		await process_frame
		RenderingServer.force_draw(false)
func run() -> void:
	var output := "res://docs/visual-lab/desert-parity"
	DirAccess.make_dir_recursive_absolute(output)
	var scene = load("res://studies/prototype_inland_worlds.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.set_process(false)
	scene.set_process_unhandled_input(false)
	scene.lab_ui.hide()
	await create_timer(3).timeout
	root.mode = Window.MODE_WINDOWED
	root.content_scale_factor = 1.0
	root.size = Vector2i(1600,1000)
	scene.cloud_drift = false
	scene.cloud_clock = 12.0
	var records: Array = []
	for kind in scene.Desert.KINDS:
		scene.choices = {"composition":kind}
		scene.set_scale_variant(0)
		scene.apply_mood(1)
		scene._process(0)
		if kind=="salt-basin":
			assert(not scene._chunk_editor.data.ponds.is_empty(),"Missing salt pools")
			for pond in scene._chunk_editor.data.ponds:
				assert(scene._chunk_editor.data.pond_surface(pond).size()>0,"Dry salt pool")
		await settle()
		root.get_texture().get_image().save_png(output.path_join(kind+".png"))
		records.append(scene.genome.duplicate(true))
		print("DESERT CAPTURE ",kind)
	scene.choices = {"composition":"salt-basin"}
	scene.set_scale_variant(0)
	var initial := var_to_bytes(scene._chunk_editor.data._snapshot())
	for mood in range(9):
		scene.apply_mood(mood)
		assert(initial==var_to_bytes(scene._chunk_editor.data._snapshot()),"Mood changed terrain")
		if mood in [0,3,6]:
			scene._process(0)
			await settle()
			root.get_texture().get_image().save_png(output.path_join("salt-mood-%d.png"%mood))
	scene.apply_mood(1)
	scene.lab_ui.show()
	await settle()
	root.get_texture().get_image().save_png(output.path_join("interactive.png"))
	FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	scene.free()
	quit()
