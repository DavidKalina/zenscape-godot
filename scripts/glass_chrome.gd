extends RefCounted
## Quiet glass chrome for the creation shell: a dark translucent tint over a
## softly blurred copy of the world, transparent resting buttons with a thin
## selected outline, and thin line glyphs. Taken from the parked maker-editor
## look (wip/parked-2026-09-26, scripts/maker_editor_style.gd and
## shaders/editor_glass.gdshader); its pixel-stepped colour sprites stay parked.
const INK := Color("e2e8e6")
const MUTED := Color("97a7a3")
const ACCENT := Color("bedbd1")
## The blur reads the rendered frame through the screen texture. Only panel
## surfaces carry it; buttons and text draw on top without it.
const BLUR := true

static func panel(radius := 12, padding := 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("182422bc")
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	style.set_border_width_all(1)
	style.border_color = Color("d4ede614")
	style.anti_aliasing = true
	return style

## A panel that blurs the world behind it. Give it no children: buttons and
## text on the glass sit in a sibling container laid over it.
static func surface(radius := 14) -> Panel:
	var glass := Panel.new()
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.add_theme_stylebox_override("panel",panel(radius,0))
	if BLUR:
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/editor_glass.gdshader")
		glass.material = material
	return glass

static func button(target: BaseButton, accent := ACCENT, radius := 9) -> void:
	for state: String in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		var style := panel(radius,6)
		style.bg_color = Color.TRANSPARENT
		style.border_color = Color.TRANSPARENT
		if state == "hover": style.bg_color = Color(accent,0.10)
		if state in ["pressed","hover_pressed"]:
			style.bg_color = Color(accent,0.12 if state == "hover_pressed" else 0.07)
			style.border_color = Color(accent,0.55)
		if state == "focus": style.border_color = Color(accent,0.35)
		target.add_theme_stylebox_override(state,style)
	for state: String in ["normal","hover","pressed","hover_pressed","focus"]:
		target.add_theme_color_override("font_color" if state == "normal" else "font_"+state+"_color",INK if state != "normal" else Color(INK,0.82))
		target.add_theme_color_override("icon_"+state+"_color",INK if state != "normal" else Color(INK,0.78))
	target.add_theme_color_override("font_disabled_color",Color(MUTED,0.3))
	target.add_theme_color_override("icon_disabled_color",Color(MUTED,0.3))
	target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

## A popup menu dressed to match: the same tint, a soft hover, muted separators.
static func popup(menu: PopupMenu) -> void:
	menu.add_theme_stylebox_override("panel",panel(12,8))
	var hover := panel(7,4)
	hover.bg_color = Color(ACCENT,0.12)
	hover.border_color = Color.TRANSPARENT
	menu.add_theme_stylebox_override("hover",hover)
	var line := StyleBoxLine.new()
	line.color = Color(INK,0.12)
	line.grow_begin = -6
	line.grow_end = -6
	menu.add_theme_stylebox_override("separator",line)
	menu.add_theme_color_override("font_color",Color(INK,0.86))
	menu.add_theme_color_override("font_hover_color",INK)
	menu.add_theme_color_override("font_disabled_color",Color(MUTED,0.4))
	menu.add_theme_constant_override("v_separation",10)
	menu.add_theme_constant_override("item_start_padding",12)
	menu.add_theme_constant_override("item_end_padding",16)
	menu.add_theme_font_size_override("font_size",14)

## Thin line glyphs on a 24px grid, drawn white so buttons can tint them.
const GLYPHS := {
	"land":'<path d="M2 19 L8 10 L11 14 L15 6 L22 19 Z"/><path d="M13.2 9.4 L15 6 L16.8 9.4"/>',
	"water":'<path d="M12 3 C12 3 5.5 10.5 5.5 14.5 A6.5 6.5 0 0 0 18.5 14.5 C18.5 10.5 12 3 12 3 Z"/><path d="M9 15 A3 3 0 0 0 12 18"/>',
	"meadow":'<path d="M3 20 C6 18 9 18 12 20 C15 18 18 18 21 20"/><path d="M7 18 V11 M12 19 V8 M17 18 V12"/><circle cx="12" cy="6" r="2"/><circle cx="7" cy="9" r="1.5"/>',
	"forest":'<path d="M8 3 L3.5 12 H6 L3 18 H13 L10 12 H12.5 Z"/><path d="M8 18 V21"/><path d="M17 8 L13.5 15 H20.5 Z M17 15 V21"/>',
	"path":'<path d="M9 21 C9 16 15 15 15 11 C15 7 10 7 10 3"/><path d="M14 21 C14 17 19 15.5 19 11 C19 7.5 15 6 15 3" stroke-opacity="0.5"/>',
	"look":'<path d="M2 12 C5 6.5 8.5 5 12 5 C15.5 5 19 6.5 22 12 C19 17.5 15.5 19 12 19 C8.5 19 5 17.5 2 12 Z"/><circle cx="12" cy="12" r="3.2"/>',
	"craft":'<path d="M14.5 4.5 L19.5 9.5 L9 20 H4 V15 Z"/><path d="M12.5 6.5 L17.5 11.5"/>',
	"world":'<circle cx="12" cy="12" r="9"/><ellipse cx="12" cy="12" rx="4" ry="9"/><path d="M3 12 H21"/>',
	"dot":'<circle cx="12" cy="12" r="4"/>',
}

## Unknown kinds get a quiet dot. Not cached: a shell draws only a handful.
static func glyph(kind: String, size := 24) -> Texture2D:
	var image := Image.new()
	var body: String = GLYPHS.get(kind,GLYPHS.dot)
	image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="#ffffff" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">'+body+'</g></svg>',size/24.0)
	return ImageTexture.create_from_image(image)
