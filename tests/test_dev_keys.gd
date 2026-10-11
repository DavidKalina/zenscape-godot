extends SceneTree
## The study's developer keys and capture flags, off in a release build and
## on in debug and dev runs (scripts/kit_isle/dev_keys.gd, studies/
## zenscape.gd; docs/design/consolidation-audit.md, round 2), headless:
##   - the gate: on in this debug run; judged as a release export, off, unless
##     the project setting zenscape/dev/dev_keys or --dev-keys says on;
##     --no-dev-keys is off anywhere;
##   - as a release build the capture flags leave the flags in force before
##     the isle reads them (the game starts, takes no capture, doesn't quit),
##     and the others (--no-title, --verify-desktop-build) stay;
##   - as a release build, on foot, L, F1, F2 and a station key do nothing;
##     in the plane R and F1 do nothing (the plane flies on);
##   - in a debug run L steps the look preset and F1 shows the numbers.
##   godot --headless --path . --script tests/test_dev_keys.gd
const LaunchArgs = preload("res://scripts/launch_args.gd")
const DevKeys = preload("res://scripts/kit_isle/dev_keys.gd")
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

func key(code: Key, shift := false) -> void:
	for down: bool in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.shift_pressed = shift
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(2)

func run() -> void:
	create_timer(300).timeout.connect(func() -> void: print("FAIL: timed out"); quit(2))
	root.size = Vector2i(1440,900)
	# The gate.
	LaunchArgs.set_override(PackedStringArray())
	check(DevKeys.enabled(),"On in a debug run")
	DevKeys.as_release = true
	check(not DevKeys.enabled(),"Off judged as a release export")
	ProjectSettings.set_setting(DevKeys.SETTING,true)
	check(DevKeys.enabled(),"...on there if the project setting says so")
	ProjectSettings.set_setting(DevKeys.SETTING,null)
	LaunchArgs.set_override(PackedStringArray(["--dev-keys"]))
	check(DevKeys.enabled(),"...on there with --dev-keys")
	DevKeys.as_release = false
	LaunchArgs.set_override(PackedStringArray(["--no-dev-keys"]))
	check(not DevKeys.enabled(),"--no-dev-keys is off anywhere")
	var keyed := InputEventKey.new()
	keyed.pressed = true
	for code: Key in [KEY_L,KEY_B,KEY_F1,KEY_F2]:
		keyed.keycode = code
		check(DevKeys.is_dev_event(keyed,false),"%s is a developer key on foot" % OS.get_keycode_string(code))
	keyed.keycode = KEY_R
	check(DevKeys.is_dev_event(keyed,true) and not DevKeys.is_dev_event(keyed,false),"R is one in the plane, not on foot (there it's Back to the plane)")
	for code: Key in [KEY_SPACE,KEY_E,KEY_F,KEY_ESCAPE,KEY_TAB,KEY_Q,KEY_X]:
		keyed.keycode = code
		check(not DevKeys.is_dev_event(keyed,false) and not DevKeys.is_dev_event(keyed,true),"%s is the player's" % OS.get_keycode_string(code))
	# A release build: the capture flags go before the isle reads them.
	DevKeys.as_release = true
	LaunchArgs.set_override(PackedStringArray(["--no-title","--capture=user://never.png","--at=0,40,0","--capture-wait=1","--verify-desktop-build-not"]))
	change_scene_to_file(FRONT_DOOR)
	check(await until(func() -> bool: return current_scene != null and current_scene.scene_file_path == FRONT_DOOR,10.0),"The game opens as a release build")
	var game: Node3D = current_scene
	var args := LaunchArgs.user_args()
	check(not args.has("--capture=user://never.png") and not args.has("--at=0,40,0") and not args.has("--capture-wait=1"),"The capture flags are gone from the flags in force")
	check(args.has("--no-title") and args.has("--verify-desktop-build-not"),"...the others stay")
	check(await until(func() -> bool: return game.isle_up and game.walk_ready,180.0),"The isle comes up")
	check(game._capture.is_empty(),"No capture is taken")
	await frames(30)
	check(is_instance_valid(game) and current_scene == game and not FileAccess.file_exists("user://never.png"),"The game runs on")
	# On foot.
	var look: String = game.look_id
	await key(KEY_L)
	await key(KEY_L,true)
	check(game.look_id == look,"L and Shift+L leave the look as it is")
	var hud: bool = game._hud.visible
	await key(KEY_F1)
	check(game._hud.visible == hud,"F1 shows no numbers")
	await key(KEY_F2)
	check(not game._tune.visible,"F2 opens no feel panel")
	var feet: Vector3 = game.motor.feet
	await key(KEY_1)
	await key(KEY_0)
	check(game.motor.feet.distance_to(feet) < 0.01,"The station keys move him nowhere")
	# In the plane.
	game.board()
	await frames(4)
	check(game.flying,"In the plane")
	await key(KEY_R)
	await key(KEY_F1)
	check(game.flying and game._hud.visible == hud,"In the plane R and F1 do nothing")
	# A debug run.
	DevKeys.as_release = false
	LaunchArgs.set_override(PackedStringArray(["--no-title"]))
	game.leave_plane()
	await frames(4)
	await key(KEY_L)
	check(game.look_id != look,"In a debug run L steps the look preset (%s to %s)" % [look,game.look_id])
	await key(KEY_F1)
	check(game._hud.visible != hud,"...and F1 shows the numbers")
	LaunchArgs.set_override(null)
	print("dev keys: %d failures" % failures)
	quit(1 if failures else 0)
