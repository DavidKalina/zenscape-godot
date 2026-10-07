extends SceneTree
## suite: serial
## The gamepad in the live scene (docs/gamepad.md, scripts/pad_input.gd),
## headless, through injected joypad events:
##   - the named actions are in the InputMap, the pad's A and B in ui_accept
##     and ui_cancel, and no pad read is left hard-coded in the wanderer;
##   - the last device used decides the prompts: the walk and fly hints, the
##     hand's hint line and the first steps' lines;
##   - building: the left stick moves the cursor (and the pointer with it),
##     the right stick orbits, the triggers zoom, the shoulders step the tool,
##     the D-pad the case and the size, Y the mode; A taps a tree in with a
##     seed in hand, B puts it down, B held undoes;
##   - build -> walk (View) -> fly (A held) -> land (Y) -> walk -> build (B);
##   - Menu pauses, the D-pad steps the panel, A opens the field notes and B
##     comes back from them, B resumes;
##   - L3 opens photo mode, its sticks compose, X is the ground eye, B leaves;
##     View held watches, any button comes back;
##   - the keyboard and mouse still do what they did: V and Esc, the walk's
##     keys, the wheel, Q and Esc in hand, and a moved mouse takes the cursor.
##   godot --headless --path . --script tests/test_gamepad.gd
## Waits about a minute headless for the sky under the loading veil.
## suite: slow
const Pad = preload("res://scripts/pad.gd")
const PadInput = preload("res://scripts/pad_input.gd")
const FirstSteps = preload("res://scripts/first_steps.gd")
var failures := 0
var scene: Node3D
var pad: Node
var eye: Node

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func frames(n: int) -> void:
	for i in range(n): await process_frame

func seconds(s: float) -> void:
	await create_timer(s).timeout

## Waits for `condition` up to `limit` seconds: under load (parallel runs)
## a fixed wait comes up short.
func until(condition: Callable, limit := 10.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(limit*1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > deadline: return false
		await process_frame
	return true

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
	await frames(2)

func axis(which: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = which
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func key(code: Key, down := true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func mouse_to(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = Vector2(8,0)
	Input.parse_input_event(event)
	Input.flush_buffered_events()

## Where the land's middle is on screen.
func land_middle() -> Vector2:
	var editor: Node = scene._chunk_editor
	var local := Vector3(0.0,0.0,0.0)
	var hit: Variant = editor.data.ground_height(Vector2.ZERO)
	if hit != null: local.y = float(hit)
	return scene.camera.unproject_position(editor.terrain.to_global(local))

func run() -> void:
	create_timer(600.0).timeout.connect(func() -> void: push_error("gamepad test timed out"); quit(2))
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.set_meta("manage_worlds",true)
	scene.places_path = "/private/tmp/gamepad-%d/places.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	root.size = Vector2i(1440,900)
	root.content_scale_size = Vector2i(1440,900)
	root.add_child(scene)
	current_scene = scene
	while not (scene.places_ready and scene.shell_ready): await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await frames(20)
	pad = scene.pad
	eye = scene.wanderer
	_actions()
	await _prompts()
	await _building()
	await _modes()
	await _pause()
	await _photo_and_watch()
	await _keys_and_mouse()
	print("PASS: gamepad" if failures == 0 else "FAIL: gamepad (%d)" % failures)
	quit(1 if failures else 0)

func _actions() -> void:
	var missing: Array = Pad.ACTIONS.keys().filter(func(action: String) -> bool: return not InputMap.has_action(action))
	check(missing.is_empty(),"Every pad action is in the InputMap (missing: %s)" % str(missing))
	var has_button := func(action: String, index: JoyButton) -> bool:
		return InputMap.action_get_events(action).any(func(event: InputEvent) -> bool: return event is InputEventJoypadButton and event.button_index == index)
	check(has_button.call("ui_accept",JOY_BUTTON_A) and has_button.call("ui_cancel",JOY_BUTTON_B),"The pad's A and B are the GUI's accept and cancel")
	check(Pad.glyph("fly_land") == "Y" and Pad.glyph("build_tool_next") == "RB" and Pad.glyph("zoom_in") == "RT" and Pad.glyph("move_left") == "LS","The prompts name each action by its binding")
	var source := FileAccess.get_file_as_string("res://scripts/wanderer_eye.gd")
	check(not source.contains("is_joy_button_pressed") and not source.contains("get_joy_axis") and not source.contains("is_physical_key_pressed"),"The wanderer reads the pad and the walk's keys through actions only")

func _prompts() -> void:
	key(KEY_SHIFT)
	key(KEY_SHIFT,false)
	await frames(2)
	check(not Pad.using_pad(),"A key: the keyboard and mouse are in hand")
	eye._hint.text = eye.HINT
	await frames(2)
	check(eye._hint.shown_text() == eye.HINT and eye._hint.visible_characters == -1,"The walk hint names the keys")
	await tap(JOY_BUTTON_DPAD_UP)
	check(Pad.using_pad(),"A pad press: the pad is in hand")
	await frames(2)
	check(eye._hint.shown_text() == eye.PAD_HINTS[eye.HINT] and eye._hint.visible_characters == 0,"The walk hint names the pad: %s" % eye._hint.shown_text())
	eye._hint.text = eye.PLANE_HINT
	await frames(2)
	check("{Y} land" in eye._hint.shown_text(),"The plane's hint: Y lands")
	check(FirstSteps.line("look") == FirstSteps.PAD_LINES.look,"The first steps' lines are the pad's")
	var reach: Node = scene.hand_reach
	reach._show_hint(reach.VOID_HINT)
	check(str(scene.creation_palette.get("_reach_hint")) == reach.PAD_HINTS[reach.VOID_HINT],"The hand's hint line is the pad's")
	key(KEY_SHIFT)
	key(KEY_SHIFT,false)
	await frames(2)
	check(not Pad.using_pad() and eye._hint.shown_text() == eye.PLANE_HINT and FirstSteps.line("look") == FirstSteps.VERBS.look.line,"A key again: back to the keys' words")
	check(await until(func() -> bool: return str(scene.creation_palette.get("_reach_hint")) == reach.VOID_HINT),"And the hand's hint line with them")
	reach._show_hint("")
	eye._hint.text = eye._walk_hint()
	# A small push of a stick is not the pad picked up.
	axis(JOY_AXIS_LEFT_X,0.2)
	axis(JOY_AXIS_LEFT_X,0.0)
	check(not Pad.using_pad(),"A brush of the stick under its notice leaves the keys in hand")

func _building() -> void:
	check(pad.context() == "world","Building: the pad is in the world")
	var materials: Node = scene.hand_reach.materials
	# The cursor.
	var start: Vector2 = land_middle()+Vector2(-200,0)
	pad._move_to(start)
	axis(JOY_AXIS_LEFT_X,1.0)
	await seconds(0.4)
	axis(JOY_AXIS_LEFT_X,0.0)
	await frames(2)
	check(pad.cursor.x > start.x+60.0 and absf(pad.cursor.y-start.y) < 1.0,"The left stick moves the cursor right (%.0f px)" % (pad.cursor.x-start.x))
	check(scene.get_viewport().get_mouse_position().distance_to(pad.cursor) < 1.0,"And the pointer with it")
	check(Pad.using_pad(),"The stick pushed: the pad is in hand")
	# Tools on the shoulders, size on the D-pad, mode on Y.
	materials.select_tool("hand")
	await tap(JOY_BUTTON_RIGHT_SHOULDER)
	var next: String = materials.roll.tool
	check(next != "hand" and next == "hills","RB takes the next tool on the roll (%s)" % next)
	await tap(JOY_BUTTON_LEFT_SHOULDER)
	check(materials.roll.tool == "hand","LB steps back to the Modeller")
	materials.set_size(1)
	await tap(JOY_BUTTON_DPAD_UP)
	check(materials.roll.size_level == 2,"D-pad up sizes up")
	await tap(JOY_BUTTON_DPAD_DOWN)
	await tap(JOY_BUTTON_DPAD_DOWN)
	check(materials.roll.size_level == 0,"D-pad down sizes down")
	materials.set_size(1)
	var mode: String = materials.roll.mode
	await tap(JOY_BUTTON_Y)
	check(materials.roll.mode != mode and not materials.roll.mode.is_empty(),"Y steps the tool's mode (%s to %s)" % [mode,materials.roll.mode])
	# The case on the D-pad, A taps a tree in, B puts it down, B held undoes.
	await tap(JOY_BUTTON_DPAD_RIGHT)
	check(materials.held == "oak","D-pad right takes the first seed from the case (%s)" % materials.held)
	await tap(JOY_BUTTON_DPAD_RIGHT)
	check(materials.held == "pine","Again, the next")
	await tap(JOY_BUTTON_DPAD_LEFT)
	var objects: int = scene._chunk_editor.data.objects.size()
	pad._move_to(land_middle())
	await frames(3)
	await tap(JOY_BUTTON_A)
	await seconds(0.5)
	var planted: int = scene._chunk_editor.data.objects.size()
	check(planted > objects,"A taps a tree into the land (%d to %d)" % [objects,planted])
	await tap(JOY_BUTTON_B)
	check(materials.held.is_empty(),"B puts the seed back")
	button(JOY_BUTTON_B,true)
	await seconds(0.7)
	button(JOY_BUTTON_B,false)
	await frames(10)
	check(scene._chunk_editor.data.objects.size() == objects,"B held undoes it (%d)" % scene._chunk_editor.data.objects.size())
	await tap(JOY_BUTTON_B)
	check(materials.roll.tool == materials.FREE,"B with a tool in hand puts it down")
	await tap(JOY_BUTTON_B)
	check(materials.roll.tool == materials.FREE and scene._chunk_editor.data.objects.size() == objects,"B with nothing in hand does nothing")
	# The camera.
	var rig: Node = scene.camera_rig
	await seconds(0.3)
	var resting: Vector2 = pad.cursor
	var yaw: float = rig._view_goal.x
	axis(JOY_AXIS_RIGHT_X,1.0)
	await seconds(0.4)
	axis(JOY_AXIS_RIGHT_X,0.0)
	check(absf(rig._view_goal.x-yaw) > 0.2,"The right stick orbits (%.2f rad)" % absf(rig._view_goal.x-yaw))
	await seconds(0.8)
	check(pad.cursor.distance_to(resting) > 2.0 and pad._anchor != null,"The resting cursor keeps to its land point as the view turns (%.0f px)" % pad.cursor.distance_to(resting))
	resting = pad.cursor
	var distance: float = rig._view_goal.z
	axis(JOY_AXIS_TRIGGER_RIGHT,1.0)
	await seconds(0.4)
	axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
	check(rig._view_goal.z < distance-0.1,"The right trigger zooms in")
	await seconds(1.0)
	check(pad.cursor.distance_to(resting) < 40.0,"Zooming draws in toward the cursor, which stays near where it was (%.0f px)" % pad.cursor.distance_to(resting))
	axis(JOY_AXIS_TRIGGER_LEFT,1.0)
	await seconds(0.4)
	axis(JOY_AXIS_TRIGGER_LEFT,0.0)
	await seconds(0.5)

## Build, walk, fly, land, walk, build.
func _modes() -> void:
	pad._move_to(land_middle())
	await frames(3)
	await tap(JOY_BUTTON_BACK)
	await frames(5)
	check(eye.active and not eye.flying and pad.context() == "eye","View steps into the eyes where the cursor is")
	var feet: Vector3 = eye._feet
	axis(JOY_AXIS_LEFT_Y,-1.0)
	await seconds(0.6)
	axis(JOY_AXIS_LEFT_Y,0.0)
	check(Vector2(eye._feet.x-feet.x,eye._feet.z-feet.z).length() > 0.3,"The left stick walks (%.2f m)" % Vector2(eye._feet.x-feet.x,eye._feet.z-feet.z).length())
	var yaw: float = eye._yaw
	axis(JOY_AXIS_RIGHT_X,1.0)
	await seconds(0.3)
	axis(JOY_AXIS_RIGHT_X,0.0)
	check(absf(eye._yaw-yaw) > 0.2,"The right stick looks round")
	button(JOY_BUTTON_A,true)
	await frames(3)
	button(JOY_BUTTON_A,false)
	await frames(2)
	button(JOY_BUTTON_A,true)
	await frames(3)
	button(JOY_BUTTON_A,false)
	await frames(3)
	check(eye.flying,"A again on the way up the jump: flying")
	await seconds(1.5)
	await tap(JOY_BUTTON_Y)
	check(eye._landing_wait or eye.landing != null,"Y: it comes in to land")
	var began := Time.get_ticks_msec()
	while eye.flying and Time.get_ticks_msec()-began < 60000: await process_frame
	check(eye.active and not eye.flying,"Down and walking beside the plane")
	await seconds(1.2)
	await tap(JOY_BUTTON_B)
	await frames(3)
	check(not eye.active and pad.context() == "world","B steps back out to building")
	await seconds(1.0)

func _pause() -> void:
	await tap(JOY_BUTTON_START)
	await frames(3)
	var panel: Control = scene.pause_panel
	check(panel.is_open and pad.context() == "pause","Menu pauses")
	check(scene.get_viewport().gui_get_focus_owner() == panel.resume_row,"Resume has the focus")
	await tap(JOY_BUTTON_DPAD_DOWN)
	check(scene.get_viewport().gui_get_focus_owner() == panel.copy_row,"D-pad down steps to the next row")
	await tap(JOY_BUTTON_DPAD_RIGHT)
	check(scene.get_viewport().gui_get_focus_owner() == panel.copy_row,"Left and right go nowhere behind the panel")
	await tap(JOY_BUTTON_A)
	check(panel.copy_open,"A presses it: the copy well opens")
	await tap(JOY_BUTTON_B)
	check(not panel.copy_open and panel.is_open,"B folds the well")
	if panel.notes_row.visible:
		panel.notes_row.grab_focus()
		await tap(JOY_BUTTON_A)
		check(scene.field_notes.is_open and pad.context() == "notes","A on Field notes opens them")
		await tap(JOY_BUTTON_B)
		await frames(4)
		check(not scene.field_notes.is_open and panel.is_open,"B comes back to the pause panel")
	await tap(JOY_BUTTON_B)
	await frames(3)
	check(not panel.is_open and not scene._menu.visible and pad.context() == "world","B again resumes")
	await seconds(0.5)

func _photo_and_watch() -> void:
	await tap(JOY_BUTTON_LEFT_STICK)
	await frames(3)
	var photo: Node = scene.photo
	check(photo.active and pad.context() == "photo","L3 opens photo mode")
	var yaw: float = photo._goal.yaw
	axis(JOY_AXIS_RIGHT_X,1.0)
	await seconds(0.3)
	axis(JOY_AXIS_RIGHT_X,0.0)
	check(absf(photo._goal.yaw-yaw) > 0.1,"The right stick turns the shot")
	await tap(JOY_BUTTON_X)
	check(photo.ground,"X is the ground eye")
	await tap(JOY_BUTTON_X)
	await tap(JOY_BUTTON_B)
	await frames(3)
	check(not photo.active and pad.context() == "world","B leaves photo mode")
	await seconds(1.0)
	button(JOY_BUTTON_BACK,true)
	await seconds(0.7)
	button(JOY_BUTTON_BACK,false)
	await frames(3)
	check(scene.watch.active and not eye.active,"View held: watch mode, not the eyes")
	await tap(JOY_BUTTON_A)
	await frames(3)
	check(not scene.watch.active,"Any button comes back")
	await seconds(1.0)

func _keys_and_mouse() -> void:
	var materials: Node = scene.hand_reach.materials
	# The mouse takes the cursor back, and V steps in under it.
	var echo: Vector2 = pad.cursor
	mouse_to(echo)
	await frames(2)
	check(Pad.using_pad(),"The system's echo of the warped pointer is not the mouse picked up")
	var by_hand := land_middle()+Vector2(6,4)
	mouse_to(by_hand)
	await frames(2)
	check(not Pad.using_pad() and pad.cursor.distance_to(by_hand) < 1.0,"A moved mouse puts the cursor where it is")
	key(KEY_V)
	key(KEY_V,false)
	await frames(3)
	check(eye.active,"V steps into the eyes")
	var feet: Vector3 = eye._feet
	key(KEY_W)
	await seconds(0.5)
	key(KEY_W,false)
	check(Vector2(eye._feet.x-feet.x,eye._feet.z-feet.z).length() > 0.3,"W walks")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE,false)
	await frames(3)
	check(not eye.active,"Esc steps out")
	await seconds(1.0)
	# The wheel zooms.
	var distance: float = scene.camera_rig._view_goal.z
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.factor = 1.0
	wheel.position = land_middle()
	wheel.global_position = wheel.position
	Input.parse_input_event(wheel)
	Input.flush_buffered_events()
	await frames(2)
	check(scene.camera_rig._view_goal.z < distance,"The wheel zooms")
	# Q steps the mode, Esc puts the tool down.
	materials.select_tool("hand")
	var mode: String = materials.roll.mode
	key(KEY_E)
	key(KEY_E,false)
	await frames(2)
	check(materials.roll.mode != mode,"E steps the mode")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE,false)
	await frames(2)
	check(materials.roll.tool == materials.FREE and not scene._menu.visible,"Esc puts the tool down")
	# A mouse click on the land with a seed in hand still plants.
	materials.take("oak")
	var objects: int = scene._chunk_editor.data.objects.size()
	var at := land_middle()+Vector2(40,20)
	mouse_to(at)
	for down: bool in [true,false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		click.position = at
		click.global_position = at
		Input.parse_input_event(click)
		Input.flush_buffered_events()
		await frames(2)
	check(await until(func() -> bool: return scene._chunk_editor.data.objects.size() > objects),"A click plants a tree")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE,false)
	await frames(2)
	check(materials.held.is_empty(),"Esc puts the seed back")
