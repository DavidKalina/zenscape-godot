extends Control
## The near misses on screen (scripts/endless/near_miss.gd), small and
## out of the way of the land ahead:
## - the pop: a scored moment's kind and band over its points, a little over
##   the middle, swelling in and rising away over POP_TIME s; a scrape or a
##   crash says so in its place.
## - the chain, low in the middle: its points times its multiplier, a bar
##   under it running down to the bank; "banked" or "lost" as it ends.
## - the meter under that: the surge's charge and its key, bright while
##   the surge runs.
## Only in the weighted presets (`show_state`'s `on`).

const NearMiss = preload("res://scripts/endless/near_miss.gd")

const POP_TIME := 1.3
const NOTE_TIME := 1.1
const BAR := Vector2(280.0,5.0)
const METER := Vector2(280.0,10.0)
const GOLD := Color("ffd36b")
const WHITE := Color(1.0,1.0,1.0)
const MIST := Color("cfe3ee")
const LOST := Color("ff8a6b")
const BANK := Color("a9f0b4")
const BACK := Color(0.0,0.0,0.0,0.35)

var _pop_kind: Label
var _pop_points: Label
var _pop := Control.new()
var _pop_age := INF
var _chain: Label
var _bar_back: ColorRect
var _bar: ColorRect
var _note: Label
var _note_age := INF
var _meter_label: Label
var _meter_back: ColorRect
var _meter: ColorRect
var _clock := 0.0
## The key's name in the meter's label (the pad's or the keyboard's).
var key_name := "B"

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pop)
	_pop_kind = _label(46,_pop)
	_pop_kind.anchor_top = 0.2
	_pop_kind.anchor_bottom = 0.2
	_pop_points = _label(32,_pop)
	_pop_points.anchor_top = 0.2
	_pop_points.anchor_bottom = 0.2
	_pop_points.offset_top = 56.0
	_pop.modulate.a = 0.0
	_chain = _label(30,self)
	_chain.anchor_top = 1.0
	_chain.anchor_bottom = 1.0
	_chain.offset_top = -150.0
	_bar_back = _rect(BAR,BACK,-110.0)
	_bar = _rect(BAR,WHITE,-110.0)
	_note = _label(24,self)
	_note.anchor_top = 1.0
	_note.anchor_bottom = 1.0
	_note.offset_top = -184.0
	_note.modulate.a = 0.0
	_meter_label = _label(18,self)
	_meter_label.anchor_top = 1.0
	_meter_label.anchor_bottom = 1.0
	_meter_label.offset_top = -100.0
	_meter_back = _rect(METER,BACK,-74.0)
	_meter = _rect(METER,GOLD,-74.0)

func _label(size: int, parent: Control) -> Label:
	var l := Label.new()
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_outline_color",Color(0,0,0,0.75))
	l.add_theme_constant_override("outline_size",6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _rect(size: Vector2, color: Color, from_bottom: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.anchor_left = 0.5
	r.anchor_right = 0.5
	r.anchor_top = 1.0
	r.anchor_bottom = 1.0
	r.offset_left = -size.x*0.5
	r.offset_right = size.x*0.5
	r.offset_top = from_bottom
	r.offset_bottom = from_bottom+size.y
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r

## One frame: `near` the NearMiss, `on` whether it runs (a weighted preset,
## flying), `events` the frame's (its "near", "banked", "scrape", "crash",
## and "lost" {points}).
func show_state(delta: float, near: NearMiss, on: bool, events: Dictionary) -> void:
	visible = on
	if not on: return
	_clock += delta
	if events.has("near"):
		var m: Dictionary = events.near
		_pop_kind.text = str(m.kind).to_upper()+("  ·  "+str(m.band) if str(m.band) != "near" else "")
		_pop_points.text = "+%s" % _grouped(float(m.points))
		var tint: Color = GOLD if m.band == "razor" else (WHITE if m.band == "close" else MIST)
		_pop_kind.add_theme_color_override("font_color",tint)
		_pop_points.add_theme_color_override("font_color",tint)
		_pop_age = 0.0
	if events.has("crash"): _say("CRASHED",LOST)
	elif events.has("scrape"):
		var lost := float((events.get("lost",{}) as Dictionary).get("points",0.0))
		_say("SCRAPE" if lost <= 0.0 else "SCRAPE  ·  chain lost  -%s" % _grouped(lost),LOST)
	elif events.has("banked"): _say("banked  +%s" % _grouped(float(events.banked.points)),BANK)
	# The pop: swells in, holds, rises and fades.
	_pop_age += delta
	var t := _pop_age/POP_TIME
	_pop.modulate.a = clampf(1.0-(t-0.55)/0.45,0.0,1.0) if t < 1.0 else 0.0
	_pop.position.y = -24.0*smoothstep(0.4,1.0,t)
	var swell := 1.0+0.25*(1.0-smoothstep(0.0,0.12,_pop_age))
	_pop.scale = Vector2.ONE*swell
	_pop.pivot_offset = Vector2(size.x*0.5,size.y*0.2)
	# The chain and its bank timer.
	var live := near.chain_points > 0.0
	_chain.visible = live
	_bar.visible = live and near.bank_left > 0.0
	_bar_back.visible = _bar.visible
	if live:
		_chain.text = "%s  ×%.1f" % [_grouped(near.chain_points),near.multiplier()]
		_chain.add_theme_color_override("font_color",MIST if near.skimming else WHITE)
		var share := clampf(near.bank_left/near.bank_after(),0.0,1.0)
		_bar.offset_right = _bar.offset_left+BAR.x*share
	_note_age += delta
	_note.modulate.a = clampf(1.0-(_note_age-NOTE_TIME*0.6)/(NOTE_TIME*0.4),0.0,1.0) if _note_age < NOTE_TIME else 0.0
	# The meter.
	_meter.offset_right = _meter.offset_left+METER.x*clampf(near.meter,0.0,1.0)
	var bright := near.surge > 0.0
	var pulse := 0.75+0.25*sin(_clock*TAU*4.0) if bright else (1.0 if near.meter >= 0.999 else 0.85)
	_meter.color = Color(GOLD.r,GOLD.g,GOLD.b,pulse)
	_meter_label.text = ("SURGE" if bright else "surge  ·  %s" % key_name) if near.meter > 0.0 else "surge"
	_meter_label.modulate.a = 1.0 if near.meter > 0.0 else 0.55

func _say(text: String, color: Color) -> void:
	_note.text = text
	_note.add_theme_color_override("font_color",color)
	_note_age = 0.0

## 12345 as "12,345".
static func _grouped(v: float) -> String:
	var n := str(roundi(v))
	var out := ""
	while n.length() > 3:
		out = ","+n.substr(n.length()-3)+out
		n = n.substr(0,n.length()-3)
	return n+out
