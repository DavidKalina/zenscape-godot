extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene=load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var editor=scene._chunk_editor
	editor.start_flat()
	editor.select_tool("range")
	editor.form_range()
	scene._build_palette.action_for("FillLandscapeWaterfall").pressed.emit()
	var placed: bool=editor.data.landscape_waterfall and editor.content._landscape_falls.size()==1
	var mesh_arrays: Array=editor.content._landscape_falls[0].mesh.surface_get_arrays(0)
	var baseline: Dictionary=editor.data.to_document()
	var saved=JSON.parse_string(JSON.stringify(baseline,"",true,true))
	editor.data.undo()
	editor.refresh()
	var undone: bool=not editor.data.landscape_waterfall and editor.content._landscape_falls.is_empty()
	editor.data.redo()
	editor.refresh()
	var restored: bool=editor.content._landscape_falls[0].mesh.surface_get_arrays(0)==mesh_arrays
	var reopened: bool=editor.data.load_document(saved)
	editor.refresh()
	reopened=reopened and editor.data.to_document()==baseline and editor.content._landscape_falls[0].mesh.surface_get_arrays(0)==mesh_arrays
	var bad: Dictionary=saved.duplicate(true)
	bad.landscape_waterfall="yes"
	var rejected: bool=not editor.data.load_document(bad) and editor.data.to_document()==baseline
	var legacy: Dictionary=saved.duplicate(true)
	legacy.version=7
	legacy.erase("landscape_waterfall")
	var migrated: bool=editor.data.load_document(legacy) and not editor.data.landscape_waterfall
	print("Waterfall button ",placed,"; undo ",undone,"; redo ",restored,"; reopen ",reopened,"; invalid atomic reject ",rejected,"; v7 migration ",migrated)
	var ok: bool=placed and undone and restored and reopened and rejected and migrated
	scene.queue_free()
	await process_frame
	quit(0 if ok else 1)
