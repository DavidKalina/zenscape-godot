extends SceneTree
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in range(30):
		await process_frame
		RenderingServer.force_draw(false)
func run() -> void:
	var output := "res://docs/visual-lab/living-fog"
	DirAccess.make_dir_recursive_absolute(output)
	var scene = load("res://studies/prototype_living_fog.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.set_process(false)
	scene.set_process_unhandled_input(false)
	scene.lab_ui.hide()
	await create_timer(3).timeout
	root.size = Vector2i(1600,1000)
	root.content_scale_factor = 1.0
	scene.cloud_drift = false
	var snapshot := var_to_bytes(scene._chunk_editor.data._snapshot())
	scene._process(0)
	await settle()
	root.get_texture().get_image().save_png(output.path_join("rolling-calm.png"))
	scene._atmosphere.strength = 3.0
	for i in range(360): scene._process(1.0/30.0)
	await settle()
	root.get_texture().get_image().save_png(output.path_join("rolling-wind.png"))
	assert(snapshot==var_to_bytes(scene._chunk_editor.data._snapshot()),"Atmosphere changed terrain records")
	scene._atmosphere.strength = 0.4
	scene.lab_ui.show()
	scene._process(0)
	await settle()
	root.get_texture().get_image().save_png(output.path_join("interactive.png"))
	print("PASS native fog: calm and wind captures; terrain unchanged")
	scene.free()
	quit()
