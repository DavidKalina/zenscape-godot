extends SceneTree
## The title as world library (scripts/world_title.gd): order, kicker and
## played-at line, browsing, rename, duplicate, delete, the empty state and
## entering, through the keys and buttons a player uses.
const Library = preload("res://scripts/world_library.gd")
const WorldTitle = preload("res://scripts/world_title.gd")
const Style = preload("res://scripts/worlds_style.gd")
var failures := 0
var changed: Array = []
var entered: Array = []
var new_requests := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1440,810)
	var path := "user://test-world-title-%d" % Time.get_ticks_usec()
	var library := Library.new(path)
	var oldest := library.create("Juniper Steps","canyon","",1000.0)
	var middle := library.create("The quiet plain","plain","",2000.0)
	var newest := library.create("Valley of Sleeping Stones","isle","",3000.0)
	# A capture for one world, read back as its tile's thumbnail.
	var image := Image.create(32,18,false,Image.FORMAT_RGB8)
	image.fill(Color("8a6a50"))
	image.save_png(library.thumbnail_path(newest.id))
	var title := WorldTitle.new()
	title.now = 3000.0+120.0
	root.add_child(title)
	title.selection_changed.connect(func(world: Dictionary) -> void: changed.append(world))
	title.enter_requested.connect(func(world: Dictionary) -> void: entered.append(world))
	title.new_world_requested.connect(func() -> void: new_requests += 1)
	title.setup(library)
	title.refresh()
	check(names(title) == ["Valley of Sleeping Stones","The quiet plain","Juniper Steps"], "Tiles run most recent first: %s" % [names(title)])
	check(title.kicker.text == Style.caps("Your worlds · 1 of 3"), "Kicker counts the selection: "+title.kicker.text)
	check(title.name_label.text == "Valley of Sleeping Stones", "The selected world's name shows")
	check(title.when_label.text == "Played 2 minutes ago", "Played-at line: "+title.when_label.text)
	check(changed.size() == 1 and changed[0].id == newest.id, "The first selection is announced for the backdrop")
	check(title.tiles[0].texture != null and title.tiles[1].texture == null, "A capture becomes the tile's thumbnail; others fall back to a fill")
	check(title.capture.texture != null, "The capture fades in over the backdrop")
	await create_timer(0.4).timeout
	check(title.veil.modulate.a > 0.95, "The capture covers the change")
	title.reveal_live()
	await create_timer(0.4).timeout
	check(title.veil.modulate.a < 0.05, "reveal_live fades the capture off")
	# Browsing.
	key(KEY_RIGHT)
	check(title.selected == 1 and changed.size() == 2 and changed[1].id == middle.id, "Right selects the next world and announces it")
	check(title.kicker.text == Style.caps("Your worlds · 2 of 3"), "The kicker follows")
	check(title.capture.texture == null, "No capture: the backdrop fades through the dark")
	key(KEY_LEFT)
	key(KEY_LEFT)
	check(title.selected == 0, "Left stops at the first world")
	key(KEY_RIGHT)
	# Rename: commit, blank, Escape.
	title.rename_button.pressed.emit()
	check(title.mode == "rename" and title.rename_edit.visible and not title.name_label.visible, "Rename turns the name into a field")
	check(title.rename_edit.text == "The quiet plain" and title.keep_name_button.visible and title.cancel_button.visible, "The field is pre-filled; Keep name and Cancel show")
	title.rename_edit.text = "  Fern bank "
	key(KEY_ENTER)
	check(title.mode == "idle" and library.find(middle.id).name == "Fern bank" and title.name_label.text == "Fern bank", "Enter keeps the new name")
	check(names(title)[1] == "Fern bank", "The tile takes the new name")
	check(entered.is_empty(), "Committing a rename does not enter")
	title.start_rename()
	title.rename_edit.text = "   "
	key(KEY_ENTER)
	check(library.find(middle.id).name == "Fern bank" and title.mode == "idle", "A blank name is ignored")
	title.start_rename()
	title.rename_edit.text = "Something else"
	key(KEY_ESCAPE)
	check(library.find(middle.id).name == "Fern bank" and title.mode == "idle" and title.name_label.visible, "Escape cancels the rename")
	title.start_rename()
	key(KEY_RIGHT)
	check(title.mode == "rename" and title.selected == 1, "Arrows edit the name while renaming")
	key(KEY_ESCAPE)
	# Duplicate.
	var before := changed.size()
	title.duplicate_button.pressed.emit()
	check(title.worlds.size() == 4 and names(title)[2] == "Fern bank (copy)", "Duplicate inserts the copy after its source: %s" % [names(title)])
	check(title.selected == 2 and title.name_label.text == "Fern bank (copy)", "The copy is selected")
	check(title.when_label.text == "Played just now", "The copy was played just now: "+title.when_label.text)
	check(changed.size() == before+1, "Selecting the copy is announced")
	check(library.worlds().size() == 4, "The copy is kept in the library")
	# Delete: Keep it, Escape, then Let it go.
	title.delete_button.pressed.emit()
	check(title.mode == "delete" and title.delete_card.visible and not title.enter_button.visible, "Delete asks on a card in place of the row")
	title.keep_button.pressed.emit()
	check(title.mode == "idle" and library.worlds().size() == 4, "Keep it keeps the world")
	title.delete_button.pressed.emit()
	key(KEY_ESCAPE)
	check(title.mode == "idle" and library.worlds().size() == 4, "Escape keeps it too")
	title.delete_button.pressed.emit()
	title.start_rename()
	check(title.mode == "rename" and not title.delete_card.visible, "Only one inline mode at a time")
	title.delete_button.pressed.emit()
	key(KEY_LEFT)
	check(title.mode == "idle" and title.selected == 1, "A selection change resets to idle")
	key(KEY_RIGHT)
	var copy_id: String = title.worlds[2].id
	title.delete_button.pressed.emit()
	title.let_go_button.pressed.emit()
	check(library.find(copy_id).is_empty() and title.worlds.size() == 3, "Let it go deletes the world")
	check(title.selected == 2 and title.worlds[2].id == oldest.id, "The selection moves to the next world")
	title.delete_button.pressed.emit()
	title.let_go_button.pressed.emit()
	check(title.selected == 1 and title.worlds[1].id == middle.id, "Deleting the last world moves to the previous one")
	# Entering.
	key(KEY_ENTER)
	check(entered.size() == 1 and entered[0].id == middle.id, "Enter enters the selected world")
	title.enter_button.pressed.emit()
	check(entered.size() == 2, "So does Enter world")
	# The empty state.
	title.select(0)
	title.delete_selected()
	title.delete_selected()
	check(title.worlds.is_empty() and title.kicker.text == Style.caps("Your worlds"), "Empty: the kicker reads Your worlds")
	check(title.name_label.text == "No worlds yet" and title.tiles.is_empty() and title.new_tile.visible, "Empty: No worlds yet, and only the New world tile")
	check(not title.enter_button.visible and not title.rename_button.visible and not title.delete_card.visible, "Empty: no actions")
	check(changed.back().is_empty(), "Empty: the backdrop is told there is no world")
	key(KEY_ENTER)
	check(new_requests == 1 and entered.size() == 2, "Empty: Enter asks for a new world")
	title.new_tile.picked.emit(title.new_tile)
	check(new_requests == 2, "The New world tile asks for a new world")
	# Many worlds scroll to keep the selection in view.
	for i in 14: library.create("World %d" % i,"hollow","",4000.0+i)
	title.refresh()
	for i in 13: key(KEY_RIGHT)
	await create_timer(0.3).timeout
	var tile: Control = title.tiles[title.selected]
	var shown := Rect2(title._clip.global_position,title._clip.size)
	check(shown.encloses(Rect2(tile.global_position,tile.size)), "The strip scrolls to the selection")
	title.queue_free()
	for world: Dictionary in library.worlds(): library.delete(world.id)
	DirAccess.remove_absolute(library.root.path_join("index.json"))
	DirAccess.remove_absolute(library.root)
	print("World title: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures else 0)

func names(title) -> Array:
	return title.tiles.map(func(tile) -> String: return str(tile.world.name))

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: "+message)
