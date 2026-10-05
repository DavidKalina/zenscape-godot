extends SceneTree
const Plate = preload("res://scripts/plate.gd")
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
	editor.select_tool("ground")
	var button: Button = scene._build_palette.action_for("FormGroundFoundation")
	check(button != null and button.text == "Form ground foundation","Foundation is available through the palette")
	button.pressed.emit()
	while editor.forming: await process_frame
	var heights: PackedFloat32Array = editor.data.heights.duplicate()
	check(editor.data.blank and editor.data.objects.is_empty(),"Foundation does not reveal imported scenery")
	var near_edge: Array[float] = []
	for i in range(editor.data.points.size()):
		var point: Vector2 = editor.data.points[i]
		var edge := maxf(absf(point.x),absf(point.y))
		if edge > Plate.RIM:
			check(is_equal_approx(heights[i],0.6),"Sealed rim retains fidelity soil datum")
		elif edge > Plate.HALF-1.5 and edge < Plate.HALF-0.5:
			near_edge.append(heights[i])
	near_edge.sort()
	check(near_edge[near_edge.size()/2] > 2.0,"Green thickness is actual raised ground above the rim")
	check(editor._skirt.mesh.get_surface_count() == 1,"No artificial extra turf band")
	check(editor._skirt.mesh.get_aabb().is_equal_approx(editor._skirt_mesh.get_aabb()),"Foundation preserves original soil thickness")
	editor.grass_amount = 1.0
	editor.cover_grass()
	var colors: PackedColorArray = editor.terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	for i in range(0,colors.size(),3):
		check(colors[i] == colors[i+1] and colors[i] == colors[i+2],"Ground retains crisp per-face colors")
	var vertices: PackedVector3Array = editor.terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in range(vertices.size()):
		if maxf(absf(vertices[i].x),absf(vertices[i].z)) > Plate.RIM:
			check(colors[i].g > colors[i].r,"Painted cut rim remains green, not misclassified cliff rock")
	check(editor.data.blades.count(0.0) == editor.data.blades.size(),"Ground adds no blades")
	var saved = editor.data.to_document()
	check(editor.data.load_document(JSON.parse_string(JSON.stringify(saved,"",true,true))),"Foundation roundtrips through saved garden")
	check(editor.data.heights == heights,"Reopened foundation heights are exact")
	# load_document resets history; verify an independently formed undoable edit.
	editor.ground_elevation = 1.0
	editor.ground_relief = 0.5
	editor.form_foundation()
	check(editor.data.heights != heights,"Foundation controls change real terrain")
	editor.undo()
	check(editor.data.heights == heights,"Undo restores exact foundation")
	scene.queue_free()
	await process_frame
	print("Native turf foundation: ",failures," failures")
	quit(1 if failures else 0)
