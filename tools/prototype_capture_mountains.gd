extends SceneTree
var scene: Node3D
var output := "res://docs/visual-lab/mountains"
var records: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in range(32):
		await process_frame
		RenderingServer.force_draw(false)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	scene = load("res://studies/prototype_mountain_scale.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.set_process(false)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	scene.lab_ui.hide()
	await create_timer(3.0).timeout
	root.mode = Window.MODE_WINDOWED
	root.content_scale_factor = 1.0
	root.size = Vector2i(1600,1000)
	await create_timer(2.0).timeout
	for view in ["overview","inhabitant"]:
		for index in range(3):
			scene.set_scale_variant(index)
			if view == "overview": scene.reset_lab_camera()
			else: scene.focus_scale_reference()
			scene._process(0.0)
			await settle()
			assert(root.size == Vector2i(1600,1000))
			var filename: String = view+"-%d.png" % index
			root.get_texture().get_image().save_png(output.path_join(filename))
			records.append({"view":view,"variant":index,"camera":str(scene.camera.transform),"size":str(root.size),"peak_units":scene.peak,"avatar_visual_units":scene.avatar_height*scene.actor.scale.y,"avatar_feet":str(scene.actor.position)})
			print("CAPTURE ",filename)
	scene.set_scale_variant(1)
	scene.reset_lab_camera()
	scene._process(0.0)
	scene.lab_ui.show()
	await settle()
	root.get_texture().get_image().save_png(output.path_join("interactive.png"))
	FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	scene.free()
	quit()
