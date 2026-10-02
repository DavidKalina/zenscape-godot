extends SceneTree
## The pause panel: its copy, the Save a copy well, keys and signals, status.
const Pause = preload("res://scripts/pause_panel.gd")
var failures := 0
var view := SubViewport.new()
var copies: Array = []
var resumes := 0
var settings := 0
var titles := 0

func _initialize() -> void:
	# A 1440x810 frame of its own: the headless root is only 64 square.
	view.size = Vector2i(1440,810)
	view.gui_disable_input = false
	root.add_child(view)
	var panel: Control = Pause.new()
	view.add_child(panel)
	await process_frame
	panel.copy_requested.connect(func(copy_name: String, carry_on: bool) -> void: copies.append([copy_name,carry_on]))
	panel.resumed.connect(func() -> void: resumes += 1)
	panel.settings_requested.connect(func() -> void: settings += 1)
	panel.title_requested.connect(func() -> void: titles += 1)
	check(not panel.visible and not panel.is_open, "It starts hidden")
	panel.open("The quiet plain")
	check(panel.visible and panel.is_open, "Open shows it")
	check(panel.process_mode == Node.PROCESS_MODE_ALWAYS, "It works while the tree is paused")
	check(panel.mouse_filter == Control.MOUSE_FILTER_STOP and panel._scrim.mouse_filter == Control.MOUSE_FILTER_STOP, "The scrim takes the world's clicks")
	check(panel._scrim.color.is_equal_approx(Color(20/255.0,18/255.0,26/255.0,0.42)), "Scrim colour")
	check(panel.kicker.text.to_lower() == "paused", "Kicker reads Paused")
	check(panel.name_label.text == "The quiet plain", "The world's name")
	check(panel.status.text == "Kept safe · just now", "Status starts kept safe: "+panel.status.text)
	check(panel.resume_row.text == "Resume" and panel.resume_row.hint == "Esc", "Resume with its Esc hint")
	check(panel.copy_row.text == "Save a copy as…" and panel.copy_row.chevron == 1, "Save a copy as… folded (▸)")
	check(panel.settings_row.text == "Settings", "Settings")
	check(panel.title_row.text == "Return to title", "Return to title")
	check(panel.footnote.text == "Nothing is lost when you leave.", "Footnote")
	check(panel.resume_row.has_focus(), "Resume is in reach")
	check(is_equal_approx(panel._sheet.size.x,roundf(440.0*panel._px)), "The panel is 440 design pixels wide")
	check(panel._sheet.get_rect().get_center().distance_to(panel.size*0.5) <= 1.0, "The panel is centred")
	check(panel._sheet.divider.z > panel.settings_row.position.y+panel.settings_row.size.y and panel._sheet.divider.z < panel.title_row.position.y, "The divider sits between Settings and Return to title")
	# Keys move between rows; Enter on a row activates it.
	key(KEY_DOWN)
	check(panel.copy_row.has_focus(), "Down moves to Save a copy as…")
	key(KEY_DOWN)
	key(KEY_DOWN)
	key(KEY_DOWN)
	check(panel.title_row.has_focus(), "Down stops at Return to title")
	key(KEY_UP)
	check(panel.settings_row.has_focus(), "Up moves back")
	key(KEY_ENTER)
	check(settings == 1 and panel.is_open, "Enter on Settings asks for settings")
	click(panel.title_row.get_global_rect().get_center())
	check(titles == 1, "A click on Return to title asks for the title")
	# Save a copy as…
	var height: float = panel._sheet.size.y
	panel.copy_row.pressed.emit()
	check(panel.copy_open and panel._well.visible and panel.copy_row.chevron == 2, "Save a copy as… opens the well (▾)")
	check(panel._sheet.size.y > height, "The panel grows round the well")
	check(panel.copy_name.text == "The quiet plain (copy)", "The name is pre-filled: "+panel.copy_name.text)
	check(panel.copy_name.has_focus(), "The name is in reach")
	check(panel.carry_on and panel.carry_radio.selected and not panel.stay_radio.selected, "Carry on in the copy by default")
	check(panel.carry_radio.text == "Carry on in the copy" and panel.stay_radio.text == "Stay here — keep the copy for later", "Radio labels")
	check(panel.save_button.text == "Save copy ↵", "Save copy ↵")
	check(panel._well.position.y > panel.copy_row.position.y and panel._well.position.y < panel.settings_row.position.y, "The well opens in place")
	key(KEY_DOWN)
	key(KEY_DOWN)
	check(panel.stay_radio.has_focus(), "Down steps through the well")
	key(KEY_ENTER)
	check(not panel.carry_on and panel.stay_radio.selected and not panel.carry_radio.selected, "Picking Stay here switches the radio")
	panel.save_button.pressed.emit()
	check(copies.size() == 1 and copies[0] == ["The quiet plain (copy)",false], "Save copy asks for the copy: %s" % [copies])
	check(not panel.copy_open and panel.is_open, "Saving folds the well, the panel stays")
	# Enter in the name saves, under the typed name.
	panel.copy_row.pressed.emit()
	panel.carry_radio.pressed.emit()
	panel.copy_name.text = "  Fogwater  "
	panel.copy_name.grab_focus()
	key(KEY_ENTER)
	check(copies.size() == 2 and copies[1] == ["Fogwater",true], "Enter in the name saves the copy: %s" % [copies])
	# A blank name falls back.
	panel.copy_row.pressed.emit()
	panel.copy_name.text = "   "
	panel.save_copy()
	check(copies.size() == 3 and copies[2][0] == "The quiet plain (copy)", "A blank name falls back: %s" % [copies])
	# Esc folds the well first, then resumes.
	panel.copy_row.pressed.emit()
	key(KEY_ESCAPE)
	check(not panel.copy_open and panel.is_open and resumes == 0, "Esc in the name folds the well")
	check(panel.copy_row.has_focus(), "Focus goes back to the row")
	key(KEY_ESCAPE)
	check(resumes == 1 and not panel.is_open and not panel.visible, "Esc resumes and closes")
	panel.open("Moss Hollow")
	check(panel.copy_name.text == "Moss Hollow (copy)" and panel.carry_on and not panel.copy_open, "Reopening resets the well")
	panel.resume_row.pressed.emit()
	check(resumes == 2 and not panel.is_open, "Resume resumes")
	# Status.
	var now := 1_800_000_000.0
	panel.set_status(true,now-30.0,now)
	check(panel.status.text == "Keeping…", "Keeping…")
	panel.set_status(false,now-20.0,now)
	check(panel.status.text == "Kept safe · just now", "Just now: "+panel.status.text)
	panel.set_status(false,now-240.0,now)
	check(panel.status.text == "Kept safe · 4 minutes ago", "Minutes ago: "+panel.status.text)
	panel.set_status(false,now-60.0,now)
	check(panel.status.text == "Kept safe · 1 minute ago", "One minute: "+panel.status.text)
	# Small and large windows keep it centred and whole.
	for extent: Vector2 in [Vector2(960,640),Vector2(2560,1440)]:
		panel.open("The quiet plain")
		panel.size = extent
		check(panel._sheet.get_rect().get_center().distance_to(extent*0.5) <= 1.0 and panel._sheet.size.y < extent.y, "Centred and whole at %s" % extent)
	panel.close()
	print("Pause panel: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures else 0)

func key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		view.push_input(event)

func click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	view.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.global_position = at
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		view.push_input(event,true)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: "+message)
