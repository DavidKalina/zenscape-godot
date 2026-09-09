extends SceneTree
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in range(40):
		await process_frame
		RenderingServer.force_draw(false)
func run() -> void:
	var output := "res://docs/visual-lab/valley-rock"
	DirAccess.make_dir_recursive_absolute(output)
	var scene = load("res://studies/prototype_valley_rock.tscn").instantiate()
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
	for mood in [0,2,6]:
		scene.apply_mood(mood)
		for close in [false,true]:
			if close: scene.cliff_camera()
			else: scene.reset_lab_camera()
			for treatment in range(3):
				scene.set_rock_style(treatment)
				scene._process(0.0)
				await settle()
				assert(initial == var_to_bytes(scene._chunk_editor.data._snapshot()))
				var filename: String = "%s-%s-%d.png" % [scene.MOODS[mood],"close" if close else "overview",treatment]
				root.get_texture().get_image().save_png(output.path_join(filename))
				records.append({"file":filename,"geometry_unchanged":true,"camera":str(scene.camera.transform)})
				print("ROCK CAPTURE ",filename)
	scene.apply_mood(0)
	scene.reset_lab_camera()
	scene.set_rock_style(1)
	scene.lab_ui.show()
	await settle()
	root.get_texture().get_image().save_png(output.path_join("interactive.png"))
	FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	scene.free()
	quit()
