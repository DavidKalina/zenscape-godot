extends "res://studies/fidelity_life.gd"
## Product entry point. Study scenes remain available through their launchers.
var library_path := "user://dioramas"
var recent_file := "user://diorama-recent.cfg"
var _has_world := false
var title_loaded := false
var title_seed := -1
var title_recipe := {}
var _menu: Control
var _save_copy: Button
var _menu_orbit := false
var _toolbar: HBoxContainer
var _home_button: Button
var _notice: Label
var _continue: Button
var _build_button: Button
var _file_dialog: FileDialog
var _settings: AcceptDialog
var _before_menu_paused := false
var _defaults := {}
var _world_menu := MenuButton.new()
var _resident_play = preload("res://scripts/resident_interaction.gd").new()
var _gust_button: Button
var _resident_wind = preload("res://scripts/resident_wind.gd").new()
var _performance_trace = preload("res://scripts/performance_trace.gd").new()

func _choose_inhabited_shore() -> void:
	_chunk_editor.data.reset_flat()
	_chunk_editor.refresh()
	_refresh_habitat()

func _seed_loose_stones() -> void:
	pass

func _ready() -> void:
	set_process(false)
	var loading := preload("res://scripts/title_loading.gd").new()
	add_child(loading)
	await get_tree().process_frame
	await get_tree().process_frame
	resident_enabled = false
	super._ready()
	get_window().title = "ZenScape"
	get_tree().auto_accept_quit = false
	_life_status.get_parent().hide()
	_ui.hide()
	for item in fish.population: item.node.free()
	fish.population.clear()
	_celestial.cycling = false
	_celestial.set_phase(0.48)
	_atmosphere.strength = 0.35
	_atmosphere._air_strength = 0.35
	_precipitation.set_weather(0,true)
	_growth.terrain = 1.0
	_growth.foliage = 1.0
	_growth.water = 1.0
	_growth.replaying = false
	_growth.publish()
	_frame_diorama()
	_celestial.update_rig()
	_defaults = NativeGardenStore.capture(self)
	# The cover is disposable; New restores the blank-world defaults above.
	_make_shell()
	_resident_play.setup(self)
	add_child(_resident_wind)
	_resident_wind.setup(self)
	prepare_authoring_ui()
	add_child(_performance_trace)
	_performance_trace.saved.connect(func(path: String) -> void:
		_notice.text = "Performance capture saved: "+path if not path.is_empty() else "Could not save performance capture."
		if not path.is_empty() and DisplayServer.get_name() != "headless": OS.shell_show_in_file_manager(path))
	_chunk_editor.status_changed.connect(func(text: String) -> void:
		_notice.text = "" if text in NativeChunkEditor.TOOL_TEXT.values() else text)
	title_recipe = preload("res://scripts/title_showcase.gd").choose(title_seed if title_seed >= 0 else int(Time.get_unix_time_from_system()*1000000.0))
	_toolbar.hide()
	_menu.hide()
	loading.stage("Raising the land · growing the forest")
	await _chunk_editor.form_landscape(title_recipe.family,title_recipe.biome,true,title_recipe.variation)
	loading.stage("Gathering light")
	_frame_title()
	await get_tree().process_frame
	loading.queue_free()
	_notice.text = ""
	title_loaded = true
	set_process(true)
	show_menu()

func _process(delta: float) -> void:
	var trace_started := Time.get_ticks_usec() if _performance_trace.active else 0
	super._process(delta)
	if _resident_play.scene != null: _resident_play.update(delta)
	if _home_button != null:
		_home_button.disabled = not resident_enabled or routine.habits.home == null
		_home_button.tooltip_text = "Find his sheltered home" if routine.habits.sheltered_home else "Find his resting spot"
	if trace_started > 0: _performance_trace.last_scene_usec = Time.get_ticks_usec()-trace_started

func _frame_title() -> void:
	# Electron titleView: 72% of the chunk camera radius, with a raised target.
	var radius := Vector3(19,12,22).length()*0.72
	var eye := Vector3(sin(1.10)*sin(atan2(19.0,22.0)),cos(1.10),sin(1.10)*cos(atan2(19.0,22.0)))*radius
	target = Vector3(0,4,0)
	var offset := eye-target
	distance = offset.length()
	polar = acos(offset.y/distance)
	yaw = atan2(offset.x,offset.z)
	_auto_orbit_speed = TAU/60.0*0.22
	if title_recipe.family in ["valley","canyon"]:
		target.y = 2.0
		distance = 24.0
		polar = 1.12
	SceneLookPresets.apply(self,title_recipe.look,title_recipe.overrides)
	_update_camera()

func _frame_diorama() -> void:
	_auto_orbit_speed = 0.055
	target = Vector3(0,-1.0,0)
	distance = 40.0
	yaw = 0.35
	polar = 0.82
	_auto_orbit = false
	_update_camera()
	# Overview leaves a clear strip for the tools instead of hiding the
	# near edge of the miniature beneath them. Fit the actual terrain bounds.
	var screen := get_viewport().get_visible_rect().size
	var kit_scale := minf(1.0,minf(screen.x/1080.0,screen.y/720.0))
	var safe := Rect2(24,48,screen.x-48,screen.y-80-70*kit_scale)
	var outline := {}
	for mesh: MeshInstance3D in [_chunk_editor.terrain,_chunk_editor._skirt]:
		for surface in range(mesh.mesh.get_surface_count()):
			var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices: outline[mesh.to_global(vertex)] = true
	for step in range(60):
		var fits := true
		for corner: Vector3 in outline:
			if not safe.has_point(camera.unproject_position(corner)): fits = false
		if fits: break
		distance *= 1.04
		_update_camera()

func _style(fill: Color, border: Color, radius := 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _button(parent: Node, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _make_shell() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font = _build_palette.theme.default_font
	theme.default_font_size = 17
	theme.set_color("font_color","Label",Color("eee7db"))
	theme.set_color("font_color","Button",Color("eee7db"))
	theme.set_stylebox("normal","Button",_style(Color("332c37"),Color("665563"),10))
	theme.set_stylebox("hover","Button",_style(Color("51424e"),Color("c5aa75"),10))
	theme.set_stylebox("pressed","Button",_style(Color("665342"),Color("e0c68c"),10))
	root.theme = theme
	_toolbar = HBoxContainer.new()
	_toolbar.add_theme_constant_override("separation",8)
	root.add_child(_toolbar)
	_button(_toolbar,"Menu",show_menu)
	_build_button = _button(_toolbar,"Build",func() -> void: set_building(not _chunk_editor.active))
	_button(_toolbar,"Save",save_current)
	_button(_toolbar,"Landscapes",func() -> void:
		set_building(true)
		edit_landscape_presets())
	_button(_toolbar,"Colors & sky",func() -> void:
		set_building(true)
		_build_palette.close_palette()
		edit_scene_look())
	_button(_toolbar,"Bigfoot",func() -> void:
		if resident_enabled: _focus_bigfoot()
		else:
			set_building(true)
			_build_palette._start_placing("bigfoot"))
	_button(_toolbar,"Overview",_frame_diorama)
	_home_button = _button(_toolbar,"His spot",_focus_resting_spot)
	_home_button.disabled = true
	# The everyday shell shares the dock's warm, quiet controls.
	for control: Button in _toolbar.get_children():
		preload("res://scripts/tactile_editor_style.gd").button(control)
		control.add_theme_font_size_override("font_size",14)
		control.custom_minimum_size.y = 36
	_world_menu.text = "World"
	_world_menu.custom_minimum_size.y = 36
	_world_menu.add_theme_font_size_override("font_size",14)
	preload("res://scripts/tactile_editor_style.gd").button(_world_menu)
	_toolbar.add_child(_world_menu)
	for index in range(3,8):
		var action: Button = _toolbar.get_child(index)
		action.hide()
		_world_menu.get_popup().add_item(action.text,index)
	_world_menu.get_popup().id_pressed.connect(func(id: int) -> void:
		var action: Button = _toolbar.get_child(id)
		if not action.disabled: action.pressed.emit())
	_world_menu.about_to_popup.connect(func() -> void:
		_world_menu.get_popup().set_item_disabled(4,_home_button.disabled))
	_gust_button = _button(_toolbar,"Wind gust",_resident_play.toggle_gust)
	_gust_button.toggle_mode = true
	_gust_button.tooltip_text = "Drag the ground to aim wind; release to send · G"
	preload("res://scripts/tactile_editor_style.gd").button(_gust_button)
	_notice = Label.new()
	_notice.add_theme_font_size_override("font_size",13)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_notice)
	_notice.resized.connect(_layout_shell)
	_menu = preload("res://scripts/title_screen.gd").new()
	root.add_child(_menu)
	_continue = _menu.add_action("Continue your diorama","A little wilderness, waiting for you.",continue_world)
	_menu.add_action("New diorama","",new_diorama)
	_menu.add_action("Open diorama…","",show_open)
	_save_copy = _menu.add_action("Save a copy…","",show_save_copy)
	_menu.add_action("Settings","",func() -> void: _settings.popup_centered(Vector2i(400,260)))
	_menu.add_action("Quit","",_quit_safely)
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters = PackedStringArray(["*.json ; ZenScape diorama"])
	_file_dialog.file_selected.connect(_file_selected)
	_file_dialog.canceled.connect(func() -> void: show_menu())
	layer.add_child(_file_dialog)
	_settings = AcceptDialog.new()
	_settings.title = "Settings"
	_settings.theme = theme
	layer.add_child(_settings)
	var options := VBoxContainer.new()
	options.add_theme_constant_override("separation",12)
	_settings.add_child(options)
	var quality_label := Label.new()
	quality_label.text = "Visual quality"
	options.add_child(quality_label)
	var quality := OptionButton.new()
	quality.add_item("Beauty")
	quality.add_item("Balanced")
	quality.select(_quality.selected)
	quality.item_selected.connect(func(index: int) -> void:
		_quality.select(index)
		_set_quality(index)
		_defaults.quality = index)
	options.add_child(quality)
	for group: String in ["_ambient_audio","_thunder_audio"]:
		var audio: Node = get(group)
		var toggle := CheckButton.new()
		toggle.text = "Nature sounds" if group == "_ambient_audio" else "Thunder"
		toggle.button_pressed = not audio.muted
		toggle.toggled.connect(func(enabled: bool) -> void:
			audio.muted = not enabled
			_defaults[group] = NativeGardenStore.capture(self)[group])
		options.add_child(toggle)
		var volume := HSlider.new()
		volume.min_value = 0
		volume.max_value = 1
		volume.step = 0.01
		volume.value = audio.volume
		volume.value_changed.connect(func(value: float) -> void:
			audio.volume = value
			_defaults[group] = NativeGardenStore.capture(self)[group])
		options.add_child(volume)
	get_viewport().size_changed.connect(_layout_shell)
	_layout_shell.call_deferred()

func _layout_shell() -> void:
	if _menu == null: return
	var viewport_size := get_viewport().get_visible_rect().size
	_toolbar.size = _toolbar.get_combined_minimum_size()
	var kit_scale := minf(1.0,minf(viewport_size.x/1080.0,viewport_size.y/720.0))
	_toolbar.scale = Vector2.ONE*minf(kit_scale,(viewport_size.x-180)/_toolbar.size.x)
	_toolbar.position = Vector2(viewport_size.x-_toolbar.size.x*_toolbar.scale.x-20,16)
	_notice.scale = Vector2.ONE*kit_scale
	_notice.size.x = minf(400.0,maxf(100.0,(viewport_size.x-40.0)/kit_scale))
	_notice.size.y = _notice.get_minimum_size().y
	_notice.position = Vector2(viewport_size.x-_notice.size.x*kit_scale-20,maxf(72.0,viewport_size.y-100.0-_notice.size.y*kit_scale))

func set_building(enabled: bool) -> void:
	if not _has_world: return
	if not enabled and _look_editor != null: _look_editor.hide()
	if not enabled and _landscape_editor != null: _landscape_editor.hide()
	_chunk_editor.set_active(enabled)
	_ui.visible = enabled
	# The study header is replaced by this shell; keep its palette only.
	for child in _ui.get_children():
		if child != _build_palette and child is CanvasItem: child.hide()
	_build_button.text = "Enjoy" if enabled else "Build"

func show_menu() -> void:
	if _menu == null or _chunk_editor.forming: return
	if _resident_play.scene != null: _resident_play.cancel()
	if _resident_wind.scene != null: _resident_wind.clear()
	_chunk_editor.finish_stroke()
	if _look_editor != null: _look_editor.hide()
	if _landscape_editor != null: _landscape_editor.hide()
	_build_palette.close_palette()
	_build_palette.set_process_input(false)
	if not _menu.visible:
		_before_menu_paused = _paused
		_menu_orbit = _auto_orbit
	_paused = _has_world
	_auto_orbit = not _has_world
	_ui.hide()
	_toolbar.hide()
	_menu.show()
	_continue.disabled = not _has_world and not FileAccess.file_exists(_recent_path())
	_save_copy.disabled = not _has_world
	_menu.present(not _has_world)

func close_menu() -> void:
	_auto_orbit_speed = 0.055
	_menu.hide()
	_auto_orbit = _menu_orbit
	_toolbar.show()
	_build_palette.set_process_input(true)
	_paused = _before_menu_paused
	set_building(_chunk_editor.active)

func _recent_path() -> String:
	var config := ConfigFile.new()
	if config.load(recent_file) != OK: return ""
	return str(config.get_value("world","path",""))

func _remember() -> void:
	var config := ConfigFile.new()
	config.set_value("world","path",_chunk_editor.save_path)
	config.save(recent_file)

func save_current() -> bool:
	if not _has_world: return true
	# Menu pause is presentation state, not the world's saved pause preference.
	var paused_now := _paused
	if _menu.visible: _paused = _before_menu_paused
	var saved := _chunk_editor.save_garden()
	_paused = paused_now
	_notice.text = "Saved · "+_chunk_editor.save_path.get_file() if saved else "Could not save. Your diorama is still open."
	if saved: _remember()
	return saved

func new_diorama() -> void:
	if _chunk_editor.forming or not save_current(): return
	if DirAccess.make_dir_recursive_absolute(library_path) != OK:
		_notice.text = "Could not create the diorama folder."
		return
	routine.cancel("new diorama")
	resident_enabled = false
	_chunk_editor.start_flat()
	_chunk_editor.data._undo.clear()
	_chunk_editor.data._redo.clear()
	_chunk_editor.selected_object_id = -1
	_chunk_editor.select_tool("select")
	NativeGardenStore.restore(self,_defaults)
	_chunk_editor.save_path = library_path+"/Diorama-"+Time.get_datetime_string_from_system().replace(":","-")+"-"+str(Time.get_ticks_msec())+".json"
	_has_world = true
	_before_menu_paused = false
	close_menu()
	set_building(true)
	_frame_diorama()
	save_current()
	_notice.text = "Your blank diorama · Choose Landscapes for a curated starting point, or sculpt your own."

func continue_world() -> void:
	if _has_world: close_menu()
	else: open_path(_recent_path())

func show_open() -> void:
	if _chunk_editor.forming or not save_current(): return
	show_menu()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.current_dir = ProjectSettings.globalize_path(library_path)
	_file_dialog.popup_centered_ratio(0.75)

func show_save_copy() -> void:
	if not _has_world:
		_notice.text = "Create or open a diorama first."
		return
	_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.current_path = ProjectSettings.globalize_path(_chunk_editor.save_path).get_base_dir()+"/My diorama.json"
	_file_dialog.popup_centered_ratio(0.75)

func _file_selected(path: String) -> void:
	if _file_dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILE:
		open_path(path)
	else:
		var previous := _chunk_editor.save_path
		_chunk_editor.save_path = path
		if not save_current(): _chunk_editor.save_path = previous

func open_path(path: String) -> bool:
	if path.is_empty() or _chunk_editor.forming or not save_current(): return false
	var previous := _chunk_editor.save_path
	_chunk_editor.save_path = path
	if not _chunk_editor.open_garden():
		_chunk_editor.save_path = previous
		_notice.text = "Could not open that diorama. Your current world is unchanged."
		return false
	_has_world = true
	_before_menu_paused = _paused
	_remember()
	close_menu()
	set_building(false)
	_notice.text = "Opened · "+path.get_file()
	return true

func invite_bigfoot(point: Vector3) -> bool:
	if not _has_world: return false
	_refresh_habitat()
	var safe: Variant = navigation.nearest_safe(point)
	if safe == null:
		_notice.text = "Bigfoot needs a dry, open place to stand."
		return false
	routine.cancel("Bigfoot invited")
	creature.reset_at(safe)
	brain.reset_behavior()
	resident_enabled = true
	return true

func _summon_bigfoot(_fog := false) -> void:
	if resident_enabled: _focus_bigfoot()

func capture_diorama_state() -> Dictionary:
	return {"resident":resident_enabled,"position":[creature.position.x,creature.position.y,creature.position.z]}

func restore_life_state(state: Dictionary) -> void:
	# Physical props from the previous world cannot survive a world switch.
	routine.cancel("world switched")
	for projectile in routine._projectiles:
		if is_instance_valid(projectile.node): projectile.node.queue_free()
	routine._projectiles.clear()
	super.restore_life_state(state)

func restore_diorama_state(state: Dictionary) -> void:
	resident_enabled = bool(state.get("resident",false))
	if resident_enabled:
		var p: Array = state.position
		var safe: Variant = navigation.nearest_safe(Vector3(p[0],p[1],p[2]))
		if safe != null: creature.reset_at(safe)
	brain.reset_behavior()

func _input(event: InputEvent) -> void:
	if not is_node_ready(): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		if _performance_trace.active:
			_performance_trace.finish()
		else:
			_performance_trace.start(self)
			_notice.text = "Recording performance · F9 to save · Stops automatically after 60 seconds"
		get_viewport().set_input_as_handled()
		return
	if _file_dialog != null and (_file_dialog.visible or _settings.visible): return
	if _menu != null and _menu.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and _has_world:
			close_menu()
			get_viewport().set_input_as_handled()
		return
	if handle_resident_input(event): return
	super._input(event)

func activate_gust_tool() -> void:
	if not _resident_play.gust: _resident_play.toggle_gust()

func send_scene_gust(center: Vector3, direction := Vector3.ZERO) -> void:
	_resident_wind.send(center,direction)

func handle_resident_input(event: InputEvent) -> bool:
	if _resident_play.scene == null or _menu.visible or _file_dialog.visible or _settings.visible: return false
	if _resident_play.handle(event):
		get_viewport().set_input_as_handled()
		return true
	return false

func blocks_world_input(point: Vector2) -> bool:
	if _menu == null: return false
	return _menu.visible or _file_dialog.visible or _settings.visible or (_toolbar.is_visible_in_tree() and _toolbar.get_global_rect().has_point(point))

func _unhandled_input(event: InputEvent) -> void:
	# Terrain setup can dispatch input before the editor and shell exist.
	if not is_node_ready(): return
	if _menu != null and (_menu.visible or _file_dialog.visible or _settings.visible): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_S and (event.meta_pressed or event.ctrl_pressed):
			save_current()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and _landscape_editor != null and _landscape_editor.visible:
			_landscape_editor.hide()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and _look_editor != null and _look_editor.visible:
			_look_editor.hide()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_H:
			if _landscape_editor != null: _landscape_editor.hide()
			if _look_editor != null: _look_editor.hide()
			_toolbar.visible = not _toolbar.visible
			_notice.visible = _toolbar.visible
			_ui.visible = _toolbar.visible and _chunk_editor.active
			return
		if event.keycode == KEY_ESCAPE and _chunk_editor.mode == "select":
			show_menu()
			return
		if event.keycode == KEY_G:
			activate_gust_tool()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_R:
			_frame_diorama()
			return
	super._unhandled_input(event)
	_build_button.text = "Enjoy" if _chunk_editor.active else "Build"

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _resident_play.scene != null: _resident_play.cancel()
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _menu != null: _quit_safely()

func _quit_safely() -> void:
	if not _chunk_editor.forming and save_current(): get_tree().quit()
