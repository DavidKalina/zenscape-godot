extends SceneTree
## The command palette (scripts/command_palette.gd) in the product scene,
## headless: Cmd K opens it, typing filters, Tab changes pocket, Enter takes
## a redwood seed, a mood (Rose dusk) and a world verb, Life summons Bigfoot
## and a snake (or says what it needs), Esc and a press outside close it.
## Headless draws nothing; the look has to be judged on screen.
##   Godot --headless --fixed-fps 60 --path . -s res://tools/probe_command_palette.gd -- --no-title

var scene: Node3D
var palette: Control
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ")+what)
	if not ok: failures += 1

func frames(n: int) -> void:
	for i in range(n): await process_frame

func key(code: Key, command := false, shift := false, unicode := 0) -> bool:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.meta_pressed = command
	event.shift_pressed = shift
	event.unicode = unicode
	return palette.handle_event(event)

func type(text: String) -> void:
	for c in text: key(KEY_NONE,false,false,c.unicode_at(0))

func run() -> void:
	create_timer(300).timeout.connect(func() -> void: push_error("Command palette probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-palette-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(0.5).timeout
	var materials: Node = scene.hand_reach.materials
	palette = materials.palette
	check(palette != null,"the palette is on the HUD layer")
	if palette == null: quit(1); return

	var foot: Control = materials.foot
	check(foot.press(foot.slot_centre("palette")) and palette.is_open(),"the foot's Lens opens it")
	key(KEY_ESCAPE)
	await frames(15)
	check(key(KEY_K,true) and palette.is_open(),"Cmd K opens it")
	await frames(20)
	var rect: Rect2 = palette.panel_rect()
	print("Panel %s at %.2f px per design px" % [rect,palette.ui_scale])
	var counts := {}
	for pair: Array in palette.listed(): counts[pair[0]] = int(counts.get(pair[0],0))+1
	print("Listed: %s" % counts)
	check(counts.get("seed",0) == 10 and counts.get("tool",0) == 7 and counts.get("element",0) == 4,"seeds, tools, elements all listed")
	check(counts.get("mood",0) >= 19,"every mood and This world listed (%d)" % counts.get("mood",0))
	check(counts.get("life",0) == 10 and counts.get("world",0) == 8,"life and world listed")

	type("redw")
	check(palette.listed() == [["seed","redwood"]],"typing 'redw' finds the redwood: %s" % [palette.listed()])
	key(KEY_ENTER)
	check(not palette.is_open() and materials.held == "redwood","Enter takes the redwood seed in hand (held '%s')" % materials.held)
	materials.put_back()

	key(KEY_SLASH)
	check(palette.is_open(),"/ opens it")
	for i in range(5): key(KEY_TAB)
	check(palette.tab == 5 and palette.listed()[0] == ["mood",""],"Tab five times is the Moods pocket")
	type("rose")
	print("  rose: %s" % [palette.listed()])
	check(["mood","rose_dusk"] in palette.listed(),"Rose dusk is in the Moods pocket")
	while palette.listed()[palette.sel] != ["mood","rose_dusk"]: key(KEY_DOWN)
	key(KEY_ENTER)
	await frames(2)
	check(scene.mood_look.mood == "rose_dusk","Enter chooses Rose dusk (mood '%s')" % scene.mood_look.mood)
	while scene.mood_look.fading(): await process_frame
	print("  sky now %s, phase %.3f" % [scene._celestial.look.colors.sky,scene._celestial.phase])

	key(KEY_K,true)
	key(KEY_TAB,false,true)
	check(palette.tab == 6,"Shift Tab from All is World")
	var running: bool = scene.world_clock.running
	type("still")
	key(KEY_ENTER)
	check(scene.world_clock.running != running,"Still time toggles the clock")
	scene.world_clock.running = running

	for kind: String in ["bigfoot_watch","snake","deer"]:
		key(KEY_K,true)
		palette.tab = 4
		palette._refresh()
		var at := -1
		for i in range(palette.listed().size()):
			if palette.listed()[i] == ["life",kind]: at = i
		palette.sel = at
		key(KEY_ENTER)
		var said: String = palette.last_refusal if palette.is_open() else ""
		print("  %s: %s" % [kind,"came" if said.is_empty() else "refused: "+said])
		if kind == "bigfoot_watch": check(said.is_empty() and scene.land_life.moments.bigfoot.showing(),"Bigfoot comes when called")
		if palette.is_open(): key(KEY_ESCAPE)
		palette.last_refusal = ""

	key(KEY_K,true)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(20,880)
	palette.handle_event(press)
	check(not palette.is_open(),"a press outside puts it away")

	print("%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
