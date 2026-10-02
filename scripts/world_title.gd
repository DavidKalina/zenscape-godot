extends Control
## The title screen as the world library (docs/design/worlds/README.md
## "1. Title + worlds", direction 1b): the wordmark, the selected world's
## name, when it was last played and what can be done with it, over the live
## backdrop, and every world as a tile on a strip of linen along the foot.
## Rename, duplicate and delete happen here through scripts/world_library.gd;
## entering, a new world, settings and quitting are the host's. Lengths are
## design pixels of the 1440-wide frame times scripts/hud_linen.gd
## `scale_for`, laid out from the screen's edges.
##
## The host draws the selected world live behind this Control. On every
## `selection_changed` the selected world's capture fades in over it (dark
## when there is none); call `reveal_live` once the live world has caught up.

signal selection_changed(world: Dictionary)
signal enter_requested(world: Dictionary)
signal new_world_requested
signal settings_requested
signal quit_requested

const Library = preload("res://scripts/world_library.gd")
const Style = preload("res://scripts/worlds_style.gd")
const Linen = preload("res://scripts/hud_linen.gd")
## Muted fills standing in for a capture, by land.
const LAND_TINTS := {"plain":Color("66704f"),"canyon":Color("7d5544"),"isle":Color("5f686d"),"hollow":Color("4a5743"),
	"wildflowers":Color("7d8a4c"),"sunflowers":Color("a08a3c"),"dandelions":Color("6f8f45"),"cosmos":Color("9a7484"),"alpine_meadow":Color("5f7a66")}
const TILE := Vector2(156,96)
const TILE_GAP := 14.0
const TILE_LABEL_GAP := 7.0
const LIFT := 6.0
## The strip's padding: left, top, right, bottom.
const STRIP_PAD := Vector4(24,18,24,14)
const FADE := 0.3
const SCRIM_DARK := Color(16/255.0,12/255.0,16/255.0)
## The strip's backdrop-filter: blur(6px), as a few taps of the screen's mipmaps.
const BLUR_SHADER := "shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec2 extent = vec2(100.0);
uniform float radius = 14.0;
uniform float blur = 6.0;
void fragment() {
	vec2 h = extent*0.5;
	vec2 q = abs(UV*extent-h)-h+vec2(radius);
	float d = length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-radius;
	float lod = log2(max(blur,1.0));
	vec2 step = SCREEN_PIXEL_SIZE*blur*0.5;
	vec3 c = textureLod(screen_texture,SCREEN_UV,lod).rgb*0.4;
	c += textureLod(screen_texture,SCREEN_UV+vec2(step.x,step.y),lod).rgb*0.15;
	c += textureLod(screen_texture,SCREEN_UV+vec2(-step.x,step.y),lod).rgb*0.15;
	c += textureLod(screen_texture,SCREEN_UV+vec2(step.x,-step.y),lod).rgb*0.15;
	c += textureLod(screen_texture,SCREEN_UV-step,lod).rgb*0.15;
	COLOR = vec4(c,1.0-smoothstep(-0.5,0.5,d));
}"

var library
## A fixed clock (unix seconds) for tests; below 0 reads the system's.
var now := -1.0
## idle, rename or delete; one at a time.
var mode := "idle"
var selected := 0
## The worlds as shown: most recently played first, except that a duplicate
## sits after its source until the next `refresh`.
var worlds: Array = []
var tiles: Array = []
var new_tile: Tile
var px := 1.0
var kicker: Label
var name_label: Label
var rename_edit: LineEdit
var when_label: Label
var enter_button: Button
var rename_button: Button
var duplicate_button: Button
var delete_button: Button
var keep_name_button: Button
var cancel_button: Button
var delete_card: MarginContainer
var keep_button: Button
var let_go_button: Button
var settings_button: Button
var quit_button: Button
var hint: Label
var veil := Control.new()
var capture := TextureRect.new()
var strip := Control.new()
var _strip_cloth := Linen.Cloth.new()
var _blur := ColorRect.new()
var _clip := Control.new()
var _row := Control.new()
var _scroll := 0.0
var _scroll_tween: Tween
var _veil_tween: Tween
var _shown_id := "~"
var _textures := {}

# --- Shared typesetting (scripts/new_world_panel.gd uses these too) ------------------

## Sets `node` in `font` at `size` design pixels, tracked `track` em, in
## `colour`; `caps` sets it at the small-caps size. `rescale` fits it.
static func typeset(node: Control, font: FontVariation, size: float, colour: Color, track := 0.0, caps := false) -> Control:
	node.set_meta("type",[size,track,caps])
	node.set_meta("font",font)
	node.add_theme_font_override("font",font)
	node.add_theme_color_override("font_color",colour)
	return node

static func label(text: String, font: FontVariation, size: float, colour: Color, track := 0.0, caps := false) -> Label:
	var node := Label.new()
	node.text = Style.caps(text) if caps else text
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return typeset(node,font,size,colour,track,caps)

## A soft text shadow: `offset_y` and `spread` design pixels. Godot's font
## shadow has no blur, so it is an outline, faint.
static func shadow(node: Label, colour: Color, offset_y: float, spread: float) -> void:
	node.set_meta("shadow",[offset_y,spread])
	node.add_theme_color_override("font_shadow_color",colour)

## A small-caps text link, `hover` under the pointer.
static func link(text: String, size: float, colour: Color, hover: Color, track: float) -> Button:
	var node := Button.new()
	node.text = Style.caps(text)
	_bare(node)
	for state in ["normal","hover","pressed","hover_pressed","focus","disabled"]: node.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for state in ["font_hover_color","font_pressed_color","font_hover_pressed_color"]: node.add_theme_color_override(state,hover)
	node.add_theme_color_override("font_focus_color",colour)
	return typeset(node,Style.newsreader(500),size,colour,track,true)

## A filled button; `pad` its padding (x, y) and `border` its outline, if any.
static func button(text: String, size: float, colour: Color, fill: Color, hover_fill: Color, pad: Vector2, border := Color.TRANSPARENT) -> Button:
	var node := Button.new()
	node.text = text
	_bare(node)
	var boxes := {}
	for state in ["normal","hover","pressed","hover_pressed","disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = fill if state in ["normal","disabled"] else hover_fill
		box.draw_center = box.bg_color.a > 0.0
		box.set_corner_radius_all(8)
		box.anti_aliasing = true
		box.content_margin_left = pad.x
		box.content_margin_right = pad.x
		box.content_margin_top = pad.y
		box.content_margin_bottom = pad.y
		if border.a > 0.0:
			box.border_color = border
			box.set_border_width_all(1)
		boxes[state] = box
	node.set_meta("boxes",boxes)
	node.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	for state in ["font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]: node.add_theme_color_override(state,colour)
	return typeset(node,Style.newsreader(500),size,colour)

## The primary button: thread-coloured, dark text.
static func primary(text: String, size := 18.0, pad := Vector2(26,10)) -> Button:
	return button(text,size,Style.BUTTON_TEXT,Style.THREAD,Style.BUTTON_HOVER,pad)

static func _bare(node: Button) -> void:
	node.focus_mode = Control.FOCUS_NONE
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER

## A one-line input: `fill`, a dashed `rule` beneath, top corners `radius`.
static func input(size: float, colour: Color, fill: Color, rule: Color, radius: float, pad: Vector2) -> LineEdit:
	var node := LineEdit.new()
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.corner_radius_top_left = int(radius)
	box.corner_radius_top_right = int(radius)
	box.anti_aliasing = true
	box.content_margin_left = pad.x
	box.content_margin_right = pad.x
	box.content_margin_top = pad.y
	box.content_margin_bottom = pad.y
	node.set_meta("boxes",{"normal":box,"read_only":box})
	node.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	node.add_theme_color_override("caret_color",Style.THREAD)
	node.add_theme_color_override("selection_color",Color(Style.THREAD,0.3))
	node.add_theme_color_override("font_selected_color",colour)
	node.add_theme_color_override("font_placeholder_color",Color("8f8676"))
	dashed_rule(node,rule)
	return typeset(node,Style.newsreader(400),size,colour)

## A dashed 1px rule along `node`'s bottom (or top) edge.
static func dashed_rule(node: Control, colour: Color, top := false) -> void:
	node.set_meta("deco",true)
	node.draw.connect(func() -> void:
		var unit: float = node.get_meta("px",1.0)
		var line := maxf(1.0,roundf(unit))
		var y := line*0.5 if top else node.size.y-line*0.5
		Linen.dashed(node,PackedVector2Array([Vector2(0,y),Vector2(node.size.x,y)]),colour,line,3.0*unit,3.0*unit))

## A dashed outline round `node`, `width` and `radius` in design pixels.
static func dashed_box(node: Control, colour: Color, radius: float, width := 1.0) -> void:
	node.set_meta("deco",true)
	node.draw.connect(func() -> void:
		var unit: float = node.get_meta("px",1.0)
		var line := maxf(1.0,width*unit)
		Linen.dashed_round(node,Rect2(Vector2.ONE*line*0.5,node.size-Vector2.ONE*line),radius*unit,colour,line,unit))

## Fits every typeset node, box, gap, margin and minimum under `root` to `s`
## viewport pixels per design pixel.
static func rescale(root: Node, s: float) -> void:
	for node: Node in [root]+root.find_children("*","Control",true,false):
		var control := node as Control
		if control.has_meta("type"):
			var type: Array = control.get_meta("type")
			control.add_theme_font_size_override("font_size",maxi(1,roundi(float(type[0])*s*(0.78 if type[2] else 1.0))))
			(control.get_meta("font") as FontVariation).spacing_glyph = roundi(float(type[0])*s*float(type[1]))
		if control.has_meta("shadow"):
			var shade: Array = control.get_meta("shadow")
			control.add_theme_constant_override("shadow_offset_x",0)
			control.add_theme_constant_override("shadow_offset_y",roundi(float(shade[0])*s))
			control.add_theme_constant_override("shadow_outline_size",roundi(float(shade[1])*s))
		if control.has_meta("boxes"):
			var boxes: Dictionary = control.get_meta("boxes")
			for state: String in boxes: control.add_theme_stylebox_override(state,_scaled(boxes[state],s))
		if control.has_meta("gap"):
			control.add_theme_constant_override("separation",roundi(float(control.get_meta("gap"))*s))
		if control.has_meta("margins"):
			var m: Vector4 = control.get_meta("margins")
			for side: Array in [["margin_left",m.x],["margin_top",m.y],["margin_right",m.z],["margin_bottom",m.w]]:
				control.add_theme_constant_override(side[0],roundi(float(side[1])*s))
		if control.has_meta("min"):
			control.custom_minimum_size = (Vector2(control.get_meta("min"))*s).round()
		if control.has_meta("deco"):
			control.set_meta("px",s)
			control.queue_redraw()
		if control.has_method("set_px"): control.set_px(s)

static func _scaled(box: StyleBoxFlat, s: float) -> StyleBoxFlat:
	var out: StyleBoxFlat = box.duplicate()
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		if box.get_content_margin(side) >= 0.0: out.set_content_margin(side,roundf(box.get_content_margin(side)*s))
		if box.get_border_width(side) > 0: out.set_border_width(side,maxi(1,roundi(box.get_border_width(side)*s)))
	for corner in [CORNER_TOP_LEFT,CORNER_TOP_RIGHT,CORNER_BOTTOM_RIGHT,CORNER_BOTTOM_LEFT]:
		out.set_corner_radius(corner,roundi(box.get_corner_radius(corner)*s))
	return out

## A box container with `gap` design pixels between its children.
static func box(vertical: bool, gap: float) -> BoxContainer:
	var node: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	node.set_meta("gap",gap)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func margins(m: Vector4) -> MarginContainer:
	var node := MarginContainer.new()
	node.set_meta("margins",m)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

## Linen behind a container's content. As a container's first child it is
## sized to the content; the cloth reaches `outset` (left, top, right, bottom
## design pixels) beyond it, over the container's padding.
class Backing extends Control:
	var cloth := Linen.Cloth.new()
	var outset := Vector4.ZERO
	var radius := 12.0
	var hem := Vector2(5,8)
	var alpha := 0.9
	var shade := Vector3(10,30,0.4)
	var px := 1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cloth)
		resized.connect(fit)

	func set_px(s: float) -> void:
		px = s
		fit()

	## The linen panel's cloth (README "Linen panel") with its shadow: `shade` is
	## its y offset, blur and alpha in design pixels.
	static func dress(cloth: Linen.Cloth, rect: Rect2, s: float, radius: float, hem: Vector2, alpha: float, shade: Vector3) -> void:
		cloth.place(rect,s,radius,hem)
		cloth.material_ref.set_shader_parameter("cloth",Color(84/255.0,75/255.0,63/255.0,alpha))
		cloth.material_ref.set_shader_parameter("shadow",Color(10/255.0,8/255.0,12/255.0,shade.z))
		cloth.material_ref.set_shader_parameter("shadow_y",shade.x)
		cloth.material_ref.set_shader_parameter("shadow_blur",shade.y)

	func fit() -> void:
		var rect := Rect2(-Vector2(outset.x,outset.y)*px,size+Vector2(outset.x+outset.z,outset.y+outset.w)*px)
		Backing.dress(cloth,Rect2(rect.position.round(),rect.size.round()),px,radius,hem,alpha,shade)

## A world on the strip: its capture (or a muted fill), its name beneath, and
## when selected a thread ring and a 6px lift. Or, `is_new`, the dashed
## "New world" tile.
class Tile extends Control:
	signal picked(tile: Tile)
	signal opened(tile: Tile)
	var world := {}
	var texture: Texture2D
	var tint := Color("66704f")
	var is_new := false
	var selected := false
	var px := 1.0
	var lift := 0.0:
		set(value):
			lift = value
			queue_redraw()
	var _tween: Tween
	var _spectral := Style.spectral()
	var _plus := Style.newsreader(400)
	var _hovered := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func() -> void:
			_hovered = true
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_hovered = false
			queue_redraw())

	func set_px(s: float) -> void:
		px = s
		queue_redraw()

	func title() -> String:
		return "New world" if is_new else str(world.get("name",""))

	## Selects or lets go, lifting over .18s (CSS `ease`) when `animate`.
	func select(on: bool, animate := true) -> void:
		selected = on
		if _tween: _tween.kill()
		if not animate or not is_inside_tree():
			lift = 1.0 if on else 0.0
			return
		_tween = create_tween()
		_tween.tween_property(self,"lift",1.0 if on else 0.0,0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			if event.double_click: opened.emit(self)
			else: picked.emit(self)

	func _draw() -> void:
		var thumb := Rect2(Vector2(0,roundf(-LIFT*px*lift)),(TILE*px).round())
		var radius := 8.0*px
		if is_new:
			Linen.fill_round(self,thumb,radius,Color(20/255.0,15/255.0,10/255.0,0.55 if _hovered else 0.35))
			var line := maxf(1.0,1.5*px)
			Linen.dashed_round(self,thumb.grow(-line*0.5),radius,Color(Style.THREAD,0.55),line,px)
			var plus_size := roundi(30.0*px)
			var plus := _plus.get_string_size("+",HORIZONTAL_ALIGNMENT_LEFT,-1,plus_size)
			draw_string(_plus,Vector2(thumb.get_center().x-plus.x*0.5,thumb.get_center().y-plus.y*0.5+_plus.get_ascent(plus_size)),"+",HORIZONTAL_ALIGNMENT_LEFT,-1,plus_size,Style.THREAD)
		else:
			var box := StyleBoxFlat.new()
			box.bg_color = tint
			box.set_corner_radius_all(roundi(radius))
			box.anti_aliasing = true
			box.shadow_color = Color(8/255.0,6/255.0,8/255.0,0.45)
			box.shadow_size = roundi(8.0*px)
			box.shadow_offset = Vector2(0,6.0*px)
			draw_style_box(box,thumb)
			if texture != null: _draw_cover(thumb,radius)
			if selected:
				var ring := maxf(1.0,1.5*px)
				draw_polyline(Linen.round_points(thumb.grow(-ring*0.5),radius-ring*0.5),Style.THREAD,ring,true)
		var line := TextLine.new()
		var font_size := roundi(14.0*px)
		line.add_string(title(),_spectral,font_size)
		line.width = maxf(1.0,thumb.size.x-4.0*px)
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var ink := Style.SECONDARY_SCENE if is_new else (Style.INK_PRIMARY if selected else Style.MUTED_LABEL)
		line.draw(get_canvas_item(),Vector2(2.0*px,thumb.end.y+roundf(TILE_LABEL_GAP*px)),ink)

	## The capture, cropped to cover the thumbnail, inside its rounded corners.
	func _draw_cover(thumb: Rect2, radius: float) -> void:
		var points := Linen.round_points(thumb,radius)
		points.remove_at(points.size()-1)
		var aspect := float(texture.get_width())/maxf(1.0,texture.get_height())
		var span := Vector2.ONE
		if aspect > thumb.size.x/thumb.size.y: span.x = thumb.size.x/thumb.size.y/aspect
		else: span.y = aspect/(thumb.size.x/thumb.size.y)
		var uvs := PackedVector2Array()
		for point in points: uvs.append((Vector2.ONE-span)*0.5+(point-thumb.position)/thumb.size*span)
		draw_colored_polygon(points,Color.WHITE,uvs,texture)

# --- The screen ----------------------------------------------------------------------

## Built whole on creation, so the host can set it up before it is in the tree.
func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The capture over the live backdrop, dark where there is none.
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.modulate.a = 0.0
	add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dark := ColorRect.new()
	dark.color = SCRIM_DARK
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(dark)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	capture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	capture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(capture)
	capture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add_scrim()
	# The wordmark, top left.
	var mark := box(true,8)
	add_child(mark)
	mark.add_child(label("ZENSCAPE",Style.newsreader(400),32,Style.INK,0.42))
	mark.add_child(label("a little wilderness, made by you",Style.newsreader(500),13,Style.SECONDARY_SCENE,0.3,true))
	mark.set_meta("edges",Vector4(64,46,-1,-1))
	# Settings and Quit, top right.
	var links := box(false,32)
	add_child(links)
	settings_button = link("Settings",14,Style.SECONDARY_SCENE,Style.HOVER_INK,0.26)
	quit_button = link("Quit",14,Style.SECONDARY_SCENE,Style.HOVER_INK,0.26)
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
	links.add_child(settings_button)
	links.add_child(quit_button)
	links.set_meta("edges",Vector4(-1,56,64,-1))
	_build_selected()
	_build_strip()
	resized.connect(_layout)
	_layout()
	_set_mode("idle")

func _add_scrim() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.22,0.38,1.0])
	gradient.colors = PackedColorArray([Color(20/255.0,16/255.0,22/255.0,0.45),Color(20/255.0,16/255.0,22/255.0,0.0),Color(20/255.0,16/255.0,22/255.0,0.0),Color(SCRIM_DARK,0.88)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 4
	texture.height = 256
	texture.fill_from = Vector2(0,0)
	texture.fill_to = Vector2(0,1)
	var scrim := TextureRect.new()
	scrim.texture = texture
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## The selected world, bottom left: kicker, name (or its rename field), when
## it was played, and the action row.
func _build_selected() -> void:
	var block := box(true,14)
	add_child(block)
	block.set_meta("edges",Vector4(64,-1,64,214))
	kicker = label("Your worlds",Style.newsreader(500),13,Style.SECONDARY_SCENE,0.28,true)
	name_label = label("",Style.newsreader(400),58,Style.INK_PRIMARY)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	shadow(name_label,Color(10/255.0,8/255.0,10/255.0,0.22),2,6)
	rename_edit = input(50,Style.INK_PRIMARY,Color(20/255.0,16/255.0,12/255.0,0.45),Color(Style.THREAD,0.6),8,Vector2(14,4))
	rename_edit.set_meta("min",Vector2(720,0))
	rename_edit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rename_edit.hide()
	when_label = label("",Style.spectral(),17,Style.SECONDARY_SCENE)
	for node in [kicker,name_label,rename_edit,when_label]: block.add_child(node)
	var lift := margins(Vector4(0,6,0,0))
	block.add_child(lift)
	var row := box(false,28)
	row.set_meta("min",Vector2(0,46))
	lift.add_child(row)
	enter_button = primary("Enter world ↵")
	enter_button.pressed.connect(enter)
	rename_button = link("Rename",14,Style.THREAD,Style.HOVER_INK,0.24)
	rename_button.pressed.connect(start_rename)
	duplicate_button = link("Duplicate",14,Style.THREAD,Style.HOVER_INK,0.24)
	duplicate_button.pressed.connect(duplicate_selected)
	delete_button = link("Delete",14,Style.THREAD,Style.DESTRUCTIVE,0.24)
	delete_button.pressed.connect(func() -> void: _set_mode("delete"))
	keep_name_button = primary("Keep name ↵")
	keep_name_button.pressed.connect(commit_rename)
	cancel_button = link("Cancel · Esc",14,Style.THREAD,Style.HOVER_INK,0.24)
	cancel_button.pressed.connect(func() -> void: _set_mode("idle"))
	for node in [enter_button,rename_button,duplicate_button,delete_button,keep_name_button,cancel_button]: row.add_child(node)
	# Delete confirm: a small linen card in place of the row.
	delete_card = margins(Vector4(22,12,14,12))
	delete_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var backing := Backing.new()
	backing.outset = Vector4(22,12,14,12)
	backing.radius = 12.0
	backing.hem = Vector2(4,8)
	backing.alpha = 0.92
	backing.shade = Vector3(10,30,0.4)
	delete_card.add_child(backing)
	var card := box(false,22)
	delete_card.add_child(card)
	card.add_child(label("Let this world go? It can't be brought back.",Style.spectral(),18,Style.INK))
	(card.get_child(0) as Label).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	keep_button = primary("Keep it",17,Vector2(18,8))
	keep_button.pressed.connect(func() -> void: _set_mode("idle"))
	let_go_button = button("Let it go",17,Style.DESTRUCTIVE,Color(Style.DESTRUCTIVE,0.0),Color(Style.DESTRUCTIVE,0.12),Vector2(16,7),Color(Style.DESTRUCTIVE,0.55))
	let_go_button.pressed.connect(delete_selected)
	card.add_child(keep_button)
	card.add_child(let_go_button)
	row.add_child(delete_card)

## The strip of linen along the foot: every world's tile, the New world tile
## and the hint. Tiles scroll sideways when they outrun it.
func _build_strip() -> void:
	strip.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(strip)
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = BLUR_SHADER
	_blur.material = material
	_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blur.show_behind_parent = true
	strip.add_child(_blur)
	strip.add_child(_strip_cloth)
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_PASS
	strip.add_child(_clip)
	_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_clip.add_child(_row)
	new_tile = Tile.new()
	new_tile.is_new = true
	new_tile.picked.connect(func(_tile: Tile) -> void: new_world_requested.emit())
	new_tile.opened.connect(func(_tile: Tile) -> void: new_world_requested.emit())
	_row.add_child(new_tile)
	hint = label("◂ ▸ browse · ↵ enter",Style.newsreader(500),13,Style.MUTED,0.24,true)
	strip.add_child(hint)
	strip.gui_input.connect(_on_strip_input)

## Reads the library: `setup` once, then `refresh` whenever worlds change.
func setup(world_library) -> void:
	library = world_library

## Re-reads the worlds, most recent first, and selects `select_id` (or keeps
## the selection, or takes the first).
func refresh(select_id := "") -> void:
	if library == null: return
	var keep := select_id if not select_id.is_empty() else (_selected_id() if _shown_id != "~" else "")
	worlds = library.worlds()
	_textures.clear()
	selected = 0
	for i in worlds.size():
		if worlds[i].id == keep: selected = i
	_build_tiles()
	mode = "idle"
	_show()

## Fades the capture back off once the host's live world has caught up.
func reveal_live() -> void:
	_fade_veil(0.0)

func selected_world() -> Dictionary:
	return worlds[selected].duplicate() if selected < worlds.size() else {}

func select(index: int) -> void:
	if worlds.is_empty(): return
	index = clampi(index,0,worlds.size()-1)
	if index == selected and mode == "idle": return
	selected = index
	mode = "idle"
	_show()

func browse(step: int) -> void:
	select(selected+step)

func enter() -> void:
	if worlds.is_empty(): new_world_requested.emit()
	else: enter_requested.emit(selected_world())

func start_rename() -> void:
	_set_mode("rename")

## Keeps the typed name; a blank one is ignored and the old name stays.
func commit_rename() -> void:
	if mode != "rename" or worlds.is_empty(): return
	var world: Dictionary = worlds[selected]
	if library.rename(world.id,rename_edit.text): world.name = rename_edit.text.strip_edges()
	_set_mode("idle")
	_show()

## "{name} (copy)", right after its source, played just now, and selected.
func duplicate_selected() -> void:
	if worlds.is_empty(): return
	var copy: Dictionary = library.duplicate_world(worlds[selected].id,"",_now())
	if copy.is_empty(): return
	worlds.insert(selected+1,copy)
	_build_tiles()
	select(selected+1)

## Lets the selected world go; the selection moves to the next world, or the
## previous one when it was last.
func delete_selected() -> void:
	if worlds.is_empty(): return
	library.delete(worlds[selected].id)
	worlds.remove_at(selected)
	selected = maxi(0,mini(selected,worlds.size()-1))
	_build_tiles()
	mode = "idle"
	_show()

func _now() -> float:
	return now if now >= 0.0 else Time.get_unix_time_from_system()

func _selected_id() -> String:
	return str(worlds[selected].id) if selected < worlds.size() else ""

func _build_tiles() -> void:
	for tile: Tile in tiles:
		_row.remove_child(tile)
		tile.queue_free()
	tiles.clear()
	for world: Dictionary in worlds:
		var tile := Tile.new()
		tile.world = world
		tile.tint = LAND_TINTS.get(world.get("land","plain"),LAND_TINTS.plain)
		tile.texture = _capture_of(world.id)
		tile.picked.connect(func(picked: Tile) -> void: select(tiles.find(picked)))
		tile.opened.connect(func(picked: Tile) -> void:
			select(tiles.find(picked))
			enter())
		tiles.append(tile)
		_row.add_child(tile)
	_row.move_child(new_tile,-1)
	rescale(_row,px)
	_place_strip()

func _capture_of(id: String) -> Texture2D:
	if not _textures.has(id):
		var path: String = library.thumbnail_path(id)
		var image := Image.load_from_file(path) if FileAccess.file_exists(path) else null
		_textures[id] = ImageTexture.create_from_image(image) if image != null and not image.is_empty() else null
	return _textures[id]

## Shows the selected world, its mode and tiles; a new selection swaps the
## backdrop and is announced.
func _show() -> void:
	var empty := worlds.is_empty()
	kicker.text = Style.caps("Your worlds" if empty else "Your worlds · %d of %d" % [selected+1,worlds.size()])
	name_label.text = "No worlds yet" if empty else str(worlds[selected].name)
	when_label.text = "Begin a new one" if empty else Library.relative_time(float(worlds[selected].last_played_at),_now())
	for i in tiles.size():
		var tile: Tile = tiles[i]
		tile.world = worlds[i]
		if tile.selected != (i == selected): tile.select(i == selected)
		tile.queue_redraw()
	_set_mode(mode)
	_place_strip()
	var id := _selected_id()
	if id != _shown_id:
		_shown_id = id
		capture.texture = null if empty else _capture_of(id)
		_fade_veil(1.0)
		selection_changed.emit(selected_world())

func _fade_veil(alpha: float) -> void:
	if _veil_tween: _veil_tween.kill()
	if not is_inside_tree():
		veil.modulate.a = alpha
		return
	_veil_tween = create_tween()
	_veil_tween.tween_property(veil,"modulate:a",alpha,FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## idle, rename or delete: the action row, the name or its field, and the
## delete card. Only one at a time; none with no worlds.
func _set_mode(next: String) -> void:
	var empty := worlds.is_empty()
	mode = "idle" if empty else next
	name_label.visible = mode != "rename"
	rename_edit.visible = mode == "rename"
	for node: Control in [enter_button,rename_button,duplicate_button,delete_button]: node.visible = mode == "idle" and not empty
	keep_name_button.visible = mode == "rename"
	cancel_button.visible = mode == "rename"
	delete_card.visible = mode == "delete"
	if mode == "rename":
		rename_edit.text = str(worlds[selected].name)
		if rename_edit.is_inside_tree(): rename_edit.grab_focus()
		rename_edit.select_all()
		rename_edit.caret_column = rename_edit.text.length()
	elif rename_edit.has_focus(): rename_edit.release_focus()

func _input(event: InputEvent) -> void:
	if library == null or not is_visible_in_tree() or not event is InputEventKey or not event.pressed: return
	var key_event := event as InputEventKey
	var key := key_event.keycode
	var handled := true
	if key == KEY_ESCAPE and mode != "idle": _set_mode("idle")
	elif (key == KEY_ENTER or key == KEY_KP_ENTER) and not key_event.echo:
		if mode == "rename": commit_rename()
		elif mode == "delete": _set_mode("idle")
		else: enter()
	elif (key == KEY_LEFT or key == KEY_RIGHT) and mode != "rename": browse(-1 if key == KEY_LEFT else 1)
	else: handled = false
	if handled: get_viewport().set_input_as_handled()

func _on_strip_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_LEFT,MOUSE_BUTTON_WHEEL_RIGHT]:
		var step := (TILE.x+TILE_GAP)*px*(-1.0 if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_LEFT] else 1.0)
		_scroll_to(_scroll+step)
		strip.accept_event()

## Places everything from the screen's edges at the current scale.
func _layout() -> void:
	px = Linen.scale_for(size)
	rescale(self,px)
	for node: Control in get_children():
		if not node.has_meta("edges"): continue
		# Left, top, right, bottom design px from the edges; -1 leaves one free.
		var edges: Vector4 = node.get_meta("edges")
		node.anchor_left = 1.0 if edges.x < 0.0 else 0.0
		node.anchor_right = 0.0 if edges.z < 0.0 else 1.0
		node.anchor_top = 1.0 if edges.y < 0.0 else 0.0
		node.anchor_bottom = 0.0 if edges.w < 0.0 else 1.0
		node.grow_horizontal = Control.GROW_DIRECTION_BEGIN if edges.x < 0.0 else Control.GROW_DIRECTION_END
		node.grow_vertical = Control.GROW_DIRECTION_BEGIN if edges.y < 0.0 else Control.GROW_DIRECTION_END
		node.offset_left = -roundf(edges.z*px) if edges.x < 0.0 else roundf(edges.x*px)
		node.offset_right = roundf(edges.x*px) if edges.z < 0.0 else -roundf(edges.z*px)
		node.offset_top = -roundf(edges.w*px) if edges.y < 0.0 else roundf(edges.y*px)
		node.offset_bottom = roundf(edges.y*px) if edges.w < 0.0 else -roundf(edges.w*px)
	_place_strip()

## The strip: left/right 64, bottom 28, its height fitted to the tiles.
func _place_strip() -> void:
	var pad := (STRIP_PAD*px).round()
	var label_height := Style.SPECTRAL.get_height(roundi(14.0*px))
	var tile_size := Vector2(roundf(TILE.x*px),roundf((TILE.y+TILE_LABEL_GAP)*px+label_height))
	var height := roundf(pad.y+tile_size.y+pad.w)
	strip.position = Vector2(roundf(64.0*px),roundf(size.y-28.0*px-height))
	strip.size = Vector2(maxf(1.0,size.x-roundf(128.0*px)),height)
	_blur.position = Vector2.ZERO
	_blur.size = strip.size
	var blur_material := _blur.material as ShaderMaterial
	blur_material.set_shader_parameter("extent",strip.size)
	blur_material.set_shader_parameter("radius",14.0*px)
	blur_material.set_shader_parameter("blur",6.0*px)
	Backing.dress(_strip_cloth,Rect2(Vector2.ZERO,strip.size),px,14.0,Vector2(5,10),0.82,Vector3(10,30,0.35))
	var hint_size := hint.get_combined_minimum_size()
	hint.size = hint_size
	hint.position = Vector2(strip.size.x-pad.z-hint_size.x,roundf(pad.y+(tile_size.y-hint_size.y)*0.5))
	# The tiles' window: from the strip's left edge (so shadows aren't cut)
	# to the hint, less a gap.
	var avail := floorf(maxf(tile_size.x,hint.position.x-TILE_GAP*px-pad.x))
	_clip.position = Vector2.ZERO
	_clip.size = Vector2(pad.x+avail,strip.size.y)
	_row.size = _clip.size
	var pitch := roundf((TILE.x+TILE_GAP)*px)
	var all: Array = tiles+[new_tile]
	for i in all.size():
		var tile: Tile = all[i]
		tile.size = tile_size
		tile.position = Vector2(roundf(pad.x)+i*pitch,roundf(pad.y))
	# Keep the selection in view.
	var content := all.size()*pitch-roundf(TILE_GAP*px)
	var target := clampf(_scroll,0.0,maxf(0.0,content-avail))
	if not tiles.is_empty():
		var left := selected*pitch
		if left < target: target = left
		elif left+tile_size.x > target+avail: target = left+tile_size.x-avail
	_scroll_to(target)

func _scroll_to(target: float) -> void:
	var pitch := roundf((TILE.x+TILE_GAP)*px)
	var content := (tiles.size()+1)*pitch-roundf(TILE_GAP*px)
	var avail := _clip.size.x-roundf(STRIP_PAD.x*px)
	target = roundf(clampf(target,0.0,maxf(0.0,content-avail)))
	if is_equal_approx(target,_scroll) and is_equal_approx(_row.position.x,-_scroll): return
	_scroll = target
	if _scroll_tween: _scroll_tween.kill()
	if not is_inside_tree():
		_row.position.x = -_scroll
		return
	_scroll_tween = create_tween()
	_scroll_tween.tween_property(_row,"position:x",-_scroll,0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
