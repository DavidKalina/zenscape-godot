extends Button
## One Lantern slot: a line glyph in a thin ring over its own dark under-glow
## disc, with a halo that swells in the slot's tint while it is in hand. The
## name shows in small caps beside it on hover and while held. It stays a
## Button (toggle mode, `pressed`), so probes and the packaged self-check can
## press it as they pressed the glass palette's buttons.
const Style = preload("res://scripts/lantern_style.gd")

## Where the name sits: "right", "left", "below", or "" for tooltip only.
var label_side := "right"
## Show the name all the time, not just on hover and while held.
var label_always := false
var tint := Style.LIGHT
var glyph_id := ""
var held := false
## 0..1 how far the slot is lit: hover, held, and the swell when picked.
var _lit := 0.0
var _hover := 0.0
var _swell := 0.0
var _phase := randf()*TAU
var _period := randf_range(3.0,5.0)
var _time := 0.0
## 0..1 of a ring drawn round the glyph (the water ball's fill), or < 0 for none.
var fill := -1.0
## Sparks shed by the undo wisp: [angle, age].
var _sparks: Array[Vector2] = []
var _spin := 0.0
var _spin_speed := 0.0
var _hop := 0.0

var underglow := TextureRect.new()
var halo := TextureRect.new()
var ring := Control.new()
var glyph: TextureRect
var caption: Label
var badge: TextureRect
var badge_disc: Control

func setup(id: String, title: String, slot_size := Style.SLOT, side := "right") -> void:
	glyph_id = id
	tint = Style.tint(id)
	label_side = side
	name = "Slot_"+id
	Style.bare(self)
	toggle_mode = true
	custom_minimum_size = Vector2.ONE*slot_size
	size = custom_minimum_size
	tooltip_text = title
	for layer: TextureRect in [underglow,halo]:
		layer.texture = Style.glyph("underglow" if layer == underglow else "halo")
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.stretch_mode = TextureRect.STRETCH_SCALE
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
	# The under-glow is 1.6x the slot; the halo swells to about 1.9x.
	underglow.size = Vector2.ONE*slot_size*1.6
	underglow.position = (Vector2.ONE*slot_size-underglow.size)*0.5
	halo.size = Vector2.ONE*slot_size*1.9
	halo.position = (Vector2.ONE*slot_size-halo.size)*0.5
	halo.pivot_offset = halo.size*0.5
	halo.modulate = Color(tint,0.0)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.size = Vector2.ONE*slot_size
	ring.draw.connect(_draw_ring)
	add_child(ring)
	glyph = Style.glyph_rect(id,slot_size*0.66)
	glyph.position = (Vector2.ONE*slot_size-glyph.size)*0.5
	add_child(glyph)
	caption = Style.label(title,12)
	caption.modulate.a = 0.0
	add_child(caption)
	_place_caption()
	mouse_entered.connect(func() -> void: _hover_target = 1.0)
	mouse_exited.connect(func() -> void: _hover_target = 0.0)

var _hover_target := 0.0

## A small badge at the lower right, as Mario Maker shows a part's variant
## (Land's form in hand).
func set_badge(id: String) -> void:
	if badge == null:
		badge_disc = Control.new()
		badge_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_disc.size = Vector2.ONE*20
		badge_disc.position = size-Vector2(18,18)
		badge_disc.draw.connect(func() -> void:
			badge_disc.draw_circle(Vector2(10,10),10.0,Color(Style.SHADE,0.82))
			badge_disc.draw_arc(Vector2(10,10),9.5,0,TAU,32,Color(Style.LIGHT,0.6),1.0,true))
		add_child(badge_disc)
		badge = Style.glyph_rect(id,17)
		badge.position = badge_disc.position+Vector2(1.5,1.5)
		add_child(badge)
	badge.texture = Style.glyph(id)

func set_title(title: String) -> void:
	tooltip_text = title
	caption.text = Style.caps(title)
	_place_caption()

func _place_caption() -> void:
	caption.size = caption.get_minimum_size()
	match label_side:
		"right": caption.position = Vector2(size.x+14,(size.y-caption.size.y)*0.5)
		"left": caption.position = Vector2(-14-caption.size.x,(size.y-caption.size.y)*0.5)
		"below": caption.position = Vector2((size.x-caption.size.x)*0.5,size.y+6)
	caption.visible = label_side != ""

func set_held(value: bool) -> void:
	if value and not held: _swell = 1.0
	held = value

## The undo wisp's hop, and its spin back with sparks once the undo lands;
## `direction` -1 spins it the other way for a redo.
func hop(direction := 1.0) -> void:
	_hop = 1.0
	_spin_speed = TAU*2.4*direction
	for i in range(7): _sparks.append(Vector2(randf()*TAU,0.0))

func _process(delta: float) -> void:
	_time += delta
	_hover = move_toward(_hover,_hover_target if not disabled else 0.0,delta*6.0)
	var goal := 1.0 if held else 0.45*_hover
	_lit = lerpf(_lit,goal,1.0-exp(-10.0*delta))
	_swell = maxf(0.0,_swell-delta/0.4)
	_hop = maxf(0.0,_hop-delta/0.45)
	# Idle drift: each glyph breathes on its own slow sine; hover lifts it.
	var lift := sin(_time*TAU/_period+_phase)*1.5-3.0*_hover-sin(_hop*PI)*7.0
	glyph.position.y = (size.y-glyph.size.y)*0.5+lift
	if _spin_speed != 0.0:
		_spin += _spin_speed*delta
		_spin_speed = move_toward(_spin_speed,0.0,delta*TAU*4.0)
		if _spin_speed == 0.0: _spin = 0.0
	glyph.rotation = wrapf(_spin,-PI,PI) if _spin_speed != 0.0 else 0.0
	# The halo swells 0.7 -> 1.1 -> 1 when picked.
	var swell := 1.0+0.1*sin((1.0-_swell)*PI) if _swell > 0.0 else 1.0
	halo.scale = Vector2.ONE*lerpf(0.7,1.0,_lit)*swell
	halo.modulate = Color(tint,_lit*0.95)
	glyph.modulate = tint.lerp(Style.LIGHT,0.55) if held else Style.LIGHT
	glyph.modulate.a = 0.4 if disabled else 1.0
	caption.modulate.a = move_toward(caption.modulate.a,1.0 if label_always or held or _hover > 0.5 else 0.0,delta*5.0)
	for i in range(_sparks.size()-1,-1,-1):
		_sparks[i].y += delta
		if _sparks[i].y > 0.6: _sparks.remove_at(i)
	ring.queue_redraw()

func _draw_ring() -> void:
	var c := ring.size*0.5
	var r := ring.size.x*0.5-1.0
	# A thin ring always, a second one outside it in the tint while held.
	ring.draw_arc(c,r,0,TAU,48,Color(Style.LIGHT,0.3+0.45*_lit),1.2,true)
	if _lit > 0.05: ring.draw_arc(c,r+4.0,0,TAU,48,Color(tint,0.55*_lit),1.0,true)
	if fill >= 0.0:
		ring.draw_arc(c,r+4.0,-PI*0.5,-PI*0.5+TAU*clampf(fill,0.0,1.0),48,Color(tint,0.95),2.4,true)
	for spark: Vector2 in _sparks:
		var t := spark.y/0.6
		ring.draw_circle(c+Vector2.from_angle(spark.x)*(r+4.0+t*16.0),1.6*(1.0-t),Color(Style.tint("undo"),1.0-t))
