extends RefCounted
## The HUD's shared look (design "ZenScape HUD 4c", Claude Design project
## a0f03cdb, `design_handoff_lowpoly_linen_hud_4c/README.md`; notes in
## docs/design/materials-tray/HUD-4c.md): linen in shadow, stitched, with
## small caps printed on it. The materials bar (scripts/materials_tray.gd)
## and the tool roll (scripts/tool_roll.gd) both draw with it, so tuning a
## token here tunes both.
##
## Lengths are design pixels at the reference frame (1440 wide), multiplied by
## the Lantern UI scale (scripts/lantern_style.gd `ui_scale`) when drawn.

const Style = preload("res://scripts/lantern_style.gd")
const DISPLAY = preload("res://assets/fonts/newsreader-latin.woff2")
const SHADER = preload("res://shaders/hud_linen.gdshader")

## Tokens (4c "Design tokens").
const INK := Color("e3d7bd")
const HAIRLINE := Color(0.890,0.843,0.741,0.45)
const PRESSED := Color(0.078,0.055,0.031,0.2)
const PRESSED_SHADE := Color(0.039,0.031,0.016,0.32)
const HOVER := Color(0.078,0.055,0.031,0.1)
const HOVER_SHADE := Color(0.039,0.031,0.016,0.16)
const FOCUS := Color("e3d7bd")
const CUE := Color(0.890,0.843,0.741,0.5)
const DIVIDER := Color(0.890,0.843,0.741,0.32)
const ICON_SHADOW := Color(0.047,0.035,0.020,0.28)
const POCKET := Color(0.078,0.055,0.031,0.08)
const POCKET_STITCH := Color(0.890,0.843,0.741,0.26)
const POCKET_MOUTH := Color(0.078,0.055,0.031,0.34)
const POCKET_LIGHT := Color(1.0,0.941,0.843,0.08)
const PIP_REST := Color(0.890,0.843,0.741,0.42)
const PIP_STITCH := Color(0.890,0.843,0.741,0.75)
## At rest a bar shows REST_OPACITY of itself, sunk or tucked its REST_OFFSET;
## reached for, it comes up over REACH s, and goes back over RECEDE s after
## HOLD s.
const REST_OPACITY := 0.6
const REACH := 0.25
const RECEDE := 0.4
const HOLD := 0.3
## Slots, icons and their radius; the tag's type size and tracking (em of
## TAG_SIZE). The shipped Newsreader has no small caps, so they are set as
## capitals at TAG_CAPS, about the x-height of TAG_SIZE.
const SLOT := 60.0
const ICON := 44.0
const SLOT_RADIUS := 9.0
const TAG_SIZE := 13.0
const TAG_TRACK := 0.22
const TAG_CAPS := 10.0
## The reference frame's width, which design pixels are measured against.
const FRAME := 1440.0

## One design pixel in viewport pixels.
static func scale_for(viewport: Vector2) -> float:
	return Style.ui_scale(viewport)*Style.DESIGN.x/FRAME

## The tag's font: Newsreader at weight 500.
static func tag_font() -> FontVariation:
	var font := FontVariation.new()
	font.base_font = DISPLAY
	font.variation_opentype = {"wght":500}
	return font

## An eased 0..1.
static func eased(t: float) -> float:
	var u := clampf(t,0.0,1.0)
	return u*u*(3.0-2.0*u)

## A strip of linen: a Control drawing the cloth under its parent's drawing.
class Cloth extends Control:
	var material_ref: ShaderMaterial
	## The strip, viewport pixels, and the room round it for the shadow.
	var strip := Rect2()
	var margin := 24.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		show_behind_parent = true
		material_ref = ShaderMaterial.new()
		material_ref.shader = preload("res://shaders/hud_linen.gdshader")
		material = material_ref

	## Places the strip; `px` is one design pixel. `radius` and `hem` (inset,
	## radius; 0 inset for none) in design pixels.
	func place(rect: Rect2, px: float, radius := 12.0, hem := Vector2(5.0,8.0), shadow := true) -> void:
		strip = rect
		margin = ceilf(30.0*px)
		position = rect.position-Vector2.ONE*margin
		size = rect.size+Vector2.ONE*margin*2.0
		material_ref.set_shader_parameter("strip",rect.size)
		material_ref.set_shader_parameter("margin",margin)
		material_ref.set_shader_parameter("radius",radius)
		material_ref.set_shader_parameter("px",px)
		material_ref.set_shader_parameter("hem_inset",hem.x)
		material_ref.set_shader_parameter("hem_radius",hem.y)
		material_ref.set_shader_parameter("shadow",Color(0.071,0.086,0.118,0.2 if shadow else 0.0))
		material_ref.set_shader_parameter("shadow_y",6.0 if radius > 4.0 else 4.0)
		material_ref.set_shader_parameter("shadow_blur",18.0 if radius > 4.0 else 12.0)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color.WHITE)

# --- Drawing helpers (on any CanvasItem) --------------------------------------------

## A filled rounded rect.
static func fill_round(item: CanvasItem, rect: Rect2, radius: float, colour: Color) -> void:
	if colour.a <= 0.0: return
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.set_corner_radius_all(int(round(radius)))
	box.corner_detail = 6
	box.anti_aliasing = true
	item.draw_style_box(box,rect)

## A slot pressed into the cloth: the patch, darker at its top edge as an
## inset shadow would be (`inset 0 2px 5px`).
static func pressed_patch(item: CanvasItem, rect: Rect2, px: float, patch: Color, shade: Color) -> void:
	if patch.a <= 0.0: return
	fill_round(item,rect,SLOT_RADIUS*px,patch)
	for i in range(3):
		var h := (2.0+i*1.6)*px
		var box := StyleBoxFlat.new()
		box.bg_color = Color(shade,shade.a*0.34)
		box.corner_radius_top_left = int(round(SLOT_RADIUS*px))
		box.corner_radius_top_right = int(round(SLOT_RADIUS*px))
		box.corner_radius_bottom_left = int(round(minf(SLOT_RADIUS*px,h*0.5)))
		box.corner_radius_bottom_right = box.corner_radius_bottom_left
		box.anti_aliasing = true
		item.draw_style_box(box,Rect2(rect.position,Vector2(rect.size.x,h)))

## Points round a rounded rect, clockwise from its top-left corner's end.
static func round_points(rect: Rect2, radius: float) -> PackedVector2Array:
	var r := minf(radius,minf(rect.size.x,rect.size.y)*0.5)
	var points := PackedVector2Array()
	var corners := [[Vector2(rect.end.x-r,rect.position.y+r),-PI*0.5],[Vector2(rect.end.x-r,rect.end.y-r),0.0],
		[Vector2(rect.position.x+r,rect.end.y-r),PI*0.5],[Vector2(rect.position.x+r,rect.position.y+r),PI]]
	for corner: Array in corners:
		for k in range(7):
			points.append(corner[0]+Vector2.from_angle(float(corner[1])+PI*0.5*k/6.0)*r)
	points.append(points[0])
	return points

## A dashed line along `points`: `on` then `off` pixels, `width` wide.
static func dashed(item: CanvasItem, points: PackedVector2Array, colour: Color, width: float, on: float, off: float) -> void:
	if colour.a <= 0.0 or points.size() < 2: return
	var drawing := true
	var left := on
	for i in range(points.size()-1):
		var a := points[i]
		var b := points[i+1]
		var length := a.distance_to(b)
		var at := 0.0
		while at < length:
			var run := minf(left,length-at)
			var from := a.lerp(b,at/length)
			var to := a.lerp(b,(at+run)/length)
			if drawing: item.draw_line(from,to,colour,width,true)
			at += run
			left -= run
			if left <= 0.0:
				drawing = not drawing
				left = on if drawing else off

## A dashed rounded outline.
static func dashed_round(item: CanvasItem, rect: Rect2, radius: float, colour: Color, width: float, px: float) -> void:
	dashed(item,round_points(rect,radius),colour,width,3.0*px,3.0*px)

## A dashed circle.
static func dashed_circle(item: CanvasItem, centre: Vector2, radius: float, colour: Color, width: float, px: float) -> void:
	var points := PackedVector2Array()
	for k in range(33): points.append(centre+Vector2.from_angle(TAU*k/32.0)*radius)
	dashed(item,points,colour,width,2.0*px,2.0*px)

## An icon from scripts/hud_icons.gd, drawn `icon_px` across its 24-unit box
## round `centre`, with its drop shadow `shadow_y` design pixels below.
static func icon(item: CanvasItem, textures: Dictionary, id: String, centre: Vector2, icon_px: float, px: float, variant: String, shadow_y: float, tint := Color.WHITE) -> void:
	var extent := icon_px*28.0/24.0
	var rect := Rect2((centre-Vector2.ONE*extent*0.5).round(),Vector2.ONE*roundf(extent))
	if shadow_y > 0.0:
		var shade: Texture2D = textures.get(id+":shadow")
		if shade != null: item.draw_texture_rect(shade,Rect2(rect.position+Vector2(0.0,roundf(shadow_y*px)),rect.size),false,Color(ICON_SHADOW,ICON_SHADOW.a*tint.a))
	var texture: Texture2D = textures.get(id+":"+variant)
	if texture == null: return
	var Icons = preload("res://scripts/hud_icons.gd")
	var colour := Color(tint,tint.a*float(Icons.item(id).get("opacity",1.0)))
	if variant == "locked": colour = Color(Icons.LOCKED*Color(tint.r,tint.g,tint.b),tint.a)
	item.draw_texture_rect(texture,rect,false,colour)

## Rasterises every variant of `ids` at `icon_px` into `into` (id:variant).
static func rasterise(into: Dictionary, ids: Array, icon_px: float) -> void:
	var Icons = preload("res://scripts/hud_icons.gd")
	into.clear()
	for id: String in ids:
		for variant: String in ["icon","lit","shadow","locked"]:
			var texture: Texture2D = Icons.texture(id,variant,icon_px)
			if texture != null: into[id+":"+variant] = texture

## Small caps with a hairline beneath, centred on `centre_x` with its
## hairline at `rule_y`. Returns the text's width.
static func tag(item: CanvasItem, font: FontVariation, text: String, centre_x: float, rule_y: float, px: float, alpha: float) -> float:
	text = text.to_upper()
	var size := maxi(6,roundi(TAG_CAPS*px))
	font.spacing_glyph = roundi(TAG_TRACK*TAG_SIZE*px)
	var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	# Tracking trails the last letter; centre the letters, not the box.
	var x := roundf(centre_x-(width-font.spacing_glyph)*0.5)
	var baseline := roundf(rule_y-3.0*px)
	item.draw_string(font,Vector2(x,baseline),text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(INK,alpha))
	var line := maxf(1.0,roundf(px))
	item.draw_line(Vector2(x,rule_y+line*0.5),Vector2(x+width-font.spacing_glyph,rule_y+line*0.5),Color(HAIRLINE,HAIRLINE.a*alpha),line)
	return width-font.spacing_glyph

static func tag_width(font: FontVariation, text: String, px: float) -> float:
	text = text.to_upper()
	var size := maxi(6,roundi(TAG_CAPS*px))
	font.spacing_glyph = roundi(TAG_TRACK*TAG_SIZE*px)
	return font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x-font.spacing_glyph
