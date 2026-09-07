class_name NativeBuildPalette
extends Control
## The builder's palette: a bottom bar of large tiles, one row per tool group.
## Placeable tiles carry a thumbnail rendered from the real mesh and material,
## and can be dragged into the world, where a ghost follows the ground until
## the drop commits through the editor's own placement path.
const TILE := 72.0
const ICON := 96
const BAR_HEIGHT := 152.0
const DRAG_SLOP := 6.0
const HOVER_SCALE := 1.08
const PRESS_SCALE := 0.94
const TWEEN_TIME := 0.09
const LANDMARKS := ["tree","rock","flower","arch","bigfoot_tree"]
## Simple drawn glyphs stand in for the tools that have no object to render.
const GLYPHS := {
	"raise":"up","lower":"down","smooth":"wave","flatten":"bar",
	"ground":"bar","range":"peak","mountain":"peak",
	"grass":"tuft","blades":"tuft","meadow":"tuft","paint":"disc","erase":"ring",
	"pond":"disc","waterfall":"down","assets":"ring",
}

## Reports every finished drag, so a shell can chime or count placements.
signal drag_finished(placed: bool)

var editor: NativeChunkEditor
var _bar := PanelContainer.new()
var _tabs := HBoxContainer.new()
var _deck := VBoxContainer.new()
var _strip := VBoxContainer.new()
var _grid := GridContainer.new()
var _actions := HFlowContainer.new()
var _hint := Label.new()
var _rows := {}
var _tabs_by_name := {}
var _tiles := {}
var _strip_rows := {}
var _thumbs := {}
var _viewports: Array[SubViewport] = []
var _tile_group := ButtonGroup.new()
var _tab_group := ButtonGroup.new()
var _category := ""
var _cursor := TextureRect.new()
var _ghost: Node3D
var _ghost_ground := 0.0
var _drag_id := ""
var _pressed := false
var _dragging := false
var _press_at := Vector2.ZERO
var _bob := 0.0

## Take an editor that has already been set up and build the palette for it.
func attach(target: NativeChunkEditor) -> void:
	editor = target
	editor.tool_changed.connect(_on_tool_changed)
	editor.setting_changed.connect(_on_setting_changed)
	editor.status_changed.connect(_on_status_changed)
	editor.active_changed.connect(_on_active_changed)
	_build()
	visible = editor.active

## The tile that stands for a tool, or for a catalog piece under its own name.
## The catalog tool answers with the tile of the piece currently in hand.
func tile_for(id: String) -> Button:
	if id == "assets":
		return _tiles.get(editor.catalog_asset)
	return _tiles.get(id)

## The one-shot action button the strip shows for the tool in hand, by the node
## name the editor's action table gives it, or null when this tool has none.
func action_for(id: String) -> Button:
	return _actions.get_node_or_null(NodePath(id))

## Every id the palette shows a tile for, in the order they are laid out.
func tile_ids() -> Array:
	return _tiles.keys()

## True while a tile is being dragged towards the world.
func dragging() -> bool:
	return _dragging

## The translucent preview following the ground, or null when nothing is dragged.
func ghost() -> Node3D:
	return _ghost

# --- layout -----------------------------------------------------------------

func _build() -> void:
	name = "BuildPalette"
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(0,BAR_HEIGHT)
	# Pinned across the bottom of the viewport, whatever the window becomes.
	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_right = 0.0
	offset_top = -BAR_HEIGHT
	offset_bottom = 0.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055,0.075,0.085,0.92)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_bar.add_theme_stylebox_override("panel",style)
	_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bar)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",6)
	_bar.add_child(column)
	_tabs.add_theme_constant_override("separation",4)
	column.add_child(_tabs)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",12)
	column.add_child(body)
	_deck.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_deck)
	body.add_child(VSeparator.new())
	body.add_child(_build_strip())
	for entry: Array in editor.tool_groups():
		_build_group(entry[0],entry[1])
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cursor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cursor.size = Vector2(TILE,TILE)
	_cursor.pivot_offset = Vector2(TILE,TILE)*0.5
	_cursor.top_level = true
	_cursor.visible = false
	_cursor.modulate = Color(1,1,1,0.9)
	add_child(_cursor)
	_show_category(_category_of(editor.mode))
	_on_tool_changed(editor.mode)

func _build_strip() -> Control:
	_strip.custom_minimum_size = Vector2(352,0)
	_strip.add_theme_constant_override("separation",4)
	_hint.text = editor.status
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size",12)
	_hint.add_theme_color_override("font_color",Color("aab8ad"))
	_hint.custom_minimum_size = Vector2(0,30)
	_strip.add_child(_hint)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_strip.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation",4)
	scroll.add_child(stack)
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation",10)
	stack.add_child(_grid)
	_actions.add_theme_constant_override("h_separation",4)
	_actions.add_theme_constant_override("v_separation",3)
	stack.add_child(_actions)
	return _strip

func _build_group(title: String, tools: Array) -> void:
	var tab := Button.new()
	tab.text = title
	tab.toggle_mode = true
	tab.button_group = _tab_group
	tab.focus_mode = Control.FOCUS_NONE
	tab.pressed.connect(_show_category.bind(title))
	_tabs.add_child(tab)
	_tabs_by_name[title] = tab
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.visible = false
	_deck.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	scroll.add_child(row)
	_rows[title] = scroll
	for tool: String in tools:
		if tool == "assets":
			for piece: String in NativeAssetCatalog.PARTS:
				row.add_child(_tile(piece,"assets",piece))
			continue
		row.add_child(_tile(tool,tool,""))

func _tile(id: String, tool: String, piece: String) -> Button:
	var button := Button.new()
	button.name = "Tile_"+id
	button.toggle_mode = true
	button.button_group = _tile_group
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(TILE,TILE)
	button.tooltip_text = "%s\n%s" % [_title(id),editor.TOOL_TEXT.get(tool,"")]
	button.set_meta("tool",tool)
	button.set_meta("piece",piece)
	button.expand_icon = true
	if _placeable(id):
		button.add_child(_caption(id))
	else:
		var glyph := ToolGlyph.new()
		glyph.kind = GLYPHS.get(id,"disc")
		glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(glyph)
		button.add_child(_caption(id))
	button.pressed.connect(_choose.bind(id))
	button.gui_input.connect(_on_tile_input.bind(id))
	button.mouse_entered.connect(_on_tile_hover.bind(id,true))
	button.mouse_exited.connect(_on_tile_hover.bind(id,false))
	button.button_down.connect(_scale_tile.bind(button,PRESS_SCALE))
	button.button_up.connect(_scale_tile.bind(button,1.0))
	_tiles[id] = button
	return button

func _caption(id: String) -> Label:
	var label := Label.new()
	label.text = _title(id)
	label.add_theme_font_size_override("font_size",9)
	label.add_theme_color_override("font_color",Color("d5e2d6"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE,Control.PRESET_MODE_MINSIZE)
	label.offset_bottom = -3
	label.offset_top = -17
	return label

func _title(id: String) -> String:
	return "Bigfoot tree" if id == "bigfoot_tree" else id.replace("_"," ").capitalize()

func _placeable(id: String) -> bool:
	return id in LANDMARKS or NativeAssetCatalog.PARTS.has(id)

func _category_of(tool: String) -> String:
	for entry: Array in editor.tool_groups():
		if tool in entry[1]:
			return entry[0]
	return editor.tool_groups()[0][0]

func _show_category(title: String) -> void:
	_category = title
	for name: String in _rows:
		_rows[name].visible = name == title
		_tabs_by_name[name].set_pressed_no_signal(name == title)

# --- thumbnails -------------------------------------------------------------

## Render every placeable once into its own transparent viewport. Kept alive so
## the tiles can keep using the viewport textures as their icons.
func ensure_thumbnails() -> void:
	if not _thumbs.is_empty():
		return
	for id: String in _tiles:
		if not _placeable(id):
			continue
		var model := build_model(id)
		if model == null:
			continue
		_thumbs[id] = _render(model)
		_tiles[id].icon = _thumbs[id]

## The real meshes and materials for a placeable, in the local frame the garden
## renders its record in. Both the thumbnails and the drag ghost use this.
func build_model(id: String) -> Node3D:
	var view: GardenView = editor.content
	var root := Node3D.new()
	root.name = "Model_"+id
	match id:
		"tree":
			_part(root,view._meshes.trunk,view._materials.trunk,Color.WHITE,Transform3D.IDENTITY)
			_part(root,view._meshes.canopy,view._materials.canopy,view._tints.canopy,Transform3D.IDENTITY)
		"flower":
			_part(root,view._meshes.stem,view._materials.stem,Color.WHITE,Transform3D.IDENTITY)
			_part(root,view._meshes.petal,view._materials.petal,view._tints.petal,Transform3D.IDENTITY)
		"rock":
			_part(root,view._meshes.rock,view._materials.rock,Color.WHITE,Transform3D(Basis(),Vector3(0,0.24,0)))
		"arch":
			_part(root,editor.landmarks._arch_mesh,editor.landmarks._arch_material,Color.WHITE,Transform3D(Basis(),editor.landmarks._arch_offset))
		"bigfoot_tree":
			var tree: Node3D = preload("res://assets/bigfoot/old_tree.glb").instantiate()
			tree.scale *= preload("res://studies/bigfoot_encounter.gd").PEEK_SCALE
			root.add_child(tree)
		_:
			if not view._catalog_parts.has(id):
				root.free()
				return null
			for key: String in view._catalog_parts[id]:
				_part(root,view._meshes[key],view._materials[key],view._tints.get(key,Color.WHITE),view._catalog_poses[key])
	return root

func _part(root: Node3D, mesh: Mesh, material: Material, tint: Color, pose: Transform3D) -> void:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.transform = pose
	var copy := material.duplicate() as Material
	if copy is ShaderMaterial:
		# The living scene grows and sways these; a portrait wants them formed.
		for flag: String in ["terrain_growth","plant_growth","sway_enabled","wet_ground"]:
			copy.set_shader_parameter(flag,false)
		var base: Variant = copy.get_shader_parameter("base_color")
		copy.set_shader_parameter("base_color",(base if base is Color else Color.WHITE)*tint)
	node.material_override = copy
	root.add_child(node)

func _render(model: Node3D) -> Texture2D:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(ICON,ICON)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	_viewports.append(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.72,0.79,0.82)
	environment.environment.ambient_light_energy = 1.1
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-42.0),deg_to_rad(-38.0),0.0)
	light.light_energy = 1.5
	viewport.add_child(light)
	viewport.add_child(model)
	var bounds := AABB(Vector3.ZERO,Vector3.ZERO)
	var first := true
	for node: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var box := node.global_transform*node.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var center := bounds.get_center()
	var radius := maxf(bounds.size.length()*0.5,0.05)
	var camera := Camera3D.new()
	camera.fov = 32.0
	camera.near = 0.01
	camera.far = radius*20.0+50.0
	viewport.add_child(camera)
	var away := Vector3(0.62,0.46,1.0).normalized()*(radius/tan(deg_to_rad(camera.fov*0.5))*1.06)
	camera.look_at_from_position(center+away,center,Vector3.UP)
	return viewport.get_texture()

# --- selection and feel -----------------------------------------------------

func _choose(id: String) -> void:
	var button: Button = _tiles[id]
	if button.get_meta("piece") != "":
		editor.catalog_asset = button.get_meta("piece")
	editor.select_tool(button.get_meta("tool"))

func _scale_tile(button: Button, factor: float) -> void:
	if not is_instance_valid(button):
		return
	button.pivot_offset = button.size*0.5
	var tween := create_tween()
	tween.tween_property(button,"scale",Vector2.ONE*factor,TWEEN_TIME).set_trans(Tween.TRANS_SINE)

func _on_tile_hover(id: String, entered: bool) -> void:
	_scale_tile(_tiles[id],HOVER_SCALE if entered else 1.0)
	if not entered:
		_hint.text = editor.status
		return
	var tool: String = _tiles[id].get_meta("tool")
	_hint.text = "%s · %s" % [_title(id),editor.TOOL_TEXT.get(tool,"")]

func _on_tool_changed(tool: String) -> void:
	var chosen := tile_for(tool)
	for id: String in _tiles:
		_tiles[id].set_pressed_no_signal(_tiles[id] == chosen)
		_tiles[id].modulate = Color.WHITE if _tiles[id] == chosen else Color(0.82,0.86,0.83)
	_show_category(_category_of(tool))
	_rebuild_strip()

func _on_setting_changed(property: String, value: float) -> void:
	if not _strip_rows.has(property):
		return
	_strip_rows[property].control.set_value_no_signal(value)
	NativeSettingRow.show_value(_strip_rows[property],value)

func _on_status_changed(text: String) -> void:
	_hint.text = text

func _on_active_changed(enabled: bool) -> void:
	visible = enabled
	if enabled:
		ensure_thumbnails()
	else:
		_cancel_drag()

## The sliders for the tool in hand, then its one-shot actions and colours,
## beside the tiles. Every tool's whole set of controls lives here.
func _rebuild_strip() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	_strip_rows.clear()
	for spec: Dictionary in editor.settings_for(editor.mode):
		var entry := NativeSettingRow.build(editor,spec.property,true)
		entry.box.custom_minimum_size = Vector2(160,0)
		_grid.add_child(entry.box)
		_strip_rows[spec.property] = entry
	for action: Dictionary in editor.actions_for(editor.mode):
		var button := Button.new()
		button.name = action.name
		button.text = action.title
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size",11)
		button.pressed.connect(Callable(editor,action.method))
		_actions.add_child(button)
	if editor.mode == "paint":
		_actions.add_child(_colour_row("Colour","PaletteColor",editor.paint_color,
			func(color: Color) -> void: editor.paint_color = color))
	elif editor.mode in editor.POSE_TOOLS:
		_actions.add_child(_tint_row())

## The Paint tool names its colour; the picker itself is what a shell drives.
func _colour_row(title: String, id: String, colour: Color, apply: Callable) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size",11)
	row.add_child(label)
	row.add_child(_picker(id,colour,apply))
	return row

## Placeables tint only when asked; touching the picker asks for them.
func _tint_row() -> Control:
	var row := HBoxContainer.new()
	var box := CheckBox.new()
	box.name = "CustomColor"
	box.text = "Custom color"
	box.button_pressed = editor.custom_tint
	box.focus_mode = Control.FOCUS_NONE
	box.add_theme_font_size_override("font_size",11)
	box.toggled.connect(func(enabled: bool) -> void: editor.custom_tint = enabled)
	row.add_child(box)
	row.add_child(_picker("PlacementColor",editor.object_tint,func(colour: Color) -> void:
		editor.object_tint = colour
		box.button_pressed = true
	))
	return row

func _picker(id: String, colour: Color, apply: Callable) -> ColorPickerButton:
	var picker := ColorPickerButton.new()
	picker.name = id
	picker.color = colour
	picker.edit_alpha = false
	picker.custom_minimum_size = Vector2(72,0)
	picker.color_changed.connect(apply)
	return picker

# --- drag to place ----------------------------------------------------------

func _on_tile_input(event: InputEvent, id: String) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	_choose(id)
	if not _placeable(id):
		return
	_drag_id = id
	_pressed = true
	_press_at = event.global_position

func _input(event: InputEvent) -> void:
	if not _pressed:
		return
	if event is InputEventMouseMotion:
		if not _dragging and event.position.distance_to(_press_at) > DRAG_SLOP:
			_begin_drag()
		if _dragging:
			_cursor.position = event.position-_cursor.size*0.5
			_move_ghost(event.position)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var carried := _dragging
		_drop(event.position)
		if carried:
			get_viewport().set_input_as_handled()

func _begin_drag() -> void:
	_dragging = true
	_bob = 0.0
	_cursor.texture = _thumbs.get(_drag_id)
	_cursor.scale = Vector2.ONE
	_cursor.visible = true
	_clear_ghost()
	var model := build_model(_drag_id)
	if model == null:
		return
	_ghost = Node3D.new()
	_ghost.name = "PaletteGhost"
	_ghost.add_child(model)
	_ghost.visible = false
	editor.content.add_child(_ghost)
	for node: MeshInstance3D in _ghost.find_children("*","MeshInstance3D",true,false):
		node.material_override = _ghost_material()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _ghost_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.86,0.96,0.88,0.42)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

## Sit the ghost on the ground under the pointer, matching what a click here
## would commit. It lives outside the records, so nothing saves or picks it.
func _move_ghost(mouse: Vector2) -> bool:
	if _ghost == null:
		return false
	var hit: Variant = editor.pick(mouse)
	if hit == null:
		_ghost.visible = false
		return false
	var basis := Basis(Vector3.UP,editor.object_angle).scaled(Vector3.ONE*editor.object_scale)
	var lift := 0.0
	var pose := editor._placement_pose()
	if not pose.is_empty():
		basis = NativeObjectPose.decode_basis(pose)
		lift = NativeObjectPose.decode_offset(pose)
	_ghost_ground = hit.y+lift
	_ghost.transform = Transform3D(basis,Vector3(hit.x,_ghost_ground,hit.z))
	_ghost.visible = true
	return true

func _drop(mouse: Vector2) -> void:
	_pressed = false
	if not _dragging:
		return
	_dragging = false
	var placed := _ghost != null and _ghost.visible and editor.place_at(mouse)
	_clear_ghost()
	if placed:
		_cursor.visible = false
		_cursor.scale = Vector2.ONE
	else:
		var tween := create_tween()
		tween.tween_property(_cursor,"scale",Vector2.ZERO,0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void:
			_cursor.visible = false
			_cursor.scale = Vector2.ONE
		)
	drag_finished.emit(placed)

func _cancel_drag() -> void:
	_pressed = false
	_dragging = false
	_cursor.visible = false
	_cursor.scale = Vector2.ONE
	_clear_ghost()

func _clear_ghost() -> void:
	if _ghost == null:
		return
	_ghost.get_parent().remove_child(_ghost)
	_ghost.queue_free()
	_ghost = null

func _process(delta: float) -> void:
	if not _dragging or _ghost == null or not _ghost.visible:
		return
	_bob += delta
	_ghost.position.y = _ghost_ground+sin(_bob*5.5)*0.06*editor.object_scale

## A flat glyph for the tools that shape ground and cover rather than place a
## thing: the tile still reads at a glance without a mesh to portrait.
class ToolGlyph:
	extends Control
	var kind := "disc"

	func _draw() -> void:
		var middle := size*Vector2(0.5,0.44)
		var span := minf(size.x,size.y)*0.26
		var color := Color("cfe0cd")
		match kind:
			"up","down":
				var way := -1.0 if kind == "up" else 1.0
				draw_line(middle+Vector2(0,-span*way),middle+Vector2(0,span*way),color,3.0)
				draw_colored_polygon(PackedVector2Array([
					middle+Vector2(0,span*way*1.4),
					middle+Vector2(-span*0.7,span*way*0.2),
					middle+Vector2(span*0.7,span*way*0.2)]),color)
			"bar":
				draw_rect(Rect2(middle-Vector2(span,3.0),Vector2(span*2.0,6.0)),color)
			"wave":
				var points := PackedVector2Array()
				for i in range(17):
					var t := float(i)/16.0
					points.append(middle+Vector2((t-0.5)*span*2.4,sin(t*TAU)*span*0.45))
				draw_polyline(points,color,3.0)
			"peak":
				draw_colored_polygon(PackedVector2Array([
					middle+Vector2(-span*1.2,span*0.8),
					middle+Vector2(0,-span*1.1),
					middle+Vector2(span*1.2,span*0.8)]),color)
			"tuft":
				for i in range(5):
					var root := middle+Vector2((float(i)-2.0)*span*0.42,span*0.8)
					draw_line(root,root+Vector2((float(i)-2.0)*span*0.2,-span*1.5),color,2.5)
			"ring":
				draw_arc(middle,span,0.0,TAU,28,color,3.0)
			_:
				draw_circle(middle,span,color)
