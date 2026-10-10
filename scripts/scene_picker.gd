extends Control
## The scene picker, behind the title's quiet "Scenes" (studies/cozy_worlds.gd
## `open_scene_picker`; docs/design/scene-picker.md): every scene the
## run-*.command launchers open, from the game, on the title's linen card.
## One column a group of scripts/scene_catalog.gd, a row an entry; the row in
## reach says what it is under the columns. Mouse, arrows and the pad's D-pad
## or stick walk the rows; Return, Space or A opens one; Esc or B (or Back
## on the card's foot) goes back to the title.
##
## Opening a scene hands its flags over through scripts/launch_args.gd and
## changes scene; scripts/scene_return.gd brings you back (hold Esc, or View
## and Menu on the pad).

signal closed
## An entry was picked; with nobody listening, `open_entry` opens it.
signal picked(entry: Dictionary)

const Catalog = preload("res://scripts/scene_catalog.gd")
const Title = preload("res://scripts/title_screen.gd")
const Linen = preload("res://scripts/hud_linen.gd")
const PadPrompt = preload("res://scripts/pad_prompt.gd")
const Pad = preload("res://scripts/pad.gd")
const DISPLAY = preload("res://assets/fonts/newsreader-latin.woff2")
const READING = preload("res://assets/fonts/spectral-latin-400.woff2")

## Design pixels, as the title's (1180 x 613 frame): the card's top and width,
## its padding, a column's gap, a row's height and gap, a group's heading.
const FRAME := Vector2(1180.0,613.0)
const CARD_TOP := 150.0
const CARD_WIDTH := 1080.0
const PAD := 12.0
const COLUMN_GAP := 14.0
const ROW := 40.0
const ROW_GAP := 2.0
const HEADING := 30.0
const DETAIL := 40.0
const FOOT := 34.0

## Every entry's row, in catalogue order; `entry_of` maps back.
var rows: Array[Button] = []
var back_button: Button
var entry_of := {}
var _card := Linen.Cloth.new()
var _headings: Array[Dictionary] = []
var _detail := Label.new()
var _hint := PadPrompt.new()
var _mark := Label.new()
var _scrim := ColorRect.new()
var _sheet := Control.new()
var _px := 1.0
var _elapsed := 0.0
var _focused: Button

func _ready() -> void:
	Pad.ensure()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/title_scrim.gdshader")
	_scrim.material = material
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Everything on the card is on the sheet, over the scrim; the cloth lies
	# under the sheet's own drawing (the headings, the seam).
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sheet)
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sheet.draw.connect(_draw_sheet)
	_sheet.add_child(_card)
	var inscription := FontVariation.new()
	inscription.base_font = DISPLAY
	inscription.variation_opentype = {"wght":500.0}
	inscription.spacing_glyph = 10
	_mark.text = "SCENES"
	_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.add_theme_font_override("font",inscription)
	_mark.add_theme_color_override("font_color",Color("e3d7bd"))
	_mark.add_theme_color_override("font_shadow_color",Color(0,0,0,0.25))
	_mark.add_theme_constant_override("shadow_offset_y",1)
	_sheet.add_child(_mark)
	for group: String in Catalog.groups():
		_headings.append({"text":group})
		for entry: Dictionary in Catalog.in_group(group):
			var row := _entry(str(entry.title),false)
			row.pressed.connect(open_entry.bind(entry))
			row.set_meta("scene_entry",entry.id)
			entry_of[row] = entry
			rows.append(row)
	back_button = _entry("Back",true)
	back_button.pressed.connect(close)
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_theme_font_override("font",READING)
	_detail.add_theme_color_override("font_color",Color(Linen.INK,0.86))
	_sheet.add_child(_detail)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_override("font",READING)
	_hint.add_theme_color_override("font_color",Color(Linen.INK,0.62))
	_hint.text = "Esc back  ·  in a scene, hold Esc for the title"
	_hint.alternates = {_hint.text:"{B} back  ·  in a scene, hold {VIEW} + {MENU} for the title"}
	_sheet.add_child(_hint)
	_link_focus()
	resized.connect(_layout)
	_layout()

func _entry(text: String, quiet: bool) -> Button:
	var button := Title.Entry.new()
	button.text = text
	button.quiet = quiet
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus","disabled","hover_pressed"]:
		button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for colour in ["font_color","font_hover_color","font_focus_color","font_pressed_color","font_hover_pressed_color","font_disabled_color"]:
		button.add_theme_color_override(colour,Color.TRANSPARENT)
	button.focus_entered.connect(func() -> void:
		_focused = button
		_show_detail()
		for row: Button in rows: row.queue_redraw()
		back_button.queue_redraw())
	button.focus_exited.connect(button.queue_redraw)
	button.mouse_entered.connect(func() -> void: if button.is_visible_in_tree(): button.grab_focus())
	_sheet.add_child(button)
	return button

## The rows' neighbours, set outright so the focus never leaves the card for
## the title's entries faded out under it: up and down within a column (the
## last row's down is Back), left and right to the nearest row of the next
## column over.
func _link_focus() -> void:
	var columns: Array = []
	for group: String in Catalog.groups():
		var column: Array[Button] = []
		for row: Button in rows:
			if entry_of[row].group == group: column.append(row)
		columns.append(column)
	for c in columns.size():
		var column: Array = columns[c]
		for r in column.size():
			var row: Button = column[r]
			row.focus_neighbor_top = row.get_path_to(column[r-1] if r > 0 else row)
			row.focus_neighbor_bottom = row.get_path_to(column[r+1] if r+1 < column.size() else back_button)
			var left: Array = columns[c-1] if c > 0 else column
			var right: Array = columns[c+1] if c+1 < columns.size() else column
			row.focus_neighbor_left = row.get_path_to(left[mini(r,left.size()-1)])
			row.focus_neighbor_right = row.get_path_to(right[mini(r,right.size()-1)])
	for i in rows.size():
		rows[i].focus_next = rows[i].get_path_to(rows[i+1] if i+1 < rows.size() else back_button)
		rows[i].focus_previous = rows[i].get_path_to(rows[i-1] if i > 0 else back_button)
	back_button.focus_neighbor_top = back_button.get_path_to(columns[0][columns[0].size()-1])
	for side in ["focus_neighbor_bottom","focus_neighbor_left","focus_neighbor_right"]:
		back_button.set(side,back_button.get_path_to(back_button))
	back_button.focus_next = back_button.get_path_to(rows[0])
	back_button.focus_previous = back_button.get_path_to(rows[rows.size()-1])

## Shows the picker with the first row (or `id`'s) in reach.
func present(id := "") -> void:
	show()
	modulate.a = 0.0
	create_tween().tween_property(self,"modulate:a",1.0,0.25)
	var at := rows[0]
	for row: Button in rows:
		if entry_of[row].id == id: at = row
	at.grab_focus()

func close() -> void:
	if not visible: return
	hide()
	closed.emit()

## Opens `entry`: the owner's, if it listens to `picked`, else straight away.
func open_entry(entry: Dictionary) -> void:
	if picked.get_connections().is_empty(): Catalog.open(get_tree(),entry)
	else: picked.emit(entry)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()

func _show_detail() -> void:
	if _focused == back_button: _detail.text = "Back to the title."
	elif entry_of.has(_focused):
		var entry: Dictionary = entry_of[_focused]
		var args := " ".join(PackedStringArray(entry.args))
		_detail.text = str(entry.detail)+("   ·   "+args if not args.is_empty() else "")

func _layout() -> void:
	_px = minf(minf(size.x/FRAME.x,size.y/FRAME.y),1.75)
	var px := _px
	var origin := Vector2(roundf((size.x-FRAME.x*px)*0.5),0.0)
	var at := func(x: float, y: float) -> Vector2: return (origin+Vector2(x,y)*px).round()
	_mark.position = at.call(0.0,62.0)
	_mark.size = (Vector2(FRAME.x,60.0)*px).round()
	_mark.add_theme_font_size_override("font_size",maxi(1,roundi(40.0*px)))
	(_mark.get_theme_font("font") as FontVariation).spacing_glyph = roundi(10.0*px)
	var groups := Catalog.groups()
	var left := (FRAME.x-CARD_WIDTH)*0.5
	var inner := CARD_WIDTH-PAD*2.0
	var column_width := (inner-COLUMN_GAP*(groups.size()-1))/groups.size()
	var deepest := 0.0
	for g in groups.size():
		var x := left+PAD+g*(column_width+COLUMN_GAP)
		_headings[g]["x"] = x+column_width*0.5
		var y := CARD_TOP+PAD+HEADING
		for row: Button in rows:
			if entry_of[row].group != groups[g]: continue
			row.position = at.call(x,y)
			row.size = (Vector2(column_width,ROW)*px).round()
			(row as Title.Entry).px = px
			y += ROW+ROW_GAP
		deepest = maxf(deepest,y-ROW_GAP)
	var detail_top := deepest+10.0
	_detail.position = at.call(left+PAD+22.0,detail_top)
	_detail.size = (Vector2(inner-44.0,DETAIL)*px).round()
	_detail.add_theme_font_size_override("font_size",maxi(1,roundi(15.0*px)))
	var foot_top := detail_top+DETAIL+6.0
	_headings_y = CARD_TOP+PAD+HEADING*0.62
	_foot_y = foot_top
	var tag_font := Linen.tag_font()
	back_button.position = at.call(left+PAD,foot_top)
	back_button.size = (Vector2(Linen.tag_width(tag_font,back_button.text,1.0)+32.0,FOOT)*px).round()
	(back_button as Title.Entry).px = px
	_hint.position = at.call(left+PAD+200.0,foot_top+7.0)
	_hint.size = (Vector2(inner-200.0-10.0,22.0)*px).round()
	_hint.add_theme_font_size_override("font_size",maxi(1,roundi(13.0*px)))
	var card := Rect2(at.call(left,CARD_TOP),(Vector2(CARD_WIDTH,foot_top+FOOT+PAD-CARD_TOP)*px).round())
	_card.place(card,px)
	_origin = origin
	_sheet.queue_redraw()

var _headings_y := 0.0
var _foot_y := 0.0
var _origin := Vector2.ZERO

## The groups' names over their columns and the seam over the foot, as the
## title card's small caps and stitch.
func _draw_sheet() -> void:
	var sheet := _sheet
	var px := _px
	var tag_font := Linen.tag_font()
	for heading: Dictionary in _headings:
		if not heading.has("x"): continue
		Linen.tag(sheet,tag_font,str(heading.text),roundf(_origin.x+float(heading.x)*px),roundf(_headings_y*px),px,0.78)
	var line := maxf(1.0,roundf(px))
	var left := _origin.x+((FRAME.x-CARD_WIDTH)*0.5+PAD+6.0)*px
	var right := _origin.x+((FRAME.x+CARD_WIDTH)*0.5-PAD-6.0)*px
	for y_design: float in [_foot_y-8.0]:
		for k in [-1.5,1.5]:
			var y := roundf(y_design*px+k*px)
			Linen.dashed(sheet,PackedVector2Array([Vector2(left,y),Vector2(right,y)]),Linen.DIVIDER,line,3.0*px,3.0*px)

func _process(delta: float) -> void:
	if not visible or _focused == null: return
	_elapsed += delta
	# The resting stitch breathes, as on the title.
	(_focused as Title.Entry).breath = sin(_elapsed*TAU/5.2)*0.5+0.5
	_focused.queue_redraw()
