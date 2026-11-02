extends Control
## A trial look for the near misses on screen (scripts/endless/near_miss.gd),
## behind --near-hud=glyph; the same calls as scripts/endless/near_miss_hud.gd,
## plus `plane_at` (the plane's place in the world, set each frame).
## Kept out of the action: the chain rides a small block tilted ANGLE, its
## lower right corner hung OFFSET off the plane's place on screen (above and
## to its left), following it smoothly; the surge meter sits quiet in the
## lower right corner.
## - the feed, over the chain: a line a pass (its glyph, scripts/endless/
##   near_glyphs.gd, popping in and gleaming; its kind; its points), the
##   newest lowest, older ones pushed up and fading, FEED_LINES at most;
##   they sink away when the chain ends.
## - the chain: its total in gilt, ticking up and jolting as each pass lands,
##   and its multiplier beside it, heating from cream to flame as it climbs
##   to the cap; a bar under them running down to the bank.
## - the bank: the multiplier slams into the total, which counts up to the
##   banked points and swells by how big it is, its sun glyph bursting
##   beside it, then fades; a scrape cracks the total and drains it away.

const NearMiss = preload("res://scripts/endless/near_miss.gd")
const Glyphs = preload("res://scripts/endless/near_glyphs.gd")
const GILT = preload("res://shaders/near_gilt.gdshader")
const DISPLAY = preload("res://assets/fonts/newsreader-latin.woff2")
const CAPS = preload("res://assets/fonts/CormorantGaramond-SemiBold-latin.ttf")

const ICON_POP := 0.14
const GLEAM := 0.3
const FEED_LINES := 3
const FEED_FADE := 0.3
const BANK_TIME := 1.7
const LOSS_TIME := 1.0
const NOTE_TIME := 1.2
## The block's tilt (rad, rising to the right) and where its lower right
## corner hangs off the plane on screen (px at 1080 high).
const ANGLE := -0.12
const OFFSET := Vector2(-86.0,-62.0)
## How quickly the block follows the plane (1/s).
const FOLLOW := 10.0
## The chain line's height in the block, and the bank bar's width.
const CHAIN := -22.0
const BAR_W := 150.0
## The surge meter: in from the lower right corner, and its width.
const METER_AT := Vector2(56.0,64.0)
const METER_W := 150.0
const CREAM := Color("fff8e7")
const GOLD := Color("ffd36b")
const MIST := Color("cfe3ee")
const LOST := Color("ff8a6b")
const INK := Color(0.10,0.07,0.04,0.85)
## The multiplier's heat, x1 to the cap.
const HEAT := [Color("fff8e7"),Color("ffd36b"),Color("ff9a3c"),Color("ff4a24")]

var key_name := "B"
## The plane's place in the world; the block hangs off it on screen.
var plane_at: Variant = null

var _caps := FontVariation.new()
var _display := FontVariation.new()
var _block := Control.new()
var _anchor := Vector2.ZERO
var _anchored := false
var _total: Label
var _mult: Label
var _bank_word: Label
var _feed: Array = []
var _shown := 0.0
var _jolt := INF
var _mult_kick := INF
var _last_mult := 1.0
var _prev_chain := 0.0
var _prev_mult := 1.0
var _bank := {}
var _loss := {}
var _note := {}
## The total's left edge this frame, in the block (the bank's glyph bursts past it).
var _total_inner := 0.0
var _clock := 0.0
var _near: NearMiss

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block.rotation = ANGLE
	_block.draw.connect(_draw_block)
	add_child(_block)
	_display.base_font = DISPLAY
	_display.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):700}
	_caps.base_font = CAPS
	_caps.spacing_glyph = 2
	_total = _gilt_label()
	_mult = _gilt_label()
	_bank_word = _gilt_label()
	_bank_word.add_theme_font_override("font",_caps)

func _gilt_label() -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font",_display)
	l.add_theme_color_override("font_outline_color",Color("2a1c0e"))
	l.add_theme_color_override("font_shadow_color",Color(0,0,0,0.45))
	l.add_theme_constant_override("shadow_offset_x",0)
	var m := ShaderMaterial.new()
	m.shader = GILT
	l.material = m
	l.visible = false
	_block.add_child(l)
	return l

## One frame, as NearMissHud's: `near` the NearMiss, `on` whether it runs,
## `events` the frame's.
func show_state(delta: float, near: NearMiss, on: bool, events: Dictionary) -> void:
	visible = on
	_near = near
	if not on:
		_prev_chain = near.chain_points
		_prev_mult = near.multiplier()
		_anchored = false
		return
	_clock += delta
	var u := _u()
	if events.has("near"):
		var m: Dictionary = events.near
		_feed.push_front({"id":Glyphs.for_moment(m),"kind":str(m.kind).to_upper(),"band":str(m.band),
			"points":float(m.points),"age":0.0,"slot":-1.0,"landed":false,"fade":-1.0})
	if events.has("banked"):
		_bank = {"age":0.0,"points":float(events.banked.points),"chain":_prev_chain,"mult":_prev_mult}
		_end_feed()
	if events.has("crash"):
		_loss = {"age":0.0,"text":"CRASHED","chain":_prev_chain}
		_end_feed(true)
	elif events.has("scrape"):
		var lost := float((events.get("lost",{}) as Dictionary).get("points",0.0))
		if lost > 0.0:
			_loss = {"age":0.0,"text":"SCRAPE  ·  −%s" % _grouped(lost),"chain":_prev_chain}
			_end_feed(true)
		else:
			_note = {"age":0.0,"text":"SCRAPE"}
	# The feed's lines: age them, land their glyphs, slide them to their slots.
	var pending := 0.0
	for i in _feed.size():
		var f: Dictionary = _feed[i]
		f.age += delta
		if f.slot < 0.0: f.slot = float(i)
		f.slot = lerpf(f.slot,float(i),minf(1.0,delta*14.0))
		if f.fade >= 0.0: f.fade += delta
		if not f.landed and f.age >= ICON_POP:
			f.landed = true
			_jolt = 0.0
		if not f.landed and f.fade < 0.0: pending += f.points
	_feed = _feed.filter(func(f: Dictionary) -> bool: return f.fade < FEED_FADE)
	if _feed.size() > FEED_LINES+1: _feed.resize(FEED_LINES+1)
	# The total ticks toward the chain's points, less what is still landing.
	var target := maxf(near.chain_points-pending,0.0)
	if near.chain_points <= 0.0: _shown = 0.0
	_shown = target if absf(target-_shown) < 1.0 else lerpf(_shown,target,minf(1.0,delta*12.0))
	_jolt += delta
	var mult := near.multiplier()
	if mult > _last_mult+0.01: _mult_kick = 0.0
	_last_mult = mult
	_mult_kick += delta
	if not _bank.is_empty():
		_bank.age += delta
		if _bank.age >= BANK_TIME: _bank = {}
	if not _loss.is_empty():
		_loss.age += delta
		if _loss.age >= LOSS_TIME: _loss = {}
	if not _note.is_empty():
		_note.age += delta
		if _note.age >= NOTE_TIME: _note = {}
	# The block follows the plane, with a small shake on a big bank or a loss.
	var to := _plane_screen()+OFFSET*u
	to = Vector2(clampf(to.x,320.0*u,size.x-40.0*u),clampf(to.y,170.0*u,size.y-80.0*u))
	_anchor = to if not _anchored else _anchor.lerp(to,minf(1.0,delta*FOLLOW))
	_anchored = true
	var shake := 0.0
	if not _bank.is_empty():
		var b := float(_bank.age)-0.2
		if b > 0.0 and b < 0.4: shake = _big(float(_bank.points))*4.0*u*(1.0-b/0.4)
	if not _loss.is_empty() and float(_loss.age) < 0.25: shake = maxf(shake,3.0*u*(1.0-float(_loss.age)/0.25))
	_block.position = _anchor+Vector2(randf_range(-1.0,1.0),randf_range(-1.0,1.0))*shake
	_place_labels(near,u)
	_prev_chain = near.chain_points
	_prev_mult = mult
	queue_redraw()
	_block.queue_redraw()

## The feed sinks away; `quick` (a loss) makes room for its note at once.
func _end_feed(quick := false) -> void:
	for f: Dictionary in _feed:
		if f.fade < 0.0: f.fade = FEED_FADE*0.6 if quick else 0.0
		f.landed = true

func _u() -> float:
	return size.y/1080.0

## How big a bank is, 0 (800 points) to 1 (16,000).
static func _big(points: float) -> float:
	return clampf(log(maxf(points,1.0)/800.0)/log(20.0),0.0,1.0)

func _plane_screen() -> Vector2:
	var fallback := Vector2(size.x*0.5,size.y*0.62)
	var cam := get_viewport().get_camera_3d()
	if cam == null or not (plane_at is Vector3) or cam.is_position_behind(plane_at): return fallback
	return cam.unproject_position(plane_at)

# --- The gilt labels (in the block): the total, the multiplier, the bank's word --

func _place_labels(near: NearMiss, u: float) -> void:
	var cy := CHAIN*u
	_total.visible = _shown >= 1.0 or not _bank.is_empty() or not _loss.is_empty()
	_mult.visible = false
	_bank_word.visible = false
	if not _total.visible: return
	var text := _grouped(_shown)
	var grow := 1.0+0.14*(1.0-smoothstep(0.0,0.16,_jolt))
	var tint := CREAM
	var flash := 0.0
	var offset := Vector2.ZERO
	var alpha := 1.0
	var rot := 0.0
	var mult := near.multiplier()
	var mult_alpha := 1.0
	var into := 0.0
	if not _bank.is_empty():
		var a := float(_bank.age)
		mult = float(_bank.mult)
		if a < 0.2:
			text = _grouped(float(_bank.chain))
			into = smoothstep(0.0,0.2,a)
			mult_alpha = 1.0-into
		else:
			var c := clampf((a-0.2)/0.55,0.0,1.0)
			text = _grouped(lerpf(float(_bank.chain),float(_bank.points),1.0-pow(1.0-c,3.0)))
			mult_alpha = 0.0
			var slam := a-0.2
			grow = 1.0+(0.15+0.3*_big(float(_bank.points)))*(1.0-smoothstep(0.0,0.9,slam))+0.12*(1.0-smoothstep(0.0,0.08,slam))
			flash = 0.8*(1.0-smoothstep(0.0,0.25,slam))
			tint = CREAM.lerp(GOLD,0.6)
			if a > 1.05:
				var d := smoothstep(1.05,BANK_TIME,a)
				grow *= 1.0-0.4*d
				offset.y = -24.0*u*d
				alpha = 1.0-d
		_bank_word.visible = a > 0.2
		_bank_word.text = "BANKED"
		var word_px := roundi(15.0*u)
		_bank_word.add_theme_font_size_override("font_size",word_px)
		_bank_word.add_theme_constant_override("outline_size",roundi(4.0*u))
		var ww := _caps.get_string_size("BANKED",HORIZONTAL_ALIGNMENT_LEFT,-1,word_px).x+20.0*u
		_bank_word.size = Vector2(ww,26.0*u)
		_bank_word.position = Vector2(-ww+5.0*u,cy-30.0*u-20.0*u*grow)+offset
		_bank_word.modulate.a = alpha*smoothstep(0.2,0.3,a)
		_set_gilt(_bank_word,GOLD,0.0)
	elif not _loss.is_empty():
		var a := float(_loss.age)
		text = _grouped(float(_loss.chain)) if float(_loss.chain) >= 1.0 else ""
		tint = LOST
		mult_alpha = 0.0
		if a > 0.3:
			var d := smoothstep(0.3,LOSS_TIME,a)
			offset.y = 30.0*u*d*d
			rot = 0.08*d
			alpha = 1.0-d
	var total_px := roundi(34.0*u)
	var tw := _display.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,total_px).x
	var mtext := "×%s" % String.num(mult,1)
	var heat := clampf((mult-1.0)/(NearMiss.CHAIN_TOP-1.0),0.0,1.0)
	var mult_px := roundi(22.0*u*(1.0+0.25*heat))
	var mw := _display.get_string_size(mtext,HORIZONTAL_ALIGNMENT_LEFT,-1,mult_px).x
	var gap := 8.0*u
	var show_mult := mult_alpha > 0.0 and mult > 1.0
	# In reading order, the total then the multiplier, the row ending at the block's corner.
	var whole := tw+gap+mw if show_mult else tw
	if not _bank.is_empty(): whole = tw+(gap+mw)*(1.0-into) if mult > 1.0 else tw
	var left := -whole
	_total_inner = left+tw*0.5-tw*0.5*grow
	_style(_total,total_px,u)
	_total.text = text
	_total.size = Vector2(tw+30.0*u,total_px*1.4)
	_total.position = Vector2(left+tw*0.5-_total.size.x*0.5,cy-_total.size.y*0.5)+offset
	_total.pivot_offset = _total.size*0.5
	_total.scale = Vector2.ONE*grow
	_total.rotation = rot
	_total.modulate.a = alpha
	_set_gilt(_total,tint,flash)
	if show_mult:
		_mult.visible = true
		_style(_mult,mult_px,u)
		_mult.text = mtext
		_mult.size = Vector2(mw+24.0*u,mult_px*1.4)
		var mx := lerpf(left+tw+gap+mw*0.5,left+tw*0.5,into)
		_mult.position = Vector2(mx-_mult.size.x*0.5,cy-_mult.size.y*0.5+3.0*u)
		_mult.pivot_offset = _mult.size*0.5
		var kick := 1.0+0.25*(1.0-smoothstep(0.0,0.2,_mult_kick))
		var live_heat := heat*heat
		_mult.scale = Vector2.ONE*kick*(1.0+0.05*live_heat*sin(_clock*TAU*3.0))
		_mult.rotation = 0.04*live_heat*sin(_clock*TAU*2.3)
		_mult.modulate.a = mult_alpha
		_set_gilt(_mult,_heat(heat)*(1.0+0.12*live_heat*sin(_clock*TAU*7.0)),0.0)

func _style(l: Label, px: int, u: float) -> void:
	l.add_theme_font_size_override("font_size",px)
	l.add_theme_constant_override("outline_size",roundi(px*0.16))
	l.add_theme_constant_override("shadow_offset_y",roundi(2.0*u))

func _set_gilt(l: Label, tint: Color, flash: float) -> void:
	var m := l.material as ShaderMaterial
	var px := float(l.get_theme_font_size("font_size"))
	m.set_shader_parameter("top",l.size.y*0.5-px*0.42)
	m.set_shader_parameter("height",px*0.8)
	m.set_shader_parameter("tint",tint)
	m.set_shader_parameter("flash",flash)

func _heat(h: float) -> Color:
	var x := h*(HEAT.size()-1)
	var i := mini(int(x),HEAT.size()-2)
	return (HEAT[i] as Color).lerp(HEAT[i+1],x-i)

# --- Drawn on the screen: the surge meter ----------------------------------------

func _draw() -> void:
	if _near == null: return
	var u := _u()
	var mw := METER_W*u
	var right := size.x-METER_AT.x*u
	var my := size.y-METER_AT.y*u
	var bright := _near.surge > 0.0
	draw_rect(Rect2(right-mw-1.0,my-1.0,mw+2.0,5.0*u+2.0),Color(0,0,0,0.3))
	var fill := clampf(_near.meter,0.0,1.0)
	var pulse := 0.75+0.25*sin(_clock*TAU*4.0) if bright else 0.9
	var banked := 0.0
	if not _bank.is_empty(): banked = 1.0-smoothstep(1.2,BANK_TIME,float(_bank.age))
	draw_rect(Rect2(right-mw*fill,my,mw*fill,5.0*u),Color(GOLD.lerp(Color.WHITE,banked*0.6),pulse))
	var label := ("SURGE" if bright else "SURGE  ·  %s" % key_name) if _near.meter > 0.0 else "SURGE"
	_text(self,_caps,label,Vector2(right,my-5.0*u),roundi(13.0*u),Color(CREAM,0.75 if _near.meter > 0.0 else 0.4),u,1.0)

# --- Drawn in the block: the feed and its glyphs, the bank bar, notes -----------
# The block's origin is its lower right corner; rows end at x = 0.

func _draw_block() -> void:
	if _near == null: return
	var u := _u()
	var cy := CHAIN*u
	for i in range(_feed.size()-1,-1,-1): _draw_line(_feed[i],cy,u)
	# The bar running down to the bank, shrinking toward the corner.
	if _near.chain_points > 0.0 and _near.bank_left > 0.0:
		var share := clampf(_near.bank_left/_near.bank_after(),0.0,1.0)
		var bw := BAR_W*u
		var y := cy+20.0*u
		_block.draw_rect(Rect2(-bw-1.0,y-1.0,bw+2.0,3.0*u+2.0),Color(0,0,0,0.3))
		_block.draw_rect(Rect2(-bw*share,y,bw*share,3.0*u),Color(GOLD,0.85))
	# The bank's glyph and burst, left of the total.
	if not _bank.is_empty() and float(_bank.age) > 0.2:
		var a := float(_bank.age)-0.2
		var fade := 1.0-smoothstep(0.85,BANK_TIME-0.2,a+0.2)
		_burst(Vector2(_total_inner-22.0*u,cy),a,u,GOLD,fade)
	# A loss's note and a bare scrape's, on the feed's first line.
	var note := {}
	if not _loss.is_empty(): note = {"text":str(_loss.text),"fade":1.0-smoothstep(0.6,LOSS_TIME,float(_loss.age)),"age":float(_loss.age)}
	elif not _note.is_empty(): note = {"text":str(_note.text),"fade":1.0-smoothstep(NOTE_TIME*0.6,NOTE_TIME,float(_note.age)),"age":float(_note.age)}
	if not note.is_empty():
		var px := roundi(16.0*u)
		var icon := 22.0*u
		var tw := _caps.get_string_size(str(note.text),HORIZONTAL_ALIGNMENT_LEFT,-1,px).x
		var left := -(icon+8.0*u+tw)
		var y := cy-30.0*u
		var pop := 1.0+0.3*(1.0-smoothstep(0.0,0.15,float(note.age)))
		_glyph("scrape",Vector2(left+icon*0.5,y-5.0*u),icon*pop,float(note.fade),0.0)
		_text(_block,_caps,str(note.text),Vector2(left+icon+8.0*u,y),px,Color(LOST,float(note.fade)),u,0.0)

## A feed line: its glyph popping in and gleaming, its kind and points.
func _draw_line(f: Dictionary, cy: float, u: float) -> void:
	var slot := float(f.slot)
	var fade := 1.0
	if float(f.fade) >= 0.0: fade = 1.0-clampf(float(f.fade)/FEED_FADE,0.0,1.0)
	var row_alpha := clampf(1.0-slot*0.25,0.0,1.0)*fade
	if slot > FEED_LINES-0.5: row_alpha *= clampf(FEED_LINES+0.5-slot,0.0,1.0)
	if row_alpha <= 0.01: return
	var y := cy-30.0*u-slot*25.0*u
	# Ending (banked or lost), the lines sink as they fade.
	if float(f.fade) >= 0.0: y += 18.0*u*clampf(float(f.fade)/FEED_FADE,0.0,1.0)
	var band := str(f.band)
	var col := GOLD if band == "razor" else (CREAM if band == "close" else MIST)
	var kind := str(f.kind)
	var pts := "+%s" % _grouped(float(f.points))
	var kind_px := roundi(15.0*u)
	var pts_px := roundi(17.0*u)
	var icon := 26.0*u
	var kw := _caps.get_string_size(kind,HORIZONTAL_ALIGNMENT_LEFT,-1,kind_px).x
	var pw := _display.get_string_size(pts,HORIZONTAL_ALIGNMENT_LEFT,-1,pts_px).x
	var gap := 7.0*u
	var whole := icon+gap+kw+gap*1.2+pw
	var left := -whole
	var age := float(f.age)
	var pop := 1.0+0.25*(1.0-smoothstep(0.0,0.14,age))
	var half := (kw+gap*1.2+pw)*0.5
	_block.draw_set_transform(Vector2(left+icon+gap+half,y),0.0,Vector2.ONE*pop)
	_text(_block,_caps,kind,Vector2(-half,0.0),kind_px,Color(col,row_alpha),u,0.0)
	_text(_block,_display,pts,Vector2(half,1.0*u),pts_px,Color(col,row_alpha),u,1.0)
	_block.draw_set_transform_matrix(Transform2D.IDENTITY)
	# The glyph: pops in, then gleams as it lands.
	var s := 1.0
	var gleam := 0.0
	var at := Vector2(left+icon*0.5,y-5.0*u)
	if age < ICON_POP:
		s = 1.35*sin(age/ICON_POP*PI*0.5)
	else:
		var since := age-ICON_POP
		gleam = 1.0-clampf(since/GLEAM,0.0,1.0)
		s = 1.0+0.2*gleam*gleam
		if since < 0.45: _sparkle(at+Vector2(icon*0.42,-icon*0.4),since,u,row_alpha)
	_glyph(str(f.id),at,icon*s,row_alpha,gleam)

func _glyph(id: String, p: Vector2, px: float, alpha: float, gleam: float) -> void:
	var size_px := maxf(roundf(px/2.0)*2.0,6.0)
	var draw_px := size_px*Glyphs.BOX/24.0
	var rect := Rect2(p-Vector2.ONE*draw_px*0.5,Vector2.ONE*draw_px)
	var shadow := Glyphs.texture(id,"shadow",size_px)
	if shadow != null: _block.draw_texture_rect(shadow,Rect2(rect.position+Vector2(0.0,2.0)*_u(),rect.size),false,Color(0.08,0.05,0.03,0.6*alpha))
	var tex := Glyphs.texture(id,"icon",size_px)
	if tex != null: _block.draw_texture_rect(tex,rect,false,Color(1,1,1,alpha))
	if gleam > 0.0:
		var lit := Glyphs.texture(id,"lit",size_px)
		if lit != null: _block.draw_texture_rect(lit,rect,false,Color(1,1,1,alpha*gleam))

## A four-point glint, growing and fading over 0.45 s.
func _sparkle(p: Vector2, t: float, u: float, alpha: float) -> void:
	var k := clampf(t/0.45,0.0,1.0)
	var r := 7.0*u*sin(k*PI)
	if r <= 0.5: return
	var c := Color(1.0,0.98,0.9,alpha*(1.0-k*0.6))
	_block.draw_line(p-Vector2(r,0.0),p+Vector2(r,0.0),c,1.4*u,true)
	_block.draw_line(p-Vector2(0.0,r),p+Vector2(0.0,r),c,1.4*u,true)

## The bank's sun glyph in a burst of rays.
func _burst(p: Vector2, t: float, u: float, col: Color, fade: float) -> void:
	var k := clampf(t/0.5,0.0,1.0)
	for i in 10:
		var d := Vector2.from_angle(i*TAU/10.0+0.13)
		var r0 := lerpf(14.0,34.0,k)*u
		var r1 := r0+lerpf(10.0,4.0,k)*u
		_block.draw_line(p+d*r0,p+d*r1,Color(col,(1.0-k)*fade),1.8*u,true)
	var pop := 1.0+0.35*(1.0-smoothstep(0.0,0.15,t))
	_glyph("bank",p,24.0*u*pop,fade,1.0-smoothstep(0.0,0.3,t))

## Text on `on` at `p` (baseline p.y), `align` 0 starting at x, 1 ending at
## x, with a dark cut edge.
func _text(on: CanvasItem, font: Font, text: String, p: Vector2, px: int, col: Color, u: float, align: float) -> void:
	var w := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x
	var at := Vector2(p.x-w*align,p.y)
	var edge := maxi(roundi(px*0.22),2)
	on.draw_string_outline(font,at+Vector2(0.0,1.5*u),text,HORIZONTAL_ALIGNMENT_LEFT,-1,px,edge,Color(0,0,0,0.35*col.a))
	on.draw_string_outline(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,px,edge,Color(INK,INK.a*col.a))
	on.draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,px,col)

## 12345 as "12,345".
static func _grouped(v: float) -> String:
	var n := str(roundi(v))
	var out := ""
	while n.length() > 3:
		out = ","+n.substr(n.length()-3)+out
		n = n.substr(0,n.length()-3)
	return n+out
