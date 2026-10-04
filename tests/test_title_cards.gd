extends SceneTree
## The title as cards (scripts/title_cards.gd, scripts/menu_card.gd): the
## design's fans and their resting places, dealing, hover lift and lean,
## tilt and sheen, picks and their actions, keys, world select's focus and
## words, and each world's card (scripts/world_card.gd). Headless: nothing
## is drawn, so the faces and shaders are not checked.
const Library = preload("res://scripts/world_library.gd")
const TitleCards = preload("res://scripts/title_cards.gd")
const WorldCard = preload("res://scripts/world_card.gd")
const Style = preload("res://scripts/worlds_style.gd")
var failures := 0
var picks: Array = []
var entered: Array = []
var selections: Array = []
var news := 0
var backs := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: "+message)

func near(a: float, b: float, tolerance := 0.6) -> bool:
	return absf(a-b) <= tolerance

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)

func frames(n: int) -> void:
	for i in n: await process_frame

func run() -> void:
	root.size = Vector2i(1440,810)
	var path := "user://test-title-cards-%d" % Time.get_ticks_usec()
	var library := Library.new(path)
	var first := library.create("Juniper Steps","alpine_meadow","pine-basalt-5108",1000.0)
	var second := library.create("Lantern Mesa","canyon","amber-cinder-7702",2000.0)
	library.touch(second.id,2000.0,{"pal":{"sky":"8a7c9c","glow":"e2a462","land":"b0703c","sun":"f2c79a"},
		"mood":"Autumn · Dusk · Clear","els":[{"k":"crystal","n":22},{"k":"pine","n":4},{"k":"water","n":2}]})
	var newest := library.create("The quiet plain","plain","fern-dusk-2210",3000.0)
	check(library.number(first.id) == 1 and library.number(newest.id) == 3, "Worlds are numbered in the order they were made")

	# A world's card: its summary, or its land's.
	var mesa := WorldCard.of(library.find(second.id))
	check(mesa.hero == "crystal" and mesa.mood == "Autumn · Dusk · Clear", "A kept summary sets the hero glyph and mood: %s" % [mesa])
	check(mesa.pal.sky == Color("8a7c9c"), "A kept summary sets the palette")
	var steps := WorldCard.of(library.find(first.id))
	check(steps.hero == "pine" and steps.mood == "" and steps.pal.land == Color(WorldCard.LAND_PALETTES.alpine_meadow.land), "A world with no summary takes its land's glyph and palette")
	check(WorldCard.hero([{"k":"globe","n":0},{"k":"reed","n":3}],"oak") == "reed", "A sky glyph is never the hero")
	check(WorldCard.elements({"oak":3,"water":7,"reed":3,"stone":1,"lamp":2}).map(func(e: Dictionary) -> String: return e.k) == ["water","oak","reed","lamp"], "Elements: most placed first, four kept")
	check(WorldCard.mood_short("Summer · Golden hour · Clear") == "Summer · Golden hour", "The card's foot keeps two parts of the mood")
	check(WorldCard.roman(4) == "IV" and WorldCard.roman(14) == "14", "Numerals")

	var title := TitleCards.new()
	title.now = 3000.0+120.0
	root.add_child(title)
	title.setup(library)
	title.picked.connect(func(action: String) -> void: picks.append(action))
	title.enter_requested.connect(func(world: Dictionary) -> void: entered.append(world))
	title.selection_changed.connect(func(world: Dictionary) -> void: selections.append(world))
	title.new_world_requested.connect(func() -> void: news += 1)
	title.back_requested.connect(func() -> void: backs += 1)
	title.show_menu()
	# Dealt: sunk, rising in turn.
	check(title.menu_cards[4].sk > title.menu_cards[0].sk and title.menu_cards[0].sk > 2.0, "Cards are dealt sunk, the last deepest")
	await frames(2)

	# The menu: five cards on the design's arc.
	check(title.items.map(func(item: Dictionary) -> String: return item.label) == ["Continue","Your worlds","A new world","Almanac","Rest"], "Five picks")
	check(title.items[0].line == "Back to The quiet plain", "Continue names the most recent world: "+str(title.items[0].line))
	check(title.menu_cards.size() == 5 and title.menu_cards[1].deck and not title.menu_cards[0].deck, "Your worlds sits on a deck")
	check(near(title.px,1.0,0.001), "1440x810 is the design frame")
	# Design: left = 720 + d·188 − 120·.72, top = 606 + d²·6 − 168·.72.
	for i in 5:
		var d := i-2
		var card: Control = title.menu_cards[i]
		check(near(card.position.x,720.0+d*188.0-86.4) and near(card.position.y,606.0+d*d*6.0-120.96), "Menu card %d rests where the design puts it: %s" % [i,card.position])
		check(near(card.size.x,172.8) and near(card.size.y,241.92), "Menu cards are 240x336 at .72")
	check(title.hint.text == Style.caps("hover or ◂ ▸ · ↵ to choose"), "The menu's hint")
	check(title.menu_mark.visible and not title.worlds_head.visible and not title.info.visible, "The menu shows the wordmark, not world select's words")
	await create_timer(2.5).timeout
	check(title.menu_cards.all(func(card: Control) -> bool: return absf(card.sk) < 0.05), "Dealt cards rise to rest")

	# Hover: the card lifts and tilts toward the pointer, neighbours lean away.
	var middle: Control = title.menu_cards[2]
	middle.hovered.emit(middle)
	middle.pointed.emit(middle,Vector2(0.8,-0.5))
	await create_timer(1.2).timeout
	check(title.hovered.menu == 2, "The card under the pointer is hovered")
	check(near(middle.l,1.0,0.05), "The hovered card lifts: %f" % middle.l)
	check(near(title.menu_cards[1].n,-26.0,1.0) and near(title.menu_cards[3].n,26.0,1.0), "Its neighbours lean away 26: %f %f" % [title.menu_cards[1].n,title.menu_cards[3].n])
	check(near(title.menu_cards[0].n,-10.0,1.0) and near(title.menu_cards[4].n,10.0,1.0), "The next ones lean 10")
	check(near(middle.sx,0.8,0.05) and near(middle.sy,-0.5,0.05), "The tilt follows the pointer")
	middle.unhovered.emit(middle)
	await create_timer(1.2).timeout
	check(title.hovered.menu == -1 and near(middle.l,0.0,0.05) and near(title.menu_cards[1].n,0.0,1.0), "Leaving lets it settle")

	# Keys: from none, the middle; Enter picks.
	key(KEY_RIGHT)
	check(title.hovered.menu == 2, "◂ ▸ start in the middle")
	key(KEY_RIGHT)
	check(title.hovered.menu == 3, "▸ moves along")
	key(KEY_ENTER)
	await frames(1)
	check(title.chosen.menu == 3 and title.hint.text == Style.caps("Opening · Almanac"), "↵ picks the hovered card: "+title.hint.text)
	await create_timer(0.3).timeout
	check(title.menu_cards[3].l > 1.0 and title.menu_cards[0].sk > 0.5, "The pick rises, the rest sink")
	await create_timer(0.5).timeout
	check(picks == ["settings"], "Almanac asks for settings after the draw: %s" % [picks])
	await create_timer(1.3).timeout
	check(title.chosen.menu == -1, "A settings pick settles back")

	# Your worlds: world select, the most recent world in focus.
	title.choose(1)
	await create_timer(0.8).timeout
	check(picks.back() == "worlds", "Your worlds asks for world select")
	title.show_worlds()
	await frames(2)
	check(title.view == "worlds" and title.world_cards.size() == 4, "Three worlds and the blank card")
	check(title.worlds_head.visible and title.info.visible and not title.menu_mark.visible, "World select shows its words")
	check(title.focus == 0 and selections.size() == 1 and selections[0].id == newest.id, "The most recent world is in focus and announced")
	check(title.count_label.text == "Your worlds · 1 of 3", "Count: "+title.count_label.text)
	check(title.kicker.text == Style.caps("No. 03 · Played 2 minutes ago"), "Kicker: "+title.kicker.text)
	check(title.name_label.text == "The quiet plain" and title.line_label.text == "Quiet plain · seed fern-dusk-2210", "Words: "+title.line_label.text)
	check(title.world_cards[1].spec.label == "Lantern Mesa" and title.world_cards[1].spec.sub == "Autumn · Dusk" and title.world_cards[1].spec.roman == "II", "A world's card: %s" % [title.world_cards[1].spec])
	check(title.world_cards[3].spec.kind == "blank", "The blank card ends the deck")
	for i in 4:
		var d := i-1.5
		var card: Control = title.world_cards[i]
		check(near(card.position.x,720.0+d*166.0-74.4) and near(card.position.y,640.0+d*d*5.0-104.16), "World card %d rests on the design's arc: %s" % [i,card.position])
	check(title.hint.text == Style.caps("◂ ▸ browse · ↵ enter · esc menu"), "World select's hint")
	# Hovering focuses; the blank card keeps the backdrop.
	title.world_cards[1].hovered.emit(title.world_cards[1])
	check(title.focus == 1 and selections.size() == 2 and selections[1].id == second.id, "Hovering a world focuses and announces it")
	check(title.line_label.text == "Autumn · Dusk · Clear · seed amber-cinder-7702", "Its mood and seed: "+title.line_label.text)
	title.world_cards[3].hovered.emit(title.world_cards[3])
	check(title.count_label.text == "A blank card" and title.name_label.text == "A new world" and selections.size() == 2, "The blank card shows its words, the backdrop stays")
	title.world_cards[3].unhovered.emit(title.world_cards[3])
	key(KEY_LEFT)
	check(title.hovered.worlds == 2 and title.focus == 2 and selections.back().id == first.id, "◂ moves from the focused card")
	key(KEY_ESCAPE)
	check(backs == 1, "Esc asks to go back")
	key(KEY_ENTER)
	await create_timer(0.8).timeout
	check(entered.size() == 1 and entered[0].id == first.id and title.hint.text == Style.caps("Entering · Juniper Steps"), "↵ enters the focused world")
	title.show_worlds(second.id)
	check(title.focus == 1 and title.chosen.worlds == -1, "World select reopens on a given world")
	title.choose(3)
	await create_timer(0.8).timeout
	check(news == 1, "The blank card asks for a new world")

	# A long deck closes up inside the sides.
	var spot: Dictionary = TitleCards.fan_spot("worlds",0,21,Vector2(1440,810))
	var last: Dictionary = TitleCards.fan_spot("worlds",20,21,Vector2(1440,810))
	check(spot.centre.x-0.62*120.0 >= TitleCards.SIDE-0.5 and last.centre.x+0.62*120.0 <= 1440.0-TitleCards.SIDE+0.5, "Twenty worlds fit inside the sides")
	check(last.centre.y-640.0 <= 45.5, "and drop no further than seven")

	# No worlds: nothing to continue.
	var empty := Library.new(path+"-empty")
	title.setup(empty)
	title.show_menu()
	check(title.items.size() == 4 and title.items[0].label == "Your worlds", "With no worlds there is no Continue")
	title.queue_free()
	print("Title cards: "+("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)
