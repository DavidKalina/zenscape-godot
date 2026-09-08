extends PanelContainer
const Presets = preload("res://scripts/native_landscape_presets.gd")
const Shape = preload("res://scripts/native_formation_shape.gd")
var library := preload("res://scripts/landscape_favorites.gd").new()
var tabs := TabContainer.new()
var favorite_name := LineEdit.new()
var favorite_list := VBoxContainer.new()
var favorite_status := Label.new()
var favorite_save: Button
var favorite_buttons: Array[Button] = []
var _saving := false
var scene: Node3D
var cards := {}
var biome_choice := OptionButton.new()
var water_choice := OptionButton.new()
var another_button: Button
var status := Label.new()
var undo_button: Button
var redo_button: Button
var scroll := ScrollContainer.new()
var grid := GridContainer.new()

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	name = "LandscapePresets"
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Theme.new()
	theme.default_font = load("res://assets/fonts/Nunito.ttf")
	theme.default_font_size = 13
	var style := StyleBoxFlat.new()
	style.bg_color = Color("252931")
	style.border_color = Color("59636c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	add_theme_stylebox_override("panel",style)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",10)
	add_child(body)
	var row := HBoxContainer.new()
	body.add_child(row)
	var title := _label(row,"Landscapes")
	title.add_theme_font_size_override("font_size",20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(row,"×",hide)
	_label(body,"A beautiful starting point. Make it your own.")
	var help := _label(body,"Choose a complete world: terrain, planting, water, lighting and atmosphere. Undo restores your previous world.")
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.modulate = Color("bdc9c6")
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(tabs)
	scroll.name = "Create"
	tabs.add_child(scroll)
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",10)
	scroll.add_child(grid)
	for id: String in Presets.PRESETS:
		var p: Dictionary = Presets.PRESETS[id]
		var card := Button.new()
		card.name = id
		card.toggle_mode = true
		card.clip_contents = true
		card.custom_minimum_size = Vector2(174,181)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.tooltip_text = p.description+"\n"+p.family.capitalize()+" · "+Shape.BIOMES[p.biome].title
		for state in ["normal","hover","pressed","focus"]:
			var tile := StyleBoxFlat.new()
			tile.bg_color = Color("333b43") if state == "normal" else Color("46575a")
			tile.border_color = Color("bdc5a0") if state == "focus" else Color("5d706e")
			tile.set_border_width_all(1)
			tile.set_corner_radius_all(9)
			card.add_theme_stylebox_override(state,tile)
		var image := TextureRect.new()
		image.position = Vector2(5,5)
		image.size = Vector2(164,103)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var path := "res://assets/landscapes/"+id+".png"
		if ResourceLoader.exists(path): image.texture = load(path)
		card.add_child(image)
		var name_label := _label(card,p.title)
		name_label.position = Vector2(9,111)
		name_label.add_theme_font_size_override("font_size",14)
		var caption := _label(card,p.family.capitalize()+" · "+Shape.BIOMES[p.biome].title)
		caption.position = Vector2(9,133)
		caption.size = Vector2(156,42)
		caption.add_theme_font_size_override("font_size",11)
		caption.modulate = Color("bdc9c6")
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.resized.connect(func() -> void:
			image.size.x = card.size.x-10
			caption.size.x = card.size.x-18)
		card.pressed.connect(func() -> void: await scene._chunk_editor.form_landscape(id))
		grid.add_child(card)
		cards[id] = card
	var create_options := VBoxContainer.new()
	create_options.add_theme_constant_override("separation",8)
	body.add_child(create_options)
	var note := _label(create_options,"Each preset includes its pictured mood. Biome changes and variations keep your custom look.")
	note.add_theme_font_size_override("font_size",11)
	note.modulate = Color("bdc9c6")
	create_options.add_child(status)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var biome_row := HBoxContainer.new()
	create_options.add_child(biome_row)
	_label(biome_row,"Biome").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id: String in Shape.BIOMES: biome_choice.add_item(Shape.BIOMES[id].title)
	biome_choice.item_selected.connect(func(index: int) -> void: await scene._chunk_editor.change_landscape_biome(Shape.BIOMES.keys()[index]))
	biome_row.add_child(biome_choice)
	var water_row := HBoxContainer.new()
	create_options.add_child(water_row)
	_label(water_row,"Water").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	water_choice.add_item("Connected flow")
	water_choice.add_item("Quiet pools")
	water_choice.tooltip_text = "Reforms this landscape with the chosen water treatment. Undo restores your edits."
	water_choice.item_selected.connect(func(index: int) -> void: await scene._chunk_editor.change_landscape_water("connected" if index == 0 else "quiet"))
	water_row.add_child(water_choice)
	another_button = _button(create_options,"Another like this",func() -> void: await scene._chunk_editor.another_landscape())
	another_button.tooltip_text = "A new composition with this family, biome, water treatment and palette. Undo restores your previous landscape."
	var buttons := HBoxContainer.new()
	create_options.add_child(buttons)
	undo_button = _button(buttons,"Undo terrain",scene._chunk_editor.undo)
	redo_button = _button(buttons,"Redo",scene._chunk_editor.redo)
	_button(buttons,"Swap palette…",func() -> void:
		scene.edit_scene_look()
		scene._look_editor.tabs.current_tab = 1)
	_build_favorites()
	tabs.tab_changed.connect(func(index: int) -> void:
		create_options.visible = index == 0
		help.visible = index == 0
		if index == 1: refresh_favorites())
	get_viewport().size_changed.connect(_layout)
	_layout()
	sync()

func _label(parent: Node,text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node,text: String,action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 32
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _layout() -> void:
	var area := get_viewport_rect().size
	var factor := clampf((area.y-80.0)/800.0,0.4,1.0)
	scale = Vector2.ONE*factor
	size = Vector2(minf(420,(area.x-24)/factor),minf(820,(area.y-80)/factor))
	position = Vector2(area.x-size.x*factor-12,58)

func sync() -> void:
	var editor: Node = scene._chunk_editor
	favorite_save.disabled = editor.forming or _saving or favorite_name.text.strip_edges().is_empty()
	for button in favorite_buttons: button.disabled = editor.forming or _saving
	var settings: Dictionary = editor.data._recipe_settings
	var family: String = settings.get("family","")
	for id in cards:
		cards[id].disabled = editor.forming
		cards[id].set_pressed_no_signal(family == id)
	water_choice.disabled = editor.forming or family.is_empty()
	another_button.disabled = editor.forming or family.is_empty()
	water_choice.select(1 if settings.get("water","") == "quiet" else 0)
	biome_choice.disabled = editor.forming or family.is_empty()
	if not family.is_empty(): biome_choice.select(Shape.BIOMES.keys().find(settings.biome))
	status.text = "Forming your landscape…" if editor.forming else (family.capitalize()+" · "+Shape.BIOMES[settings.biome].title if not family.is_empty() else "Choose a landscape to get started")
	undo_button.disabled = editor.forming or editor.data._undo.is_empty()
	redo_button.disabled = editor.forming or editor.data._redo.is_empty()

func _process(_delta: float) -> void:
	if visible: sync()

func _build_favorites() -> void:
	var page := VBoxContainer.new()
	page.name = "Favorites"
	page.add_theme_constant_override("separation",10)
	tabs.add_child(page)
	var caption := _label(page,"Keep this landscape, including your edits and its look.")
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	favorite_name.placeholder_text = "Name this discovery…"
	favorite_name.max_length = 80
	page.add_child(favorite_name)
	favorite_save = _button(page,"Save to Favorites",save_favorite)
	favorite_name.text_submitted.connect(func(_text: String) -> void: await save_favorite())
	favorite_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(favorite_status)
	var browsing := ScrollContainer.new()
	browsing.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	browsing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(browsing)
	favorite_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	favorite_list.add_theme_constant_override("separation",14)
	browsing.add_child(favorite_list)
	var history := HBoxContainer.new()
	page.add_child(history)
	favorite_buttons.append(_button(history,"Undo restore",scene._chunk_editor.undo))
	favorite_buttons.append(_button(history,"Redo",scene._chunk_editor.redo))
	refresh_favorites()

func refresh_favorites() -> void:
	for child in favorite_list.get_children(): child.free()
	# Keep the two permanent history buttons, discard old card references.
	favorite_buttons.resize(2)
	var entries: Array = library.entries()
	if entries.is_empty():
		var empty := _label(favorite_list,"Your discoveries will appear here.\nSave a landscape you love, then try another.")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for entry: Dictionary in entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",10)
		favorite_list.add_child(row)
		var picture := TextureRect.new()
		picture.texture = library.preview(entry.id)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.custom_minimum_size = Vector2(132,100)
		row.add_child(picture)
		var detail := VBoxContainer.new()
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(detail)
		var title := _label(detail,entry.title)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var description := _label(detail,entry.family.capitalize()+" · "+entry.biome.capitalize())
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_font_size_override("font_size",11)
		var actions := HBoxContainer.new()
		detail.add_child(actions)
		favorite_buttons.append(_button(actions,"Restore",func() -> void:
			var ok: bool = await scene._chunk_editor.restore_landscape_favorite(library,entry.id)
			favorite_status.text = "Restored · "+entry.title if ok else "Could not restore this favorite. Your landscape is unchanged."))
		favorite_buttons.append(_button(actions,"Remove",func() -> void:
			if library.remove(entry.id):
				favorite_status.text = "Removed · "+entry.title
				refresh_favorites.call_deferred()))

func save_favorite() -> void:
	if _saving or scene._chunk_editor.forming or favorite_name.text.strip_edges().is_empty(): return
	scene._chunk_editor.finish_stroke()
	_saving = true
	var editor: Node = scene._chunk_editor
	var paused: bool = scene._paused
	scene._paused = true
	editor.forming = true
	var hidden: Array[Node] = []
	for control in [self,scene._ui]:
		if control.visible: hidden.append(control); control.hide()
	if scene.has_method("save_current"):
		for control in [scene._toolbar,scene._notice]:
			if control.visible: hidden.append(control); control.hide()
	await get_tree().process_frame
	var preview: Image = null
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		preview = get_viewport().get_texture().get_image()
	for control in hidden: control.show()
	scene._paused = paused
	editor.forming = false
	var id: String = library.save(scene,favorite_name.text,preview)
	favorite_status.text = "Saved · "+favorite_name.text.strip_edges() if not id.is_empty() else "Could not save this favorite. Your landscape is still here."
	_saving = false
	scene._sync_authoring_chrome()
	refresh_favorites()
	sync()
