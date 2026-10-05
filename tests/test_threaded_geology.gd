extends SceneTree
## Native scene seam: desert geology must not monopolize its simulation update.
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func settings(kind: String, seed_value := 7) -> Dictionary:
	return {"kind":"inland","version":3,"seed":seed_value,"composition":kind,"archetype":"range","landform":"original","biome":"arid","relief":1.25,"breadth":1.0}
func queued(data: NativeTerrainData, value: Dictionary, results: Array) -> void:
	results.append(await data._set_recipe(value,self))
func run() -> void:
	create_timer(120).timeout.connect(func() -> void: quit(2))
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._chunk_editor.set_process(false)
	for i in range(30):
		scene._process(0.0)
		await process_frame
	var data: NativeTerrainData = scene._chunk_editor.data
	# Exercise the actual recipe preparation API before its scene consumer.
	await data._set_recipe(settings("salt-basin"),self)
	var began := Time.get_ticks_usec()
	scene._process(0.0)
	var elapsed := Time.get_ticks_usec()-began
	print("GEOLOGY_SCENE_UPDATE_MS ",elapsed/1000.0)
	check(elapsed<50000,"Preparing desert geology must not block a live scene update for 50 ms")
	check(data.last_geology_worker,"Live recipe preparation computes geology on workers")
	check(scene._world_visuals._geology.get_image().get_data()==data._recipe_geology.get_data(),"Main-thread texture publication retains exact worker pixels")
	var samples = preload("res://scripts/native_recipe_samples.gd")
	for family in preload("res://scripts/desert_landscape.gd").KINDS:
		var value := settings(family)
		# Exercise the independent, retained WorldVisuals loop as the oracle.
		data._recipe_settings = value.duplicate(true)
		data._recipe = NativeTerrainRecipe.new(value)
		data._recipe_geology = null
		scene._world_visuals._signature.clear()
		scene._world_visuals.sync(scene)
		var expected: PackedByteArray = scene._world_visuals._geology.get_image().get_data()
		for workers in [1,2,4,8]:
			for trial in range(3 if "--benchmark" in OS.get_cmdline_user_args() else 1):
				var gaps: Array[float] = []
				var clock := [Time.get_ticks_usec()]
				var observe := func() -> void:
					var now := Time.get_ticks_usec()
					gaps.append((now-clock[0])/1000.0)
					clock[0] = now
				process_frame.connect(observe)
				var started := Time.get_ticks_usec()
				var result: Dictionary = await samples.build_parallel(value,PackedVector2Array(),PackedFloat64Array(),PackedFloat64Array(),false,self,workers)
				var completion := (Time.get_ticks_usec()-started)/1000.0
				process_frame.disconnect(observe)
				gaps.append((Time.get_ticks_usec()-clock[0])/1000.0)
				gaps.sort()
				check(result.geology.get_data()==expected,family+": partitioned geology matches original pixel bytes")
				check(result.geology_worker,"Every geology partition executes on a worker")
				print("GEOLOGY_WORKERS ",JSON.stringify({"family":family,"workers":workers,"trial":trial,"completion_ms":completion,"worker_cpu_ms":result.geology_usec/1000.0,"frame_p50_ms":gaps[int(gaps.size()*0.5)],"frame_p95_ms":gaps[int(gaps.size()*0.95)],"frame_p99_ms":gaps[int(gaps.size()*0.99)],"frame_max_ms":gaps[-1]}))
	# A newer ordinary recipe must supersede a map still being computed.
	data._set_recipe({})
	var results: Array = []
	queued(data,settings("salt-basin",37),results)
	check(data._recipe_geology==null,"Pending geology is not published before its recipe")
	data._set_recipe({"kind":"foundation","elevation":0.0,"relief":1.0})
	while results.is_empty(): await process_frame
	check(not results[0] and data._recipe_geology==null,"Superseded desert map cannot overwrite a newer ordinary recipe")
	results.clear()
	for seed_value in range(7,14): queued(data,settings("salt-basin",seed_value),results)
	while results.size()<7: await process_frame
	check(results.count(true)==1 and data._recipe_settings.seed==13,"Burst geology requests coalesce with their recipe generation")
	var latest := data._recipe_geology.get_data()
	data._set_recipe({})
	data._set_recipe(settings("salt-basin",13))
	check(data._recipe_geology.get_data()==latest,"Latest live geology matches synchronous recipe preparation")
	var before := data.to_document()
	data.begin_stroke()
	await data.form_foundation(1.0,1.0,self)
	data.end_stroke()
	check(data._recipe_geology==null,"An ordinary recipe releases the previous desert image")
	check(data.undo() and data.to_document()==before and data._recipe_geology.get_data()==latest,"Undo restores exact terrain state and desert geology")
	check(data.redo() and data._recipe_geology==null,"Redo removes the restored desert image")
	scene._world_visuals.sync(scene)
	check(scene._world_visuals._geology==null,"The scene clears desert texture state after redo")
	# Small geometry still has a substantial 128x128 geology workload.
	var small := NativeTerrainData.new()
	await small._set_recipe(settings("desert"),self)
	check(small._recipe_geology.get_size()==Vector2i(128,128) and small.last_geology_worker,"Small terrain providers also prepare full geology on workers")
	await data._set_recipe(settings("salt-basin",13),self)
	data._recipe_settings = settings("desert")
	data._recipe = NativeTerrainRecipe.new(data._recipe_settings)
	scene._world_visuals.sync(scene)
	check(scene._world_visuals._geology.get_image().get_data()==small._recipe_geology.get_data(),"Hand-constructed recipes cannot reuse a cached image from different settings")
	check(not data._recipe_busy and preload("res://scripts/background_work.gd").statistics().jobs==0,"Every geology partition is joined through the existing owner slot")
	scene.free()
	print("Threaded geology: ",failures," failures")
	quit(1 if failures else 0)
