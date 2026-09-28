extends Control
## The forms wheel under Land (Mario Maker's parts wheel): the land forms
## (scripts/mountain_forms.gd FORMS) swing down from behind the Land slot on an
## arc, each a moment after the last, joined to it by dotted threads. The
## shell opens it on a hold of Land, a second click of Land, or the 1 key, and
## picks the form a hold is released over (`form_at`).
const Style = preload("res://scripts/lantern_style.gd")
const Slot = preload("res://scripts/lantern_slot.gd")
const Forms = preload("res://scripts/mountain_forms.gd")
const RADIUS := 146.0
## Degrees, clockwise from the right with y down: 150 is down-left, 30 down-right.
const ARC := Vector2(150.0,30.0)
const OPEN_SECONDS := 0.28
const STAGGER := 0.025

signal picked(id: String)
var buttons := {}
var open := false
var _t := 0.0
var _order: Array = []

func setup() -> void:
	name = "FormsWheel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for entry: Dictionary in Forms.FORMS:
		var slot: Button = Slot.new()
		slot.setup(entry.glyph if entry.id != "hill" else "hill",str(entry.title),Style.FORM_SLOT,"below")
		slot.tint = Style.tint("land")
		slot.tooltip_text = str(entry.title)+"  ·  1 steps through the forms"
		slot.pressed.connect(func() -> void: picked.emit(entry.id))
		buttons[entry.id] = slot
		_order.append(entry.id)
		add_child(slot)
	hide()

## Where a form rests, from the Land slot's centre (this control's origin).
func rest(index: int) -> Vector2:
	var t := float(index)/maxf(1.0,_order.size()-1)
	var angle := deg_to_rad(lerpf(ARC.x,ARC.y,t))
	return Vector2.from_angle(angle)*RADIUS

func set_open(value: bool) -> void:
	if value == open: return
	open = value
	if open: show()

func sync(form: String) -> void:
	for id: String in buttons:
		buttons[id].set_pressed_no_signal(id == form)
		buttons[id].set_held(id == form)
		buttons[id].label_always = id == form

## The form whose slot is under a viewport point, or "".
func form_at(point: Vector2) -> String:
	if not visible: return ""
	for id: String in buttons:
		var slot: Control = buttons[id]
		var rect := slot.get_global_rect().grow(6.0*slot.get_global_transform().get_scale().x)
		if rect.has_point(point): return id
	return ""

func contains_pointer(point: Vector2) -> bool:
	return visible and _t > 0.5 and not form_at(point).is_empty()

func _process(delta: float) -> void:
	if not visible: return
	var span := OPEN_SECONDS+STAGGER*_order.size()
	_t = clampf(_t+(delta if open else -delta*1.4)/span,0.0,1.0)
	for index in range(_order.size()):
		var slot: Control = buttons[_order[index]]
		# Each form starts STAGGER after the last and eases out with a little overshoot.
		var local := clampf((_t*span-STAGGER*index)/OPEN_SECONDS,0.0,1.0)
		var eased := Tween.interpolate_value(0.0,1.0,local,1.0,Tween.TRANS_BACK,Tween.EASE_OUT) as float
		slot.position = rest(index)*eased-slot.size*0.5
		slot.modulate.a = clampf(local*1.6,0.0,1.0)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP if open and local > 0.6 else Control.MOUSE_FILTER_IGNORE
	if not open and _t <= 0.0: hide()
	queue_redraw()

func _draw() -> void:
	for index in range(_order.size()):
		var slot: Control = buttons[_order[index]]
		var tip := slot.position+slot.size*0.5
		if tip.length() < 36.0: continue
		var from := tip.normalized()*32.0
		Style.thread(self,from,tip-tip.normalized()*(Style.FORM_SLOT*0.5+4.0),Color(Style.LIGHT,0.5*slot.modulate.a))
