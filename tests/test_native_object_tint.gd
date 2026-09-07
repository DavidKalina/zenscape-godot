extends SceneTree
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func _run() -> void:
	var scene=load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var editor=scene._chunk_editor
	editor.start_flat()
	editor.set_active(true)
	editor.mode="tree"
	scene._reset_camera()
	var picker: ColorPickerButton=editor.controls.find_child("PlacementColor",true,false)
	check(picker!=null,"Placement color is exposed in editor")
	var expected: Array[Color]=[]
	for i in range(2):
		var color:=Color("ba663d" if i==0 else "437e65")
		picker.color=color
		picker.color_changed.emit(color)
		expected.append(color.srgb_to_linear())
		var click:=InputEventMouseButton.new()
		click.button_index=MOUSE_BUTTON_LEFT
		click.pressed=true
		click.position=scene.camera.unproject_position(Vector3(-3.0+6.0*i,0,0))
		editor.handle_input(click)
		click.pressed=false
		editor.handle_input(click)
	var crowns: MultiMesh=editor.content.get_node("Canopy").multimesh
	var trunks: MultiMesh=editor.content.get_node("Trunk").multimesh
	for i in range(2):
		check(crowns.get_instance_color(i)==expected[i],"Each tree retains its independently chosen color")
		check(trunks.get_instance_color(i)==Color.WHITE,"Foliage recoloring leaves trunk tint intact")
	var saved=editor.data.to_document()
	check(editor.data.load_document(JSON.parse_string(JSON.stringify(saved,"",true,true))),"Colored assets reopen")
	editor.refresh()
	for i in range(2):
		check(editor.content.get_node("Canopy").multimesh.get_instance_color(i)==expected[i],"Reopened rendered colors are exact")
	var before=editor.data.to_document()
	var bad=before.duplicate(true)
	bad.objects[0].tint="g".repeat(24)
	check(not editor.data.load_document(bad) and editor.data.to_document()==before,"Malformed color rejects atomically")
	editor.data.begin_stroke()
	editor.data.erase_objects(Vector2(-3,0),1.0)
	editor.data.end_stroke()
	editor.undo()
	check(editor.content.get_node("Canopy").multimesh.get_instance_color(0)==expected[0],"Undo restores exact color")
	scene.queue_free()
	await process_frame
	print("Native object tint: ",failures," failures")
	quit(1 if failures else 0)
