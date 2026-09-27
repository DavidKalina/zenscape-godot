extends "res://studies/diorama.gd"
## The full diorama renderer/editor, with reversible growth for regenerating the current place.
var places: Node
var places_ready := false
var places_path := "user://cozy-worlds/places.json"
## Creation is the default tool state: the land brush is in hand without the
## build palette. Craft opens the palette's fine tools; Create returns to the
## brush. --classic-build keeps the old Build/Enjoy toggle.
var creation_mode := "--classic-build" not in OS.get_cmdline_user_args()
var crafting := false
var craft_tool := "raise"
var _craft_before_menu := false
var _creation_hint: Label
const Genesis = preload("res://scripts/genesis_canvas.gd")

func _ready() -> void:
	library_path = places_path.get_base_dir()
	recent_file = library_path.path_join("recent.cfg")
	await super._ready()
	places = preload("res://scripts/cozy_regrowth.gd").new()
	add_child(places)
	await places.setup(self)
	places_ready = places.initialized
	get_window().title = "ZenScape · Gentle regrowth"
	_setup_creation()

func _setup_creation() -> void:
	_world_menu.get_popup().add_separator()
	_world_menu.get_popup().add_item("New open plain",120)
	_world_menu.get_popup().id_pressed.connect(func(id: int) -> void:
		if id == 120 and places != null and not places.busy: places.new_plain())
	_chunk_editor.status_changed.connect(func(text: String) -> void:
		# Every stroke refreshes; the creation hint already says how to keep going.
		if _creating() and text.begins_with("Garden changed"): _notice.text = "")
	if not creation_mode: return
	for connection: Dictionary in _build_button.pressed.get_connections():
		_build_button.pressed.disconnect(connection.callable)
	_build_button.pressed.connect(func() -> void: set_building(not crafting))
	_build_button.tooltip_text = "Craft opens the fine sculpt, paint and place tools · Create returns to the land brush"
	_creation_hint = Label.new()
	_creation_hint.text = "Drag to raise land  ·  Shift or right drag lowers  ·  [ ] brush size  ·  drag the sky to orbit"
	_creation_hint.add_theme_font_size_override("font_size",13)
	_creation_hint.add_theme_color_override("font_color",Color("eee7db",0.78))
	_creation_hint.add_theme_color_override("font_shadow_color",Color("182628",0.8))
	_creation_hint.add_theme_constant_override("shadow_offset_y",1)
	_creation_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.get_parent().add_child(_creation_hint)
	get_viewport().size_changed.connect(_place_creation_hint)
	_place_creation_hint()
	_sync_creation_ui()

func _place_creation_hint() -> void:
	if _creation_hint == null: return
	var screen := get_viewport().get_visible_rect().size
	_creation_hint.size = _creation_hint.get_minimum_size()
	_creation_hint.position = Vector2((screen.x-_creation_hint.size.x)*0.5,screen.y-_creation_hint.size.y-18.0)

## The land brush is in hand and the craft palette is away.
func _creating() -> bool:
	return creation_mode and _has_world and _chunk_editor.active and not crafting and _chunk_editor.mode == "land"

func set_building(enabled: bool) -> void:
	if not creation_mode or not _has_world:
		super.set_building(enabled)
		return
	if enabled:
		super.set_building(true)
		crafting = true
		if _chunk_editor.mode == "land": _chunk_editor.select_tool(craft_tool)
	else:
		_enter_creation()
	_sync_creation_ui()

func _enter_creation() -> void:
	if _look_editor != null: _look_editor.hide()
	if _landscape_editor != null: _landscape_editor.hide()
	_build_palette.close_palette()
	crafting = false
	if _chunk_editor.mode != "land": craft_tool = _chunk_editor.mode
	flush_world_play()
	_chunk_editor.set_active(true)
	# The "land" tool paints with the creation brush last in hand.
	if _chunk_editor.active and _chunk_editor.mode != "land": _chunk_editor.select_tool("land")
	_ui.visible = false

## Regrowth folds the world away with no tool in hand, then gives the brush back.
func suspend_creation() -> void:
	_chunk_editor.finish_stroke()
	crafting = false
	super.set_building(false)
	_sync_creation_ui()

func resume_creation() -> void:
	if creation_mode: set_building(false)

func _sync_creation_ui() -> void:
	if not creation_mode or _build_button == null: return
	_build_button.text = "Create" if crafting else "Craft"
	if not crafting and _chunk_editor.active and not _menu.visible: _ui.visible = false
	if _creation_hint != null:
		_creation_hint.text = Genesis.brush_hint(_chunk_editor.brush_id)+"  ·  [ ] brush size  ·  1 land  2 water  3 meadow  4 forest  5 path"
		_creation_hint.visible = _creating() and _toolbar.visible and not _menu.visible
		_place_creation_hint()

func show_menu() -> void:
	if _menu != null and not _menu.visible: _craft_before_menu = crafting
	super.show_menu()
	_sync_creation_ui()

func close_menu() -> void:
	super.close_menu()
	if creation_mode and _has_world and not _craft_before_menu: set_building(false)
	_sync_creation_ui()

func launch_fidelity() -> void:
	# Startup is already the fully initialized Fidelity world. The cozy flow prepares
	# a native landscape next, without opening/writing a legacy save.
	if not title_loaded:
		_has_world = true
		_before_menu_paused = false
		_menu_orbit = false
		close_menu()
		set_building(false)
		return
	super.launch_fidelity()

func _process(delta: float) -> void:
	# Formation is presentation time: keep its air and tremor alive while the
	# resident/world clock remain paused. Super applies the resulting camera
	# pose before the fog compositor reads it, so both views stay aligned.
	if places != null and places.initialized and places.busy and _paused:
		_tremor.advance(delta,false)
		_atmosphere.advance(delta,false)
		_motion_time += delta
		RenderingServer.global_shader_parameter_set("zs_motion_time",_motion_time)
		_precipitation.advance(delta,false,_celestial)
	super._process(delta)
	if places != null and places.holding: creature.hide()
	# Cmd/Ctrl K opens the palette directly; treat that as entering Craft.
	if creation_mode and not crafting and _ui.visible and _chunk_editor.active and _menu != null and not _menu.visible:
		crafting = true
		if _chunk_editor.mode == "land": _chunk_editor.select_tool(craft_tool)
		_sync_creation_ui()

func _unhandled_input(event: InputEvent) -> void:
	# While creating, [ ] size the brush; Alt [ ] still steps the showcase seeds.
	if places != null and places.initialized and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_BRACKETLEFT,KEY_BRACKETRIGHT] and (not _creating() or event.alt_pressed):
		places.step_showcase(1 if event.keycode == KEY_BRACKETRIGHT else -1)
		get_viewport().set_input_as_handled()
		return
	if _creating() and event is InputEventKey and event.pressed and not event.echo and not (_menu.visible or _file_dialog.visible or _settings.visible):
		if event.keycode == KEY_ESCAPE:
			show_menu()
			get_viewport().set_input_as_handled()
			return
		# Number keys pick creation brushes (1 land, 2 water, ...); V and the
		# rest wait for the Craft palette.
		if event.keycode in [KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9,KEY_V] and not (event.ctrl_pressed or event.meta_pressed):
			var brush := Genesis.brush_for_key(event.keycode)
			if not brush.is_empty(): _chunk_editor.select_brush(brush)
			get_viewport().set_input_as_handled()
			_sync_creation_ui()
			return
	super._unhandled_input(event)
	_sync_creation_ui()

func handle_resident_input(event: InputEvent) -> bool:
	# The build palette forwards resident gestures before the scene's _input.
	# Claim the gesture at their shared entry point so the legacy carry handler
	# cannot take Bigfoot before the regrowth controller sees the press.
	if places != null and places.handle(event):
		get_viewport().set_input_as_handled()
		return true
	return super.handle_resident_input(event)

func blocks_world_input(point: Vector2) -> bool:
	if places != null and places.blocks(point): return true
	return super.blocks_world_input(point)

func save_current() -> bool:
	if places == null or not places.initialized: return true
	if places.holding or places.busy: return false
	if not places.save_places():
		_notice.text = "Could not save this place. Please try Save again."
		return false
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_safely()
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and places != null and places.holding and not has_meta("movie_capture"):
		places.cancel_carry()
	super._notification(what)

func _quit_safely() -> void:
	if places != null and places.holding:
		await places.cancel_carry()
		while places.busy or places.holding: await get_tree().process_frame
	if places != null and places.save_places(): get_tree().quit()

func new_diorama() -> void:
	if places == null or places.busy or places.holding or _chunk_editor.forming: return
	super.new_diorama()
	if _chunk_editor.data.blank:
		_refresh_habitat()
		invite_bigfoot(Vector3(0,0,5))
		save_current()

func open_crossing_glade(chasm := false) -> void:
	if places == null or places.busy or places.holding or not save_current(): return
	# Regrowth normally saves over its active slot. Keep an ordinary Open-able
	# world before starting this separate activity, rather than replacing it.
	var previous := _chunk_editor.save_path
	_chunk_editor.save_path = library_path.path_join("Before-crossing-"+str(Time.get_unix_time_from_system())+".json")
	var saved := _chunk_editor.save_garden()
	_chunk_editor.save_path = previous
	if not saved:
		_notice.text = "Could not save the current place. Your world is still open."
		return
	super.open_crossing_glade(chasm)
