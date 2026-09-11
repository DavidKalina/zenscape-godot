class_name NativeBuildPalette
extends Control
const TactileStyle = preload("res://scripts/tactile_editor_style.gd")
## Searchable tool and miniature palette. The landscape stays clear until Cmd/Ctrl K.
## Placeable tiles carry a thumbnail rendered from the real mesh and material,
## and can be dragged into the world, where a ghost follows the ground until
## the drop commits through the editor's own placement path. A last tab holds
## the sky: mood and weather swatches over the scene's own light and air.
const TILE := 54.0
const SWATCH := 56.0
const ICON := 256
const BAR_HEIGHT := 48.0
const TAB_TITLES := {"Sculpt":"Shape", "Landscape":"Land", "Cover":"Plant", "Place":"Miniatures"}
const DRAG_SLOP := 6.0
const HOVER_SCALE := 1.08
const PRESS_SCALE := 0.94
const TWEEN_TIME := 0.09
const LANDMARKS := ["tree","rock","flower","arch","bigfoot_tree","campsite","fallen_branch"]
## Landscape tools whose stamp is a shape, so the tile can portrait the real
## heightfield instead of a drawn glyph. Only Mountain stamps at a point, so
## only Mountain drags; Range forms the whole chunk from its strip button.
const LANDFORMS := ["mountain","range"]
const LANDFORM_CELLS := 28
## Below this the mountain stamp has not left the ground, and drawing it would
## only lay a flat plate over the terrain for the depth test to fight with.
const LANDFORM_FLOOR := 0.03
## A landform ghost hovers this far above the terrain. It must clear the fog
## composite's inversion paint, which repaints translucent surfaces sitting on
## the ground as ground under the Balanced preset and erased the ghost at 0.02;
## probes on 2026-09-07 showed it whole again from 0.3 up.
const LANDFORM_LIFT := 0.3
const GHOST_ALPHA := 0.55
## Simple drawn glyphs stand in for the tools that have no object to render.
const GLYPHS := {
	"select":"ring",
	"raise":"up","lower":"down","smooth":"wave","flatten":"bar",
	"ground":"bar","range":"peak","mountain":"peak",
	"grass":"tuft","blades":"tuft","meadow":"tuft","paint":"disc","erase":"ring",
	"pond":"disc","waterfall":"down","assets":"ring",
}
## The sky tab is not a tool: choosing it leaves the tool in hand alone and
## swaps the strip for the scene's own weather, light and air.
const SKY_TAB := "Sky"
## Each mood the scene can settle into, with the sky its swatch paints.
const MOODS := [
	{"title":"Golden hour","top":Color("2b5f95"),"bottom":Color("f3b169"),"mark":"sun"},
	{"title":"Misty dawn","top":Color("6d7f94"),"bottom":Color("d8dbd4"),"mark":"lines"},
	{"title":"Night","top":Color("070d1d"),"bottom":Color("1d2c50"),"mark":"moon"},
]
## One swatch per weather preset, in the order the precipitation node names them.
const SKIES := {
	"clear":{"top":Color("2f7bc0"),"bottom":Color("9fd0ea"),"mark":"sun"},
	"rain":{"top":Color("4a5763"),"bottom":Color("8e9aa3"),"mark":"rain"},
	"storm":{"top":Color("242c36"),"bottom":Color("5a6470"),"mark":"bolt"},
	"snow":{"top":Color("788ea3"),"bottom":Color("e6eef4"),"mark":"flake"},
	"fair":{"top":Color("3f8ac6"),"bottom":Color("cfe4f0"),"mark":"cloud"},
	"overcast":{"top":Color("6a7480"),"bottom":Color("aab3ba"),"mark":"cloud"},
	"mist":{"top":Color("8a97a0"),"bottom":Color("d3dbdc"),"mark":"lines"},
	"autumn":{"top":Color("6f6a4d"),"bottom":Color("d29a52"),"mark":"leaf"},
}

## Reports every finished drag, so a shell can chime or count placements.
signal drag_finished(placed: bool)
signal scene_controls_requested

var editor: NativeChunkEditor
var _bar := PanelContainer.new()
var _tabs := HBoxContainer.new()
var _strip := VBoxContainer.new()
var _scroll := ScrollContainer.new()
var _grid := GridContainer.new()
var _actions := HFlowContainer.new()
var _hint := Label.new()
var _tabs_by_name := {}
var _tiles := {}
var _sky_tiles := {}
var _sky_rows := {}
var _sky_group := ButtonGroup.new()
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
var _details := PanelContainer.new()
var _details_title := Label.new()
var _tune := Button.new()
const FOLIAGE := ["redwood","fern","tree","flower","broadleaf","shrub","reeds","bank_grass","button_flower","spike_flower","umbel_flower","daisy_flower","grass_tuft","mushroom"]
var _search := LineEdit.new()
var _results := VBoxContainer.new()
var _library := Control.new()
var _scrim := ColorRect.new()
var _launcher := Button.new()
var _page_label := Label.new()
var _empty := Label.new()
var _entries := {}
var _matches: Array[String] = []
var _page := 0
var _setting_page := 0
var _setting_pages := HBoxContainer.new()
var _setting_page_label := Label.new()
var _page_size := 8
var _focus_index := 0


var _search_category := "All"
var _portraits := {}
var _portrait_clock := 0.0
var miniatures_animate := true
const CATEGORIES := ["All", "Terrain", "Water", "Flora", "Creatures", "Weather", "Scene"]
var _fit_wrapper := Control.new()
var _result_scroll := ScrollContainer.new()
var _row_buttons := {}
var _result_rows := {}
var _result_headings := {}
var _detail_preview := TextureRect.new()
var _detail_name := Label.new()
var _detail_description := Label.new()
var _meta_table := VBoxContainer.new()
var _hud_count := Label.new()
var _placing := ""
var _tool_rail: Control
var _hand := preload("res://scripts/native_garden_cursor.gd").new()
var _inhabitant: CreatureActor
var _entrance: Tween
var _mono: Font


## Take an editor that has already been set up and build the palette for it.
func attach(target: NativeChunkEditor) -> void:
	editor = target
	editor.tool_changed.connect(_on_tool_changed)
	editor.setting_changed.connect(_on_setting_changed)
	editor.status_changed.connect(_on_status_changed)
	editor.active_changed.connect(_on_active_changed)
	editor.sky_toggle_requested.connect(_on_sky_toggle_requested)
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

## A sky swatch by its id: "mood_0".."mood_2" for the moods, "weather_rain" and
## the like for the presets. Null while the scene offers no sky to shape.
func sky_tile_for(id: String) -> Button:
	return _sky_tiles.get(id)

## One sky slider by name, as the strip holds it: {box,control,label,...}.
func sky_row(key: String) -> Dictionary:
	return _sky_rows.get(key,{})

## The category the palette is showing, tool group or sky.
func category() -> String:
	return _category

## True when the expanded settings need no vertical scrolling.
func strip_fits() -> bool:
	var inner: Control = _scroll.get_child(0)
	return inner.get_combined_minimum_size().y <= _scroll.size.y+0.5

## The detached settings panel also shields the terrain from pointer input.
func contains_pointer(point: Vector2) -> bool:
	return _bar.visible or (_tool_rail != null and _tool_rail.contains_pointer(point)) or (_launcher.visible and _launcher.get_global_rect().has_point(point)) or (_tune.visible and _tune.get_global_rect().has_point(point)) or (_details.visible and _details.get_global_rect().has_point(point))

## True while a tile is being dragged towards the world.
func dragging() -> bool:
	return _dragging

## The translucent preview following the ground, or null when nothing is dragged.
func ghost() -> Node3D:
	return _ghost

# --- layout -----------------------------------------------------------------

func _build() -> void:
	name = "BuildPalette"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_install_theme()
	_library.visible = false
	add_child(_library)
	# Existing tile/control factories retain their ownership under the library.
	_library.add_child(_hint)
	_scrim.color = Color.WHITE
	var veil_material := ShaderMaterial.new()
	veil_material.shader = load("res://shaders/palette_veil.gdshader")
	_scrim.material = veil_material
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop_copy := BackBufferCopy.new()
	backdrop_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(backdrop_copy)
	add_child(_scrim)
	add_child(_fit_wrapper)
	_fit_wrapper.add_child(_bar)
	_bar.custom_minimum_size = Vector2(880,540)
	_bar.size = Vector2(880,540)
	var panel_style := _stone_style(Color(0,0,0,0),26)
	panel_style.set_content_margin_all(0)
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color(0.85,0.70,0.44,0.45)
	panel_style.shadow_size = 40
	panel_style.shadow_offset = Vector2(0,25)
	panel_style.shadow_color = Color(0.047,0.031,0.047,0.55)
	_bar.add_theme_stylebox_override("panel",panel_style)
	var surface := Control.new()
	surface.custom_minimum_size = Vector2(880,540)
	_bar.add_child(surface)
	var glass := ColorRect.new()
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var glass_material := ShaderMaterial.new()
	glass_material.shader = load("res://shaders/palette_panel.gdshader")
	glass.material = glass_material
	surface.add_child(glass)
	var diamond := Label.new()
	diamond.text = "◆"
	diamond.position = Vector2(22,22)
	diamond.add_theme_color_override("font_color",Color("d8b26f"))
	surface.add_child(diamond)
	_search.position = Vector2(45,14)
	_search.size = Vector2(672,40)
	_search.placeholder_text = "Place, summon, or shape…"
	_search.add_theme_font_size_override("font_size",21)
	_search.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	_search.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	_search.add_theme_color_override("font_placeholder_color",Color(0.97,0.94,0.89,0.55))
	_search.text_changed.connect(func(_text: String) -> void: _refresh_results())
	_search.text_submitted.connect(func(_text: String) -> void: _activate_result())
	surface.add_child(_search)
	_page_label.position = Vector2(744,27)
	_page_label.size = Vector2(112,20)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_page_label.add_theme_font_override("font",_mono)
	_page_label.add_theme_font_size_override("font_size",11)
	_page_label.modulate.a = 0.5
	surface.add_child(_page_label)
	_tabs.position = Vector2(22,78)
	_tabs.add_theme_constant_override("separation",7)
	surface.add_child(_tabs)
	for category_name: String in CATEGORIES: _add_category(category_name,category_name)
	for entry: Array in editor.tool_groups(): _build_group(entry[0],entry[1])
	_build_sky_group()
	for id: String in _tiles:
		var group := "Terrain"
		var old_group := _category_of(_tiles[id].get_meta("tool"))
		if old_group == "Water": group = "Water"
		elif id in FOLIAGE or old_group == "Cover": group = "Flora"
		elif id in ["bigfoot_tree","campsite"]: group = "Creatures"
		_entries[id] = {"button":_tiles[id],"group":group,"title":_title(id),"blurb":editor.TOOL_TEXT.get(_tiles[id].get_meta("tool"),"A small detail for your world")}
	for id: String in _sky_tiles:
		_entries[id] = {"button":_sky_tiles[id],"group":"Weather","title":_sky_tiles[id].tooltip_text.get_slice("\n",0),"blurb":"Settle the whole scene into a new atmosphere"}
	for entry: Array in [["undo","Undo",editor.undo],["redo","Redo",editor.redo],
		["save","Save garden",editor.scene.save_current if editor.scene.has_method("save_current") else editor.save_garden],["open","Open garden",editor.scene.show_open if editor.scene.has_method("show_open") else editor.open_garden],
		["inspect","Leave build mode",func() -> void: editor.set_active(false)],
		["landscapes","Landscapes · formation families and biomes",editor.scene.edit_landscape_presets],
		["scene_colors","Looks & presets · colors and atmosphere",editor.scene.edit_scene_look],
		["sky_settings","Sky settings",func() -> void: _show_category(SKY_TAB); _details.visible = true; _tune.set_pressed_no_signal(true)],
		["tool_settings","Tool settings",func() -> void: _details.visible = true; _tune.set_pressed_no_signal(true)]]:
		var button := Button.new()
		button.pressed.connect(func() -> void: close_palette(); entry[2].call())
		_library.add_child(button)
		_entries["command_"+entry[0]] = {"button":button,"group":"Scene","title":entry[1],"blurb":"Care for your diorama"}
	for entry: Array in [["bigfoot","Bigfoot","Creatures","A curious visitor. Set him down and watch him settle."], ["wind_gust","Wind gust","Weather","Drag the ground to aim a gust. Release to send it."], ["fireflies","Fireflies","Creatures","Invite little lights, even in daylight."], ["fog_bank","Fog bank","Weather","Wrap the landscape in a soft bank of mist."]]:
		var button := Button.new()
		_library.add_child(button)
		button.pressed.connect(_take_special.bind(entry[0]))
		_entries[entry[0]] = {"button":button,"group":entry[2],"title":entry[1],"blurb":entry[3]}
	# Use truthful descriptions of the currently available tools.
	for id: String in {"tree":"Pine", "raise":"Rolling hill", "rock":"Boulder", "meadow":"Wildflowers", "range":"Mountain ridge"}:
		_entries[id].title = {"tree":"Pine", "raise":"Rolling hill", "rock":"Boulder", "meadow":"Wildflowers", "range":"Mountain ridge"}[id]
	_result_scroll.position = Vector2(12,128)
	_result_scroll.size = Vector2(481,398)
	_result_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_result_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	surface.add_child(_result_scroll)
	_results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results.add_theme_constant_override("separation",2)
	_result_scroll.add_child(_results)
	_empty.text = "Nothing by that name\nTry “tree”, “water”, “wind”, or “bigfoot”."
	_empty.position = Vector2(24,160)
	_empty.size = Vector2(460,70)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	surface.add_child(_empty)
	_build_preview(surface)
	for line: Rect2 in [Rect2(0,65,880,1),Rect2(0,117,880,1),Rect2(505,118,1,422)]:
		var rule := ColorRect.new()
		rule.position = line.position
		rule.size = line.size
		rule.color = Color(0.85,0.70,0.44,0.18)
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		surface.add_child(rule)
	var hud := Label.new()
	hud.text = "zenscape"
	hud.position = Vector2(24,22)
	hud.add_theme_font_size_override("font_size",12)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	move_child(hud,1)
	_hud_count.visible = false
	_hud_count.position = Vector2(24,45)
	_hud_count.add_theme_font_override("font",_mono)
	_hud_count.add_theme_font_size_override("font_size",11)
	_hud_count.modulate.a = 0.7
	_hud_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_count)
	move_child(_hud_count,2)
	_details.name = "ToolDetails"
	_details.add_theme_stylebox_override("panel",TactileStyle.panel(20,16))
	_details.visible = false
	add_child(_details)
	_details.add_child(_build_strip())
	_launcher.pressed.connect(open_palette)
	_launcher.custom_minimum_size = Vector2(190,30)
	var pill := _stone_style(Color(0.24,0.18,0.23,0.86),24)
	pill.set_border_width_all(1)
	pill.border_color = Color(0.85,0.70,0.44,0.4)
	_launcher.add_theme_stylebox_override("normal",pill)
	_launcher.add_theme_font_size_override("font_size",14)
	add_child(_launcher)
	_tune.icon = _line_icon("tune")
	_tune.tooltip_text = "Current tool settings"
	_tune.toggle_mode = true
	_tune.toggled.connect(func(open: bool) -> void: _details.visible = open)
	add_child(_tune)
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.size = Vector2(TILE,TILE)
	_cursor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cursor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cursor.visible = false
	add_child(_cursor)
	add_child(_hand)
	get_viewport().size_changed.connect(_fit_dock)
	_tool_rail = preload("res://scripts/native_tool_rail.gd").new()
	add_child(_tool_rail)
	_tool_rail.setup(self)
	_details.visibility_changed.connect(func() -> void:
		if _details.visible: _tool_rail.close_controls())
	_fit_dock()
	_on_tool_changed(editor.mode)
	close_palette()

func _add_category(id: String, title: String) -> void:
	var tab := Button.new()
	tab.text = title
	tab.add_theme_font_size_override("font_size",13)
	for state: String in ["normal","hover","pressed","hover_pressed"]:
		var selected := state in ["pressed","hover_pressed"]
		var chip := _stone_style(Color("d8b26f") if selected else Color(0.97,0.94,0.89,0.08),20)
		chip.shadow_size = 0
		chip.content_margin_left = 13
		chip.content_margin_right = 13
		chip.content_margin_top = 6
		chip.content_margin_bottom = 6
		tab.add_theme_stylebox_override(state,chip)
	tab.add_theme_color_override("font_pressed_color",Color("2b2126"))
	tab.add_theme_color_override("font_hover_pressed_color",Color("2b2126"))
	tab.toggle_mode = true
	tab.button_group = _tab_group
	tab.focus_mode = Control.FOCUS_NONE
	tab.pressed.connect(_browse.bind(id))
	_tabs.add_child(tab)
	_tabs_by_name[id] = tab

func _browse(id: String) -> void:
	if id in [SKY_TAB,"Weather"]: _show_category(SKY_TAB)
	id = {"Cover":"Flora","Place":"Terrain","Sky":"Weather"}.get(id,id)
	_search_category = id
	_page = 0
	_refresh_results()

func open_palette() -> void:
	if editor.scene._landscape_editor != null: editor.scene._landscape_editor.hide()
	if editor.scene._look_editor != null: editor.scene._look_editor.hide()
	if not editor.active: return
	editor.finish_stroke()
	_hand.hide_pointer()
	_bar.visible = true
	_scrim.visible = true
	_launcher.visible = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_tool_rail.visible = false
	_tune.visible = false
	_details.visible = false
	_tune.set_pressed_no_signal(false)
	_search.text = ""
	_search_category = "All"
	_page = 0
	_refresh_results()
	_search.grab_focus()
	if _entrance: _entrance.kill()
	_bar.modulate.a = 0.0
	_bar.position.y = 14
	_entrance = create_tween().set_parallel(true)
	_entrance.tween_property(_bar,"modulate:a",1.0,0.24)
	_entrance.tween_property(_bar,"position:y",0.0,0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func close_palette() -> void:
	_bar.visible = false
	_scrim.visible = false
	_launcher.visible = false
	_tune.visible = false
	_search.release_focus()
	if _category == SKY_TAB: _show_category(_category_of(editor.mode))
	if _tool_rail != null: _tool_rail.visible = true

## Names outrank incidental words in descriptions. Keep category grouping,
## bringing the best matching category first only while searching.
func _search_rank(id: String, query: String) -> int:
	var title: String = _entries[id].title.to_lower()
	if title == query: return 0
	if title.begins_with(query): return 1
	if title.contains(query): return 2
	if id.replace("_"," ").contains(query): return 3
	return 4 if _entries[id].blurb.to_lower().contains(query) else 5

func _refresh_results() -> void:
	if _entries.is_empty(): return
	for child in _results.get_children():
		child.hide()
	_row_buttons.clear()
	_matches.clear()
	var query := _search.text.strip_edges().to_lower()
	var ordered: Array = _entries.keys()
	var featured := ["range","mountain","raise","rock","pond","waterfall","tree","broadleaf","meadow","flower","bigfoot","fireflies"]
	ordered.sort_custom(func(a: String,b: String) -> bool:
		if not query.is_empty():
			var ar := _search_rank(a,query)
			var br := _search_rank(b,query)
			if ar != br: return ar < br
		var ai := featured.find(a)
		var bi := featured.find(b)
		return (ai if ai >= 0 else 100) < (bi if bi >= 0 else 100))
	var groups: Array = CATEGORIES.slice(1)
	if not query.is_empty():
		var rank := {}
		for group: String in groups: rank[group] = 5
		for id: String in ordered:
			var group: String = _entries[id].group
			rank[group] = mini(rank[group],_search_rank(id,query))
		groups.sort_custom(func(a: String,b: String) -> bool:
			return rank[a] < rank[b] if rank[a] != rank[b] else CATEGORIES.find(a) < CATEGORIES.find(b))
	var result_index := 0
	for group: String in groups:
		if _search_category != "All" and _search_category != group: continue
		var heading_added := false
		for id: String in ordered:
			var entry: Dictionary = _entries[id]
			if entry.group != group: continue
			var words: String = (entry.title+" "+id.replace("_"," ")+" "+entry.blurb).to_lower()
			if not query.is_empty() and not words.contains(query): continue
			if not heading_added:
				if not _result_headings.has(group):
					var heading := Label.new()
					heading.text = "  "+group.to_upper()
					heading.custom_minimum_size.y = 30
					heading.add_theme_font_override("font",_mono)
					heading.add_theme_font_size_override("font_size",11)
					heading.add_theme_color_override("font_color",Color("e6c07c"))
					_results.add_child(heading)
					_result_headings[group] = heading
				_result_headings[group].show()
				_results.move_child(_result_headings[group],result_index)
				result_index += 1
				heading_added = true
			_matches.append(id)
			if not _result_rows.has(id):
				_result_rows[id] = _make_result_row(id)
				_results.add_child(_result_rows[id])
			var row: Button = _result_rows[id]
			row.get_child(0).texture = _thumbs.get(id,entry.button.icon)
			row.show()
			_results.move_child(row,result_index)
			result_index += 1
			_row_buttons[id] = row
	_empty.visible = _matches.is_empty()
	_page_label.text = "%d results" % _matches.size()
	for id: String in _tabs_by_name: _tabs_by_name[id].set_pressed_no_signal(id == _search_category)
	_focus_index = 0
	_result_scroll.scroll_vertical = 0
	_mark_result()

func _make_result_row(id: String) -> Button:
	var entry: Dictionary = _entries[id]
	var button := Button.new()
	button.custom_minimum_size = Vector2(0,55)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: entry.button.pressed.emit())
	if _tiles.has(id): button.gui_input.connect(_on_tile_input.bind(id))
	button.mouse_entered.connect(func() -> void: _focus_index = _matches.find(id); _mark_result(false))
	var icon := TextureRect.new()
	icon.position = Vector2(10,12)
	icon.size = Vector2(30,30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _thumbs.get(id,entry.button.icon)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var title := Label.new()
	title.text = entry.title
	title.position = Vector2(52,6)
	title.size = Vector2(325,22)
	title.clip_text = true
	title.add_theme_font_size_override("font_size",15)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(title)
	var blurb := Label.new()
	blurb.text = entry.blurb.get_slice("\n",0)
	blurb.position = Vector2(52,29)
	blurb.size = Vector2(330,18)
	blurb.clip_text = true
	blurb.add_theme_font_size_override("font_size",12)
	blurb.modulate.a = 0.72
	blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(blurb)
	var badge := Label.new()
	badge.text = _verb(id)
	badge.position = Vector2(394,18)
	badge.size = Vector2(68,18)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.add_theme_font_override("font",_mono)
	badge.add_theme_font_size_override("font_size",11)
	badge.add_theme_color_override("font_color",Color("e6c07c"))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(badge)
	return button

func _verb(id: String) -> String:
	if id == "range": return "scene"
	if id == "wind_gust": return "aim"
	if id.begins_with("command_") or _entries[id].group == "Weather" or id == "fireflies": return "scene"
	if _placeable(id): return "click"
	if id == "bigfoot": return "hero"
	if id == "wind_gust": return "aim"
	return "shape" if _entries[id].group == "Terrain" else "brush"

func _build_preview(surface: Control) -> void:
	var preview_frame := Panel.new()
	preview_frame.position = Vector2(526,136)
	preview_frame.size = Vector2(334,132)
	var style := _stone_style(Color(0.85,0.70,0.44,0.06),14)
	style.set_border_width_all(1)
	style.border_color = Color(0.85,0.70,0.44,0.22)
	preview_frame.add_theme_stylebox_override("panel",style)
	surface.add_child(preview_frame)
	_detail_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_frame.add_child(_detail_preview)
	_detail_name.position = Vector2(526,284)
	_detail_name.size = Vector2(334,26)
	_detail_name.add_theme_font_size_override("font_size",17)
	surface.add_child(_detail_name)
	_detail_description.position = Vector2(526,316)
	_detail_description.size = Vector2(334,72)
	_detail_description.max_lines_visible = 3
	_detail_description.clip_text = true
	_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_description.add_theme_font_size_override("font_size",14)
	_detail_description.modulate.a = 0.82
	surface.add_child(_detail_description)
	_meta_table.position = Vector2(526,398)
	_meta_table.size = Vector2(334,114)
	_meta_table.add_theme_constant_override("separation",1)
	surface.add_child(_meta_table)

func _turn_page(direction: int) -> void:
	if _matches.is_empty(): return
	_focus_index = posmod(_focus_index+direction,_matches.size())
	_mark_result()

func _mark_result(scroll_to_selection := true) -> void:
	for i in range(_matches.size()):
		var button: Button = _row_buttons[_matches[i]]
		var style := _stone_style(Color(0.72,0.52,0.42,0.24 if i == _focus_index else 0.0),12)
		style.shadow_size = 0
		style.set_border_width_all(1 if i == _focus_index else 0)
		style.border_color = Color(0.94,0.84,0.64,0.55)
		for state: String in ["normal","hover","pressed"]: button.add_theme_stylebox_override(state,style)
	for child in _meta_table.get_children():
		_meta_table.remove_child(child)
		child.queue_free()
	_detail_preview.texture = null
	_detail_name.text = "—"
	_detail_description.text = "Search the catalog to see how a piece behaves once it is in the world."
	if _matches.is_empty(): return
	var id := _matches[_focus_index]
	var entry: Dictionary = _entries[id]
	_detail_preview.texture = _thumbs.get(id,entry.button.icon)
	_detail_name.text = entry.title
	_detail_description.text = entry.blurb.get_slice("\n",0)
	for pair: Array in [["CATEGORY",entry.group],["INTERACTION",_verb(id).capitalize()],["PLACEMENT","In the world" if _verb(id) != "scene" else "Whole scene"]]:
		var row := PanelContainer.new()
		var style := _stone_style(Color(0.97,0.94,0.89,0.07),4)
		style.shadow_size = 0
		style.set_content_margin_all(9)
		row.add_theme_stylebox_override("panel",style)
		var box := HBoxContainer.new()
		row.add_child(box)
		var key := Label.new()
		key.text = pair[0]
		key.add_theme_font_override("font",_mono)
		key.add_theme_font_size_override("font_size",11)
		key.add_theme_color_override("font_color",Color("e6c07c"))
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(key)
		var value := Label.new()
		value.text = pair[1]
		value.add_theme_font_size_override("font_size",13)
		box.add_child(value)
		_meta_table.add_child(row)
	if scroll_to_selection: _reveal_selection.call_deferred()

func _reveal_selection() -> void:
	if _matches.is_empty(): return
	var row: Button = _row_buttons[_matches[_focus_index]]
	if row.position.y-44 < _result_scroll.scroll_vertical:
		_result_scroll.scroll_vertical = maxi(0,int(row.position.y-44))
	elif row.position.y+row.size.y+12 > _result_scroll.scroll_vertical+_result_scroll.size.y:
		_result_scroll.scroll_vertical = int(row.position.y+row.size.y+12-_result_scroll.size.y)

func _activate_result() -> void:
	if _matches.is_empty(): return
	_entries[_matches[_focus_index]].button.pressed.emit()

func _build_strip() -> Control:
	_strip.custom_minimum_size = Vector2(352,0)
	_strip.add_theme_constant_override("separation",4)
	var heading := HBoxContainer.new()
	heading.name = "SettingsHeading"
	_details_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_details_title)
	var close := Button.new()
	close.name = "CloseSettings"
	close.text = "Close"
	close.pressed.connect(func() -> void:
		_details.hide()
		_tune.set_pressed_no_signal(false))
	heading.add_child(close)
	_strip.add_child(heading)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_strip.add_child(_scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation",4)
	_scroll.add_child(stack)
	stack.minimum_size_changed.connect(_fit_details.call_deferred)
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation",8)
	stack.add_child(_grid)
	_actions.add_theme_constant_override("h_separation",4)
	_actions.add_theme_constant_override("v_separation",3)
	stack.add_child(_actions)
	_setting_pages.add_theme_constant_override("separation",8)
	_setting_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setting_pages.add_child(_setting_page_label)
	for direction: int in [-1,1]:
		var button := Button.new()
		button.text = "Previous" if direction < 0 else "Next"
		button.pressed.connect(func() -> void:
			_setting_page = posmod(_setting_page+direction,maxi(1,ceili(_grid.get_child_count()/6.0)))
			_paginate_settings())
		_setting_pages.add_child(button)
	stack.add_child(_setting_pages)
	return _strip

func _paginate_settings() -> void:
	var count := _grid.get_child_count()
	for i in range(count): _grid.get_child(i).visible = i/6 == _setting_page
	_setting_pages.visible = count > 6
	_setting_page_label.text = "%d / %d" % [_setting_page+1,maxi(1,ceili(count/6.0))]
	_fit_details.call_deferred()

func _build_group(title: String, tools: Array) -> void:

	for tool: String in tools:
		if tool == "assets":
			for piece: String in NativeAssetCatalog.PARTS: _library.add_child(_tile(piece,"assets",piece))
		else:
			_library.add_child(_tile(tool,tool,""))

func _tile(id: String, tool: String, piece: String) -> Button:
	var button := Button.new()
	button.name = "Tile_"+id
	button.toggle_mode = true
	button.button_group = _tile_group
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(TILE,TILE)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.tooltip_text = "%s\n%s" % [_title(id),editor.TOOL_TEXT.get(tool,"")]
	button.set_meta("tool",tool)
	button.set_meta("piece",piece)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _portrait(id):
		for state: String in ["normal","hover","pressed","hover_pressed"]:
			var style: StyleBoxFlat = theme.get_stylebox(state,"Button").duplicate()
			style.content_margin_bottom = 18
			button.add_theme_stylebox_override(state,style)
	if _portrait(id):
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
	return _caption_text(_title(id))

func _caption_text(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.clip_text = true
	label.add_theme_font_size_override("font_size",9)
	label.add_theme_color_override("font_color",Color("b9b1bc"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE,Control.PRESET_MODE_MINSIZE)
	label.offset_bottom = -3
	label.offset_top = -17
	return label

func _title(id: String) -> String:
	if _entries.has(id): return str(_entries[id].title)
	return "Bigfoot tree" if id == "bigfoot_tree" else id.replace("_"," ").capitalize()

func _placeable(id: String) -> bool:
	return id in LANDMARKS or NativeAssetCatalog.PARTS.has(id)

## Landscape tools that shape ground rather than place an object.
func _landform(id: String) -> bool:
	return id in LANDFORMS

## Tiles that carry a rendered thumbnail rather than a drawn glyph.
func _portrait(id: String) -> bool:
	return _placeable(id) or _landform(id)

## Tiles that can be carried into the world. Range forms the whole chunk at
## once, so it has no drop point to aim at and stays a click.
func _draggable(id: String) -> bool:
	return _placeable(id) or id == "mountain"

func _category_of(tool: String) -> String:
	if tool in FOLIAGE or tool == "assets" and editor.catalog_asset in FOLIAGE:
		return "Cover"
	for entry: Array in editor.tool_groups():
		if tool in entry[1]:
			return entry[0]
	return editor.tool_groups()[0][0]

## Showing a category only changes what the bar offers, never the tool in hand:
## the sky tab shapes the scene's weather while the same brush waits below it.
func _show_category(title: String) -> void:
	_category = title
	_rebuild_strip()
	_on_status_changed(editor.status)

func _fit_dock() -> void:
	var screen := get_viewport_rect().size
	var fit := clampf(minf(1.0,minf((screen.y-48)/540.0,(screen.x-48)/880.0)),0.45,1.0)
	_fit_wrapper.scale = Vector2.ONE*fit
	_fit_wrapper.position = (screen-Vector2(880,540)*fit)*0.5
	_launcher.position = Vector2((screen.x-220.0)*0.5,screen.y-72.0)
	_launcher.size = Vector2(220,44)
	if _tool_rail != null: _tool_rail.fit()
	_fit_details.call_deferred()

func _fit_details() -> void:
	if _scroll.get_child_count() == 0: return
	var content: Control = _scroll.get_child(0)
	var screen := get_viewport_rect().size
	var factor: float = _tool_rail.scale.x if _tool_rail != null else 1.0
	var available := maxf(64.0,(screen.y-96.0)/factor)
	var height := clampf(content.get_combined_minimum_size().y+64.0,64.0,available)
	_details.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var rail: Rect2 = _tool_rail.context_rect() if _tool_rail != null else Rect2(20,92,174,320)
	var left := minf(rail.position.x,screen.x-384.0*factor-16.0)
	var width := 384.0
	factor = minf(factor,maxf(0.1,(screen.x-left-16.0)/width))
	_details.scale = Vector2.ONE*factor
	_details.position = Vector2(left,clampf(rail.position.y,48.0,maxf(48.0,screen.y-70.0-height*factor)))
	_details.size = Vector2(width,height)

## Small antialiased vector icons avoid platform-dependent Unicode glyphs.
func _line_icon(kind: String) -> Texture2D:
	var path := ""
	match kind:
		"undo": path = '<path d="M8 5 L3 10 L8 15 M3 10 H13 A6 6 0 0 1 13 22"/>'
		"redo": path = '<path d="M16 5 L21 10 L16 15 M21 10 H11 A6 6 0 0 0 11 22"/>'
		"close": path = '<path d="M6 6 L18 18 M18 6 L6 18"/>'
		"menu": path = '<path d="M5 7 H19 M5 12 H19 M5 17 H19"/>'
		"tune": path = '<path d="M5 7 H19 M5 17 H19"/><circle cx="9" cy="7" r="2.5" fill="#26232b"/><circle cx="15" cy="17" r="2.5" fill="#26232b"/>'
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24"><g fill="none" stroke="#c8c1cc" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round">'+path+'</g></svg>'
	var image := Image.new()
	image.load_svg_from_string(svg)
	return ImageTexture.create_from_image(image)

func _stone_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(0)
	style.border_color = Color(0.85,0.73,0.77,0.16)
	style.set_content_margin_all(12)
	style.shadow_color = Color(0.06,0.04,0.08,0.12)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0,4)
	return style

func _install_theme() -> void:
	var look := Theme.new()
	look.default_font_size = 11
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Inter","Helvetica Neue","Arial"])
	var nunito := FontVariation.new()
	nunito.base_font = load("res://assets/fonts/Nunito.ttf")
	nunito.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):600.0}
	look.default_font = nunito
	_mono = load("res://assets/fonts/IBMPlexMono-Regular.ttf")
	look.set_icon("clear","LineEdit",_line_icon("close"))
	for state: String in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		var color := Color(0.58,0.45,0.52,0.0)
		if state == "hover": color.a = 0.20
		if state in ["pressed","hover_pressed"]: color = Color(0.64,0.58,0.69,0.12)
		var style := _stone_style(color,8)
		style.shadow_size = 0
		style.set_content_margin_all(4)
		style.border_color.a = 0.0
		look.set_stylebox(state,"Button",style)
	look.set_color("font_color","Button",Color("e4d9d5"))
	look.set_color("font_hover_color","Button",Color("fff0e3"))
	look.set_color("font_pressed_color","Button",Color("fff0e3"))
	look.set_color("font_color","Label",Color("e4d9d5"))
	for state: String in ["normal","focus","read_only"]:
		var field := _stone_style(Color(0.55,0.51,0.60,0.08),6)
		field.shadow_size = 0
		field.set_content_margin_all(6)
		look.set_stylebox(state,"LineEdit",field)
	for state: String in ["scroll","grabber","grabber_highlight","grabber_pressed"]:
		var rail := StyleBoxFlat.new()
		rail.bg_color = Color(0.75,0.62,0.68,0.10 if state == "scroll" else 0.38)
		rail.set_corner_radius_all(3)
		rail.content_margin_top = 2
		rail.content_margin_bottom = 2
		look.set_stylebox(state,"HScrollBar",rail)
		var vertical: StyleBoxFlat = rail.duplicate()
		vertical.content_margin_top = 0
		vertical.content_margin_bottom = 0
		vertical.content_margin_left = 1
		vertical.content_margin_right = 1
		look.set_stylebox(state,"VScrollBar",vertical)
	theme = look

## Only the visible slice of the current shelf renders, at 24 Hz. Hidden and
## horizontally clipped thumbnails keep their last texture, without 3D work.
func _animate_portraits(delta: float) -> void:
	if not is_visible_in_tree() or not miniatures_animate:
		return
	_portrait_clock += delta
	if _portrait_clock < 1.0/24.0:
		return
	var step := _portrait_clock
	_portrait_clock = 0.0
	var held: Array = _tool_rail.visible_portraits() if _tool_rail != null else []
	for id: String in _portraits:
		var card_visible := id in held
		var row_visible := _bar.visible and id in _matches
		if not card_visible and not row_visible: continue
		var selected := not _matches.is_empty() and _matches[_focus_index] == id
		if not card_visible and not selected and (not _row_buttons.has(id) or not _row_buttons[id].get_global_rect().intersects(_result_scroll.get_global_rect())): continue
		var portrait: Dictionary = _portraits[id]
		portrait.pivot.rotation.y += step*0.28
		portrait.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

# --- the sky tab -------------------------------------------------------------

## The sky tab only appears where a living scene stands behind the editor.
func _sky_ready() -> bool:
	var scene: Node3D = editor.scene
	return scene != null and scene.get("_celestial") != null and scene.get("_atmosphere") != null and scene.get("_precipitation") != null

## Swatches for the three moods on one row and every weather preset on the next,
## so a whole sky is one click while the tool in hand waits untouched.
func _build_sky_group() -> void:
	if not _sky_ready(): return
	for title: String in preload("res://scripts/scene_look.gd").MOODS:
		var recipe: Array = preload("res://scripts/scene_look.gd").MOODS[title]
		var colors: Dictionary = preload("res://scripts/scene_look.gd").preset_colors(recipe[0])
		_library.add_child(_sky_tile("scene_mood_"+title,title,"Palette, hour and weather",{"top":colors.sky,"bottom":colors.glow,"mark":"sun"},editor.scene.apply_scene_mood.bind(title)))

	for i in range(MOODS.size()):
		var mood: Dictionary = MOODS[i]
		_library.add_child(_sky_tile("mood_%d" % i,mood.title,"A whole sky at once",mood,_apply_mood.bind(i)))
	var names: Array = editor.scene._precipitation.PRESET_NAMES
	for i in range(names.size()):
		var key: String = names[i]
		_library.add_child(_sky_tile("weather_"+key,_title(key),"Weather preset",SKIES.get(key,SKIES.clear),_choose_weather.bind(i)))

func _sky_tile(id: String, title: String, hint: String, look: Dictionary, apply: Callable) -> Button:
	var button := Button.new()
	button.name = "Sky_"+id
	button.toggle_mode = true
	button.button_group = _sky_group
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(SWATCH,SWATCH)
	button.tooltip_text = "%s\n%s" % [title,hint]
	var swatch := SkySwatch.new()
	swatch.top = look.top
	swatch.bottom = look.bottom
	swatch.mark = look.mark
	swatch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(swatch)
	button.add_child(_caption_text(title))
	button.pressed.connect(func() -> void: apply.call(); close_palette())
	button.mouse_entered.connect(func() -> void:
		_scale_tile(button,HOVER_SCALE)
		_on_status_changed("%s · %s" % [title,hint]))
	button.mouse_exited.connect(func() -> void:
		_scale_tile(button,1.0)
		_on_status_changed(editor.status))
	button.button_down.connect(_scale_tile.bind(button,PRESS_SCALE))
	button.button_up.connect(_scale_tile.bind(button,1.0))
	_sky_tiles[id] = button
	return button

func _apply_mood(index: int) -> void:
	editor.scene._apply_mood(index)
	_sync_sky()

func _choose_weather(index: int) -> void:
	editor.scene._precipitation.set_weather(index)
	_sync_sky()

## K folds the sky in and out, leaving the tool it interrupted in hand.
func _on_sky_toggle_requested() -> void:
	if not _sky_ready():
		return
	if _bar.visible and _category == SKY_TAB:
		close_palette()
	else:
		open_palette()
		_browse(SKY_TAB)

## Every dial the scene's own study offers for its light, air and weather.
func _fill_sky_strip() -> void:
	var scene: Node3D = editor.scene
	if not _sky_ready():
		return
	var colors := Button.new()
	colors.text = "Scene colors & atmosphere…"
	colors.pressed.connect(scene.edit_scene_look)
	_actions.add_child(colors)
	var sky: RefCounted = scene._celestial
	var air: Node3D = scene._atmosphere
	var weather: Node3D = scene._precipitation
	# Volumetric mist and the summit cap only exist under Forward+.
	var deep := RenderingServer.get_current_rendering_method() == "forward_plus"
	_sky_row("time","Time of day",0.0,1.0,0.001,
		func() -> float: return sky.phase,
		func(value: float) -> void: sky.set_phase(value))
	_sky_row("clouds","Cloud cover",0.0,1.0,0.01,
		func() -> float: return weather.cloud_override if weather.cloud_override >= 0.0 else sky.cloud,
		func(value: float) -> void: weather.cloud_override = value)
	_sky_row("fog","Mist",0.0,1.0,0.01,
		func() -> float: return air._fog_target,
		func(value: float) -> void: air.set_fog(value),deep)
	_sky_row("wind","Wind",0.0,3.0,0.05,
		func() -> float: return air.strength,
		func(value: float) -> void: scene._set_wind(value))
	_sky_row("haze","Haze",0.0,1.0,0.01,
		func() -> float: return air.haze_amount,
		func(value: float) -> void: air.set_haze(value))
	_sky_row("autumn","Autumn",0.0,1.0,0.01,
		func() -> float: return weather.surface_weather.autumn,
		func(value: float) -> void: weather.surface_weather.target_autumn = value)
	_sky_row("cold","Cold",0.0,1.0,0.01,
		func() -> float: return weather.surface_weather.target_cold,
		func(value: float) -> void: weather.cold_override = value)
	_sky_row("night_fill","Night fill",0.0,1.5,0.05,
		func() -> float: return sky.night_fill,
		func(value: float) -> void:
			sky.night_fill = value
			sky.update_rig())
	_sky_row("summit_mist","Summit mist",0.0,1.5,0.05,
		func() -> float: return air.summit_mist,
		func(value: float) -> void:
			air.summit_mist = value
			air._publish_wind(),deep)
	_sync_sky()

## A slider bound to a pair of callables rather than an editor property, since
## the sky lives in the scene and the editor holds no setting for it.
func _sky_row(key: String, title: String, low: float, high: float, step: float, read: Callable, write: Callable, editable := true) -> Dictionary:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",1)
	box.custom_minimum_size = Vector2(104,0)
	var label := Label.new()
	label.add_theme_font_size_override("font_size",11)
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.editable = editable
	slider.focus_mode = Control.FOCUS_NONE
	box.add_child(label)
	box.add_child(slider)
	var entry := {"box":box,"control":slider,"label":label,"title":title,"read":read,"write":write}
	slider.value_changed.connect(func(value: float) -> void:
		write.call(value)
		_show_sky_value(entry,value))
	slider.set_value_no_signal(float(read.call()))
	_show_sky_value(entry,slider.value)
	_grid.add_child(box)
	_sky_rows[key] = entry
	return entry

func _show_sky_value(entry: Dictionary, value: float) -> void:
	entry.label.text = "%s · %s" % [entry.title,String.num(value,2)]

## The scene keeps changing on its own, so the rows read from it rather than
## remembering what they last wrote, exactly as the study's own sliders do.
func _sync_sky() -> void:
	if not _sky_ready():
		return
	var index: int = editor.scene._precipitation.preset_index
	var names: Array = editor.scene._precipitation.PRESET_NAMES
	for id: String in _sky_tiles:
		var chosen: bool = id == "weather_"+String(names[index])
		_sky_tiles[id].set_pressed_no_signal(chosen)
		_sky_tiles[id].modulate = Color.WHITE if chosen else Color(0.82,0.86,0.83)
	for key: String in _sky_rows:
		var entry: Dictionary = _sky_rows[key]
		var value := float(entry.read.call())
		if is_equal_approx(value,entry.control.value):
			continue
		entry.control.set_value_no_signal(value)
		_show_sky_value(entry,entry.control.value)

# --- thumbnails -------------------------------------------------------------

## Seed each portrait once. Visible tiles subsequently turn in their own small
## transparent viewport; clipped and hidden tiles retain the last rendered pose.
func ensure_thumbnails() -> void:
	if not _thumbs.is_empty():
		return
	for id: String in _tiles:
		if not _portrait(id):
			continue
		var model := build_model(id)
		if model == null:
			continue
		_thumbs[id] = _render(model,id)
		_tiles[id].icon = _thumbs[id]
	var bigfoot_model: Node3D = load("res://assets/models/zenscape-bigfoot-breathing.glb").instantiate()
	_style_bigfoot(bigfoot_model)
	_thumbs["bigfoot"] = _render(bigfoot_model,"bigfoot")
	for id: String in _entries:
		if _thumbs.has(id): continue
		var symbol := ToolGlyph.new()
		symbol.kind = GLYPHS.get(id,"disc")
		if id in ["wind_gust","fog_bank"]: symbol.kind = "wave"
		_thumbs[id] = _render_symbol(symbol)
	if _bar.visible: _refresh_results()
	if _tool_rail != null: _tool_rail.sync()

func _render_symbol(symbol: Control) -> Texture2D:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(ICON,ICON)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	_viewports.append(viewport)
	viewport.add_child(symbol)
	symbol.size = Vector2(ICON,ICON)
	return viewport.get_texture()

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
		"campsite":
			root.add_child(preload("res://scripts/campsite_model.gd").tent())
		"fallen_branch":
			root.add_child(preload("res://scripts/campsite_model.gd").branch())
		"arch":
			_part(root,editor.landmarks._arch_mesh,editor.landmarks._arch_material,Color.WHITE,Transform3D(Basis(),editor.landmarks._arch_offset))
		"bigfoot_tree":
			var tree: Node3D = preload("res://assets/bigfoot/old_tree.glb").instantiate()
			tree.scale *= preload("res://studies/bigfoot_encounter.gd").PEEK_SCALE
			root.add_child(tree)
		"mountain","range":
			var patch := MeshInstance3D.new()
			patch.name = "Landform"
			patch.mesh = _landform_mesh(id)
			patch.material_override = _landform_material()
			root.add_child(patch)
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
		for flag: String in ["terrain_growth","plant_growth","sway_enabled","conifer_sway","wet_ground"]:
			copy.set_shader_parameter(flag,false)
		var base: Variant = copy.get_shader_parameter("base_color")
		copy.set_shader_parameter("base_color",(base if base is Color else Color.WHITE)*tint)
	node.material_override = copy
	root.add_child(node)

## A patch of ground carrying the shape the landscape tool would stamp, at the
## size its settings ask for. Mountain evaluates the very stamp function the
## editor calls; Range evaluates the recipe its Form button installs. The
## thumbnail and the drag ghost are both this mesh, so the tile and the ghost
## show the land the tool is about to make.
func _landform_mesh(id: String) -> ArrayMesh:
	var palette: NativeTerrainPalette = editor.data._palette
	var shape: NativeMountainShape = null
	var recipe: NativeTerrainRecipe = null
	var span := 1.0
	if id == "mountain":
		shape = NativeMountainShape.new(editor.mountain_variation)
	else:
		recipe = NativeTerrainRecipe.new({"kind":"range","height":editor.range_height,
			"width":editor.range_width,"heading":deg_to_rad(editor.range_heading),
			"variation":editor.range_variation})
		span = 14.0 # The chunk the range recipe fills reaches 14 units each way.
	var angle := deg_to_rad(editor.mountain_heading)
	var grid := PackedVector3Array()
	for iz in range(LANDFORM_CELLS+1):
		for ix in range(LANDFORM_CELLS+1):
			var unit := Vector2(lerpf(-1.0,1.0,float(ix)/LANDFORM_CELLS),lerpf(-1.0,1.0,float(iz)/LANDFORM_CELLS))
			var flat := unit*span
			var height := 0.0
			if shape != null:
				# The stamp reads its shape in a frame rotated by the heading,
				# exactly as NativeTerrainData.mountain does.
				height = editor.mountain_peak*shape.height(unit)
				flat = (unit*editor.mountain_radius).rotated(angle)
			else:
				height = recipe.height(flat.x,flat.y)
			grid.append(Vector3(flat.x,height,flat.y))
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for iz in range(LANDFORM_CELLS):
		for ix in range(LANDFORM_CELLS):
			var corner := iz*(LANDFORM_CELLS+1)+ix
			var a := grid[corner]
			var b := grid[corner+1]
			var c := grid[corner+LANDFORM_CELLS+1]
			var d := grid[corner+LANDFORM_CELLS+2]
			if shape != null and maxf(maxf(a.y,b.y),maxf(c.y,d.y)) < LANDFORM_FLOOR:
				continue
			for triangle: Array in [[a,b,c],[b,d,c]]:
				var normal: Vector3 = (triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).normalized()
				if normal.y < 0.0:
					normal = -normal
				var center: Vector3 = (triangle[0]+triangle[1]+triangle[2])/3.0
				var color := _landform_color(palette,center,normal)
				for point: Vector3 in triangle:
					vertices.append(point)
					normals.append(normal)
					colors.append(color)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

## The bands build_mesh paints on an uncovered chunk: bare ground, rock where
## the slope or the height calls for it, snow on the gentle alpine faces.
func _landform_color(palette: NativeTerrainPalette, center: Vector3, normal: Vector3) -> Color:
	var color: Color = editor.data._ground_tint
	var slope := sqrt(maxf(0.0,1.0-normal.y*normal.y))/maxf(normal.y,0.001)
	if center.y > palette.snowline-1.8 or slope > palette.rock_slope:
		color = palette.rock_at_coordinates(center.x,center.z)
	if center.y > palette.snowline and slope < 2.4:
		color = palette.shimmer_coordinates(palette.snow,center.x,center.z)
	return color

## Vertex colours arrive from the palette already linear, which is the space a
## standard material reads them in when it is not told they are sRGB.
func _landform_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	return material

func _render(model: Node3D, id: String) -> Texture2D:
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
	var pivot := Node3D.new()
	viewport.add_child(pivot)
	pivot.position = center
	model.reparent(pivot)
	var radius := maxf(bounds.size.length()*0.5,0.05)
	var camera := Camera3D.new()
	camera.fov = 32.0
	camera.near = 0.01
	camera.far = radius*20.0+50.0
	viewport.add_child(camera)
	var away := Vector3(0.62,0.46,1.0).normalized()*(radius/tan(deg_to_rad(camera.fov*0.5))*1.06)
	camera.look_at_from_position(center+away,center,Vector3.UP)
	_portraits[id] = {"viewport":viewport,"pivot":pivot}
	return viewport.get_texture()

# --- selection and feel -----------------------------------------------------

func _choose(id: String) -> void:
	var button: Button = _tiles[id]
	if button.get_meta("piece") != "":
		editor.catalog_asset = button.get_meta("piece")
	editor.select_tool(button.get_meta("tool"))
	close_palette()
	if id == "range":
		_details.visible = true
	elif id == "ground": _details.visible = true
	elif id != "select": _start_placing(id)

func _start_placing(id: String) -> void:
	if id == "wind_gust" and editor.scene.has_method("activate_gust_tool"):
		editor.scene.activate_gust_tool()
		return
	_hand.take()
	_placing = id
	_launcher.visible = false
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	if _tool_rail != null: _tool_rail.sync()

func _finish_placing(placed := false) -> void:
	_hand.release(placed)
	_placing = ""
	_launcher.visible = false
	editor.finish_stroke()
	editor.select_tool("select")
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _style_bigfoot(model: Node3D) -> void:
	var coat := StandardMaterial3D.new()
	coat.vertex_color_use_as_albedo = true
	coat.roughness = 0.9
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if "_n7_" not in mesh.name and "_n8_" not in mesh.name: mesh.material_override = coat

func _take_special(id: String) -> void:
	if id in ["bigfoot","wind_gust"]: editor.select_tool("select")
	close_palette()
	match id:
		"fireflies": editor.scene._fireflies.called = true
		"fog_bank": editor.scene._atmosphere.set_fog(0.65)
		_: _start_placing(id)

func _place_special(point: Vector2) -> bool:
	var hit: Variant = editor.pick(point)
	if hit == null: return false
	var world: Vector3 = editor.terrain.to_global(hit)
	if _placing == "wind_gust":
		if editor.scene.has_method("send_scene_gust"): editor.scene.send_scene_gust(world)
		else: editor.scene._atmosphere.send_gust(world)
	elif _placing == "bigfoot":
		if editor.scene.has_method("invite_bigfoot"):
			return editor.scene.invite_bigfoot(world)
		if not is_instance_valid(_inhabitant):
			_inhabitant = CreatureActor.new()
			editor.scene.add_child(_inhabitant)
			_inhabitant.setup("res://assets/models/zenscape-bigfoot-breathing.glb")
			_style_bigfoot(_inhabitant.actor)
		_inhabitant.reset_at(world)
	return true

func _scale_tile(button: Button, factor: float) -> void:
	if not is_instance_valid(button):
		return
	button.pivot_offset = button.size*0.5
	if button.has_meta("hover_tween"):
		button.get_meta("hover_tween").kill()
	var tween := create_tween()
	button.set_meta("hover_tween",tween)
	tween.tween_property(button,"scale",Vector2.ONE*factor,TWEEN_TIME).set_trans(Tween.TRANS_SINE)

func _on_tile_hover(id: String, entered: bool) -> void:
	_scale_tile(_tiles[id],HOVER_SCALE if entered else 1.0)
	if not entered:
		_on_status_changed(editor.status)
		return
	var tool: String = _tiles[id].get_meta("tool")
	_on_status_changed("%s · %s" % [_title(id),editor.TOOL_TEXT.get(tool,"")])

func _on_tool_changed(tool: String) -> void:
	if not _placing.is_empty() and (not _tiles.has(_placing) or _tiles[_placing].get_meta("tool") != tool):
		_placing = ""
		_launcher.visible = false
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	var chosen := tile_for(tool)
	for id: String in _tiles:
		_tiles[id].set_pressed_no_signal(_tiles[id] == chosen)
		_tiles[id].modulate = Color.WHITE
	_show_category(_category_of(tool))
	if tool == "select": _details.hide()
	if _tool_rail != null: _tool_rail.sync()

func _on_setting_changed(property: String, value: float) -> void:
	if not _strip_rows.has(property):
		return
	_strip_rows[property].control.set_value_no_signal(value)
	NativeSettingRow.show_value(_strip_rows[property],value)

func _on_status_changed(text: String) -> void:
	_hint.text = "Sky & atmosphere" if _category == SKY_TAB else _title(editor.catalog_asset if editor.mode == "assets" else editor.mode)
	_hint.tooltip_text = text
	_launcher.text = ("⌘K" if OS.get_name() == "macOS" else "Ctrl K")+"    place something"

func _on_active_changed(enabled: bool) -> void:
	visible = enabled
	if enabled:
		ensure_thumbnails()
	else:
		_cancel_drag()

## The tool's sliders, actions and colors live in the expandable Tune panel.
func _rebuild_strip() -> void:
	_grid.columns = 2
	_details_title.text = "Sky settings" if _category == SKY_TAB else _title(editor.catalog_asset if editor.mode == "assets" else editor.mode)+" settings"
	_setting_page = 0
	_paginate_settings.call_deferred()
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	_strip_rows.clear()
	_sky_rows.clear()
	if _category == SKY_TAB:
		_fill_sky_strip()
		return
	for spec: Dictionary in editor.settings_for(editor.mode):
		var entry := NativeSettingRow.build(editor,spec.property,true)
		entry.box.custom_minimum_size = Vector2(104,0)
		entry.box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.label.clip_text = true
		if entry.control is HSlider: TactileStyle.slider(entry.control)
		_grid.add_child(entry.box)
		_strip_rows[spec.property] = entry
	_grid.columns = mini(2,maxi(1,_strip_rows.size()))
	for action: Dictionary in editor.actions_for(editor.mode):
		var button := Button.new()
		button.name = action.name
		button.text = action.title
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size",11)
		button.pressed.connect(editor.perform_action.bind(action.method))
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
	var button: Button = _tiles[id]
	if button.get_meta("piece") != "": editor.catalog_asset = button.get_meta("piece")
	editor.select_tool(button.get_meta("tool"))
	if not _draggable(id):
		return
	_drag_id = id
	_pressed = true
	_press_at = event.global_position

func _input(event: InputEvent) -> void:
	if editor.scene.has_method("handle_resident_input") and editor.scene.handle_resident_input(event): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		editor.finish_stroke()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K and (event.ctrl_pressed or event.meta_pressed):
		if not editor.active: editor.set_active(true)
		editor.scene._ui.visible = true
		if _bar.visible: close_palette()
		else: open_palette()
		get_viewport().set_input_as_handled()
		return
	if not is_visible_in_tree(): return
	if _dragging and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_drag()
		_finish_placing(false)
		get_viewport().set_input_as_handled()
		return
	if not _bar.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and editor.mode != "select":
		_finish_placing()
		get_viewport().set_input_as_handled()
		return
	if not _placing.is_empty() and not _bar.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_finish_placing()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not _bar.visible and editor.pointer_in_world(event.position):
			var placed := _place_special(event.position) if _placing in ["bigfoot","wind_gust"] else editor.place_at(event.position)
			if placed:
				_hand.release(true)
				if _placing in ["bigfoot","wind_gust"]: _finish_placing(true)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if _bar.visible and event.keycode == KEY_ESCAPE:
			close_palette()
			get_viewport().set_input_as_handled()
			return
		if _bar.visible and event.keycode in [KEY_UP,KEY_DOWN]:
			_focus_index = posmod(_focus_index+(-1 if event.keycode == KEY_UP else 1),maxi(1,_matches.size()))
			_mark_result()
			get_viewport().set_input_as_handled()
			return
		if _bar.visible and event.keycode == KEY_TAB:
			if not _matches.is_empty():
				var group: String = _entries[_matches[_focus_index]].group
				for offset in range(1,_matches.size()+1):
					var index := posmod(_focus_index+offset,_matches.size())
					if _entries[_matches[index]].group != group or index == 0:
						_focus_index = index
						break
				_mark_result()
			get_viewport().set_input_as_handled()
			return
		if _bar.visible and event.keycode in [KEY_PAGEUP,KEY_PAGEDOWN]:
			_turn_page(-1 if event.keycode == KEY_PAGEUP else 1)
			get_viewport().set_input_as_handled()
			return
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
	close_palette()
	_dragging = true
	_bob = 0.0
	_cursor.texture = _thumbs.get(_drag_id)
	_cursor.scale = Vector2.ONE
	_cursor.visible = false
	_clear_ghost()
	var model := build_model(_drag_id)
	if model == null:
		return
	_ghost = Node3D.new()
	_ghost.name = "PaletteGhost"
	_ghost.add_child(model)
	_ghost.visible = false
	editor.content.add_child(_ghost)
	_haunt(_ghost)

## Turn a freshly built model into its own ghost. Every surface keeps the
## material it was going to render with, so a tree's trunk and canopy stay two
## different things; the copy is what turns translucent, never the original.
func _haunt(model: Node3D) -> void:
	for node: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var whole: Material = node.material_override
		node.material_override = null
		if node.mesh == null:
			continue
		for surface in range(node.mesh.get_surface_count()):
			var source: Material = whole
			if source == null:
				source = node.get_surface_override_material(surface)
			if source == null:
				source = node.mesh.surface_get_material(surface)
			node.set_surface_override_material(surface,_ghost_material(source))

## The real look, made translucent: the surface's own material where that can
## carry alpha, and a standard stand-in tinted with the shader's base colour
## where it cannot. Shading stays on so the form still reads, shadows go off,
## and the ghost writes no depth, so it neither fights the terrain nor cuts a
## hole in itself while the terrain in front of it still hides it.
func _ghost_material(source: Material) -> StandardMaterial3D:
	var material: StandardMaterial3D
	var colour := Color(0.86,0.96,0.88)
	if source is StandardMaterial3D:
		material = source.duplicate() as StandardMaterial3D
		colour = material.albedo_color
	else:
		material = StandardMaterial3D.new()
		if source is ShaderMaterial:
			var base: Variant = source.get_shader_parameter("base_color")
			if base is Color:
				# Shader base colours are linear; a standard material's is not.
				colour = (base as Color).linear_to_srgb()
		elif source is BaseMaterial3D:
			colour = (source as BaseMaterial3D).albedo_color
		material.roughness = 0.85
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# It must write depth: the display fog composite reads scene depth after
	# the transparent pass and fogs anything without depth as open sky, which
	# under the Balanced preset (no ambient-occlusion prepass) erased the
	# ghost entirely. Nearer faces winning over farther ones also keeps the
	# translucent form from doubling up where it overlaps itself.
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	material.no_depth_test = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(colour.r,colour.g,colour.b,GHOST_ALPHA)
	# A cool glow and a lit rim keep it reading as a promise, not a placement.
	material.emission_enabled = true
	material.emission = Color(0.58,0.86,0.72)
	material.emission_energy_multiplier = 0.32
	material.rim_enabled = true
	material.rim = 0.85
	material.rim_tint = 0.25
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
	if _landform(_drag_id):
		# A landform has no pose to decode and no reason to float: it is the
		# ground, sat a hair above the terrain so the two never fight.
		_ghost_ground = hit.y+LANDFORM_LIFT
		_ghost.transform = Transform3D(Basis.IDENTITY,Vector3(hit.x,_ghost_ground,hit.z))
		_ghost.visible = true
		return true
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
	if placed:
		editor.finish_stroke()
		_start_placing(_drag_id)
		_hand.release(true)
	else: _finish_placing(false)
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
	_animate_portraits(delta)
	var pointer := get_global_mouse_position()
	var world_hover := is_visible_in_tree() and editor.active and get_window().has_focus() and get_viewport_rect().has_point(pointer) and not _bar.visible and editor.pointer_in_world(pointer)
	if editor.scene.get("_resident_play") != null and editor.scene._resident_play.owns_pointer(): world_hover = false
	if world_hover and Input.mouse_mode in [Input.MOUSE_MODE_VISIBLE,Input.MOUSE_MODE_HIDDEN]:
		_hand.show_at(pointer,not _placing.is_empty() or _dragging or editor._selection_drag,delta)
	else:
		_hand.hide_pointer()
	if editor != null:
		_hud_count.text = "meadow-01 · %d objects" % (editor.data.objects.size()+(1 if is_instance_valid(_inhabitant) else 0))
		if editor.scene.has_method("capture_diorama_state"):
			_hud_count.text = "a little world of your own"
		_launcher.modulate.a = 1.0 if _launcher.is_hovered() else 0.775+0.225*sin(Time.get_ticks_msec()*TAU/4000.0)
	if _category == SKY_TAB and not _sky_rows.is_empty() and is_visible_in_tree():
		_sync_sky()
	if not _dragging or _ghost == null or not _ghost.visible or _landform(_drag_id):
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
		var span := minf(size.x,size.y)*0.19
		var color := Color("bdb7c4")
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

## A little sky: the gradient a mood or a weather preset settles into, with the
## one mark that tells rain from snow at swatch size.
class SkySwatch:
	extends Control
	var top := Color("2f7bc0")
	var bottom := Color("9fd0ea")
	var mark := "sun"

	func _draw() -> void:
		var height := size.y-16.0
		var bands := 14
		for i in range(bands):
			var band := Rect2(3.0,3.0+height*float(i)/float(bands),size.x-6.0,height/float(bands)+1.0)
			draw_rect(band,top.lerp(bottom,float(i)/float(bands-1)))
		var middle := Vector2(size.x*0.5,3.0+height*0.42)
		var span := minf(size.x,height)*0.2
		var ink := Color(1,1,1,0.86) if bottom.get_luminance() < 0.6 else Color(0.16,0.19,0.22,0.8)
		match mark:
			"sun":
				draw_circle(middle,span,ink)
			"moon":
				draw_circle(middle,span,ink)
				draw_circle(middle+Vector2(span*0.5,-span*0.42),span*0.94,top.lerp(bottom,0.42))
			"rain":
				for i in range(3):
					var head := middle+Vector2((float(i)-1.0)*span*0.9,-span*0.7)
					draw_line(head,head+Vector2(-span*0.34,span*1.3),ink,2.0)
			"bolt":
				draw_colored_polygon(PackedVector2Array([
					middle+Vector2(span*0.2,-span*1.2),
					middle+Vector2(-span*0.8,span*0.15),
					middle+Vector2(-span*0.1,span*0.15),
					middle+Vector2(-span*0.5,span*1.2),
					middle+Vector2(span*0.8,-span*0.2),
					middle+Vector2(span*0.05,-span*0.2)]),ink)
			"flake":
				for i in range(3):
					var arm := Vector2(cos(PI*float(i)/3.0),sin(PI*float(i)/3.0))*span
					draw_line(middle-arm,middle+arm,ink,2.0)
			"cloud":
				draw_circle(middle+Vector2(-span*0.6,0),span*0.7,ink)
				draw_circle(middle+Vector2(span*0.6,0),span*0.6,ink)
				draw_circle(middle+Vector2(0,-span*0.35),span*0.85,ink)
			"lines":
				for i in range(3):
					var y := middle.y+(float(i)-1.0)*span*0.8
					draw_line(Vector2(middle.x-span*1.2,y),Vector2(middle.x+span*1.2,y),ink,2.0)
			"leaf":
				draw_colored_polygon(PackedVector2Array([
					middle+Vector2(0,-span*1.1),
					middle+Vector2(span*0.9,0),
					middle+Vector2(0,span*1.1),
					middle+Vector2(-span*0.9,0)]),ink)
