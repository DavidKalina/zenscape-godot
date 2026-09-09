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
	for i in range(360):
		if i%6==0: scene.stroke(1,1 if i%30==0 else 0)
		scene._process(1.0/30.0)
	assert(scene.flow>0.35,"Typing did not build wind")
	await settle()
	root.get_texture().get_image().save_png(output.path_join("rolling-wind.png"))
	scene.set_fog_mode(2)
	scene.replay_veil()
	scene.coverage = 1.0
	scene._process(0)
	await settle()
	root.get_texture().get_image().save_png(output.path_join("veil-whole.png"))
	for stage in range(2):
		for i in range(600):
			if i%6==0: scene.stroke(1,1 if i%30==0 else 0)
			scene._process(1.0/30.0)
		await settle()
		root.get_texture().get_image().save_png(output.path_join("veil-tearing.png" if stage==0 else "veil-cleared.png"))
	assert(scene.coverage<0.03,"Writing veil failed to clear")
	var high_flow: float = scene.flow
	for i in range(1800): scene._process(1.0/30.0)
	assert(scene.flow<high_flow*0.1,"Wind failed to settle")
	assert(snapshot==var_to_bytes(scene._chunk_editor.data._snapshot()),"Atmosphere changed terrain records")
	scene.set_fog_mode(1)
	scene.lab_ui.show()
	scene._process(0)
	await settle()
	root.get_texture().get_image().save_png(output.path_join("interactive.png"))
	print("PASS native fog: typing builds wind, veil clears, rest decays, terrain unchanged")
	scene.free()
	quit()
