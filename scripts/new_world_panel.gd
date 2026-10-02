extends Control
## New world (docs/design/worlds/README.md "2. New world"): name a world, pick
## its land and its seed on a linen panel docked right, while the host
## previews the chosen land live behind it (`land_changed`). The caption at
## the bottom left names the land being previewed. Enter begins, Esc goes
## back, Up and Down pick the land. Typesetting is scripts/world_title.gd's.
##
## A blank name is passed on blank: `begin_requested` carries "" and
## scripts/world_library.gd `create` names the world after its land.

signal land_changed(land: String, seed_text: String)
signal begin_requested(world_name: String, land: String, seed_text: String)
signal back_requested

const Title = preload("res://scripts/world_title.gd")
const Library = preload("res://scripts/world_library.gd")
const Style = preload("res://scripts/worlds_style.gd")
const Linen = preload("res://scripts/hud_linen.gd")
## A land's thumbnail, when one has been drawn; otherwise a muted swatch.
const LAND_ART := "res://assets/ui/lands/%s.png"

var land := "plain"
var seed_text := ""
var rng := RandomNumberGenerator.new()
var px := 1.0
var name_edit: LineEdit
var rows: Array = []
var seed_label: Label
var roll_button: Button
var back_button: Button
var begin_button: Button
var caption_name: Label
var caption_description: Label

## A land to pick: its thumbnail and name; the picked one ringed in thread.
class LandRow extends Control:
	signal picked(row: LandRow)
	var land := {}
	var texture: Texture2D
	var tint := Color("66704f")
	var selected := false
	var px := 1.0
	var _font := Style.newsreader(400)

	func _init() -> void:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		set_meta("min",Vector2(0,63))

	func set_px(s: float) -> void:
		px = s
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			picked.emit(self)

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO,size)
		var ring := maxf(1.0,1.5*px)
		if selected:
			Linen.fill_round(self,rect,9.0*px,Style.WELL)
			draw_polyline(Linen.round_points(rect.grow(-ring*0.5),9.0*px-ring*0.5),Style.THREAD,ring,true)
		var inset := roundf(7.5*px)
		var thumb := Rect2(Vector2(inset,roundf((size.y-48.0*px)*0.5)),(Vector2(76,48)*px).round())
		var points := Linen.round_points(thumb,5.0*px)
		points.remove_at(points.size()-1)
		if texture != null:
			var uvs := PackedVector2Array()
			for point in points: uvs.append((point-thumb.position)/thumb.size)
			draw_colored_polygon(points,Color.WHITE,uvs,texture)
		else:
			# A swatch: pale sky over the land's own colour.
			var colours := PackedColorArray()
			var sky := tint.lightened(0.45).lerp(Color("b9b6ae"),0.4)
			for point in points:
				var t := clampf(((point.y-thumb.position.y)/thumb.size.y-0.3)/0.4,0.0,1.0)
				colours.append(sky.lerp(tint,t))
			draw_polygon(points,colours)
		var font_size := roundi(19.0*px)
		var baseline := roundf(size.y*0.5+(_font.get_ascent(font_size)-_font.get_descent(font_size))*0.5)
		draw_string(_font,Vector2(thumb.end.x+roundf(14.0*px),baseline),str(land.name),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Style.INK)

## Built whole on creation, so the host can set it up before it is in the tree.
func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_scrim()
	# The caption, bottom left: the land being previewed.
	var caption := Title.box(true,8)
	caption.set_meta("min",Vector2(560,0))
	add_child(caption)
	caption.set_meta("edges",Vector4(64,-1,-1,56))
	caption.add_child(Title.label("Preview",Style.newsreader(500),13,Style.SECONDARY_SCENE,0.28,true))
	caption_name = Title.label("",Style.newsreader(400),52,Style.INK_PRIMARY)
	Title.shadow(caption_name,Color(10/255.0,8/255.0,10/255.0,0.22),2,6)
	caption_description = Title.label("",Style.spectral(),18,Style.THREAD)
	caption_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Title.shadow(caption_description,Color(10/255.0,8/255.0,10/255.0,0.3),1,3)
	caption.add_child(caption_name)
	caption.add_child(caption_description)
	_build_panel()
	resized.connect(_layout)
	_layout()
	hide()

func _add_scrim() -> void:
	var dark := Color(16/255.0,12/255.0,16/255.0)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.3,0.5,1.0])
	gradient.colors = PackedColorArray([Color(dark,0.55),Color(dark,0.0),Color(dark,0.0),Color(dark,0.5)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 4
	var scrim := TextureRect.new()
	scrim.texture = texture
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## The right-docked panel: right, top and bottom 24, 440 wide.
func _build_panel() -> void:
	var panel := Title.margins(Vector4(30,30,30,24))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("dock",true)
	add_child(panel)
	var backing := Title.Backing.new()
	backing.outset = Vector4(30,30,30,24)
	backing.radius = 16.0
	backing.hem = Vector2(6,11)
	backing.alpha = 0.9
	# The spec's 0 18px 50px, held inside the cloth's shadow margin.
	backing.shade = Vector3(12,36,0.45)
	panel.add_child(backing)
	var column := Title.box(true,22)
	panel.add_child(column)
	column.add_child(Title.label("A new world",Style.newsreader(400),30,Style.INK))
	name_edit = Title.input(22,Style.INK,Style.INPUT_FILL,Style.INPUT_RULE,6,Vector2(12,8))
	column.add_child(_field("Name",name_edit))
	var list := Title.box(true,4)
	for entry: Dictionary in Library.LANDS:
		var row := LandRow.new()
		row.land = entry
		row.tint = Title.LAND_TINTS.get(entry.id,Color("66704f"))
		var art := LAND_ART % entry.id
		if ResourceLoader.exists(art): row.texture = load(art)
		row.picked.connect(func(picked: LandRow) -> void: pick(str(picked.land.id)))
		rows.append(row)
		list.add_child(row)
	column.add_child(_field("Land",list))
	var seed_row := Title.box(false,10)
	seed_label = Title.label("",Style.spectral_italic(),19,Style.INK)
	seed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var well := StyleBoxFlat.new()
	well.bg_color = Style.INPUT_FILL
	well.corner_radius_top_left = 6
	well.corner_radius_top_right = 6
	well.anti_aliasing = true
	well.content_margin_left = 12
	well.content_margin_right = 12
	well.content_margin_top = 8
	well.content_margin_bottom = 8
	seed_label.set_meta("boxes",{"normal":well})
	Title.dashed_rule(seed_label,Style.INPUT_RULE)
	roll_button = Title.button(Style.caps("Roll"),13,Style.SECONDARY_LINEN,Color(0,0,0,0),Color(20/255.0,15/255.0,10/255.0,0.2),Vector2(12,9))
	roll_button.set_meta("type",[13,0.22,true])
	for state in ["font_hover_color","font_pressed_color","font_hover_pressed_color"]: roll_button.add_theme_color_override(state,Style.HOVER_INK)
	roll_button.add_theme_color_override("font_focus_color",Style.SECONDARY_LINEN)
	Title.dashed_box(roll_button,Color(Style.THREAD,0.4),8)
	roll_button.pressed.connect(roll)
	seed_row.add_child(seed_label)
	seed_row.add_child(roll_button)
	column.add_child(_field("Seed",seed_row))
	# The footer, pinned to the bottom under a dashed rule.
	var spring := Control.new()
	spring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spring.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spring)
	var footer := Title.margins(Vector4(0,18,0,0))
	Title.dashed_rule(footer,Color(Style.THREAD,0.3),true)
	column.add_child(footer)
	var buttons := Title.box(false,0)
	footer.add_child(buttons)
	back_button = Title.link("Back",14,Style.MUTED,Style.THREAD,0.24)
	back_button.pressed.connect(func() -> void: back_requested.emit())
	begin_button = Title.primary("Begin ↵",17,Vector2(24,10))
	begin_button.pressed.connect(begin)
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(back_button)
	buttons.add_child(gap)
	buttons.add_child(begin_button)

## A small-caps heading over `body`, 8 apart.
func _field(heading: String, body: Control) -> Control:
	var field := Title.box(true,8)
	field.add_child(Title.label(heading,Style.newsreader(500),13,Style.MUTED,0.24,true))
	field.add_child(body)
	return field

## Opens on the quiet plain with a blank name and a fresh seed, rolled from
## `rng_seed` (random below 0).
func open(rng_seed := -1) -> void:
	if rng_seed >= 0: rng.seed = rng_seed
	else: rng.randomize()
	seed_text = Library.roll_seed(rng)
	name_edit.text = ""
	show()
	pick(Library.LANDS[0].id)
	if name_edit.is_inside_tree(): name_edit.grab_focus()

func close() -> void:
	if name_edit.has_focus(): name_edit.release_focus()
	hide()

## Picks a land; the host previews it.
func pick(land_id: String) -> void:
	land = land_id
	var land_name := Library.land_name(land)
	for row: LandRow in rows:
		row.selected = row.land.id == land
		row.queue_redraw()
	name_edit.placeholder_text = "%s — or leave it" % land_name
	caption_name.text = land_name
	for entry: Dictionary in Library.LANDS:
		if entry.id == land: caption_description.text = entry.description
	seed_label.text = seed_text
	land_changed.emit(land,seed_text)

## A new seed for the same land.
func roll() -> void:
	seed_text = Library.roll_seed(rng)
	seed_label.text = seed_text
	land_changed.emit(land,seed_text)

## The trimmed name (blank stays blank), the land and the seed.
func begin() -> void:
	begin_requested.emit(name_edit.text.strip_edges(),land,seed_text)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed: return
	var key_event := event as InputEventKey
	var key := key_event.keycode
	var handled := true
	if (key == KEY_ENTER or key == KEY_KP_ENTER) and not key_event.echo: begin()
	elif key == KEY_ESCAPE: back_requested.emit()
	elif key == KEY_UP or key == KEY_DOWN:
		var index := 0
		for i in Library.LANDS.size():
			if Library.LANDS[i].id == land: index = i
		pick(Library.LANDS[clampi(index+(1 if key == KEY_DOWN else -1),0,Library.LANDS.size()-1)].id)
	else: handled = false
	if handled: get_viewport().set_input_as_handled()

func _layout() -> void:
	px = Linen.scale_for(size)
	Title.rescale(self,px)
	for node: Control in get_children():
		if node.has_meta("dock"):
			node.anchor_left = 1.0
			node.anchor_right = 1.0
			node.anchor_top = 0.0
			node.anchor_bottom = 1.0
			node.offset_left = -roundf(464.0*px)
			node.offset_right = -roundf(24.0*px)
			node.offset_top = roundf(24.0*px)
			node.offset_bottom = -roundf(24.0*px)
		elif node.has_meta("edges"):
			# Left and bottom, growing up from the foot.
			var edges: Vector4 = node.get_meta("edges")
			node.anchor_left = 0.0
			node.anchor_right = 0.0
			node.anchor_top = 1.0
			node.anchor_bottom = 1.0
			node.grow_vertical = Control.GROW_DIRECTION_BEGIN
			node.offset_left = roundf(edges.x*px)
			node.offset_right = roundf(edges.x*px)
			node.offset_top = -roundf(edges.w*px)
			node.offset_bottom = -roundf(edges.w*px)
