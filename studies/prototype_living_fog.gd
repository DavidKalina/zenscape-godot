extends "res://studies/prototype_inland_worlds.gd"
## Atmosphere-only experiment: a persistent bank carried by the shared world wind.
var living_volume: FogVolume
var living_material: ShaderMaterial
var fog_mode := 1
var bank_density := 1.0
var bank_height := 6.0
var bank_clock := 0.0
var fog_panel: PanelContainer
func _ready() -> void:
	choices = {"composition":"valley","landform":"glacial-valley"}
	super._ready()
	# The parent mountain study freezes the shared clock for still comparisons.
	# This atmosphere demo needs live wind integration and gusts.
	_paused = false
	# Start the air along the valley, rather than into its side walls.
	_atmosphere.direction_angle = 90.0
	_atmosphere._air_angle = PI/2.0
	_atmosphere.strength = 1.2
	_atmosphere._air_strength = 1.2
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
func _process(delta: float) -> void:
	bank_clock += delta
	super._process(delta)
	if living_volume != null: _sync_living_fog()

func set_fog_mode(index: int) -> void:
	fog_mode = index
	if living_volume != null: _sync_living_fog()

func _sync_living_fog() -> void:
	living_volume.visible = fog_mode>0
	if fog_mode>0:
		_environment.volumetric_fog_enabled = true
		# Biome mist resets this to 65 each frame, clipping the far third at our overview camera.
		_environment.volumetric_fog_length = maxf(125.0,distance+40.0)
	living_material.set_shader_parameter("ground_map",_precipitation.ground_texture)
	living_material.set_shader_parameter("stream_map",_precipitation.stream_texture)
	living_material.set_shader_parameter("bank_density",bank_density)
	living_material.set_shader_parameter("bank_height",bank_height)
	living_material.set_shader_parameter("activity",clampf(_atmosphere._air_strength/3.5,0.0,1.0))
	living_material.set_shader_parameter("bank_clock",bank_clock)
	var color: Color = _celestial.look.colors.fog.srgb_to_linear().lerp(Color(0.85,0.89,0.94).srgb_to_linear(),0.65)
	living_material.set_shader_parameter("bank_color",Vector3(color.r,color.g,color.b))
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
	for label in ["Off","Rolling fog bank"]: mode.add_item(label)
	mode.select(fog_mode)
	mode.item_selected.connect(set_fog_mode)
	column.add_child(mode)
	var density_slider := _knob(column,"Density",0.1,1.8,0.05,bank_density)
	density_slider.value_changed.connect(func(v: float) -> void: bank_density=v)
	var depth_slider := _knob(column,"Bank height",1.5,14.0,0.5,bank_height)
	depth_slider.value_changed.connect(func(v: float) -> void: bank_height=v)
	var wind_slider := _knob(column,"Wind",0.0,3.5,0.05,_atmosphere.strength)
	wind_slider.value_changed.connect(func(v: float) -> void: _atmosphere.strength=v)
	var direction_slider := _knob(column,"Wind direction",0.0,360.0,5.0,_atmosphere.direction_angle)
	direction_slider.value_changed.connect(func(v: float) -> void: _atmosphere.direction_angle=v)
