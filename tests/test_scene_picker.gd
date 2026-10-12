extends SceneTree
## The scene picker (docs/design/scene-picker.md), headless:
##   - every entry of scripts/scene_catalog.gd has a unique id, a group, and a
##     scene that exists, loads as a PackedScene and whose root script loads;
##   - scripts/launch_args.gd: no override is the command line; an override is
##     what scenes read; opening a scene always adds --no-title; the title's
##     flags drop the ones that skip it;
##   - the picker card: a row per entry, the first in reach, the keys and the
##     pad walk its columns (never off the card), A picks, B goes back;
##   - opening an entry changes scene with its flags (the builder's own-title
##     entry without --no-title), and holding Esc there
##     (then letting go) goes back, with the override gone to the title's.
##   godot --headless --path . --script tests/test_scene_picker.gd
const Catalog = preload("res://scripts/scene_catalog.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const Picker = preload("res://scripts/scene_picker.gd")
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func frames(n: int) -> void:
	for i in range(n): await process_frame

func until(condition: Callable, seconds := 20.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > deadline: return false
		await process_frame
	return true

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap_key(code: Key) -> void:
	key(code,true)
	await frames(2)
	key(code,false)
	await frames(2)

func tap_pad(index: JoyButton) -> void:
	for down: bool in [true,false]:
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = index
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(2)

func run() -> void:
	create_timer(240).timeout.connect(func() -> void: print("FAIL: timed out"); quit(2))
	root.size = Vector2i(1440,900)
	# The catalogue.
	var ids := {}
	for entry: Dictionary in Catalog.ENTRIES:
		var id := str(entry.get("id",""))
		check(not id.is_empty() and not ids.has(id),"%s: a unique id" % id)
		ids[id] = true
		check(not str(entry.get("group","")).is_empty() and not str(entry.get("title","")).is_empty() and not str(entry.get("detail","")).is_empty(),"%s: group, title and detail" % id)
		check(entry.get("args") is Array,"%s: args are a list" % id)
		var path := str(entry.get("scene",""))
		check(path.begins_with("res://") and ResourceLoader.exists(path),"%s: %s exists" % [id,path])
		var packed: PackedScene = load(path)
		check(packed != null and packed.can_instantiate(),"%s: loads as a scene" % id)
		var state := packed.get_state() if packed != null else null
		var script: Script = null
		if state != null:
			for p in state.get_node_property_count(0):
				if state.get_node_property_name(0,p) == "script": script = state.get_node_property_value(0,p)
		check(script != null and script.can_instantiate(),"%s: its root script loads" % id)
	check(Catalog.groups() == PackedStringArray(["The game","Ruins","Flight greyboxes","On-foot greyboxes"]),"Four groups, the game first")
	check(not Catalog.find("aqueduct_isle").is_empty() and Catalog.find("nope").is_empty(),"find by id")
	check(Catalog.enabled(),"The picker is offered in this (debug) run")
	# The flags.
	LaunchArgs.set_override(null)
	check(LaunchArgs.user_args() == OS.get_cmdline_user_args() and not LaunchArgs.overridden(),"No override: the command line's flags")
	LaunchArgs.set_override(["--pack=sky","--no-title"])
	check(LaunchArgs.user_args() == PackedStringArray(["--pack=sky","--no-title"]),"An override is what scenes read")
	check(preload("res://scripts/cozy_regrowth.gd").launch_choice() == "plain","A scene's own flag read follows the override")
	LaunchArgs.set_override(["--resume"])
	check(preload("res://scripts/cozy_regrowth.gd").launch_choice() == "resume","...and changes with it")
	check(LaunchArgs.title_args(["--no-title","--resume","--seed","7","--wonders"]) == PackedStringArray(["--wonders"]),"The title's flags drop the ones that skip it")
	LaunchArgs.set_override(null)
	# The card.
	var picker: Control = Picker.new()
	root.add_child(picker)
	await frames(2)
	var picked: Array = []
	picker.picked.connect(func(entry: Dictionary) -> void: picked.append(entry.id))
	var closed := [0]
	picker.closed.connect(func() -> void: closed[0] += 1)
	picker.present()
	await frames(3)
	check(picker.rows.size() == Catalog.ENTRIES.size(),"A row per entry")
	var focus := func() -> Control: return root.gui_get_focus_owner()
	check(focus.call() == picker.rows[0],"The first row in reach")
	check(picker._detail.text.begins_with(str(Catalog.ENTRIES[0].detail)),"The row in reach says what it is")
	await tap_key(KEY_DOWN)
	check(focus.call() == picker.rows[1] and picker.entry_of[picker.rows[1]].group == "The game","Down: the next row of the column")
	await tap_key(KEY_RIGHT)
	check(picker.entry_of[focus.call()].group == "Ruins","Right: the next column")
	await tap_key(KEY_UP)
	await tap_key(KEY_UP)
	await tap_key(KEY_UP)
	check(picker.entry_of.has(focus.call()) and picker.entry_of[focus.call()].group == "Ruins","Up at the top stays on the card")
	await tap_pad(JOY_BUTTON_DPAD_RIGHT)
	await tap_pad(JOY_BUTTON_DPAD_RIGHT)
	await tap_pad(JOY_BUTTON_DPAD_RIGHT)
	check(picker.entry_of.has(focus.call()) and picker.entry_of[focus.call()].group == "On-foot greyboxes","The pad's D-pad walks to the last column, and no further")
	# One more than the column holds, however many greyboxes it lists.
	var column: int = picker.entry_of.values().filter(func(e: Dictionary) -> bool: return e.group == "On-foot greyboxes").size()
	for i in column+1: await tap_pad(JOY_BUTTON_DPAD_DOWN)
	check(focus.call() == picker.back_button,"Down past a column's last row is Back")
	await tap_pad(JOY_BUTTON_DPAD_UP)
	check(picker.entry_of.has(focus.call()),"Up from Back is a row again")
	var row: Button = focus.call()
	await tap_pad(JOY_BUTTON_A)
	check(picked == [picker.entry_of[row].id],"A picks the row in reach")
	await tap_key(KEY_ENTER)
	check(picked.size() == 2,"Return picks too")
	await tap_pad(JOY_BUTTON_B)
	check(closed[0] == 1 and not picker.visible,"B goes back")
	picker.present("flight_sky")
	await frames(2)
	check(picker.entry_of[focus.call()].id == "flight_sky","present() can start on an entry")
	await tap_key(KEY_ESCAPE)
	check(closed[0] == 2 and not picker.visible,"Esc goes back")
	picker.queue_free()
	await frames(2)
	# Opening an entry: the collectible gallery, light enough headless.
	var entry := Catalog.find("collectibles")
	check(Catalog.open(self,entry) == OK,"The entry opens")
	check(await until(func() -> bool: return current_scene != null and current_scene.scene_file_path == entry.scene),"The scene changes to it")
	check(LaunchArgs.user_args()[0] == "--no-title","It reads its flags with --no-title")
	var back: Node = root.get_node_or_null("SceneReturn")
	check(back != null and back.active,"The way back is on the root")
	check(back.title_scene == str(ProjectSettings.get_setting("application/run/main_scene")),"The way back goes to the main scene")
	# Back to a light scene here, not the title's world, to keep the run short.
	var main := "res://studies/character_study.tscn"
	back.title_scene = main
	await frames(10)
	key(KEY_ESCAPE,true)
	await frames(3)
	check(back.held > 0.0 and current_scene.scene_file_path == entry.scene,"Esc held fills the way back, the scene stays")
	check(await until(func() -> bool: return back.held >= back.HOLD,5.0),"Held for its second")
	await frames(5)
	check(current_scene.scene_file_path == entry.scene,"Still there until Esc is let go")
	key(KEY_ESCAPE,false)
	var returned := await until(func() -> bool: return current_scene != null and current_scene.scene_file_path == main,10.0)
	check(returned,"Holding Esc and letting go goes back")
	check(not back.active and LaunchArgs.user_args() == LaunchArgs.title_args() and not "--no-title" in LaunchArgs.user_args(),"On the title's flags, the way back off")
	# The builder's entry opens the old game on its own title: no --no-title.
	var builder := Catalog.find("builder")
	check(builder.get("own_title") == true and builder.scene == "res://studies/cozy_worlds.tscn" and builder.group == "The game","The Builder (old game) entry: the cozy worlds scene on its own title")
	check(LaunchArgs.open_scene(self,main,PackedStringArray(builder.args),true) == OK and not "--no-title" in LaunchArgs.user_args(),"An own-title entry opens without --no-title")
	await until(func() -> bool: return current_scene != null and current_scene.scene_file_path == main,10.0)
	LaunchArgs.set_override(null)
	current_scene.queue_free()
	await frames(10)
	print("scene picker: %d failures" % failures)
	quit(1 if failures else 0)
