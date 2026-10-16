extends Control
## The motif editor's trap knobs panel (loop editor-traps): when a placed
## trap is selected while editing, a piece of the HUD's linen at the top
## right (the landform panel's cloth and theme) lists every knob the trap
## starts with (TrapRegistry.defaults_of: its defaults() plus what its
## _init merges), one row each: a slider and a typed value for a number, a
## toggle for a bool, a text field for a word; a list or vector is shown,
## kept as it is. Nothing is written per trap: the rows come from the
## knobs' types and default values (a number's slider runs 0 to three
## times its default, or round it; a typed value past the end widens it).
##
## A change goes into the trap's entry in `data.traps` (`knobs`: only
## those that differ from the start, as the save writes them), one undo
## step per drag or typed value, and the trap is built again in its place
## at the end of that frame (EditorTraps.rebuild_one). Reset takes its
## knobs back to the start.

const Linen = preload("res://scripts/hud_linen.gd")
const ClaySound = preload("res://scripts/clay_sound.gd")
const TrapRegistry = preload("res://scripts/traps/trap_registry.gd")

const T1 := Color("f4ead4")
const T2 := Color("c2b8a3")
const CLOTH := Color(0.384,0.345,0.290,0.92)
const INSET := Vector2(16.0,14.0)
const WIDTH := 340.0
const PAD := 14.0
## The panel never runs lower than this far above the screen's bottom (the
## hint strip's room); past it the rows scroll.
const FOOT := 84.0
## Its top (viewport px, unscaled as the look label is): under the editor's
## "Look: grey · G full" label in the top right corner.
const TOP_PX := 46.0

var editor: Node
var ui_scale := 1.0
var _cloth: Linen.Cloth
var _box: VBoxContainer
var _title: Label
var _scroll: ScrollContainer
var _rows: VBoxContainer
## Key -> {kind, control, value (the typed field, numbers)} for the trap shown.
var rows := {}
## The trap shown: its index in data.traps and id (-1 / "" none).
var shown := -1
var shown_id := ""
var _start := {}
var _dragging := false
## A rebuild owed for the trap shown (done once a frame, after the input).
var _owed := false
## Changes made and rebuilds done (for checks).
var changes := 0
var rebuilds := 0

func _init() -> void:
	name = "KnobsPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func setup(owner_editor: Node) -> void:
	editor = owner_editor
	var lp: Control = editor.panel
	ui_scale = lp.ui_scale
	_cloth = Linen.Cloth.new()
	_cloth.material_ref.set_shader_parameter("cloth",CLOTH)
	add_child(_cloth)
	_box = VBoxContainer.new()
	_box.name = "Box"
	_box.theme = lp._theme
	_box.add_theme_constant_override("separation",roundi(4.0*ui_scale))
	_box.custom_minimum_size.x = (WIDTH-PAD*2.0)*ui_scale
	add_child(_box)
	var top := HBoxContainer.new()
	_title = lp._caption("Trap")
	_title.name = "Title"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	top.add_child(_title)
	var reset: Button = lp._button("Reset","Every knob back to the trap's own",func() -> void: reset_knobs())
	reset.name = "Reset"
	top.add_child(reset)
	_box.add_child(top)
	_box.add_child(lp._rule())
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	_rows.add_theme_constant_override("separation",0)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows)
	visible = false

func contains_pointer(point: Vector2) -> bool:
	return visible and _cloth.strip.has_point(point)

func _process(_delta: float) -> void:
	var traps: Node = editor.traps
	var k: int = traps.selected if traps != null and editor.editing and not traps.holding() else -1
	var id := ""
	if k >= 0 and k < traps.count(): id = str(traps.entries()[k].get("id",""))
	else: k = -1
	if k != shown or id != shown_id: show_trap(k)
	if _owed:
		_owed = false
		if shown >= 0:
			traps.rebuild_one(shown)
			rebuilds += 1
	if not visible: return
	var screen := get_viewport().get_visible_rect().size
	var w := WIDTH*ui_scale
	var top := maxf(INSET.y*ui_scale,TOP_PX)
	var most: float = screen.y-top-(FOOT+PAD*2.0)*ui_scale-_box.get_child(0).size.y-12.0*ui_scale
	_scroll.custom_minimum_size = Vector2((WIDTH-PAD*2.0)*ui_scale,minf(_rows.get_combined_minimum_size().y,maxf(most,80.0*ui_scale)))
	_box.size = Vector2(_box.custom_minimum_size.x,0.0)
	var rect := Rect2(Vector2(screen.x-w-INSET.x*ui_scale,top),Vector2(w,_box.size.y+PAD*2.0*ui_scale))
	_cloth.place(rect,ui_scale,12.0,Vector2(5.0,8.0))
	_box.position = rect.position+Vector2.ONE*PAD*ui_scale

## The rows for trap `k` (-1: none, hidden).
func show_trap(k: int) -> void:
	shown = k
	shown_id = ""
	_dragging = false
	for c: Node in _rows.get_children(): c.free()
	rows.clear()
	visible = k >= 0
	if k < 0: return
	var e: Dictionary = editor.traps.entries()[k]
	shown_id = str(e.get("id",""))
	_start = TrapRegistry.defaults_of(shown_id)
	_title.text = ("%s #%d" % [TrapRegistry.display_name(shown_id),k]).to_upper()
	for key: String in _start: _rows.add_child(_row(key,_start[key]))
	sync()
	_scroll.scroll_vertical = 0

## What the trap's knobs are now: the start with its entry's changes over it.
func current() -> Dictionary:
	var out := _start.duplicate(true)
	if shown >= 0: out.merge(editor.traps.entries()[shown].get("knobs",{}),true)
	return out

## The rows set to the data (after a change, an undo).
func sync() -> void:
	var now := current()
	for key: String in rows:
		var r: Dictionary = rows[key]
		var v: Variant = now.get(key)
		var changed := not TrapRegistry.changed_knobs(shown_id,{key:v}).is_empty()
		(r.name as Label).add_theme_color_override("font_color",T1 if changed else T2)
		match str(r.kind):
			"number":
				var s := r.control as HSlider
				var f := float(v)
				if f < s.min_value: s.min_value = f
				if f > s.max_value: s.max_value = f
				s.set_value_no_signal(f)
				var field := r.value as LineEdit
				if not field.has_focus(): field.text = _number_text(v)
			"bool":
				(r.control as Button).set_pressed_no_signal(bool(v))
				(r.control as Button).text = "ON" if bool(v) else "OFF"
			"word":
				var field := r.control as LineEdit
				if not field.has_focus(): field.text = str(v)

static func _number_text(v: Variant) -> String:
	if v is int: return str(v)
	var f := float(v)
	return str(snappedf(f,0.1 if absf(f) >= 100.0 else (0.01 if absf(f) >= 1.0 else 0.001)))

## A number's slider: 0 to 3x its start (an int at least to start+6), round
## zero -1..1 for a float, both sides for a negative; steps about 1/300 of
## the run, a whole one for an int.
static func range_of(d: Variant) -> Array:
	if d is int:
		var di := int(d)
		return [float(mini(0,di*3)),float(maxi(maxi(di*3,di+6),1)),1.0]
	var f := float(d)
	var lo := 0.0 if f > 0.0 else (f*3.0 if f < 0.0 else -1.0)
	var hi := f*3.0 if f > 0.0 else (-f*3.0 if f < 0.0 else 1.0)
	var raw := (hi-lo)/300.0
	var mag := pow(10.0,floorf(log(raw)/log(10.0)))
	var step := mag
	for m: float in [1.0,2.0,5.0,10.0]:
		if mag*m >= raw:
			step = mag*m
			break
	return [lo,hi,step]

func _row(key: String, d: Variant) -> Control:
	var lp: Control = editor.panel
	var row := HBoxContainer.new()
	row.name = "Row_"+key
	row.add_theme_constant_override("separation",roundi(6.0*ui_scale))
	var name_l := Label.new()
	name_l.text = key.replace("_"," ").to_upper()
	name_l.add_theme_font_override("font",lp._caps)
	name_l.add_theme_font_size_override("font_size",roundi(10.0*ui_scale))
	name_l.add_theme_color_override("font_color",T2)
	name_l.custom_minimum_size.x = 96.0*ui_scale
	name_l.clip_text = true
	name_l.tooltip_text = key
	name_l.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(name_l)
	var r := {"name":name_l}
	if d is bool:
		r.kind = "bool"
		var b: Button = lp._button("On","",func() -> void: pass)
		b.name = "Toggle_"+key
		b.toggle_mode = true
		b.toggled.connect(func(on: bool) -> void:
			b.text = "ON" if on else "OFF"
			set_knob(key,on,true))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		r.control = b
	elif d is int or d is float:
		r.kind = "number"
		var span := range_of(d)
		var s := HSlider.new()
		s.name = "Slider_"+key
		s.min_value = float(span[0])
		s.max_value = float(span[1])
		s.step = float(span[2])
		s.value = float(d)
		s.focus_mode = Control.FOCUS_NONE
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var is_int := d is int
		s.value_changed.connect(func(v: float) -> void:
			set_knob(key,int(round(v)) if is_int else v,not _dragging))
		s.drag_started.connect(func() -> void:
			_dragging = true
			editor.snapshot())
		s.drag_ended.connect(func(_c: bool) -> void: _dragging = false)
		row.add_child(s)
		var field := LineEdit.new()
		field.name = "Value_"+key
		field.custom_minimum_size.x = 58.0*ui_scale
		field.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		field.text_submitted.connect(func(t: String) -> void:
			field.release_focus()
			if t.strip_edges().is_valid_float():
				var f := t.strip_edges().to_float()
				if f < s.min_value: s.min_value = f
				if f > s.max_value: s.max_value = f
				set_knob(key,int(round(f)) if is_int else f,true)
			else: sync())
		field.focus_exited.connect(func() -> void: sync())
		row.add_child(field)
		r.control = s
		r.value = field
	elif d is String or d is StringName:
		r.kind = "word"
		var field := LineEdit.new()
		field.name = "Word_"+key
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field.text_submitted.connect(func(t: String) -> void:
			field.release_focus()
			set_knob(key,t.strip_edges(),true))
		row.add_child(field)
		r.control = field
	else:
		r.kind = "kept"
		var l := Label.new()
		l.text = ("list of %d" % (d as Array).size()) if d is Array else type_string(typeof(d)).to_lower()
		l.add_theme_color_override("font_color",T2)
		l.add_theme_font_size_override("font_size",roundi(12.0*ui_scale))
		l.tooltip_text = "Kept as it is (not editable here)"
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		r.control = l
	rows[key] = r
	return row

## Knob `key` of the trap shown set to `v`; `step`: its own undo step (a
## click, a typed value; a drag took one when it began).
func set_knob(key: String, v: Variant, step: bool) -> void:
	if shown < 0: return
	var e: Dictionary = editor.traps.entries()[shown]
	var now := current()
	if typeof(now.get(key)) == typeof(v) and now.get(key) == v: return
	if step: editor.snapshot()
	now[key] = v
	var keep := TrapRegistry.changed_knobs(shown_id,now)
	if keep.is_empty(): e.erase("knobs")
	else: e.knobs = keep
	changes += 1
	_owed = true
	sync()
	editor.say("%s · %s %s" % [TrapRegistry.display_name(shown_id),key.replace("_"," "),_number_text(v) if (v is float or v is int) else str(v)])

## Every knob of the trap shown back to its start (one undo step).
func reset_knobs() -> void:
	if shown < 0: return
	var e: Dictionary = editor.traps.entries()[shown]
	if not e.has("knobs"): return
	editor.snapshot()
	e.erase("knobs")
	changes += 1
	_owed = true
	# Sliders widened by typed values go back to their own runs.
	for key: String in rows:
		var r: Dictionary = rows[key]
		if str(r.kind) == "number":
			var span := range_of(_start[key])
			(r.control as HSlider).min_value = float(span[0])
			(r.control as HSlider).max_value = float(span[1])
	sync()
	editor.say("%s · knobs back to its own" % TrapRegistry.display_name(shown_id))
