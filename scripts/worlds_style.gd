extends RefCounted
## Tokens for the worlds screens: title library, new world and pause
## (docs/design/worlds/README.md "Design Tokens"). The cloth itself is
## scripts/hud_linen.gd `Cloth`; lengths are design pixels at the 1440-wide
## reference frame, times scripts/hud_linen.gd `scale_for`.

const Linen = preload("res://scripts/hud_linen.gd")
const NEWSREADER = preload("res://assets/fonts/newsreader-latin.woff2")
const SPECTRAL = preload("res://assets/fonts/spectral-latin-400.woff2")

const INK_PRIMARY := Color("f6eedc")  # headlines on the scene
const INK := Color("f1e8d4")          # text on linen
const THREAD := Color("e3d7bd")       # accent, primary button fill
const SECONDARY_SCENE := Color("d4c9b2")
const SECONDARY_LINEN := Color("c2b8a3")
const MUTED := Color("a39a88")
const MUTED_LABEL := Color("bfb49e")
const HOVER_INK := Color("fffaf0")
const DESTRUCTIVE := Color("f0a383")
const STATUS_OK := Color("b9c99a")
const BUTTON_TEXT := Color("2a251f")
const BUTTON_HOVER := Color("f4ead3")
const PAGE_DARK := Color("1d1c24")
const INPUT_FILL := Color(20/255.0,16/255.0,12/255.0,0.35)
const INPUT_RULE := Color(227/255.0,215/255.0,189/255.0,0.5)
const ROW_HOVER := Color(20/255.0,15/255.0,10/255.0,0.22)
const ROW_FOCUS := Color(20/255.0,15/255.0,10/255.0,0.28)
const WELL := Color(20/255.0,15/255.0,10/255.0,0.3)

## Newsreader at a weight (400 or 500), tracked by `track_em` of `size`.
## The shipped Newsreader has no small caps: set caps text with `caps()`.
static func newsreader(weight := 400, size := 0.0, track_em := 0.0) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = NEWSREADER
	font.variation_opentype = {"wght":weight}
	if size > 0.0 and track_em > 0.0: font.spacing_glyph = roundi(size*track_em)
	return font

static func spectral() -> FontVariation:
	var font := FontVariation.new()
	font.base_font = SPECTRAL
	return font

## Spectral italic: the shipped Spectral is upright only, so slant it.
static func spectral_italic() -> FontVariation:
	var font := spectral()
	font.variation_transform = Transform2D(Vector2(1,0),Vector2(0.2,1),Vector2.ZERO)
	return font

## All-small-caps stand-in: capitals set at about the x-height (0.78 of size).
static func caps(text: String) -> String:
	return text.to_upper()

static func caps_size(size: float) -> int:
	return roundi(size*0.78)
