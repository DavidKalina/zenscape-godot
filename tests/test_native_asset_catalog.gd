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
	editor.mode="assets"
	editor.object_scale=0.8
	editor.object_angle=PI/3.0
	scene._reset_camera()
	var picker: OptionButton = editor._tools.get_node("AssetPicker")
	check(picker.item_count == 17,"Picker exposes all seventeen added source assets")
	for i in range(picker.item_count):
		picker.select(i)
		picker.item_selected.emit(i)
		var point := Vector3(-7.0+(i%4)*4.0,0,-7.0+(i/4)*4.0)
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=true
		event.position=scene.camera.unproject_position(point)
		editor.handle_input(event)
		event.pressed=false
		editor.handle_input(event)
		check(editor.data.objects.size()==i+1,"Picker asset places through actual camera ray")
		check(editor.data.objects.back().asset==picker.get_item_metadata(i),"Picked asset is stored by kind")
	var source=load("res://assets/zen_reference/geometry.scn").instantiate()
	for kind in preload("res://scripts/native_asset_catalog.gd").PARTS:
		for node_name in preload("res://scripts/native_asset_catalog.gd").PARTS[kind]:
			var key: String=kind+":"+node_name
			var matched := false
			for batch in editor.content._batches:
				if batch.multimesh.mesh==(source.get_node(node_name).multimesh.mesh if source.get_node(node_name) is MultiMeshInstance3D else source.get_node(node_name).mesh) and batch.material_override==editor.content._materials[key]:
					matched=true
					check(batch.multimesh.instance_count==1,"Every compound part appears once")
					if kind.begins_with("boulder"):
						var transform: Transform3D = batch.multimesh.get_instance_transform(0)
						var low := INF
						for vertex in batch.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
							low=minf(low,(transform*vertex).y)
						check(absf(low)<0.0001,"Visible source boulder base rests on the authored ground")
					check(batch.multimesh.get_instance_color(0)==editor.content._tints[key],"Source part tint is retained")
			check(matched,"Catalog uses original geometry and native material")
	var saved=editor.data.to_document()
	check(editor.data.load_document(JSON.parse_string(JSON.stringify(saved,"",true,true))),"Catalog placements reopen")
	editor.refresh()
	check(editor.data.objects.size()==17,"All asset kinds survive reopening")
	editor.data.begin_stroke()
	editor.data.erase_objects(Vector2(editor.data.objects[0].x,editor.data.objects[0].z),0.5)
	editor.data.end_stroke()
	editor.refresh()
	check(editor.data.objects.size()==16,"Catalog objects can be erased")
	editor.undo()
	check(editor.data.objects.size()==17,"Erase undo restores catalog object")
	source.free()
	scene.queue_free()
	await process_frame
	print("Native asset catalog: ",failures," failures")
	quit(1 if failures else 0)
