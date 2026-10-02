extends SceneTree
## The field notes: the count and headings, found and not-found rows, live
## updates, Walk me through it again, Back and Esc, scrolling, while paused.
const Notes = preload("res://scripts/field_notes.gd")
const FirstSteps = preload("res://scripts/first_steps.gd")
var failures := 0
var view := SubViewport.new()
var closes := 0
var walks := 0

func _initialize() -> void:
	# A 1440x810 frame of its own: the headless root is only 64 square.
	view.size = Vector2i(1440,810)
	view.gui_disable_input = false
	root.add_child(view)
	var steps: Node = FirstSteps.new()
	steps.settings_path = ""
	root.add_child(steps)
	steps.mark("look")
	steps.mark("raise")
	var page: Control = Notes.new()
	view.add_child(page)
	await process_frame
	page.closed.connect(func() -> void: closes += 1)
	page.walk_requested.connect(func() -> void: walks += 1)
	check(not page.visible and not page.is_open, "It starts hidden")
	page.open(null)
	check(not page.is_open, "Without a model it does not open")
	paused = true
	page.open(steps)
	check(page.visible and page.is_open, "Open shows it")
	check(page.process_mode == Node.PROCESS_MODE_ALWAYS, "It works while the tree is paused")
	check(page.mouse_filter == Control.MOUSE_FILTER_STOP and page._scrim.mouse_filter == Control.MOUSE_FILTER_STOP, "The scrim takes the world's clicks")
	check(page.kicker.text.to_lower() == "field notes", "Kicker reads Field notes")
	check(page.count_label.text == "2 of %d found" % FirstSteps.VERBS.size(), "The count: "+page.count_label.text)
	check(FirstSteps.VERBS.size() == 25, "There are 25 verbs")
	check(page.headings.size() == FirstSteps.GROUPS.size(), "A heading for every group")
	for i in range(FirstSteps.GROUPS.size()): check(page.headings[i].text == FirstSteps.GROUPS[i][1], "Heading %d is %s" % [i,FirstSteps.GROUPS[i][1]])
	check(page.entries.size() == 25, "A row for every verb")
	var look = page.entries["look"]
	var raise_row = page.entries["raise"]
	check(look.found and look.title == "Look round" and look.body == FirstSteps.VERBS["look"]["line"], "A found verb reads its name and its line")
	check(raise_row.body.contains(" · "), "The line keeps its · as written")
	var glide = page.entries["glide"]
	check(not glide.found and glide.title == "" and glide.body == FirstSteps.VERBS["glide"]["clue"], "A verb not found shows only its clue")
	for id: String in page.entries:
		var row = page.entries[id]
		if not row.found: check(row.title == "" and row.body == FirstSteps.VERBS[id]["clue"] and not row.body.contains(FirstSteps.VERBS[id]["name"]), "%s shows only its clue" % id)
	check(page.headings[0].position.y < look.position.y and look.position.y < glide.position.y and glide.position.y < page.headings[1].position.y, "Rows sit under their heading, in order")
	check(look.size.y > glide.size.y-1.0 and glide.size.y > 0.0, "Rows have a height")
	# It fits the frame and scrolls.
	check(page._sheet.get_rect().get_center().distance_to(page.size*0.5) <= 1.0, "The panel is centred")
	check(page._sheet.size.y <= 810.0-2.0*Notes.MARGIN*page._px+1.0 and page._sheet.size.y > 600.0, "The panel fits 1440x810: %s" % page._sheet.size)
	check(page._content_height > page._view.size.y, "The list is taller than its view")
	check(is_equal_approx(page._content.position.y,0.0), "It opens at the top")
	key(KEY_DOWN)
	check(page.scroll > 0.0 and page._content.position.y < 0.0, "Down scrolls the list")
	key(KEY_UP)
	check(is_zero_approx(page.scroll), "Up scrolls back")
	wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check(is_equal_approx(page.scroll,Notes.NOTCH*page._px), "The wheel scrolls: %s" % page.scroll)
	wheel(MOUSE_BUTTON_WHEEL_UP)
	wheel(MOUSE_BUTTON_WHEEL_UP)
	check(is_zero_approx(page.scroll), "It stops at the top")
	key(KEY_PAGEDOWN)
	check(page.scroll > page._view.size.y*0.5, "Page down scrolls a page")
	for i in range(40): key(KEY_PAGEDOWN)
	check(is_equal_approx(page.scroll,page._content_height-page._view.size.y), "It stops at the foot")
	key(KEY_DOWN)
	check(page.walk_row.has_focus(), "Down at the foot steps on to Walk me through it again")
	key(KEY_DOWN)
	check(page.back_row.has_focus(), "Down again reaches Back")
	key(KEY_DOWN)
	check(page.back_row.has_focus(), "Down stops at Back")
	key(KEY_UP)
	key(KEY_UP)
	check(page.get_viewport().gui_get_focus_owner() == null, "Up from Walk steps back into the list")
	# A verb found while it is open updates it.
	page.scroll_by(-100000.0)
	var before: float = page.entries["glide"].size.y
	steps.mark("glide")
	check(page.count_label.text == "3 of 25 found", "The count updates: "+page.count_label.text)
	var found_glide = page.entries["glide"]
	check(found_glide.found and found_glide.title == "Go and see" and found_glide.body == FirstSteps.VERBS["glide"]["line"], "The row reads in full once found")
	check(found_glide.size.y > before, "The found row is taller than its clue")
	# Walk me through it again.
	steps.mark("groove")
	var restarts := [0]
	steps.step_changed.connect(func(_id: String) -> void: restarts[0] += 1)
	page.walk_row.pressed.emit()
	check(restarts[0] == 1 and walks == 1, "Walk me through it again restarts the model and asks to walk")
	check(not steps.found.get("look",false) and steps.found.get("glide",false), "Only the steps are forgotten, the notes stay")
	check(page.is_open and closes == 0, "Walking leaves the page for the wiring to close")
	# Back and Esc.
	page.back_row.grab_focus()
	key(KEY_ENTER)
	check(closes == 1 and not page.is_open and not page.visible, "Enter on Back closes and says so")
	page.open(steps)
	key(KEY_ESCAPE)
	check(closes == 2 and not page.is_open and not page.visible, "Esc closes while the tree is paused")
	steps.mark("photo")
	check(page.count_label.text != "", "A closed page is left alone")
	page.open(steps)
	check(page.entries["photo"].found and is_zero_approx(page.scroll), "Reopening is fresh from the top")
	page.close()
	# Small and large windows keep it centred and whole.
	for extent: Vector2 in [Vector2(960,640),Vector2(2560,1440)]:
		page.open(steps)
		page.size = extent
		check(page._sheet.get_rect().get_center().distance_to(extent*0.5) <= 1.0 and page._sheet.size.y < extent.y, "Centred and whole at %s" % extent)
	page.close()
	paused = false
	print("Field notes: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures else 0)

func key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		view.push_input(event)

func wheel(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = Vector2(720,400)
	event.pressed = true
	view.push_input(event,true)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: "+message)
