extends Control
## One card on the title (Claude Design "ZenScape Main Menu Cards", face 5d
## Coin; docs/design/title-cards/README.md): a menu pick or a world, dealt by
## scripts/title_cards.gd, which moves it (`pose`).
##
## The card is drawn as the design builds it: 240 x 336 card pixels scaled
## by `k` (the fan's scale times the screen's), floating (bob, lift, lean,
## press), its face tilted toward the pointer in perspective (900px). The
## face is drawn flat into a SubViewport (`Face`) and set in the scene
## through its homography (shaders/card_tilt.gdshader), with its drop shadow
## and sheen; the ground shadow and, for Your worlds, the deck behind it
## float but do not tilt. The Control itself is the card's resting rect: the
## pointer's hit area, which neither floats nor tilts.

const Style = preload("res://scripts/worlds_style.gd")
const Linen = preload("res://scripts/hud_linen.gd")
const Icons = preload("res://scripts/hud_icons.gd")
const SIZE := Vector2(240,336)
const CENTRE := Vector2(120,168)
## CSS `perspective: 900px` on the floating box.
const PERSPECTIVE := 900.0
## The face is drawn this much finer than shown, for the lift and the tilt.
const OVERSAMPLE := 1.2
const RADIUS := 16.0
const BLANK_RADIUS := 14.0

signal hovered(card: Control)
signal unhovered(card: Control)
## The pointer over the card, -1..1 across and down its resting rect.
signal pointed(card: Control, at: Vector2)
signal chosen(card: Control)

## What the face shows: kind "coin" or "blank"; for a coin its window
## colours (top, low, sun, hill, and haze when `haze_on`), `glyph`, `roman`,
## `label` and `sub`; `world` true sets it as a world's card (smaller name,
## wrapped and balanced, the glyph a little higher).
var spec := {}
## Two cards behind it, as a deck (Your worlds).
var deck := false
## Viewport pixels per card pixel.
var k := 1.0
## Held down by the pointer.
var down := false
## The spring state scripts/title_cards.gd drives: lift, sink, lean, press,
## each with its velocity, and the pointer's smoothed position.
var l := 0.0
var lv := 0.0
var sk := 0.0
var skv := 0.0
var n := 0.0
var nv := 0.0
var p := 0.0
var pv := 0.0
var mx := 0.0
var my := 0.0
var sx := 0.0
var sy := 0.0

var face := Face.new()
var viewport := SubViewport.new()
var _ground := Ground.new()
var _deck := Deck.new()
var _quad := Quad.new()
var _float := Transform2D.IDENTITY
var _art := Vector3.ZERO

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_NONE
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.add_child(face)
	add_child(viewport)
	for part: Control in [_ground,_deck,_quad]:
		part.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(part)
	_deck.card = self
	_quad.card = self
	_ground.card = self
	_quad.material_ref.set_shader_parameter("face",viewport.get_texture())
	mouse_entered.connect(func() -> void: hovered.emit(self))
	mouse_exited.connect(func() -> void:
		down = false
		unhovered.emit(self))

## Sets what the face shows and redraws it.
func set_spec(value: Dictionary, with_deck := false) -> void:
	spec = value
	deck = with_deck
	var blank: bool = spec.get("kind","coin") == "blank"
	_quad.material_ref.set_shader_parameter("radius",BLANK_RADIUS if blank else RADIUS)
	face.set_spec(spec)
	_deck.queue_redraw()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

## Fits the card to `scale` viewport pixels per card pixel: the resting rect
## and a face drawn OVERSAMPLE finer.
func set_k(scale: float) -> void:
	k = scale
	size = (SIZE*k).round()
	var target := Vector2i(maxi(2,roundi(SIZE.x*k*OVERSAMPLE)),maxi(2,roundi(SIZE.y*k*OVERSAMPLE)))
	if viewport.size != target:
		viewport.size = target
		face.set_scale_to(Vector2(target)/SIZE)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

## Places the card for this frame, in card pixels and degrees, as the
## design's transforms: the float (`move`, `turn`, `grow`, `opacity`) about
## the card's centre; the face's tilt toward the pointer (`tilt`: rotateX,
## rotateY); the art inside the window (`art`: x, y, degrees); the sheen
## (`sheen`: centre as fractions of the card, alpha); the ground shadow's
## sideways shift, scale and opacity (`ground`).
func pose(move: Vector2, turn: float, grow: float, opacity: float, tilt: Vector2, art: Vector3, sheen: Vector3, ground: Vector3) -> void:
	_float = Transform2D.IDENTITY.translated(-CENTRE).scaled(Vector2.ONE*grow).rotated(deg_to_rad(turn)).translated(CENTRE+move)
	var to_screen := _matrix(Transform2D.IDENTITY.scaled(Vector2.ONE*k)*_float)
	var homography := to_screen*_translation(CENTRE)*_tilt(tilt)*_translation(-CENTRE)
	_quad.place(homography,sheen,opacity)
	_deck.modulate.a = opacity
	_deck.queue_redraw()
	_ground.place(ground)
	if not art.is_equal_approx(_art):
		_art = art
		face.place_art(art)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

## The design's rest pose: no bob, lift, tilt or sheen.
func rest() -> void:
	l = 0.0; lv = 0.0; sk = 0.0; skv = 0.0; n = 0.0; nv = 0.0; p = 0.0; pv = 0.0
	mx = 0.0; my = 0.0; sx = 0.0; sy = 0.0
	down = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var at: Vector2 = ((event as InputEventMouseMotion).position/size-Vector2(0.5,0.5))*2.0
		pointed.emit(self,at)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		down = event.pressed
		if not event.pressed and get_global_rect().has_point(get_global_mouse_position()): chosen.emit(self)

## CSS rotateX(a) rotateY(b), then the perspective, as a homography of the
## card's plane about its centre.
static func _tilt(tilt: Vector2) -> Basis:
	var a := deg_to_rad(tilt.x)
	var b := deg_to_rad(tilt.y)
	var rx := Basis(Vector3(1,0,0),Vector3(0,cos(a),sin(a)),Vector3(0,-sin(a),cos(a)))
	var ry := Basis(Vector3(cos(b),0,-sin(b)),Vector3(0,1,0),Vector3(sin(b),0,cos(b)))
	var r := rx*ry
	# (x,y,0) -> (d·rx, d·ry, d - rz): columns for x, y and the constant.
	return Basis(Vector3(PERSPECTIVE*r.x.x,PERSPECTIVE*r.x.y,-r.x.z),Vector3(PERSPECTIVE*r.y.x,PERSPECTIVE*r.y.y,-r.y.z),Vector3(0,0,PERSPECTIVE))

static func _translation(by: Vector2) -> Basis:
	return Basis(Vector3(1,0,0),Vector3(0,1,0),Vector3(by.x,by.y,1))

static func _matrix(t: Transform2D) -> Basis:
	return Basis(Vector3(t.x.x,t.x.y,0),Vector3(t.y.x,t.y.y,0),Vector3(t.origin.x,t.origin.y,1))

static func project(homography: Basis, point: Vector2) -> Vector2:
	var h := homography*Vector3(point.x,point.y,1)
	return Vector2(h.x,h.y)/maxf(h.z,1e-4)

## A soft ellipse, its centre opaque: shadows under cards and glyphs.
static func blot() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.35,0.7,1.0])
	gradient.colors = PackedColorArray([Color(1,1,1,1),Color(1,1,1,0.85),Color(1,1,1,0.32),Color(1,1,1,0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5)
	texture.fill_to = Vector2(1.0,0.5)
	texture.width = 64
	texture.height = 64
	return texture

# --- The parts ---------------------------------------------------------------------

## The face, tilted: a rect over the card's reach, drawn by card_tilt.gdshader.
class Quad extends Control:
	var card: Control
	var material_ref := ShaderMaterial.new()
	var _rect := Rect2()

	func _init() -> void:
		material_ref.shader = preload("res://shaders/card_tilt.gdshader")
		material = material_ref

	func place(homography: Basis, sheen: Vector3, opacity: float) -> void:
		var box := Rect2()
		# The card and its drop shadow's reach (17px blur, 16px down).
		var corners := [Vector2(-20,-20),Vector2(260,-20),Vector2(260,372),Vector2(-20,372)]
		for i in corners.size():
			var at: Vector2 = card.project(homography,corners[i])
			box = Rect2(at,Vector2.ZERO) if i == 0 else box.expand(at)
		_rect = box.grow(2.0)
		material_ref.set_shader_parameter("to_card",homography.inverse())
		material_ref.set_shader_parameter("sheen_at",Vector2(sheen.x,sheen.y))
		material_ref.set_shader_parameter("sheen",sheen.z)
		material_ref.set_shader_parameter("opacity",opacity)
		queue_redraw()

	func _draw() -> void:
		if _rect.has_area(): draw_rect(_rect,Color.WHITE)

## The two cards behind Your worlds: translate(10,6) rotate(5deg) in #3e372e
## with its shadow, translate(5,3) rotate(2.5deg) in #463e34. They float with
## the card but do not tilt.
class Deck extends Control:
	var card: Control

	func _draw() -> void:
		if card == null or not card.deck: return
		for back: Array in [[Vector2(10,6),5.0,Color("3e372e"),true],[Vector2(5,3),2.5,Color("463e34"),false]]:
			var lay := Transform2D.IDENTITY.translated(-card.CENTRE).rotated(deg_to_rad(back[1])).translated(card.CENTRE+back[0])
			draw_set_transform_matrix(Transform2D.IDENTITY.scaled(Vector2.ONE*card.k)*card._float*lay)
			var box := StyleBoxFlat.new()
			box.bg_color = back[2]
			box.set_corner_radius_all(16)
			box.anti_aliasing = true
			if back[3]:
				box.shadow_color = Color(10/255.0,8/255.0,12/255.0,0.35)
				box.shadow_size = 12
				box.shadow_offset = Vector2(0,10)
			draw_style_box(box,Rect2(Vector2.ZERO,card.SIZE))
		draw_set_transform_matrix(Transform2D.IDENTITY)

## The shadow on the ground: 180 x 22 at (30,348), blur 9px, rgba(8,6,10,.6).
class Ground extends Control:
	var card: Control
	var _shift := 0.0
	var _scale := 1.0
	static var _blot: Texture2D

	func place(ground: Vector3) -> void:
		_shift = ground.x
		_scale = ground.y
		modulate.a = ground.z
		queue_redraw()

	func _draw() -> void:
		if _blot == null: _blot = card.blot()
		var centre := Vector2(120.0+_shift,359.0)
		var extent := Vector2(180+54,22+54)*_scale
		var rect := Rect2((centre-extent*0.5)*card.k,extent*card.k)
		draw_texture_rect(_blot,rect,false,Color(8/255.0,6/255.0,10/255.0,0.47))

## The face drawn flat, in the SubViewport: the cloth and coin window
## (menu_card.gdshader), the glyph standing in it, and the printing.
class Face extends Control:
	const Style = preload("res://scripts/worlds_style.gd")
	const Linen = preload("res://scripts/hud_linen.gd")
	const Icons = preload("res://scripts/hud_icons.gd")
	var spec := {}
	var px := Vector2.ONE
	var cloth := ColorRect.new()
	var art := Art.new()
	var ink := Ink.new()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/menu_card.gdshader")
		cloth.material = material
		cloth.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cloth.color = Color.WHITE
		add_child(cloth)
		art.face = self
		ink.face = self
		for part: Control in [art,ink]:
			part.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(part)

	func set_scale_to(scale: Vector2) -> void:
		px = scale
		size = SIZE*px
		cloth.size = size
		ink.size = size
		_refresh()

	func set_spec(value: Dictionary) -> void:
		spec = value
		var material := cloth.material as ShaderMaterial
		var coin: bool = spec.get("kind","coin") == "coin"
		material.set_shader_parameter("coin",coin)
		material.set_shader_parameter("radius",RADIUS if coin else BLANK_RADIUS)
		material.set_shader_parameter("haze_on",spec.get("haze_on",false))
		for key in ["top","low","sun","hill","haze"]:
			if spec.has(key): material.set_shader_parameter(key,spec[key])
		_refresh()

	## The art box (192 x 192, the window) moved and turned about its centre.
	func place_art(offset: Vector3) -> void:
		art.position = (Vector2(24,28)+Vector2(offset.x,offset.y))*px
		art.rotation = deg_to_rad(offset.z)

	func _refresh() -> void:
		art.size = Vector2(192,192)*px
		art.pivot_offset = art.size*0.5
		art.position = Vector2(24,28)*px
		art.rasterise()
		art.queue_redraw()
		ink.queue_redraw()

	## The glyph and its shadow on the hill, in the window's 192px box.
	class Art extends Control:
		var face: Control
		var _icon: Texture2D
		var _shadow: Texture2D
		static var _blot: Texture2D

		func rasterise() -> void:
			_icon = null
			_shadow = null
			if face.spec.get("kind","coin") != "coin": return
			var id: String = face.spec.get("glyph","")
			var icon_px: float = 78.0*face.px.x
			_icon = Icons.texture(id,"icon",icon_px)
			_shadow = Icons.texture(id,"shadow",icon_px)

		func _draw() -> void:
			if _icon == null: return
			if _blot == null: _blot = preload("res://scripts/menu_card.gd").blot()
			var world: bool = face.spec.get("world",false)
			var px: Vector2 = face.px
			# The glyph's foot shadow, blur 2px, rgba(20,14,8,.28).
			var foot := Rect2(Vector2(67.92,136.0),Vector2(56.16,6.0)) if world else Rect2(Vector2(62,138),Vector2(68,6))
			foot = foot.grow(5.0)
			draw_texture_rect(_blot,Rect2(foot.position*px,foot.size*px),false,Color(20/255.0,14/255.0,8/255.0,0.3))
			var box := Rect2(Vector2(57,62 if world else 64),Vector2(78,78))
			var extent := box.size*Icons.BOX/24.0
			var rect := Rect2((box.get_center()-extent*0.5)*px,extent*px)
			# drop-shadow(0 1.5px 0 rgba(12,9,5,.3))
			if _shadow != null: draw_texture_rect(_shadow,Rect2(rect.position+Vector2(0,1.5*px.y),rect.size),false,Color(12/255.0,9/255.0,5/255.0,0.3))
			draw_texture_rect(_icon,rect,false)

	## The coin's stitched ring and numeral and the words under the window; or
	## the blank card's stitched border, its plus and words.
	class Ink extends Control:
		var face: Control
		var _medium := Style.newsreader(500)
		var _regular := Style.newsreader(400)

		func _draw() -> void:
			var spec: Dictionary = face.spec
			var px: float = face.px.x
			if spec.get("kind","coin") == "blank":
				_blank(spec,px)
				return
			# border: 2px dashed rgba(227,215,189,.42) round (14,18), 212 across.
			var ring := PackedVector2Array()
			for i in range(97): ring.append((Vector2(120,124)+Vector2.from_angle(TAU*i/96.0)*105.0)*px)
			Linen.dashed(self,ring,Color(Style.THREAD,0.42),2.0*px,6.0*px,6.0*px)
			_line(str(spec.get("roman","")),_medium,12.0,0.34,Color("f1e8d4"),184.0,px)
			var world: bool = spec.get("world",false)
			var label_size := 22.0 if world else 24.0
			var line_height := 26.0 if world else 28.0
			var y := 246.0
			var paragraph := TextParagraph.new()
			paragraph.add_string(str(spec.get("label","")),_regular,roundi(label_size*px))
			paragraph.alignment = HORIZONTAL_ALIGNMENT_CENTER
			paragraph.width = 208.0*px
			if world: _balance(paragraph,208.0*px)
			for i in paragraph.get_line_count():
				var line_size := paragraph.get_line_size(i)
				var ascent := paragraph.get_line_ascent(i)
				var top := (y+i*line_height)*px+(line_height*px-line_size.y)*0.5
				paragraph.draw_line(get_canvas_item(),Vector2((240.0*px-line_size.x)*0.5,top),i,Color("f6eedc"))
			y += paragraph.get_line_count()*line_height+(4.0 if world else 5.0)
			_caps(str(spec.get("sub","")),11.0,0.24,Color("c2b8a3"),y,px)

		## The blank card: inset 14, a 1.5px dashed border (radius 9), and a
		## centred column, 10 apart: "+", the name, the hint.
		func _blank(spec: Dictionary, px: float) -> void:
			var inner := Rect2(Vector2(14,14),Vector2(212,308))
			var line := 1.5*px
			Linen.dashed_round(self,Rect2(inner.position*px,inner.size*px).grow(-line*0.5),9.0*px,Color(Style.THREAD,0.42),line,1.5*px)
			var title_h := _regular.get_height(roundi(20.0*px))/px
			var hint_h := _medium.get_height(Style.caps_size(13.0*px))/px
			var top := inner.get_center().y-(44.0+10.0+title_h+10.0+hint_h)*0.5
			# line-height 1: the glyph box centred in 44px.
			_line("+",_regular,44.0,0.0,Style.THREAD,top+(44.0-_regular.get_height(roundi(44.0*px))/px)*0.5,px)
			_line(str(spec.get("label","Begin a new world")),_regular,20.0,0.0,Style.INK,top+54.0,px)
			_caps(str(spec.get("sub","name it, choose the land")),13.0,0.22,Color("c2b8a3"),top+64.0+title_h,px)

		## `text` centred on the card, its line box (the font's own height at
		## `size`) from `top` card pixels; `font_px`, when given, sets it smaller
		## on the same baseline (small caps).
		func _line(text: String, font: FontVariation, size: float, track: float, colour: Color, top: float, px: float, font_px := 0) -> void:
			var full := maxi(1,roundi(size*px))
			var font_size := font_px if font_px > 0 else full
			font.spacing_glyph = roundi(size*track*px)
			var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
			draw_string(font,Vector2(roundf((240.0*px-width)*0.5),roundf(top*px+font.get_ascent(full))),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,colour)

		## Small caps: capitals at the x-height (scripts/worlds_style.gd `caps`).
		func _caps(text: String, size: float, track: float, colour: Color, top: float, px: float) -> void:
			_line(Style.caps(text),_medium,size,track,colour,top,px,Style.caps_size(size*px))

		## text-wrap: balance: the narrowest width that keeps the line count.
		static func _balance(paragraph: TextParagraph, width: float) -> void:
			var lines := paragraph.get_line_count()
			if lines < 2: return
			var lo := width*0.4
			var hi := width
			for i in 12:
				var mid := (lo+hi)*0.5
				paragraph.width = mid
				if paragraph.get_line_count() > lines: lo = mid
				else: hi = mid
			paragraph.width = hi
