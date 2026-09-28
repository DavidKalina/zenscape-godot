extends RefCounted
## The Lantern Maker look (docs/ui/DIRECTIONS.md, "B2 · Lantern Maker"): thin
## warm-white line glyphs with brush-tinted halos, Cormorant small caps, and
## three legibility layers so white still reads over bright fog and snow: a
## soft dark plate under each group, a dark under-glow disc under each slot,
## and a dark rim drawn round every glyph before its light glow.
##
## Numbers are design units at 1440x900; the shell scales everything by
## `ui_scale`, 1.0 there and 1.2 at 1920x1080 (and 2.0 on a retina window,
## whose viewport is in pixels).
const DESIGN := Vector2(1440,900)
const SLOT := 56.0
const GAP := 16.0
const PITCH := SLOT+GAP
const MARGIN := 24.0
const FORM_SLOT := 52.0
const PHOTO_SLOT := 84.0
const LIGHT := Color("fbf6ea")
## The plate and rim colour: a deep blue-green night, not black, so the dark
## reads as shade on grass and as dusk on snow.
const SHADE := Color("081218")
const PLATE_ALPHA := 0.4
const MUTED := Color("c9c3b6")
## Halo tints by brush, mode and button.
const TINTS := {
	"land":Color("ecd49c"),"water":Color("a8dcf0"),"meadow":Color("cfe78c"),"forest":Color("9fe3c0"),"path":Color("ebc7a2"),
	"paint":Color("f3e2b8"),"lower":Color("d9c6f0"),"look":Color("bfe0f0"),"undo":Color("f6dcae"),
	"mood":Color("f0c3cc"),"world":Color("c6d9f2"),"craft":Color("e8d7b4"),"photo":Color("f6dcae"),
}
## The glyph files (assets/ui/lantern, copies of docs/ui/glyphs/lantern-maker,
## imported at 4x with mipmaps so they stay crisp from 0.7x to retina).
const GLYPH_DIR := "res://assets/ui/lantern/"
## Brushes, forms and modes whose glyph file has another name.
const GLYPH_FILES := {"look":"grab","eye":"look","form_alpine":"form-alpine","form_ridge":"form-ridge","form_mesa":"form-mesa",
	"form_volcano":"form-volcano","form_tors":"form-tors","hill":"form-hill","spring":"season-spring","summer":"season-summer",
	"autumn":"season-autumn","winter":"season-winter","empty":"slot-empty"}
const FONT_PATH := "res://assets/fonts/CormorantGaramond-SemiBold-latin.ttf"

static var _glyphs := {}
static var _font: FontVariation
static var _text_font: FontVariation
static var _glyph_material: ShaderMaterial

## `min(W/1440, H/900)`: the shell keeps its proportions at any window size.
static func ui_scale(screen: Vector2) -> float:
	return maxf(0.5,minf(screen.x/DESIGN.x,screen.y/DESIGN.y))

static func tint(id: String) -> Color:
	return TINTS.get(id,LIGHT)

## A glyph by brush, form or file name; a form id ("alpine") or its palette
## glyph ("form_alpine") both work. Unknown names get the empty slot.
static func glyph(id: String) -> Texture2D:
	if _glyphs.has(id): return _glyphs[id]
	var file: String = GLYPH_FILES.get(id,GLYPH_FILES.get("form_"+id,id))
	var path := GLYPH_DIR+file+".svg"
	var texture: Texture2D = load(path) if ResourceLoader.exists(path) else load(GLYPH_DIR+"slot-empty.svg")
	_glyphs[id] = texture
	return texture

## Cormorant Garamond SemiBold in spaced capitals, as the mockups set their
## names. (Its c2sc small capitals shrink to the x-height, too small to read
## at 12 px over fog, so the capitals stay full size and the tracking does the
## small-caps work.)
static func font() -> FontVariation:
	if _font != null: return _font
	_font = FontVariation.new()
	_font.base_font = load(FONT_PATH)
	var server := TextServerManager.get_primary_interface()
	_font.opentype_features = {server.name_to_tag("lnum"):1}
	_font.spacing_glyph = 2
	return _font

## The same face, tracked for sentences: notices and the camera's first-run line.
static func text_font() -> FontVariation:
	if _text_font != null: return _text_font
	_text_font = font().duplicate()
	_text_font.spacing_glyph = 0
	_text_font.spacing_space = 1
	return _text_font

static func caps(text: String) -> String:
	return text.to_upper()

## A spaced-capitals label with a dark rim (the outline) inside a soft dark
## under-glow (the shadow, spread wide), so warm-white letters hold over white
## fog and snow without reading as a black box.
static func label(text: String, size := 12, color := LIGHT) -> Label:
	var node := Label.new()
	node.text = caps(text)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_label(node,size,color)
	return node

static func style_label(node: Control, size := 12, color := LIGHT, sentence := false) -> void:
	node.add_theme_font_override("font",text_font() if sentence else font())
	node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",color)
	node.add_theme_color_override("font_outline_color",Color(SHADE,0.62))
	node.add_theme_constant_override("outline_size",3)
	node.add_theme_color_override("font_shadow_color",Color(SHADE,0.3))
	node.add_theme_constant_override("shadow_outline_size",9)
	node.add_theme_constant_override("shadow_offset_x",0)
	node.add_theme_constant_override("shadow_offset_y",0)

## The soft dark plate under a group: its shadow is the same colour, so its
## edge fades out instead of ending in a line.
static func plate(radius := 40, alpha := PLATE_ALPHA, spread := 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(SHADE,alpha)
	style.shadow_color = Color(SHADE,alpha*0.9)
	style.shadow_size = spread
	style.set_corner_radius_all(radius)
	style.corner_detail = 12
	style.anti_aliasing = true
	return style

## The glyph material: a dark rim round the strokes, then a faint light glow,
## then the glyph (shaders/lantern_glyph.gdshader). Shared by every glyph.
static func glyph_material() -> ShaderMaterial:
	if _glyph_material != null: return _glyph_material
	_glyph_material = ShaderMaterial.new()
	_glyph_material.shader = preload("res://shaders/lantern_glyph.gdshader")
	return _glyph_material

## A glyph as a TextureRect that draws with the rim-and-glow material.
static func glyph_rect(id: String, size: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = glyph(id)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size = Vector2.ONE*size
	rect.pivot_offset = rect.size*0.5
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = glyph_material()
	return rect

## An empty stylebox set, so a Button draws only what the slot draws.
static func bare(button: BaseButton) -> void:
	for state: String in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

## A dotted thread from `a` to `b`, as the mockups join forms and moods.
static func thread(canvas: CanvasItem, a: Vector2, b: Vector2, color := Color(LIGHT,0.45), step := 6.0, dot := 1.1) -> void:
	var length := a.distance_to(b)
	var count := int(length/step)
	for i in range(1,count):
		canvas.draw_circle(a.lerp(b,float(i)/count),dot,color)
