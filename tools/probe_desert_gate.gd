extends SceneTree
## The desert held back for an update (scripts/desert_landscape.gd `on`):
## with it off, no title pick is arid, the New world screen has no canyon,
## generated worlds draw no desert composition, the tray and palette have no
## Joshua seed and the mood drawers have no Desert afternoon. With --desert
## they all come back. Saves are untouched: canyon still forms as a land.
## godot --headless --path . --script res://tools/probe_desert_gate.gd
## godot --headless --path . --script res://tools/probe_desert_gate.gd -- --desert

const Desert = preload("res://scripts/desert_landscape.gd")
const Showcase = preload("res://scripts/title_showcase.gd")
const Lands = preload("res://scripts/world_lands.gd")
const Library = preload("res://scripts/world_library.gd")
const Generator = preload("res://scripts/cozy_world_generator.gd")
const Tray = preload("res://scripts/materials_tray.gd")
const Palette = preload("res://scripts/command_palette.gd")
const Mood = preload("res://scripts/mood_look.gd")
const NewWorldPanel = preload("res://scripts/new_world_panel.gd")
const TITLE_PICKS := 2000
const GENERATED := 60
var failures := 0

func check(ok: bool, what: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+what)
	if not ok: failures += 1

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var on: bool = Desert.on
	print("desert ",("on (--desert)" if on else "held back"))
	check(on == ("--desert" in OS.get_cmdline_user_args()),"--desert alone turns the desert on (ENABLED is false)")
	check(not Desert.ENABLED,"ENABLED is false for launch")

	# The title.
	var arid := 0
	var families := {}
	for seed_value in range(TITLE_PICKS):
		var choice: Dictionary = Showcase.choose(seed_value*7919+13)
		families[choice.family] = true
		if choice.biome == "arid" or str(choice.overrides.get("palette","")) == "Desert": arid += 1
	check((arid > 0) == on,"title: %d of %d picks arid" % [arid,TITLE_PICKS])
	check(families.has("canyon") == on and families.has("monuments") == on,"title: canyon and monuments families %s" % ("reached" if on else "never shown"))

	# The New world screen.
	check(("canyon" in Lands.offered()) == on,"lands offered: %s" % str(Lands.offered()))
	check(Library.lands().any(func(entry: Dictionary) -> bool: return entry.id == "canyon") == on,"library lands: Red canyon %s" % ("listed" if on else "absent"))
	check("canyon" in Lands.IDS and Library.land_name("canyon") == "Red canyon","canyon stays a land that forms and names its saved worlds")
	var panel := NewWorldPanel.new()
	root.add_child(panel)
	panel.open(7)
	var row_lands: Array = panel.rows.map(func(row) -> String: return str(row.land.id))
	check(("canyon" in row_lands) == on,"New world rows: %s" % str(row_lands))
	panel.queue_free()

	# The generator.
	var desert_worlds := 0
	var compositions := {}
	var previous := {}
	for i in range(GENERATED):
		var world: Dictionary = Generator.sample(i*104729+5,previous)
		compositions[world.terrain.composition] = true
		if world.terrain.composition in Desert.KINDS: desert_worlds += 1
		previous = world.terrain
	check((desert_worlds > 0) == on,"generator: %d of %d worlds desert (%s)" % [desert_worlds,GENERATED,str(compositions.keys())])

	# The tray and the palette.
	var tray_ids: Array = Tray.SPECIMENS.map(func(entry: Dictionary) -> String: return entry.id)
	check(("joshua" in tray_ids) == on,"tray: Joshua %s (%d slots)" % [("on the bar" if on else "absent"),tray_ids.size()])
	check(tray_ids.size() == Tray.ALL_SPECIMENS.size()-(0 if on else 1),"tray: only Joshua is held back")
	check("juniper" in tray_ids,"tray: juniper stays")
	var palette := Palette.new()
	palette._build_items()
	var seeds: Array = palette._items.filter(func(item: Dictionary) -> bool: return item.kind == "seed").map(func(item: Dictionary) -> String: return item.id)
	check(("joshua" in seeds) == on and "juniper" in seeds,"palette seeds: %s" % str(seeds))
	var moods: Array = palette._items.filter(func(item: Dictionary) -> bool: return item.kind == "mood").map(func(item: Dictionary) -> String: return item.id)
	check(("desert_afternoon" in moods) == on,"palette moods: Desert afternoon %s" % ("offered" if on else "absent"))
	palette.free()
	check(("desert_afternoon" in Mood.mood_ids()) == on and Mood.mood_title("desert_afternoon") == "Desert afternoon","mood drawers: Desert afternoon %s; a saved one keeps its name" % ("offered" if on else "absent"))

	print("DESERT GATE (%s): failures=%d" % [("on" if on else "off"),failures])
	quit(1 if failures else 0)
