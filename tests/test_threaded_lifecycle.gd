extends SceneTree
## Native geometry, overlapping owners, burst replacement and scene teardown.
const Work = preload("res://scripts/background_work.gd")
const OWNERS := 4
const BURST := 7
const PlateFixture := preload("res://tests/fixtures/plate.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func recipe(data: NativeTerrainData, elevation: float, results: Array) -> void:
	results.append(await data._set_recipe({"kind":"foundation","elevation":elevation,"relief":1.0},self))
func mesh(data: NativeTerrainData, results: Array) -> void:
	results.append(await data.build_mesh_budgeted(true,self))
func drained(label: String) -> void:
	var began := Time.get_ticks_usec()
	while Work.statistics().jobs > 0 and Time.get_ticks_usec()-began < 10000000:
		await process_frame
	check(Work.statistics().jobs==0 and Work.statistics().partitions==0,label+": every submitted pool job is joined")
	print("LIFECYCLE_DRAIN ",label," ",JSON.stringify(Work.statistics()))
func teardown(phase: String) -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.set_process(false)
	if phase == "recipe":
		editor.form_range(true)
		check(editor.data._recipe_busy,"Scene teardown catches active recipe preparation")
	elif phase == "mesh":
		# This fixture specifically destroys an owner while a job is pending.
		# Automatic native shading can finish inline, so request workers here.
		editor.data.mesh_workers = 2
		editor.data.brush(Vector2.ZERO,3.0,0.3,"raise",0.0)
		editor.refresh(self)
		check(editor.data._mesh_busy,"Scene teardown catches active mesh preparation")
	elif phase == "instances":
		editor.data.blades.fill(0.8)
		editor.content.rebuild(true,self)
		check(editor.content._instance_busy,"Scene teardown catches active instance preparation")
	elif phase == "blast":
		var charge := editor.data.place("explosive",Vector2.ZERO)
		editor.refresh()
		editor.explosives.target_id = charge
		editor.explosives.detonate(true)
		while editor.explosives.bodies.is_empty() and editor.explosives.firing: await process_frame
		check(editor.explosives._staging and not editor.explosives.bodies.is_empty(),"Scene teardown catches prepared blast bodies before physics release")
	elif phase == "reflections":
		editor.data.reset_flat()
		for i in range(editor.data.points.size()): editor.data.heights[i] = -(1.0-smoothstep(0.0,3.5,editor.data.points[i].length()))
		check(editor.data.add_pond(Vector2.ZERO,-0.2),"Reflection lifecycle fixture contains a native pond")
		editor.refresh()
		scene._planar_water.clear()
		scene._planar_water.revision = -1
		scene._planar_water.sync(scene,self)
		check(scene._planar_water._setup_busy,"Source replacement interrupts active reflection preparation")
		while scene._planar_water._setup_busy and scene._planar_water.get_child_count()==0: await process_frame
		editor.force_refresh()
		while scene._planar_water._setup_busy: await process_frame
		check(scene._planar_water.views.is_empty(),"Changed source batches discard pending reflection setup")
		scene._planar_water.sync(scene,self)
		check(scene._planar_water._setup_busy,"Scene teardown catches pending reflection setup")
	else:
		editor._map_ready = false
		editor._update_surface_maps(false,self)
		check(editor._map_busy,"Scene teardown catches active surface preparation")
	# Debris/reflection staging can wait only on a publication frame after all
	# workers have joined, especially with inline native shading. The dedicated
	# worker phases must still prove that destruction interrupts submitted work.
	if phase in ["recipe","mesh","maps","instances"]:
		check(Work.statistics().jobs>0,"Teardown occurs with submitted work")
	var owner: WeakRef = weakref(editor)
	var terrain: WeakRef = weakref(editor.data)
	scene.free()
	check(owner.get_ref()==null,"Scene deletion releases its editor immediately")
	editor = null
	await drained(phase)
	for _frame in range(3): await process_frame
	check(terrain.get_ref()==null,"Completed abandoned work releases its terrain inputs")
func run() -> void:
	create_timer(120).timeout.connect(func() -> void: quit(2))
	var source_mesh: ArrayMesh = PlateFixture.mesh()
	var recipes: Array[NativeTerrainData] = []
	var meshes: Array[NativeTerrainData] = []
	var nav_data: Array[NativeTerrainData] = []
	var navigators: Array[CreatureNavigation] = []
	var recipe_results: Array = []
	var mesh_results: Array = []
	for i in range(OWNERS):
		var data := NativeTerrainData.new()
		data.setup(source_mesh)
		data.reset_flat()
		recipes.append(data)
		recipe_results.append([])
		var shaded := NativeTerrainData.new()
		shaded.setup(source_mesh)
		shaded.mesh_workers = 2
		shaded.paint_grass(Vector2(i,0),3.0,0.7)
		meshes.append(shaded)
		mesh_results.append([])
		var ground := NativeTerrainData.new()
		ground.setup(source_mesh)
		ground.reset_flat()
		nav_data.append(ground)
		navigators.append(CreatureNavigation.new())
	var began := Time.get_ticks_usec()
	for i in range(OWNERS): recipe(recipes[i],0.0,recipe_results[i])
	for i in range(OWNERS):
		navigators[i].begin_rebuild(nav_data[i],Callable(),0.35,0.3,true)
		navigators[i].advance_rebuild(2000)
	for i in range(OWNERS): mesh(meshes[i],mesh_results[i])
	var first := Work.statistics()
	for request in range(1,BURST):
		for i in range(OWNERS):
			recipe(recipes[i],float(request),recipe_results[i])
			mesh(meshes[i],mesh_results[i])
			nav_data[i].heights.fill(float(request)*0.1)
			navigators[i].begin_rebuild(nav_data[i],Callable(),0.35,0.3,true)
	check(Work.statistics().jobs==first.jobs and Work.statistics().partitions==first.partitions,"Burst replacement does not submit more simultaneous groups")
	while true:
		var done := true
		for i in range(OWNERS):
			if not navigators[i].advance_rebuild(2000): done = false
			if recipe_results[i].size()<BURST or mesh_results[i].size()<BURST: done = false
		if done: break
		await process_frame
	print("LIFECYCLE_OVERLAP ",JSON.stringify({"owners_per_stage":OWNERS,"requests_per_owner":BURST,"completion_ms":(Time.get_ticks_usec()-began)/1000.0,"submitted":first,"final":Work.statistics()}))
	for i in range(OWNERS):
		check(recipe_results[i].count(true)==1,"Only the latest recipe request publishes")
		var recipe_bytes := var_to_bytes([recipes[i]._recipe_heights,recipes[i]._recipe_gradients])
		recipes[i]._set_recipe({})
		recipes[i]._set_recipe({"kind":"foundation","elevation":float(BURST-1),"relief":1.0})
		check(recipe_bytes==var_to_bytes([recipes[i]._recipe_heights,recipes[i]._recipe_gradients]),"Overlapping recipes match sequential output exactly")
		check(mesh_results[i].count(null)==BURST-1,"Only the latest mesh request publishes")
		var actual: ArrayMesh = meshes[i]._mesh_result
		check(var_to_bytes(actual.surface_get_arrays(0))==var_to_bytes(meshes[i].build_mesh(true).surface_get_arrays(0)),"Overlapping mesh output is byte-exact")
		var expected := CreatureNavigation.new()
		expected.rebuild(nav_data[i],Callable(),0.35,0.3)
		check(navigators[i]._nodes.to_byte_array()==expected._nodes.to_byte_array() and navigators[i]._cells==expected._cells,"Overlapping navigation publishes the exact latest map")
	await drained("overlap")
	# RefCounted destruction must also join without calling dying script methods.
	var abandoned := CreatureNavigation.new()
	abandoned.begin_rebuild(nav_data[0],Callable(),0.35,0.3,true)
	abandoned.advance_rebuild(2000)
	var weak: WeakRef = weakref(abandoned)
	abandoned = null
	check(weak.get_ref()==null,"An abandoned navigation owner is not retained by its worker callable")
	await drained("navigation-owner")
	# The async convenience helper must own its finite job until the join,
	# independently of a scene dropping the last external reference.
	var finite = Work.new()
	var finite_ref: WeakRef = weakref(finite)
	finite.run(func(): OS.delay_msec(30); return 42,self)
	finite = null
	check(finite_ref.get_ref()!=null,"An awaiting finite job survives loss of its caller's reference")
	await drained("finite-helper")
	await process_frame
	check(finite_ref.get_ref()==null,"A completed finite helper releases itself after joining")
	for phase in ["recipe","mesh","maps","instances","blast","reflections"]: await teardown(phase)
	print("Threaded lifecycle: ",failures," failures")
	quit(1 if failures else 0)
