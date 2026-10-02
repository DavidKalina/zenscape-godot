extends Control
## The in-game pause (docs/design/worlds/README.md "3. In-game pause"): a
## scrim over the live world and a centred linen panel that says the world is
## kept, with Resume, Save a copy as… (an inline well), Field notes, Settings
## and Return to title. It only shows and asks; the game wiring pauses, saves
## and leaves. Field notes (scripts/field_notes.gd) is left out when
## `notes_available` is false, read at `open`.
##
## Lengths are design pixels at the 1440-wide frame, times scripts/hud_linen.gd
## `scale_for`. Keys: up/down move between rows (and through the open well),
## Enter activates, Esc resumes. Esc with focus inside the open copy well
## (its name, radios or button) folds the well first and puts focus back on
## its row; a second Esc resumes. Resume closes the panel before `resumed`;
## the other signals leave it open for the wiring to `close()`.

signal resumed
signal copy_requested(copy_name: String, carry_on: bool)
signal notes_requested
signal settings_requested
signal title_requested

const Worlds = preload("res://scripts/worlds_style.gd")
const Linen = preload("res://scripts/hud_linen.gd")
const Library = preload("res://scripts/world_library.gd")
const SCRIM := Color(20/255.0,18/255.0,26/255.0,0.42)
const CLOTH := Color(84/255.0,75/255.0,63/255.0,0.9)
const SHADOW := Color(10/255.0,8/255.0,12/255.0,0.45)
const RADIO_HOVER := Color(20/255.0,15/255.0,10/255.0,0.2)
const DIVIDER := Color(227/255.0,215/255.0,189/255.0,0.3)
## The panel's width and padding (top, sides, bottom), the column's gap, and
## the fade in, seconds.
const WIDTH := 440.0
const PAD := Vector3(30.0,22.0,22.0)
const GAP := 4.0
const FADE := 0.15

var is_open := false
## Whether the Field notes row is offered; read at `open`.
var notes_available := true
var world_name := ""
var carry_on := true
var copy_open := false
var status_text := "Kept safe · just now"
var kicker := Label.new()
var name_label := Label.new()
var status := Status.new()
var resume_row := Row.new()
var copy_row := Row.new()
var notes_row := Row.new()
var settings_row := Row.new()
var title_row := Row.new()
var copy_name := LineEdit.new()
var carry_radio := Radio.new()
var stay_radio := Radio.new()
var save_button := Primary.new()
var footnote := Label.new()
var _scrim := ColorRect.new()
var _sheet := Sheet.new()
var _cloth := Linen.Cloth.new()
var _well := Well.new()
var _fade: Tween
var _px := 1.0
var _row_font := Worlds.newsreader(400)
var _caps_font := Worlds.newsreader(500)
var _button_font := Worlds.newsreader(500)
var _body_font := Worlds.spectral()
var _note_font := Worlds.spectral_italic()
var _input_box := StyleBoxFlat.new()

## A row: Newsreader 21 with an "Esc" hint or a ▸/▾ chevron on the right. It
## draws itself; the Button under it keeps focus, hover and keys.
class Row extends Button:
	var hint := ""
	var chevron := 0  # 0 none, 1 ▸ folded, 2 ▾ open
	var px := 1.0
	var font: FontVariation
	var hint_font: FontVariation
	var chevron_font: FontVariation

	func _draw() -> void:
		var fill := Worlds.ROW_FOCUS if has_focus() else Worlds.ROW_HOVER if is_hovered() else Color.TRANSPARENT
		Linen.fill_round(self,Rect2(Vector2.ZERO,size),9.0*px,fill)
		var font_size := maxi(1,roundi(21.0*px))
		var baseline := roundf(10.0*px+font.get_ascent(font_size))
		draw_string(font,Vector2(roundf(12.0*px),baseline),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Worlds.INK)
		var right := size.x-12.0*px
		if not hint.is_empty():
			var caps := Worlds.caps_size(13.0*px)
			hint_font.spacing_glyph = roundi(13.0*px*0.2)
			var width := hint_font.get_string_size(Worlds.caps(hint),HORIZONTAL_ALIGNMENT_LEFT,-1,caps).x-hint_font.spacing_glyph
			draw_string(hint_font,Vector2(roundf(right-width),baseline),Worlds.caps(hint),HORIZONTAL_ALIGNMENT_LEFT,-1,caps,Worlds.MUTED)
		elif chevron > 0:
			# Neither face has ▸/▾, so draw them: Spectral 16 on the baseline.
			var s := 16.0*px
			var mid := baseline-0.3*s
			var points := PackedVector2Array([Vector2(right-0.36*s,mid-0.22*s),Vector2(right,mid),Vector2(right-0.36*s,mid+0.22*s)]) if chevron == 1 \
				else PackedVector2Array([Vector2(right-0.44*s,mid-0.18*s),Vector2(right,mid-0.18*s),Vector2(right-0.22*s,mid+0.2*s)])
			draw_colored_polygon(points,Worlds.MUTED)
			points.append(points[0])
			draw_polyline(points,Worlds.MUTED,maxf(0.6,0.5*px),true)

## A radio in the copy well: a 14px ring with a 7px dot when chosen, and
## Spectral 16 beside it.
class Radio extends Button:
	var selected := false
	var px := 1.0
	var font: FontVariation

	func _draw() -> void:
		if has_focus() or is_hovered(): Linen.fill_round(self,Rect2(Vector2.ZERO,size),7.0*px,RADIO_HOVER)
		var centre := Vector2(13.0*px,size.y*0.5)
		draw_arc(centre,6.25*px,0.0,TAU,40,Worlds.THREAD,1.5*px,true)
		if selected: draw_circle(centre,3.5*px,Worlds.THREAD,true,-1.0,true)
		var font_size := maxi(1,roundi(16.0*px))
		var baseline := roundf((size.y-font.get_height(font_size))*0.5+font.get_ascent(font_size))
		draw_string(font,Vector2(roundf(32.0*px),baseline),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Worlds.INK)

## The primary button, "Save copy ↵". The faces have no ↵; it is drawn.
class Primary extends Button:
	const LABEL := "Save copy"
	var px := 1.0
	var font: FontVariation

	func _draw() -> void:
		Linen.fill_round(self,Rect2(Vector2.ZERO,size),8.0*px,Worlds.BUTTON_HOVER if is_hovered() or has_focus() else Worlds.THREAD)
		var font_size := maxi(1,roundi(16.0*px))
		var baseline := roundf((size.y-font.get_height(font_size))*0.5+font.get_ascent(font_size))
		draw_string(font,Vector2(roundf(18.0*px),baseline),LABEL,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Worlds.BUTTON_TEXT)
		var s := 16.0*px
		var x := 18.0*px+font.get_string_size(LABEL+" ",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		var mid := baseline-0.24*s
		var line := maxf(1.0,1.2*px)
		draw_polyline(PackedVector2Array([Vector2(x+0.62*s,baseline-0.66*s),Vector2(x+0.62*s,mid),Vector2(x+0.04*s,mid)]),Worlds.BUTTON_TEXT,line,true)
		draw_polyline(PackedVector2Array([Vector2(x+0.24*s,mid-0.18*s),Vector2(x+0.02*s,mid),Vector2(x+0.24*s,mid+0.18*s)]),Worlds.BUTTON_TEXT,line,true)

	func width_for(font_size: int) -> float:
		return 36.0*px+font.get_string_size(LABEL+" ",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+0.64*16.0*px

## The status: a 7px #b9c99a dot, then Spectral 15.
class Status extends Control:
	var text := ""
	var px := 1.0
	var font: FontVariation

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var font_size := maxi(1,roundi(15.0*px))
		var baseline := roundf((size.y-font.get_height(font_size))*0.5+font.get_ascent(font_size))
		draw_circle(Vector2(3.5*px,size.y*0.5),3.5*px,Worlds.STATUS_OK,true,-1.0,true)
		draw_string(font,Vector2(roundf(15.0*px),baseline),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Worlds.SECONDARY_LINEN)

## The panel: its cloth lies behind; it draws the dashed divider.
class Sheet extends Control:
	var divider := Vector3()  # x from, x to, y
	var px := 1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := divider.z+0.5*maxf(1.0,roundf(px))
		Linen.dashed(self,PackedVector2Array([Vector2(divider.x,y),Vector2(divider.y,y)]),DIVIDER,maxf(1.0,roundf(px)),3.0*px,3.0*px)

## The copy well's inset fill.
class Well extends Control:
	var px := 1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		Linen.fill_round(self,Rect2(Vector2.ZERO,size),10.0*px,Worlds.WELL)

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_scrim.color = SCRIM
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_scrim)
	add_child(_sheet)
	_sheet.add_child(_cloth)
	for label: Label in [kicker,name_label,footnote]: _sheet.add_child(label)
	kicker.text = Worlds.caps("Paused")
	kicker.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_style_label(kicker,_caps_font,Worlds.MUTED)
	_style_label(name_label,_row_font,Worlds.INK)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	footnote.text = "Nothing is lost when you leave."
	_style_label(footnote,_note_font,Worlds.MUTED)
	status.font = _body_font
	status.text = status_text
	_sheet.add_child(status)
	for entry: Array in [[resume_row,"Resume",_resume],[copy_row,"Save a copy as…",func() -> void: set_copy_open(not copy_open)],
			[notes_row,"Field notes",notes_requested.emit],[settings_row,"Settings",settings_requested.emit],[title_row,"Return to title",title_requested.emit]]:
		var row: Row = entry[0]
		row.font = _row_font
		row.hint_font = _caps_font.duplicate() as FontVariation
		_button(row,entry[1],entry[2],_sheet)
	resume_row.hint = "Esc"
	copy_row.chevron = 1
	_sheet.add_child(_well)
	_well.visible = false
	_input_box.bg_color = Worlds.INPUT_FILL
	copy_name.add_theme_stylebox_override("normal",_input_box)
	copy_name.add_theme_stylebox_override("read_only",_input_box)
	copy_name.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	copy_name.add_theme_font_override("font",_row_font)
	for key in ["font_color","font_selected_color","font_uneditable_color"]: copy_name.add_theme_color_override(key,Worlds.INK)
	copy_name.add_theme_color_override("font_placeholder_color",Worlds.MUTED)
	copy_name.add_theme_color_override("caret_color",Worlds.THREAD)
	copy_name.add_theme_color_override("selection_color",Color(Worlds.THREAD,0.3))
	copy_name.text_submitted.connect(func(_text: String) -> void: save_copy())
	copy_name.draw.connect(_draw_input_rule)
	_well.add_child(copy_name)
	carry_radio.font = _body_font
	stay_radio.font = _body_font
	_button(carry_radio,"Carry on in the copy",func() -> void: set_carry_on(true),_well)
	_button(stay_radio,"Stay here — keep the copy for later",func() -> void: set_carry_on(false),_well)
	save_button.font = _button_font
	_button(save_button,"Save copy ↵",save_copy,_well)
	set_carry_on(true)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout)
	_layout()

func _style_label(label: Label, font: Font, colour: Color) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font",font)
	label.add_theme_color_override("font_color",colour)

## A Button that draws itself: no theme boxes, its own words hidden (and tiny,
## so they never set its minimum size).
func _button(button: Button, text: String, action: Callable, parent: Control) -> void:
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus","disabled","hover_pressed"]: button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for colour in ["font_color","font_hover_color","font_focus_color","font_pressed_color","font_hover_pressed_color","font_disabled_color"]:
		button.add_theme_color_override(colour,Color.TRANSPARENT)
	button.add_theme_font_size_override("font_size",1)
	button.pressed.connect(action)
	parent.add_child(button)

## Shows the panel over the world named `world_name`, Resume in reach, the
## copy well folded and reset to "{name} (copy)", carrying on.
func open(name_of_world: String) -> void:
	world_name = name_of_world
	name_label.text = world_name
	copy_name.text = _default_copy_name()
	copy_open = false
	notes_row.visible = notes_available
	set_carry_on(true)
	is_open = true
	show()
	set_copy_open(false)
	if is_inside_tree(): resume_row.grab_focus()
	if _fade: _fade.kill()
	modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(self,"modulate:a",1.0,FADE)

func close() -> void:
	is_open = false
	if _fade: _fade.kill()
	var focus := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focus != null and is_ancestor_of(focus): focus.release_focus()
	hide()

## "Keeping…" while a write is in progress, else "Kept safe · just now" or
## "Kept safe · 4 minutes ago" (scripts/world_library.gd wording). Unix seconds.
func set_status(keeping: bool, kept_at: float, now: float) -> void:
	if keeping: status_text = "Keeping…"
	else:
		var when := Library.relative_time(kept_at,now)
		if when.begins_with("Played "): when = when.trim_prefix("Played ")
		elif when.begins_with("Yesterday"): when = when.to_lower()
		status_text = "Kept safe · "+when
	status.text = status_text
	status.queue_redraw()

## Opens or folds the copy well; open, the name is in reach and selected.
func set_copy_open(value: bool) -> void:
	var was_in_well := is_inside_tree() and _in_well(get_viewport().gui_get_focus_owner())
	copy_open = value
	copy_row.chevron = 2 if value else 1
	copy_row.queue_redraw()
	_well.visible = value
	_layout()
	if not is_open or not is_inside_tree(): return
	if value:
		copy_name.grab_focus()
		copy_name.select_all()
		copy_name.caret_column = copy_name.text.length()
	elif was_in_well or get_viewport().gui_get_focus_owner() == null: copy_row.grab_focus()

func set_carry_on(value: bool) -> void:
	carry_on = value
	carry_radio.selected = value
	stay_radio.selected = not value
	carry_radio.queue_redraw()
	stay_radio.queue_redraw()

## Asks for the copy under the typed name (blank: "{name} (copy)") and folds
## the well.
func save_copy() -> void:
	var typed := copy_name.text.strip_edges()
	var chosen := typed if not typed.is_empty() else _default_copy_name()
	set_copy_open(false)
	copy_requested.emit(chosen,carry_on)

func _default_copy_name() -> String:
	return "%s (copy)" % world_name

func _resume() -> void:
	close()
	resumed.emit()

func _in_well(control: Control) -> bool:
	return control != null and _well.is_ancestor_of(control)

## What up/down step through, top to bottom.
func _focus_order() -> Array[Control]:
	var order: Array[Control] = [resume_row,copy_row]
	if copy_open: order.append_array([copy_name,carry_radio,stay_radio,save_button])
	if notes_row.visible: order.append(notes_row)
	order.append_array([settings_row,title_row])
	return order

func _input(event: InputEvent) -> void:
	if not is_open: return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if copy_open and _in_well(get_viewport().gui_get_focus_owner()): set_copy_open(false)
		else: _resume()
	elif event.is_action_pressed("ui_up",true) or event.is_action_pressed("ui_down",true):
		get_viewport().set_input_as_handled()
		var order := _focus_order()
		var at := order.find(get_viewport().gui_get_focus_owner())
		var step := -1 if event.is_action("ui_up") else 1
		order[0 if at < 0 else clampi(at+step,0,order.size()-1)].grab_focus()

## Whatever the panel's controls leave, the world behind does not get.
func _unhandled_input(_event: InputEvent) -> void:
	if is_open: get_viewport().set_input_as_handled()

func _draw_input_rule() -> void:
	var line := maxf(1.0,roundf(_px))
	var y := copy_name.size.y-line*0.5
	Linen.dashed(copy_name,PackedVector2Array([Vector2(0,y),Vector2(copy_name.size.x,y)]),Worlds.INPUT_RULE,line,3.0*_px,3.0*_px)

## Stacks the column in design pixels (CSS flex, gap 4) using the faces' real
## line heights, and centres the panel.
func _layout() -> void:
	if not is_inside_tree(): return
	var px := Linen.scale_for(size)
	_px = px
	var width := roundf(WIDTH*px)
	var left := PAD.y*px
	var inner := width-PAD.y*px*2.0
	var y := PAD.x*px
	# Header: padding 0 12 14, gap 8.
	var kicker_size := maxi(1,roundi(13.0*px))
	_caps_font.spacing_glyph = roundi(13.0*px*0.26)
	kicker.add_theme_font_size_override("font_size",Worlds.caps_size(13.0*px))
	y = _place(kicker,left+12.0*px,y,inner-24.0*px,_caps_font.get_height(kicker_size))+8.0*px
	var name_size := maxi(1,roundi(30.0*px))
	name_label.add_theme_font_size_override("font_size",name_size)
	y = _place(name_label,left+12.0*px,y,inner-24.0*px,_row_font.get_height(name_size))+8.0*px
	status.px = px
	y = _place(status,left+12.0*px,y,inner-24.0*px,_body_font.get_height(maxi(1,roundi(15.0*px))))+14.0*px+GAP*px
	var row_height := 20.0*px+_row_font.get_height(maxi(1,roundi(21.0*px)))
	for row: Row in [resume_row,copy_row]:
		row.px = px
		y = _place(row,left,y,inner,row_height)+GAP*px
	if copy_open:
		# The well: margin 2 6 8, padding 14, gap 12.
		_well.px = px
		var pad := 14.0*px
		var well_width := inner-12.0*px
		var input_size := maxi(1,roundi(20.0*px))
		copy_name.add_theme_font_size_override("font_size",input_size)
		_input_box.corner_radius_top_left = roundi(6.0*px)
		_input_box.corner_radius_top_right = roundi(6.0*px)
		_input_box.set_content_margin(SIDE_LEFT,10.0*px)
		_input_box.set_content_margin(SIDE_RIGHT,10.0*px)
		_input_box.set_content_margin(SIDE_TOP,7.0*px)
		_input_box.set_content_margin(SIDE_BOTTOM,7.0*px)
		var inside := _place(copy_name,pad,pad,well_width-pad*2.0,14.0*px+_row_font.get_height(input_size))+12.0*px
		var radio_height := 12.0*px+maxf(14.0*px,_body_font.get_height(maxi(1,roundi(16.0*px))))
		for radio: Radio in [carry_radio,stay_radio]:
			radio.px = px
			inside = _place(radio,pad,inside,well_width-pad*2.0,radio_height)+2.0*px
		inside += 10.0*px
		save_button.px = px
		var button_size := maxi(1,roundi(16.0*px))
		var button_width := roundf(save_button.width_for(button_size))
		inside = _place(save_button,well_width-pad-button_width,inside,button_width,16.0*px+_button_font.get_height(button_size))+pad
		y += 2.0*px
		y = _place(_well,left+6.0*px,y,well_width,inside)+8.0*px+GAP*px
	if notes_row.visible:
		notes_row.px = px
		y = _place(notes_row,left,y,inner,row_height)+GAP*px
	settings_row.px = px
	y = _place(settings_row,left,y,inner,row_height)+GAP*px
	_sheet.divider = Vector3(roundf(left+6.0*px),roundf(left+inner-6.0*px),roundf(y+8.0*px))
	y += 17.0*px+GAP*px
	title_row.px = px
	y = _place(title_row,left,y,inner,row_height)+GAP*px+2.0*px
	var note_size := maxi(1,roundi(15.0*px))
	footnote.add_theme_font_size_override("font_size",note_size)
	y = _place(footnote,left+12.0*px,y,inner-24.0*px,_note_font.get_height(note_size))+PAD.z*px
	var height := roundf(y)
	_sheet.px = px
	_sheet.size = Vector2(width,height)
	_sheet.position = ((size-_sheet.size)*0.5).round()
	_place_cloth(Rect2(Vector2.ZERO,_sheet.size),px)
	_sheet.queue_redraw()
	for control: Control in [status,resume_row,copy_row,notes_row,settings_row,title_row,carry_radio,stay_radio,save_button,_well,copy_name]: control.queue_redraw()

## Places `control` at `x`,`y` (rounded), `w` by `h`; returns its foot.
func _place(control: Control, x: float, y: float, w: float, h: float) -> float:
	control.position = Vector2(roundf(x),roundf(y))
	control.size = Vector2(roundf(w),roundf(h))
	return y+h

## The shared cloth, tinted to the panel's linen (rgba(84,75,63,.9)), hem
## inset 6 at radius 11, with the panel's deeper shadow (0 18 50 .45).
func _place_cloth(rect: Rect2, px: float) -> void:
	_cloth.place(rect,px,16.0,Vector2(6.0,11.0))
	var margin := ceilf(70.0*px)
	_cloth.margin = margin
	_cloth.position = rect.position-Vector2.ONE*margin
	_cloth.size = rect.size+Vector2.ONE*margin*2.0
	_cloth.material_ref.set_shader_parameter("margin",margin)
	_cloth.material_ref.set_shader_parameter("cloth",CLOTH)
	_cloth.material_ref.set_shader_parameter("shadow",SHADOW)
	_cloth.material_ref.set_shader_parameter("shadow_y",18.0)
	_cloth.material_ref.set_shader_parameter("shadow_blur",50.0)
