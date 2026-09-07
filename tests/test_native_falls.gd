extends SceneTree
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func click(editor: NativeChunkEditor, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = editor.scene.camera.unproject_position(Vector3(point.x,editor.data.ground_height(point),point.y))
	editor.handle_input(event)
	event.pressed = false
	editor.handle_input(event)
func _run() -> void:
	var scene: Node3D = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene._ui.visible = false
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.set_active(true)
	editor.start_flat()
	var data := editor.data
	data.begin_stroke()
	data.mountain(Vector2(-5,0),7.0,10.0)
	data.brush(Vector2(3,0),3.0,1.0,"lower",0.0)
	data.end_stroke()
	check(data.add_pond(Vector2(3,0),-0.2),"Create receiving pond")
	editor.refresh()
	scene._reset_camera()
	editor.mode = "waterfall"
	click(editor,Vector2(-4,0))
	check(editor._fall_start != null and data.objects.is_empty(),"First click only selects the lip")
	click(editor,Vector2(3,0))
	check(data.objects.size() == 1 and editor.falls.get_child_count() == 2,"Second click creates flowing waterfall")
	if data.objects.is_empty():
		quit(1)
		return
	var ends := NativeGardenFalls.endpoints(data,data.objects[0])
	check(is_equal_approx(ends[1].y,-0.2),"Fall meets receiving pond surface")
	var node: MeshInstance3D = editor.falls.get_child(0)
	check(node.material_override.shader.resource_path.ends_with("reference_fall.gdshader"),"Authored fall uses native animated shader")
	check(node.mesh.get_aabb().size.y > 5.0,"Fall geometry spans the full drop for culling and framing")
	var course := NativeGardenFalls.build_course(data,data.objects[0])
	check(course.size() == NativeGardenFalls.RINGS,"Terrain route supplies all shader stations")
	for i in range(1,course.size()):
		check(course[i].y <= course[i-1].y+0.002,"Water stations never climb uphill")
	for point in course:
		var ground: float = data.ground_height(Vector2(point.x,point.z))
		check(absf(point.y-maxf(ground+0.08,ends[1].y)) < 0.06,"Water follows geology instead of flying above the slope")
	var probe := NativeTerrainData.new()
	probe.setup(data.source_mesh)
	probe.reset_flat()
	for i in range(probe.points.size()):
		var point := probe.points[i]
		probe.heights[i] = 1.5-0.2*point.x-2.0*exp(-point.length_squared()/4.0)
	var dry_start := Vector3(-6,probe.ground_height(Vector2(-6,0))+0.12,0)
	var dry_end := Vector3(6,probe.ground_height(Vector2(6,0))+0.06,0)
	check(NativeWaterCourse.trace(probe,dry_start,dry_end,32).is_empty(),"Dry landing does not flood an intervening depression with imaginary water")
	probe.reset_flat()
	check(NativeWaterCourse.half_width(probe,Vector3(0,1,0),Vector3.RIGHT,0.2) == 0.0,"Unsupported first width sample does not fabricate a minimum width")
	probe.mountain(Vector2.ZERO,2.0,4.0)
	var crossing := PackedVector3Array([Vector3(-4,0.08,0),Vector3(4,0.08,0)])
	check(NativeWaterCourse._resample(probe,crossing,2,-1000,PackedVector3Array()).is_empty(),"Rendered segment cannot cut through a ridge between stations")
	var expected := data.to_document()
	editor.undo()
	check(data.objects.is_empty() and editor.falls.get_child_count() == 0,"One undo removes complete two-click waterfall")
	editor.redo()
	check(data.to_document() == expected and editor.falls.get_child_count() == 2,"Redo reconstructs waterfall")
	check(not data.add_waterfall(Vector2(3,0),Vector2(-4,0),1.0),"Uphill waterfall is rejected")
	var blocked_x := (float(data.objects[0].x)+float(data.objects[0].end_x))*0.5
	data.begin_stroke()
	for i in range(data.points.size()):
		if absf(data.points[i].x-blocked_x) < 0.55:
			data.heights[i] = 24.0
	data.end_stroke()
	editor.refresh()
	check(editor.falls.get_child_count() == 0,"Intervening ridge suspends obstructed fall")
	check(not data.add_waterfall(Vector2(-4,0),Vector2(3,0),1.0),"New falls reject intervening ridge")
	editor.undo()
	check(editor.falls.get_child_count() == 2,"Undoing obstruction restores fall and spray")
	editor.falls._process(0.0)
	check(editor.falls._sprays[0].material.get_shader_parameter("camera_origin") == scene.camera.global_position,"Spray tracks camera in either fog mode")
	var malformed := expected.duplicate(true)
	malformed.objects[0].end_x = 100
	check(not data.load_document(malformed) and data.to_document() == expected,"Invalid endpoint rejects atomically")
	var save_file := "/tmp/native-falls-%d.json" % OS.get_process_id()
	editor.save_path = save_file
	check(editor.save_garden(),"Save authored waterfall")
	scene._celestial.set_phase(0.4)
	scene._reset_camera()
	for i in range(3):
		await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/native-falls.png")
	scene.set_process(false)
	editor.set_process(false)
	editor.falls.set_process(false)
	for spray in editor.falls._sprays:
		spray.visible = false
	RenderingServer.global_shader_parameter_set("zs_flow_time",1.0)
	await process_frame
	RenderingServer.force_draw(false)
	var first := root.get_texture().get_image().get_data()
	RenderingServer.global_shader_parameter_set("zs_flow_time",2.0)
	await process_frame
	RenderingServer.force_draw(false)
	check(root.get_texture().get_image().get_data() != first,"Waterfall visibly changes as flow time advances with scene and spray paused")
	scene.queue_free()
	await process_frame
	var reopened: Node3D = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(reopened)
	reopened._chunk_editor.save_path = save_file
	check(reopened._chunk_editor.open_garden(),"Fresh scene opens saved waterfall")
	check(reopened._chunk_editor.data.to_document() == expected and reopened._chunk_editor.falls.get_child_count() == 2,"Fresh scene reproduces endpoints and flowing geometry")
	reopened.queue_free()
	await process_frame
	DirAccess.remove_absolute(save_file)
	print("Native falls: ",failures," failures")
	quit(1 if failures else 0)
