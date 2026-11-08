extends Control
## One of the shell's screens (pause, settings, controls, credits): a column
## of rows drawn in the title's look (scripts/endless/main_menu.gd: Spectral
## for the words, Newsreader small caps for headings and the foot, the INK,
## the gilt title between hairlines, the picked row's dark band and dashed
## stitch) over a dark veil on the held game or the meadow.
##
## Rows are Dictionaries, by `kind`:
## heading {text}; button {text, act}; toggle {text, get, set};
## slider {text, get, set, lo, hi, step, fmt}; choice {text, get, set, names};
## note {text} (wrapped); keys {text, keys: Array, pad: Array} (a key list and
## pad glyph ids); line {text, small, dim, url} (credits); gap {}.
## Up and down (keys, d-pad, stick) move between the rows that take a pick
## (and scroll the rest); left and right step a slider or a choice; accept
## acts; cancel (Esc, B) asks `back`; the pad's Menu asks `menu`. The mouse
## picks by hovering, clicks, drags a slider, and its wheel scrolls.

signal back
signal menu

const MainMenu = preload("res://scripts/endless/main_menu.gd")
const Pad = preload("res://scripts/pad.gd")
const READING := MainMenu.READING
const DISPLAY := MainMenu.DISPLAY
const INK := MainMenu.INK
const HAIR := MainMenu.HAIR
const FRAME := MainMenu.FRAME
const BAND := Color(0.039,0.031,0.016,0.24)
const VEIL := Color(0.035,0.04,0.045,0.6)
const PICKABLE := ["button","toggle","slider","choice"]
const STEP_SCROLL := 40.0

## The title, the column's width (design px), how big a button row's words are.
var title := ""
var width := 600.0
var button_size := 22
var button_height := 44.0
## The foot's word ("BACK"; "" for none).
var foot := "BACK"
var rows: Array = []
var selected := -1
var active := false

var _px := 1.0
var _scroll := 0.0
var _tops: Array[float] = []
var _heights: Array[float] = []
var _content := 0.0
var _hover := -1
var _foot_hover := false
var _dragging := -1
var _title := Label.new()
var _gilt := ShaderMaterial.new()
var _caps := FontVariation.new()
var _display := FontVariation.new()

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_caps.base_font = DISPLAY
	_caps.variation_opentype = {"wght":500.0}
	_display.base_font = DISPLAY
	_display.variation_opentype = {"wght":500.0}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.text = title.to_upper()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_theme_font_override("font",_display)
	_title.add_theme_color_override("font_color",Color.WHITE)
	_title.add_theme_color_override("font_shadow_color",Color(0,0,0,0.3))
	_title.add_theme_constant_override("shadow_offset_y",1)
	_gilt.shader = preload("res://shaders/title_gilt.gdshader")
	_title.material = _gilt
	add_child(_title)
	resized.connect(_layout)
	_layout()

## Shown and taking input, the first pickable row picked.
func open() -> void:
	show()
	active = true
	_scroll = 0.0
	if selected < 0 or not _pickable(selected): selected = _next(-1,1)
	_layout()

func close() -> void:
	active = false
	hide()

func set_rows(r: Array) -> void:
	rows = r
	if selected >= rows.size() or (selected >= 0 and not _pickable(selected)): selected = _next(-1,1)
	_layout()

# --- Layout ---------------------------------------------------------------

func _layout() -> void:
	if not is_inside_tree(): return
	_px = clampf(minf(size.x/FRAME.x,size.y/FRAME.y),0.6,1.9)
	_title.position = Vector2(0,roundf(34*_px))
	_title.size = Vector2(size.x,roundf(60*_px))
	_title.add_theme_font_size_override("font_size",roundi(40*_px))
	_display.spacing_glyph = roundi(10*_px)
	_gilt.set_shader_parameter("glyph_scale",_px)
	_tops.clear()
	_heights.clear()
	var y := 0.0
	for r: Dictionary in rows:
		var h := _row_height(r)
		_tops.append(y)
		_heights.append(h)
		y += h
	_content = y
	_keep_in_view()
	queue_redraw()

func _row_height(r: Dictionary) -> float:
	match str(r.kind):
		"heading": return 40.0*_px
		"button": return button_height*_px
		"toggle","slider","choice": return 31.0*_px
		"keys": return 27.0*_px
		"gap": return 14.0*_px
		"note":
			var fs := roundi(15*_px)
			return READING.get_multiline_string_size(str(r.text),HORIZONTAL_ALIGNMENT_LEFT,width*_px,fs).y+12.0*_px
		"line":
			var fs := roundi((13 if r.get("small",false) else 18)*_px)
			return READING.get_multiline_string_size(str(r.text),HORIZONTAL_ALIGNMENT_LEFT,width*_px,fs).y+(4.0 if r.get("small",false) else 8.0)*_px
	return 30.0*_px

## The area rows are drawn in (px): under the title's hairline, over the foot.
func _area() -> Rect2:
	var top := roundf(106*_px)
	var bottom := size.y-roundf((58.0 if foot != "" else 30.0)*_px)
	var x := roundf((size.x-width*_px)*0.5)
	return Rect2(x,top,roundf(width*_px),maxf(0.0,bottom-top))

func _max_scroll() -> float:
	return maxf(0.0,_content-_area().size.y)

func _keep_in_view() -> void:
	var area := _area()
	if selected >= 0 and selected < _tops.size():
		var t := _tops[selected]
		var b := t+_heights[selected]
		if t-_scroll < 0.0: _scroll = t-(_heights[selected] if selected > 0 and rows[selected-1].kind == "heading" else 0.0)
		elif b-_scroll > area.size.y: _scroll = b-area.size.y
	_scroll = clampf(_scroll,0.0,_max_scroll())

## Row `i`'s rect on screen.
func row_rect(i: int) -> Rect2:
	var area := _area()
	return Rect2(area.position.x-14.0*_px,area.position.y+_tops[i]-_scroll,area.size.x+28.0*_px,_heights[i])

func _foot_rect() -> Rect2:
	var fs := roundi(13*_px)
	_caps.spacing_glyph = roundi(MainMenu.TRACK*13*_px)
	var w := _caps.get_string_size(foot,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x+_glyph_width("B",18.0*_px)+10.0*_px
	return Rect2(Vector2((size.x-w)*0.5-16.0*_px,size.y-48.0*_px),Vector2(w+32.0*_px,32.0*_px))

# --- Drawing --------------------------------------------------------------

func _process(_delta: float) -> void:
	if visible: queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),VEIL)
	var area := _area()
	# A darker field under the column, soft at its sides.
	var field := Rect2(area.position.x-60.0*_px,0,area.size.x+120.0*_px,size.y)
	for k in 6:
		var g := float(k)*10.0*_px
		draw_rect(Rect2(field.position.x+g,0,field.size.x-2.0*g,size.y),Color(0,0,0,0.045))
	var line := maxf(1.0,roundf(_px))
	# The title's hairlines, the title's own between them.
	for y: float in [roundf(30*_px),roundf(96*_px)]:
		_hairline(Vector2(size.x*0.5,y),roundf(200*_px),line,0.4)
	var breath := sin(Time.get_ticks_msec()*0.001*TAU/MainMenu.BREATH)*0.5+0.5
	for i in rows.size():
		var r := row_rect(i)
		if r.end.y < area.position.y-2.0 or r.position.y > area.end.y+2.0: continue
		_draw_row(i,rows[i],r,breath,line)
	# Fade the rows into the title and the foot when they scroll under them.
	if _max_scroll() > 0.0:
		var bar := Rect2(area.end.x+24.0*_px,area.position.y,line,area.size.y)
		draw_rect(bar,Color(INK,0.12))
		var h := bar.size.y*area.size.y/_content
		draw_rect(Rect2(bar.position.x-line,bar.position.y+(bar.size.y-h)*_scroll/_max_scroll(),line*3.0,h),Color(INK,0.45))
	if foot != "":
		var f := _foot_rect()
		if _foot_hover: draw_rect(f,BAND)
		var fs := roundi(13*_px)
		_caps.spacing_glyph = roundi(MainMenu.TRACK*13*_px)
		var x := f.position.x+16.0*_px
		var gw := _glyph(_back_glyph(),Vector2(x,f.get_center().y),18.0*_px)
		draw_string(_caps,Vector2(x+gw+10.0*_px,roundf(f.get_center().y+fs*0.36)),foot,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color(INK,0.95 if _foot_hover else 0.7))

func _back_glyph() -> String:
	return "B" if Pad.using_pad() else "ESC"

func _draw_row(i: int, row: Dictionary, r: Rect2, breath: float, line: float) -> void:
	var lit := i == selected and active
	var kind := str(row.kind)
	var inset := r.position.x+14.0*_px
	var right := r.end.x-14.0*_px
	if kind in PICKABLE and (lit or i == _hover):
		draw_rect(r,Color(BAND,BAND.a if lit else BAND.a*0.5))
	var stitch := Color(INK,0.3+0.55*breath)
	match kind:
		"heading":
			var fs := roundi(12*_px)
			_caps.spacing_glyph = roundi(MainMenu.TRACK*12*_px)
			var text := str(row.text).to_upper()
			var y := roundf(r.position.y+r.size.y-12.0*_px)
			draw_string(_caps,Vector2(inset,y),text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color(HAIR,0.85))
			var tw := _caps.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
			_rule(Vector2(inset+tw+14.0*_px,y-fs*0.35),Vector2(right,y-fs*0.35),line,0.3)
		"button":
			var fs := roundi(button_size*_px)
			var text := str(row.text)
			var tw := READING.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
			var at := Vector2(roundf(r.get_center().x-tw*0.5),roundf(r.get_center().y+fs*0.32))
			draw_string(READING,at+Vector2(0,line),text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color(0,0,0,0.35))
			draw_string(READING,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color(INK,1.0 if lit else 0.74))
			if lit: _dashed(Vector2(at.x-6.0*_px,at.y+8.0*_px),Vector2(at.x+tw+6.0*_px,at.y+8.0*_px),stitch,line,3.0*_px)
		"toggle","slider","choice":
			var fs := roundi(19*_px)
			var base := roundf(r.get_center().y+fs*0.32)
			var text := str(row.text)
			draw_string(READING,Vector2(inset,base+line),text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color(0,0,0,0.3))
			draw_string(READING,Vector2(inset,base),text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color(INK,1.0 if lit else 0.8))
			if lit:
				var tw := READING.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
				_dashed(Vector2(inset,base+7.0*_px),Vector2(inset+tw,base+7.0*_px),stitch,line,3.0*_px)
			_draw_value(row,kind,r,right,base,fs,lit,line)
		"note":
			var fs := roundi(15*_px)
			draw_multiline_string(READING,Vector2(inset,r.position.y+fs+4.0*_px),str(row.text),HORIZONTAL_ALIGNMENT_LEFT,r.size.x-28.0*_px,fs,-1,Color(INK,0.62))
		"line":
			var small: bool = row.get("small",false)
			var fs := roundi((13 if small else 18)*_px)
			var c := Color(INK,0.62 if row.get("dim",false) else (0.8 if small else 0.94))
			draw_multiline_string(READING,Vector2(inset,r.position.y+fs),str(row.text),HORIZONTAL_ALIGNMENT_LEFT,r.size.x-28.0*_px,fs,-1,c)
		"keys":
			var fs := roundi(17*_px)
			var mid := r.get_center().y
			draw_string(READING,Vector2(inset,roundf(mid+fs*0.32)),str(row.text),HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color(INK,0.88))
			var x := inset+r.size.x*0.40
			for k: String in row.get("keys",[]):
				if k in ["or","+","/","twice","hold","click"]:
					var sw := READING.get_string_size(k,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(14*_px)).x
					draw_string(READING,Vector2(x,roundf(mid+5.0*_px)),k,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(14*_px),Color(INK,0.5))
					x += sw+8.0*_px
				else: x += _keycap(k,Vector2(x,mid),22.0*_px)+6.0*_px
			x = inset+r.size.x*0.80
			for g: String in row.get("pad",[]):
				x += _glyph(g,Vector2(x,mid),22.0*_px)+6.0*_px

func _draw_value(row: Dictionary, kind: String, r: Rect2, right: float, base: float, fs: int, lit: bool, line: float) -> void:
	var vfs := roundi(17*_px)
	match kind:
		"toggle":
			var on := bool((row.get as Callable).call())
			var text := "On" if on else "Off"
			var tw := READING.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,vfs).x
			var box := Rect2(right-tw-30.0*_px,r.get_center().y-7.0*_px,14.0*_px,14.0*_px)
			draw_rect(box,Color(INK,0.7),false,line)
			if on: draw_rect(box.grow(-3.0*_px),Color(INK,0.95))
			draw_string(READING,Vector2(right-tw,base),text,HORIZONTAL_ALIGNMENT_LEFT,-1,vfs,Color(INK,0.95 if on else 0.55))
		"slider":
			var v := float((row.get as Callable).call())
			var t := inverse_lerp(float(row.lo),float(row.hi),v)
			var text: String = (row.fmt as Callable).call(v) if row.has("fmt") else str(roundi(v))
			draw_string(READING,Vector2(right-52.0*_px,base),text,HORIZONTAL_ALIGNMENT_LEFT,-1,vfs,Color(INK,0.95 if lit else 0.75))
			var track := _track(r)
			var y := r.get_center().y
			draw_line(Vector2(track.x,y),Vector2(track.y,y),Color(INK,0.25),line)
			draw_line(Vector2(track.x,y),Vector2(lerpf(track.x,track.y,t),y),Color(INK,0.85),line*2.0)
			draw_circle(Vector2(lerpf(track.x,track.y,t),y),(5.0 if lit else 4.0)*_px,Color(INK,1.0 if lit else 0.8))
		"choice":
			var names: Array = row.names
			var text := str(names[int((row.get as Callable).call())])
			var tw := READING.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,vfs).x
			var a := Color(INK,0.85 if lit else 0.35)
			draw_string(READING,Vector2(right-tw-18.0*_px,base),text,HORIZONTAL_ALIGNMENT_LEFT,-1,vfs,Color(INK,0.95 if lit else 0.75))
			_chevron(Vector2(right-tw-34.0*_px,r.get_center().y),-1.0,a,line)
			_chevron(Vector2(right-4.0*_px,r.get_center().y),1.0,a,line)

## A slider row's track (x from, x to).
func _track(r: Rect2) -> Vector2:
	var right := r.end.x-14.0*_px
	return Vector2(right-280.0*_px,right-70.0*_px)

func _chevron(at: Vector2, way: float, c: Color, line: float) -> void:
	var s := 5.0*_px
	draw_polyline(PackedVector2Array([at+Vector2(-way*s*0.6,-s),at+Vector2(way*s*0.6,0),at+Vector2(-way*s*0.6,s)]),c,line*1.5)

func _hairline(center: Vector2, half: float, line: float, alpha: float) -> void:
	var n := 24
	for k in n:
		var t0 := float(k)/n
		var t1 := float(k+1)/n
		var a := alpha*(1.0-absf((t0+t1)-1.0))
		draw_line(Vector2(center.x-half+2.0*half*t0,center.y),Vector2(center.x-half+2.0*half*t1,center.y),Color(HAIR,a),line)

func _rule(a: Vector2, b: Vector2, line: float, alpha: float) -> void:
	draw_line(a,b,Color(HAIR,alpha),line)

func _dashed(a: Vector2, b: Vector2, c: Color, w: float, dash: float) -> void:
	var length := a.distance_to(b)
	if length <= 0.0: return
	var dir := (b-a)/length
	var d := 0.0
	while d < length:
		draw_line(a+dir*d,a+dir*minf(d+dash,length),c,w)
		d += dash*2.0

## A key drawn as a cap (an outlined box, its name in small caps), its left
## edge at `at.x`, centred on `at.y`; its width.
func _keycap(text: String, at: Vector2, h: float) -> float:
	var fs := roundi(h*0.5)
	_caps.spacing_glyph = roundi(0.08*fs)
	var t := text.to_upper()
	var tw := _caps.get_string_size(t,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
	var w := maxf(h,tw+h*0.6)
	var box := Rect2(at.x,at.y-h*0.5,w,h)
	draw_rect(box,Color(0,0,0,0.25))
	draw_rect(box,Color(INK,0.55),false,maxf(1.0,roundf(_px)))
	draw_string(_caps,Vector2(roundf(at.x+(w-tw)*0.5),roundf(at.y+fs*0.36)),t,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color(INK,0.95))
	return w

func _glyph_width(id: String, h: float) -> float:
	if id in ["A","B","X","Y","LS","RS","L3","R3","UP","DOWN","LEFT","RIGHT","DPAD"]: return h
	var fs := roundi(h*0.45)
	return maxf(h,_caps.get_string_size(id,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x+h*0.7)

## A pad glyph (Pad.BUTTON_GLYPHS' ids): face buttons and sticks as rings,
## the d-pad as a cross with its arm lit, the rest as rounded tabs; its width.
func _glyph(id: String, at: Vector2, h: float) -> float:
	var line := maxf(1.0,roundf(_px))
	var w := _glyph_width(id,h)
	var c := Vector2(at.x+w*0.5,at.y)
	var ink := Color(INK,0.9)
	if id == "ESC": return _keycap("Esc",at,h)
	if id in ["UP","DOWN","LEFT","RIGHT","DPAD"]:
		# A ring like the face buttons', a cross in it, the arm pressed lit.
		draw_circle(c,h*0.5,Color(0,0,0,0.3))
		draw_arc(c,h*0.5-line*0.5,0,TAU,32,Color(INK,0.6),line*1.5,true)
		var t := maxf(2.0,roundf(h*0.11))
		var arm := h*0.3
		draw_rect(Rect2(c.x-arm,c.y-t,arm*2.0,t*2.0),Color(INK,0.35))
		draw_rect(Rect2(c.x-t,c.y-arm,t*2.0,arm*2.0),Color(INK,0.35))
		var arms := {"UP":Vector2(0,-1),"DOWN":Vector2(0,1),"LEFT":Vector2(-1,0),"RIGHT":Vector2(1,0)}
		for k: String in arms:
			if k != id and id != "DPAD": continue
			var d: Vector2 = arms[k]
			var tip := c+d*arm
			var mid := c+d*t
			draw_rect(Rect2(Vector2(minf(tip.x,mid.x),minf(tip.y,mid.y))-Vector2(t,t)*d.orthogonal().abs(),(tip-mid).abs()+Vector2(t,t)*2.0*d.orthogonal().abs()),ink)
		return w
	if id in ["A","B","X","Y","LS","RS","L3","R3"]:
		draw_circle(c,h*0.5,Color(0,0,0,0.3))
		draw_arc(c,h*0.5-line*0.5,0,TAU,32,ink,line*1.5,true)
		var fs := roundi(h*(0.55 if id.length() == 1 else 0.4))
		var tw := _caps.get_string_size(id,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
		_caps.spacing_glyph = 0
		draw_string(_caps,Vector2(roundf(c.x-tw*0.5),roundf(c.y+fs*0.36)),id,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,ink)
		return w
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0,0,0,0.3)
	box.border_color = ink
	box.set_border_width_all(int(line*1.5))
	box.set_corner_radius_all(int(h*0.45))
	draw_style_box(box,Rect2(at.x,at.y-h*0.5,w,h))
	var fs := roundi(h*0.42)
	_caps.spacing_glyph = 0
	var tw := _caps.get_string_size(id,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
	draw_string(_caps,Vector2(roundf(c.x-tw*0.5),roundf(c.y+fs*0.36)),id,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,ink)
	return w

# --- Input ----------------------------------------------------------------

func _pickable(i: int) -> bool:
	return i >= 0 and i < rows.size() and str(rows[i].kind) in PICKABLE

func _next(from: int, way: int) -> int:
	var i := from+way
	while i >= 0 and i < rows.size():
		if _pickable(i): return i
		i += way
	return from if _pickable(from) else -1

func _row_at(p: Vector2) -> int:
	var area := _area()
	if not area.grow_individual(20.0*_px,0,20.0*_px,0).has_point(p): return -1
	for i in rows.size():
		if row_rect(i).has_point(p): return i
	return -1

func _input(event: InputEvent) -> void:
	if not active or not visible: return
	# Taken first: an act may leave the tree (Quit to Title changes the scene).
	var viewport := get_viewport()
	var handled := true
	if event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		var i := _row_at(m.position)
		_hover = i if _pickable(i) else -1
		_foot_hover = foot != "" and _foot_rect().has_point(m.position)
		if _hover >= 0: selected = _hover
		if _dragging >= 0: _slide_to(_dragging,m.position.x)
		handled = false
	elif event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_WHEEL_UP and b.pressed: _scroll_by(-STEP_SCROLL*_px)
		elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN and b.pressed: _scroll_by(STEP_SCROLL*_px)
		elif b.button_index == MOUSE_BUTTON_LEFT:
			if not b.pressed:
				_dragging = -1
			elif foot != "" and _foot_rect().has_point(b.position): back.emit()
			else:
				var i := _row_at(b.position)
				if _pickable(i):
					selected = i
					_click(i,b.position)
	elif event.is_action_pressed(&"menu") and not event.is_echo(): menu.emit()
	elif event.is_action_pressed(&"ui_cancel") and not event.is_echo(): back.emit()
	elif event.is_action_pressed(&"ui_up",true): _move(-1)
	elif event.is_action_pressed(&"ui_down",true) or (event.is_action_pressed(&"ui_focus_next") and not event.is_echo()): _move(1)
	elif event.is_action_pressed(&"ui_left",true): _adjust(-1)
	elif event.is_action_pressed(&"ui_right",true): _adjust(1)
	elif event.is_action_pressed(&"ui_accept") and not event.is_echo(): _act()
	else: handled = event is InputEventKey or event is InputEventJoypadButton
	if handled and viewport != null: viewport.set_input_as_handled()

func _move(way: int) -> void:
	var n := _next(selected,way)
	if n == selected or n < 0:
		_scroll_by(way*STEP_SCROLL*_px)
		return
	selected = n
	_keep_in_view()

func _scroll_by(d: float) -> void:
	_scroll = clampf(_scroll+d,0.0,_max_scroll())

func _act() -> void:
	if not _pickable(selected): return
	var row: Dictionary = rows[selected]
	match str(row.kind):
		"button": (row.act as Callable).call()
		"toggle": (row.set as Callable).call(not bool((row.get as Callable).call()))
		"choice","slider": _adjust(1)

func _adjust(way: int) -> void:
	if not _pickable(selected): return
	var row: Dictionary = rows[selected]
	match str(row.kind):
		"toggle": (row.set as Callable).call(not bool((row.get as Callable).call()))
		"choice":
			var n: int = (row.names as Array).size()
			(row.set as Callable).call((int((row.get as Callable).call())+way+n)%n)
		"slider":
			var v := float((row.get as Callable).call())+way*float(row.step)
			(row.set as Callable).call(clampf(snappedf(v,float(row.step)),float(row.lo),float(row.hi)))

func _click(i: int, at: Vector2) -> void:
	var row: Dictionary = rows[i]
	match str(row.kind):
		"choice": _adjust(-1 if at.x < row_rect(i).end.x-110.0*_px else 1)
		"slider":
			var track := _track(row_rect(i))
			if at.x >= track.x-10.0*_px:
				_dragging = i
				_slide_to(i,at.x)
		_: _act()

func _slide_to(i: int, x: float) -> void:
	var row: Dictionary = rows[i]
	var track := _track(row_rect(i))
	var t := clampf(inverse_lerp(track.x,track.y,x),0.0,1.0)
	var v := snappedf(lerpf(float(row.lo),float(row.hi),t),float(row.step))
	if not is_equal_approx(v,float((row.get as Callable).call())): (row.set as Callable).call(v)
