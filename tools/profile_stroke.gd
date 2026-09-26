extends SceneTree
## Headless CPU timing of one held brush stroke in the cozy product scene.
## Replays the editor's 30 Hz paint loop (sub-dabs along the pointer path, then
## one refresh), releases through finish_stroke and waits for the world to
## settle. Frame gaps are main-loop intervals under the dummy renderer: they
## include scripts, physics and navigation, never GPU work or presentation.
##   -- --mode=raise|lower|smooth|meadow|grass|paint --dabs=30
##      --from=-4,-2.5 --to=3,2 --then=undo|restroke --label=name
## Dab amounts are fixed per tick, so the settled world is deterministic and the
## printed fingerprint can be compared between builds. The dummy renderer keeps
## no MultiMesh transforms, so the instance hash covers batch sources only.
var scene: Node3D
var editor: NativeChunkEditor
var mode := "raise"
var dab_count := 30
var label := "stroke"
var from_point := Vector2(-4.0,-2.5)
var to_point := Vector2(3.0,2.0)
var then := ""
var _tick_end := 0
var after_tick: Array[float] = []

func _initialize() -> void: run.call_deferred()

func stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	var sorted := values.duplicate()
	sorted.sort()
	var over := 0
	for value in values:
		if value > 16.667: over += 1
	return {"n":sorted.size(),"median":snappedf(sorted[sorted.size()/2],0.01),"p95":snappedf(sorted[mini(sorted.size()-1,int(sorted.size()*0.95))],0.01),"max":snappedf(sorted.back(),0.01),"over_16_67":over}

## Index and duration of every sample over 12 ms.
func slow(values: Array[float]) -> Array:
	var found := []
	for i in range(values.size()):
		if values[i] > 12.0: found.append([i,snappedf(values[i],0.1)])
	return found

## Called by a probe node that processes after every other node: the time from
## the end of a dab to here is the rest of that frame's node processing.
func _last_node() -> void:
	if _tick_end > 0: after_tick.append((Time.get_ticks_usec()-_tick_end)/1000.0)
	_tick_end = 0

func _hash(value: Variant) -> String:
	return var_to_bytes(value).hex_encode().sha256_text().left(12)

func fingerprint() -> Dictionary:
	var data := editor.data
	var sources := []
	for batch in editor.content._batches:
		var key: String = batch.get_meta("part")
		sources.append([key,batch.multimesh.instance_count])
		for source: Dictionary in editor.content._sources.get(key,[]):
			sources.append([source.x,source.z,source.item.id if source.item != null else -1,editor.content._instance_transform(source)])
	var arrays: Array = data._mesh_arrays
	var water := [editor.content.pond_vertices]
	for node in editor.content._stream_nodes: water.append(node.mesh.get_faces())
	return {
		"heights":_hash(data.heights),
		"cover":_hash([data.grass,data.blades,data.meadow,data.tint]),
		"mesh":_hash([arrays[Mesh.ARRAY_VERTEX],arrays[Mesh.ARRAY_NORMAL],arrays[Mesh.ARRAY_COLOR],arrays[Mesh.ARRAY_TEX_UV2]]) if not arrays.is_empty() else "",
		"mesh_published":editor.terrain.mesh == data.play_mesh(data._mesh_result) if data._mesh_result != null else false,
		"instances":_hash(sources),
		"water":_hash(water),
		"content_revision":editor.content.revision,
		"ground_map":_hash(editor._map_ground.get_data()) if editor._map_ground != null else "",
		"stream_map":_hash(editor._map_stream.get_data()) if editor._map_stream != null else "",
		"skirt":_hash(editor._skirt.mesh.get_faces()),
		"undo":data._undo.size(),
		"play_signature":_hash(editor._play_geometry_signature),
		"summit":str(scene._atmosphere._summit),
	}

func _point(text: String) -> Vector2:
	var parts := text.split(",")
	return Vector2(float(parts[0]),float(parts[1]))

## One held stroke from `a` to `b`: a dab tick whenever 1/30 s has passed.
func stroke(a: Vector2, b: Vector2, count: int, frames: Array[float], ticks: Array[float]) -> void:
	var elapsed := 0.0
	var dabs := 0
	var last_point: Variant = null
	editor._level = 0.0
	editor.data.begin_stroke()
	editor._painting = true
	var previous := Time.get_ticks_usec()
	while dabs < count:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now-previous)/1000.0)
		elapsed += minf((now-previous)/1000000.0,0.05)
		previous = now
		if elapsed < 1.0/30.0 and dabs > 0: continue
		var center := a.lerp(b,float(dabs)/(count-1))
		var from: Vector2 = last_point if last_point != null else center
		var tick := Time.get_ticks_usec()
		var steps := maxi(1,ceili(from.distance_to(center)/(editor.radius*0.15)))
		for i in range(1,steps+1):
			editor.dab(from.lerp(center,float(i)/steps),editor.strength/30.0/steps)
		editor.refresh()
		_tick_end = Time.get_ticks_usec()
		ticks.append((_tick_end-tick)/1000.0)
		elapsed = 0.0
		last_point = center
		dabs += 1

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		if arg.begins_with("--dabs="): dab_count = maxi(2,int(arg.trim_prefix("--dabs=")))
		if arg.begins_with("--label="): label = arg.trim_prefix("--label=")
		if arg.begins_with("--from="): from_point = _point(arg.trim_prefix("--from="))
		if arg.begins_with("--to="): to_point = _point(arg.trim_prefix("--to="))
		if arg.begins_with("--then="): then = arg.trim_prefix("--then=")
	create_timer(150).timeout.connect(func() -> void: push_error("Stroke profile timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-stroke-profile-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready: await process_frame
	scene.set_building(true)
	editor = scene._chunk_editor
	# The loop below stands in for the pointer; the editor's own would end the
	# stroke at once, because no mouse button is held in a headless run.
	editor.set_process(false)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	editor.select_tool(mode)
	editor.radius = 2.2
	editor.strength = 2.0
	var probe := Node.new()
	probe.process_priority = 1000000
	var script := GDScript.new()
	script.source_code = "extends Node\nvar owner_tree: SceneTree\nfunc _process(_delta: float) -> void: owner_tree._last_node()\n"
	script.reload()
	probe.set_script(script)
	probe.owner_tree = self
	root.add_child(probe)
	await create_timer(2.0).timeout
	var idle: Array[float] = []
	var previous := Time.get_ticks_usec()
	for _frame in range(60):
		await process_frame
		var now := Time.get_ticks_usec()
		idle.append((now-previous)/1000.0)
		previous = now
	var frames: Array[float] = []
	var ticks: Array[float] = []
	var began := Time.get_ticks_usec()
	await stroke(from_point,to_point,dab_count,frames,ticks)
	var release := Time.get_ticks_usec()
	editor.finish_stroke()
	var release_ms := (Time.get_ticks_usec()-release)/1000.0
	# Optional follow-ups exercise the settle being superseded: an undo on the
	# next frame, or a second, shorter stroke back along the path.
	if then == "undo":
		await process_frame
		editor.undo()
	elif then == "restroke":
		for _frame in range(3): await process_frame
		await stroke(to_point,from_point.lerp(to_point,0.5),10,frames,ticks)
		editor.finish_stroke()
	var settle: Array[float] = []
	var settle_stages := []
	var settle_frames := 0
	previous = Time.get_ticks_usec()
	while settle_frames < 90 or editor.refresh_pending > 0:
		var stage := editor.refresh_stage
		await process_frame
		var now := Time.get_ticks_usec()
		settle.append((now-previous)/1000.0)
		if settle.back() > 12.0: settle_stages.append([settle.size()-1,stage])
		previous = now
		settle_frames += 1
	var report := {"label":label,"mode":mode,"then":then,"dabs":ticks.size(),"stroke_ms":snappedf((release-began)/1000.0,0.1),"idle_frames":stats(idle),"stroke_frames":stats(frames),"dab_ticks":stats(ticks),"after_dab":stats(after_tick),"release_ms":snappedf(release_ms,0.01),"settle_frames":stats(settle),"slow_stroke_frames":slow(frames),"slow_settle_frames":slow(settle),"slow_settle_stages":settle_stages,"water_usec":editor.content.last_water_usec}
	print("STROKE ",JSON.stringify(report))
	print("FINGERPRINT ",JSON.stringify(fingerprint()))
	scene.queue_free()
	for _frame in range(3): await process_frame
	quit()
