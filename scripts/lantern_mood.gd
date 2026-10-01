extends Control
## Moods in the Lantern shell (M, or the right column's Mood): the moods pour
## out of the Mood slot as glass orbs down a crescent that bows toward the
## screen centre, and the chosen orb sends a thread to the customise veil
## beside it. The veil opens on the mockup's short form (season glyphs, and
## grass, rock and water) and TUNE THIS MOOD unfolds the rest: time, weather,
## rock and every colour, with swatches and a picker. What you set is pinned
## (scripts/mood_look.gd) and a lit dot unpins it. It replaces
## scripts/mood_panel.gd here and keeps its interface (`open`, `toggle`,
## `sync`, `contains_pointer`, `frame`); the moods and options are all read
## from mood_look.gd.
const Style = preload("res://scripts/lantern_style.gd")
const Slot = preload("res://scripts/lantern_slot.gd")
const Glass = preload("res://scripts/glass_chrome.gd")
const Mood = preload("res://scripts/mood_look.gd")
const ORB := 44.0
const ORB_CHOSEN := 54.0
const PITCH := 56.0
const BOW := 58.0
const STAGGER := 0.03
const POUR_SECONDS := 0.3
const SHORT_COLORS := ["grass","rock","water"]

var scene: Node3D
var mood: Node
var shell: Control
var open := false
var expanded := false
var orbs := {}
var _order: Array = []
var _materials := {}
var _t := 0.0
var _hovered := ""
var _origin_seen := {}
var _sync_time := 0.0
## The veil: blurred glass (glass_chrome.gd) with the controls laid over it.
var frame := Control.new()
var glass: Panel
var body := VBoxContainer.new()
var title := Label.new()
var tune := Button.new()
var back := Button.new()
var seasons := {}
var rows := {}
var extra := VBoxContainer.new()
var color_chips := {}
var color_row := HBoxContainer.new()
var swatch_row := HBoxContainer.new()
var picker := ColorPickerButton.new()
var color_key := ""
var name_label: Label
var wash := ColorRect.new()

func setup(owner_scene: Node3D, owner_shell: Control) -> void:
	scene = owner_scene
	mood = scene.mood_look
	shell = owner_shell
	name = "LanternMood"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Hovering an orb tints the screen faintly toward its sky.
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(1,1,1,0)
	add_child(wash)
	for id in [""]+Mood.mood_ids(): _orb(id)
	name_label = Style.label("",13)
	name_label.modulate.a = 0.0
	add_child(name_label)
	_build_veil()
	mood.changed.connect(sync)
	hide()

func _orb(id: String) -> void:
	var button := Button.new()
	Style.bare(button)
	button.toggle_mode = true
	button.name = "Orb_"+(id if id != "" else "world")
	button.custom_minimum_size = Vector2.ONE*ORB
	button.size = button.custom_minimum_size
	button.tooltip_text = Mood.mood_title(id)+"\n"+Mood.mood_description(id)
	button.pivot_offset = button.size*0.5
	var face := ColorRect.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/lantern_orb.gdshader")
	face.material = material
	button.add_child(face)
	_materials[id] = material
	button.pressed.connect(func() -> void: mood.choose(id))
	button.mouse_entered.connect(func() -> void: _hovered = id)
	button.mouse_exited.connect(func() -> void: if _hovered == id: _hovered = "")
	orbs[id] = button
	_order.append(id)
	add_child(button)
	_paint_orb(id)

func _paint_orb(id: String) -> void:
	var colors: Array[Color] = mood.chip_colors(id)
	var material: ShaderMaterial = _materials[id]
	material.set_shader_parameter("sky",colors[0])
	material.set_shader_parameter("glow",colors[1])
	material.set_shader_parameter("ground",colors[2])

# --- The veil --------------------------------------------------------------------

func _build_veil() -> void:
	frame.name = "Veil"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	glass = Glass.surface(18)
	frame.add_child(glass)
	body.position = Vector2(20,16)
	body.add_theme_constant_override("separation",10)
	frame.add_child(body)
	Style.style_label(title,15)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(title)
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation",10)
	body.add_child(line)
	_text_button(tune,"Tune this mood",11)
	tune.toggle_mode = true
	tune.tooltip_text = "Time, weather, rock and every colour. What you set stays through mood changes."
	tune.toggled.connect(func(on: bool) -> void:
		expanded = on
		extra.visible = on
		_sync_colors()
		fit())
	line.add_child(tune)
	_text_button(back,"Back to mood",11)
	back.tooltip_text = "Let every control follow the mood again"
	back.pressed.connect(func() -> void: mood.clear_pins())
	line.add_child(back)
	# Seasons: the four glyphs, as in the mockup.
	var season_line := _row("season","")
	for entry: Dictionary in Mood.SEASONS:
		var slot: Button = Slot.new()
		slot.setup(entry.id,entry.title,40.0,"below")
		slot.tint = Style.tint("mood")
		slot.label_always = true
		slot.caption.add_theme_font_size_override("font_size",10)
		slot.pressed.connect(func() -> void: mood.pin("season",entry.id))
		seasons[entry.id] = slot
		season_line.add_child(slot)
	season_line.add_theme_constant_override("separation",26)
	season_line.custom_minimum_size.y = 64
	extra.add_theme_constant_override("separation",8)
	extra.hide()
	body.add_child(extra)
	for id: String in ["time","weather"]:
		var row := _row(id,str(_control(id).title),extra)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation",4)
		flow.add_theme_constant_override("v_separation",2)
		flow.custom_minimum_size.x = 300
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(flow)
		for entry: Dictionary in Mood.options(id):
			var button := Button.new()
			_text_button(button,entry.title,11)
			button.toggle_mode = true
			button.pressed.connect(func() -> void: mood.pin(id,entry.id))
			rows[id].buttons[entry.id] = button
			flow.add_child(button)
	var rock := _row("rock_type","Rock",extra)
	for entry: Dictionary in Mood.ROCK_TYPES:
		var chip := _chip(Color(entry.color),entry.title,72.0)
		chip.pressed.connect(func() -> void: mood.pin("rock_type",entry.id))
		rows.rock_type.buttons[entry.id] = chip
		rock.add_child(chip)
	# Colours: grass, rock and water, or every key once tuning.
	color_row.alignment = BoxContainer.ALIGNMENT_CENTER
	color_row.add_theme_constant_override("separation",10)
	body.add_child(color_row)
	for entry: Dictionary in Mood.COLORS:
		var chip := _chip(Color.WHITE,entry.title)
		chip.pressed.connect(func() -> void:
			color_key = "" if color_key == entry.id else entry.id
			_sync_colors()
			fit())
		color_chips[entry.id] = chip
		color_row.add_child(chip)
	swatch_row.alignment = BoxContainer.ALIGNMENT_CENTER
	swatch_row.add_theme_constant_override("separation",6)
	swatch_row.hide()
	body.add_child(swatch_row)
	for index in range(6):
		var swatch := _swatch()
		swatch.pressed.connect(func() -> void:
			var colors := Mood.swatches(color_key)
			if index < colors.size(): mood.pin(color_key,colors[index]))
		swatch_row.add_child(swatch)
	picker.edit_alpha = false
	picker.focus_mode = Control.FOCUS_NONE
	picker.custom_minimum_size = Vector2(40,24)
	picker.tooltip_text = "Any colour"
	picker.flat = true
	picker.text = "ANY"
	Style.style_label(picker,10)
	picker.color_changed.connect(func(c: Color) -> void: if not color_key.is_empty(): mood.pin(color_key,c.to_html(false),false))
	swatch_row.add_child(picker)

func _control(id: String) -> Dictionary:
	for control: Dictionary in Mood.CONTROLS:
		if control.id == id: return control
	return {}

## A row: its small-caps title and a lit pin dot that lets it follow the mood.
func _row(id: String, heading: String, parent: Control = body) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER if heading.is_empty() else BoxContainer.ALIGNMENT_BEGIN
	parent.add_child(row)
	var dot := Button.new()
	_text_button(dot,"●",9)
	dot.custom_minimum_size = Vector2(14,0)
	dot.tooltip_text = "Set by you  ·  click to follow the mood again"
	dot.pressed.connect(func() -> void: mood.unpin(id))
	row.add_child(dot)
	if not heading.is_empty():
		var label := Style.label(heading,11,Color(Style.LIGHT,0.8))
		label.custom_minimum_size.x = 64
		row.add_child(label)
	rows[id] = {"dot":dot,"buttons":{}}
	return row

func _text_button(button: Button, text: String, font_size: int) -> void:
	button.text = Style.caps(text)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Style.style_label(button,font_size)
	button.add_theme_color_override("font_hover_color",Style.LIGHT)
	button.add_theme_color_override("font_pressed_color",Style.LIGHT)
	button.add_theme_color_override("font_hover_pressed_color",Style.LIGHT)
	button.add_theme_color_override("font_disabled_color",Color(Style.LIGHT,0.3))
	for state: String in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		style.content_margin_left = 7
		style.content_margin_right = 7
		style.content_margin_top = 2
		style.content_margin_bottom = 3
		style.bg_color = Color.TRANSPARENT
		if state == "hover": style.bg_color = Color(Style.LIGHT,0.08)
		if state in ["pressed","hover_pressed"]:
			style.bg_color = Color(Style.tint("mood"),0.16)
			style.border_color = Color(Style.tint("mood"),0.6)
			style.set_border_width_all(1)
		button.add_theme_stylebox_override(state,style)

## A round colour chip with its name under it.
func _chip(color: Color, heading: String, width := 52.0) -> Button:
	var chip := Button.new()
	Style.bare(chip)
	chip.toggle_mode = true
	chip.custom_minimum_size = Vector2(width,50)
	chip.tooltip_text = heading
	chip.set_meta("color",color)
	chip.draw.connect(func() -> void:
		var c := Vector2(chip.size.x*0.5,15)
		var on := chip.button_pressed
		chip.draw_circle(c,16.5,Color(Style.SHADE,0.55))
		chip.draw_circle(c,13.0,chip.get_meta("color"))
		chip.draw_arc(c,13.5,0,TAU,40,Color(Style.LIGHT,0.9 if on else 0.4),1.4 if on else 1.0,true)
		if on: chip.draw_arc(c,17.0,0,TAU,40,Color(Style.tint("mood"),0.7),1.0,true))
	var label := Style.label(heading,9,Color(Style.LIGHT,0.85))
	label.position = Vector2(0,32)
	label.size = Vector2(width,14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(label)
	return chip

func _swatch() -> Button:
	var swatch := Button.new()
	Style.bare(swatch)
	swatch.custom_minimum_size = Vector2(26,26)
	swatch.set_meta("color",Color.WHITE)
	swatch.set_meta("on",false)
	swatch.draw.connect(func() -> void:
		var c := swatch.size*0.5
		swatch.draw_circle(c,11.0,Color(Style.SHADE,0.5))
		swatch.draw_circle(c,9.0,swatch.get_meta("color"))
		if swatch.get_meta("on"): swatch.draw_arc(c,11.5,0,TAU,32,Style.LIGHT,1.3,true))
	return swatch

# --- Open, sync, place -------------------------------------------------------------

func toggle() -> void:
	set_open(not open)

func set_open(value: bool) -> void:
	open = value
	if open:
		show()
		sync()
		fit()

func _shown() -> bool:
	return shell != null and shell.is_visible_in_tree()

func sync() -> void:
	if scene == null: return
	title.text = Style.caps(Mood.mood_title(mood.mood))
	for id: String in orbs:
		var button: Button = orbs[id]
		button.visible = id != "" or not mood.origin.is_empty()
		button.set_pressed_no_signal(id == mood.mood and not mood.origin.is_empty())
		if id == "" and not is_same(_origin_seen,mood.origin):
			_origin_seen = mood.origin
			_paint_orb(id)
	for id: String in rows:
		var current: String = mood.value(id)
		rows[id].dot.modulate.a = 1.0 if mood.pinned(id) else 0.0
		rows[id].dot.disabled = not mood.pinned(id)
		for option: String in rows[id].buttons:
			rows[id].buttons[option].set_pressed_no_signal(option == current)
			rows[id].buttons[option].queue_redraw()
	var season: String = mood.value("season")
	for id: String in seasons:
		seasons[id].set_pressed_no_signal(id == season)
		seasons[id].set_held(id == season)
	var count: int = mood.pins.size()
	tune.text = Style.caps("Tune this mood"+(" · %d set by you" % count if count > 0 else ""))
	back.visible = count > 0
	_sync_colors()
	fit()

func _sync_colors() -> void:
	for key: String in color_chips:
		var chip: Button = color_chips[key]
		chip.visible = expanded or key in SHORT_COLORS
		chip.set_meta("color",Color(mood.value(key)))
		chip.set_pressed_no_signal(key == color_key)
		chip.tooltip_text = str(Mood.COLORS[Mood.color_keys().find(key)].title)+(" · set by you, right-click to follow the mood" if mood.pinned(key) else "")
		chip.queue_redraw()
	swatch_row.visible = not color_key.is_empty() and color_chips[color_key].visible
	if not swatch_row.visible: return
	var swatches := Mood.swatches(color_key)
	var current: String = mood.value(color_key)
	for index in range(6):
		var swatch: Button = swatch_row.get_child(index)
		swatch.visible = index < swatches.size()
		if swatch.visible:
			swatch.set_meta("color",Color(swatches[index]))
			swatch.set_meta("on",swatches[index] == current)
			swatch.tooltip_text = "#"+str(swatches[index])
			swatch.queue_redraw()
	if not picker.get_popup().visible: picker.color = Color(current)

func _input(event: InputEvent) -> void:
	# A right-click on a pinned colour chip lets it follow the mood again.
	if not visible or not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_RIGHT: return
	for key: String in color_chips:
		var chip: Button = color_chips[key]
		if chip.is_visible_in_tree() and chip.get_global_rect().has_point(event.position) and mood.pinned(key):
			mood.unpin(key)
			get_viewport().set_input_as_handled()

## Where the orbs rest: a crescent left of the right column, bowing toward the
## screen centre, centred on the screen's height.
func rest(index: int, count: int) -> Vector2:
	var right: float = shell.world_column_left()-ORB*0.5-18.0
	var t := float(index)/maxf(1.0,count-1)*2.0-1.0
	# Closer together when there are more moods than the screen's height holds.
	var pitch := minf(PITCH,(size.y-ORB_CHOSEN*2.0)/maxf(1.0,count-1))
	return Vector2(right-BOW*(1.0-t*t),size.y*0.5+t*pitch*(count-1)*0.5)

func _process(delta: float) -> void:
	var shown := open and _shown()
	if not shown and _t <= 0.0:
		if visible: hide()
		return
	if shown and not visible: show()
	var count := 0
	for id in _order:
		if orbs[id].visible: count += 1
	var span := POUR_SECONDS+STAGGER*count
	_t = clampf(_t+(delta if shown else -delta*1.6)/span,0.0,1.0)
	var source: Vector2 = shell.mood_anchor()
	var index := 0
	var chosen_at := Vector2.ZERO
	for id in _order:
		var button: Button = orbs[id]
		if not button.visible: continue
		var local := clampf((_t*span-STAGGER*index)/POUR_SECONDS,0.0,1.0)
		var eased := Tween.interpolate_value(0.0,1.0,local,1.0,Tween.TRANS_CUBIC,Tween.EASE_OUT) as float
		var chosen := button.button_pressed
		var target := ORB_CHOSEN if chosen else ORB*(1.06 if id == _hovered else 1.0)
		button.size = Vector2.ONE*lerpf(button.size.x,target,1.0-exp(-12.0*delta))
		button.pivot_offset = button.size*0.5
		var at := source.lerp(rest(index,count),eased)
		button.position = at-button.size*0.5
		button.modulate.a = clampf(local*2.0,0.0,1.0)
		(_materials[id] as ShaderMaterial).set_shader_parameter("lit",1.0 if chosen or id == _hovered else 0.0)
		if chosen: chosen_at = at
		index += 1
	# The hovered orb's name beside it, and its sky faintly over the screen.
	var hover_alpha := 1.0 if not _hovered.is_empty() and orbs.has(_hovered) and shown else 0.0
	if hover_alpha > 0.0:
		var orb: Button = orbs[_hovered]
		name_label.text = Style.caps(Mood.mood_title(_hovered))
		name_label.size = name_label.get_minimum_size()
		name_label.position = orb.position+Vector2(-name_label.size.x-14.0,(orb.size.y-name_label.size.y)*0.5)
		wash.color = Color(mood.chip_colors(_hovered)[0],0.07)
	else:
		wash.color.a = move_toward(wash.color.a,0.0,delta*0.4)
	name_label.modulate.a = move_toward(name_label.modulate.a,hover_alpha,delta*6.0)
	frame.visible = shown and _t > 0.6 and chosen_at != Vector2.ZERO
	frame.modulate.a = clampf((_t-0.6)/0.4,0.0,1.0)
	if frame.visible: _place_veil(chosen_at)
	_sync_time += delta
	if shown and _sync_time > 0.5:
		# Living weather and a turning day move under the veil.
		_sync_time = 0.0
		sync()
	queue_redraw()

func fit() -> void:
	body.size = body.get_combined_minimum_size()
	glass.size = body.size+Vector2(40,32)
	frame.size = glass.size

var _thread_from := Vector2.ZERO
func _place_veil(orb: Vector2) -> void:
	fit()
	var x := orb.x-ORB_CHOSEN*0.5-48.0-frame.size.x
	var y := clampf(orb.y-frame.size.y*0.5,86.0,size.y-frame.size.y-120.0)
	frame.position = Vector2(x,y)
	_thread_from = orb

func _draw() -> void:
	if not frame.visible: return
	var to := Vector2(frame.position.x+frame.size.x+2.0,clampf(_thread_from.y,frame.position.y+16.0,frame.position.y+frame.size.y-16.0))
	Style.thread(self,_thread_from-Vector2(ORB_CHOSEN*0.5+4.0,0),to,Color(Style.LIGHT,0.5*frame.modulate.a))

func contains_pointer(point: Vector2) -> bool:
	if not visible or _t < 0.3: return false
	if frame.visible and frame.get_global_rect().has_point(point): return true
	for id: String in orbs:
		if orbs[id].visible and orbs[id].get_global_rect().has_point(point): return true
	return false
