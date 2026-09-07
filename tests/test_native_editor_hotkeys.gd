extends SceneTree
## Build-mode keyboard shortcuts and the tool-shaped brush preview.
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func key(editor,code: int,shift := false,meta := false) -> bool:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.shift_pressed = shift
	event.meta_pressed = meta
	return editor.handle_input(event)
func _run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var editor = scene._chunk_editor
	editor.start_flat()
	check(not key(editor,KEY_2),"Keys stay with the scene while inspecting")
	check(editor.mode == "raise","Inspect mode leaves the tool alone")
	editor.set_active(true)
	for entry: Array in [[KEY_2,"lower"],[KEY_3,"smooth"],[KEY_4,"flatten"],[KEY_1,"raise"]]:
		check(key(editor,entry[0]),"Tool key is consumed by build mode")
		check(editor.mode == entry[1],"Number key selects %s" % entry[1])
		check(scene._build_panel._tool_buttons[entry[1]].button_pressed,"Tool button follows the key")
	check(editor.status == editor.TOOL_TEXT.raise,"Selecting a tool describes it")
	var radius: float = editor.radius
	key(editor,KEY_BRACKETRIGHT)
	check(is_equal_approx(editor.radius,radius+0.25),"] widens the brush")
	key(editor,KEY_BRACKETLEFT)
	key(editor,KEY_BRACKETLEFT)
	check(is_equal_approx(editor.radius,radius-0.25),"[ narrows the brush")
	check(is_equal_approx(scene._build_panel._settings.radius.control.value,editor.radius),"The brush slider follows the key")
	var strength: float = editor.strength
	key(editor,KEY_BRACKETRIGHT,true)
	check(is_equal_approx(editor.strength,strength+0.25) and is_equal_approx(editor.radius,radius-0.25),"Shift ] presses harder without resizing the brush")
	key(editor,KEY_BRACKETLEFT,true)
	check(is_equal_approx(editor.strength,strength),"Shift [ eases the pressure back")
	for i in range(40):
		key(editor,KEY_BRACKETLEFT)
	check(editor.radius >= 0.4,"The brush never shrinks past its smallest size")
	editor.set_setting("radius",radius)
	check(not scene._build_panel._sky_toggle.button_pressed,"Sky starts folded away")
	check(key(editor,KEY_K),"K is consumed by build mode")
	check(scene._build_panel._sky_toggle.button_pressed and scene._build_panel._sky_panel.visible,"K opens sky and weather")
	key(editor,KEY_K)
	check(not scene._build_panel._sky_panel.visible,"K folds it away again")
	editor.select_tool("raise")
	var sculpt: float = editor.preview_radius()
	check(is_equal_approx(sculpt,editor.radius) and editor.preview_wanted(),"Sculpting previews the brush circle")
	editor.select_tool("tree")
	editor.object_scale = 2.0
	check(is_equal_approx(editor.preview_radius(),1.2) and not is_equal_approx(editor.preview_radius(),sculpt),"A tree previews its own footprint")
	editor.select_tool("flower")
	check(is_equal_approx(editor.preview_radius(),0.3),"A flower previews a smaller footprint")
	editor.select_tool("mountain")
	check(is_equal_approx(editor.preview_radius(),editor.mountain_radius),"A mountain previews its base")
	editor.select_tool("assets")
	check(not editor.preview_wanted(),"Catalog pieces show no circle")
	editor.select_tool("waterfall")
	check(editor.preview_wanted(),"The waterfall lip still shows a footprint")
	editor._fall_start = Vector2.ZERO
	check(not editor.preview_wanted(),"The landing click drops the circle")
	scene.queue_free()
	await process_frame
	print("Native editor hotkeys: ",failures," failures")
	quit(1 if failures else 0)
