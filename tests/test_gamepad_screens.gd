extends SceneTree
## The gamepad on the screens (docs/gamepad.md "Screens"), in the full cozy
## scene launched as the game is, in a scratch folder, headless, through
## injected joypad events:
##   - the front page: the D-pad walks its entries, A presses one;
##   - Settings: every row takes focus on the pad, B closes it;
##   - the library: left and right browse, up lifts focus onto the action
##     row, Delete asks first and A on its card keeps the world, B goes back
##     to the strip, X opens New world;
##   - New world: the D-pad picks a land, B goes back to the library;
##   - B on the library returns to the front page;
##   - the focus ring follows the focus while the pad is in hand.
##   godot --headless --path . --script tests/test_gamepad_screens.gd
const Library = preload("res://scripts/world_library.gd")
const Pad = preload("res://scripts/pad.gd")
var failures := 0
var world: Node3D

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func until(condition: Callable, seconds := 60.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > deadline: return false
		await process_frame
	return true

func frames(n: int) -> void:
	for i in range(n): await process_frame

func button(index: JoyButton, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = index
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(index: JoyButton) -> void:
	button(index,true)
	await frames(2)
	button(index,false)
	await frames(3)

func focus() -> Control:
	return world.get_viewport().gui_get_focus_owner()

func run() -> void:
	create_timer(900).timeout.connect(func() -> void: print("FAIL: timed out"); quit(2))
	root.size = Vector2i(1440,900)
	var dir := "/private/tmp/gamepad-screens-%d" % Time.get_ticks_usec()
	var seeded := Library.new(dir.path_join("worlds"))
	var now := Time.get_unix_time_from_system()
	seeded.create("Fern bank","plain","fern-owl-0001",now-600.0)
	seeded.create("Moss hollow","plain","moss-owl-0002",now-60.0)
	world = load("res://studies/cozy_worlds.tscn").instantiate()
	world.set_meta("movie_capture",true)
	world.places_path = dir.path_join("places.json")
	root.add_child(world)
	current_scene = world
	check(await until(func() -> bool: return world.shell_ready,300.0),"The scene opens on the title")
	var pad: Node = world.pad
	var title: Control = world.world_title
	# The front page.
	check(pad.context() == "front","The front page")
	await tap(JOY_BUTTON_DPAD_DOWN)
	var first := focus()
	check(first != null and world._menu.is_ancestor_of(first),"The pad focuses an entry of the card")
	await tap(JOY_BUTTON_DPAD_DOWN)
	check(focus() != first and world._menu.is_ancestor_of(focus()),"D-pad down walks to the next")
	check(await until(func() -> bool: return pad.ring.target() == focus() and pad.ring._alpha > 0.9,8.0),"The stitched ring is round it once the card has faded in")
	# Settings from the front page: every row reachable, B closes.
	for button_node: Button in world._menu.buttons:
		if button_node.text == "Settings": button_node.grab_focus()
	await tap(JOY_BUTTON_A)
	check(world._settings.visible and pad.context() == "settings","A on Settings opens it")
	await frames(3)
	var held: Control = world._settings.gui_get_focus_owner()
	check(held != null,"The dialog's first row has the focus")
	var mute: Control = null
	for node: Node in world._settings.find_children("*","CheckButton",true,false):
		if node.text == "Mute all sound": mute = node
	check(mute != null and mute.focus_mode == Control.FOCUS_ALL,"The rows the mouse kept out of focus take it on the pad")
	var vibration: Node = world._settings.find_child("PadVibration",true,false)
	check(vibration != null and vibration.button_pressed == Pad.vibration(),"Controller vibration is offered, on")
	world._settings.hide()
	await frames(3)
	# The library.
	world._your_worlds.grab_focus()
	await tap(JOY_BUTTON_A)
	check(await until(func() -> bool: return world.library_open and title.visible and pad.context() == "library"),"A on Your worlds opens the library")
	await frames(5)
	var picked: int = title.selected
	await tap(JOY_BUTTON_DPAD_RIGHT)
	check(title.selected == picked+1,"D-pad right browses")
	await tap(JOY_BUTTON_DPAD_LEFT)
	check(title.selected == picked,"D-pad left browses back")
	await tap(JOY_BUTTON_DPAD_UP)
	check(focus() == title.enter_button,"Up lifts the focus onto Enter world")
	for i in range(3): await tap(JOY_BUTTON_DPAD_RIGHT)
	check(focus() == title.delete_button,"Right walks the row to Delete")
	var count: int = title.worlds.size()
	await tap(JOY_BUTTON_A)
	check(title.mode == "delete" and focus() == title.keep_button,"A on Delete asks first, Keep it in focus")
	await tap(JOY_BUTTON_A)
	check(title.mode == "idle" and title.worlds.size() == count,"A keeps the world")
	await tap(JOY_BUTTON_DPAD_UP)
	await tap(JOY_BUTTON_DPAD_UP)
	check(focus() == title.settings_button,"Up again reaches the links")
	await tap(JOY_BUTTON_B)
	check(focus() == null and pad._library_line == -1,"B goes back to the strip")
	await tap(JOY_BUTTON_X)
	check(world.new_world_panel.visible and pad.context() == "new_world","X opens New world")
	var land: String = world.new_world_panel.land
	await tap(JOY_BUTTON_DPAD_DOWN)
	check(world.new_world_panel.land != land,"D-pad down picks the next land (%s)" % world.new_world_panel.land)
	await tap(JOY_BUTTON_B)
	check(await until(func() -> bool: return not world.new_world_panel.visible and title.visible),"B goes back to the library")
	await frames(5)
	await tap(JOY_BUTTON_B)
	check(await until(func() -> bool: return not world.library_open and pad.context() == "front"),"B on the library returns to the front page")
	print("PASS: gamepad screens" if failures == 0 else "FAIL: gamepad screens (%d)" % failures)
	quit(1 if failures else 0)
