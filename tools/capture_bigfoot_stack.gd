extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1440,1080)
	var scene = load("res://studies/bigfoot_lair.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._paused = false
	scene._growth.terrain = 1
	scene._growth.foliage = 1
	scene._growth.water = 1
	scene._growth.replaying = false
	scene._growth.publish()
	scene._celestial.cycling = false
	scene._celestial.set_phase(0.4)
	scene._precipitation.set_weather(0,true)
	for child in scene.find_children("*","CanvasLayer",true,false): child.hide()
	scene._ui.hide()
	print("VISIT ",scene.routine.cave.request("hibernate"))
	for frame in range(2400):
		scene._process(1.0/60.0)
		if scene.routine.cave.concealed: break
	for frame in range(180): scene._process(1.0/60.0)
	scene.cave_hover = false
	for view in ["front","side","back","windows","inspect"]:
		scene._focus_stack()
		if view=="side": scene.yaw = -0.9
		if view=="back": scene.yaw = 2.5
		if view=="windows": scene._focus_lair()
		scene._update_camera()
		if view=="inspect":
			# Rest a synthetic pointer on the facing wall until the glide settles.
			scene.cave_hover = true
			var side: int = scene.lair.side_facing(scene.camera.global_position)
			scene.cave_pointer = scene.camera.unproject_position(scene.lair.to_global(scene.lair.wall_normal(side)*scene.lair.HALF_WIDTH+Vector3.UP*4.0))
			for frame in range(260): scene._update_cutaway(1.0/60.0)
		# Let the framed wall dissolve (or the others close) before capturing.
		scene._update_cutaway(1.0)
		await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("/private/tmp/bigfoot-stack-"+view+".png")
	print("STACK CAPTURE ",scene.routine.cave.phase," position ",scene.creature.position)
	scene.free()
	quit()
