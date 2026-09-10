extends SceneTree
## Compare private row workers against the retained sequential pixel loops.
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func capture(editor: NativeChunkEditor) -> PackedByteArray:
	return var_to_bytes([editor._map_base.get_data(),editor._map_ground.get_data(),editor._map_stream.get_data()])
func sweep(editor: NativeChunkEditor, label: String) -> void:
	var original := editor.data.heights == editor.data.original_heights
	editor._map_ready = false
	editor._update_surface_maps(original)
	var expected := capture(editor)
	for _frame in range(60): await process_frame
	for workers in [1,2,4,8]:
		for trial in range(3 if "--benchmark" in OS.get_cmdline_user_args() else 1):
			editor.surface_workers = workers
			editor._map_ready = false
			var gaps: Array[float] = []
			var clock := [Time.get_ticks_usec()]
			var observe := func() -> void:
				var now := Time.get_ticks_usec()
				gaps.append((now-clock[0])/1000.0)
				clock[0] = now
			process_frame.connect(observe)
			var began := Time.get_ticks_usec()
			await editor._update_surface_maps(original,self)
			process_frame.disconnect(observe)
			gaps.append((Time.get_ticks_usec()-clock[0])/1000.0)
			gaps.sort()
			check(capture(editor)==expected,label+": worker map pixels are byte-identical")
			check(editor.last_surface_profile.get("worker",false),"Surface partitions execute on workers")
			print("SURFACE_WORKERS ",label," ",JSON.stringify({"workers":workers,"trial":trial,"completion_ms":(Time.get_ticks_usec()-began)/1000.0,"submit_ms":editor.last_surface_profile.submit_usec/1000.0,"worker_cpu_ms":editor.last_surface_profile.worker_usec/1000.0,"frame_max_ms":gaps[-1],"frame_p95_ms":gaps[int(gaps.size()*0.95)],"frame_p99_ms":gaps[int(gaps.size()*0.99)]}))
func queued(editor: NativeChunkEditor, completed: Array) -> void:
	await editor._update_surface_maps(false,self)
	completed.append(true)
func run() -> void:
	create_timer(120).timeout.connect(func() -> void: quit(2))
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.set_process(false)
	await sweep(editor,"imported")
	editor.save_path = "res://docs/garden/fall-world-proof.json"
	check(editor.open_garden(),"Load populated native terrain with ponds and streams")
	check(not editor.content._stream_nodes.is_empty() and not editor.content.pond_vertices.is_empty(),"Native fixture contains both water overlays")
	await sweep(editor,"native-water")
	# A large local edit must merge only its footprint into the existing images.
	editor.data.brush(Vector2(-7,-7),5.0,0.8,"raise",0.0)
	await editor._update_surface_maps(false,self)
	check(editor.last_surface_profile.get("worker",false),"Incremental edit exercises worker stripes")
	var incremental := capture(editor)
	editor._map_ready = false
	editor._update_surface_maps(false)
	check(incremental==capture(editor),"Incremental worker stripes equal a full sequential repaint")
	# A newer synchronous edit must supersede a finite group already running.
	var completed: Array = []
	editor._map_ready = false
	queued(editor,completed)
	check(editor._map_busy,"Live map job occupies the owner's admission slot")
	for i in range(6): queued(editor,completed)
	editor.data.heights.fill(2.0)
	editor._map_ready = false
	editor._update_surface_maps(false)
	var latest := capture(editor)
	while completed.size()<7: await process_frame
	check(capture(editor)==latest,"Superseded jobs cannot overwrite newer surface textures")
	check(not editor._map_busy,"Superseded surface work joins and releases its slot")
	var published_heights := editor._map_heights.duplicate()
	editor._map_ready = false
	queued(editor,completed)
	editor.data.heights.fill(3.0)
	while completed.size()<8: await process_frame
	check(editor._map_heights==published_heights and capture(editor)==latest,"Direct terrain mutation rejects a stale map without accepting its cache metadata")
	editor._update_surface_maps(false)
	editor._map_ready = false
	queued(editor,completed)
	var owner: WeakRef = weakref(editor)
	scene.free()
	check(owner.get_ref()==null,"Pending map preparation cannot retain its scene owner")
	for _frame in range(15): await process_frame
	print("Threaded surface maps: ",failures," failures")
	quit(1 if failures else 0)
