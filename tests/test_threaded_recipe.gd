extends SceneTree
## CPU-only fixture: the real recipe preparation path, without a renderer.
signal pending_finished
var failures := 0
var ticks := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func count_frame() -> void: ticks += 1
func superseded_formation(data: RefCounted) -> void:
	await data.form_foundation(2.0,1.0,self)
	pending_finished.emit()
func queued_recipe(data: RefCounted, elevation: float, completed: Array) -> void:
	var accepted: bool = await data._set_recipe({"kind":"foundation","elevation":elevation,"relief":1.0},self)
	completed.append(accepted)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var job = preload("res://scripts/background_work.gd").new()
	check(await job.run(func(): return WorkerThreadPool.get_caller_task_id(),self) >= 0,"Live jobs execute on a worker")
	check(await job.run(func(): return WorkerThreadPool.get_caller_task_id()) == -1,"Null-tree jobs stay synchronous")
	process_frame.connect(count_frame)
	var data = preload("res://scripts/native_terrain_data.gd").new()
	for z in range(65):
		for x in range(65): data.points.append(Vector2(-14.0+x*28.0/64.0,-14.0+z*28.0/64.0))
	for z in range(64):
		for x in range(64):
			for offset in [1.0/3.0,2.0/3.0]:
				data._face_x.append(-14.0+(x+offset)*28.0/64.0)
				data._face_z.append(-14.0+(z+offset)*28.0/64.0)
	for kind in ["foundation","range"]:
		var settings = {"kind":"foundation","elevation":0.0,"relief":1.0} if kind == "foundation" else {"kind":"range","height":1.0,"width":1.0,"heading":0.0,"variation":0}
		data._set_recipe({})
		var start = Time.get_ticks_usec()
		data._set_recipe(settings)
		var reference = var_to_bytes([data._recipe_heights,data._recipe_gradients])
		var sync_ms = (Time.get_ticks_usec()-start)/1000.0
		print("RECIPE ",kind," sync_ms=",sync_ms)
		data._set_recipe({})
		ticks = 0
		start = Time.get_ticks_usec()
		await data._set_recipe(settings,self)
		var elapsed = (Time.get_ticks_usec()-start)/1000.0
		var equal = reference == var_to_bytes([data._recipe_heights,data._recipe_gradients])
		print("RECIPE ",kind," live_ms=",elapsed," equal=",equal)
		check(equal,"Worker samples match synchronous samples byte for byte")
		check(ticks > 0,"The main loop advances during sampling")
		# This fixture exposes the multi-second completion delay of 2 ms slices.
		if "--benchmark" in OS.get_cmdline_user_args() and elapsed > sync_ms*2.0+100.0:
			failures += 1
			push_error("Live sampling should avoid the multi-frame cooperative scheduling penalty")
	if "--workers" in OS.get_cmdline_user_args():
		var settings := {"kind":"range","height":1.0,"width":1.0,"heading":0.0,"variation":0}
		var samples = preload("res://scripts/native_recipe_samples.gd")
		var reference: Dictionary = samples.build(settings,data.points,data._face_x,data._face_z,true)
		for workers in [1,2,4,8]:
			for trial in range(3):
				var gaps: Array[float] = []
				var clock := [Time.get_ticks_usec()]
				var observe := func() -> void:
					var now := Time.get_ticks_usec()
					gaps.append((now-clock[0])/1000.0)
					clock[0] = now
				process_frame.connect(observe)
				var began := Time.get_ticks_usec()
				var parallel: Dictionary = await samples.build_parallel(settings,data.points,data._face_x,data._face_z,true,self,workers)
				var elapsed := (Time.get_ticks_usec()-began)/1000.0
				process_frame.disconnect(observe)
				gaps.sort()
				check(var_to_bytes([reference.heights,reference.gradients,reference.water]) == var_to_bytes([parallel.heights,parallel.gradients,parallel.water]),"Parallel partitions retain byte-exact height, gradient and water tables")
				print("WORKER_PROFILE ",JSON.stringify({"workers":workers,"trial":trial,"completion_ms":elapsed,"loop_p95_ms":gaps[int(gaps.size()*0.95)],"loop_p99_ms":gaps[int(gaps.size()*0.99)],"loop_max_ms":gaps[-1]}))
	# Water values must retain float64 precision and the same sample positions.
	data._set_recipe({})
	data.ponds.append({"x":0.0,"z":0.0,"level":1.0})
	await data._set_recipe({"kind":"foundation","elevation":0.25,"relief":1.0},self)
	var expected_water := PackedFloat64Array()
	for z in range(NativeRecipeWater.W):
		for x in range(NativeRecipeWater.W):
			expected_water.append(data._recipe.height(-14.0+x*NativeRecipeWater.CELL,-14.0+z*NativeRecipeWater.CELL))
	check(data._water_grid_h.to_byte_array() == expected_water.to_byte_array(),"Worker pond grid retains exact double precision")
	# Cancel while the finite worker is still running. Even the cached empty
	# recipe must supersede it, and the public formation caller must not apply it.
	data._set_recipe({})
	data.heights = PackedFloat32Array([42.0])
	superseded_formation(data)
	check(data._recipe == null,"Incomplete samples are never published")
	data._set_recipe({})
	await pending_finished
	check(data._recipe == null and data._recipe_heights.is_empty(),"Superseded tables are discarded")
	check(data.heights == PackedFloat32Array([42.0]),"Superseded formation cannot overwrite heights")
	var completed: Array = []
	for i in range(8): queued_recipe(data,float(i),completed)
	while completed.size() < 8: await process_frame
	check(completed.count(true) == 1 and data._recipe_settings.elevation == 7.0,"Burst requests coalesce to the latest generation")
	check(not data._recipe_busy,"Joined superseded and final jobs release the owner slot")
	# Exercise connected water and inland constructors on the worker as well.
	var small = preload("res://scripts/native_terrain_data.gd").new()
	small.points = PackedVector2Array([Vector2(-14,-14),Vector2(0,0),Vector2(3,7)])
	small._face_x = PackedFloat64Array([0.25,3.125])
	small._face_z = PackedFloat64Array([-1.25,6.875])
	var genome = preload("res://scripts/inland_genome.gd").sample(37,{"composition":"mountain"})
	var inland := {"kind":"inland","version":3,"seed":37,"composition":"mountain","archetype":genome.archetype,"landform":genome.landform,"biome":genome.habitat,"relief":1.0,"breadth":1.0}
	for settings in [preload("res://scripts/native_landscape_presets.gd").recipe("valley"),inland]:
		small._set_recipe(settings)
		var expected := var_to_bytes([small._recipe_heights,small._recipe_gradients])
		small._set_recipe({})
		await small._set_recipe(settings,self)
		check(expected == var_to_bytes([small._recipe_heights,small._recipe_gradients]),"Connected and inland recipes match across threads")
	# Fixed topology probe preparation must not invalidate existing live samples.
	var topology := NativeTerrainData.new()
	topology.points = PackedVector2Array([Vector2(-2,-2),Vector2(2,-2),Vector2(0,2)])
	topology.vertex_ids = PackedInt32Array([0,1,2])
	topology._face_center = PackedVector2Array([Vector2.ZERO])
	for z in range(-1,1):
		for x in range(-1,1): topology._buckets[Vector2i(x,z)] = [0]
	topology._ensure_face_probes()
	var expected_faces := topology._locate_face.duplicate()
	var expected_u := topology._locate_u.duplicate()
	var expected_v := topology._locate_v.duplicate()
	topology._face_probe.clear()
	var old_size := topology._locate_face.size()
	await topology._prepare_face_probes(self)
	for i in range(4):
		var slot: int = topology._face_probe[i]
		check(slot >= old_size,"Worker probes append without invalidating live cache indices")
		check(topology._locate_face[slot] == expected_faces[i] and topology._locate_u[slot] == expected_u[i] and topology._locate_v[slot] == expected_v[i],"Worker probe triangle and float64 weights match exactly")
	process_frame.disconnect(count_frame)
	print("Threaded recipe: ",failures," failures")
	quit(1 if failures else 0)
