extends SceneTree
## A fixed woodland and pose: compare silhouette size without changing defaults.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1440,1000)
	var scene = load("res://studies/diorama.tscn").instantiate()
	var folder := "/private/tmp/zenscape-scale-"+str(Time.get_ticks_usec())
	scene.library_path = folder
	scene.recent_file = folder+"/recent.cfg"
	root.add_child(scene)
	root.content_scale_factor = 1.0
	await process_frame
	scene.new_diorama()
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.reactions_enabled = false
	var data: NativeTerrainData = editor.data
	data.grass.fill(0.8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1847
	# Tall, closely spaced trees surround a narrow opening, with low foreground
	# growth so both silhouettes can be read from exactly the same camera.
	for x in range(-11,12,3):
		for z in range(-11,12,3):
			var p := Vector2(x+rng.randf_range(-0.65,0.65),z+rng.randf_range(-0.65,0.65))
			if absf(p.x)<2.8 and p.y>0: continue
			if p.distance_to(Vector2(0,3))<3.8: continue
			data.place("tree" if rng.randf()<0.7 else "broadleaf",p,rng.randf()*TAU,rng.randf_range(1.25,2.05))
	for i in range(60):
		var p := Vector2(rng.randf_range(-11,11),rng.randf_range(-11,11))
		if p.distance_to(Vector2(0,3))<2.2: continue
		data.place("shrub" if i%3 == 0 else "bank_grass",p,rng.randf()*TAU,rng.randf_range(0.5,1.1))
	for p in [Vector2(-3,5),Vector2(3,2),Vector2(-5,-2)]: data.place("rock",p,0,0.8)
	editor.refresh()
	if not scene.invite_bigfoot(Vector3(0,0,3)):
		push_error("No safe woodland spawn")
		quit(1)
		return
	scene.creature.show()
	scene.creature.rotation.y = 0.35
	scene.creature.player.pause()
	scene.set_building(false)
	scene._toolbar.hide()
	scene._notice.hide()
	scene._ui.hide()
	scene._paused = true
	scene.target = Vector3(0,1,1)
	scene.distance = 37.0
	scene.yaw = 0.12
	scene.polar = 0.86
	scene._update_camera()
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var path := "res://docs/bigfoot-scale/"
	var file := FileAccess.open(path+"woodland.json",FileAccess.WRITE)
	var document := data.to_document()
	document.scene_state = NativeGardenStore.capture(scene)
	document.scene_state.scene._paused = false
	file.store_string(JSON.stringify(document))
	file.close()
	var baseline: Vector3 = scene.creature._visual.scale
	for amount in [1.0,0.7]:
		scene.creature._visual.scale = baseline*amount
		for i in range(4): await process_frame
		RenderingServer.force_draw(false)
		var name := "current" if amount == 1.0 else "smaller"
		root.get_texture().get_image().save_png(path+name+".png")
	print("Woodland comparison: ",data.objects.size()," objects; current vs 70%; feet ",scene.creature.position)
	if "--hold" in OS.get_cmdline_user_args():
		var layer := CanvasLayer.new()
		root.add_child(layer)
		var bar := HBoxContainer.new()
		bar.position = Vector2(24,24)
		layer.add_child(bar)
		for amount in [1.0,0.7]:
			var button := Button.new()
			button.text = "Current size" if amount == 1.0 else "70% size"
			button.custom_minimum_size = Vector2(150,44)
			button.pressed.connect(func() -> void: scene.creature._visual.scale = baseline*amount)
			bar.add_child(button)
		return
	scene.free()
	for name in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder+"/"+name)
	DirAccess.remove_absolute(folder)
	quit()
