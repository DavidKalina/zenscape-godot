extends SceneTree
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in range(40):
		await process_frame
		RenderingServer.force_draw(false)
func run() -> void:
	var output := "res://docs/visual-lab/valley-palettes"
	DirAccess.make_dir_recursive_absolute(output)
	var scene = load("res://studies/prototype_valley_palettes.tscn").instantiate()
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
	var initial = var_to_bytes(scene._chunk_editor.data._snapshot())
	var records: Array = []
	for index in range(9):
		scene.apply_mood(index)
		scene._process(0.0)
		await settle()
		assert(root.size == Vector2i(1600,1000))
		assert(initial == var_to_bytes(scene._chunk_editor.data._snapshot()),"Mood changed terrain records")
		root.get_texture().get_image().save_png(output.path_join(scene.MOODS[index]+".png"))
		records.append({"mood":scene.MOODS[index],"camera":str(scene.camera.transform),"geometry_unchanged":true})
		print("PALETTE CAPTURE ",scene.MOODS[index])
	scene.apply_mood(0)
	scene._process(0.0)
	await settle()
	root.get_texture().get_image().save_png(output.path_join("alpine-return.png"))
	scene.apply_mood(4)
	scene.hour_slider.value = 0.62
	scene.fog_slider.value = 2.5
	scene.altitude_slider.value = 6.0
	scene._process(0.0)
	await settle()
	root.get_texture().get_image().save_png(output.path_join("knobs-pushed.png"))
	scene.apply_mood(2)
	scene.lab_ui.show()
	await settle()
	root.get_texture().get_image().save_png(output.path_join("interactive.png"))
	FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	scene.free()
	quit()
