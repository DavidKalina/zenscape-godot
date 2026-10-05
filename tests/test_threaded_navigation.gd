extends SceneTree
## Native geometry + live clearance regression. Run graphically, serialized.
const PlateFixture := preload("res://tests/fixtures/plate.gd")
var failures := 0
var clearance_calls := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func wall(point: Vector3) -> bool:
	check(WorkerThreadPool.get_caller_task_id() == -1 and WorkerThreadPool.get_caller_group_id() == -1,"Arbitrary clearance stays on the main thread")
	clearance_calls += 1
	return not (absf(point.x-4.0)<0.6 and absf(point.z)<3.0)
func moving(point: Vector3) -> bool:
	check(WorkerThreadPool.get_caller_task_id() == -1 and WorkerThreadPool.get_caller_group_id() == -1,"Dynamic clearance stays on the main thread")
	return not (point.x < -4 and point.z > 5)
func complete(nav: CreatureNavigation, physics := false) -> Dictionary:
	var began := Time.get_ticks_usec()
	var previous := began
	var gaps: Array[float] = []
	var max_slice := 0
	while true:
		if Time.get_ticks_usec()-began > 10000000:
			check(false,"Navigation must finish within the fixture deadline")
			quit(1)
			return {}
		var start := Time.get_ticks_usec()
		var done := nav.advance_rebuild(2000)
		max_slice = maxi(max_slice,Time.get_ticks_usec()-start)
		if done: break
		check(nav.path(Vector3.ZERO,Vector3.ONE).is_empty(),"No route escapes a partial replacement map")
		if physics: await physics_frame
		else: await process_frame
		var now := Time.get_ticks_usec()
		gaps.append((now-previous)/1000.0)
		previous = now
	var elapsed := (Time.get_ticks_usec()-began)/1000.0
	if gaps.is_empty(): gaps.append(0.0)
	gaps.sort()
	return {"completion_ms":elapsed,"slice_max_ms":max_slice/1000.0,"loop_p95_ms":gaps[int(gaps.size()*0.95)],"loop_p99_ms":gaps[int(gaps.size()*0.99)],"loop_max_ms":gaps[-1],"submit_ms":nav.last_submit_usec/1000.0,"validation_ms":nav.last_validation_usec/1000.0,"workers":nav.last_worker_count}
func run() -> void:
	create_timer(120).timeout.connect(func() -> void: quit(2))
	var source: Node3D = PlateFixture.dress(load("res://assets/zen_reference/geometry.scn").instantiate())
	var data := NativeTerrainData.new()
	data.setup(source.get_node("terrain").mesh)
	data.reset_flat()
	for i in range(data.points.size()): data.heights[i] = -(1.0-smoothstep(0.0,3.5,data.points[i].length()))
	check(data.add_pond(Vector2.ZERO,-0.2),"Fixture contains an actual native pond")
	data.streams = [{"pts":[{"x":-8.0,"z":-10.0,"h":0.0},{"x":-8.0,"z":10.0,"h":0.0}],"width":0.5,"depth":0.1,"surface":0.1,"capHead":false,"capTail":false}]
	var expected := CreatureNavigation.new()
	expected.dynamic_clearance = moving
	expected.rebuild(data,wall,0.35,0.3)
	var sliced := CreatureNavigation.new()
	sliced.dynamic_clearance = moving
	sliced.begin_rebuild(data,wall,0.35,0.3)
	print("NAVIGATION_COOPERATIVE ",JSON.stringify(await complete(sliced)))
	check(sliced._nodes == expected._nodes and sliced._cells == expected._cells,"Cooperative reference map is exact")
	for workers in [1,2,4,8]:
		for trial in range(3 if "--benchmark" in OS.get_cmdline_user_args() else 1):
			var nav := CreatureNavigation.new()
			nav.thread_workers = workers
			nav.dynamic_clearance = moving
			nav.begin_rebuild(data,wall,0.35,0.3,true)
			var result: Dictionary = await complete(nav)
			result.trial = trial
			print("NAVIGATION_WORKERS ",JSON.stringify(result))
			check(nav.last_worker_executed,"Every candidate partition executes on a worker")
			check(nav._nodes.to_byte_array() == expected._nodes.to_byte_array() and nav._cells == expected._cells,"Worker map retains exact node bytes and indices with ponds, streams, slopes and live clearance")
	check(clearance_calls>0,"Live clearance was exercised")
	var latest := CreatureNavigation.new()
	latest.begin_rebuild(data,Callable(),0.35,0.3,true)
	latest.advance_rebuild(2000)
	var task: int = latest._work._task
	for i in range(8):
		data.heights.fill(float(i)*0.1)
		latest.begin_rebuild(data,Callable(),0.35,0.3,true)
		check(latest._work._task == task,"Repeated edits do not enqueue competing worker groups")
	await complete(latest)
	expected.dynamic_clearance = Callable()
	expected.rebuild(data,Callable(),0.35,0.3)
	check(latest._nodes == expected._nodes and latest._cells == expected._cells,"Superseded scans cannot publish over the latest terrain")
	check(not latest._work.active(),"Published navigation reclaims the pool task")
	# A live native world queries physics only in the validation stage.
	data.place("rock",Vector2(4,0),0,2.0)
	var collisions := NativePlayCollisions.new()
	root.add_child(collisions)
	collisions.rebuild(data)
	await physics_frame
	await physics_frame
	var physics_clearance := func(point: Vector3) -> bool:
		check(WorkerThreadPool.get_caller_task_id() == -1 and WorkerThreadPool.get_caller_group_id() == -1,"Physics queries never execute on workers")
		return collisions.can_stand(point)
	expected.rebuild(data,physics_clearance)
	latest.begin_rebuild(data,physics_clearance,CreatureNavigation.STEP,CreatureNavigation.MAX_RISE,true)
	await complete(latest,true)
	check(latest._nodes == expected._nodes and latest._cells == expected._cells,"Physics validation agrees with sequential shape queries")
	collisions.free()
	# Original Fidelity's ground, water triangles and solid bounds are copied.
	var habitat = preload("res://scripts/fidelity_habitat.gd").new()
	habitat.setup(source)
	expected.rebuild(habitat,habitat.clear_at,0.35,0.3)
	latest.begin_rebuild(habitat,habitat.clear_at,0.35,0.3,true)
	await complete(latest)
	check(latest._worker_checks_clearance,"Explicit static habitat clearance runs on its copied provider")
	check(latest._nodes == expected._nodes and latest._cells == expected._cells,"Copied Fidelity ground/water/solids match exactly")
	# Dropping an owner joins its finite group without retaining the navigation.
	var abandoned := CreatureNavigation.new()
	abandoned.begin_rebuild(data,Callable(),0.35,0.3,true)
	abandoned.advance_rebuild(2000)
	var weak: WeakRef = weakref(abandoned)
	abandoned = null
	check(weak.get_ref() == null,"Dropping the navigation owner releases its worker inputs and task")
	source.free()
	print("Threaded navigation: ",failures," failures")
	quit(1 if failures else 0)
