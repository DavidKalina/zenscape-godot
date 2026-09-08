extends RefCounted
## Shared warm surfaces for the everyday building tools.
const INK := Color("f1e9dc")
const MUTED := Color("bcb0a5")
const HONEY := Color("dfb979")
const SURFACE := Color("302b30f7")

static func panel(radius := 20, padding := 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = SURFACE
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	style.set_border_width_all(1)
	style.border_color = Color("72605266")
	style.shadow_color = Color("110d1438")
	style.shadow_size = 12
	style.shadow_offset = Vector2(0,6)
	return style

static func button(target: Button, selected := false) -> void:
	for state: String in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		var style := panel(12,8)
		style.shadow_size = 0
		style.bg_color = Color("ffffff00")
		style.border_color = Color("ffffff00")
		if state == "hover": style.bg_color = Color("eedcc012")
		if state in ["pressed","hover_pressed"]:
			style.bg_color = HONEY if selected else Color("eedcc024")
			style.border_color = Color("f3d5a275")
		if state == "focus": style.border_color = HONEY
		target.add_theme_stylebox_override(state,style)
	target.add_theme_color_override("font_color",INK)
	target.add_theme_color_override("font_hover_color",Color("fff6e6"))
	target.add_theme_color_override("font_pressed_color",Color("332c29") if selected else INK)
	target.add_theme_color_override("font_hover_pressed_color",Color("332c29") if selected else INK)
	target.add_theme_color_override("icon_pressed_color",Color("332c29") if selected else INK)
	target.add_theme_color_override("icon_hover_pressed_color",Color("332c29") if selected else INK)
	target.add_theme_color_override("icon_normal_color",INK)
	target.add_theme_color_override("icon_hover_color",INK)
	target.add_theme_color_override("font_disabled_color",Color("bcb0a560"))
	target.add_theme_color_override("icon_disabled_color",Color("bcb0a560"))
	target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func slider(target: HSlider) -> void:
	for state: String in ["slider","grabber_area","grabber_area_highlight"]:
		var track := StyleBoxFlat.new()
		track.bg_color = Color("171519") if state == "slider" else HONEY
		track.set_corner_radius_all(3)
		track.content_margin_top = 3
		track.content_margin_bottom = 3
		target.add_theme_stylebox_override(state,track)
	var image := Image.new()
	image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="18" height="20"><circle cx="9" cy="11" r="7" fill="#171519" fill-opacity=".5"/><circle cx="9" cy="9" r="7" fill="#efdfc4"/><path d="M5 7 Q9 3 13 7" fill="none" stroke="#fff8e9" stroke-width="1.5"/></svg>')
	var texture := ImageTexture.create_from_image(image)
	for state: String in ["grabber","grabber_highlight","grabber_disabled"]: target.add_theme_icon_override(state,texture)
	target.custom_minimum_size.y = 28
	target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func icon(kind: String) -> Texture2D:
	var paths := {
		"Select":'<path d="m6 3 13 10-7 1-3 7Z"/>',
		"Sculpt":'<path d="m3 19 7-13 4 7 2-3 5 9Z M8 10l2 2 2-2"/>',
		"Paint":'<path d="M12 21V10 M12 15C3 15 4 8 4 8c7 0 8 7 8 7ZM12 11s0-7 8-7c0 0 1 7-8 7Z"/>',
		"Place":'<path d="m12 3-5 7h3l-5 7h6v4h2v-4h6l-5-7h3Z"/>',
		"Water":'<path d="M12 3S5 11 5 15a7 7 0 0 0 14 0c0-4-7-12-7-12Z M8 15q0 4 4 4"/>',
		"Browse":'<rect x="4" y="4" width="6" height="6" rx="2"/><rect x="14" y="4" width="6" height="6" rx="2"/><rect x="4" y="14" width="6" height="6" rx="2"/><path d="M17 14v6m-3-3h6"/>',
		"undo":'<path d="m8 4-5 5 5 5M3 9h10a6 6 0 0 1 0 12"/>',
		"redo":'<path d="m16 4 5 5-5 5m5-5H11a6 6 0 0 0 0 12"/>',
		"close":'<path d="m7 7 10 10M7 17 17 7"/>',
	}
	var image := Image.new()
	image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="white" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round">'+str(paths.get(kind,""))+'</g></svg>')
	return ImageTexture.create_from_image(image)
