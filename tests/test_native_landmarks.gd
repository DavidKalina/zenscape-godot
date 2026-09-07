extends SceneTree
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var scene: Node3D = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.set_active(true)
	editor.start_flat()
	scene._ui.visible = false
	scene._celestial.set_phase(0.4)
	scene._reset_camera()
	editor.data.begin_stroke()
	editor.data.mountain(Vector2(-5,0),7.0,9.0)
	editor.data.end_stroke()
	editor.refresh()
	for entry: Array in [["arch",Vector2(1,2)],["bigfoot_tree",Vector2(6,-4)]]:
		editor.mode = entry[0]
		editor.object_scale = 0.8
		for row: Control in editor._tool_settings:
			if row is HBoxContainer and row.get_child(0).text == "Rotation °":
				row.get_child(1).value = 60.0
		var point: Vector2 = entry[1]
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = scene.camera.unproject_position(Vector3(point.x,editor.data.ground_height(point),point.y))
		editor.handle_input(click)
		click.pressed = false
		editor.handle_input(click)
	check(editor.data.objects.size() == 2,"Both landmark tools place through actual camera rays")
	check(editor.landmarks.get_child_count() == 2,"Both source landmarks render")
	check(scene._bigfoot.authored_tree,"Placed Bigfoot tree anchors the encounter")
	check(scene._bigfoot._frame.position.is_equal_approx(editor.data.object_position(editor.data.objects[1])),"Encounter frame follows authored tree location")
	scene._summon_bigfoot()
	check(scene._bigfoot.active and scene._bigfoot.rig.visible,"Authored tree supports Bigfoot preview")
	var arch: Node3D = editor.landmarks.get_child(0)
	var geometry: MeshInstance3D = arch.get_child(0)
	check(geometry.mesh.get_aabb().size.y > 2.0,"Arch geometry retains its full height")
	check(is_equal_approx(arch.rotation.y,PI/3.0) and arch.scale.is_equal_approx(Vector3.ONE*0.8),"Rotation and size apply to landmarks")
	check(is_equal_approx(editor.object_angle,PI/3.0),"Rotation control converts degrees to saved radians")
	var base := geometry.to_global(Vector3(geometry.mesh.get_aabb().get_center().x,geometry.mesh.get_aabb().position.y,geometry.mesh.get_aabb().get_center().z))
	check(absf(base.y-editor.data.ground_height(Vector2(arch.position.x,arch.position.z))) < 0.001,"Visible arch base is grounded at placement center")
	var saved := editor.data.to_document()
	check(editor.data.load_document(JSON.parse_string(JSON.stringify(saved,"",true,true))),"Landmark records survive JSON")
	check(editor.data.to_document() == saved,"Landmark positions and transforms roundtrip exactly")
	var tree_id: int = editor.data.objects[1].id
	var point := Vector2(editor.data.objects[1].x,editor.data.objects[1].z)
	editor.data.begin_stroke()
	editor.data.brush(point,3.0,1.0,"raise",0.0)
	editor.data.end_stroke()
	editor.refresh()
	check(editor.landmarks.get_node("bigfoot_tree_%d" % tree_id).position.y > 0.8,"Bigfoot tree follows sculpted ground")
	editor.undo()
	check(absf(editor.landmarks.get_node("bigfoot_tree_%d" % tree_id).position.y) < 0.001,"Undo restores landmark grounding")
	editor.data.begin_stroke()
	editor.data.erase_objects(point,1.0)
	editor.data.end_stroke()
	editor.refresh()
	check(editor.landmarks.get_child_count() == 1,"Erase removes authored landmark")
	editor.undo()
	check(editor.landmarks.get_child_count() == 2,"Undo restores authored landmark")
	scene._reset_camera()
	for i in range(3):
		await process_frame
	for mesh: MeshInstance3D in editor.landmarks.find_children("*","MeshInstance3D",true,false):
		for i in range(8):
			var world := mesh.to_global(mesh.get_aabb().get_endpoint(i))
			check(not scene.camera.is_position_behind(world) and root.get_visible_rect().has_point(scene.camera.unproject_position(world)),"Camera frames nested landmark geometry")
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/native-landmarks.png")
	var save_file := "/tmp/native-landmark-save-%d.json" % OS.get_process_id()
	editor.save_path = save_file
	check(editor.save_garden(),"Landmark scene saves")
	var expected := editor.data.to_document()
	scene.queue_free()
	await process_frame
	var reopened: Node3D = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(reopened)
	reopened._chunk_editor.save_path = save_file
	check(reopened._chunk_editor.open_garden(),"Fresh scene reopens authored landmarks")
	check(reopened._chunk_editor.data.to_document() == expected and reopened._chunk_editor.landmarks.get_child_count() == 2,"Fresh scene reconstructs both landmarks and transforms")
	reopened.queue_free()
	await process_frame
	DirAccess.remove_absolute(save_file)
	print("Native landmarks: ",failures," failures")
	quit(1 if failures else 0)
