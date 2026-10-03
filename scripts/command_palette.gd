extends Control
## The command palette (design "ZenScape Command Palette", Claude Design
## project a0f03cdb, `ZenScapePalette.dc.html`, frame 1a "Classic · centred",
## shadow skin): reach for anything by name. Same linen as the tool roll.
## Type to search, Up and Down to move, Tab to change pocket, Enter to take it
## in hand, Esc to put the palette away. Cmd/Ctrl K or / opens it.
##
## Pockets: Seeds (the case's seeds and those with no slot in it: birch,
## redwood, juniper, Joshua), Tools (the roll), Elements (water, stone, and the
## undiscovered quartz and frost), Life (calls a creature now, whatever its
## chance or hour: scripts/land_life.gd `summon`), Moods (every mood_look mood
## and This world) and World (undo, redo, turning the view, the overview, the
## day held, saving and photographing).
##
## Nothing is decided here: taking a thing is hand_materials' (`take`,
## `select_tool`, `take_feather`), a mood is mood_look's `choose`, and the
## world's verbs are the owners' own. While open the palette is modal: it
## takes every key and press in `_input`, ahead of the hand (it sits under it
## in the tree), and a press outside it puts it away.

signal closed

const Linen = preload("res://scripts/hud_linen.gd")
const Icons = preload("res://scripts/hud_icons.gd")
const Mood = preload("res://scripts/mood_look.gd")
const Tray = preload("res://scripts/materials_tray.gd")
const Roll = preload("res://scripts/tool_roll.gd")
const ClaySound = preload("res://scripts/clay_sound.gd")
const SPECTRAL = preload("res://assets/fonts/spectral-latin-400.woff2")

# --- Tokens (the design's "shadow" skin) --------------------------------------------

const CLOTH := Color(0.384,0.345,0.290,0.9)
const SCRIM := Color(0.078,0.071,0.102,0.35)
const T1 := Color("f4ead4")
const T2 := Color("c2b8a3")
const ACC := Color("e3d7bd")
const KEY := Color(0.890,0.843,0.741,0.45)
const WELL := Color(0.078,0.055,0.031,0.2)
const WELL_SHADE := Color(0.039,0.031,0.016,0.32)
const WELL_STITCH := Color(0.890,0.843,0.741,0.22)
const RULE := Color(0.890,0.843,0.741,0.32)
const TAB_BG := Color(0.078,0.055,0.031,0.14)
const TAB_LINE := Color(0.890,0.843,0.741,0.7)
const ON_STITCH := Color(0.890,0.843,0.741,0.45)
const GLYPH_BG := Color(0.078,0.055,0.031,0.12)
const GLYPH_STITCH := Color(0.890,0.843,0.741,0.5)

# --- Geometry, design pixels --------------------------------------------------------

const WIDTH := 640.0
const TOP := 96.0
const RADIUS := 14.0
const HEM := Vector2(6.0,10.0)
const PAD := 18.0
const SEARCH_H := 56.0
const TAB_H := 36.0
const RULES_H := 8.0
const LIST_MAX := 372.0
const GROUP_H := 30.0
const ROW_H := 54.0
const ICON_BOX := 40.0
const ICON := 34.0
const HINTS_H := 44.0
## Faked small caps, as the HUD sets them: capitals at CAPS of the type size.
const CAPS := 10.0/13.0
const NAME_TYPE := 17.0
const NAME_TRACK := 0.16
const SUB_TYPE := 14.0
const GROUP_TYPE := 13.0
const GROUP_TRACK := 0.24
const TAB_TYPE := 15.0
const TAB_TRACK := 0.2
const QUERY_TYPE := 20.0
const KEY_TYPE := 12.0
const OPEN_TIME := 0.18
const WHEEL_STEP := 40.0
## Seconds a refusal's line stays on the hint line.
const NOTICE_SECONDS := 3.0

const TABS := ["All","Seeds","Tools","Elements","Life","Moods","World"]
const TAB_ICONS := ["all","oak","hand","water","track","sun","globe"]

## Seeds in the order the palette lists them: the case's, then the ones with
## no slot in it. [id, name, sub, description].
const SEEDS := [
	["oak","Acorn","Oak","Plants an oak. Slow to rise, long to stay."],
	["pine","Cone","Pine","Plants a pine. They climb toward high ground."],
	["willow","Sprig","Willow","A willow, happiest near water."],
	["birch","Samara","Birch","A birch, pale and quick to come up."],
	["redwood","Redwood","Giant","A redwood. The tallest thing on the land."],
	["juniper","Juniper","Berry","A juniper, low and blue, for dry slopes."],
	["joshua","Joshua","Desert","A Joshua tree, wherever you set it."],
	["wildflower","Wildflower","Meadow","Daisy, buttercup and poppy seed. The wind sows it in drifts."],
	["dandelion","Clock","Dandelion","Dandelions and their clocks. The wind carries it on."],
	["poppy","Poppy","Field","Red poppies in drifts, where the wind sets them down."],
	["cosmos","Cosmos","Drift","Tall pink and white cosmos, a drift of one colour."],
	["sunflower","Sunflower","Stand","Sunflowers in a stand, their faces to the sun."],
	["reed","Reed","Cattail","Cattails for the shallows."],
]
const TOOLS := [
	["hand","Modeller","Mould","Push and pull soft ground into shape."],
	["hills","Hills","Roll","Drag across the land to raise rolling hills."],
	["mountain","Mountain","Peak","Press and drag up to pull a mountain; drag sideways too for a range."],
	["paddle","Paddle","Smooth","Plane levels ground and lays grass, earth, rock or sand; Pat flattens bumps."],
	["chisel","Chisel","Cut","Crisp rock: faces, cliffs, terraces."],
	["wire","Ravine","Carve","Draw a line and a ravine is carved along it; draw a loop for a lake basin."],
	["hammer","Hammer","Break","Cracks rock and sheds scree."],
	["feather","Feather","Gust","Wind in hand."],
	["can","Watering can","Pour","Pours or sprinkles water. Hold still up high for a spring."],
	["brush","Brush","Paint","Paints grass, rock, bare earth or any colour onto the ground. Shift wipes."],
]
const ELEMENTS := [
	["water","Water","Scoop","Scoops a ball of water out of a pond, fish and all."],
	["stone","River stone","Place","Sets a stone, or scatters pebbles."],
	["crystal","Crystal","Quartz","Quartz breaks through the rock."],
	["snow","Frost","Winter","Brings winter to the whole chunk."],
]
## Life: [summon kind (land_life SUMMONS), name, sub, icon (hud_icons.gd), description].
const LIFE := [
	["deer","Deer","At the wood's edge","deer","Deer step out of the trees to graze."],
	["heron","Heron","Wading","heron","A heron comes down to fish the shallows."],
	["snake","Snake","By the pond","snake","A snake comes to the pond's bank."],
	["bigfoot_watch","Bigfoot","Watching","bigfoot","He steps out of the trees and looks back at you."],
	["bigfoot_stride","Bigfoot","Striding past","bigfoot_stride","He crosses the open ground, unhurried."],
	["bigfoot_tracks","Bigfoot's tracks","A sign","track","A line of big bare footprints."],
	["bigfoot_howl","Bigfoot's howl","A sign","howl","Something calls from far off."],
	["woodpecker","Woodpecker","On a snag","woodpecker","A woodpecker drums on dead wood."],
	["geese","Geese","Passing over","geese","A skein of geese crosses the sky."],
	["rainbow","Rainbow","After rain","rainbow","A bow over the land."],
]
## World: [id, name, sub, glyph, keys].
const WORLD := [
	["undo","Undo","Take back the last change","U",["⌘","Z"]],
	["redo","Redo","Put it back","R",["⇧","⌘","Z"]],
	["turn_left","Turn the chunk","A quarter to the left","T",[]],
	["turn_right","Turn the chunk","A quarter to the right","T",[]],
	["overview","Settle the view","See the whole chunk","V",["R"]],
	["still","Still time","Hold the day, or let it run","S",[]],
	["save","Keep this island","Save","K",["⌘","S"]],
	["photo","Photograph","Frame and capture","F",["P"]],
]

var scene: Node
var materials: Node
var query := ""
var tab := 0
var sel := 0
var scroll := 0.0
var shown := 0.0
var ui_scale := 1.0
## Names taken lately, newest first (the "Lately in hand" group).
var recent: Array[String] = []
## The last thing taken (`kind:id`), and the last refusal line, for probes.
var last_taken := ""
var last_refusal := ""
var pointer_override: Variant = null

var _want := false
var _items: Array[Dictionary] = []
## The list as drawn: [{kind: "group"|"row", y, h, item}], design px from the
## list's top; and the rows alone, in selection order.
var _lines: Array[Dictionary] = []
var _rows: Array[Dictionary] = []
var _list_h := 0.0
var _keep_in_view := false
var _icons := {}
var _icon_px := 0.0
var _tab_rects: Array[Rect2] = []
var _cloth: Linen.Cloth
var _scrim: ColorRect
var _body: Control
var _caps_font: FontVariation
var _text_font: FontVariation
var _notice_left := 0.0

func _ready() -> void:
	name = "CommandPalette"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_caps_font = Linen.tag_font()
	_text_font = FontVariation.new()
	_text_font.base_font = SPECTRAL
	_scrim = ColorRect.new()
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.color = SCRIM
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_scrim)
	_cloth = Linen.Cloth.new()
	_cloth.material_ref.set_shader_parameter("cloth",CLOTH)
	add_child(_cloth)
	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.clip_contents = true
	_body.draw.connect(_draw_body)
	add_child(_body)
	modulate.a = 0.0
	visible = false

## `hand_materials` (scripts/hand_materials.gd) holds the tray, the roll, the
## foot and the pages; its scene holds mood_look, land_life and camera_rig.
func setup(owner_scene: Node, hand_materials: Node) -> void:
	scene = owner_scene
	materials = hand_materials
	_build_items()

# --- API --------------------------------------------------------------------------

func open() -> void:
	if _want: return
	_want = true
	visible = true
	query = ""
	tab = 0
	sel = 0
	scroll = 0.0
	_refresh()
	ClaySound.cue(&"ui_page")

func close() -> void:
	if not _want: return
	_want = false
	closed.emit()

func toggle() -> void:
	if _want: close()
	else: open()

func is_open() -> bool:
	return _want

## The panel in viewport pixels.
func panel_rect() -> Rect2:
	var screen := get_viewport_rect().size
	var width := minf(WIDTH,screen.x/ui_scale-32.0)*ui_scale
	var height := (PAD+SEARCH_H+12.0+TAB_H+RULES_H+minf(_list_h,LIST_MAX)+6.0+RULES_H+HINTS_H)*ui_scale
	var slide := (1.0-Linen.eased(shown))*8.0*ui_scale
	return Rect2(Vector2(roundf((screen.x-width)*0.5),roundf(TOP*ui_scale-slide)),Vector2(roundf(width),roundf(height)))

func contains_pointer(point: Vector2) -> bool:
	return _want and panel_rect().has_point(point)

## The rows now listed, as [kind, id] pairs, for probes.
func listed() -> Array:
	return _rows.map(func(line: Dictionary) -> Array: return [line.item.kind,line.item.id])

## Types `text` into the search, for probes.
func type_text(text: String) -> void:
	query += text
	sel = 0
	scroll = 0.0
	_refresh()

# --- Items ------------------------------------------------------------------------

func _build_items() -> void:
	_items.clear()
	for entry: Array in SEEDS:
		_items.append({"kind":"seed","cat":1,"id":entry[0],"name":entry[1],"sub":entry[2],"desc":entry[3],"icon":entry[0]})
	for entry: Array in TOOLS:
		_items.append({"kind":"tool","cat":2,"id":entry[0],"name":entry[1],"sub":entry[2],"desc":entry[3],"icon":entry[0]})
	for entry: Array in ELEMENTS:
		_items.append({"kind":"element","cat":3,"id":entry[0],"name":entry[1],"sub":entry[2],"desc":entry[3],"icon":entry[0]})
	for entry: Array in LIFE:
		_items.append({"kind":"life","cat":4,"id":entry[0],"name":entry[1],"sub":entry[2],"icon":entry[3],"desc":entry[4]})
	_items.append({"kind":"mood","cat":5,"id":"","name":"This world","sub":Mood.mood_description(""),"desc":""})
	for id: String in Mood.mood_ids():
		_items.append({"kind":"mood","cat":5,"id":id,"name":Mood.mood_title(id),"sub":Mood.mood_description(id),"desc":""})
	for entry: Array in WORLD:
		_items.append({"kind":"world","cat":6,"id":entry[0],"name":entry[1],"sub":entry[2],"glyph":entry[3],"keys":entry[4],"desc":""})

## True when `item` cannot be taken yet: an undiscovered tool, or a case slot
## not found yet.
func _locked(item: Dictionary) -> bool:
	match str(item.kind):
		"tool": return materials != null and materials.roll != null and not materials.roll.discovered(item.id)
		"element", "seed":
			for entry: Dictionary in Tray.SPECIMENS:
				if entry.id == item.id: return bool(entry.get("hidden",false))
	return false

func _key_of(item: Dictionary) -> String:
	return str(item.kind)+":"+str(item.id)

func _find(key: String) -> Dictionary:
	for item: Dictionary in _items:
		if _key_of(item) == key: return item
	return {}

## Rebuilds the groups and rows for the query and pocket.
func _refresh() -> void:
	var q := query.strip_edges().to_lower()
	var hits: Array[Dictionary] = []
	for item: Dictionary in _items:
		if q.is_empty() or (str(item.name)+" "+str(item.sub)+" "+str(TABS[item.cat])).to_lower().contains(q): hits.append(item)
	var groups := []
	if tab == 0:
		if q.is_empty() and not recent.is_empty():
			var lately := []
			for key: String in recent:
				var item := _find(key)
				if not item.is_empty(): lately.append(item)
			groups.append(["Lately in hand",lately])
		for c in range(1,TABS.size()):
			var its := hits.filter(func(it: Dictionary) -> bool: return it.cat == c)
			if not its.is_empty(): groups.append([TABS[c],its])
	else:
		var its := hits.filter(func(it: Dictionary) -> bool: return it.cat == tab)
		if not its.is_empty(): groups.append([TABS[tab],its])
	_lines.clear()
	_rows.clear()
	var y := 6.0
	for group: Array in groups:
		if tab == 0:
			_lines.append({"kind":"group","y":y,"h":GROUP_H,"title":group[0]})
			y += GROUP_H
		for item: Dictionary in group[1]:
			var line := {"kind":"row","y":y,"h":ROW_H,"item":item,"index":_rows.size()}
			_lines.append(line)
			_rows.append(line)
			y += ROW_H+2.0
	_list_h = maxf(y+10.0,96.0)
	sel = clampi(sel,0,maxi(0,_rows.size()-1))

# --- Frames -----------------------------------------------------------------------

func _process(delta: float) -> void:
	delta = minf(delta,0.05)
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0 and materials != null and materials.reach != null and materials.reach._hint == last_refusal:
			materials.reach._show_hint("")
	var scale_now := Linen.scale_for(get_viewport_rect().size)
	if not is_equal_approx(scale_now,ui_scale):
		ui_scale = scale_now
		_icons.clear()
	shown = move_toward(shown,1.0 if _want else 0.0,delta/OPEN_TIME)
	visible = shown > 0.0
	if not visible: return
	modulate.a = Linen.eased(shown)
	var icon_px := ICON*ui_scale
	if _icons.is_empty() or not is_equal_approx(icon_px,_icon_px):
		_icon_px = icon_px
		var ids := TAB_ICONS.duplicate()
		for item: Dictionary in _items:
			if item.has("icon") and not item.icon in ids: ids.append(item.icon)
		Linen.rasterise(_icons,ids,icon_px)
	var rect := panel_rect()
	_cloth.place(rect,ui_scale,RADIUS,HEM)
	_body.position = rect.position
	_body.size = rect.size
	var list := _list_rect()
	scroll = clampf(scroll,0.0,maxf(0.0,_list_h-list.size.y/ui_scale))
	if _keep_in_view and not _rows.is_empty():
		_keep_in_view = false
		var line: Dictionary = _rows[sel]
		var view := list.size.y/ui_scale
		if float(line.y) < scroll+8.0: scroll = maxf(0.0,float(line.y)-(GROUP_H if sel == 0 or tab == 0 else 6.0))
		elif float(line.y)+float(line.h) > scroll+view-8.0: scroll = float(line.y)+float(line.h)-view+12.0
	_body.queue_redraw()

## The list's box in the body's pixels.
func _list_rect() -> Rect2:
	var top := (PAD+SEARCH_H+12.0+TAB_H+RULES_H)*ui_scale
	return Rect2(Vector2(PAD*ui_scale,top),Vector2(_body.size.x-PAD*ui_scale*2.0+6.0*ui_scale,minf(_list_h,LIST_MAX)*ui_scale))

# --- Drawing ----------------------------------------------------------------------

func _draw_body() -> void:
	var px := ui_scale
	var line := maxf(1.0,roundf(px))
	var width := _body.size.x
	# The search well.
	var well := Rect2(Vector2(PAD,PAD)*px,Vector2(width-PAD*2.0*px,SEARCH_H*px))
	_patch(well,10.0,WELL,WELL_SHADE)
	Linen.dashed_round(_body,well.grow(-3.0*px),8.0*px,WELL_STITCH,line,px)
	var lens := Vector2(well.position.x+16.0*px+10.5*px*22.0/24.0,well.get_center().y-1.5*px)
	_body.draw_arc(lens,6.0*px*22.0/24.0,0.0,TAU,24,ACC,1.8*px*22.0/24.0,true)
	_body.draw_line(lens+Vector2(4.2,4.2)*px,lens+Vector2(8.6,8.6)*px,ACC,1.8*px,true)
	var text_x := well.position.x+(16.0+22.0+12.0)*px
	var baseline := well.get_center().y+7.0*px
	var size := roundi(QUERY_TYPE*px)
	if query.is_empty():
		_body.draw_string(_text_font,Vector2(text_x,baseline),"Reach for something…",HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color("b3a891"))
		_body.draw_line(Vector2(text_x,baseline-15.0*px),Vector2(text_x,baseline+4.0*px),Color(T1,0.5+0.5*sin(Time.get_ticks_msec()*0.006)),line)
	else:
		_body.draw_string(_text_font,Vector2(text_x,baseline),query,HORIZONTAL_ALIGNMENT_LEFT,-1,size,T1)
		var caret := text_x+_text_font.get_string_size(query,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x+2.0*px
		_body.draw_line(Vector2(caret,baseline-15.0*px),Vector2(caret,baseline+4.0*px),Color(T1,0.5+0.5*sin(Time.get_ticks_msec()*0.006)),line)
	_key_chip(["esc"],Vector2(well.end.x-16.0*px,well.get_center().y),line)
	# The pockets.
	_draw_tabs(Vector2(14.0*px,(PAD+SEARCH_H+12.0)*px),line)
	var rules_y := (PAD+SEARCH_H+12.0+TAB_H)*px
	_double_rule(rules_y,line)
	# The list.
	var list := _list_rect()
	for entry: Dictionary in _lines:
		var y := list.position.y+(float(entry.y)-scroll)*px
		var h := float(entry.h)*px
		if y+h < list.position.y or y > list.end.y: continue
		var clip_top := maxf(0.0,list.position.y-y)
		var clip_bottom := maxf(0.0,y+h-list.end.y)
		if clip_top > h*0.5 or clip_bottom > h*0.5: continue
		if entry.kind == "group":
			_caps(str(entry.title),Vector2(list.position.x+12.0*px,y+h-8.0*px),GROUP_TYPE,GROUP_TRACK,T2)
		else:
			_draw_row(entry,Rect2(Vector2(list.position.x,y),Vector2(list.size.x-12.0*px,h)),line)
	if _rows.is_empty():
		var empty := "Nothing by that name in the roll."
		var w := _text_font.get_string_size(empty,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(16.0*px)).x
		_body.draw_string(_text_font,Vector2((width-w)*0.5,list.position.y+50.0*px),empty,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(16.0*px),T2)
	if _list_h > LIST_MAX:
		var view := list.size.y
		var bar_h := maxf(24.0*px,view*LIST_MAX/_list_h)
		var bar_y := list.position.y+(view-bar_h)*(scroll/maxf(1.0,_list_h-LIST_MAX))
		Linen.fill_round(_body,Rect2(Vector2(list.end.x-8.0*px,bar_y),Vector2(6.0*px,bar_h)),3.0*px,Color(ACC,0.22))
	# The foot: the hints, and what the selection is.
	var foot_y := list.end.y+6.0*px
	_double_rule(foot_y,line)
	var x := 22.0*px
	var hint_y := foot_y+RULES_H*px+HINTS_H*0.5*px
	for hint: Array in [["↑ ↓","move"],["tab","pocket"],["↵","take in hand"]]:
		x = _key_chip([hint[0]],Vector2(x,hint_y),line,false)+6.0*px
		_body.draw_string(_text_font,Vector2(x,hint_y+4.5*px),hint[1],HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(13.0*px),T2)
		x += _text_font.get_string_size(hint[1],HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(13.0*px)).x+18.0*px
	if not _rows.is_empty():
		var item: Dictionary = _rows[sel].item
		var desc := str(item.desc)
		if not desc.is_empty():
			var room := width-x-22.0*px
			_body.draw_string(_text_font,Vector2(width-22.0*px-minf(room,_text_font.get_string_size(desc,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(13.0*px)).x),hint_y+4.5*px),desc,HORIZONTAL_ALIGNMENT_LEFT,room,roundi(13.0*px),Color(ACC,0.85))

func _draw_tabs(origin: Vector2, line: float) -> void:
	var px := ui_scale
	_tab_rects.clear()
	var room := _body.size.x-origin.x*2.0
	var counts := []
	var q := query.strip_edges().to_lower()
	for i in range(TABS.size()):
		var n := 0
		for item: Dictionary in _items:
			if (i == 0 or item.cat == i) and (q.is_empty() or (str(item.name)+" "+str(item.sub)+" "+str(TABS[item.cat])).to_lower().contains(q)): n += 1
		counts.append(n)
	# Labels with counts if they fit, without if not, and the chosen's label
	# alone when even that is too wide.
	var plans := [[true,true],[true,false],[false,false]]
	var widths := []
	for plan: Array in plans:
		widths.clear()
		var total := 0.0
		for i in range(TABS.size()):
			var w := 8.0*px+20.0*px+12.0*px
			if plan[0] or i == tab: w += 6.0*px+_caps_width(TABS[i],TAB_TYPE,TAB_TRACK)*px
			if plan[1]: w += 6.0*px+_text_font.get_string_size(str(counts[i]),HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(12.0*px)).x
			widths.append(w)
			total += w+2.0*px
		if total <= room or plan == plans[-1]:
			var x := origin.x
			for i in range(TABS.size()):
				var on := i == tab
				var rect := Rect2(Vector2(x,origin.y),Vector2(widths[i],TAB_H*px))
				_tab_rects.append(rect)
				if on:
					var box := StyleBoxFlat.new()
					box.bg_color = TAB_BG
					box.corner_radius_top_left = roundi(7.0*px)
					box.corner_radius_top_right = roundi(7.0*px)
					box.anti_aliasing = true
					_body.draw_style_box(box,rect)
				var cx := x+8.0*px+10.0*px
				Linen.icon(_body,_icons,TAB_ICONS[i],Vector2(cx,rect.get_center().y),20.0*px,px,"icon",1.0,Color(1,1,1,1.0 if on else 0.72))
				var tx := cx+10.0*px+6.0*px
				if plan[0] or on:
					var colour := T1 if on else T2
					var w := _caps(TABS[i],Vector2(tx,rect.get_center().y+5.0*px),TAB_TYPE,TAB_TRACK,colour)
					if on: _body.draw_line(Vector2(tx,rect.get_center().y+9.0*px),Vector2(tx+w,rect.get_center().y+9.0*px),TAB_LINE,line)
					tx += w+6.0*px
				if plan[1]:
					_body.draw_string(_text_font,Vector2(tx,rect.get_center().y+5.0*px),str(counts[i]),HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(12.0*px),T2)
				x += widths[i]+2.0*px
			return

func _draw_row(entry: Dictionary, rect: Rect2, line: float) -> void:
	var px := ui_scale
	var item: Dictionary = entry.item
	var on: bool = entry.index == sel
	var locked := _locked(item)
	if on: _patch(rect,9.0,WELL,WELL_SHADE)
	var box := Rect2(Vector2(rect.position.x+8.0*px,rect.get_center().y-ICON_BOX*0.5*px),Vector2.ONE*ICON_BOX*px)
	if item.kind == "mood":
		_draw_vignette(str(item.id),box,line)
	elif item.has("icon"):
		Linen.icon(_body,_icons,str(item.icon),box.get_center(),ICON*px,px,"locked" if locked else ("lit" if on else "icon"),0.0 if locked else (1.0 if on else 2.0))
	else:
		var glyph := Rect2(box.get_center()-Vector2.ONE*16.0*px,Vector2.ONE*32.0*px)
		Linen.fill_round(_body,glyph,8.0*px,GLYPH_BG)
		Linen.dashed_round(_body,glyph,8.0*px,GLYPH_STITCH,line,px)
		var g := str(item.glyph)
		var gsize := roundi(16.0*px)
		var gw := _caps_font.get_string_size(g,HORIZONTAL_ALIGNMENT_LEFT,-1,gsize).x
		_caps_font.spacing_glyph = 0
		_body.draw_string(_caps_font,Vector2(glyph.get_center().x-gw*0.5,glyph.get_center().y+5.5*px),g,HORIZONTAL_ALIGNMENT_LEFT,-1,gsize,ACC)
	var x := box.end.x+14.0*px
	var right := rect.end.x-12.0*px
	var keys: Array = item.get("keys",[])
	if locked:
		var tag := "undiscovered"
		var tw := _text_font.get_string_size(tag,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(13.0*px)).x
		_body.draw_string(_text_font,Vector2(right-tw,rect.get_center().y+4.5*px),tag,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(13.0*px),T2)
		right -= tw+12.0*px
	elif not keys.is_empty():
		right = _key_chip(keys,Vector2(right,rect.get_center().y),line)-12.0*px
	elif item.kind == "mood" and _mood_now() == str(item.id):
		var tag := "now"
		var tw := _text_font.get_string_size(tag,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(13.0*px)).x
		_body.draw_string(_text_font,Vector2(right-tw,rect.get_center().y+4.5*px),tag,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(13.0*px),T2)
		right -= tw+12.0*px
	elif item.kind == "world" and item.id == "still":
		var running := _clock_running()
		var tag := "running" if running else "held"
		var tw := _text_font.get_string_size(tag,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(13.0*px)).x
		_body.draw_string(_text_font,Vector2(right-tw,rect.get_center().y+4.5*px),tag,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(13.0*px),T2)
		right -= tw+12.0*px
	_caps(str(item.name),Vector2(x,rect.get_center().y-3.0*px),NAME_TYPE,NAME_TRACK,T2 if locked else T1)
	_body.draw_string(_text_font,Vector2(x,rect.get_center().y+15.0*px),str(item.sub),HORIZONTAL_ALIGNMENT_LEFT,maxf(10.0,right-x),roundi(SUB_TYPE*px),T2,TextServer.JUSTIFICATION_NONE)
	if on: Linen.dashed_round(_body,rect.grow(-2.0*px),8.0*px,ON_STITCH,line,px)

func _draw_vignette(id: String, box: Rect2, line: float) -> void:
	var pages: Node = materials.pages if materials != null else null
	if pages == null or not pages.has_method("_vignette"): return
	var size: Vector2 = Icons.VIGNETTE_SIZES.world*ui_scale*0.68
	var rect := Rect2((box.get_center()-size*0.5).round(),size.round())
	_body.draw_rect(Rect2(rect.position+Vector2(0.0,2.0*ui_scale),rect.size),Color(0.047,0.035,0.020,0.22))
	_body.draw_rect(rect.grow(line),Color(0.078,0.055,0.031,0.3))
	var texture: Texture2D = pages._vignette(id,"world")
	if texture != null: _body.draw_texture_rect(texture,rect,false)

## Key caps in a row ending (or starting, `from_right` false) at `at`; returns
## the far edge's x.
func _key_chip(keys: Array, at: Vector2, line: float, from_right := true) -> float:
	var px := ui_scale
	var size := roundi(KEY_TYPE*px)
	var widths := []
	var total := 0.0
	for k: String in keys:
		var w := maxf(12.0*px,_text_font.get_string_size(k,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x)+14.0*px
		widths.append(w)
		total += w+4.0*px
	total -= 4.0*px
	var x := at.x-total if from_right else at.x
	var start := x
	for i in range(keys.size()):
		var rect := Rect2(Vector2(x,at.y-10.0*px),Vector2(widths[i],20.0*px))
		Linen.dashed_round(_body,rect,4.0*px,KEY,line,px)
		var tw := _text_font.get_string_size(keys[i],HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		_body.draw_string(_text_font,Vector2(rect.get_center().x-tw*0.5,at.y+4.0*px),keys[i],HORIZONTAL_ALIGNMENT_LEFT,-1,size,ACC)
		x += widths[i]+4.0*px
	return start if from_right else x-4.0*px

func _double_rule(y: float, line: float) -> void:
	var px := ui_scale
	for k in range(2):
		var at := roundf(y+(2.0+k*3.0)*px)+line*0.5
		Linen.dashed(_body,PackedVector2Array([Vector2(PAD*px,at),Vector2(_body.size.x-PAD*px,at)]),RULE,line,3.0*px,3.0*px)

## The pressed well (hud_linen's pressed patch at any radius).
func _patch(rect: Rect2, radius: float, patch: Color, shade: Color) -> void:
	var r := minf(radius*ui_scale,minf(rect.size.x,rect.size.y)*0.5)
	Linen.fill_round(_body,rect,r,patch)
	for i in range(3):
		var h := minf((2.0+i*1.6)*ui_scale,rect.size.y)
		var box := StyleBoxFlat.new()
		box.bg_color = Color(shade,shade.a*0.34)
		box.corner_radius_top_left = int(round(r))
		box.corner_radius_top_right = int(round(r))
		box.corner_radius_bottom_left = int(round(minf(r,h*0.5)))
		box.corner_radius_bottom_right = box.corner_radius_bottom_left
		box.anti_aliasing = true
		_body.draw_style_box(box,Rect2(rect.position,Vector2(rect.size.x,h)))

## Faked small caps at `baseline_at`; returns the letters' width.
func _caps(text: String, baseline_at: Vector2, type: float, track: float, colour: Color) -> float:
	text = text.to_upper()
	var size := maxi(6,roundi(type*CAPS*ui_scale))
	_caps_font.spacing_glyph = roundi(track*type*ui_scale)
	_body.draw_string(_caps_font,baseline_at.round(),text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,colour)
	return _caps_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x-_caps_font.spacing_glyph

## The same width in design pixels.
func _caps_width(text: String, type: float, track: float) -> float:
	text = text.to_upper()
	var size := maxi(6,roundi(type*CAPS*ui_scale))
	_caps_font.spacing_glyph = roundi(track*type*ui_scale)
	return (_caps_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x-_caps_font.spacing_glyph)/ui_scale

func _mood_now() -> String:
	var mood: Node = scene.get("mood_look") if scene != null else null
	return str(mood.mood) if mood != null else ""

func _clock_running() -> bool:
	var clock: Variant = scene.get("world_clock") if scene != null else null
	return clock == null or bool(clock.running)

# --- Input ------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if handle_event(event): get_viewport().set_input_as_handled()

## Opens on Cmd/Ctrl K or /; while open takes every key and press. True when
## the event was used.
func handle_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo and not _want:
		var command: bool = event.ctrl_pressed or event.meta_pressed
		if (command and event.keycode == KEY_K) or (event.keycode == KEY_SLASH and not command and not event.alt_pressed):
			if not _can_open(): return false
			open()
			return true
		return false
	if not _want: return false
	if event is InputEventKey:
		if event.pressed: _key(event)
		return true
	if event is InputEventMouseMotion:
		var row := _row_at(event.position)
		if row >= 0: sel = row
		return true
	if event is InputEventMouseButton:
		var point: Vector2 = event.position
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			if event.pressed: scroll += WHEEL_STEP*(1.0 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0)
			return true
		if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT: return true
		if not contains_pointer(point):
			close()
			return true
		var local := point-panel_rect().position
		for i in range(_tab_rects.size()):
			if _tab_rects[i].has_point(local):
				_set_tab(i)
				return true
		var row := _row_at(point)
		if row >= 0:
			sel = row
			_take(_rows[row].item)
		return true
	return true

func _can_open() -> bool:
	if materials == null or materials.hud_hidden: return false
	var reach: Node = materials.reach
	return reach != null and reach.available() and reach.holding.is_empty()

func _key(event: InputEventKey) -> void:
	var command: bool = event.ctrl_pressed or event.meta_pressed
	match event.keycode:
		KEY_ESCAPE:
			close()
		KEY_K:
			if command: close()
			else: _type(event)
		KEY_DOWN, KEY_UP:
			if _rows.is_empty(): return
			sel = posmod(sel+(1 if event.keycode == KEY_DOWN else -1),_rows.size())
			_keep_in_view = true
		KEY_TAB:
			_set_tab(posmod(tab+(-1 if event.shift_pressed else 1),TABS.size()))
		KEY_ENTER, KEY_KP_ENTER:
			if not _rows.is_empty(): _take(_rows[sel].item)
		KEY_BACKSPACE:
			if command: query = ""
			elif not query.is_empty(): query = query.left(query.length()-1)
			sel = 0
			scroll = 0.0
			_refresh()
		_:
			_type(event)

func _type(event: InputEventKey) -> void:
	if event.ctrl_pressed or event.meta_pressed or event.unicode < 32: return
	type_text(String.chr(event.unicode))

func _set_tab(i: int) -> void:
	tab = i
	sel = 0
	scroll = 0.0
	_refresh()
	ClaySound.cue(&"ui_pick")

func _row_at(point: Vector2) -> int:
	var local := point-panel_rect().position
	var list := _list_rect()
	if not list.has_point(local): return -1
	var y := (local.y-list.position.y)/ui_scale+scroll
	for line: Dictionary in _rows:
		if y >= float(line.y) and y < float(line.y)+float(line.h): return int(line.index)
	return -1

# --- Taking -----------------------------------------------------------------------

## Takes `item` in hand, or does it; the palette goes away unless it refused.
func _take(item: Dictionary) -> void:
	if _locked(item):
		ClaySound.cue(&"ui_refuse")
		return
	var refusal := ""
	match str(item.kind):
		"seed", "element":
			if not materials.take(item.id): refusal = "Not something the hand can hold"
		"tool":
			if item.id == "feather": materials.take_feather()
			else:
				materials.put_back()
				materials.select_tool(item.id)
		"life":
			var life: Node = scene.get("land_life")
			if life == null or not life.has_method("summon"): refusal = "No wild things on this land"
			else: refusal = life.summon(item.id)
			if refusal.is_empty(): ClaySound.cue(&"ui_take")
		"mood":
			var mood: Node = scene.get("mood_look")
			if mood == null: refusal = "No moods here"
			else: mood.choose(item.id)
		"world":
			refusal = _world(item.id)
	if not refusal.is_empty():
		last_refusal = refusal
		_notice_left = NOTICE_SECONDS
		materials.reach._show_hint(refusal)
		ClaySound.cue(&"ui_refuse")
		return
	last_taken = _key_of(item)
	var key := _key_of(item)
	recent.erase(key)
	recent.push_front(key)
	if recent.size() > 3: recent.resize(3)
	close()

## A World verb; "" when done, else why not.
func _world(id: String) -> String:
	var rig: Node = scene.get("camera_rig")
	match id:
		"undo":
			materials.foot.undo()
			ClaySound.cue(&"ui_undo")
		"redo":
			var editor: Node = materials.reach._editor()
			if editor == null: return "Nothing to put back"
			editor.redo()
			ClaySound.cue(&"ui_undo")
		"turn_left", "turn_right":
			if rig == null or not rig.has_method("quarter_turn"): return "The view cannot turn here"
			rig.quarter_turn(-1 if id == "turn_left" else 1)
		"overview":
			if rig == null: return "The view cannot settle here"
			rig.overview()
		"still":
			var clock: Variant = scene.get("world_clock")
			if clock == null: return "No clock on this land"
			clock.running = not clock.running
		"save":
			if not scene.has_method("save_current") or not scene.save_current(): return "Could not keep it just now"
		"photo":
			close()
			materials.foot.photo()
	return ""
