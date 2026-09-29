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
## The Lantern Maker shell (scripts/lantern_shell.gd): brushes along the top,
## hands down the left, the world down the right, Photo as the play button.
## --classic-shell keeps the glass palette (scripts/creation_palette.gd) and
## its mood panel.
var lantern := "--classic-shell" not in OS.get_cmdline_user_args()
## The hand scheme (scripts/modeless_input.gd): the hand is the only way to
## touch the world. No brush bar, hand modes, world column, Photo button, Craft
## or command palette; the keys are M (moods), P (photo), Esc (menu) and the
## Cmd shortcuts. `--classic-controls` brings the old shell back.
var hand_only := creation_mode and lantern and preload("res://scripts/modeless_input.gd").enabled()
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
## A figure to set down and look through (scripts/wanderer_eye.gd). V.
var wanderer: Node
## Moods and their pins (scripts/mood_look.gd), saved with the place, and the
## panel that picks them (scripts/mood_panel.gd). M or the palette's Mood.
var mood_look: Node
var mood_panel: Control
## The shell's camera: focus, follow, glides and gestures (scripts/camera_rig.gd).
var camera_rig: Node
## True once the shell is built and the first world is open.
var shell_ready := false
var _craft_before_menu := false
var _look_before_hide := false
var _toolbar_glass: Panel
var _glyphs := {}
## --atlas: Genesis chunks stitched into one world (scripts/chunk_atlas_controller.gd).
var atlas: Node
var atlas_path := "user://cozy-worlds/atlas.json"
## --modeless: turning the diorama over for a new world (scripts/diorama_flip.gd).
var flip: Node
## --modeless: the rim pulled down springs a range; a lift set down slowly
## sinks a basin (scripts/edge_spring.gd).
var edge_spring: Node
## The title: the game opens on a generated world the camera orbits, under the
## title menu, and the pick opens the place ("resume" or "plain", the choices
## of scripts/cozy_regrowth.gd `launch_choice`). A launch flag that names a
## world (--resume, --generated, --seed, --atlas), --no-title, the desktop
## self-check and a scene a probe instantiates itself go straight in.
signal title_picked(choice: String)
## True while the title's world is up and waiting for a pick.
var titled := false

func _ready() -> void:
	if "--verify-desktop-build" in OS.get_cmdline_user_args():
		# The packaged self-check must never touch the player's saved places.
		places_path = OS.get_temp_dir().path_join("zenscape-export-places-"+str(Time.get_ticks_usec())).path_join("places.json")
		DirAccess.make_dir_recursive_absolute(places_path.get_base_dir())
	elif preload("res://scripts/chunk_atlas_controller.gd").enabled() and places_path == "user://cozy-worlds/places.json":
		# The atlas keeps its live chunk's regrowth save apart from the
		# player's places; the chunks themselves live in atlas.json.
		places_path = "user://cozy-worlds/atlas-live/places.json"
		DirAccess.make_dir_recursive_absolute(places_path.get_base_dir())
	library_path = places_path.get_base_dir()
	recent_file = library_path.path_join("recent.cfg")
	# Before the first restore, which reads and writes its document.
	mood_look = preload("res://scripts/mood_look.gd").new()
	mood_look.name = "MoodLook"
	add_child(mood_look)
	mood_look.setup(self)
	await super._ready()
	_retitle_menu()
	var choice := ""
	var veil: Node
	if _title_wanted():
		choice = await _run_title()
		veil = preload("res://scripts/title_loading.gd").new()
		add_child(veil)
		veil.stage("Opening your world")
	places = preload("res://scripts/cozy_regrowth.gd").new()
	add_child(places)
	await places.setup(self,choice)
	places_ready = places.initialized
	if veil != null: veil.queue_free()
	get_window().title = "ZenScape · Gentle regrowth"
	if preload("res://scripts/chunk_atlas_controller.gd").enabled():
		atlas = preload("res://scripts/chunk_atlas_controller.gd").new()
		atlas.name = "ChunkAtlasController"
		atlas.path = atlas_path
		add_child(atlas)
		await atlas.setup(self)
		get_window().title = "ZenScape · Chunk atlas"
	_setup_creation()
	if preload("res://scripts/diorama_flip.gd").enabled():
		flip = preload("res://scripts/diorama_flip.gd").new()
		add_child(flip)
		flip.setup(self)
		# Dragging the rim up and over the lip turns the diorama over.
		if hand_reach != null:
			hand_reach.flip_began.connect(func(at: Vector2) -> void: flip.begin(at))
			hand_reach.flip_dragged.connect(flip.drag)
			hand_reach.flip_released.connect(flip.release)
		# Pulling the rim down dips the block and springs a range; a lift set
		# down slowly sinks a basin (the flip's `set_down`).
		edge_spring = preload("res://scripts/edge_spring.gd").new()
		add_child(edge_spring)
		edge_spring.setup(self)
		if hand_reach != null:
			hand_reach.edge_spring_began.connect(func(at: Vector2) -> void: edge_spring.pull_begin(at))
			hand_reach.edge_spring_dragged.connect(func(at: Vector2, relative: Vector2) -> void: edge_spring.pull(at,relative))
			hand_reach.edge_spring_released.connect(edge_spring.release)
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

func _title_wanted() -> bool:
	if get_tree().current_scene != self: return false
	var args := OS.get_cmdline_user_args()
	for flag: String in ["--no-title","--resume","--generated","--seed","--atlas","--verify-desktop-build"]:
		if flag in args: return false
	return true

## Forms a showcase world (scripts/title_showcase.gd), orbits it under the
## title menu and returns the pick, with the menu closed.
func _run_title() -> String:
	var loading := preload("res://scripts/title_loading.gd").new()
	add_child(loading)
	loading.stage("Raising the land · growing the forest")
	resident_enabled = false
	restore_cave_state({})
	title_recipe = preload("res://scripts/title_showcase.gd").choose(title_seed if title_seed >= 0 else int(Time.get_unix_time_from_system()*1000000.0))
	if title_recipe.has("terrain_recipe"):
		await _chunk_editor.form_inland(title_recipe.terrain_recipe,true,false)
	else:
		await _chunk_editor.form_landscape(title_recipe.family,title_recipe.biome,true,title_recipe.variation)
	_frame_title()
	_has_world = false
	titled = true
	show_menu()
	loading.queue_free()
	var choice: String = await title_picked
	titled = false
	_has_world = true
	_before_menu_paused = false
	_menu_orbit = false
	close_menu()
	set_building(false)
	return choice

## The title menu for this flow: Continue, a new world, Settings, Quit. The
## legacy diorama entries (Fidelity, Open, Save a copy) are hidden.
func _retitle_menu() -> void:
	if _menu == null: return
	_continue.text = "Continue your world"
	for index: int in [1,3,4]: _menu.buttons[index].disabled = true
	# show_menu re-enables Save a copy; point it at a button nobody sees.
	_save_copy = Button.new()
	var fresh: Button = _menu.buttons[2]
	fresh.text = "Create a new world"
	for connection: Dictionary in fresh.pressed.get_connections(): fresh.pressed.disconnect(connection.callable)
	fresh.pressed.connect(_new_world_from_menu)

func _new_world_from_menu() -> void:
	if titled:
		title_picked.emit("plain")
		return
	if not _places_idle(): return
	close_menu()
	places.new_plain()

func continue_world() -> void:
	if titled:
		if FileAccess.file_exists(places_path): title_picked.emit("resume")
		return
	super.continue_world()

## Continue picks up the regrowth save, not the legacy diorama's recent file.
func _recent_path() -> String:
	return places_path if FileAccess.file_exists(places_path) else ""

func _places_idle() -> bool:
	return places != null and places.initialized and not places.busy and not places.holding and not _chunk_editor.forming

## Every brush and land form how-to, as the editor's status repeats them.
func _brush_hints() -> Array:
	var hints := Palette.registered().map(func(info: Dictionary) -> String: return info.hint)
	for entry: Dictionary in preload("res://scripts/mountain_forms.gd").FORMS: hints.append(entry.hint)
	return hints

func _setup_creation() -> void:
	_chunk_editor.status_changed.connect(func(text: String) -> void:
		# Every stroke refreshes; the palette's hint already says how to keep going.
		if _creating() and text.begins_with("Garden changed"): _notice.text = ""
		# Lantern's hint line already shows the brush's how-to.
		elif lantern and creation_palette != null and text in _brush_hints(): _notice.text = "")
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
	_toolbar.visibility_changed.connect(func() -> void: _toolbar_glass.visible = _toolbar.visible and (crafting or not lantern))
	creation_palette = preload("res://scripts/lantern_shell.gd").new() if lantern else Palette.new()
	_toolbar.get_parent().add_child(creation_palette)
	_toolbar.get_parent().move_child(creation_palette,_toolbar_glass.get_index())
	creation_palette.setup(self)
	if lantern: preload("res://scripts/lantern_style.gd").style_label(_notice,16,Color("fbf6ea"),true)
	photo = preload("res://scripts/photo_mode.gd").new()
	add_child(photo)
	photo.setup(self)
	wanderer = preload("res://scripts/wanderer_eye.gd").new()
	add_child(wanderer)
	wanderer.setup(self)
	if lantern:
		# The Lantern shell pours its own mood orbs from the right column.
		mood_panel = creation_palette.mood
	else:
		mood_panel = preload("res://scripts/mood_panel.gd").new()
		_toolbar.get_parent().add_child(mood_panel)
		_toolbar.get_parent().move_child(mood_panel,creation_palette.get_index())
		mood_panel.setup(self)
	camera_rig = preload("res://scripts/camera_rig.gd").new()
	add_child(camera_rig)
	camera_rig.setup(self)
	if lantern:
		for text: Label in [camera_rig.hint,camera_rig.label]: preload("res://scripts/lantern_style.gd").style_label(text,16,Color("fbf6ea"),true)
	# Right drags orbit here; Shift-drag works the brush the other way.
	_chunk_editor.right_works_other_way = false
	_layout_shell()
	_sync_creation_ui()

func _layout_shell() -> void:
	super._layout_shell()
	if _toolbar_glass == null: return
	var pad := Vector2(6,5)*_toolbar.scale.x
	_toolbar_glass.position = _toolbar.position-pad
	_toolbar_glass.size = _toolbar.size*_toolbar.scale+pad*2.0
	# Lantern: notices sit above Photo, clear of the right column.
	if lantern and creation_palette != null and creation_palette.has_method("notice_bottom"):
		var screen := get_viewport().get_visible_rect().size
		var k: float = creation_palette.ui_scale
		_notice.scale = Vector2.ONE*k
		_notice.size = Vector2(400.0,_notice.get_minimum_size().y)
		_notice.position = Vector2(screen.x-(400.0+24.0)*k,creation_palette.notice_bottom()-_notice.size.y*k)

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

## W and E pin the weather and season they turned to, as the mood drawer's
## Customise would, so the drawer never shows a stale value and a later mood
## keeps them; Shift+W letting the weather drift again unpins the weather.
func _weather_keyed(control: String, value: String) -> void:
	if mood_look == null: return
	match control:
		"weather", "season": mood_look.pin(control,value)
		"drift":
			if value == "on": mood_look.unpin("weather")

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
	if lantern and _toolbar_glass != null:
		# The right column holds Craft and World; the old toolbar shows only
		# while crafting, as the way back (Create) and the World menu.
		_toolbar_glass.visible = _toolbar.visible and crafting
		if _build_button.visible != crafting:
			_build_button.visible = crafting
			_world_menu.visible = crafting
			_layout_shell()
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
	if creation_mode and not hand_only and not crafting and _ui.visible and _chunk_editor.active and _menu != null and not _menu.visible:
		crafting = true
		if _chunk_editor.mode == "land": _chunk_editor.select_tool(craft_tool)
		_sync_creation_ui()

func _unhandled_input(event: InputEvent) -> void:
	var key: bool = event is InputEventKey and event.pressed and not event.echo
	# Alt [ ] steps the showcase seeds; plain [ ] sizes the brush in hand.
	if places != null and places.initialized and key and not hand_only and event.keycode in [KEY_BRACKETLEFT,KEY_BRACKETRIGHT] and (event.alt_pressed or not creation_mode):
		places.step_showcase(1 if event.keycode == KEY_BRACKETRIGHT else -1)
		get_viewport().set_input_as_handled()
		return
	if key and creation_mode and _has_world and not crafting and not (_menu.visible or _file_dialog.visible or _settings.visible) and _creation_key(event):
		get_viewport().set_input_as_handled()
		return
	# The hand scheme: any other plain key is the old shell's or a debug key
	# (brush numbers, V, [ ], G, R, W, E, N, B, L...). Only Cmd and Ctrl
	# shortcuts (save, undo, redo), Esc, the F keys and the mouse go on.
	if hand_only and event is InputEventKey and not (event.ctrl_pressed or event.meta_pressed) \
			and event.keycode != KEY_ESCAPE and not (event.keycode >= KEY_F1 and event.keycode <= KEY_F12):
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)
	_sync_creation_ui()

## Keys while creating or looking: Tab looks, 1-9 pick brushes in palette
## order, H hides the chrome and puts the brush away with it, P opens photo
## mode, M the moods, Esc closes the moods or opens the menu. Returns true when the key was used.
func _creation_key(event: InputEventKey) -> bool:
	if event.ctrl_pressed or event.meta_pressed or event.alt_pressed: return false
	if hand_only: return _hand_key(event)
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

## Keys in the hand scheme: M the moods, P photo mode, Esc closes the moods
## or opens the menu. Returns true when the key was used.
func _hand_key(event: InputEventKey) -> bool:
	if not _creating(): return false
	match event.keycode:
		KEY_M: toggle_mood()
		KEY_P: enter_photo()
		KEY_ESCAPE:
			if mood_open(): toggle_mood()
			else: show_menu()
		_: return false
	return true

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
	if atlas != null and atlas.contains_pointer(point): return true
	if mood_panel != null and mood_panel.contains_pointer(point): return true
	if camera_rig != null and camera_rig.contains_pointer(point): return true
	if _toolbar_glass != null and _toolbar_glass.is_visible_in_tree() and _toolbar_glass.get_global_rect().has_point(point): return true
	return super.blocks_world_input(point)

func save_current() -> bool:
	if places == null or not places.initialized: return true
	if places.holding or places.busy: return false
	if not places.save_places():
		_notice.text = "Could not save this place. Please try Save again."
		return false
	if atlas != null and not atlas.save():
		_notice.text = "Could not save the atlas. Please try Save again."
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
	if atlas != null: atlas.save()
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
