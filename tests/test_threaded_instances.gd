extends SceneTree
## Native rendered instance buffer equivalence. Optional --reference=<script>
## compares an earlier GardenView implementation as an independent oracle.
const PlateFixture := preload("res://tests/fixtures/plate.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func buffers(view: Node3D) -> Dictionary:
	var result := {}
	for batch: MultiMeshInstance3D in view._batches:
		result[batch.get_meta("part")] = batch.multimesh.buffer.to_byte_array()
	return result
func queued(view: Node3D, completed: Array) -> void:
	completed.append(await view._rebuild_instances(self))
func rebuilt(view: GardenView, completed: Array) -> void:
	await view.rebuild(false,self)
	completed.append(true)
func cache_publication(view: GardenView) -> void:
	view.rebuild(true)
	var before := buffers(view)
	var signature := view._view_signature.duplicate()
	var water_signature := view._water_signature.duplicate()
	var revision := view.revision
	view.data.objects[0].angle += 0.1
	view.data.objects_revision += 1
	var completed: Array = []
	rebuilt(view,completed)
	check(completed.is_empty(),"Object-only rebuild is pending before an environment change")
	view.data.grass[0] += 0.1
	while completed.is_empty(): await process_frame
	check(before == buffers(view),"Rejected object-only rebuild preserves its visible batches")
	check(not view._view_ready and signature == view._view_signature and water_signature == view._water_signature and revision == view.revision,"Rejected rebuild does not mark changed environment or object state as rendered")
	view.rebuild(false)
	var repaired := buffers(view)
	view.rebuild(true)
	check(repaired == buffers(view),"Ordinary rebuild repairs a rejected object/environment transaction")
func stale_inputs(view: GardenView) -> void:
	var data: NativeTerrainData = view.data
	for field in ["objects", "heights", "blades", "meadow", "provider", "tints", "environment"]:
		view.rebuild(true)
		var before := buffers(view)
		var before_sources := var_to_bytes(view._sources)
		var completed: Array = []
		queued(view,completed)
		check(completed.is_empty(),field+": rebuild is pending before mutation")
		match field:
			"objects": data.objects[0].angle += 0.3
			"heights": data.heights[0] += 0.2
			"blades": data.blades[0] = 0.0
			"meadow": data.meadow[0] = 0.0
			"provider": view.data = preload("res://scripts/native_terrain_snapshot.gd").for_queries(data)
			"tints": view._tints.canopy = Color.RED
			"environment": data.grass[0] += 0.1
		while completed.is_empty(): await process_frame
		check(completed == [false],field+": changed input rejects pending instances")
		check(before == buffers(view) and before_sources == var_to_bytes(view._sources),field+": rejection preserves visible buffers and sources")
		view.data = data
		view.rebuild(false)
		var repaired := buffers(view)
		view.rebuild(true)
		check(repaired == buffers(view),field+": ordinary rebuild repairs rejected inputs")
func staged_inputs(view: GardenView) -> void:
	view.rebuild(true)
	var before := buffers(view)
	var before_sources := var_to_bytes(view._sources)
	var changed := [false]
	var observer := func() -> void:
		if changed[0]: return
		for child in view.get_children():
			if child is Node3D and not child.visible and child.get_child_count() > 0:
				view.data.objects[0].angle += 0.3
				changed[0] = true
	process_frame.connect(observer)
	var accepted := await view._rebuild_instances(self)
	process_frame.disconnect(observer)
	check(changed[0],"Mutation reaches hidden staging after sampling has finished")
	check(not accepted,"Input mutation during GPU staging rejects the result")
	check(before == buffers(view) and before_sources == var_to_bytes(view._sources),"Stale hidden staging preserves visible buffers and sources")
	check(view.get_children().filter(func(child: Node) -> bool: return child is Node3D and not child.visible and child.get_child_count() > 0).is_empty(),"Rejected staging releases all temporary nodes")
func cached_supersession(view: GardenView) -> void:
	view.rebuild(true)
	var original: Array = view._batches.duplicate()
	var completed: Array = []
	queued(view,completed)
	view.rebuild(false)
	while completed.is_empty(): await process_frame
	check(completed == [false],"A cache-hit rebuild supersedes pending instance preparation")
	check(original == view._batches,"A cache-hit rebuild keeps its visible batches")
	queued(view,completed)
	view.discard_cache()
	while completed.size() < 2: await process_frame
	check(completed == [false,false],"Discarding the view cache cancels pending instances")
	queued(view,completed)
	var preview: Dictionary = view.data.objects[0].duplicate(true)
	preview.angle += 0.25
	view.update_object_preview(preview)
	var preview_buffers := buffers(view)
	var preview_sources := var_to_bytes(view._sources)
	preview.angle += 0.25
	while completed.size() < 3: await process_frame
	check(completed == [false,false,false],"An object preview supersedes pending instances")
	check(preview_buffers == buffers(view) and preview_sources == var_to_bytes(view._sources),"Preview buffers and source records remain paired and detached")
func run() -> void:
	create_timer(90).timeout.connect(func() -> void: quit(2))
	var data := NativeTerrainData.new()
	data.setup(PlateFixture.mesh())
	await preload("res://scripts/native_landscape_presets.gd").form(data,"horn")
	data.blades.fill(0.75)
	data.meadow.fill(0.5)
	for kind in ["tree","rock","flower","layered_tree","explosive","broadleaf","log"]:
		data.place(kind,Vector2(data.objects.size()%10-5,1),0.25,0.8)
	var view := GardenView.new()
	view.data = data
	root.add_child(view)
	view.rebuild(true)
	var expected := buffers(view)
	var sources := var_to_bytes(view._sources)
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--reference="): continue
		var old := GDScript.new()
		old.source_code = FileAccess.get_file_as_string(argument.trim_prefix("--reference=")).replace("class_name GardenView\n","")
		check(old.reload() == OK,"Reference builder compiles")
		var legacy: Node3D = old.new()
		legacy.data = data
		root.add_child(legacy)
		legacy.rebuild(true)
		check(expected == buffers(legacy),"New synchronous buffers equal the pre-change builder byte for byte")
		check(sources == var_to_bytes(legacy._sources),"New source recipes equal the pre-change builder byte for byte")
		legacy.free()
	var original: Array = view._batches.duplicate()
	var progress := [0]
	var observer := func() -> void:
		progress[0] += 1
		check(original.all(func(batch: Node) -> bool: return is_instance_valid(batch) and batch.is_inside_tree()),"Old batches stay visible during preparation")
	process_frame.connect(observer)
	await view.rebuild(true,self)
	process_frame.disconnect(observer)
	check(progress[0] > 0,"Live instance preparation advances the main loop")
	check(expected == buffers(view),"Worker instance buffers match sequential buffers exactly")
	check(sources == var_to_bytes(view._sources),"Worker source recipes and colors match exactly")
	var completed: Array = []
	for i in range(6):
		data.objects[0].angle += 0.1
		queued(view,completed)
	while completed.size() < 6: await process_frame
	check(completed.count(true) == 1 and not view._instance_busy,"Instance requests coalesce and release the worker slot")
	var latest := buffers(view)
	view._rebuild_instances()
	check(latest == buffers(view),"Only the newest instance snapshot is published")
	await stale_inputs(view)
	await cache_publication(view)
	await staged_inputs(view)
	await cached_supersession(view)
	view.free()
	var generic := GardenData.new()
	generic.meadow.fill(0.8)
	generic.place("tree",Vector2.ZERO)
	var generic_view := GardenView.new()
	generic_view.data = generic
	root.add_child(generic_view)
	generic_view.rebuild(true)
	var generic_expected := buffers(generic_view)
	await generic_view.rebuild(true,self)
	check(generic_expected == buffers(generic_view),"Synchronous sampling with staged publication preserves generic garden buffers")
	await staged_inputs(generic_view)
	generic_view.free()
	print("Threaded instances: ",failures," failures")
	quit(1 if failures else 0)
