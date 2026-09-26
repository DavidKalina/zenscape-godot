extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	create_timer(240).timeout.connect(func(): quit(2))
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene._paused = true
	scene._ui.hide()
	scene._auto_orbit = false
	scene.target = Vector3(0,2.5,0)
	scene.distance = 57.0
	scene.yaw = 0.35
	scene.polar = 0.80
	scene._update_camera()
	preload("res://scripts/scene_look_presets.gd").apply(scene,"golden_meadow")
	var folder := "/private/tmp/zenscape-places"
	DirAccess.make_dir_recursive_absolute(folder)
	for family in ["massif","foothills","valley"]:
		for version in [3,4]:
			var recipe := {"kind":"inland","version":version,"seed":7,"composition":family,"archetype":"range","landform":"tall-massif" if family=="massif" else "rolling-uplands" if family=="foothills" else "glacial-valley","biome":"woodland","relief":1.1,"breadth":1.1}
			await scene._chunk_editor.form_inland(recipe,false,false)
			await create_timer(2.0).timeout
			for i in range(12): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/%s-v%s.png"%[family,version])
			print("CAPTURE ",family," v",version," objects=",scene._chunk_editor.data.objects.size())
	scene.free()
	quit()
