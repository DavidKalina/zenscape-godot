extends SceneTree
## Each placed tree keeps its own canopy colour through save, reopen and undo.
## suite: gpu
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
## A tree draws as its spruce variant's trunk and canopies (a2eec160).
func rendered_color(editor: NativeChunkEditor,id: int,suffix: String) -> Color:
	for batch: MultiMeshInstance3D in editor.content._batches:
		var part: String=batch.get_meta("part")
		if not (part.begins_with("tree:") and part.ends_with(suffix)): continue
		var sources: Array=editor.content._sources[part]
		for index in range(sources.size()):
			if sources[index].item is Dictionary and sources[index].item.id==id:
				return batch.multimesh.get_instance_color(index)
	check(false,"Tree %d has a rendered%s instance" % [id,suffix])
	return Color.TRANSPARENT
func _run() -> void:
	root.size=Vector2i(1440,960)
	var scene=load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var editor=scene._chunk_editor
	editor.reactions_enabled = false
	editor.start_flat()
	editor.set_active(true)
	editor.select_tool("tree")
	scene._reset_camera()
	var picker: ColorPickerButton=scene._build_palette.find_child("PlacementColor",true,false)
	check(picker!=null,"Placement color is exposed on the palette")
	var expected: Array[Color]=[]
	for i in range(2):
		var color:=Color("ba663d" if i==0 else "437e65")
		picker.color=color
		picker.color_changed.emit(color)
		expected.append(color.srgb_to_linear())
		## The left press is the hand's under modeless controls (7a1d6669);
		## place_at is the press's own placement path.
		check(editor.place_at(scene.camera.unproject_position(Vector3(-3.0+6.0*i,0,0))),"Tree %d is placed" % i)
		editor.finish_stroke()
	var ids: Array=editor.data.objects.map(func(item: Dictionary) -> int: return item.id)
	if ids.size()!=2:
		check(false,"Two trees are placed")
		quit(1)
		return
	for i in range(ids.size()):
		check(rendered_color(editor,ids[i],"-canopies")==expected[i],"Each tree retains its independently chosen color")
		check(rendered_color(editor,ids[i],"-trunk")==Color.WHITE,"Foliage recoloring leaves trunk tint intact")
	var saved=editor.data.to_document()
	check(editor.data.load_document(JSON.parse_string(JSON.stringify(saved,"",true,true))),"Colored assets reopen")
	editor.refresh()
	for i in range(ids.size()):
		check(rendered_color(editor,ids[i],"-canopies")==expected[i],"Reopened rendered colors are exact")
	var before=editor.data.to_document()
	var bad=before.duplicate(true)
	bad.objects[0].tint="g".repeat(24)
	check(not editor.data.load_document(bad) and editor.data.to_document()==before,"Malformed color rejects atomically")
	editor.data.begin_stroke()
	editor.data.erase_objects(Vector2(-3,0),1.0)
	editor.data.end_stroke()
	editor.undo()
	check(rendered_color(editor,ids[0],"-canopies")==expected[0],"Undo restores exact color")
	scene.queue_free()
	await process_frame
	print("Native object tint: ",failures," failures")
	quit(1 if failures else 0)
