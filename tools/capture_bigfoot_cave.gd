extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1440,960)
	var scene = load("res://studies/bigfoot_cave.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._paused = false
	scene._growth.terrain = 1.0
	scene._growth.foliage = 1.0
	scene._growth.water = 1.0
	scene._growth.replaying = false
	scene._growth.publish()
	scene._celestial.cycling = false
	scene._celestial.set_phase(0.4)
	scene._precipitation.set_weather(0,true)
	for child in scene.find_children("*","CanvasLayer",true,false): child.hide()
	scene._ui.hide()
	scene._life_status.get_parent().hide()
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://docs/bigfoot-cave/placement.png")
	print("CAVE REQUEST ",scene.routine.cave.request("sleep"))
	var captured := {}
	for frame in range(6000):
		scene._process(1.0/60.0)
		var cave = scene.routine.cave
		var name := ""
		if cave.phase == "entering" and cave._elapsed>2.5: name = "entering"
		if cave.phase == "resting" and cave._away>2.0: name = "sheltered"
		if cave.phase == "leaving" and cave._elapsed>1.6: name = "emerging"
		if not name.is_empty() and not captured.has(name):
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png("res://docs/bigfoot-cave/"+name+".png")
			captured[name] = true
		if captured.size()==3: break
		if frame%60==0: await process_frame
	print("CAVE CAPTURE ",captured.keys()," phase ",scene.routine.cave.phase," position ",scene.creature.position)
	scene._chunk_editor.save_path = "res://docs/bigfoot-cave/Fidelity cave.json"
	# Openable in the main product as a populated world.
	var document: Dictionary = scene._chunk_editor.data.to_document()
	document.scene_state = NativeGardenStore.capture(scene)
	var exterior: Vector3 = scene.navigation.nearest_safe(Vector3(5.6,0.543902,-7.7))
	document.scene_state.diorama = {"resident":true,"position":[exterior.x,exterior.y,exterior.z]}
	var file := FileAccess.open(scene._chunk_editor.save_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(document,"",true,true))
	file.close()
	scene.free()
	quit(0 if captured.size()==3 else 1)
