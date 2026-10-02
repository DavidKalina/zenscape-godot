extends Control
## The field notes (docs/scenic/first-steps.md): a page off the pause panel
## that lists everything the hand can do. A verb the player has found reads in
## full, its name and how it is done; one not found yet is a faint dashed
## outline with only its clue, the way the materials tray shows specimens not
## found yet. It reads scripts/first_steps.gd (VERBS, GROUPS, `found`) and
## only shows and asks; the game wiring mounts it and hides the pause panel.
##
## One column in the pause panel's linen, wider, that scrolls: the lines are
## sentences that wrap, and a column keeps the groups in reading order.
## Lengths are design pixels at the 1440-wide frame, times scripts/hud_linen.gd
## `scale_for`. Keys: Up/Down (and PageUp/PageDown, or the wheel) scroll; Down
## past the end steps on to "Walk me through it again" and Back, Up steps back
## into the list. Enter activates, Esc goes back. A verb found while the page
## is open updates it. The page works while the tree is paused.

## Back was chosen (Esc or the Back row); the page is already closed.
signal closed
## "Walk me through it again" was chosen, after `restart` on the model.
signal walk_requested

const Worlds = preload("res://scripts/worlds_style.gd")
const Linen = preload("res://scripts/hud_linen.gd")
const Pause = preload("res://scripts/pause_panel.gd")
const FirstSteps = preload("res://scripts/first_steps.gd")
const SCRIM := Color(20/255.0,18/255.0,26/255.0,0.42)
const CLOTH := Color(84/255.0,75/255.0,63/255.0,0.9)
const SHADOW := Color(10/255.0,8/255.0,12/255.0,0.45)
const DIVIDER := Color(227/255.0,215/255.0,189/255.0,0.3)
## An unfound row's dashed outline and clue.
const OUTLINE := Color(227/255.0,215/255.0,189/255.0,0.3)
const BAR := Color(227/255.0,215/255.0,189/255.0,0.28)
## The panel's width and padding (top, sides, bottom), its margin to the
## window's edge, the gap between rows, and the fade in, seconds.
const WIDTH := 560.0
const PAD := Vector3(30.0,22.0,22.0)
const MARGIN := 40.0
const GAP := 4.0
const FADE := 0.15
## Scroll: one Up/Down press or wheel notch, in design pixels.
const STEP := 48.0
const NOTCH := 64.0

var is_open := false
var kicker := Label.new()
var count_label := Label.new()
var walk_row := Pause.Row.new()
var back_row := Pause.Row.new()
## Verb id -> its row, and the headings in order, as last built.
var entries := {}
var headings: Array[Heading] = []
var scroll := 0.0
var _steps: Node
var _scrim := ColorRect.new()
var _sheet := Sheet.new()
var _cloth := Linen.Cloth.new()
var _view := Control.new()
var _content := Control.new()
var _fade: Tween
var _px := 1.0
var _content_height := 0.0
var _name_font := Worlds.newsreader(400)
var _caps_font := Worlds.newsreader(500)
var _body_font := Worlds.spectral()
var _note_font := Worlds.spectral_italic()

## A verb's row. Found: its name (Newsreader 21) over its line (Spectral 15).
## Not found: a dashed outline round the clue alone, in italic.
class Entry extends Control:
	var id := ""
	var found := false
	## The name ("" until found) and the words under it: the line, or the clue.
	var title := ""
	var body := ""
	var px := 1.0
	var name_font: FontVariation
	var line_font: FontVariation
	var clue_font: FontVariation
	var _body_height := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## The height this row needs at `width`; keeps the wrapped body's size.
	func fit(width: float) -> float:
		var font := line_font if found else clue_font
		var line_size := maxi(1,roundi(15.0*px))
		_body_height = font.get_multiline_string_size(body,HORIZONTAL_ALIGNMENT_LEFT,width-24.0*px,line_size).y
		if not found: return 20.0*px+_body_height
		return 18.0*px+name_font.get_height(maxi(1,roundi(21.0*px)))+2.0*px+_body_height

	func _draw() -> void:
		var line_size := maxi(1,roundi(15.0*px))
		var wrap := size.x-24.0*px
		if not found:
			Linen.dashed_round(self,Rect2(Vector2.ONE*0.5*px,size-Vector2.ONE*px),9.0*px,OUTLINE,maxf(1.0,roundf(px)),px)
			draw_multiline_string(clue_font,Vector2(roundf(12.0*px),roundf(10.0*px+clue_font.get_ascent(line_size))),body,HORIZONTAL_ALIGNMENT_LEFT,wrap,line_size,-1,Worlds.MUTED)
			return
		var name_size := maxi(1,roundi(21.0*px))
		var top := 9.0*px
		draw_string(name_font,Vector2(roundf(12.0*px),roundf(top+name_font.get_ascent(name_size))),title,HORIZONTAL_ALIGNMENT_LEFT,wrap,name_size,Worlds.INK)
		top += name_font.get_height(name_size)+2.0*px
		draw_multiline_string(line_font,Vector2(roundf(12.0*px),roundf(top+line_font.get_ascent(line_size))),body,HORIZONTAL_ALIGNMENT_LEFT,wrap,line_size,-1,Worlds.SECONDARY_LINEN)

## A group's heading: small caps, muted.
class Heading extends Control:
	var text := ""
	var px := 1.0
	var font: FontVariation

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var caps := Worlds.caps_size(13.0*px)
		font.spacing_glyph = roundi(13.0*px*0.26)
		draw_string(font,Vector2(roundf(12.0*px),roundf(size.y-5.0*px-font.get_descent(caps))),Worlds.caps(text),HORIZONTAL_ALIGNMENT_LEFT,-1,caps,Worlds.MUTED)

## The panel: its cloth lies behind; it draws the dashed divider above the
## foot and the scroll bar.
class Sheet extends Control:
	var divider := Vector3()  # x from, x to, y
	var bar := Rect2()
	var px := 1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var line := maxf(1.0,roundf(px))
		var y := divider.z+0.5*line
		Linen.dashed(self,PackedVector2Array([Vector2(divider.x,y),Vector2(divider.y,y)]),DIVIDER,line,3.0*px,3.0*px)
		if bar.size.y > 0.0: Linen.fill_round(self,bar,bar.size.x*0.5,BAR)

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_scrim.color = SCRIM
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_scrim)
	add_child(_sheet)
	_sheet.add_child(_cloth)
	for label: Label in [kicker,count_label]:
		_sheet.add_child(label)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kicker.text = Worlds.caps("Field notes")
	kicker.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	kicker.add_theme_font_override("font",_caps_font)
	kicker.add_theme_color_override("font_color",Worlds.MUTED)
	count_label.add_theme_font_override("font",_name_font)
	count_label.add_theme_color_override("font_color",Worlds.INK)
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(_view)
	_view.add_child(_content)
	for entry: Array in [[walk_row,"Walk me through it again",_walk],[back_row,"Back",_back]]:
		var row: Pause.Row = entry[0]
		row.font = _name_font
		row.hint_font = _caps_font.duplicate() as FontVariation
		_button(row,entry[1],entry[2],_sheet)
	back_row.hint = "Esc"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout)
	_layout()

## A Button that draws itself, as in the pause panel.
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

## Shows the page for the model `steps` (scripts/first_steps.gd), from the top,
## with focus in the list. Without a model (classic controls, no First steps)
## there is nothing to list, and nothing happens: the pause panel should not
## offer the row (its `notes_available`).
func open(steps: Node) -> void:
	if steps == null: return
	if _steps != null and _steps.verb_found.is_connected(_on_found): _steps.verb_found.disconnect(_on_found)
	_steps = steps
	_steps.verb_found.connect(_on_found)
	scroll = 0.0
	is_open = true
	show()
	_build()
	if is_inside_tree():
		var focus := get_viewport().gui_get_focus_owner()
		if focus != null and is_ancestor_of(focus): focus.release_focus()
	if _fade: _fade.kill()
	modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(self,"modulate:a",1.0,FADE)

func close() -> void:
	is_open = false
	if _fade: _fade.kill()
	if _steps != null and _steps.verb_found.is_connected(_on_found): _steps.verb_found.disconnect(_on_found)
	var focus := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focus != null and is_ancestor_of(focus): focus.release_focus()
	hide()

## How many verbs are found, of how many.
func found_count() -> int:
	var count := 0
	for id: String in FirstSteps.VERBS:
		if bool(_steps.found.get(id,false)): count += 1
	return count

func _on_found(_id: String) -> void:
	if is_open: _build()

## Makes a row for every verb, grouped, under the headings, and sets the
## count. Keeps the scroll.
func _build() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.free()
	entries.clear()
	headings.clear()
	for group: Array in FirstSteps.GROUPS:
		var heading := Heading.new()
		heading.text = group[1]
		heading.font = _caps_font
		_content.add_child(heading)
		headings.append(heading)
		for id: String in FirstSteps.VERBS:
			var verb: Dictionary = FirstSteps.VERBS[id]
			if verb["group"] != group[0]: continue
			var entry := Entry.new()
			entry.id = id
			entry.found = bool(_steps.found.get(id,false))
			entry.title = verb["name"] if entry.found else ""
			entry.body = verb["line"] if entry.found else verb["clue"]
			entry.name_font = _name_font
			entry.line_font = _body_font
			entry.clue_font = _note_font
			_content.add_child(entry)
			entries[id] = entry
	count_label.text = "%d of %d found" % [found_count(),FirstSteps.VERBS.size()]
	_layout()

## Scrolls the list by `by` design pixels (negative goes up), within its ends.
func scroll_by(by: float) -> void:
	scroll = clampf(scroll+by*_px,0.0,maxf(0.0,_content_height-_view.size.y))
	_content.position.y = -roundf(scroll)
	_update_bar()

func _update_bar() -> void:
	var track := _view.size.y
	if _content_height <= track or track <= 0.0:
		_sheet.bar = Rect2()
	else:
		var thumb := maxf(24.0*_px,track*track/_content_height)
		var width := maxf(2.0,roundf(3.0*_px))
		_sheet.bar = Rect2(_view.position.x+_view.size.x-width,_view.position.y+(track-thumb)*scroll/(_content_height-track),width,thumb)
	_sheet.queue_redraw()

func _walk() -> void:
	_steps.restart()
	walk_requested.emit()

func _back() -> void:
	close()
	closed.emit()

func _at_foot() -> bool:
	return scroll >= maxf(0.0,_content_height-_view.size.y)-0.5

func _input(event: InputEvent) -> void:
	if not is_open: return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()
	elif event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		get_viewport().set_input_as_handled()
		scroll_by(-NOTCH if event.button_index == MOUSE_BUTTON_WHEEL_UP else NOTCH)
	elif event.is_action_pressed("ui_page_up",true) or event.is_action_pressed("ui_page_down",true):
		get_viewport().set_input_as_handled()
		scroll_by((-1.0 if event.is_action("ui_page_up") else 1.0)*_view.size.y*0.9/_px)
	elif event.is_action_pressed("ui_up",true) or event.is_action_pressed("ui_down",true):
		get_viewport().set_input_as_handled()
		var down := event.is_action("ui_down")
		var focus := get_viewport().gui_get_focus_owner()
		if focus == back_row:
			if not down: walk_row.grab_focus()
		elif focus == walk_row:
			if down: back_row.grab_focus()
			else: walk_row.release_focus()
		elif down and _at_foot(): walk_row.grab_focus()
		else: scroll_by(STEP if down else -STEP)

## Whatever the page's controls leave, the world behind does not get.
func _unhandled_input(_event: InputEvent) -> void:
	if is_open: get_viewport().set_input_as_handled()

## Stacks the page in design pixels: header, the list in a clipped view, a
## dashed divider, then the foot (Walk me through it again, Back), and
## centres the panel. The panel is as tall as the rows need, up to the window
## less its margin.
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
	var count_size := maxi(1,roundi(30.0*px))
	count_label.add_theme_font_size_override("font_size",count_size)
	y = _place(count_label,left+12.0*px,y,inner-24.0*px,_name_font.get_height(count_size))+14.0*px
	# The list, at its full height inside the view's width.
	var bar_room := 10.0*px
	var column := inner-bar_room
	var at := 0.0
	var first := true
	for child in _content.get_children():
		if child is Heading:
			var heading := child as Heading
			heading.px = px
			if not first: at += 12.0*px
			var heading_height := _caps_font.get_height(Worlds.caps_size(13.0*px))+9.0*px
			at = _place(heading,0.0,at,column,heading_height)
		elif child is Entry:
			var entry := child as Entry
			entry.px = px
			at = _place(entry,0.0,at,column,entry.fit(column))+GAP*px
		child.queue_redraw()
		first = false
	_content_height = maxf(0.0,at-GAP*px)
	var foot := 20.0*px+_name_font.get_height(maxi(1,roundi(21.0*px)))
	var chrome := y+17.0*px+foot+GAP*px+PAD.z*px
	var height := minf(chrome+_content_height,maxf(size.y-MARGIN*2.0*px,chrome+96.0*px))
	_view.position = Vector2(roundf(left),roundf(y))
	_view.size = Vector2(roundf(inner),roundf(height-chrome))
	_content.size = Vector2(column,_content_height)
	y = _view.position.y+_view.size.y
	_sheet.divider = Vector3(roundf(left+6.0*px),roundf(left+inner-6.0*px),roundf(y+8.0*px))
	y += 17.0*px
	var walk_width := roundf(inner*0.64)
	walk_row.px = px
	back_row.px = px
	_place(walk_row,left,y,walk_width,foot)
	_place(back_row,left+walk_width+GAP*px,y,inner-walk_width-GAP*px,foot)
	_sheet.px = px
	_sheet.size = Vector2(width,roundf(height))
	_sheet.position = ((size-_sheet.size)*0.5).round()
	_place_cloth(Rect2(Vector2.ZERO,_sheet.size),px)
	scroll_by(0.0)
	for control: Control in [walk_row,back_row]: control.queue_redraw()

## Places `control` at `x`,`y` (rounded), `w` by `h`; returns its foot.
func _place(control: Control, x: float, y: float, w: float, h: float) -> float:
	control.position = Vector2(roundf(x),roundf(y))
	control.size = Vector2(roundf(w),roundf(h))
	return y+h

## The shared cloth, tinted as the pause panel's.
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
