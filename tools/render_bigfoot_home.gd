extends SceneTree
## Trigger one rest, then render the real approach/inspection/bed sequence.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1440,1000)
	var scene = load("res://studies/diorama.tscn").instantiate()
	var folder := "/private/tmp/home-render-"+str(Time.get_ticks_usec())
	scene.library_path = folder
	scene.recent_file = folder+"/recent.cfg"
	root.add_child(scene)
	root.content_scale_factor = 1.0
	await process_frame
	scene.new_diorama()
	scene.set_process(false)
	var data: NativeTerrainData = scene._chunk_editor.data
	data.grass.fill(0.65)
	data.place("broadleaf",Vector2(3,0),0,3.8)
	data.place("shrub",Vector2(4,2),0,0.9)
	data.place("rock",Vector2(0,-2),0,1.0)
	data.place("tree",Vector2(6,-5),0,1.6)
	scene._chunk_editor.refresh()
	scene.invite_bigfoot(Vector3.ZERO)
	scene.set_building(false)
	scene._toolbar.hide()
	scene._notice.hide()
	scene.target = Vector3(2,1,0)
	scene.distance = 11
	scene.yaw = -0.6
	scene.polar = 1.05
	scene._update_camera()
	scene.routine.request("sleep")
	var captured := {}
	for frame in range(1800):
		scene._process(1.0/60.0)
		var name := ""
		if scene.routine._phase == "inspect_home" and scene.routine._elapsed>0.8: name = "inspection"
		if scene.routine.habits.stage>0 and scene.creature.action_clip=="Sleep" and scene.creature._age>1.0: name = "home"
		if not name.is_empty() and not captured.has(name):
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png("res://docs/bigfoot-home/"+name+".png")
			captured[name] = true
		if captured.size() == 2: break
		if frame%60 == 0: await process_frame
	print("Home sequence rendered: ",captured.keys())
	scene.free()
	for name in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder+"/"+name)
	DirAccess.remove_absolute(folder)
	quit(0 if captured.size()==2 else 1)
