extends SceneTree
var scene: Node3D
var output := "res://docs/visual-lab/mountain-clouds"
var records: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in range(32):
		await process_frame
		RenderingServer.force_draw(false)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	scene = load("res://studies/prototype_mountain_clouds.tscn").instantiate()
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
	scene.cloud_drift = false
	scene.cloud_clock = 12.0
	for index in range(3):
		scene.set_scale_variant(index)
		for height in [12.0,24.0,32.0]:
			scene.set_height(height)
			scene.reset_lab_camera()
			scene._process(0.0)
			await settle()
			var filename: String = "shape-%d-height-%d.png" % [index,int(height)]
			assert(root.size == Vector2i(1600,1000))
			root.get_texture().get_image().save_png(output.path_join(filename))
			records.append({"shape":index,"height":height,"peak":scene.peak,"cloud_altitude":scene.cloud_altitude,"camera":str(scene.camera.transform),"size":str(root.size)})
			print("CLOUD CAPTURE ",filename)
	scene.set_scale_variant(0)
	scene.set_height(24.0)
	scene.reset_lab_camera()
	scene.clouds_enabled = false
	scene._process(0.0)
	await settle()
	root.get_texture().get_image().save_png(output.path_join("clouds-off.png"))
	scene.clouds_enabled = true
	scene.set_scale_variant(0)
	scene.reset_lab_camera()
	scene._process(0.0)
	scene.cloud_clock = 32.0
	scene._process(0.0)
	await settle()
	root.get_texture().get_image().save_png(output.path_join("clouds-later.png"))
	scene.lab_ui.show()
	await settle()
	root.get_texture().get_image().save_png(output.path_join("interactive.png"))
	FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	scene.free()
	quit()
