extends SceneTree
## The game's pause and the way back to the plane (studies/zenscape.gd,
## scripts/kit_isle/pause_host.gd, pause_menu.gd, menu_sheet.gd;
## docs/design/consolidation-audit.md, round 2), headless, straight in
## (--no-title):
##   - Esc pauses the tree under the sheet, Resume in reach, its key "Esc";
##     the world stops (the pilot's feet don't move under a held stick);
##   - with the pad in hand the row's key is pad B and the hint line its pad
##     form; down and up step the rows;
##   - Settings opens the settings sheet, Esc comes back to the pause with
##     Settings in reach; Scenes opens the picker, Esc comes back;
##   - pad B resumes, the tree given back; the pad's Menu pauses and
##     resumes too;
##   - walked away, R stands him beside the parked plane, facing it; so does
##     the pause's Back to the plane; in the plane the row isn't offered
##     (R in the plane is a developer key: tests/test_dev_keys.gd);
##   - Back to the title opens the front door again on its title.
##   godot --headless --path . --script tests/test_game_pause.gd
const LaunchArgs = preload("res://scripts/launch_args.gd")
const Pad = preload("res://scripts/pad.gd")
const FRONT_DOOR := "res://studies/zenscape.tscn"
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func frames(n: int) -> void:
	for i in range(n): await process_frame

func until(condition: Callable, seconds := 60.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > deadline: return false
		await process_frame
	return true

func tap_pad(index: JoyButton) -> void:
	for down: bool in [true,false]:
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = index
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(3)

func key(code: Key) -> void:
	for down: bool in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(2)

func focused() -> Control:
	return root.gui_get_focus_owner()

func run() -> void:
	create_timer(400).timeout.connect(func() -> void: print("FAIL: timed out"); quit(2))
	root.size = Vector2i(1440,900)
	LaunchArgs.set_override(PackedStringArray(["--no-title"]))
	change_scene_to_file(FRONT_DOOR)
	check(await until(func() -> bool: return current_scene != null and current_scene.scene_file_path == FRONT_DOOR,10.0),"The game opens")
	var game: Node3D = current_scene
	check(await until(func() -> bool: return game.isle_up and game.walk_ready,180.0),"The isle comes up")
	await frames(4)
	var host: Node = game.pause
	var menu: Control = host.menu
	check(host != null and not host.is_open and not menu.visible,"Not paused to begin with")
	# Esc pauses.
	await key(KEY_ESCAPE)
	check(host.is_open and paused and menu.is_visible_in_tree(),"Esc pauses the game under the sheet")
	check(focused() == menu.resume_row,"Resume in reach")
	check(menu.heading.text == game.isle_name(),"The sheet names the isle")
	check(menu.plane_row.visible and menu.settings_row.visible and menu.title_row.visible and menu.quit_row.visible,"Back to the plane, Settings, Back to the title and Quit on it")
	Pad.set_pad(false)
	check(menu.resume_row.shown_key() == "Esc","With the keys, Resume's key reads Esc")
	var feet: Vector3 = game.motor.feet
	Input.action_press(&"move_forward")
	await frames(20)
	Input.action_release(&"move_forward")
	check(game.motor.feet.distance_to(feet) < 0.001,"Paused, the pilot doesn't move under a held stick")
	# The pad in hand.
	await tap_pad(JOY_BUTTON_DPAD_DOWN)
	check(Pad.using_pad(),"The pad is in hand")
	check(focused() == menu.plane_row,"Down steps to Back to the plane")
	check(menu.resume_row.shown_key() == "{B}" and menu.plane_row.shown_key() == "","With the pad, Resume's key is pad B; R isn't shown")
	check(menu.hint.shown_text() == menu.hint.text,"The hint line reads the same on both")
	await tap_pad(JOY_BUTTON_DPAD_UP)
	check(focused() == menu.resume_row,"Up steps back")
	# Settings and back.
	menu.settings_row.grab_focus()
	await tap_pad(JOY_BUTTON_A)
	var settings: Control = host.settings
	check(settings.is_visible_in_tree() and not menu.visible,"Settings opens its sheet in the pause's place")
	check(settings.hint.shown_text().contains("{B}"),"Its hint line names the pad's buttons")
	await tap_pad(JOY_BUTTON_B)
	check(not settings.visible and menu.visible and focused() == menu.settings_row and paused,"Pad B goes back to the pause, Settings in reach")
	# Scenes and back.
	if menu.scenes_row.visible:
		menu.scenes_row.grab_focus()
		await key(KEY_ENTER)
		check(host.picker != null and host.picker.is_visible_in_tree() and not menu.visible,"Scenes opens the picker")
		await key(KEY_ESCAPE)
		check(not host.picker.visible and menu.visible and focused() == menu.scenes_row,"Esc comes back to the pause, Scenes in reach")
	# Pad B resumes.
	await tap_pad(JOY_BUTTON_B)
	check(not host.is_open and not paused and not menu.visible,"Pad B resumes")
	await tap_pad(JOY_BUTTON_START)
	check(host.is_open and paused,"The pad's Menu pauses")
	await tap_pad(JOY_BUTTON_START)
	check(not host.is_open and not paused,"...and resumes")
	# Back to the plane: R.
	Pad.set_pad(false)
	check(game.parked and game.by_plane(),"He starts by the parked plane")
	var plane_at: Vector3 = game.parked_at
	var away: Vector3 = game.safe_ground(plane_at+Vector3(18.0,0.0,14.0))
	game.place(away,Vector2(0,-1))
	await frames(4)
	check(not game.by_plane(),"Walked away from it (%.1f m)" % Vector2(away.x-plane_at.x,away.z-plane_at.z).length())
	await key(KEY_R)
	check(game.by_plane() and game.parked_at == plane_at,"R stands him beside the parked plane, which hasn't moved")
	var to: Vector3 = (plane_at-game.motor.feet)*Vector3(1,0,1)
	var facing: Vector2 = Vector2(-sin(game.motor.facing),-cos(game.motor.facing))
	check(facing.dot(Vector2(to.x,to.z).normalized()) > 0.9,"...facing it")
	# Back to the plane: the pause's row.
	game.place(away,Vector2(0,-1))
	await frames(4)
	await key(KEY_ESCAPE)
	menu.plane_row.grab_focus()
	await key(KEY_ENTER)
	check(not host.is_open and not paused and game.by_plane(),"The pause's Back to the plane does the same, and gives the game back")
	# In the plane.
	game.board_parked()
	await frames(10)
	check(game.flying,"Boarded")
	await key(KEY_ESCAPE)
	check(host.is_open and not menu.plane_row.visible,"In the plane the pause offers no Back to the plane")
	await key(KEY_ESCAPE)
	check(not host.is_open,"Esc resumes")
	# Back to the title.
	await key(KEY_ESCAPE)
	var first := game.get_instance_id()
	host.title_scene = FRONT_DOOR
	menu.title_row.grab_focus()
	await key(KEY_ENTER)
	check(not paused,"Back to the title gives the tree back")
	check(await until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != first,10.0),"...and opens the front door again")
	game = current_scene
	check(not LaunchArgs.user_args().has("--no-title") and game.front_door.title_wanted,"...on its title")
	LaunchArgs.set_override(null)
	print("game pause: %d failures" % failures)
	quit(1 if failures else 0)
