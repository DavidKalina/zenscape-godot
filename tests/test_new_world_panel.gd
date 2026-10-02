extends SceneTree
## New world (scripts/new_world_panel.gd): land picks and rolls are previewed,
## a blank name begins blank, Enter begins and Escape goes back.
const NewWorldPanel = preload("res://scripts/new_world_panel.gd")
const Library = preload("res://scripts/world_library.gd")
var failures := 0
var lands: Array = []
var begun: Array = []
var backs := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1440,810)
	var panel := NewWorldPanel.new()
	root.add_child(panel)
	check(not panel.visible, "The panel starts closed")
	panel.land_changed.connect(func(land: String, seed_text: String) -> void: lands.append([land,seed_text]))
	panel.begin_requested.connect(func(world_name: String, land: String, seed_text: String) -> void: begun.append([world_name,land,seed_text]))
	panel.back_requested.connect(func() -> void: backs += 1)
	panel.open(7)
	var seed_text := panel.seed_text
	check(panel.visible and RegEx.create_from_string("^[a-z]+-[a-z]+-\\d{4}$").search(seed_text) != null, "Opening rolls a seed: "+seed_text)
	check(lands.size() == 1 and lands[0] == ["plain",seed_text], "Opening previews the quiet plain")
	check(panel.name_edit.placeholder_text == "Quiet plain — or leave it", "Placeholder names the land: "+panel.name_edit.placeholder_text)
	check(panel.caption_name.text == "Quiet plain" and panel.caption_description.text == "Flat and green. Raise every hill yourself.", "The caption describes the land")
	check(panel.rows.size() == 4 and panel.rows[0].selected, "Four lands, the first picked")
	panel.rows[1].picked.emit(panel.rows[1])
	check(lands.back() == ["canyon",seed_text] and panel.rows[1].selected and not panel.rows[0].selected, "Picking a land previews it with the same seed")
	check(panel.caption_name.text == "Red canyon" and panel.name_edit.placeholder_text == "Red canyon — or leave it", "Caption and placeholder follow the land")
	key(KEY_DOWN)
	check(panel.land == "isle" and lands.back()[0] == "isle", "Down picks the next land")
	panel.roll_button.pressed.emit()
	check(panel.seed_text != seed_text and lands.back() == ["isle",panel.seed_text] and panel.seed_label.text == panel.seed_text, "Roll changes the seed and previews it")
	key(KEY_ENTER)
	check(begun.size() == 1 and begun[0] == ["","isle",panel.seed_text], "A blank name begins blank (the library names it for the land)")
	panel.name_edit.text = "  Fogwater "
	panel.begin_button.pressed.emit()
	check(begun.back() == ["Fogwater","isle",panel.seed_text], "Begin passes the trimmed name")
	key(KEY_ESCAPE)
	check(backs == 1, "Escape goes back")
	panel.back_button.pressed.emit()
	check(backs == 2, "So does Back")
	panel.open(7)
	check(panel.seed_text == seed_text and panel.land == "plain" and panel.name_edit.text.is_empty(), "Opening again starts fresh; the same rng seed rolls the same seed")
	panel.close()
	key(KEY_ESCAPE)
	check(not panel.visible and backs == 2, "Closed, it ignores keys")
	panel.queue_free()
	print("New world panel: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures else 0)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: "+message)
