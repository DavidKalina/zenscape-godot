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
	var start_travel: Vector2 = scene._atmosphere._travel
	for i in range(30): scene._process(1.0/30.0)
	if scene._atmosphere._travel.distance_to(start_travel)<0.1:
		push_error("FAIL living fog: demo startup leaves shared wind frozen")
		quit(1)
		return
	assert(scene._environment.volumetric_fog_length>=scene.distance+30.0,"Fog view distance clips the far valley")
	await settle()
	root.get_texture().get_image().save_png(output.path_join("rolling-calm.png"))
	var calm_travel: float = scene._atmosphere._travel.distance_to(start_travel)
	var fast_start: Vector2 = scene._atmosphere._travel
	scene._atmosphere.strength = 3.5
	for i in range(360): scene._process(1.0/30.0)
	assert(scene._atmosphere._travel.distance_to(fast_start)/12.0>calm_travel*1.3,"Wind control failed to accelerate shared air")
	await settle()
	root.get_texture().get_image().save_png(output.path_join("rolling-wind.png"))
	assert(snapshot==var_to_bytes(scene._chunk_editor.data._snapshot()),"Atmosphere changed terrain records")
	scene._atmosphere.strength = 1.2
	scene._atmosphere._air_strength = 1.2
	DirAccess.make_dir_recursive_absolute(output.path_join("motion"))
	for frame in range(80):
		for step in range(3): scene._process(1.0/30.0)
		await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(output.path_join("motion/%03d.png" % frame))
	scene.lab_ui.show()
	scene._process(0)
	await settle()
	root.get_texture().get_image().save_png(output.path_join("interactive.png"))
	print("PASS native fog: startup wind advances; strong wind accelerates; terrain unchanged")
	scene.free()
	quit()
