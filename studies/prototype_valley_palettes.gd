extends "res://studies/prototype_nahanni_valley.gd"
## Same geometry, planting, river, and camera; compare the existing nine world moods.
const MOODS := ["alpine_morning","golden_meadow","copper_autumn","rosewater_dusk","enchanted_forest","halloween_hollow","first_snow","nordic_night","after_the_rain"]
var mood_index := 0
var fog_weight := 1.0
var mood_ready := false
var hour_slider: HSlider
var fog_slider: HSlider
var altitude_slider: HSlider

func _ready() -> void:
	super._ready()
	mountain_material.shader = preload("res://shaders/prototype_valley_palette.gdshader")
	cloud_material.shader = preload("res://shaders/prototype_valley_palette_fog.gdshader")
	valley_mist.material.shader = preload("res://shaders/prototype_valley_palette_fog.gdshader")
	mood_ready = true
	apply_mood(0)
	get_window().title = "ZenScape visual lab · One valley, nine moods"

func apply_mood(index: int) -> void:
	mood_index = posmod(index,MOODS.size())
	fog_weight = 1.0
	clouds_enabled = true
	cloud_altitude = 9.0
	SceneLookPresets.apply(self,MOODS[mood_index])
	hour_slider.set_value_no_signal(_celestial.phase)
	fog_slider.set_value_no_signal(fog_weight)
	altitude_slider.set_value_no_signal(cloud_altitude)
	_update_stats()
	print("VALLEY MOOD ",MOODS[mood_index])

func _sync_clouds() -> void:
	super._sync_clouds()
	if not mood_ready: return
	var recipe: Dictionary = SceneLookPresets.PRESETS[MOODS[mood_index]]
	var tint: Color = _celestial.look.colors.fog.srgb_to_linear()
	var daylight: float = _celestial.state.get("zs_daylight",1.0)
	for material: ShaderMaterial in [cloud_material,valley_mist.material]:
		material.set_shader_parameter("cloud_tint",Vector3(tint.r,tint.g,tint.b))
		material.set_shader_parameter("cloud_glow",lerpf(0.035,0.23,daylight))
	cloud_material.set_shader_parameter("cloud_density",(0.12+recipe.clouds*0.45)*fog_weight)
	valley_mist.material.set_shader_parameter("cloud_density",recipe.mist*0.38*fog_weight)

func _update_stats() -> void:
	if stats != null:
		stats.text = "%s · Hour %.2f · Mist ×%.1f · Cloud altitude %.1f" % [SceneLookPresets.PRESETS[MOODS[mood_index]].title,_celestial.phase,fog_weight,cloud_altitude]

func _make_lab_ui() -> void:
	lab_ui = CanvasLayer.new()
	lab_ui.layer = 30
	add_child(lab_ui)
	var host := Control.new()
	lab_ui.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	host.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -450
	panel.offset_right = 450
	panel.offset_top = -275
	panel.offset_bottom = -15
	var column := VBoxContainer.new()
	panel.add_child(column)
	for row_index in range(3):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_child(row)
		for j in range(3):
			var index := row_index*3+j
			var button := Button.new()
			button.text = str(index+1)+" · "+SceneLookPresets.PRESETS[MOODS[index]].title
			button.pressed.connect(func() -> void: apply_mood(index))
			row.add_child(button)
	hour_slider = _knob(column,"Hour",0.0,1.0,0.005,0.4)
	hour_slider.value_changed.connect(func(v: float) -> void:
		_celestial.set_phase(v)
		_update_stats())
	fog_slider = _knob(column,"Mist strength",0.0,3.0,0.1,1.0)
	fog_slider.value_changed.connect(func(v: float) -> void:
		fog_weight = v
		var recipe: Dictionary = SceneLookPresets.PRESETS[MOODS[mood_index]]
		_atmosphere.set_fog(clampf(recipe.mist*v,0.0,1.0))
		_update_stats())
	altitude_slider = _knob(column,"Cloud altitude",4.0,20.0,0.5,9.0)
	altitude_slider.value_changed.connect(func(v: float) -> void:
		cloud_altitude = v
		_update_stats())
	stats = Label.new()
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(stats)
	var hint := Label.new()
	hint.text = "1–9 mood · K cloud banks · P freeze drift · C overview · F Bigfoot · Space orbit"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size",13)
	column.add_child(hint)

func _knob(column: VBoxContainer,title: String,minimum: float,maximum: float,step: float,value: float) -> HSlider:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 125
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.custom_minimum_size.x = 380
	row.add_child(slider)
	return slider

func _unhandled_input(event: InputEvent) -> void:
	if not mood_ready: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			apply_mood(event.keycode-KEY_1)
			return
		if event.keycode in [KEY_BRACKETLEFT,KEY_BRACKETRIGHT]: return
	super._unhandled_input(event)
