extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var scene=load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var editor=scene._chunk_editor
	editor.start_flat()
	editor.form_range()
	var button: Button=editor._tools.find_child("FillLandscapeStreams",true,false)
	button.pressed.emit()
	var placed: bool=editor.data.streams.size()==1 and editor.content._stream_nodes.size()==1
	var original: Array=editor.content._stream_nodes[0].mesh.surface_get_arrays(0)
	var baseline: Dictionary=editor.data.to_document()
	var saved=JSON.parse_string(JSON.stringify(baseline,"",true,true))
	editor.data.undo()
	editor.refresh()
	var undone: bool=editor.data.streams.is_empty() and editor.content._stream_nodes.is_empty()
	editor.data.redo()
	editor.refresh()
	var redone: bool=editor.content._stream_nodes[0].mesh.surface_get_arrays(0)==original
	var opened: bool=editor.data.load_document(saved)
	editor.refresh()
	opened=opened and editor.content._stream_nodes[0].mesh.surface_get_arrays(0)==original and editor.data.to_document()==baseline
	var invalid: Dictionary=saved.duplicate(true)
	invalid.streams[0].pts[1].h="000000000000f87f"
	var rejected: bool=not editor.data.load_document(invalid) and editor.data.to_document()==baseline
	var legacy: Dictionary=saved.duplicate(true)
	legacy.version=6
	legacy.erase("streams")
	var migrated: bool=editor.data.load_document(legacy) and editor.data.streams.is_empty()
	print("Stream button ",placed,"; undo ",undone,"; redo ",redone,"; exact JSON reopen ",opened,"; invalid atomic reject ",rejected,"; v6 migration ",migrated)
	var ok: bool=placed and undone and redone and opened and rejected and migrated
	scene.queue_free()
	await process_frame
	quit(0 if ok else 1)
