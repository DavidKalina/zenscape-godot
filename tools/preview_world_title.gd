extends SceneTree
## Dev only: the worlds title (scripts/world_title.gd) and New world
## (scripts/new_world_panel.gd) over a flat stand-in backdrop, with a few
## fake worlds in user://preview-worlds, to eyeball them in a window:
##   godot --path . --script tools/preview_world_title.gd [-- --new]
## The stand-in takes each world's land colour and, a beat after every
## selection, reveals itself as the host's live world would. Begin adds the
## world and returns to the title; Quit closes.
const Library = preload("res://scripts/world_library.gd")
const WorldTitle = preload("res://scripts/world_title.gd")
const NewWorldPanel = preload("res://scripts/new_world_panel.gd")
const NAMES := [["Valley of Sleeping Stones","canyon",120.0],["The quiet plain","plain",20.0*3600.0],["Lantern Mesa","canyon",3*86400.0],
	["Fogwater","isle",19*86400.0],["Juniper Steps","canyon",28*86400.0],["Moss Hollow","hollow",60*86400.0],["A very long name for a world that will not fit its tile","plain",400*86400.0]]

var backdrop := ColorRect.new()

func _initialize() -> void:
	var root_path := "user://preview-worlds"
	var stale := Library.new(root_path)
	for world: Dictionary in stale.worlds(): stale.delete(world.id)
	var library := Library.new(root_path)
	var now := Time.get_unix_time_from_system()
	for i in NAMES.size():
		var world := library.create(NAMES[i][0],NAMES[i][1],"",now-float(NAMES[i][2]))
		# Every other world gets a capture: a dusk gradient in its land's colour.
		if i % 2 == 0: _capture(WorldTitle.LAND_TINTS[NAMES[i][1]]).save_png(library.thumbnail_path(world.id))
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var title := WorldTitle.new()
	var panel := NewWorldPanel.new()
	root.add_child(title)
	root.add_child(panel)
	title.selection_changed.connect(func(world: Dictionary) -> void: _stand_in(world.get("land","plain"),title))
	title.enter_requested.connect(func(world: Dictionary) -> void: print("Enter: ",world.name))
	title.settings_requested.connect(func() -> void: print("Settings"))
	title.quit_requested.connect(quit)
	title.new_world_requested.connect(func() -> void:
		title.hide()
		panel.open())
	panel.land_changed.connect(func(land: String, _seed: String) -> void: backdrop.color = WorldTitle.LAND_TINTS[land])
	panel.back_requested.connect(func() -> void:
		panel.close()
		title.show()
		title.refresh())
	panel.begin_requested.connect(func(world_name: String, land: String, seed_text: String) -> void:
		var world := library.create(world_name,land,seed_text)
		panel.close()
		title.show()
		title.refresh(world.id))
	title.setup(library)
	title.refresh()
	if "--new" in OS.get_cmdline_user_args(): title.new_world_requested.emit()

func _stand_in(land: String, title) -> void:
	await create_timer(0.35).timeout
	backdrop.color = WorldTitle.LAND_TINTS.get(land,WorldTitle.LAND_TINTS.plain)
	title.reveal_live()

func _capture(tint: Color) -> Image:
	var image := Image.create(320,180,false,Image.FORMAT_RGB8)
	for y in 180:
		var colour := Color("c9b9a6").lerp(tint,clampf((y-50)/90.0,0.0,1.0))
		for x in 320: image.set_pixel(x,y,colour.darkened(0.15*absf(x-160)/160.0))
	return image
