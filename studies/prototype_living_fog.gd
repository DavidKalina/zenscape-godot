extends "res://studies/prototype_inland_worlds.gd"
## Atmosphere experiment: persistent wind-driven bank or a writing-responsive reveal.
## Writing stays in memory and never enters the journal or terrain generator.
var living_volume: FogVolume
var living_material: ShaderMaterial
var fog_mode := 1
var bank_density := 1.0
var bank_height := 6.0
var coverage := 1.0
var cover_target := 1.0
var typed_characters := 0
var rate := 0.0
var flow := 0.0
var bank_clock := 0.0
var base_wind := 0.4
var meter: Label
var writing: TextEdit
var previous_text := ""
var fog_panel: PanelContainer
func _ready() -> void:
	choices = {"composition":"valley","landform":"glacial-valley"}
	super._ready()
	base_wind = _atmosphere.strength
	living_material = ShaderMaterial.new()
	living_material.shader = preload("res://shaders/prototype_living_fog.gdshader")
	living_volume = FogVolume.new()
	living_volume.name = "LivingFogBank"
	living_volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	living_volume.size = Vector3(36,24,36)
	living_volume.position = Vector3(0,10,0)
	living_volume.material = living_material
	add_child(living_volume)
	_make_fog_controls()
	get_window().title = "ZenScape visual lab · Living fog"
	_sync_living_fog()
func apply_mood(index: int) -> void:
	super.apply_mood(index)
	base_wind = _atmosphere.strength

func _process(delta: float) -> void:
	if living_volume != null:
		advance_writing(delta)
	super._process(delta)
	if living_volume != null: _sync_living_fog()
func advance_writing(delta: float) -> void:
	# Source writing.js: an 8-second pace meter, 2.5-second rise and 6-second decay.
	# Fixed 260 CPM baseline in this disposable lab; no personal pace persistence.
	rate *= exp(-delta/8.0)
	var target_flow := rate/(rate+260.0)
	flow = lerpf(flow,target_flow,1.0-exp(-delta/(2.5 if target_flow>flow else 6.0)))
	coverage = lerpf(coverage,cover_target,1.0-exp(-delta/2.8))
	bank_clock += delta
	if fog_mode>0: _atmosphere.strength = base_wind+flow*3.5
func stroke(count: int,word_ends := 0) -> void:
	if fog_mode==0 or count<=0: return
	rate += minf(count,8)*60.0/8.0
	typed_characters += mini(count,8)
	if word_ends>0: _atmosphere.send_gust(Vector3.ZERO)
	if fog_mode==2: cover_target = 1.0-smoothstep(15,180,typed_characters)
func _text_changed() -> void:
	var current := writing.text
	# Compare common prefix/suffix so replacing a selection counts inserted text.
	var prefix := 0
	while prefix<mini(current.length(),previous_text.length()) and current[prefix]==previous_text[prefix]: prefix += 1
	var suffix := 0
	while suffix<mini(current.length(),previous_text.length())-prefix and current[current.length()-1-suffix]==previous_text[previous_text.length()-1-suffix]: suffix += 1
	var inserted := current.substr(prefix,current.length()-prefix-suffix)
	previous_text = current
	# Ignore paste-sized changes; a pasted paragraph is not a burst of typing.
	if inserted.length()>0 and inserted.length()<=8:
		stroke(inserted.length(),inserted.count(" ")+inserted.count("\n"))
func set_fog_mode(index: int) -> void:
	fog_mode = index
	coverage = 1.0
	cover_target = 1.0
	typed_characters = 0
	if fog_mode==0: _atmosphere.strength = base_wind
	if living_volume != null: _sync_living_fog()
func replay_veil() -> void:
	cover_target = 1.0
	typed_characters = 0
	rate = 0
	flow = 0
	if writing != null:
		writing.text = ""
		previous_text = ""
func _sync_living_fog() -> void:
	living_volume.visible = fog_mode>0
	if fog_mode>0: _environment.volumetric_fog_enabled = true
	living_material.set_shader_parameter("ground_map",_precipitation.ground_texture)
	living_material.set_shader_parameter("stream_map",_precipitation.stream_texture)
	living_material.set_shader_parameter("bank_density",bank_density)
	living_material.set_shader_parameter("bank_height",bank_height)
	living_material.set_shader_parameter("coverage",coverage if fog_mode==2 else 1.0)
	living_material.set_shader_parameter("activity",flow)
	living_material.set_shader_parameter("bank_clock",bank_clock)
	var color: Color = _celestial.look.colors.fog.srgb_to_linear().lerp(Color(0.85,0.89,0.94).srgb_to_linear(),0.65)
	living_material.set_shader_parameter("bank_color",Vector3(color.r,color.g,color.b))
	if meter != null: meter.text = "Writing energy %d%% · Fog cover %d%%" % [roundi(flow*100),roundi((coverage if fog_mode==2 else 1.0)*100)]
func _make_fog_controls() -> void:
	fog_panel = PanelContainer.new()
	lab_ui.get_child(0).add_child(fog_panel)
	fog_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fog_panel.offset_left = -330
	fog_panel.offset_right = -15
	fog_panel.offset_top = 140
	var column := VBoxContainer.new()
	fog_panel.add_child(column)
	var title := Label.new()
	title.text = "Living fog"
	column.add_child(title)
	var mode := OptionButton.new()
	for label in ["Off","Rolling bank · stays","Writing veil · clears"]: mode.add_item(label)
	mode.select(fog_mode)
	mode.item_selected.connect(set_fog_mode)
	column.add_child(mode)
	var density_slider := _knob(column,"Density",0.1,1.8,0.05,bank_density)
	density_slider.value_changed.connect(func(v: float) -> void: bank_density=v)
	var depth_slider := _knob(column,"Bank height",1.5,14.0,0.5,bank_height)
	depth_slider.value_changed.connect(func(v: float) -> void: bank_height=v)
	var hint := Label.new()
	hint.text = "Type here to stir the air.\nWords send gusts; pauses let it settle.\nThis scratchpad is not saved."
	column.add_child(hint)
	writing = TextEdit.new()
	writing.custom_minimum_size = Vector2(300,130)
	writing.placeholder_text = "Start a few sentences…"
	writing.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	writing.text_changed.connect(_text_changed)
	column.add_child(writing)
	var replay := Button.new()
	replay.text = "Gather fog again"
	replay.pressed.connect(replay_veil)
	column.add_child(replay)
	meter = Label.new()
	column.add_child(meter)
