extends Control
## A small tool dock and a contextual miniature card; their gap belongs to the world.
const Style = preload("res://scripts/tactile_editor_style.gd")
const FAMILIES := {
	"Select":["select"],
	"Sculpt":["raise","lower","tunnel","smooth","flatten","mountain","ground","range"],
	"Paint":["meadow","grass","blades","paint","erase"],
	"Place":["explosive","tree","rock","flower","arch","bigfoot_tree","assets"],
	"Water":["pond","waterfall"],
}
const SHELF := ["explosive","tree","broadleaf","rock","flower"]
var palette: NativeBuildPalette
var editor: NativeChunkEditor
var buttons := {}
var remembered := {"Select":"select","Sculpt":"raise","Paint":"meadow","Place":"tree","Water":"pond"}
var family := "Sculpt"
var item := "tree"
var context := VBoxContainer.new()
var title := Label.new()
var hint := Label.new()
var choices := OptionButton.new()
var trail := CheckButton.new()
var dig := Button.new()
var dock := PanelContainer.new()
var card := PanelContainer.new()
var portrait := TextureRect.new()
var shelf := HBoxContainer.new()
var miniatures := {}
var quick := VBoxContainer.new()
var tunnel_actions := VBoxContainer.new()
var quick_row := {}
var _shown_id := ""
var _card_tween: Tween
var _undo := Button.new()
var _redo := Button.new()
var _eyebrow := Label.new()
var held := Button.new()
var _card_open := false

func setup(owner_palette: NativeBuildPalette) -> void:
	palette = owner_palette
	editor = palette.editor
	name = "ToolRail"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_theme_stylebox_override("panel",Style.panel(22,7))
	add_child(dock)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation",3)
	dock.add_child(tools)
	for key: String in FAMILIES:
		var button := Button.new()
		button.text = key
		button.icon = Style.icon(key)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.text = ""
		button.tooltip_text = key
		button.add_theme_font_size_override("font_size",12)
		button.add_theme_constant_override("h_separation",4)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(54,42)
		button.tooltip_text = "Select · Esc" if key == "Select" else key
		Style.button(button,true)
		button.pressed.connect(activate.bind(key))
		_bind_feel(button)
		tools.add_child(button)
		buttons[key] = button
	held.custom_minimum_size = Vector2(130,42)
	held.expand_icon = true
	held.add_theme_constant_override("icon_max_width",32)
	held.add_theme_font_size_override("font_size",14)
	held.toggle_mode = true
	held.tooltip_text = "Open the current tool’s controls"
	Style.button(held)
	held.pressed.connect(func() -> void:
		_card_open = not _card_open
		card.visible = _card_open
		palette._details.hide()
		fit())
	tools.add_child(held)
	var rule := VSeparator.new()
	rule.modulate.a = 0.2
	tools.add_child(rule)
	var browse := Button.new()
	browse.name = "Browse"
	browse.text = ""
	browse.icon = Style.icon("Browse")
	browse.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	browse.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	browse.custom_minimum_size = Vector2(42,42)
	browse.add_theme_font_size_override("font_size",12)
	browse.tooltip_text = "All tools & miniatures · "+("⌘K" if OS.get_name() == "macOS" else "Ctrl K")
	Style.button(browse)
	browse.pressed.connect(palette.open_palette)
	_bind_feel(browse)
	tools.add_child(browse)
	for entry: Array in [[_undo,"undo",editor.undo],[_redo,"redo",editor.redo]]:
		var button: Button = entry[0]
		button.icon = Style.icon(entry[1])
		button.tooltip_text = "Undo · ⌘Z / Ctrl Z" if entry[1] == "undo" else "Redo · ⇧⌘Z / Ctrl Shift Z"
		button.custom_minimum_size = Vector2(36,40)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		Style.button(button)
		button.pressed.connect(entry[2])
		tools.add_child(button)
	card.name = "ToolCard"
	card.add_theme_stylebox_override("panel",Style.panel())
	card.custom_minimum_size.x = 236
	add_child(card)
	context.add_theme_constant_override("separation",10)
	card.add_child(context)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",8)
	context.add_child(header)
	portrait.custom_minimum_size = Vector2(64,72)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(portrait)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(heading)
	_eyebrow.add_theme_font_size_override("font_size",10)
	_eyebrow.add_theme_color_override("font_color",Style.HONEY)
	heading.add_child(_eyebrow)
	title.add_theme_font_size_override("font_size",20)
	title.custom_minimum_size.x = 124
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_child(title)
	shelf.add_theme_constant_override("separation",4)
	context.add_child(shelf)
	for id: String in SHELF:
		var tile := Button.new()
		tile.name = id
		tile.custom_minimum_size = Vector2(48,50)
		tile.expand_icon = true
		tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.toggle_mode = true
		tile.tooltip_text = palette._title(id)
		Style.button(tile)
		tile.pressed.connect(palette._choose.bind(id))
		_bind_feel(tile)
		shelf.add_child(tile)
		miniatures[id] = tile
	choices.custom_minimum_size.x = 208
	choices.add_theme_font_size_override("font_size",13)
	Style.button(choices)
	choices.item_selected.connect(func(index: int) -> void: palette._choose(FAMILIES[family][index]))
	context.add_child(choices)
	context.add_child(quick)
	context.add_child(tunnel_actions)
	for spec in [["Plant charge inside","plant_tunnel_charge"],["Seal last tunnel","seal_tunnel"],["Reopen last tunnel","reopen_tunnel"]]:
		var button := Button.new()
		button.text = spec[0]
		button.name = spec[1]
		Style.button(button)
		button.pressed.connect(Callable(editor,spec[1]))
		tunnel_actions.add_child(button)
	editor.play_geometry_changed.connect(_sync_tunnels)
	trail.text = "Paint a trail"
	trail.add_theme_font_size_override("font_size",13)
	trail.tooltip_text = "Drag to place a trail. One stroke, one undo."
	trail.toggled.connect(func(enabled: bool) -> void:
		editor.finish_stroke()
		editor.placement_trail = enabled
		sync())
	context.add_child(trail)
	dig.text = "Dig a hollow"
	Style.button(dig)
	dig.pressed.connect(func() -> void: palette._choose("lower"))
	context.add_child(dig)
	var actions := HBoxContainer.new()
	actions.name = "Actions"
	context.add_child(actions)
	var choose := Button.new()
	choose.name = "ChooseItem"
	choose.text = "More pieces"
	choose.custom_minimum_size.y = 34
	choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Style.button(choose)
	choose.pressed.connect(func() -> void:
		palette.open_palette()
		if family in ["Place","Paint"]: palette._browse("Flora" if family == "Paint" or item in palette.FOLIAGE else "All")
		elif family == "Water": palette._browse("Water"))
	actions.add_child(choose)
	var tune := Button.new()
	tune.name = "Settings"
	tune.text = "Adjust"
	tune.icon = palette._line_icon("tune")
	tune.custom_minimum_size.y = 34
	Style.button(tune)
	tune.pressed.connect(func() -> void:
		_card_open = false
		card.hide()
		held.set_pressed_no_signal(false)
		palette._details.show())
	actions.add_child(tune)
	hint.custom_minimum_size.x = 208
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size",12)
	hint.add_theme_color_override("font_color",Style.MUTED)
	context.add_child(hint)
	editor.setting_changed.connect(_sync_setting)
	card.minimum_size_changed.connect(fit.call_deferred)
	sync()

func _bind_feel(button: Button) -> void:
	button.mouse_entered.connect(func() -> void: palette._scale_tile(button,1.035))
	button.mouse_exited.connect(func() -> void: palette._scale_tile(button,1.0))
	button.button_down.connect(func() -> void: palette._scale_tile(button,0.96))
	button.button_up.connect(func() -> void: palette._scale_tile(button,1.035 if button.is_hovered() else 1.0))

func activate(key: String) -> void:
	if key == "Place":
		if item == "bigfoot": palette._take_special(item)
		else: palette._choose(item)
	else: palette._choose(remembered[key])

func sync() -> void:
	var id := editor.catalog_asset if editor.mode == "assets" else editor.mode
	if palette._placing == "bigfoot": id = "bigfoot"
	for key: String in FAMILIES:
		if editor.mode in FAMILIES[key]: family = key
	if id == "bigfoot": family = "Place"
	remembered[family] = editor.mode
	if family == "Place": item = id
	for key: String in buttons: buttons[key].set_pressed_no_signal(key == family)
	title.text = palette._title(id)
	_eyebrow.text = "IN YOUR HAND" if family == "Place" else "SHAPE YOUR WORLD"
	held.text = title.text+"  ···"
	held.icon = palette._thumbs.get(id)
	held.visible = family != "Select"
	card.visible = _card_open and family != "Select"
	held.set_pressed_no_signal(card.visible)
	portrait.texture = palette._thumbs.get(id)
	portrait.visible = portrait.texture != null
	shelf.visible = family == "Place"
	for piece: String in miniatures:
		miniatures[piece].icon = palette._thumbs.get(piece)
		miniatures[piece].set_pressed_no_signal(piece == id)
	choices.clear()
	choices.visible = family in ["Sculpt","Paint","Water"]
	for tool: String in FAMILIES[family]: choices.add_item(palette._title(tool))
	var index: int = FAMILIES[family].find(editor.mode)
	if index >= 0: choices.select(index)
	trail.visible = editor.trail_available() and id != "bigfoot"
	trail.set_pressed_no_signal(editor.placement_trail)
	dig.visible = id == "pond"
	tunnel_actions.visible = id == "tunnel"
	_sync_tunnels()
	if id == "bigfoot": hint.text = "Find him a little place to call home."
	elif editor.trail_available(): hint.text = "Drag to plant a trail · Esc to put away" if editor.placement_trail else "Click to place · Esc to put away"
	elif id == "pond": hint.text = "Hover over a hollow to see the shoreline."
	elif id in ["ground","range"]: hint.text = "Open Adjust to shape the landscape."
	elif id == "tunnel": hint.text = "Click into a steep slope · Plant, seal, then X"
	elif family in ["Sculpt","Paint"]: hint.text = "Drag to brush · Right drag to orbit"
	else: hint.text = "Click to place · Esc to put away"
	context.get_node("Actions/Settings").visible = editor.mode != "select" and id != "bigfoot"
	context.get_node("Actions/ChooseItem").visible = family in ["Place","Paint","Water"]
	if _shown_id != id:
		_shown_id = id
		_card_open = false
		card.hide()
		held.set_pressed_no_signal(false)
		_build_quick(id)
		if _card_tween: _card_tween.kill()
		card.modulate.a = 0.45
		_card_tween = create_tween()
		_card_tween.tween_property(card,"modulate:a",1.0,0.16)
	card.size = Vector2(236,0)
	fit.call_deferred()

func _sync_tunnels() -> void:
	if tunnel_actions.get_child_count()==0: return
	var available := not editor.data.tunnels.is_empty()
	var sealed: bool = available and editor.data.tunnels.back().sealed
	tunnel_actions.get_node("plant_tunnel_charge").disabled = not available or sealed or editor.data.explosive_count()>=editor.data.MAX_EXPLOSIVES
	tunnel_actions.get_node("seal_tunnel").disabled = not available or sealed
	tunnel_actions.get_node("reopen_tunnel").disabled = not available or not sealed

func _build_quick(id: String) -> void:
	for child in quick.get_children():
		quick.remove_child(child)
		child.queue_free()
	quick_row.clear()
	if id == "bigfoot" or family == "Select": return
	var property := "object_scale" if family == "Place" else "radius"
	if id == "explosive": property = "blast_radius"
	if id == "tunnel": property = "tunnel_width"
	if id == "mountain": property = "mountain_radius"
	if id == "pond": property = "pond_level"
	if not editor.settings_for(editor.mode).any(func(spec: Dictionary) -> bool: return spec.property == property): return
	quick_row = NativeSettingRow.build(editor,property,true)
	quick_row.label.add_theme_font_size_override("font_size",13)
	quick_row.control.focus_mode = Control.FOCUS_ALL
	Style.slider(quick_row.control)
	quick.add_child(quick_row.box)

func _sync_setting(property: String, value: float) -> void:
	if quick_row.is_empty(): return
	var spec := editor.setting_spec(property)
	if spec.is_empty() or quick_row.title != spec.title: return
	quick_row.control.set_value_no_signal(value)
	NativeSettingRow.show_value(quick_row,value)

func close_controls() -> void:
	_card_open = false
	card.hide()
	held.set_pressed_no_signal(false)

func context_rect() -> Rect2:
	return card.get_global_rect()

func contains_pointer(point: Vector2) -> bool:
	return is_visible_in_tree() and (dock.get_global_rect().has_point(point) or (card.visible and card.get_global_rect().has_point(point)))

func visible_portraits() -> Array:
	if not is_visible_in_tree() or not held.visible: return []
	return [_shown_id]

func _process(_delta: float) -> void:
	_undo.disabled = editor.data._undo.is_empty()
	_redo.disabled = editor.data._redo.is_empty()

func fit() -> void:
	var screen := get_viewport_rect().size
	dock.size = dock.get_combined_minimum_size()
	size = dock.size
	# Godot's viewport is in points on Retina. Fit the kit as one unit so
	# a small physical window never turns the tools into the main subject.
	var factor := minf(1.0,minf(screen.x/1080.0,screen.y/720.0))
	scale = Vector2.ONE*factor
	position = Vector2((screen.x-size.x*factor)*0.5,screen.y-size.y*factor-16)
	card.size = Vector2(236,card.get_combined_minimum_size().y)
	var card_left := clampf(held.get_global_rect().position.x,16.0,screen.x-card.size.x*factor-16.0)
	card.position = (Vector2(card_left,screen.y-(card.size.y+size.y)*factor-28)-position)/factor
	palette._fit_details.call_deferred()
