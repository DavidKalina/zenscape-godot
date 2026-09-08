extends SceneTree
## Actual editor commit/preview paths; no user saves or mouse input.
var rows: Array[Dictionary] = []
var output := "/tmp/zs-object-edits.json"
var world_file := ""
var redwood := false
var frame_gaps: Array[float] = []
var previous_frame := 0

func _initialize() -> void: _run.call_deferred()

func measure(label: String, action: Callable) -> void:
	var start := Time.get_ticks_usec()
	action.call()
	var row := {"operation":label,"ms":float(Time.get_ticks_usec()-start)/1000.0}
	rows.append(row)
	print("OBJECT_EDIT ",JSON.stringify(row))

func _run() -> void:
	root.size = Vector2i(1440,900)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg.begins_with("--file="): world_file = arg.trim_prefix("--file=")
		if arg == "--redwood-bigfoot": redwood = true
	var scene = load("res://studies/diorama.tscn").instantiate()
	root.add_child(scene)
	scene.close_menu()
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.set_process(false)
	editor.set_active(true)
	if redwood:
		editor.form_landscape("redwood_grove","",false)
		scene._has_world = true
		measure("invite_bigfoot",func(): scene.invite_bigfoot(Vector3.ZERO))
	if not world_file.is_empty():
		editor.save_path = world_file
		if not editor.open_garden():
			quit(1)
			return
	await create_timer(1.0).timeout
	previous_frame = Time.get_ticks_usec()
	process_frame.connect(_frame)
	for i in range(4):
		measure("place_commit",func():
			editor.data.begin_stroke()
			editor.data.place("rock",Vector2(i*0.8,0),0.0,1.0)
			editor.data.end_stroke()
			editor.refresh())
		await create_timer(0.6).timeout
	editor.select_tool("select")
	editor.select_object(int(editor.data.objects.back().id))
	editor.begin_selection_edit()
	for i in range(8):
		measure("drag_preview",func(): editor.update_selected({"x":2.4+i*0.05}))
		await process_frame
	measure("drag_release",func(): editor.end_selection_edit())
	measure("selection_marker",func(): editor.selection.update_marker(editor.selected_object_id))
	measure("instance_preview",func(): editor.content.update_object_preview(editor.selected_object()))
	measure("geometry_notification",func(): editor._notify_play_geometry())
	editor.data.place("rock",Vector2(-1,0),0.0,1.0)
	measure("content_rebuild",func(): editor.content.rebuild())
	measure("surface_maps",func(): editor._update_surface_maps(editor.data.heights == editor.data.original_heights))
	measure("remaining_refresh",func(): editor.refresh())
	await create_timer(2.0).timeout
	if redwood:
		measure("redwood_cover",func(): scene._redwood_mist._cover(editor.data))
		measure("leaf_litter",func():
			scene._leaf_objects_revision = -1
			scene._update_leaf_litter(0.0))
		measure("habitat_setup",func(): scene.habitat.setup(scene.get_node("Reference"),editor.data))
		measure("navigation_begin",func(): scene.navigation.begin_rebuild(scene.habitat,scene.habitat.clear_at,0.35,0.3))
		measure("navigation_all_cells",func():
			while not scene.navigation.advance_rebuild(2000): pass)
		measure("brain_world_changed",func(): scene.brain.world_changed())
		measure("brain_advance",func(): scene.brain.advance(1.0/60.0))
	process_frame.disconnect(_frame)
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"gpu":RenderingServer.get_video_adapter_name(),"rows":rows,"frame_gaps_ms":frame_gaps},"\t"))
	frame_gaps.sort()
	print("EDIT_FRAMES max_ms=",frame_gaps.back()," p95_ms=",frame_gaps[int(frame_gaps.size()*0.95)])
	quit()

func _frame() -> void:
	var now := Time.get_ticks_usec()
	frame_gaps.append(float(now-previous_frame)/1000.0)
	previous_frame = now
