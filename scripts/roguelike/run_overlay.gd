extends CanvasLayer
## The run's few words on the screen (docs/design/roguelike/
## stakes-experiment.md), in the isle card's language (scripts/
## isle_splash.gd: its gilt, tracked inscription, its hairline parted by a
## diamond, its soft dark band, its fades; the pieces are the card's own,
## shared from there):
##
## - **The readout**, top left: the height, small, gilt, tracked, with the
##   runes carried beside it in small caps and a hairline under both, over
##   a faint band. It sinks low while he moves and comes up when he stands
##   still or a count changes (`set_readout`'s `loud`).
## - **The hearts** (`set_hearts`), under the readout's hairline, straight
##   over the view: the HUD's carved, faceted glyph (scripts/hud_icons.gd
##   "heart") with a soft shadow while held, its pale silhouette when lost.
##   A hit (`hurt`) pops the hearts lost (a flash, the lit glyph swelling
##   and fading off the empty one) with a low madder bloom at the screen's
##   edge; the last one left beats. They never sink below HEARTS_LOW while
##   he moves.
## - **The caption** (`show_caption`): a small isle card in the upper
##   middle, a title settling from wider tracking, the hairline drawing out
##   from its diamond, a line under it; it holds, then fades.
## - **The card** a fall ends on (`show_card`), centred over the dark: the
##   title, the hairline and diamond, the few facts in the reading face
##   one after another, and the prompt quiet at the bottom.
## - **The veil** over everything (dark for a fall, warm for the gate).
##
## Drawn only; scripts/roguelike/run_loop.gd says what (its WORDS, the one
## place the words live), and steps it (`step`) on the study's tick.
## Lengths are design px of a 1080-high screen, scaled.
const Splash = preload("res://scripts/isle_splash.gd")
const Icons = preload("res://scripts/hud_icons.gd")
const DARK := Color(0.035,0.04,0.055)
const WARM := Color(1.0,0.93,0.8)
## Seconds: the caption in, held, out; the card in; the readout's rise and
## sink (its alpha per second).
const CAPTION_IN := 1.0
const CAPTION_HOLD := 2.2
const CAPTION_OUT := 1.6
const CARD_IN := 1.4
const READOUT_RATE := 1.4
## The readout's alpha when quiet (moving) and up.
const READOUT_LOW := 0.28
const READOUT_HIGH := 1.0
## Design px: the readout's corner and type; the caption's top and type;
## the card's type, its facts' spacing, the prompt off the bottom.
const CORNER := Vector2(46.0,38.0)
const READOUT_SIZE := 22
const READOUT_TRACK := 5.0
const SIDE_SIZE := 10
const CAPTION_TOP := 236.0
const CAPTION_SIZE := 30
const CARD_SIZE := 40
const FACT_SIZE := 19
const FACT_GAP := 32.0
const PROMPT_SIZE := 10
const PROMPT_BOTTOM := 104.0
## The hearts: their size and gap (design px), their row under the
## hairline (px below CORNER.y); their least alpha while he moves; a lost
## heart's pop (s); the edge's bloom on a hit (s, alpha); the last heart's
## beat (Hz).
const HEART := 24.0
const HEART_GAP := 4.0
const HEARTS_ROW := 58.0
const HEARTS_LOW := 0.6
const POP := 0.55
const BLOOM := 0.45
const BLOOM_A := 0.4
const BEAT_HZ := 1.1
## The bloom's warmth (a deep madder, kept low).
const BLOOM_TINT := Color(0.40,0.08,0.06)
## An empty heart's alpha (its pale silhouette), and the glyphs' shadow.
const EMPTY_A := 0.34
const SHADOW_TINT := Color(0.03,0.025,0.02,0.55)

var veil: ColorRect
var readout: Control
var readout_main: Label
var readout_side: Label
var caption: Control
var caption_title: Label
var caption_line: Label
var card: Control
var card_title: Label
var card_facts: Array[Label] = []
var card_prompt: Label

var _px := 1.0
var _readout_band: ColorRect
var _readout_font: FontVariation
var _side_font: FontVariation
var _readout_a := 0.0
var _readout_want := 0.0
var _caption_band: ColorRect
var _caption_font: FontVariation
var _caption_age := INF
var _card_band: ColorRect
var _card_font: FontVariation
var _prompt_font: FontVariation
var _card_age := INF
var hearts_row: Control
var _hearts := 4
var _hearts_most := 4
## Each heart's pop age (INF none), by its place in the row.
var _pops: Array[float] = []
var _bloom: TextureRect
var _bloom_age := INF
var _beat := 0.0
## The heart glyph's textures by variant, and the size they were made at.
var _glyph_tex := {}
var _glyph_px := 0.0

func _init() -> void:
	name = "RunOverlay"
	layer = 60

func _ready() -> void:
	veil = ColorRect.new()
	veil.name = "Veil"
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.color = Color(DARK,0.0)
	add_child(veil)
	readout = _group("Readout",_draw_readout)
	_readout_band = readout.get_child(0)
	_readout_font = Splash.inscription_font()
	_side_font = Splash.inscription_font()
	readout_main = _label(readout,_readout_font,true)
	readout_side = _label(readout,_side_font,false)
	hearts_row = Control.new()
	hearts_row.name = "Hearts"
	hearts_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hearts_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hearts_row.draw.connect(_draw_hearts.bind(hearts_row))
	readout.add_child(hearts_row)
	_bloom = TextureRect.new()
	_bloom.name = "Bloom"
	_bloom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bloom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bloom.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bloom.stretch_mode = TextureRect.STRETCH_SCALE
	_bloom.texture = _bloom_texture()
	_bloom.modulate = Color(1,1,1,0)
	_bloom.visible = false
	add_child(_bloom)
	move_child(_bloom,1)
	caption = _group("Caption",_draw_caption)
	_caption_band = caption.get_child(0)
	_caption_font = Splash.inscription_font()
	caption_title = _label(caption,_caption_font,true)
	caption_line = _label(caption,null,false)
	caption_line.add_theme_font_override("font",Splash.READING)
	caption.visible = false
	card = _group("Card",_draw_card)
	_card_band = card.get_child(0)
	_card_font = Splash.inscription_font()
	_prompt_font = Splash.inscription_font()
	card_title = _label(card,_card_font,true)
	card_prompt = _label(card,_prompt_font,false)
	card.visible = false

## A full-screen group: its band, its marks (drawn by `draw`), then its
## labels.
func _group(group_name: String, draw: Callable) -> Control:
	var group := Control.new()
	group.name = group_name
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(group)
	group.add_child(Splash.make_band())
	var marks := Control.new()
	marks.name = "Marks"
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marks.draw.connect(draw.bind(marks))
	group.add_child(marks)
	return group

func _label(group: Control, font: Font, gilt: bool) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null: label.add_theme_font_override("font",font)
	label.add_theme_color_override("font_shadow_color",Splash.SHADOW)
	if gilt: label.material = Splash.gilt_material()
	group.add_child(label)
	return label

# --- What run_loop.gd sets ----------------------------------------------------------

func set_veil(colour: Color, alpha: float) -> void:
	veil.color = Color(colour,clampf(alpha,0.0,1.0))

## The corner: `main` (the height), `side` (the runes, "" for none), shown
## at all or not, and `loud` (up) or quiet.
func set_readout(main: String, side: String, shown: bool, loud: bool) -> void:
	readout_main.text = main
	readout_side.text = side
	readout.visible = shown
	_readout_want = (READOUT_HIGH if loud else READOUT_LOW) if shown else 0.0
	if not shown: _readout_a = 0.0

## The hearts held of `most`.
func set_hearts(held: int, most: int) -> void:
	if most != _hearts_most or _pops.size() != most:
		_pops.resize(most)
		_pops.fill(INF)
	_hearts = held
	_hearts_most = most

## A hit: `took` hearts lost, `held` left. The lost pop, the edge blooms.
func hurt(held: int, took: int) -> void:
	if _pops.size() != _hearts_most:
		_pops.resize(_hearts_most)
		_pops.fill(INF)
	for i in range(held,mini(held+took,_hearts_most)): _pops[i] = 0.0
	_hearts = held
	_bloom_age = 0.0
	_bloom.visible = true

## The caption from the start: `title` over the hairline, `line` under.
func show_caption(title: String, line: String) -> void:
	caption_title.text = title
	caption_line.text = line
	_caption_age = 0.0
	caption.visible = true

## The card from the start: `title`, then `facts` (one a line; "" a
## half-line's pause), then `prompt` at the bottom.
func show_card(title: String, facts: PackedStringArray, prompt: String) -> void:
	card_title.text = title
	for label in card_facts: label.queue_free()
	card_facts.clear()
	for fact in facts:
		var label := _label(card,null,false)
		label.add_theme_font_override("font",Splash.READING)
		label.text = fact
		card_facts.append(label)
	card_prompt.text = prompt
	_card_age = 0.0
	card.visible = true
	_layout_card()

func hide_card() -> void:
	card.visible = false
	_card_age = INF

func set_prompt(prompt: String) -> void:
	card_prompt.text = prompt

## On the study's tick: the fades moved on and everything laid out.
func step(delta: float) -> void:
	_px = maxf(veil.get_viewport_rect().size.y,1.0)/1080.0
	_readout_a = move_toward(_readout_a,_readout_want,delta*READOUT_RATE)
	for i in range(_pops.size()):
		if _pops[i] != INF:
			_pops[i] += delta
			if _pops[i] > POP: _pops[i] = INF
	_beat += delta
	if _bloom_age != INF:
		_bloom_age += delta
		var k := _bloom_age/BLOOM
		_bloom.modulate = Color(1,1,1,BLOOM_A*(1.0-smoothstep(0.15,1.0,k))*smoothstep(0.0,0.08,k))
		if _bloom_age > BLOOM:
			_bloom_age = INF
			_bloom.visible = false
	_layout_readout()
	if caption.visible:
		_caption_age += delta
		if _caption_age >= CAPTION_IN+CAPTION_HOLD+CAPTION_OUT:
			caption.visible = false
			_caption_age = INF
		else:
			_layout_caption()
	if card.visible:
		_card_age += delta
		_layout_card()

# --- Laid out -----------------------------------------------------------------------

func _width(label: Label) -> float:
	if label.text == "": return 0.0
	var font: Font = label.get_theme_font("font")
	return font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x

## `label`'s text centred on `mid`, its top at `top`.
func _centre(label: Label, mid: float, top: float) -> void:
	label.position = Vector2(roundf(mid-_width(label)*0.5),roundf(top))

func _view() -> Vector2:
	return veil.get_viewport_rect().size

## The readout's span (screen px): the height, and the runes after a gap.
func _readout_span() -> float:
	var w := _width(readout_main)
	if readout_side.text != "": w += 18.0*_px+_width(readout_side)
	return w

func _layout_readout() -> void:
	if not readout.visible: return
	var px := _px
	var a := _readout_a
	Splash.style(readout_main,_readout_font,READOUT_SIZE,READOUT_TRACK,px,Color.WHITE)
	Splash.gild(readout_main,READOUT_SIZE,px)
	Splash.style(readout_side,_side_font,SIDE_SIZE,2.5,px,Splash.INK)
	var top := CORNER.y*px
	readout_main.position = Vector2(roundf(CORNER.x*px),roundf(top))
	readout_side.position = Vector2(roundf(CORNER.x*px+_width(readout_main)+18.0*px),roundf(top+11.0*px))
	readout_main.modulate = Color(1,1,1,0.92*a)
	readout_side.modulate = Color(1,1,1,0.7*a)
	var span := _readout_span()
	Splash.lay_band(_readout_band,CORNER.x*px+span*0.5,top-22.0*px,top+58.0*px,span,px,0.4*a,70.0)
	readout.get_node("Marks").queue_redraw()
	hearts_row.queue_redraw()

func _draw_readout(on: Control) -> void:
	if not readout.visible or _readout_a <= 0.0: return
	var px := _px
	var span := _readout_span()
	var line := Color(Splash.HAIRLINE,Splash.HAIRLINE.a*0.8*_readout_a)
	Splash.hairline(on,CORNER.x*px+span*0.5,roundf((CORNER.y+36.0)*px),span*0.5+10.0*px,px,line,3.0*px)

# --- The hearts --------------------------------------------------------------------

## The hearts' alpha: the readout's, never under HEARTS_LOW while shown.
func _hearts_a() -> float:
	if not readout.visible or _readout_want <= 0.0: return _readout_a
	return maxf(_readout_a,HEARTS_LOW)

func _draw_hearts(on: Control) -> void:
	var a := _hearts_a()
	if not readout.visible or a <= 0.0: return
	var px := _px
	var y := (CORNER.y+HEARTS_ROW+HEART*0.5)*px
	for i in range(_hearts_most):
		var at := Vector2((CORNER.x+HEART*0.5+(HEART+HEART_GAP)*float(i))*px,y)
		var pop: float = _pops[i] if i < _pops.size() else INF
		_heart(on,at,roundf(HEART*px),i < _hearts,pop,a,_hearts == 1 and i == 0)

## One heart at `at`, `size` px across, the carved glyph (scripts/
## hud_icons.gd "heart"): held, its faceted stone with a soft shadow; lost,
## its pale empty silhouette; `pop` s into its loss (INF none): the lit
## glyph swelling and fading off the empty one, a flash at its start;
## `last`, the beat.
func _heart(on: Control, at: Vector2, size: float, held: bool, pop: float, a: float, last: bool) -> void:
	_glyphs(size)
	var swell := 1.0
	if last and held: swell = 1.0+0.1*pow(maxf(0.0,sin(_beat*TAU*BEAT_HZ)),6.0)
	if held:
		_glyph(on,"icon",at,size*swell,Color(1,1,1,a),true)
		return
	_glyph(on,"locked",at,size,Color(1,1,1,EMPTY_A*a),false)
	if pop != INF:
		var k := clampf(pop/POP,0.0,1.0)
		var flash := 1.0-smoothstep(0.0,0.35,k)
		_glyph(on,"lit",at,size*(1.0+0.6*smoothstep(0.0,1.0,k)),Color(1.0+0.8*flash,1.0+0.7*flash,1.0+0.6*flash,a*(1.0-smoothstep(0.2,1.0,k))),false)

## One variant of the heart glyph, its 24-unit box `size` px across round
## `at` (the texture covers the icon's padded box), with its soft shadow.
func _glyph(on: Control, variant: String, at: Vector2, size: float, tint: Color, shadow: bool) -> void:
	var tex: Texture2D = _glyph_tex.get(variant)
	if tex == null: return
	var extent := size*Icons.BOX/24.0
	var rect := Rect2(at-Vector2.ONE*extent*0.5,Vector2.ONE*extent)
	if shadow:
		var shade: Texture2D = _glyph_tex.get("shadow")
		if shade != null:
			for o: Vector2 in [Vector2(0.0,1.6),Vector2(0.0,2.6)]:
				on.draw_texture_rect(shade,Rect2(rect.position+o*_px,rect.size),false,Color(SHADOW_TINT,SHADOW_TINT.a*0.5*tint.a))
	on.draw_texture_rect(tex,rect,false,tint)

## The heart's textures, made at `size` px (again when the screen's scale
## changes it).
func _glyphs(size: float) -> void:
	if is_equal_approx(size,_glyph_px) and not _glyph_tex.is_empty(): return
	_glyph_px = size
	for variant: String in ["icon","lit","locked","shadow"]:
		var tex: Texture2D = Icons.texture("heart",variant,size)
		if tex != null: _glyph_tex[variant] = tex

## The bloom's texture: clear in the middle, the edges' warmth.
static func _bloom_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0,Color(BLOOM_TINT,0.0))
	g.set_color(1,Color(BLOOM_TINT,1.0))
	g.add_point(0.55,Color(BLOOM_TINT,0.0))
	g.add_point(0.85,Color(BLOOM_TINT,0.45))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5,0.5)
	tex.fill_to = Vector2(1.08,1.08)
	tex.width = 256
	tex.height = 256
	return tex

## How far in the caption is (0..1) and how shown.
func _caption_t() -> float:
	return clampf(_caption_age/CAPTION_IN,0.0,1.0)

func _caption_shown() -> float:
	if _caption_age == INF: return 0.0
	if _caption_age < CAPTION_IN: return smoothstep(0.0,1.0,_caption_age/CAPTION_IN)
	return 1.0-smoothstep(0.0,1.0,(_caption_age-CAPTION_IN-CAPTION_HOLD)/CAPTION_OUT)

func _layout_caption() -> void:
	var px := _px
	var mid := _view().x*0.5
	var t := _caption_t()
	var settle := 1.0-pow(1.0-t,3.0)
	var shown := _caption_shown()
	var top := CAPTION_TOP*px
	Splash.style(caption_title,_caption_font,CAPTION_SIZE,lerpf(22.0,10.0,settle),px,Color.WHITE)
	Splash.gild(caption_title,CAPTION_SIZE,px)
	Splash.style(caption_line,null,17,0.0,px,Splash.INK)
	_centre(caption_title,mid,top)
	_centre(caption_line,mid,top+62.0*px)
	caption_title.modulate = Color(1,1,1,shown)
	caption_line.modulate = Color(1,1,1,0.85*smoothstep(0.35,1.0,t)*shown)
	var wide := maxf(_width(caption_title),_width(caption_line))
	Splash.lay_band(_caption_band,mid,top-36.0*px,top+112.0*px,wide,px,0.45*shown,150.0)
	caption.get_node("Marks").queue_redraw()

func _draw_caption(on: Control) -> void:
	if not caption.visible: return
	var px := _px
	var t := _caption_t()
	var line := Color(Splash.HAIRLINE,Splash.HAIRLINE.a*_caption_shown())
	Splash.hairline(on,_view().x*0.5,roundf((CAPTION_TOP+50.0)*px),150.0*px*smoothstep(0.15,1.0,t),px,line,3.5*px*smoothstep(0.0,0.4,t))

## The card's title top (screen px), and each fact's top.
func _card_top() -> float:
	return _view().y*0.42-80.0*_px

func _fact_top(i: int) -> float:
	var y := _card_top()+(CARD_SIZE+52.0)*_px
	for k in range(i): y += FACT_GAP*_px*(0.5 if card_facts[k].text == "" else 1.0)
	return y

## How far in fact `i` is (0..1): one after another as the title settles.
func _fact_in(i: int) -> float:
	var start := CARD_IN*0.45+0.18*float(i)
	return smoothstep(start,start+0.5,_card_age) if _card_age != INF else 0.0

func _layout_card() -> void:
	var px := _px
	var view := _view()
	var mid := view.x*0.5
	var t := clampf(_card_age/CARD_IN,0.0,1.0)
	var settle := 1.0-pow(1.0-t,3.0)
	var shown := smoothstep(0.0,1.0,t)
	var top := _card_top()
	Splash.style(card_title,_card_font,CARD_SIZE,lerpf(20.0,8.0,settle),px,Color.WHITE)
	Splash.gild(card_title,CARD_SIZE,px)
	_centre(card_title,mid,top)
	card_title.modulate = Color(1,1,1,shown)
	var wide := _width(card_title)
	for i in range(card_facts.size()):
		Splash.style(card_facts[i],null,FACT_SIZE,0.0,px,Splash.INK)
		_centre(card_facts[i],mid,_fact_top(i))
		card_facts[i].modulate = Color(1,1,1,0.85*_fact_in(i))
		wide = maxf(wide,_width(card_facts[i]))
	Splash.style(card_prompt,_prompt_font,PROMPT_SIZE,3.0,px,Splash.INK)
	_centre(card_prompt,mid,view.y-PROMPT_BOTTOM*px)
	card_prompt.modulate = Color(1,1,1,0.5*smoothstep(CARD_IN,CARD_IN+1.0,_card_age))
	var bottom := _fact_top(card_facts.size())+40.0*px
	Splash.lay_band(_card_band,mid,top-50.0*px,bottom,wide,px,0.5*shown)
	card.get_node("Marks").queue_redraw()

func _draw_card(on: Control) -> void:
	if not card.visible: return
	var px := _px
	var t := clampf(_card_age/CARD_IN,0.0,1.0)
	var line := Color(Splash.HAIRLINE,Splash.HAIRLINE.a*smoothstep(0.0,1.0,t))
	Splash.hairline(on,_view().x*0.5,roundf(_card_top()+(CARD_SIZE+26.0)*px),220.0*px*smoothstep(0.15,1.0,t),px,line,4.5*px*smoothstep(0.0,0.4,t))
