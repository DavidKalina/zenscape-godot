extends SceneTree
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var editor = scene._chunk_editor
	editor.start_flat()
	editor.select_tool("range")
	var button: Button = scene._build_palette.action_for("FormMountainLandscape")
	check(button != null and button.text == "Form mountain landscape","Range generation is exposed through the palette")
	button.pressed.emit()
	while editor.forming: await process_frame
	var generated: PackedFloat32Array = editor.data.heights.duplicate()
	# The imported fidelity terrain is the authored 28 m mesh, no longer the
	# plate: the range's equations are read at its points, its rim held at
	# 0.6 as that plate's rim was.
	var source: Node3D = load("res://assets/zen_reference/geometry.scn").instantiate()
	var imported := NativeTerrainData.new()
	imported.setup(source.get_node("terrain").mesh,[],false)
	source.free()
	var equations: PackedFloat32Array = preload("res://scripts/native_recipe_samples.gd").build(editor.data._recipe_settings,imported.points,PackedFloat64Array(),PackedFloat64Array(),false).heights
	var worst := 0.0
	for i in range(equations.size()):
		var rim := maxf(absf(imported.points[i].x),absf(imported.points[i].y)) > preload("res://scripts/plate.gd").LEGACY_HALF-0.0001
		worst = maxf(worst,absf((0.6 if rim else equations[i])-imported.original_heights[i]))
	print("Generated range vs imported fidelity vertices: max error ",worst)
	check(worst < 0.0001,"Default range reconstructs fidelity terrain from equations")
	check(editor.data.blank and editor.data.objects.is_empty(),"Generation leaves source scenery hidden and placements empty")
	for node in editor._source_visibility:
		check(not node.visible,"Imported content remains hidden")
	editor.undo()
	check(editor.data.heights.count(0.0) == generated.size(),"Range generation undoes to blank")
	editor.redo()
	check(editor.data.heights == generated,"Range redo restores exact heights")
	var document = editor.data.to_document()
	check(editor.data.load_document(JSON.parse_string(JSON.stringify(document,"",true,true))),"Range document reopens")
	check(editor.data.heights == generated,"Reopened range is exact")
	for settings: Array in [[0.7,1.0,0.0,0],[1.0,0.7,0.0,0],[1.0,1.0,45.0,0],[1.0,1.0,0.0,10]]:
		editor.range_height=settings[0]
		editor.range_width=settings[1]
		editor.range_heading=settings[2]
		editor.range_variation=settings[3]
		editor.form_range()
		check(editor.data.heights != generated,"Each range control changes generated geometry")
		editor.undo()
		check(editor.data.heights == generated,"Undo returns from varied range to fidelity")
	scene.queue_free()
	await process_frame
	print("Native range: ",failures," failures")
	quit(1 if failures else 0)
