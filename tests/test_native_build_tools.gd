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
	scene.set_process(false)
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.set_process(false)
	editor.start_flat()
	var data := editor.data
	editor.mode = "grass"
	data.begin_stroke()
	editor.dab(Vector2.ZERO,0.06)
	data.end_stroke()
	editor.refresh()
	check(editor.content.has_node("Grass"),"One grass dab produces visible blades")
	check(not editor.content.has_node("Petal"),"Grass-only painting adds no flowers")
	check(data.undo() and data.grass.count(0.0) == data.grass.size(),"Grass stroke undoes completely")
	editor.grass_amount = 0.5
	editor.cover_grass()
	check(data.grass.count(0.5) == data.grass.size(),"Cover uses chosen density across chunk")
	check(editor.content.get_node("Grass").multimesh.instance_count > 10000,"Coverage renders native grass instances")
	var grass_doc := data.to_document()
	var legacy := grass_doc.duplicate(true)
	legacy.version = 3
	legacy.erase("grass")
	check(data.load_document(JSON.parse_string(JSON.stringify(legacy))),"Version 3 gardens migrate")
	check(data.grass.count(0.0) == data.grass.size(),"Migration leaves legacy meadow independent")
	check(data.load_document(JSON.parse_string(JSON.stringify(grass_doc))),"Version 4 grass round trips through JSON")
	var bad := grass_doc.duplicate(true)
	bad.grass[4] = 2.0
	check(not data.load_document(bad) and data.to_document() == grass_doc,"Invalid density rejects atomically")
	data.begin_stroke()
	editor.set_active(true)
	editor.mode = "mountain"
	editor.mountain_radius = 8.0
	editor.mountain_peak = 18.0
	scene._ui.visible = false
	scene._reset_camera()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = scene.camera.unproject_position(Vector3.ZERO)
	editor.handle_input(event)
	event.pressed = false
	editor.handle_input(event)
	editor.refresh()
	check(data.ground_height(Vector2.ZERO) > 15.0,"Mountain stamp creates a tall peak immediately")
	check(data.ground_height(Vector2(12,12)) == 0.0,"Mountain leaves ground outside base untouched")
	check(data.heights.count(0.0) > 0 and Array(data.heights).max() <= 24.0,"Mountain respects height bounds")
	check(scene._precipitation._materials[0].get_shader_parameter("top") > Array(data.heights).max(),"Rain ceiling follows summit")
	var arrays := editor.terrain.mesh.surface_get_arrays(0)
	var summit := 0
	for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
		if arrays[Mesh.ARRAY_VERTEX][i].y > arrays[Mesh.ARRAY_VERTEX][summit].y:
			summit = i
	check(arrays[Mesh.ARRAY_COLOR][summit].r > 0.25,"Summit uses alpine stone palette")
	scene._reset_camera()
	check(scene.target.y > 5.0,"Frame includes the authored mountain")
	for i in range(3):
		await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/native-build-mountain.png")
	editor.undo()
	scene._reset_camera()
	check(scene.target.y < 2.0,"Flat framing excludes hidden original mountain")
	scene._celestial.next_hour()
	editor._sky_controls.time.value = 0.7
	check(scene._celestial._target == -1.0,"Time selection cancels pending next-hour transition")
	scene._celestial.cycling = false
	scene._celestial.advance(0.5,false)
	editor._sky_controls.clouds.value = 0.4
	editor._sky_controls.fog.value = 0.6
	check(is_equal_approx(scene._celestial.phase,0.7) and is_equal_approx(scene._atmosphere._fog_target,0.6),"Sky sliders control native light and atmosphere")
	editor._sky_controls.weather.item_selected.emit(1)
	check(scene._precipitation.preset_index == 1,"Build weather control selects native rain")
	editor._sky_controls.clouds.value = 0.45
	var state := NativeGardenStore.capture(scene)
	scene._celestial.phase = 0.1
	NativeGardenStore.restore(scene,state)
	editor._sync_sky_controls()
	check(is_equal_approx(editor._sky_controls.time.value,0.7) and is_equal_approx(editor._sky_controls.clouds.value,0.45),"Sky state restores and controls synchronize")
	scene._ui.visible = true
	editor.mode = "grass"
	editor._update_tool_settings()
	for child in editor._tools.get_children():
		if child is CheckButton:
			child.button_pressed = true
	for i in range(3):
		await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/native-build-controls.png")
	scene.queue_free()
	await process_frame
	print("Native build tools: ",failures," failures")
	quit(1 if failures else 0)
