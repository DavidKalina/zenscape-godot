extends Control
## A centred linen sheet of rows over a scrim, in the game's pause look
## (scripts/pause_panel.gd: its scrim, its cloth, its Newsreader rows and
## dashed divider), for the game's pause and settings (scripts/kit_isle/
## pause_menu.gd, settings_menu.gd; docs/design/consolidation-audit.md,
## round 2). A small-caps kicker and a heading over the rows; a row is an
## action (`add_row`, with an optional key on its right), a choice
## (`add_choice`: "‹ Balanced ›" on its right, stepped), a group's small
## caps (`add_group`) or the dashed seam (`add_seam`); a hint line under
## them names the keys.
##
## Mouse, keys and pad alike: hovering a row puts it in reach; up and down
## (the arrows, the D-pad, the left stick: Godot's ui_up and ui_down) step
## through the rows; Enter, a click or pad A presses one (a choice steps on;
## a click on its ‹ steps back); left and right step a choice; Esc or pad B
## is `cancelled`. Every hint follows the device in hand (scripts/pad.gd
## `using_pad`, `hub.device_changed`): a row's key reads "Esc" with the
## keys and draws pad B with the pad, and the hint line its pad form
## (scripts/pad_prompt.gd).
##
## It runs while the tree is paused. Lengths are design pixels at the
## 1440-wide frame, times scripts/hud_linen.gd `scale_for`.

signal cancelled

const Worlds = preload("res://scripts/worlds_style.gd")
const Linen = preload("res://scripts/hud_linen.gd")
const Pad = preload("res://scripts/pad.gd")
const PadPrompt = preload("res://scripts/pad_prompt.gd")
const SCRIM := Color(20/255.0,18/255.0,26/255.0,0.42)
const CLOTH := Color(84/255.0,75/255.0,63/255.0,0.9)
const SHADOW := Color(10/255.0,8/255.0,12/255.0,0.45)
const DIVIDER := Color(227/255.0,215/255.0,189/255.0,0.3)
## The sheet's width and padding (top, sides, bottom), the gap between rows,
## a seam's height and the fade in, seconds.
const WIDTH := 440.0
const PAD := Vector3(30.0,22.0,22.0)
const GAP := 4.0
const SEAM := 17.0
const FADE := 0.15

var kicker := Label.new()
var heading := Label.new()
var hint := PadPrompt.new()
var rows: Array[Row] = []
## The rows' words' size and the room above and below them, design pixels
## (a long sheet sets them smaller).
var row_text := 21.0
var row_pad := 10.0
var _items: Array[Control] = []
var _scrim := ColorRect.new()
var _sheet := Sheet.new()
var _cloth := Linen.Cloth.new()
var _fade: Tween
var _px := 1.0
var _row_font := Worlds.newsreader(400)
var _caps_font := Worlds.newsreader(500)
var _value_font := Worlds.spectral()
var _note_font := Worlds.spectral_italic()

## A row: Newsreader 21, and on its right a key ("Esc", or the pad's glyph
## with the pad in hand) or a choice's "‹ value ›". It draws itself; the
## Button under it keeps focus, hover and keys.
class Row extends Button:
	## The keyboard key named on the right, and the pad glyph in its place.
	var key := ""
	var pad_glyph := ""
	## A choice: its options and the one chosen; `stepped(by)` steps it.
	var choices: Array = []
	var chosen := 0
	var on_step: Callable
	var px := 1.0
	## Its words' size and the room above them, design pixels.
	var text_size := 21.0
	var pad_y := 10.0
	var font: FontVariation
	var caps_font: FontVariation
	var value_font: FontVariation
	var glyph_font: Font
	## The choice's ‹, for a click on it to step back.
	var back_rect := Rect2()

	## The key shown on the right now: the pad's glyph id ("{B}") with the
	## pad in hand (nothing, if the row has no pad button), else the
	## keyboard's key; "" for none.
	func shown_key() -> String:
		if Pad.using_pad(): return "{%s}" % pad_glyph if not pad_glyph.is_empty() else ""
		return key

	func value() -> String:
		return str(choices[chosen]) if chosen >= 0 and chosen < choices.size() else ""

	## Steps a choice by `by`, wrapping, and tells its owner.
	func step(by: int) -> void:
		if choices.is_empty(): return
		chosen = posmod(chosen+by,choices.size())
		queue_redraw()
		if on_step.is_valid(): on_step.call(chosen)

	func _gui_input(event: InputEvent) -> void:
		if choices.is_empty() or not event is InputEventMouseButton: return
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT and back_rect.has_point(click.position):
			accept_event()
			grab_focus()
			step(-1)

	func _draw() -> void:
		var fill := Worlds.ROW_FOCUS if has_focus() else Worlds.ROW_HOVER if is_hovered() else Color.TRANSPARENT
		Linen.fill_round(self,Rect2(Vector2.ZERO,size),9.0*px,fill)
		var font_size := maxi(1,roundi(text_size*px))
		var baseline := roundf(pad_y*px+font.get_ascent(font_size))
		draw_string(font,Vector2(roundf(12.0*px),baseline),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Worlds.INK)
		var right := size.x-12.0*px
		if not choices.is_empty():
			var value_size := maxi(1,roundi(text_size*0.82*px))
			var words := value()
			var width := value_font.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,value_size).x
			var s := 9.0*px
			var mid := baseline-0.33*value_size
			var ink := Worlds.INK if has_focus() else Worlds.SECONDARY_LINEN
			var arrow := Color(Worlds.MUTED,1.0 if has_focus() else 0.7)
			# › at the right, the value, ‹ before it.
			_chevron(Vector2(right-s*0.5,mid),s,1.0,arrow)
			var x := right-s-8.0*px-width
			draw_string(value_font,Vector2(roundf(x),baseline),words,HORIZONTAL_ALIGNMENT_LEFT,-1,value_size,ink)
			var back := x-8.0*px-s*0.5
			_chevron(Vector2(back,mid),s,-1.0,arrow)
			back_rect = Rect2(back-s*1.5,0.0,s*3.0,size.y)
			return
		var shown := shown_key()
		if shown.is_empty(): return
		if shown.begins_with("{"):
			var id := shown.trim_prefix("{").trim_suffix("}")
			var height := 19.0*px
			PadPrompt.draw_glyph(self,id,Vector2(right-PadPrompt.glyph_width(id,height)*0.5,size.y*0.5),height,glyph_font)
			return
		var caps := Worlds.caps_size(13.0*px)
		caps_font.spacing_glyph = roundi(13.0*px*0.2)
		var label := Worlds.caps(shown)
		var width := caps_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,caps).x-caps_font.spacing_glyph
		draw_string(caps_font,Vector2(roundf(right-width),baseline),label,HORIZONTAL_ALIGNMENT_LEFT,-1,caps,Worlds.MUTED)

	func _chevron(centre: Vector2, s: float, way: float, colour: Color) -> void:
		var points := PackedVector2Array([centre+Vector2(-0.3*s*way,-0.5*s),centre+Vector2(0.3*s*way,0.0),centre+Vector2(-0.3*s*way,0.5*s)])
		draw_polyline(points,colour,maxf(1.0,1.4*px),true)

## A group's name in small caps, between the rows.
class Group extends Control:
	var text := ""
	var px := 1.0
	var font: FontVariation

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var caps := Worlds.caps_size(13.0*px)
		font.spacing_glyph = roundi(13.0*px*0.26)
		draw_string(font,Vector2(roundf(12.0*px),roundf(size.y-5.0*px)),Worlds.caps(text),HORIZONTAL_ALIGNMENT_LEFT,-1,caps,Worlds.MUTED)

## The dashed seam between parts of the sheet.
class Seam extends Control:
	var px := 1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var line := maxf(1.0,roundf(px))
		var y := roundf(size.y*0.5)+0.5*line
		Linen.dashed(self,PackedVector2Array([Vector2(6.0*px,y),Vector2(size.x-6.0*px,y)]),DIVIDER,line,3.0*px,3.0*px)

class Sheet extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_scrim.color = SCRIM
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_scrim)
	add_child(_sheet)
	_sheet.add_child(_cloth)
	for label: Label in [kicker,heading]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sheet.add_child(label)
	kicker.add_theme_font_override("font",_caps_font)
	kicker.add_theme_color_override("font_color",Worlds.MUTED)
	kicker.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	heading.add_theme_font_override("font",_row_font)
	heading.add_theme_color_override("font_color",Worlds.INK)
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font",_note_font)
	hint.add_theme_color_override("font_color",Worlds.MUTED)
	_sheet.add_child(hint)
	Pad.hub.device_changed.connect(_device_changed)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout)
	_layout()

func _exit_tree() -> void:
	if Pad.hub.device_changed.is_connected(_device_changed): Pad.hub.device_changed.disconnect(_device_changed)

func _device_changed(_pad: bool) -> void:
	for row: Row in rows: row.queue_redraw()

## The kicker over the heading, and the heading.
func set_title(kicker_text: String, heading_text: String) -> void:
	kicker.text = Worlds.caps(kicker_text)
	heading.text = heading_text
	heading.visible = not heading_text.is_empty()
	_layout()

## The hint line under the rows: `keys` with the keyboard and mouse, `pad`
## (with "{A}" and the like) with the pad.
func set_hint(keys: String, pad: String) -> void:
	hint.text = keys
	hint.alternates = {keys:pad}
	_layout()

## An action row; `key` names its key on the right ("Esc"), `pad_glyph` the
## pad's ("B").
func add_row(text: String, action: Callable, key := "", pad_glyph := "") -> Row:
	var row := _row(text)
	row.key = key
	row.pad_glyph = pad_glyph
	row.pressed.connect(action)
	return row

## A choice row: `options` (names), `chosen` now; `on_step(index)` when it
## steps.
func add_choice(text: String, options: Array, chosen: int, on_step: Callable) -> Row:
	var row := _row(text)
	row.choices = options
	row.chosen = clampi(chosen,0,options.size()-1)
	row.on_step = on_step
	row.pressed.connect(func() -> void: row.step(1))
	return row

func add_group(text: String) -> void:
	var group := Group.new()
	group.text = text
	group.font = _caps_font.duplicate() as FontVariation
	_sheet.add_child(group)
	_items.append(group)
	_layout()

func add_seam() -> void:
	var seam := Seam.new()
	_sheet.add_child(seam)
	_items.append(seam)
	_layout()

func _row(text: String) -> Row:
	var row := Row.new()
	row.text = text
	row.font = _row_font
	row.caps_font = _caps_font.duplicate() as FontVariation
	row.value_font = _value_font
	row.glyph_font = _caps_font
	row.focus_mode = Control.FOCUS_ALL
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus","disabled","hover_pressed"]: row.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for colour in ["font_color","font_hover_color","font_focus_color","font_pressed_color","font_hover_pressed_color","font_disabled_color"]:
		row.add_theme_color_override(colour,Color.TRANSPARENT)
	row.add_theme_font_size_override("font_size",1)
	row.mouse_entered.connect(func() -> void: if row.is_visible_in_tree(): row.grab_focus())
	row.focus_entered.connect(row.queue_redraw)
	row.focus_exited.connect(row.queue_redraw)
	_sheet.add_child(row)
	rows.append(row)
	_items.append(row)
	_layout()
	return row

## Shows the sheet, `first` (else the first shown row) in reach.
func open(first: Row = null) -> void:
	show()
	_layout()
	var at := first if first != null and first.visible else null
	if at == null:
		for row: Row in rows:
			if row.visible:
				at = row
				break
	if at != null and is_inside_tree(): at.grab_focus()
	if _fade: _fade.kill()
	modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(self,"modulate:a",1.0,FADE)

func close() -> void:
	if _fade: _fade.kill()
	var focus := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focus != null and is_ancestor_of(focus): focus.release_focus()
	hide()

## The row in reach, or null.
func focused() -> Row:
	if not is_inside_tree(): return null
	var focus := get_viewport().gui_get_focus_owner()
	return focus as Row if focus is Row and is_ancestor_of(focus) else null

## The rows shown, top to bottom.
func shown_rows() -> Array[Row]:
	var out: Array[Row] = []
	for row: Row in rows:
		if row.visible: out.append(row)
	return out

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		cancelled.emit()
	elif event.is_action_pressed("ui_up",true) or event.is_action_pressed("ui_down",true):
		get_viewport().set_input_as_handled()
		var order := shown_rows()
		if order.is_empty(): return
		var at := order.find(focused())
		var step := -1 if event.is_action("ui_up") else 1
		order[0 if at < 0 else clampi(at+step,0,order.size()-1)].grab_focus()
	elif event.is_action_pressed("ui_left",true) or event.is_action_pressed("ui_right",true):
		# Taken either way, so focus doesn't wander sideways off the rows.
		get_viewport().set_input_as_handled()
		var row := focused()
		if row != null: row.step(-1 if event.is_action("ui_left") else 1)

## Whatever the sheet's rows leave, the world behind doesn't get.
func _unhandled_input(_event: InputEvent) -> void:
	if is_visible_in_tree(): get_viewport().set_input_as_handled()

## Stacks the sheet in design pixels and centres it.
func _layout() -> void:
	if not is_inside_tree(): return
	var px := Linen.scale_for(size)
	_px = px
	var width := roundf(WIDTH*px)
	var left := PAD.y*px
	var inner := width-PAD.y*px*2.0
	var y := PAD.x*px
	var kicker_size := maxi(1,roundi(13.0*px))
	_caps_font.spacing_glyph = roundi(13.0*px*0.26)
	kicker.add_theme_font_size_override("font_size",Worlds.caps_size(13.0*px))
	y = _place(kicker,left+12.0*px,y,inner-24.0*px,_caps_font.get_height(kicker_size))+8.0*px
	if heading.visible:
		var heading_size := maxi(1,roundi(30.0*px))
		heading.add_theme_font_size_override("font_size",heading_size)
		y = _place(heading,left+12.0*px,y,inner-24.0*px,_row_font.get_height(heading_size))+14.0*px
	var row_height := row_pad*2.0*px+_row_font.get_height(maxi(1,roundi(row_text*px)))
	for item: Control in _items:
		if not item.visible: continue
		if item is Row:
			(item as Row).px = px
			(item as Row).text_size = row_text
			(item as Row).pad_y = row_pad
			y = _place(item,left,y,inner,row_height)+GAP*px
		elif item is Group:
			(item as Group).px = px
			y = _place(item,left,y+6.0*px,inner,22.0*px)+GAP*px
		elif item is Seam:
			(item as Seam).px = px
			y = _place(item,left,y,inner,SEAM*px)+GAP*px
		item.queue_redraw()
	var hint_size := maxi(1,roundi(15.0*px))
	hint.add_theme_font_size_override("font_size",hint_size)
	hint.visible = not hint.text.is_empty()
	if hint.visible: y = _place(hint,left,y+6.0*px,inner,_note_font.get_height(hint_size)+8.0*px)
	y += PAD.z*px
	_sheet.size = Vector2(width,roundf(y))
	_sheet.position = ((size-_sheet.size)*0.5).round()
	_place_cloth(Rect2(Vector2.ZERO,_sheet.size),px)

func _place(control: Control, x: float, y: float, w: float, h: float) -> float:
	control.position = Vector2(roundf(x),roundf(y))
	control.size = Vector2(roundf(w),roundf(h))
	return y+h

## The shared cloth in the pause panel's linen, with its deeper shadow.
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
