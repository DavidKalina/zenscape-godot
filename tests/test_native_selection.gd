extends SceneTree
## Authored props remain editable after placement. Exercise the public editor
## path, rendered-instance picking, and undo/save boundaries together.
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

## A tree draws as its spruce variant's pair and a rock as its stone variant
## (a2eec160, 6502b431); --classic-trees/--classic-rocks keep the plain parts.
func is_part(key: String, part: String) -> bool:
	match part:
		"canopy": return key == "canopy" or (key.begins_with("tree:") and key.ends_with("-canopies"))
		"trunk": return key == "trunk" or (key.begins_with("tree:") and key.ends_with("-trunk"))
		"rock": return key == "rock" or key.begins_with("boulder_stone:")
	return key == part

func rendered_center(editor: NativeChunkEditor, id: int, part: String) -> Vector3:
	for batch: MultiMeshInstance3D in editor.content._batches:
		if not is_part(batch.get_meta("part"),part):
			continue
		var sources: Array = editor.content._sources[batch.get_meta("part")]
		for index in range(sources.size()):
			var item: Variant = sources[index].item
			if item is Dictionary and item.id == id:
				return batch.global_transform * batch.multimesh.get_instance_transform(index) * batch.multimesh.mesh.get_aabb().get_center()
	check(false,"The authored %s has a rendered instance" % part)
	return Vector3.ZERO

func rendered_color(editor: NativeChunkEditor, id: int, part: String) -> Color:
	for batch: MultiMeshInstance3D in editor.content._batches:
		if not is_part(batch.get_meta("part"),part):
			continue
		var sources: Array = editor.content._sources[batch.get_meta("part")]
		for index in range(sources.size()):
			var item: Variant = sources[index].item
			if item is Dictionary and item.id == id:
				return batch.multimesh.get_instance_color(index)
	check(false,"The authored %s has a rendered color" % part)
	return Color.TRANSPARENT

func press(editor: NativeChunkEditor, point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = point
	editor.handle_input(event)

func move(editor: NativeChunkEditor, point: Vector2, previous: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.relative = point-previous
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	editor.handle_input(event)

func _run() -> void:
	root.size = Vector2i(1440,960)
	var scene: Node3D = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.reactions_enabled = false
	editor.set_process(false)
	editor.save_path = OS.get_temp_dir().path_join("zenscape-selection-test.json")
	editor.start_flat()
	editor.set_active(true)
	editor.data.begin_stroke()
	var tree_id := editor.data.place("tree",Vector2(-3,0),0.2,1.1)
	var rock_id := editor.data.place("rock",Vector2(3,0),0.6,1.5)
	editor.data.end_stroke()
	editor.refresh()
	editor.select_tool("select")
	for i in range(3):
		await process_frame
	check(editor.mode == "select","Select is an available editor tool")
	check(scene._ui.find_child("SelectionPanel",true,false) != null,"The scene exposes an inspector for selected props")
	# Keep the picker tests independent of inspector/palette screen coverage.
	scene._ui.visible = false
	var tree_screen: Vector2 = scene.camera.unproject_position(rendered_center(editor,tree_id,"canopy"))
	var rock_screen: Vector2 = scene.camera.unproject_position(rendered_center(editor,rock_id,"rock"))
	check(editor.pick_object(tree_screen) == tree_id,"Picking the visible canopy identifies its tree")
	check(editor.pick_object(rock_screen) == rock_id,"Picking the visible rock identifies its stable ID")
	var unchanged := editor.data.to_document()
	editor.select_object(tree_id)
	check(editor.selected_object().get("id") == tree_id,"Selection exposes the selected prop")
	var tree_parts := editor.selection.parts(tree_id)
	check(not tree_parts.is_empty() and tree_parts.all(func(part: Dictionary) -> bool: return part.id == tree_id),"Selection bounds request only the selected object's rendered parts")
	check(editor.data.to_document() == unchanged,"Selecting leaves the saved garden unchanged")

	# Taking hold of a still-arriving piece finishes its reaction, including
	# when the scene is paused. Animation must never fight the live preview.
	var reacting := editor.selected_object()
	scene._paused = true
	check(editor.reactions.play("tree",editor.reactions.record_pose(reacting),reacting,tree_id),"The placed tree starts a reaction")
	check(editor.reactions.active_count() == 1,"The paused reaction remains active before selection")
	editor.select_object(tree_id)
	check(editor.reactions.active_count() == 0,"Selection finishes even a paused placement reaction")
	editor.begin_selection_edit()
	editor.update_selected({"x":-2.0})
	var moved_center := rendered_center(editor,tree_id,"canopy")
	scene._paused = false
	editor.reactions.advance(1.0)
	check(rendered_center(editor,tree_id,"canopy").is_equal_approx(moved_center),"A finished reaction cannot overwrite an ongoing edit preview")
	editor.end_selection_edit()
	editor.undo()

	# Continuous inspector edits form one gesture and preserve all unrelated data.
	var original := editor.selected_object().duplicate(true)
	editor.begin_selection_edit()
	editor.update_selected({"scale":1.4})
	editor.update_selected({"scale":1.8,"angle":1.0})
	var live_tint := Color("ba6042")
	editor.update_selected({"tint":NativeObjectPose.encode_tint(Color("4d885e"))})
	editor.update_selected({"tint":NativeObjectPose.encode_tint(live_tint)})
	var tinted_document := editor.data.to_document()
	editor._notify_play_geometry()
	check(editor.data.to_document() == tinted_document,"Geometry notification preserves authored tint and pose records")
	# Dummy rendering does not retain MultiMesh instance-color readback.
	if DisplayServer.get_name() != "headless":
		check(rendered_color(editor,tree_id,"canopy").is_equal_approx(live_tint),"Recoloring updates the visible canopy before the gesture ends")
		check(rendered_color(editor,tree_id,"trunk").is_equal_approx(Color.WHITE),"Recoloring foliage preserves the trunk's original material tint")
	editor.end_selection_edit()
	var edited := editor.selected_object().duplicate(true)
	check(is_equal_approx(edited.scale,1.8) and is_equal_approx(edited.angle,1.0) and edited.has("tint"),"A gesture can resize, rotate and recolor an existing prop")
	editor.undo()
	check(editor.data.object_by_id(tree_id) == original,"One undo restores the entire inspector gesture")
	editor.redo()
	check(editor.data.object_by_id(tree_id) == edited,"Redo restores the entire inspector gesture")
	check(editor.data.object_by_id(rock_id).scale == 1.5,"Editing the tree leaves the rock unchanged")

	editor.select_object(tree_id)
	editor.duplicate_selected()
	var duplicate := editor.selected_object().duplicate(true)
	var duplicate_id: int = duplicate.get("id",-1)
	check(duplicate_id != tree_id and duplicate_id >= 0 and editor.data.objects.size() == 3,"Duplicate creates and selects a new stable ID")
	for key in ["asset","angle","scale","pose","tint"]:
		check(duplicate.get(key) == edited.get(key),"Duplicate preserves the original %s" % key)
	editor.begin_selection_edit()
	editor.update_selected({"x":5.0,"z":2.0,"scale":0.8})
	editor.end_selection_edit()
	check(editor.data.object_by_id(tree_id) == edited,"Changing a duplicate does not change its source")
	editor.delete_selected()
	check(editor.data.object_by_id(duplicate_id).is_empty() and editor.selected_object().is_empty(),"Delete removes the prop and clears selection")
	editor.undo()
	check(not editor.data.object_by_id(duplicate_id).is_empty(),"Undo restores a deleted prop with its stable ID")

	# Under modeless controls, the default since 7a1d6669, a left press is the
	# hand's, never the editor's: the mouse drag and click are --classic-controls'.
	if not preload("res://scripts/modeless_input.gd").enabled():
		# A mouse drag must move the selected object, not stamp another one, and
		# all of its motion events must share one undo boundary.
		editor.select_object(rock_id)
		var rock_before := editor.selected_object().duplicate(true)
		rock_screen = scene.camera.unproject_position(rendered_center(editor,rock_id,"rock"))
		var drag_end := rock_screen+Vector2(30,12)
		check(editor.pick(drag_end) != null,"The drag ends above terrain")
		press(editor,rock_screen,true)
		move(editor,rock_screen+Vector2(15,6),rock_screen)
		move(editor,drag_end,rock_screen+Vector2(15,6))
		press(editor,drag_end,false)
		var rock_after := editor.data.object_by_id(rock_id)
		check(not is_equal_approx(rock_before.x,rock_after.x) or not is_equal_approx(rock_before.z,rock_after.z),"Dragging the rendered rock moves its existing record")
		check(editor.data.objects.size() == 3,"Dragging never places another prop")
		editor.undo()
		check(editor.data.object_by_id(rock_id) == rock_before,"One undo restores a multi-event mouse drag")
		editor.redo()
		check(editor.data.object_by_id(rock_id) == rock_after,"Redo restores the dragged position")

		var empty := Vector2(2,2)
		check(editor.pick_object(empty) < 0,"The corner is empty sky")
		press(editor,empty,true)
		press(editor,empty,false)
		check(editor.selected_object().is_empty(),"Clicking empty space clears selection")
	editor.select_object(tree_id)
	check(editor.save_garden(),"An edited garden saves successfully")
	var saved := editor.data.to_document()
	editor.delete_selected()
	check(editor.open_garden(),"An edited garden reopens successfully")
	check(editor.data.to_document() == saved,"Save/Open preserves edited poses, colors, positions and IDs")
	check(editor.selected_object().is_empty(),"Open does not retain a stale selection")
	# The empty inspector should be a short prompt. Expanded details must stay
	# above the palette and inside a shorter window, scrolling when needed.
	scene._ui.visible = true
	var panel: NativeSelectionPanel = scene._ui.find_child("SelectionPanel",true,false)
	for i in range(8):
		await process_frame
	check(panel.size.y < 120.0,"An empty selection inspector stays compact")
	check(not panel.visible,"An empty selection leaves the landscape clear")
	editor.select_object(tree_id)
	panel._more.button_pressed = true
	root.size = Vector2i(960,640)
	for i in range(8):
		await process_frame
	var panel_rect := panel.get_global_rect()
	var viewport_rect := root.get_visible_rect()
	check(panel_rect.position.y >= viewport_rect.position.y and panel_rect.end.y <= viewport_rect.end.y,"Expanded selected-object controls stay inside a shorter window")
	check(panel_rect.end.y <= scene._build_palette._launcher.get_global_rect().position.y,"Expanded controls stay above the palette")
	check(panel._scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,"Advanced settings use a separate page without scrollbars")
	DirAccess.remove_absolute(editor.save_path)
	scene.queue_free()
	await process_frame
	print("Native selection: ",failures," failures")
	quit(1 if failures else 0)
