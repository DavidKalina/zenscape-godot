extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1440,900)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440,900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene = load("res://studies/diorama.tscn").instantiate()
	viewport.add_child(scene)
	scene._menu.get_parent().hide()
	scene._paused = true
	scene._ui.hide()
	await scene._chunk_editor.form_landscape("redwood_grove","",false)
	scene._auto_orbit = false
	scene.target = Vector3(0,7,0)
	scene.distance = 43.0
	scene.polar = 1.12
	scene.yaw = -0.45
	scene._update_camera()
	for i in range(30):
		await process_frame
		RenderingServer.force_draw(false)
	var picture := viewport.get_texture().get_image()
	picture.save_png("res://docs/redwood-grove/overview.png")
	picture.resize(480,320,Image.INTERPOLATE_LANCZOS)
	picture.save_png("res://assets/landscapes/redwood_grove.png")
	scene.target = Vector3(1.2,3.0,-3)
	scene.distance = 13.0
	scene.polar = 1.52
	scene.yaw = 0.0
	scene._update_camera()
	for i in range(30):
		await process_frame
		RenderingServer.force_draw(false)
	viewport.get_texture().get_image().save_png("res://docs/redwood-grove/inside.png")
	print("REDWOOD GROVE CAPTURED trees=",scene._redwood_mist.redwoods," mist=",scene._redwood_mist.active)
	scene.free()
	quit()
