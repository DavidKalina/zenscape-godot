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
	editor.reactions_enabled = false
	editor.set_process(false)
	var original_mesh := editor.terrain.mesh
	var original_colors: PackedColorArray = original_mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	editor.data.begin_stroke()
	editor.data.paint_grass(Vector2.ZERO,3.0,1.0)
	editor.data.end_stroke()
	editor.refresh()
	check(editor.terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] != original_colors,"Grass visibly paints the imported chunk")
	editor.undo()
	check(editor.terrain.mesh == original_mesh,"Undo unpaints the imported chunk exactly")
	editor.start_flat()
	var data := editor.data
	editor.mode = "grass"
	data.begin_stroke()
	editor.dab(Vector2.ZERO,0.06)
	data.end_stroke()
	editor.refresh()
	check(not editor.content.has_node("Grass") and data.grass.count(0.0) < data.grass.size(),"Grass paints ground without scattering blades")
	check(not editor.content.has_node("Petal"),"Grass-only painting adds no flowers")
	check(data.undo() and data.grass.count(0.0) == data.grass.size(),"Grass stroke undoes completely")
	editor.grass_amount = 0.5
	editor.cover_grass()
	check(data.grass.count(0.5) == data.grass.size(),"Cover uses chosen density across chunk")
	check(not editor.content.has_node("Grass"),"Full ground coverage does not scatter blades")
	editor.mode = "blades"
	data.begin_stroke()
	editor.dab(Vector2.ZERO,0.06)
	data.end_stroke()
	editor.refresh()
	check(editor.content.has_node("Grass") and editor.content.get_node("Grass").multimesh.instance_count < 300,"Blade brush creates a local sparse patch")
	check(not editor.content.has_node("Petal"),"Blade brush does not add flowers")
	var grass_doc := data.to_document()
	var legacy := grass_doc.duplicate(true)
	legacy.version = 3
	legacy.erase("grass")
	check(data.load_document(JSON.parse_string(JSON.stringify(legacy))),"Version 3 gardens migrate")
	check(data.grass.count(0.0) == data.grass.size(),"Migration leaves legacy meadow independent")
	check(data.load_document(JSON.parse_string(JSON.stringify(grass_doc))),"Version 5 ground and blades round trip through JSON")
	var version4 := grass_doc.duplicate(true)
	version4.version = 4
	version4.erase("blades")
	check(data.load_document(version4) and data.blades == data.grass,"Version 4 preserves previous grass vegetation")
	check(data.load_document(grass_doc),"Restore current independent layers")
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
	var summit_color: Color = arrays[Mesh.ARRAY_COLOR][summit]
	check(summit_color.r > summit_color.g or (summit_color.r > 0.8 and summit_color.b > 0.8),"Summit uses warm source rock or snow rather than green ground")
	scene._reset_camera()
	check(scene.target.y > 5.0,"Frame includes the authored mountain")
	for i in range(3):
		await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/native-build-mountain.png")
	editor.undo()
	scene._reset_camera()
	check(scene.target.y < 2.0,"Flat framing excludes hidden original mountain")
	var palette: NativeBuildPalette = scene._build_palette
	palette._show_category("Sky")
	scene._celestial.next_hour()
	palette.sky_row("time").control.value = 0.7
	check(scene._celestial._target == -1.0,"Time selection cancels pending next-hour transition")
	scene._celestial.cycling = false
	scene._celestial.advance(0.5,false)
	palette.sky_row("clouds").control.value = 0.4
	palette.sky_row("fog").control.value = 0.6
	check(is_equal_approx(scene._celestial.phase,0.7) and is_equal_approx(scene._atmosphere._fog_target,0.6),"Sky sliders control native light and atmosphere")
	palette.sky_tile_for("weather_rain").pressed.emit()
	check(scene._precipitation.preset_index == 1,"The rain swatch selects native rain")
	palette.sky_row("clouds").control.value = 0.45
	var state := NativeGardenStore.capture(scene)
	scene._celestial.phase = 0.1
	NativeGardenStore.restore(scene,state)
	palette._sync_sky()
	check(is_equal_approx(palette.sky_row("time").control.value,0.7) and is_equal_approx(palette.sky_row("clouds").control.value,0.45),"Sky state restores and the palette synchronizes")
	scene._ui.visible = true
	editor.select_tool("grass")
	for i in range(3):
		await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/native-build-controls.png")
	scene.queue_free()
	await process_frame
	print("Native build tools: ",failures," failures")
	quit(1 if failures else 0)
