extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func settle() -> void:
	for i in range(4): await process_frame
func key(code: Key, command := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.ctrl_pressed = command
	root.push_input(event)
func run() -> void:
	root.size = Vector2i(1440,960)
	var scene: Node3D = load("res://studies/nursery_preview.tscn").instantiate()
	root.add_child(scene)
	var palette: NativeBuildPalette = scene._build_palette
	var editor: NativeChunkEditor = scene._chunk_editor
	await settle()
	check(not palette._bar.visible,"The scene starts without an open palette")
	check(not palette.contains_pointer(root.get_visible_rect().size*0.5),"Closed palette leaves the diorama interactive")
	key(KEY_K,true)
	await settle()
	check(palette._bar.visible and palette._search.has_focus(),"Ctrl/Cmd K opens focused search")
	check(not palette._launcher.visible,"The launcher disappears while search is open")
	check(palette.contains_pointer(Vector2(10,10)),"Open palette blocks editing behind the modal")
	var seen := {}
	while true:
		for child in palette._results.get_children(): seen[child] = true
		if palette._next_page.disabled: break
		palette._turn_page(1)
	check(seen.size() == palette._entries.size(),"Every tool, asset, sky preset and action is reachable through pages")
	palette._browse("Cover")
	check(palette._matches.has("tree") and not palette._matches.has("rock"),"Plant tab separates foliage from finished objects")
	palette._search.text = "pine"
	palette._search.text_changed.emit("pine")
	await settle()
	check(palette._matches == ["tree"],"Search finds the pine alias")
	key(KEY_ENTER)
	await settle()
	check(editor.mode == "tree" and not palette._bar.visible,"Enter chooses the result and returns to the scene")
	key(KEY_K,true)
	palette._search.text = "zzzzzzzz"
	palette._search.text_changed.emit("zzzzzzzz")
	await settle()
	check(palette._empty.visible and palette._results.get_child_count() == 0,"Empty search is explicit")
	key(KEY_ESCAPE)
	check(not palette._bar.visible and editor.mode == "tree","Escape dismisses without changing the tool")
	root.size = Vector2i(960,640)
	palette.open_palette()
	await settle()
	check(root.get_visible_rect().encloses(palette._bar.get_global_rect()),"Palette fits the minimum window: "+str(palette._bar.get_global_rect())+" in "+str(root.get_visible_rect()))
	check(palette._results.get_child_count() <= 6,"Small windows page six results")
	for scroll in palette.find_children("*","ScrollBar",true,false):
		check(not scroll.is_visible_in_tree(),"No scrollbar is exposed in search")
	palette.close_palette()
	editor.select_tool("tree")
	palette._tune.button_pressed = true
	await settle()
	check(palette.strip_fits(),"Tool settings fit without scrolling")
	check(palette._setting_pages.visible,"Long settings offer pages")
	var first: Control = palette._grid.get_child(0)
	palette._setting_page = 1
	palette._paginate_settings()
	await settle()
	check(not first.visible and palette._grid.get_child(6).visible,"Settings pages reveal remaining controls")
	check(root.get_visible_rect().encloses(palette._details.get_global_rect()),"Settings stay inside the small window")
	print("Command palette: ",failures," failures")
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
