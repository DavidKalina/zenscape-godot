extends SceneTree
const Presets = preload("res://scripts/native_landscape_presets.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1440,900)
	var viewport := root
	viewport.msaa_3d = Viewport.MSAA_8X
	var scene = load("res://studies/diorama.tscn").instantiate()
	viewport.add_child(scene)
	scene._menu.get_parent().hide()
	scene._ui.hide()
	scene._paused = true
	scene._auto_orbit = false
	scene._set_quality(0)
	scene.target = Vector3(0,2.5,0)
	scene.distance = 43.0
	scene.yaw = 0.35
	scene.polar = 0.80
	scene._update_camera()
	for id in Presets.PRESETS:
		if id == "redwood_grove": continue
		await scene._chunk_editor.form_landscape(id,"",false)
		for i in range(20):
			await process_frame
			RenderingServer.force_draw(false)
		var picture := viewport.get_texture().get_image()
		picture.save_png("res://docs/preset-atmospheres/"+id+".png")
		picture.resize(480,320,Image.INTERPOLATE_LANCZOS)
		picture.save_png("res://assets/landscapes/"+id+".png")
		print("ATMOSPHERE CAPTURED ",id)
	scene.free()
	quit()
