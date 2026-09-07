extends SceneTree
## The populated landscape versus the exported seed-7 scene: every scatter
## layer's instance matrices and colors, through the real editor button, then
## undo/redo/reopen and atomic rejection of a malformed landscape flag.
var failures := 0
func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var editor = scene._chunk_editor
	editor.content.set_process(false)
	editor.start_flat()
	editor.form_range()
	var pool: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/terrain-source.json")).pool
	check(editor.data.add_pond(Vector2(pool.x,pool.z),pool.waterY),"Landscape pond places at the source pool")
	editor.refresh()
	editor._tools.find_child("FillLandscapeStreams",true,false).pressed.emit()
	var started := Time.get_ticks_msec()
	editor._tools.find_child("PopulateLandscapeFlora",true,false).pressed.emit()
	var elapsed := Time.get_ticks_msec()-started
	var records: int = editor.data.objects.size()
	check(records > 0,"Populate button creates landscape records")
	var expected := {}
	for mesh in JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/scene.json")).meshes:
		expected[mesh.name] = mesh
	var stem_offsets := {}
	var offset := 0
	for form in ["button","spike","umbel","daisy"]:
		stem_offsets[form] = offset
		offset += int(expected["flowers-"+form].count)
	var rendered := _rendered(editor.content)
	var worst_transform := 0.0
	var worst_color := 0.0
	var summary := ""
	var counted := 0
	for key in rendered:
		var node: String = key.split(":")[1] if ":" in key else {"trunk":"mesh-8","canopy":"mesh-9"}.get(key,"")
		if node == "": continue
		var source: Dictionary = expected[node]
		var items: Array = rendered[key]
		var first := 0
		var want := int(source.count)
		if node == "flower-stems":
			var form: String = key.split(":")[0].replace("_flower","")
			first = stem_offsets[form]
			want = int(expected["flowers-"+form].count)
		if want == 0: want = 1
		check(items.size() == want,"%s renders %d instances (got %d)" % [key,want,items.size()])
		var transform_error := 0.0
		var color_error := 0.0
		for i in range(mini(items.size(),want)):
			var values: Array = source.instances.slice((first+i)*16,(first+i+1)*16) if source.instances != null else source.matrix
			var t: Transform3D = items[i][0]
			for pair in [[t.basis.x,0],[t.basis.y,4],[t.basis.z,8],[t.origin,12]]:
				var v: Vector3 = pair[0]
				var at: int = pair[1]
				transform_error = maxf(transform_error,maxf(absf(v.x-values[at]),maxf(absf(v.y-values[at+1]),absf(v.z-values[at+2]))))
			var c: Color = items[i][1]
			var wanted := Color.WHITE
			if source.instanceColors != null:
				wanted = Color(source.instanceColors[(first+i)*3],source.instanceColors[(first+i)*3+1],source.instanceColors[(first+i)*3+2])
			color_error = maxf(color_error,maxf(absf(c.r-wanted.r),maxf(absf(c.g-wanted.g),absf(c.b-wanted.b))))
		counted += items.size()
		worst_transform = maxf(worst_transform,transform_error)
		worst_color = maxf(worst_color,color_error)
		summary += "\n  %s: %d/%d transform %s color %s" % [key,items.size(),want,String.num_scientific(transform_error),String.num_scientific(color_error)]
	check(worst_transform < 0.000001,"Instance transforms match the exported scene")
	check(worst_color < 0.000001,"Instance colors match the exported scene")
	# Lifecycle: undo removes every generated record, redo and reopen restore them exactly.
	var baseline: Dictionary = editor.data.to_document()
	var saved = JSON.parse_string(JSON.stringify(baseline,"",true,true))
	editor.data.undo()
	editor.refresh()
	check(editor.data.objects.is_empty() and editor.content._batches.is_empty(),"Undo removes the populated landscape")
	editor.data.redo()
	editor.refresh()
	check(_same(_rendered(editor.content),rendered),"Redo restores identical instances")
	check(editor.data.load_document(saved),"Saved landscape reopens")
	editor.refresh()
	check(editor.data.to_document() == baseline and _same(_rendered(editor.content),rendered),"Reopened landscape matches saved records and rendering")
	editor._tools.find_child("PopulateLandscapeFlora",true,false).pressed.emit()
	check(editor.data.objects.size() == records,"Repopulating replaces landscape records rather than duplicating them")
	var bad: Dictionary = saved.duplicate(true)
	bad.objects[0].landscape = "yes"
	check(not editor.data.load_document(bad) and editor.data.to_document().objects.size() == records,"Malformed landscape flag rejects atomically")
	print("Flora records ",records,"; instances ",counted,"; elapsed ",elapsed," ms; worst transform ",worst_transform,"; worst color ",worst_color,summary)
	print("Failures: ",failures)
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
func _rendered(content: Node) -> Dictionary:
	var result := {}
	for batch in content._batches:
		var key: String = batch.get_meta("part")
		var items: Array = []
		for i in range(batch.multimesh.instance_count):
			items.append([batch.multimesh.get_instance_transform(i),batch.multimesh.get_instance_color(i)])
		result[key] = items
	return result
func _same(a: Dictionary, b: Dictionary) -> bool:
	if a.keys() != b.keys(): return false
	for key in a:
		if a[key].size() != b[key].size(): return false
		for i in range(a[key].size()):
			if a[key][i][0] != b[key][i][0] or a[key][i][1] != b[key][i][1]: return false
	return true
