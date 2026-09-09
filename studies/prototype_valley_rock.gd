extends "res://studies/prototype_valley_palettes.gd"
## Clean, layered, and weathered rock on identical terrain. T cycles treatments.
const ROCKS := ["Clean", "Lightly layered", "Weathered"]
var rock_style := 0
var detail_strength := 0.65
var rock_label: Label

func _ready() -> void:
	super._ready()
	mountain_material.shader = preload("res://shaders/prototype_valley_rock.gdshader")
	set_rock_style(0)
	get_window().title = "ZenScape visual lab · Rock face treatments"

func set_rock_style(index: int) -> void:
	rock_style = posmod(index,3)
	mountain_material.set_shader_parameter("rock_treatment",rock_style)
	mountain_material.set_shader_parameter("rock_detail_strength",detail_strength)
	if rock_label != null: rock_label.text = "%s · Detail %.2f · T cycle · R cliff view · C overview" % [ROCKS[rock_style],detail_strength]
	print("ROCK ",ROCKS[rock_style]," strength=",detail_strength)

func _make_lab_ui() -> void:
	super._make_lab_ui()
	var panel := PanelContainer.new()
	lab_ui.get_child(0).add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -340
	panel.offset_right = 340
	panel.offset_top = 15
	var column := VBoxContainer.new()
	panel.add_child(column)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	for i in range(3):
		var button := Button.new()
		button.text = ROCKS[i]
		button.pressed.connect(func() -> void: set_rock_style(i))
		row.add_child(button)
	var slider := _knob(column,"Rock detail",0.0,1.5,0.05,detail_strength)
	slider.value_changed.connect(func(v: float) -> void:
		detail_strength = v
		set_rock_style(rock_style))
	rock_label = Label.new()
	rock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(rock_label)

func cliff_camera() -> void:
	target = Vector3(-6.2,8.0,0.0)
	distance = 28.0
	yaw = 0.65
	polar = 1.13
	_auto_orbit = false
	_orbit_delta = Vector2.ZERO
	_pan_delta = Vector2.ZERO
	_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			set_rock_style(rock_style+1)
			return
		if event.keycode == KEY_R:
			cliff_camera()
			return
	super._unhandled_input(event)
