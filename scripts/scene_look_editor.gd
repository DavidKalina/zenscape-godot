extends PanelContainer
## Live authoring controls, separate from the changing weather simulation.
const Presets = preload("res://scripts/scene_look_presets.gd")
const Look = preload("res://scripts/scene_look.gd")
const EDIT_FIELDS := {
	"_world_visuals":["fog_density","fog_height","peak_density","peak_altitude","rock_style","rock_detail"],
	"_celestial":["phase","cycling","night_fill","aurora_strength","rainbow_strength","_rainbow_growth","_target"],
	"_atmosphere":["strength","direction_angle","_fog_target","_haze_target","summit_mist","shroud","loosen","ray_strength"],
	"_precipitation":["preset_index","cloud_override","cold_override","state","target"],
	"surface_weather":["target_autumn","autumn","cold","target_cold","ice","snow_cover","ground_wet","air_wet"]
}
var scene: Node3D
var look: RefCounted
var preset_buttons := {}
var preset_status := Label.new()
var _preset_grid: GridContainer
var _preset_options: Control
var palette_choice := OptionButton.new()
var mood_choice := OptionButton.new()
var tabs := TabContainer.new()
var pickers := {}
var sliders := {}
var checks := {}
var weather_choice := OptionButton.new()
## World clock: how fast the day runs, and what day/hour it is now.
const SPEEDS := [1.0,4.0,12.0]
## World years the "Day" scrubber reaches: two, enough to walk the seasons
## twice, whatever length of year the clock is keeping.
const DAY_RANGE_YEARS := 2
var clock_choice := OptionButton.new()
var clock_readout := Label.new()
var force_weather_choice := OptionButton.new()
## Ticked, the year comes from the day count; unticked, the Season slider pins it.
var season_follows := true:
	set(value):
		season_follows = value
		var clock: WorldClock = scene.get("world_clock") if scene != null else null
		if clock != null: clock.season_override = -1.0 if value else clock.season
var rock_choice := OptionButton.new()
var undo_button := Button.new()
var redo_button := Button.new()
var _before := {}
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _gesture := false
var _touched := false
var _syncing := false

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	look = scene._celestial.look
	name = "SceneLookEditor"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("252931")
	style.border_color = Color("59636c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	add_theme_stylebox_override("panel",style)
	theme = Theme.new()
	theme.default_font_size = 13
	theme.default_font = load("res://assets/fonts/Nunito.ttf")
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",10)
	add_child(body)
	var heading := HBoxContainer.new()
	body.add_child(heading)
	var title := Label.new()
	title.text = "Scene colors & atmosphere"
	title.add_theme_font_size_override("font_size",18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close := Button.new()
	close.text = "×"
	close.tooltip_text = "Close · changes stay in this diorama"
	close.pressed.connect(hide)
	heading.add_child(close)
	var help := Label.new()
	help.text = "One click sets colors, light and weather."
	body.add_child(help)
	var preset_grid := GridContainer.new()
	preset_grid.columns = 2
	preset_grid.add_theme_constant_override("h_separation",12)
	body.add_child(preset_grid)
	_preset_options = preset_grid
	_label(preset_grid,"Palette")
	palette_choice.name = "PalettePreset"
	palette_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for title_text in Look.palette_names()+["Custom"]: palette_choice.add_item(title_text)
	palette_choice.set_item_disabled(palette_choice.item_count-1,true)
	palette_choice.item_selected.connect(func(index: int) -> void: _edit(func() -> void: look.choose(palette_choice.get_item_text(index))))
	preset_grid.add_child(palette_choice)
	_label(preset_grid,"Whole mood")
	mood_choice.name = "AtmosphereMood"
	mood_choice.add_item("Choose palette + weather…")
	for title_text in Look.MOODS: mood_choice.add_item(title_text)
	mood_choice.item_selected.connect(func(index: int) -> void:
		if index > 0: _edit(func() -> void: scene.apply_scene_mood(mood_choice.get_item_text(index)))
		mood_choice.select(0))
	preset_grid.add_child(mood_choice)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(tabs)
	_build_presets()
	tabs.tab_changed.connect(func(index: int) -> void: _preset_options.visible = index != 0)
	_preset_options.hide()
	var colors := _page("Landscape")
	for pair in [["grass","Grass"],["foliage","Leaves & needles"],["rock","Rock & shore"],["earth","Earth & wood"],["water","Water"]]: _color(colors,pair[0],pair[1])
	_slider(colors,"strength","Palette strength",0,1,0.01,func() -> float: return look.settings.strength,func(v: float) -> void: look.set_value("strength",v))
	_label(colors,"Facet shading and individual tints are retained.")
	var lighting := _page("Sky & light")
	for pair in [["sky","Upper sky"],["horizon","Horizon"],["glow","Horizon glow"],["sun","Daytime sunlight"],["ambient","Ambient sky"],["bounce","Ground bounce"],["rim","Rim light"],["fog","Mist tint"]]: _color(lighting,pair[0],pair[1])
	for key in ["sun_energy","ambient_energy","exposure"]:
		_slider(lighting,key,{"sun_energy":"Sun / moon strength","ambient_energy":"Ambient strength","exposure":"Exposure"}[key],Look.LIMITS[key][0],Look.LIMITS[key][1],0.01,
			func() -> float: return look.settings[key],func(v: float) -> void: look.set_value(key,v))
	var air := _page("Atmosphere")
	_label(air,"Weather")
	weather_choice.name = "WeatherPreset"
	for title_text in scene._precipitation.PRESET_NAMES: weather_choice.add_item(title_text.capitalize())
	weather_choice.item_selected.connect(func(index: int) -> void: _edit(func() -> void:
		scene._precipitation.cloud_override = -1.0
		scene._precipitation.cold_override = -1.0
		scene._precipitation.set_weather(index,true)))
	air.add_child(weather_choice)
	_slider(air,"time","Time of day",0,1,0.001,func() -> float: return scene._celestial.phase,scene._celestial.set_phase)
	_check(air,"cycling","Let the day cycle",scene._celestial,"cycling")
	if scene.get("weather_scheduler") != null:
		_check(air,"weather_drift","Let the weather drift",scene.weather_scheduler,"enabled")
	var clock: WorldClock = scene.get("world_clock")
	if clock != null:
		var pace := HBoxContainer.new()
		_label(pace,"Day pace").size_flags_horizontal = Control.SIZE_EXPAND_FILL
		clock_choice.name = "ClockSpeed"
		for multiplier: float in SPEEDS: clock_choice.add_item("%dx" % int(multiplier))
		clock_choice.item_selected.connect(func(index: int) -> void: clock.speed = SPEEDS[index])
		pace.add_child(clock_choice)
		air.add_child(pace)
		clock_readout.name = "ClockReadout"
		clock_readout.modulate = Color("bdc9c6")
		clock_readout.add_theme_font_size_override("font_size",11)
		air.add_child(clock_readout)
		# Scrub tooling: jump to a day, pin a season, force a sky. Nothing here
		# is part of the garden's own state; it is how a season gets watched.
		_slider(air,"day","Day",0,float(clock.year_days*DAY_RANGE_YEARS),1,func() -> float: return float(clock.day),func(v: float) -> void: clock.set_time(int(round(v)),clock.hour))
		_slider(air,"season","Season",0,1,0.01,func() -> float: return clock.season,func(v: float) -> void:
			season_follows = false
			clock.season_override = v)
		_check(air,"season_follows","Follow the calendar",self,"season_follows")
		_label(air,"Force weather")
		force_weather_choice.name = "ForceWeather"
		for weather_name in WeatherScheduler.PRESET_NAMES: force_weather_choice.add_item(String(weather_name).capitalize())
		force_weather_choice.item_selected.connect(func(index: int) -> void: _edit(func() -> void: scene._precipitation.set_weather(index)))
		air.add_child(force_weather_choice)
	_slider(air,"clouds","Cloud cover",0,1,0.01,func() -> float: return scene._celestial.cloud if scene._precipitation.cloud_override < 0 else scene._precipitation.cloud_override,func(v: float) -> void: scene._precipitation.cloud_override = v)
	_slider(air,"mist","Valley mist",0,1,0.01,func() -> float: return scene._atmosphere._fog_target,func(v: float) -> void:
		scene._atmosphere.set_fog(v)
		scene._atmosphere.fog_amount = v)
	_slider(air,"haze","Distance haze",0,1,0.01,func() -> float: return scene._atmosphere._haze_target,func(v: float) -> void:
		scene._atmosphere.set_haze(v)
		scene._atmosphere.haze_amount = v)
	_slider(air,"wind","Wind",0,3,0.05,func() -> float: return scene._atmosphere.strength,func(v: float) -> void:
		scene._set_wind(v)
		scene._atmosphere._air_strength = v)
	_slider(air,"wind_direction","Wind direction",0,360,1,func() -> float: return scene._atmosphere.direction_angle,func(v: float) -> void:
		scene._atmosphere.direction_angle = v
		scene._atmosphere._air_angle = deg_to_rad(v))
	_slider(air,"fog_density","Living fog",0,1.8,0.05,func() -> float: return scene._world_visuals.fog_density,func(v: float) -> void: scene._world_visuals.fog_density = v)
	_slider(air,"fog_height","Fog bank height",1.5,14,0.5,func() -> float: return scene._world_visuals.fog_height,func(v: float) -> void: scene._world_visuals.fog_height = v)
	_slider(air,"peak_density","Peak clouds",0,0.7,0.01,func() -> float: return scene._world_visuals.peak_density,func(v: float) -> void: scene._world_visuals.peak_density = v)
	_slider(air,"peak_altitude","Peak cloud altitude",2,24,0.5,func() -> float: return scene._world_visuals.peak_altitude,func(v: float) -> void: scene._world_visuals.peak_altitude = v)
	_label(air,"Rock faces")
	for rock_title in ["Clean","Lightly layered","Weathered"]: rock_choice.add_item(rock_title)
	rock_choice.item_selected.connect(func(index: int) -> void: _edit(func() -> void: scene._world_visuals.rock_style = index))
	air.add_child(rock_choice)
	_slider(air,"rock_detail","Rock detail",0,1,0.05,func() -> float: return scene._world_visuals.rock_detail,func(v: float) -> void: scene._world_visuals.rock_detail = v)
	_slider(air,"summit","Summit mist",0,1.5,0.01,func() -> float: return scene._atmosphere.summit_mist,func(v: float) -> void: scene._atmosphere.summit_mist = v)
	_slider(air,"cold","Cold",0,1,0.01,func() -> float: return scene._precipitation.surface_weather.target_cold,func(v: float) -> void:
		scene._precipitation.cold_override = v
		scene._precipitation.surface_weather.cold = v)
	_slider(air,"autumn","Autumn",0,1,0.01,func() -> float: return scene._precipitation.surface_weather.target_autumn,func(v: float) -> void:
		scene._precipitation.surface_weather.target_autumn = v
		scene._precipitation.surface_weather.autumn = v)
	_slider(air,"night_fill","Night fill",0,1.5,0.01,func() -> float: return scene._celestial.night_fill,func(v: float) -> void: scene._celestial.night_fill = v)
	_slider(air,"aurora","Aurora",0,1.5,0.01,func() -> float: return scene._celestial.aurora_strength,func(v: float) -> void: scene._celestial.aurora_strength = v)
	_slider(air,"rainbow","Hold rainbow",0,1,0.01,func() -> float: return scene._celestial.rainbow_strength,func(v: float) -> void: scene._celestial.rainbow_strength = v)
	var actions := HBoxContainer.new()
	body.add_child(actions)
	undo_button.text = "Undo look"
	undo_button.pressed.connect(undo_edit)
	actions.add_child(undo_button)
	redo_button.text = "Redo"
	redo_button.pressed.connect(redo_edit)
	actions.add_child(redo_button)
	var reset := Button.new()
	reset.text = "Reset colors"
	reset.pressed.connect(func() -> void: _edit(func() -> void: look.restore(Look.new().document())))
	actions.add_child(reset)
	var save := Button.new()
	save.text = "Save"
	save.pressed.connect(func() -> void:
		if scene.has_method("save_current"): scene.save_current()
		else: scene._chunk_editor.save_garden())
	actions.add_child(save)
	get_viewport().size_changed.connect(_layout)
	_layout()
	sync()

func _layout() -> void:
	var area := get_viewport_rect().size
	var factor := clampf((area.y-80.0)/620.0,0.5,1.0)
	scale = Vector2.ONE*factor
	size = Vector2(minf(420,(area.x-24)/factor),minf(700,(area.y-80)/factor))
	position = Vector2(area.x-size.x*factor-12,58)

func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",10)
	scroll.add_child(body)
	return body

func _label(parent: Node, title: String) -> Label:
	var label := Label.new()
	label.text = title
	parent.add_child(label)
	return label

func _color(parent: Node, key: String, title: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	_label(row,title).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var picker := ColorPickerButton.new()
	picker.name = key.capitalize()+"Color"
	picker.custom_minimum_size = Vector2(94,32)
	picker.edit_alpha = false
	picker.color = look.colors[key]
	picker.pressed.connect(_begin)
	picker.color_changed.connect(func(c: Color) -> void:
		_touched = true
		look.set_color(key,c))
	picker.popup_closed.connect(_commit)
	row.add_child(picker)
	pickers[key] = picker

func _slider(parent: Node, key: String, title: String, low: float, high: float, step: float, read: Callable, write: Callable) -> void:
	var label := _label(parent,title)
	var slider := HSlider.new()
	slider.name = key.capitalize()+"Slider"
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.custom_minimum_size.y = 24
	slider.drag_started.connect(func() -> void: _begin(); _gesture = true)
	slider.drag_ended.connect(func(_changed: bool) -> void: _gesture = false; _commit())
	slider.value_changed.connect(func(value: float) -> void:
		if not _syncing: _edit(func() -> void: write.call(value)))
	parent.add_child(slider)
	sliders[key] = {"control":slider,"read":read,"label":label,"title":title}

func _check(parent: Node, key: String, title: String, object: Object, field: String) -> void:
	var control := CheckBox.new()
	control.text = title
	control.toggled.connect(func(value: bool) -> void:
		if not _syncing: _edit(func() -> void: object.set(field,value)))
	parent.add_child(control)
	checks[key] = {"control":control,"object":object,"field":field}

func capture_edit() -> Dictionary:
	var result := {"look":look.document()}
	for group in EDIT_FIELDS:
		var object: Object = scene._precipitation.surface_weather if group == "surface_weather" else scene.get(group)
		result[group] = {}
		for key in EDIT_FIELDS[group]: result[group][key] = object.get(key)
	return result

func restore_edit(value: Dictionary) -> void:
	look.restore(value.look)
	scene._precipitation.set_weather(value._precipitation.preset_index,true)
	for group in EDIT_FIELDS:
		var object: Object = scene._precipitation.surface_weather if group == "surface_weather" else scene.get(group)
		for key in EDIT_FIELDS[group]: object.set(key,value[group][key])
	scene._atmosphere.set_fog(scene._atmosphere._fog_target)
	scene._atmosphere.set_haze(scene._atmosphere._haze_target)
	scene._atmosphere._air_angle = deg_to_rad(scene._atmosphere.direction_angle)
	scene._atmosphere._air_strength = scene._atmosphere.strength
	scene._atmosphere.set_rays(scene._atmosphere.ray_strength)
	scene._celestial.update_rig()
	scene._process(0.0)
	sync()

func _begin() -> void:
	_touched = false
	_before = capture_edit()

func _commit() -> void:
	if _touched and not _before.is_empty() and _before != capture_edit():
		_undo.append(_before)
		if _undo.size() > 64: _undo.pop_front()
		_redo.clear()
	_before = {}
	sync()

func _edit(action: Callable) -> void:
	if not _gesture: _begin()
	_touched = true
	action.call()
	scene._process(0.0)
	if not _gesture: _commit()

func undo_edit() -> void:
	if _undo.is_empty(): return
	_redo.append(capture_edit())
	restore_edit(_undo.pop_back())

func redo_edit() -> void:
	if _redo.is_empty(): return
	_undo.append(capture_edit())
	restore_edit(_redo.pop_back())

func reset_history() -> void:
	_undo.clear()
	_redo.clear()
	_before.clear()
	sync()

func sync() -> void:
	if scene == null: return
	_syncing = true
	palette_choice.select((Look.palette_names()+["Custom"]).find(look.palette))
	for key in pickers:
		if not pickers[key].get_popup().visible: pickers[key].color = look.colors[key]
	_sync_presets()
	weather_choice.select(scene._precipitation.preset_index)
	var clock: WorldClock = scene.get("world_clock")
	if clock != null:
		# The readout is where the Season slider is watched from: it names the quarter.
		clock_readout.text = clock.label()+" · "+clock.season_name()
		var pace := SPEEDS.find(clock.speed)
		if pace >= 0: clock_choice.select(pace)
		force_weather_choice.select(scene._precipitation.preset_index)
		var following := clock.season_override < 0.0
		if season_follows != following: season_follows = following
	rock_choice.select(scene._world_visuals.rock_style)
	for key in sliders:
		var row: Dictionary = sliders[key]
		var value: float = row.read.call()
		if not _gesture: row.control.set_value_no_signal(value)
		row.label.text = row.title+" · "+("%02d:%02d" % [int(value*24)%24,int(value*1440)%60] if key == "time" else String.num(value,2))
	for key in checks:
		var row: Dictionary = checks[key]
		row.control.set_pressed_no_signal(row.object.get(row.field))
	undo_button.disabled = _undo.is_empty()
	redo_button.disabled = _redo.is_empty()
	_syncing = false

func _process(_delta: float) -> void:
	if visible: sync()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_Z and (event.meta_pressed or event.ctrl_pressed):
		if event.shift_pressed: redo_edit()
		else: undo_edit()
		get_viewport().set_input_as_handled()

func _build_presets() -> void:
	var page := _page("Looks")
	preset_status.text = "Previewed on sample terrain · keeps your landscape"
	page.add_child(preset_status)
	var caption := _label(page,"Previews use sample terrain; your landscape stays unchanged.")
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size",11)
	caption.modulate = Color("bdc9c6")
	_preset_grid = GridContainer.new()
	_preset_grid.columns = 2
	_preset_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preset_grid.add_theme_constant_override("h_separation",8)
	_preset_grid.add_theme_constant_override("v_separation",10)
	page.add_child(_preset_grid)
	for id: String in Presets.PRESETS:
		var p: Dictionary = Presets.PRESETS[id]
		var button := Button.new()
		button.name = id
		button.tooltip_text = p.title+" · "+p.description+"\nApply colors, lighting and weather. Undo look restores your previous settings."
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(174,174)
		button.toggle_mode = true
		button.clip_contents = true
		for state in ["normal","hover","pressed","focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("333b43") if state == "normal" else Color("46575a")
			style.border_color = Color("bdc5a0") if state == "focus" else Color("5d706e")
			style.set_border_width_all(1)
			style.set_corner_radius_all(9)
			button.add_theme_stylebox_override(state,style)
		var image := TextureRect.new()
		image.position = Vector2(5,5)
		image.size = Vector2(164,98)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var path := "res://assets/scene_looks/"+id+".png"
		if ResourceLoader.exists(path): image.texture = load(path)
		button.add_child(image)
		var title := Label.new()
		title.text = p.title
		title.position = Vector2(9,106)
		title.add_theme_font_size_override("font_size",14)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(title)
		var description := Label.new()
		description.text = p.description
		description.position = Vector2(9,126)
		description.size = Vector2(156,40)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_font_size_override("font_size",11)
		description.modulate = Color("bdc9c6")
		description.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(description)
		button.pressed.connect(func() -> void: _edit(func() -> void: Presets.apply(scene,id)))
		button.resized.connect(func() -> void:
			image.size.x = button.size.x-10
			description.size.x = button.size.x-18)
		_preset_grid.add_child(button)
		preset_buttons[id] = button

func _sync_presets() -> void:
	if tabs.current_tab != 0: return
	var chosen := ""
	for id in preset_buttons:
		var selected: bool = Presets.matches(scene,id)
		preset_buttons[id].set_pressed_no_signal(selected)
		preset_buttons[id].modulate = Color.WHITE if selected else Color(0.88,0.92,0.92)
		if selected: chosen = Presets.PRESETS[id].title
	preset_status.text = "Your look · "+chosen if chosen != "" else "Choose a look · fine-tune it in the other tabs"
