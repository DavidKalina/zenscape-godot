extends "res://studies/diorama.gd"
## The full diorama renderer/editor, with reversible growth for regenerating the current place.
const Palette = preload("res://scripts/creation_palette.gd")
const Glass = preload("res://scripts/glass_chrome.gd")
var places: Node
var places_ready := false
var places_path := "user://cozy-worlds/places.json"
## The creation shell: the game opens with a brush in hand and a quiet palette
## of brushes (scripts/creation_palette.gd). Craft opens the build palette's
## fine sculpt, paint and place tools; Create returns to the brush. Look (Tab) puts
## the brush away so the camera roams and nothing paints. --classic-build keeps
## the old Build/Enjoy toggle.
var creation_mode := "--classic-build" not in OS.get_cmdline_user_args()
## Emitted when a different creation brush is picked, and when Look puts the
## brush away or picks it back up.
signal brush_changed(brush_id: String)
signal looking_changed(looking: bool)
var crafting := false
var craft_tool := "raise"
## Just look: the brush is put away, the camera roams, nothing paints.
var looking := false
## Every registered creation brush in palette order (scripts/genesis_canvas.gd
## `BRUSHES`, the one list the editor, these keys and the palette read).
var brush_ids: Array = Palette.registered().map(func(info: Dictionary) -> String: return info.brush_id)
## The creation brush last in hand; Look and Craft return to it.
var brush: String = brush_ids[0] if not brush_ids.is_empty() else "land"
var creation_palette: Control
## Photo mode: compose, then capture (scripts/photo_mode.gd). P or the palette's camera.
var photo: Node
## Moods and their pins (scripts/mood_look.gd), saved with the place, and the
## panel that picks them (scripts/mood_panel.gd). M or the palette's Mood.
var mood_look: Node
var mood_panel: Control
## True once the shell is built and the first world is open.
var shell_ready := false
var _craft_before_menu := false
var _look_before_hide := false
var _toolbar_glass: Panel
var _glyphs := {}

func _ready() -> void:
	if "--verify-desktop-build" in OS.get_cmdline_user_args():
		# The packaged self-check must never touch the player's saved places.
		places_path = OS.get_temp_dir().path_join("zenscape-export-places-"+str(Time.get_ticks_usec())).path_join("places.json")
		DirAccess.make_dir_recursive_absolute(places_path.get_base_dir())
	library_path = places_path.get_base_dir()
	recent_file = library_path.path_join("recent.cfg")
	# Before the first restore, which reads and writes its document.
	mood_look = preload("res://scripts/mood_look.gd").new()
	mood_look.name = "MoodLook"
	add_child(mood_look)
	mood_look.setup(self)
	await super._ready()
	places = preload("res://scripts/cozy_regrowth.gd").new()
	add_child(places)
	await places.setup(self)
	places_ready = places.initialized
	get_window().title = "ZenScape · Gentle regrowth"
	_setup_creation()
	shell_ready = true

func _fill_world_menu() -> void:
	if not creation_mode:
		super._fill_world_menu()
		_world_menu.get_popup().add_separator()
		add_world_action("New open plain",func() -> void: places.new_plain(),120,_places_idle)
		return
	# World actions for the creation shell; the fine tools live behind Craft.
	add_world_action("New open plain",func() -> void: places.new_plain(),120,_places_idle)
	add_world_action("Regenerate landscape",func() -> void: places.regrow(),121,_places_idle)
	add_world_action("Return to previous place",func() -> void: places.resume_previous(),122,
		func() -> bool: return _places_idle() and places.has_previous())
	_world_menu.get_popup().add_separator()
	add_world_action("Save now",func() -> void:
		if save_current(): _notice.text = "Saved",123,_places_idle)
	add_world_action("Colors & sky",func() -> void:
		set_building(true)
		_build_palette.close_palette()
		edit_scene_look(),4)
	add_world_action("Overview",_overview,6)
	add_world_action("Sound",func() -> void: _settings.popup_centered(Vector2i(400,0)),125)
	_world_menu.get_popup().add_separator()
	add_world_action("Main menu",show_menu,124)

func _places_idle() -> bool:
	return places != null and places.initialized and not places.busy and not places.holding and not _chunk_editor.forming

func _setup_creation() -> void:
	_chunk_editor.status_changed.connect(func(text: String) -> void:
		# Every stroke refreshes; the palette's hint already says how to keep going.
		if _creating() and text.begins_with("Garden changed"): _notice.text = "")
	if not creation_mode: return
	for connection: Dictionary in _build_button.pressed.get_connections():
		_build_button.pressed.disconnect(connection.callable)
	_build_button.pressed.connect(func() -> void: set_building(not crafting))
	# The top right keeps only Craft and World; Esc opens the main menu, Cmd S saves.
	for control: Control in _toolbar.get_children():
		control.visible = control in [_build_button,_world_menu]
	for control: Button in [_build_button,_world_menu]:
		Glass.button(control)
		control.add_theme_font_size_override("font_size",13)
		control.add_theme_constant_override("h_separation",6)
		control.custom_minimum_size = Vector2(0,34)
		control.focus_mode = Control.FOCUS_NONE
	_world_menu.icon = _glyph("world")
	_world_menu.tooltip_text = "New plain, regenerate, save and the main menu"
	Glass.popup(_world_menu.get_popup())
	_toolbar.add_theme_constant_override("separation",2)
	_toolbar_glass = Glass.surface(12)
	_toolbar.get_parent().add_child(_toolbar_glass)
	_toolbar.get_parent().move_child(_toolbar_glass,_toolbar.get_index())
	_toolbar.visibility_changed.connect(func() -> void: _toolbar_glass.visible = _toolbar.visible)
	creation_palette = Palette.new()
	_toolbar.get_parent().add_child(creation_palette)
	_toolbar.get_parent().move_child(creation_palette,_toolbar_glass.get_index())
	creation_palette.setup(self)
	photo = preload("res://scripts/photo_mode.gd").new()
	add_child(photo)
	photo.setup(self)
	mood_panel = preload("res://scripts/mood_panel.gd").new()
	_toolbar.get_parent().add_child(mood_panel)
	_toolbar.get_parent().move_child(mood_panel,creation_palette.get_index())
	mood_panel.setup(self)
	_layout_shell()
	_sync_creation_ui()

func _layout_shell() -> void:
	super._layout_shell()
	if _toolbar_glass == null: return
	var pad := Vector2(6,5)*_toolbar.scale.x
	_toolbar_glass.position = _toolbar.position-pad
	_toolbar_glass.size = _toolbar.size*_toolbar.scale+pad*2.0

## A creation brush is in hand and the craft palette is away.
func _creating() -> bool:
	return creation_mode and _has_world and _chunk_editor.active and not crafting and not looking and _chunk_editor.mode == "land"

func set_building(enabled: bool) -> void:
	if not creation_mode or not _has_world:
		super.set_building(enabled)
		return
	if enabled:
		_set_looking_state(false)
		super.set_building(true)
		crafting = true
		if _chunk_editor.mode == "land": _chunk_editor.select_tool(craft_tool)
	elif looking:
		_put_brush_away()
	else:
		_enter_creation()
	_sync_creation_ui()

func _enter_creation() -> void:
	_close_craft_panels()
	crafting = false
	if _chunk_editor.mode != "land": craft_tool = _chunk_editor.mode
	flush_world_play()
	_chunk_editor.set_active(true)
	# The editor's "land" tool paints with whichever creation brush is in hand.
	if _chunk_editor.active and _chunk_editor.held_brush() != brush: _chunk_editor.select_brush(brush)
	_ui.visible = false

## Look: no tool in hand, so drags orbit the camera and there is no brush ring.
func _put_brush_away() -> void:
	_close_craft_panels()
	if crafting and _chunk_editor.mode != "land": craft_tool = _chunk_editor.mode
	crafting = false
	super.set_building(false)

func _close_craft_panels() -> void:
	if _look_editor != null: _look_editor.hide()
	if _landscape_editor != null: _landscape_editor.hide()
	_build_palette.close_palette()

func _set_looking_state(enabled: bool) -> void:
	if looking == enabled: return
	looking = enabled
	looking_changed.emit(looking)

## Put the brush away (true) or pick the last one back up (false).
func set_looking(enabled: bool) -> void:
	if not creation_mode or not _has_world or (places != null and places.busy): return
	if enabled == looking and not crafting: return
	_set_looking_state(enabled)
	set_building(false)

## Photo mode from the shell: the brush goes away and the chrome hides.
func enter_photo() -> void:
	if photo != null: photo.enter()

## The mood panel over the palette: open or close it.
func toggle_mood() -> void:
	if mood_panel != null: mood_panel.toggle()
	_sync_creation_ui()

func mood_open() -> bool:
	return mood_panel != null and mood_panel.open

## A new world opens on its own look with nothing pinned.
func establish_world_weather(world: Dictionary) -> void:
	super.establish_world_weather(world)
	if mood_look != null: mood_look.reset()

## Pick up a registered creation brush; this also ends Look and Craft.
func select_brush(id: String) -> void:
	if not creation_mode or not _has_world or id not in brush_ids or (places != null and places.busy): return
	var changed := id != brush
	brush = id
	_set_looking_state(false)
	set_building(false)
	if changed: brush_changed.emit(id)

## Regrowth folds the world away with no tool in hand, then gives the brush back.
func suspend_creation() -> void:
	_chunk_editor.finish_stroke()
	crafting = false
	super.set_building(false)
	_sync_creation_ui()

func resume_creation() -> void:
	if creation_mode: set_building(false)

func _glyph(kind: String) -> Texture2D:
	if not _glyphs.has(kind): _glyphs[kind] = Glass.glyph(kind,18)
	return _glyphs[kind]

func _sync_creation_ui() -> void:
	if not creation_mode or _build_button == null: return
	_build_button.text = "Create" if crafting else "Craft"
	_build_button.icon = _glyph(brush if crafting else "craft")
	_build_button.tooltip_text = "Back to the brushes" if crafting else "Fine sculpt, paint and place tools"
	if not crafting and _chunk_editor.active and not _menu.visible: _ui.visible = false
	if creation_palette != null:
		creation_palette.visible = _has_world and not crafting and _toolbar.visible and not _menu.visible
		creation_palette.sync()

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
	var key: bool = event is InputEventKey and event.pressed and not event.echo
	# Alt [ ] steps the showcase seeds; plain [ ] sizes the brush in hand.
	if places != null and places.initialized and key and event.keycode in [KEY_BRACKETLEFT,KEY_BRACKETRIGHT] and (event.alt_pressed or not creation_mode):
		places.step_showcase(1 if event.keycode == KEY_BRACKETRIGHT else -1)
		get_viewport().set_input_as_handled()
		return
	if key and creation_mode and _has_world and not crafting and not (_menu.visible or _file_dialog.visible or _settings.visible) and _creation_key(event):
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)
	_sync_creation_ui()

## Keys while creating or looking: Tab looks, 1-9 pick brushes in palette
## order, H hides the chrome and puts the brush away with it, P opens photo
## mode, M the moods, Esc closes the moods or opens the menu. Returns true when the key was used.
func _creation_key(event: InputEventKey) -> bool:
	if event.ctrl_pressed or event.meta_pressed or event.alt_pressed: return false
	if event.keycode == KEY_TAB:
		set_looking(not looking)
		return true
	if event.keycode == KEY_H:
		var hiding := _toolbar.visible
		if hiding:
			_look_before_hide = looking
			set_looking(true)
		super._unhandled_input(event)
		if not hiding: set_looking(_look_before_hide)
		_sync_creation_ui()
		return true
	if not (_creating() or looking): return false
	if event.keycode == KEY_M:
		toggle_mood()
		return true
	if event.keycode == KEY_ESCAPE and mood_open():
		toggle_mood()
		return true
	if event.keycode == KEY_ESCAPE:
		show_menu()
		return true
	if event.keycode == KEY_P:
		enter_photo()
		return true
	# Number keys pick brushes; V and unused numbers wait for the Craft palette.
	if event.keycode >= KEY_1 and event.keycode <= KEY_9:
		var index: int = event.keycode-KEY_1
		# The land key again, with land in hand, steps through its forms
		# (scripts/mountain_forms.gd); Shift steps back.
		if index < brush_ids.size() and brush_ids[index] == "land" and brush == "land" and _creating():
			_chunk_editor.cycle_land_form(-1 if event.shift_pressed else 1)
		elif index < brush_ids.size(): select_brush(brush_ids[index])
		return true
	if event.keycode == KEY_V: return true
	# Looking holds no brush: size keys have nothing to size.
	return looking and event.keycode in [KEY_BRACKETLEFT,KEY_BRACKETRIGHT]

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
	if creation_palette != null and creation_palette.contains_pointer(point): return true
	if photo != null and photo.contains_pointer(point): return true
	if mood_panel != null and mood_panel.contains_pointer(point): return true
	if _toolbar_glass != null and _toolbar_glass.is_visible_in_tree() and _toolbar_glass.get_global_rect().has_point(point): return true
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
