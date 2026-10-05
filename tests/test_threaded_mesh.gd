extends SceneTree
## Native mesh arrays remain byte-identical to the retained sequential builder.
const PlateFixture := preload("res://tests/fixtures/plate.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func sequential_reference(data: NativeTerrainData) -> ArrayMesh:
	var enabled := data.native_mesh_enabled
	data.native_mesh_enabled = false
	var mesh := data.build_mesh(true)
	data.native_mesh_enabled = enabled
	return mesh
func sweep(data: NativeTerrainData, label: String) -> void:
	var reference := sequential_reference(data)
	var expected := var_to_bytes(reference.surface_get_arrays(0))
	var shore := var_to_bytes([data._shore_field,data._shore_mask])
	check(var_to_bytes(data.build_mesh(true).surface_get_arrays(0))==expected,label+": synchronous selected kernel matches sequential bytes")
	data.mesh_workers = 0
	var automatic := await data.build_mesh_budgeted(true,self)
	check(var_to_bytes(automatic.surface_get_arrays(0))==expected,label+": automatic shading matches sequential bytes")
	if preload("res://scripts/native_terrain_kernels.gd").get_kernel() != null:
		check(data.last_mesh_profile.workers == 0 and not data.last_mesh_profile.shade_worker,"Automatic native shading avoids a worker round trip")
	for workers in [1,2,4,8]:
		for trial in range(3 if "--benchmark" in OS.get_cmdline_user_args() else 1):
			data.mesh_workers = workers
			var began := Time.get_ticks_usec()
			var mesh := await data.build_mesh_budgeted(true,self)
			check(mesh != null,"Current mesh preparation returns a resource")
			if mesh == null: continue
			check(var_to_bytes(mesh.surface_get_arrays(0))==expected,label+": worker face arrays match sequential bytes")
			check(var_to_bytes([data._shore_field,data._shore_mask])==shore,label+": shoreline and incremental mask match")
			check(mesh.surface_get_format(0)==reference.surface_get_format(0) and mesh.surface_get_material(0)==reference.surface_get_material(0),"Source mesh format and material are preserved")
			check(data.last_mesh_profile.shade_worker,"Face shading executes on workers")
			if data.blank and data._recipe != null and (not data.ponds.is_empty() or not data.streams.is_empty()):
				check(data.last_mesh_profile.prepare_worker,"Nonempty shoreline preparation executes on a worker")
			print("MESH_WORKERS ",label," ",JSON.stringify({"workers":workers,"trial":trial,"completion_ms":(Time.get_ticks_usec()-began)/1000.0,"profile":data.last_mesh_profile}))
func queued(data: NativeTerrainData, results: Array) -> void:
	results.append(await data.build_mesh_budgeted(true,self))
func run() -> void:
	create_timer(120).timeout.connect(func() -> void: quit(2))
	print("MESH_BACKEND ","native" if preload("res://scripts/native_terrain_kernels.gd").get_kernel() != null else "gdscript")
	if "--native-kernels" in OS.get_cmdline_user_args():
		check(preload("res://scripts/native_terrain_kernels.gd").get_kernel() != null,"Native benchmark loads its C++ kernel")
		if failures:
			quit(1)
			return
	var data := NativeTerrainData.new()
	data.setup(PlateFixture.mesh())
	data.paint_grass(Vector2.ZERO,3.0,0.7)
	await sweep(data,"imported-cover")
	data.reset_flat()
	await data.form_foundation(1.0,1.0)
	data.paint_tint(Vector2(-3,2),4.0,Color(0.7,0.1,0.3),0.6)
	await sweep(data,"foundation-tint")
	await preload("res://scripts/native_landscape_presets.gd").form(data,"horn")
	data.brush(Vector2.ZERO,4.0,0.8,"raise",0.0)
	await sweep(data,"sculpted-alpine-water")
	data.brush(Vector2(-9,-9),2.0,0.2,"lower",0.0)
	var incremental := await data.build_mesh_budgeted(false,self)
	check(var_to_bytes(incremental.surface_get_arrays(0))==var_to_bytes(sequential_reference(data).surface_get_arrays(0)),"Incremental face partitions equal a full sequential rebuild")
	var results: Array = []
	for i in range(7): queued(data,results)
	data.heights.fill(2.0)
	var latest := data.build_mesh(true)
	while results.size()<7: await process_frame
	check(results.count(null)==7 and data._mesh_result==latest,"New synchronous mesh supersedes every pending request")
	results.clear()
	queued(data,results)
	data.heights.fill(3.0)
	while results.is_empty(): await process_frame
	check(results[0]==null and data._mesh_result==null,"Direct terrain mutation rejects stale mesh/cache publication")
	check(not data._mesh_busy,"Finite superseded mesh jobs join and release admission")
	print("Threaded mesh: ",failures," failures")
	quit(1 if failures else 0)
