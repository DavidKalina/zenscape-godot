extends SceneTree
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in range(40):
		await process_frame
		RenderingServer.force_draw(false)
func run() -> void:
	var output := "res://docs/visual-lab/inland-worlds"
	DirAccess.make_dir_recursive_absolute(output)
	var scene = load("res://studies/prototype_inland_worlds.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.set_process(false)
	scene.set_process_unhandled_input(false)
	scene.lab_ui.hide()
	await create_timer(3.0).timeout
	root.mode = Window.MODE_WINDOWED
	root.content_scale_factor = 1.0
	root.size = Vector2i(1600,1000)
	await create_timer(2.0).timeout
	scene.cloud_drift = false
	scene.cloud_clock = 12.0
	var records: Array = []
	for composition in (["marsh"] if "--watercheck" in OS.get_cmdline_user_args() else scene.Genome.COMPOSITIONS):
		scene.choices = {"composition":composition}
		scene.set_scale_variant(0)
		scene.apply_mood(1 if scene.genome.habitat == "arid" else 4 if composition == "marsh" else 0)
		scene._process(0.0)
		for pond in scene._chunk_editor.data.ponds:
			assert(scene._chunk_editor.data.pond_surface(pond).size()>0,"Dry generated pool")
		print("WATER vertices=",scene._chunk_editor.content.pond_vertices.size()," hidden=",scene._chunk_editor.content._water_material.get_shader_parameter("hide_pool_surface"))
		await settle()
		root.get_texture().get_image().save_png(output.path_join(composition+".png"))
		records.append(scene.genome.duplicate(true))
		print("INLAND CAPTURE ",composition)
	if "--watercheck" not in OS.get_cmdline_user_args():
		var cases: Array = []
		for archetype in scene.Genome.ARCHETYPES:
			cases.append({"name":"original-"+archetype,"choices":{"composition":"mountain","archetype":archetype,"landform":"original"}})
		for form in ["sawtooth-ridge","tall-massif","volcanic-crown","glacial-valley"]:
			cases.append({"name":form,"choices":{"composition":"valley" if form=="glacial-valley" else "mountain","landform":form}})
		for habitat in ["redwood","woodland","meadow","arid"]:
			cases.append({"name":"habitat-"+habitat,"choices":{"composition":"valley","landform":"glacial-valley","habitat":habitat}})
		cases.append({"name":"relief-low","choices":{"composition":"mountain","landform":"tall-massif","relief":0.5,"breadth":1.25}})
		cases.append({"name":"relief-high","choices":{"composition":"mountain","landform":"tall-massif","relief":1.6,"breadth":0.65}})
		var valley_heights := PackedFloat32Array()
		var valley_water := PackedByteArray()
		for entry in cases:
			scene.choices = entry.choices
			scene.set_scale_variant(0)
			scene.apply_mood(0)
			if str(entry.name).begins_with("habitat-"):
				if valley_heights.is_empty():
					valley_heights = scene._chunk_editor.data.heights.duplicate()
					valley_water = var_to_bytes(scene._chunk_editor.data.streams)
				assert(valley_heights == scene._chunk_editor.data.heights,"Habitat changed rendered terrain")
				assert(valley_water == var_to_bytes(scene._chunk_editor.data.streams),"Habitat changed rendered water")
			await settle()
			root.get_texture().get_image().save_png(output.path_join(entry.name+".png"))
			records.append({"file":entry.name+".png","genome":scene.genome.duplicate(true)})
			print("INLAND CASE ",entry.name)
	scene.choices = {"composition":"valley","landform":"glacial-valley"}
	scene.set_scale_variant(0)
	var initial = var_to_bytes(scene._chunk_editor.data._snapshot())
	for mood in range(9):
		scene.apply_mood(mood)
		assert(initial == var_to_bytes(scene._chunk_editor.data._snapshot()),"Mood changed native records")
	scene.apply_mood(0)
	scene.lab_ui.show()
	await settle()
	root.get_texture().get_image().save_png(output.path_join("interactive.png"))
	FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	scene.free()
	quit()
