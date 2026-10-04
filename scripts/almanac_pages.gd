extends Control
## The almanac's pages (design "ZenScape HUD 5 Air", docs/design/hud-5/README.md
## sections B, E, "Customise" and Motion; notes in docs/design/hud-5/PAGES.md):
## two sheets of the HUD's linen that open to the LEFT of the almanac strip on
## the right edge (scripts/almanac.gd, `page_requested(page, row)`).
##
## - **Moods** (320 px): a page of specimen cards, one faceted vignette per
##   mood drawn from the mood's own colours, with This world first once the
##   look has moved from how the world was made. Choosing one cross-fades the
##   world (scripts/mood_look.gd `choose`, 1.2 s).
## - **Customise** (360 px): the mood's name and a row of mini vignettes to
##   switch without leaving, then chip rows for Season, Time, Weather, Wind and
##   Rock, and the colours with their swatches and Mix. Setting anything ties
##   a knot (a pin); a knot's click unties it; Back to mood unties them all.
##
## Nothing is decided here. The moods, controls, options, swatches and pins are
## mood_look's (`choose`, `pin`, `unpin`, `pinned`, `value`, `clear_pins`), and
## the wind strengths are its WIND_STRENGTHS, which the strip's windsock reads
## too. This file lays the page out as a list of items (design pixels, in the
## page's scrolling content) that both the drawing and the hit tests read, so
## what is drawn is what is hit.
##
## Input: a press inside the page acts on the item under it (grooves and the
## wind dial take the drag that follows); a press on the empty frame outside
## the page and the strip closes it, as does Esc (Esc in Mix first goes back to
## the swatches). The owner can read `contains_pointer` to keep the hand off
## the page; the page takes its own events in `_input`, or through
## `handle_event` for probes.

signal closed

const Linen = preload("res://scripts/hud_linen.gd")
const Icons = preload("res://scripts/hud_icons.gd")
const Mood = preload("res://scripts/mood_look.gd")
const Presets = preload("res://scripts/scene_look_presets.gd")
const SPECTRAL = preload("res://assets/fonts/spectral-latin-400.woff2")

# --- Tokens (lowpoly.js AIR_TOKENS; README "New tokens") ----------------------------

## The page's cloth: 4c's linen at .8 rather than .76, since pages sit over
## brighter sky.
const PAGE_CLOTH := Color(0.384,0.345,0.290,0.8)
## The knot (a pin): a 7 px cream dot, its two shadows (an inner shade along
## its foot, a drop under it) and its halo, 3 px at rest and 5 px hovered.
const KNOT := Color("e3d7bd")
const KNOT_SHADE := Color(0.102,0.078,0.055,0.35)
const KNOT_DROP := Color(0.047,0.035,0.020,0.3)
const KNOT_HALO := Color(0.890,0.843,0.741,0.14)
const KNOT_SIZE := 7.0
const KNOT_HALO_REST := 3.0
const KNOT_HALO_HOVER := 5.0
## Descriptions and whispers.
const WHISPER_INK := Color("d6cbb2")
## A chip's dashed outline; the dashed section rules.
const CHIP_STITCH := Color(0.890,0.843,0.741,0.22)
const RULE := Color(0.890,0.843,0.741,0.3)
## Flat colour (swatches, the colour chips): stitched 2 px inside, a darker
## 1.5 px foot and a 1 px dark edge round it.
const SWATCH_STITCH := Color(1.0,0.980,0.941,0.35)
const SWATCH_FOOT := Color(0.102,0.078,0.055,0.25)
const SWATCH_EDGE := Color(0.078,0.055,0.031,0.25)
## Vignettes: stitched 1 px dashed 2 px inside, a 1 px dark edge and a 2 px
## drop below.
const VIGNETTE_STITCH := Color(1.0,0.980,0.941,0.3)
const VIGNETTE_EDGE := Color(0.078,0.055,0.031,0.3)
const VIGNETTE_DROP := Color(0.047,0.035,0.020,0.22)
## The Unpin tooltip's patch.
const TIP := Color(0.078,0.055,0.031,0.55)

# --- Geometry, design pixels ------------------------------------------------------

## Pages open left of the strip, their right edge this far from the frame's
## (the strip's 24 px inset, its 80 px width and the 10 px page gap, as the
## design places it), vertically centred.
const RIGHT := 116.0
const WIDTHS := {"moods":320.0,"customise":360.0}
## The page's padding, and the least room it leaves above and below it before
## it scrolls instead of growing.
const PAD := Vector2(18.0,16.0)
const MARGIN_Y := 24.0
const RADIUS := 12.0
const HEM := Vector2(5.0,8.0)
## The header's line height and the gap under it.
const HEADER_H := 20.0
const HEADER_GAP := 10.0
## A rule's block: the dashed line in the middle of it.
const RULE_H := 14.0
## Small caps (faked, as 4c does: capitals at CAPS of the type size, tracked):
## chips and labels at 12.5 px with 0.12 em, card titles at 12 px, headers at
## 13 px with 4c's 0.22 em.
const CAPS := 10.0/13.0
const CHIP_TYPE := 12.5
const CHIP_TRACK := 0.12
const CARD_TYPE := 12.0
const HEAD_TYPE := 13.0
const HEAD_TRACK := 0.22
## Newsreader for the mood's name; Spectral for descriptions.
const NAME_TYPE := 16.0
const DESC_TYPE := 15.0
const WORLD_DESC_TYPE := 13.0
## Moods page: the This world row (a 56x35 vignette, caps and a Spectral
## line), and the 3x3 grid of 78x49 cards with two lines of title below.
const WORLD_ROW_H := 43.0
const CARD_TOP := 6.0
const CARD_TITLE_GAP := 7.0
const CARD_LINE := 13.0
const CARD_FOOT := 6.0
const FOOT_H := 60.0
## Customise: the mini vignettes (22x14 in 3 px patches, 4 apart); rows with
## a 14 px knot gutter and a 64 px label column; chips 24 tall, padded
## CHIP_PAD each side, CHIP_GAP apart, radius CHIP_RADIUS; ROW_GAP between rows.
const MINI_PAD := 3.0
const MINI_GAP := 4.0
const GUTTER := 14.0
const LABEL_W := 64.0
const CHIP_H := 24.0
const CHIP_PAD := 9.0
const CHIP_GAP := 4.0
const CHIP_RADIUS := 5.0
const ROW_GAP := 8.0
## The wind's 22 px stitched direction dial.
const DIAL := 22.0
## Colours: two columns of label and a 30x16 chip, COLOUR_ROW_H apart; an
## opened colour's row of six 24x20 swatches and Mix; Mix's three 12 px
## grooves, GROOVE_ROW_H apart, with a 14 px knot riding each.
const COLOUR_CHIP := Vector2(30.0,16.0)
const COLOUR_ROW_H := 24.0
const SWATCH := Vector2(24.0,20.0)
const SWATCH_GAP := 6.0
const SWATCH_POCKET := 3.0
const GROOVE_H := 12.0
const GROOVE_ROW_H := 24.0
const GROOVE_KNOT := 14.0
const GROOVE_STEPS := 24
## Mix's three channels: hue, depth (saturation) and light (value).
const CHANNELS := ["Hue","Depth","Light"]
## Rows a Customise page lists, in order. `open("customise", row)` also takes
## "rock" (the strip's name for the Rock row), a colour key, or "c_<key>".
const ROWS := ["season","time","weather","wind","rock_type"]
const ROW_TITLES := {"season":"Season","time":"Time","weather":"Weather","wind":"Wind","rock_type":"Rock"}

# --- Motion (README "Motion") -----------------------------------------------------

## Page open and close: 250 ms of opacity with a 6 px slide from the strip.
## Switching pages fades the new page's content in over the same time.
const OPEN_TIME := 0.25
const SLIDE := 6.0
## Hover and press patches: 150 ms, linear.
const HOVER_TIME := 0.15
## A ghost knot's fade.
const GHOST_TIME := 0.4
## A row asked for by `open` is lit with the hover patch, which fades out
## over this long.
const FLASH_TIME := 1.2
## Pixels a wheel notch scrolls.
const WHEEL_STEP := 40.0

## Seeds for the vignettes (lowpoly.js MOODS: 23 This world, 24..32 the moods
## in SceneLookPresets.PRESETS order, which the design's list matches).
const WORLD_SEED := 23
const FIRST_MOOD_SEED := 24

var scene: Node
var mood: Node
## "moods", "customise" or "" when never opened.
var page := ""
## 0..1: how far open the page is, and its content after a page switch.
var shown := 0.0
var content := 1.0
## The open colour (a COLORS key) and whether its Mix is showing.
var colour_open := ""
var mixing := false
var scroll := 0.0
var ui_scale := 1.0
## The item under the pointer (its key) and the knot hovered, for probes too.
var hovered := ""
var pointer_override: Variant = null
## The strip's rectangle in viewport pixels; a press there never closes the
## page (the strip switches pages itself). Empty: the design's strip column,
## the right RIGHT design pixels of the frame.
var strip_rect := Rect2()

## Body draws so far, for probes (headless still runs the drawing code).
var draws := 0
var _want := false
var _items: Array[Dictionary] = []
var _content_h := 0.0
var _hover := {}
var _ghosts: Array[Dictionary] = []
var _flash_row := ""
var _flash := 0.0
var _scroll_to := ""
## A drag in progress: {kind: "groove" or "dial", id, value}.
var _drag := {}
## Mix's hue, depth and light, kept while mixing so a grey keeps its hue.
var _hsv := Vector3.ZERO
var _cloth: Linen.Cloth
var _body: Control
var _caps_font: FontVariation
var _name_font: FontVariation
var _desc_font: FontVariation
var _vignettes := {}
var _vignette_px := 0.0

func _ready() -> void:
	name = "AlmanacPages"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_caps_font = Linen.tag_font()
	_name_font = FontVariation.new()
	_name_font.base_font = Linen.DISPLAY
	_desc_font = FontVariation.new()
	_desc_font.base_font = SPECTRAL
	_cloth = Linen.Cloth.new()
	_cloth.material_ref.set_shader_parameter("cloth",PAGE_CLOTH)
	add_child(_cloth)
	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.clip_contents = true
	_body.draw.connect(_draw_body)
	add_child(_body)
	modulate.a = 0.0
	visible = false

## `owner_scene` holds `mood_look` (scripts/mood_look.gd), `_atmosphere` and
## `_celestial`, as studies/cozy_worlds.gd does.
func setup(owner_scene: Node) -> void:
	scene = owner_scene
	mood = scene.get("mood_look")
	if mood != null: mood.changed.connect(_body.queue_redraw)

# --- API --------------------------------------------------------------------------

## Opens `which` ("moods" or "customise"). On Customise, `row` (a ROWS id,
## "rock", a colour key or "c_<key>") is scrolled to and lit; a colour opens
## its swatches.
func open(which: String, row := "") -> void:
	if not WIDTHS.has(which): return
	if _want and which != page: content = 0.0
	if which != page:
		colour_open = ""
		mixing = false
		_drag.clear()
		scroll = 0.0
	page = which
	_want = true
	visible = true
	if which == "customise" and not row.is_empty():
		var id := row.trim_prefix("c_")
		if row == "rock" or row == "rock_type": id = "rock_type"
		if id in ROWS:
			_flash_row = id
		elif id in Mood.color_keys():
			colour_open = id
			mixing = false
			_flash_row = "colour:"+id
		_flash = 1.0 if not _flash_row.is_empty() else 0.0
		_scroll_to = _flash_row

func close() -> void:
	if not _want: return
	_want = false
	_drag.clear()
	closed.emit()

func is_open() -> bool:
	return _want

func contains_pointer(point: Vector2) -> bool:
	return _want and shown > 0.0 and page_rect().has_point(point)

## The page in viewport pixels, where it is drawn now.
func page_rect() -> Rect2:
	if page.is_empty(): return Rect2()
	var screen := get_viewport_rect().size
	var width := float(WIDTHS[page])*ui_scale
	var height := minf(_content_h,screen.y/ui_scale-MARGIN_Y*2.0)*ui_scale
	var slide := (1.0-Linen.eased(shown))*SLIDE*ui_scale
	return Rect2(Vector2(roundf(screen.x-RIGHT*ui_scale-width+slide),roundf((screen.y-height)*0.5)),Vector2(roundf(width),roundf(height)))

## An item's rectangle in viewport pixels (for probes and the strip): the
## first whose kind, id and value match, or an empty rect.
func item_rect(kind: String, id := "", value: Variant = null) -> Rect2:
	for item: Dictionary in _items:
		if item.kind == kind and item.id == id and (value == null or item.get("value") == value): return _to_screen(item.rect)
	return Rect2()

# --- Frames -----------------------------------------------------------------------

func _process(delta: float) -> void:
	delta = minf(delta,0.05)
	var screen := get_viewport_rect().size
	var scale_now := Linen.hud_scale_for(screen)
	if not is_equal_approx(scale_now,ui_scale):
		ui_scale = scale_now
		_vignettes.clear()
	shown = move_toward(shown,1.0 if _want else 0.0,delta/OPEN_TIME)
	content = move_toward(content,1.0,delta/OPEN_TIME)
	visible = shown > 0.0
	if not visible: return
	modulate.a = Linen.eased(shown)
	_layout()
	if not _scroll_to.is_empty(): _scroll_into_view(_scroll_to)
	var pointer: Vector2 = get_viewport().get_mouse_position() if pointer_override == null else pointer_override
	var under := _item_at(pointer) if _want else {}
	hovered = _key(under) if not under.is_empty() else ""
	for key: String in _hover.keys():
		if key != hovered:
			_hover[key] = move_toward(float(_hover[key]),0.0,delta/HOVER_TIME)
			if float(_hover[key]) <= 0.0: _hover.erase(key)
	if not hovered.is_empty(): _hover[hovered] = move_toward(float(_hover.get(hovered,0.0)),1.0,delta/HOVER_TIME)
	for ghost: Dictionary in _ghosts: ghost.t = float(ghost.t)+delta/GHOST_TIME
	_ghosts = _ghosts.filter(func(ghost: Dictionary) -> bool: return float(ghost.t) < 1.0)
	_flash = move_toward(_flash,0.0,delta/FLASH_TIME)
	# Mix follows a colour changed from elsewhere (a mood, a swatch, an
	# unpin); a grey keeps the hue it had.
	if mixing and _drag.is_empty() and colour_open in Mood.color_keys():
		var now := Color(mood.value(colour_open))
		if now.to_html(false) != Color.from_hsv(_hsv.x,_hsv.y,_hsv.z).to_html(false):
			_hsv = Vector3(now.h if now.s > 0.001 else _hsv.x,now.s,now.v)
	var rect := page_rect()
	_cloth.place(rect,ui_scale,RADIUS,HEM)
	_body.position = rect.position
	_body.size = rect.size
	_body.modulate.a = Linen.eased(content)
	_body.queue_redraw()

# --- Layout -----------------------------------------------------------------------

## Rebuilds `_items` for the page: each {kind, id, value, rect} in content
## design pixels (x from the page's left, y from its content's top).
func _layout() -> void:
	_items.clear()
	if mood == null: return
	var width := float(WIDTHS[page])
	var inner := width-PAD.x*2.0
	var y := PAD.y
	if page == "moods": y = _layout_moods(y,inner)
	else: y = _layout_customise(y,inner)
	_content_h = y+PAD.y
	var view := minf(_content_h,get_viewport_rect().size.y/ui_scale-MARGIN_Y*2.0)
	scroll = clampf(scroll,0.0,maxf(_content_h-view,0.0))

func _add(kind: String, id: String, rect: Rect2, value: Variant = null) -> void:
	_items.append({"kind":kind,"id":id,"value":value,"rect":rect})

func _layout_moods(y: float, inner: float) -> float:
	var link := _caps_width("Customise",HEAD_TYPE,HEAD_TRACK)
	_add("header","moods",Rect2(PAD.x,y,inner,HEADER_H))
	_add("link","customise",Rect2(PAD.x+inner-link-4.0,y,link+8.0,HEADER_H))
	y += HEADER_H+HEADER_GAP
	if _differs():
		_add("world","",Rect2(PAD.x,y,inner,WORLD_ROW_H))
		y += WORLD_ROW_H+ROW_GAP
	var ids: Array = Mood.mood_ids()
	var cell := Vector2(inner/3.0,CARD_TOP+Icons.VIGNETTE_SIZES.card.y+CARD_TITLE_GAP+CARD_LINE*2.0+CARD_FOOT)
	for i in range(ids.size()):
		_add("card",ids[i],Rect2(PAD.x+cell.x*(i%3),y+cell.y*(i/3),cell.x,cell.y))
	y += cell.y*ceili(ids.size()/3.0)
	_add("rule","",Rect2(PAD.x,y,inner,RULE_H))
	y += RULE_H
	_add("foot","",Rect2(PAD.x,y,inner,FOOT_H))
	return y+FOOT_H

func _layout_customise(y: float, inner: float) -> float:
	var link := _caps_width("Moods",HEAD_TYPE,HEAD_TRACK)
	_add("header","customise",Rect2(PAD.x,y,inner,HEADER_H))
	_add("link","moods",Rect2(PAD.x-4.0,y,link+8.0,HEADER_H))
	if not mood.pins.is_empty():
		var back := _caps_width("Back to mood",HEAD_TYPE,HEAD_TRACK)+14.0
		_add("back","",Rect2(PAD.x+inner-back-4.0,y,back+8.0,HEADER_H))
	y += HEADER_H+HEADER_GAP
	var minis: Array = [""]+Mood.mood_ids()
	var mini: Vector2 = Icons.VIGNETTE_SIZES.mini+Vector2.ONE*MINI_PAD*2.0
	# As many to a row as the page holds, rows centred, more rows when the
	# moods outgrow one.
	var per_row := maxi(1,floori((inner+MINI_GAP)/(mini.x+MINI_GAP)))
	var x := PAD.x
	for start in range(0,minis.size(),per_row):
		var row := minis.slice(start,start+per_row)
		var span := mini.x*row.size()+MINI_GAP*(row.size()-1)
		x = PAD.x+(inner-span)*0.5
		for id: String in row:
			_add("mini",id,Rect2(x,y,mini.x,mini.y))
			x += mini.x+MINI_GAP
		y += mini.y+(MINI_GAP if start+per_row < minis.size() else 0.0)
	_add("rule","",Rect2(PAD.x,y,inner,RULE_H))
	y += RULE_H
	var chips_x := PAD.x+GUTTER+LABEL_W
	var chips_w := PAD.x+inner-chips_x
	for row: String in ROWS:
		var top := y
		var entries: Array = Mood.WIND_STRENGTHS if row == "wind" else Mood.options(row)
		x = chips_x
		for entry: Dictionary in entries:
			var w := _caps_width(entry.title,CHIP_TYPE,CHIP_TRACK)+CHIP_PAD*2.0
			if x > chips_x and x+w > chips_x+chips_w:
				x = chips_x
				y += CHIP_H+CHIP_GAP
			_add("chip",row,Rect2(x,y,w,CHIP_H),entry.id)
			x += w+CHIP_GAP
		if row == "wind":
			if x+DIAL > chips_x+chips_w:
				x = chips_x
				y += CHIP_H+CHIP_GAP
			_add("dial","wind",Rect2(x+2.0,y+(CHIP_H-DIAL)*0.5,DIAL,DIAL))
		y += CHIP_H
		_add("row",row,Rect2(PAD.x,top,inner,y-top))
		if mood.pinned(row): _add("knot",row,_knot_cell(Vector2(PAD.x,top)))
		y += ROW_GAP
	y += RULE_H-ROW_GAP
	_add("rule","",Rect2(PAD.x,y-RULE_H,inner,RULE_H))
	# Colours: two columns of label and chip; an open colour's row, full
	# width, under the pair it belongs to.
	var keys: Array = Mood.color_keys()
	var column := inner*0.5
	for i in range(0,keys.size(),2):
		for k in range(2):
			if i+k >= keys.size(): break
			var key: String = keys[i+k]
			var cell := Rect2(PAD.x+column*k,y,column-(8.0 if k == 0 else 0.0),COLOUR_ROW_H)
			_add("colour",key,cell)
			if mood.pinned(key): _add("knot",key,_knot_cell(cell.position))
		y += COLOUR_ROW_H
		var opened: String = colour_open if colour_open in keys.slice(i,i+2) else ""
		if opened.is_empty(): continue
		y += 4.0
		var top := y
		if mixing:
			var link_w := _caps_width("Swatches",CHIP_TYPE,CHIP_TRACK)+CHIP_PAD*2.0
			_add("link","swatches",Rect2(PAD.x+inner-link_w,y,link_w,GROOVE_ROW_H))
			for c in range(CHANNELS.size()):
				var groove_w := inner-GUTTER-LABEL_W-(link_w+CHIP_GAP if c == 0 else 0.0)
				_add("groove",opened,Rect2(PAD.x+GUTTER+LABEL_W,y,groove_w,GROOVE_ROW_H),c)
				y += GROOVE_ROW_H
		else:
			x = PAD.x+GUTTER+LABEL_W
			for s in range(Mood.swatches(opened).size()):
				_add("swatch",opened,Rect2(x,y+(COLOUR_ROW_H+4.0-SWATCH.y)*0.5,SWATCH.x,SWATCH.y),s)
				x += SWATCH.x+SWATCH_GAP
			var mix_w := _caps_width("Mix",CHIP_TYPE,CHIP_TRACK)+CHIP_PAD*2.0
			_add("mix",opened,Rect2(x+2.0,y+2.0,mix_w,CHIP_H))
			y += COLOUR_ROW_H+4.0
		_add("open",opened,Rect2(PAD.x,top,inner,y-top))
	return y

## A knot's hit cell for a row starting at `origin` (content design pixels):
## the gutter, a label's height tall.
func _knot_cell(origin: Vector2) -> Rect2:
	return Rect2(origin+Vector2(-3.0,(CHIP_H-GUTTER)*0.5),Vector2(GUTTER+3.0,GUTTER))

func _scroll_into_view(row: String) -> void:
	_scroll_to = ""
	for item: Dictionary in _items:
		if (item.kind == "row" and item.id == row) or (item.kind == "colour" and "colour:"+str(item.id) == row):
			var view := minf(_content_h,get_viewport_rect().size.y/ui_scale-MARGIN_Y*2.0)
			var rect: Rect2 = item.rect
			if rect.position.y < scroll+PAD.y or rect.end.y > scroll+view-PAD.y:
				scroll = clampf(rect.get_center().y-view*0.5,0.0,maxf(_content_h-view,0.0))
			return

# --- Coordinates ------------------------------------------------------------------

## Content design pixels to the page body's local pixels.
func _local(rect: Rect2) -> Rect2:
	return Rect2((rect.position-Vector2(0.0,scroll))*ui_scale,rect.size*ui_scale)

func _to_screen(rect: Rect2) -> Rect2:
	var local := _local(rect)
	return Rect2(local.position+page_rect().position,local.size)

func _item_at(point: Vector2) -> Dictionary:
	var rect := page_rect()
	if not rect.has_point(point): return {}
	var at := (point-rect.position)/ui_scale+Vector2(0.0,scroll)
	# Knots and the dial sit inside rows: test the small things first.
	for pass_kinds: Array in [["knot","dial","back","link"],["card","world","mini","chip","colour","swatch","mix","groove"]]:
		for i in range(_items.size()-1,-1,-1):
			var item: Dictionary = _items[i]
			if item.kind in pass_kinds and Rect2(item.rect).has_point(at): return item
	return {}

func _key(item: Dictionary) -> String:
	return "%s:%s:%s" % [item.kind,item.id,str(item.get("value"))]

func _hover_of(item: Dictionary) -> float:
	return Linen.eased(float(_hover.get(_key(item),0.0)))

# --- Input ------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if handle_event(event): get_viewport().set_input_as_handled()

## Takes a mouse or key event while the page is open. True when it was used.
func handle_event(event: InputEvent) -> bool:
	if not _want: return false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		escape()
		return true
	if event is InputEventMouseMotion:
		if _drag.is_empty(): return false
		_drag_to(event.position)
		return true
	if event is InputEventMouseButton:
		var point: Vector2 = event.position
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			if not contains_pointer(point): return false
			scroll += WHEEL_STEP*(1.0 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0)
			return true
		if event.button_index != MOUSE_BUTTON_LEFT: return contains_pointer(point)
		if not event.pressed:
			if _drag.is_empty(): return contains_pointer(point)
			_drag_to(point)
			_drag.clear()
			return true
		if contains_pointer(point):
			press(point)
			return true
		if _strip().has_point(point): return false
		close()
		return true
	return false

## Esc: Mix back to its swatches, otherwise the page closes.
func escape() -> void:
	if mixing:
		mixing = false
		_drag.clear()
		return
	close()

func _strip() -> Rect2:
	if strip_rect.size != Vector2.ZERO: return strip_rect
	var screen := get_viewport_rect().size
	return Rect2(Vector2(screen.x-RIGHT*ui_scale,0.0),Vector2(RIGHT*ui_scale,screen.y))

## A press inside the page at `point` (viewport pixels).
func press(point: Vector2) -> void:
	_layout()
	var item := _item_at(point)
	if item.is_empty(): return
	var id: String = item.id
	match str(item.kind):
		"link":
			if id == "swatches": mixing = false
			else: open(id)
		"card", "world", "mini": mood.choose(id)
		"chip":
			if id == "wind":
				var air: Node = scene.get("_atmosphere")
				mood.pin("wind",Mood.wind_pin(str(item.value),float(air.direction_angle) if air != null else 0.0))
			else: mood.pin(id,str(item.value))
		"dial":
			_drag = {"kind":"dial","id":"wind"}
			_drag_to(point)
		"knot":
			_ghost(item)
			mood.unpin(id)
		"back":
			for knot: Dictionary in _items.filter(func(it: Dictionary) -> bool: return it.kind == "knot"): _ghost(knot)
			mood.clear_pins()
		"colour":
			colour_open = "" if colour_open == id else id
			mixing = false
		"swatch":
			var colours: Array = Mood.swatches(id)
			mood.pin(id,str(colours[int(item.value)]))
		"mix":
			mixing = true
			var c := Color(mood.value(id))
			_hsv = Vector3(c.h,c.s,c.v)
		"groove":
			_drag = {"kind":"groove","id":id,"value":int(item.value),"rect":item.rect}
			_drag_to(point)
	_body.queue_redraw()

## A drag at `point`: the dial turns the prevailing wind; a groove sets its
## channel. Both apply directly, without the mood's fade, as the old drawer's
## colour picker did.
func _drag_to(point: Vector2) -> void:
	if _drag.is_empty(): return
	if _drag.kind == "dial":
		var dial := item_rect("dial","wind")
		var way := point-dial.get_center()
		if way.length() < 1.0: return
		var air: Node = scene.get("_atmosphere")
		var strength := Mood.wind_strength_id(float(air.strength) if air != null else 0.4)
		# The dial is the ground seen from above, north up: screen x is the
		# world's x and screen y its z, so the angle carries straight over.
		mood.pin("wind",Mood.wind_pin(strength,rad_to_deg(way.angle())),false)
	else:
		var groove := _groove_track(_to_screen(_drag.rect))
		var t := clampf((point.x-groove.position.x)/maxf(groove.size.x,1.0),0.0,1.0)
		_hsv[int(_drag.value)] = t
		mood.pin(str(_drag.id),Color.from_hsv(_hsv.x,_hsv.y,_hsv.z).to_html(false),false)

func _ghost(item: Dictionary) -> void:
	_ghosts.append({"rect":item.rect,"t":0.0})

## The page differs from how the world was made: a mood chosen, or a pin.
func _differs() -> bool:
	return mood != null and (mood.mood != "" or not mood.pins.is_empty())

# --- Vignettes --------------------------------------------------------------------

## A mood's vignette colours: sky, horizon glow and grass from its look (the
## game's own moods; "" is the world's origin, or the look now before any
## change), and its hour from its phase.
func _vignette_source(id: String) -> Dictionary:
	var colours: Dictionary
	var phase := 0.4
	if id != "" and Presets.PRESETS.has(id):
		colours = Presets.look_document(id).colors
		phase = float(Presets.PRESETS[id].phase)
	elif mood != null and not mood.origin.is_empty():
		colours = mood.origin.look.colors
		phase = float(mood.origin.phase)
	elif scene != null and scene.get("_celestial") != null:
		colours = scene._celestial.look.document().colors
		phase = float(scene._celestial.phase)
	else:
		return {"sky":Color("8b95a2"),"glow":Color("c4bfb2"),"grass":Color("4f8a5a"),"hour":"high"}
	var pick := func(key: String) -> Color:
		var c: Array = colours.get(key,[0.5,0.5,0.5])
		return Color(c[0],c[1],c[2])
	return {"sky":pick.call("sky"),"glow":pick.call("glow"),"grass":pick.call("grass"),"hour":hour_of(phase)}

## "night", "low" (dawn, golden hour, dusk) or "high" for a day phase
## (mood_look TIMES: dawn 0.275, golden 0.738, dusk 0.76, night 0.035): the
## afterglow after sunset (to 0.775) still counts as low.
static func hour_of(phase: float) -> String:
	phase = fposmod(phase,1.0)
	if phase < 0.25 or phase >= 0.775: return "night"
	if phase < 0.31 or phase >= 0.6: return "low"
	return "high"

static func seed_of(id: String) -> int:
	# Every mood, offered or not, so each keeps its vignette's seed.
	var index: int = Mood.Presets.PRESETS.keys().find(id)
	return WORLD_SEED if index < 0 else FIRST_MOOD_SEED+index

## A vignette texture at `size_name`'s size, cached. This world's is keyed by
## its colours and hour too, since the origin is only taken at the first change.
func _vignette(id: String, size_name: String) -> Texture2D:
	var source := _vignette_source(id)
	var key := id+":"+size_name
	if id == "": key += ":%s%s%s%s" % [source.sky.to_html(false),source.glow.to_html(false),source.grass.to_html(false),source.hour]
	if _vignettes.has(key): return _vignettes[key]
	var size: Vector2 = Icons.VIGNETTE_SIZES[size_name]*ui_scale
	var texture := Icons.vignette_texture(seed_of(id),source.sky,source.glow,source.grass,source.hour,size.round())
	_vignettes[key] = texture
	return texture

# --- Drawing ----------------------------------------------------------------------

func _draw_body() -> void:
	if mood == null or page.is_empty(): return
	draws += 1
	var line := maxf(1.0,roundf(ui_scale))
	if _flash > 0.0:
		for item: Dictionary in _items:
			if (item.kind == "row" and item.id == _flash_row) or (item.kind == "colour" and "colour:"+str(item.id) == _flash_row):
				var a := Linen.eased(_flash)
				_patch(_local(item.rect).grow(2.0*ui_scale),6.0,Color(Linen.HOVER,Linen.HOVER.a*a),Color(Linen.HOVER_SHADE,Linen.HOVER_SHADE.a*a))
	for item: Dictionary in _items:
		match str(item.kind):
			"header": _draw_header(item,line)
			"link": _draw_link(item)
			"back": _draw_back(item,line)
			"rule": _rule(item.rect,line)
			"world": _draw_world(item,line)
			"card": _draw_card(item,line)
			"foot": _draw_foot(item)
			"mini": _draw_mini(item,line)
			"row": _draw_row_label(item)
			"chip": _draw_chip(item,line)
			"dial": _draw_dial(item,line)
			"colour": _draw_colour(item,line)
			"swatch": _draw_swatch(item,line)
			"mix": _draw_chip(item,line,"Mix",mixing)
			"groove": _draw_groove(item,line)
			"knot": _draw_knot(item,line)
	for ghost: Dictionary in _ghosts:
		var centre := _knot_centre(ghost.rect)
		Linen.dashed_circle(_body,centre,KNOT_SIZE*0.5*ui_scale,Color(KNOT,0.8*(1.0-Linen.eased(ghost.t))),line,ui_scale)
	# The Unpin tooltip, over everything.
	for item: Dictionary in _items:
		if item.kind == "knot" and _hover_of(item) > 0.0: _draw_tip(item,_hover_of(item))

func _draw_header(item: Dictionary, line: float) -> void:
	var rect := _local(item.rect)
	var baseline := rect.end.y-6.0*ui_scale
	if item.id == "moods":
		var width := _caps(_body,"Moods",Vector2(rect.position.x,baseline),HEAD_TYPE,HEAD_TRACK,Color(Linen.INK,1.0))
		var link := _local(item_rect_content("link","customise"))
		var y := roundf(rect.end.y-9.0*ui_scale)+line*0.5
		_body.draw_line(Vector2(rect.position.x+width+10.0*ui_scale,y),Vector2(link.position.x-6.0*ui_scale,y),Linen.HAIRLINE,line)
	else:
		var link := _local(item_rect_content("link","moods"))
		var x := link.end.x+6.0*ui_scale
		_body.draw_string(_name_font,Vector2(x,baseline+1.0*ui_scale),"·",HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(NAME_TYPE*ui_scale),Color(Linen.INK,0.6))
		x += 10.0*ui_scale
		var title: String = Mood.mood_title(mood.mood)
		_body.draw_string(_name_font,Vector2(x,baseline+1.0*ui_scale),title,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(NAME_TYPE*ui_scale),Linen.INK)

func item_rect_content(kind: String, id: String) -> Rect2:
	for item: Dictionary in _items:
		if item.kind == kind and item.id == id: return item.rect
	return Rect2()

## A caps link, underlined by a hairline when hovered.
func _draw_link(item: Dictionary) -> void:
	var rect := _local(item.rect)
	var h := _hover_of(item)
	var text := {"customise":"Customise","moods":"Moods","swatches":"Swatches"}.get(item.id,str(item.id)) as String
	var type := CHIP_TYPE if item.id == "swatches" else HEAD_TYPE
	var track := CHIP_TRACK if item.id == "swatches" else HEAD_TRACK
	var baseline := rect.end.y-6.0*ui_scale
	if item.id == "swatches": baseline = rect.get_center().y+4.0*ui_scale
	var x := rect.position.x+4.0*ui_scale if item.id != "swatches" else rect.position.x+CHIP_PAD*ui_scale
	var width := _caps(_body,text,Vector2(x,baseline),type,track,Color(Linen.INK,lerpf(0.72,1.0,h)))
	var y := roundf(baseline+3.0*ui_scale)
	_body.draw_line(Vector2(x,y),Vector2(x+width,y),Color(Linen.HAIRLINE,Linen.HAIRLINE.a*lerpf(0.5,1.0,h)),maxf(1.0,roundf(ui_scale)))

## Back to mood: a 5 px dashed ring glyph and caps, at the header's right.
func _draw_back(item: Dictionary, line: float) -> void:
	var rect := _local(item.rect)
	var h := _hover_of(item)
	var baseline := rect.end.y-6.0*ui_scale
	var ink := Color(Linen.INK,lerpf(0.72,1.0,h))
	Linen.dashed_circle(_body,Vector2(rect.position.x+8.0*ui_scale,baseline-4.0*ui_scale),2.5*ui_scale,ink,line,ui_scale*0.75)
	var x := rect.position.x+18.0*ui_scale
	var width := _caps(_body,"Back to mood",Vector2(x,baseline),HEAD_TYPE,HEAD_TRACK,ink)
	var y := roundf(baseline+3.0*ui_scale)
	_body.draw_line(Vector2(x,y),Vector2(x+width,y),Color(Linen.HAIRLINE,Linen.HAIRLINE.a*lerpf(0.5,1.0,h)),line)

func _rule(rect_content: Rect2, line: float) -> void:
	var rect := _local(rect_content)
	var y := roundf(rect.get_center().y)+line*0.5
	Linen.dashed(_body,PackedVector2Array([Vector2(rect.position.x,y),Vector2(rect.end.x,y)]),RULE,line,3.0*ui_scale,3.0*ui_scale)

## A vignette with its edge, drop and inside stitch.
func _draw_vignette(id: String, size_name: String, rect: Rect2, line: float) -> void:
	rect = Rect2(rect.position.round(),rect.size.round())
	_body.draw_rect(Rect2(rect.position+Vector2(0.0,2.0*ui_scale),rect.size),VIGNETTE_DROP)
	_body.draw_rect(rect.grow(line),VIGNETTE_EDGE)
	var texture := _vignette(id,size_name)
	if texture != null: _body.draw_texture_rect(texture,rect,false)
	if size_name != "mini": Linen.dashed(_body,Linen.round_points(rect.grow(-2.0*ui_scale),1.5*ui_scale),VIGNETTE_STITCH,line,2.0*ui_scale,2.0*ui_scale)

func _selected(id: String) -> bool:
	return mood.mood == id

func _draw_world(item: Dictionary, line: float) -> void:
	var rect := _local(item.rect)
	_state_patch(item,rect,_selected(""),9.0)
	var size: Vector2 = Icons.VIGNETTE_SIZES.world*ui_scale
	var at := Vector2(rect.position.x+4.0*ui_scale,rect.get_center().y-size.y*0.5)
	_draw_vignette("","world",Rect2(at,size),line)
	var x := at.x+size.x+12.0*ui_scale
	_caps(_body,"This world",Vector2(x,rect.get_center().y-3.0*ui_scale),CHIP_TYPE,CHIP_TRACK,Linen.INK)
	_body.draw_string(_desc_font,Vector2(x,rect.get_center().y+13.0*ui_scale),Mood.mood_description(""),HORIZONTAL_ALIGNMENT_LEFT,rect.end.x-x,roundi(WORLD_DESC_TYPE*ui_scale),WHISPER_INK)

func _draw_card(item: Dictionary, line: float) -> void:
	var rect := _local(item.rect)
	var id: String = item.id
	_state_patch(item,rect.grow_individual(-2.0*ui_scale,0.0,-2.0*ui_scale,0.0),_selected(id),9.0)
	var size: Vector2 = Icons.VIGNETTE_SIZES.card*ui_scale
	var at := Vector2(rect.get_center().x-size.x*0.5,rect.position.y+CARD_TOP*ui_scale)
	_draw_vignette(id,"card",Rect2(at,size),line)
	var lines := _balanced(Mood.mood_title(id),item.rect.size.x-6.0,CARD_TYPE,CHIP_TRACK)
	var y := at.y+size.y+(CARD_TITLE_GAP+CARD_LINE-3.0)*ui_scale
	if lines.size() == 1: y += CARD_LINE*0.5*ui_scale
	for text: String in lines:
		var w := _caps_width(text,CARD_TYPE,CHIP_TRACK)*ui_scale
		_caps(_body,text,Vector2(roundf(rect.get_center().x-w*0.5),roundf(y)),CARD_TYPE,CHIP_TRACK,Linen.INK)
		y += CARD_LINE*ui_scale

## The hovered mood's (else the current one's) title and description.
func _draw_foot(item: Dictionary) -> void:
	var rect := _local(item.rect)
	var id: String = mood.mood
	var parts := hovered.split(":")
	if parts.size() >= 2 and parts[0] in ["card","world"]: id = parts[1]
	_caps(_body,Mood.mood_title(id),Vector2(rect.position.x,rect.position.y+12.0*ui_scale),CHIP_TYPE,CHIP_TRACK,Linen.INK)
	_body.draw_multiline_string(_desc_font,Vector2(rect.position.x,rect.position.y+32.0*ui_scale),Mood.mood_description(id),HORIZONTAL_ALIGNMENT_LEFT,rect.size.x,roundi(DESC_TYPE*ui_scale),2,WHISPER_INK)

func _draw_mini(item: Dictionary, line: float) -> void:
	var rect := _local(item.rect)
	_state_patch(item,rect,_selected(item.id),MINI_PAD)
	var size: Vector2 = Icons.VIGNETTE_SIZES.mini*ui_scale
	_draw_vignette(item.id,"mini",Rect2(rect.get_center()-size*0.5,size),line)

## A row's label in the label column.
func _draw_row_label(item: Dictionary) -> void:
	var rect := _local(item.rect)
	var baseline := rect.position.y+(CHIP_H*0.5+4.0)*ui_scale
	_caps(_body,ROW_TITLES[item.id],Vector2(rect.position.x+GUTTER*ui_scale,baseline),CHIP_TYPE,CHIP_TRACK,Color(Linen.INK,0.8))

## A chip: the pressed patch when chosen (no stitch), else the stitch, and
## the hover patch.
func _draw_chip(item: Dictionary, line: float, text := "", on: Variant = null) -> void:
	var rect := _local(item.rect)
	var chosen: bool = on if on != null else _chip_chosen(item)
	if text.is_empty(): text = _chip_title(item)
	var h := _hover_of(item)
	if chosen: _patch(rect,CHIP_RADIUS,Linen.PRESSED,Linen.PRESSED_SHADE)
	else:
		if h > 0.0: _patch(rect,CHIP_RADIUS,Color(Linen.HOVER,Linen.HOVER.a*h),Color(Linen.HOVER_SHADE,Linen.HOVER_SHADE.a*h))
		Linen.dashed_round(_body,rect.grow(-line*0.5),CHIP_RADIUS*ui_scale,CHIP_STITCH,line,ui_scale)
	_caps(_body,text,Vector2(rect.position.x+CHIP_PAD*ui_scale,rect.get_center().y+4.0*ui_scale),CHIP_TYPE,CHIP_TRACK,Color(Linen.INK,1.0 if chosen else lerpf(0.82,1.0,h)))

func _chip_title(item: Dictionary) -> String:
	var entries: Array = Mood.WIND_STRENGTHS if item.id == "wind" else Mood.options(item.id)
	for entry: Dictionary in entries:
		if entry.id == item.value: return entry.title
	return str(item.value)

func _chip_chosen(item: Dictionary) -> bool:
	var now: String = mood.value(item.id)
	if item.id == "wind": return Mood.wind_parts(now).get("id","") == item.value
	return now == item.value

## The wind's dial: a stitched ring, the way the wind blows as a needle with a
## knot at its head, north up.
func _draw_dial(item: Dictionary, line: float) -> void:
	var rect := _local(item.rect)
	var centre := rect.get_center()
	var r := rect.size.x*0.5
	var h := maxf(_hover_of(item),1.0 if _drag.get("kind","") == "dial" else 0.0)
	if h > 0.0: _body.draw_circle(centre,r,Color(Linen.HOVER,Linen.HOVER.a*h),true,-1.0,true)
	Linen.dashed_circle(_body,centre,r-line*0.5,Color(Linen.INK,0.45),line,ui_scale)
	var air: Node = scene.get("_atmosphere")
	var angle := deg_to_rad(float(air.direction_angle) if air != null else 0.0)
	var way := Vector2.from_angle(angle)
	var tip := centre+way*(r-4.0*ui_scale)
	_body.draw_line(centre-way*(r-7.0*ui_scale),tip,Color(Linen.INK,0.9),line*1.5,true)
	_knot_dot(tip,2.5*ui_scale,0.0)

## A colour in the two-column list: its label and a 30x16 flat stitched chip.
func _draw_colour(item: Dictionary, line: float) -> void:
	var rect := _local(item.rect)
	var key: String = item.id
	var h := _hover_of(item)
	var open := colour_open == key
	var chip := Rect2(Vector2(rect.end.x-(COLOUR_CHIP.x+4.0)*ui_scale,rect.get_center().y-COLOUR_CHIP.y*0.5*ui_scale),COLOUR_CHIP*ui_scale)
	chip = Rect2(chip.position.round(),chip.size.round())
	if open: _patch(chip.grow(SWATCH_POCKET*ui_scale),6.0,Linen.PRESSED,Linen.PRESSED_SHADE)
	elif h > 0.0: _patch(chip.grow(SWATCH_POCKET*ui_scale),6.0,Color(Linen.HOVER,Linen.HOVER.a*h),Color(Linen.HOVER_SHADE,Linen.HOVER_SHADE.a*h))
	var title := ""
	for entry: Dictionary in Mood.COLORS:
		if entry.id == key: title = entry.title
	_caps(_body,title,Vector2(rect.position.x+GUTTER*ui_scale,rect.get_center().y+4.0*ui_scale),CHIP_TYPE,CHIP_TRACK,Color(Linen.INK,lerpf(0.8,1.0,maxf(h,1.0 if open else 0.0))))
	_flat(chip,Color(mood.value(key)),line)

func _draw_swatch(item: Dictionary, line: float) -> void:
	var rect := _local(item.rect)
	rect = Rect2(rect.position.round(),rect.size.round())
	var colours: Array = Mood.swatches(item.id)
	var colour := str(colours[int(item.value)])
	var chosen: bool = mood.value(item.id) == colour
	var h := _hover_of(item)
	if chosen: _patch(rect.grow(SWATCH_POCKET*ui_scale),6.0,Linen.PRESSED,Linen.PRESSED_SHADE)
	elif h > 0.0: _patch(rect.grow(SWATCH_POCKET*ui_scale),6.0,Color(Linen.HOVER,Linen.HOVER.a*h),Color(Linen.HOVER_SHADE,Linen.HOVER_SHADE.a*h))
	_flat(rect,Color(colour),line)

## Flat colour, as the design stitches it: a dark 1 px edge, the fill, a
## darker foot, and a dashed stitch 2 px inside.
func _flat(rect: Rect2, colour: Color, line: float) -> void:
	_body.draw_rect(rect.grow(line),SWATCH_EDGE)
	_body.draw_rect(rect,colour)
	_body.draw_rect(Rect2(rect.position.x,rect.end.y-1.5*ui_scale,rect.size.x,1.5*ui_scale),SWATCH_FOOT)
	Linen.dashed(_body,Linen.round_points(rect.grow(-2.0*ui_scale),1.0*ui_scale),SWATCH_STITCH,line,2.0*ui_scale,2.0*ui_scale)

## The groove's track, where its knot rides, in viewport or local pixels (a
## rect in the same space as `row`).
func _groove_track(row: Rect2) -> Rect2:
	var inset := GROOVE_KNOT*0.5*ui_scale
	return Rect2(Vector2(row.position.x+inset,row.get_center().y-GROOVE_H*0.5*ui_scale),Vector2(row.size.x-inset*2.0,GROOVE_H*ui_scale))

## One of Mix's grooves: its label, a 12 px stitched groove holding the
## channel's gradient at the other two channels, and the cream knot on it.
func _draw_groove(item: Dictionary, line: float) -> void:
	var row := _local(item.rect)
	var channel := int(item.value)
	_caps(_body,CHANNELS[channel],Vector2(row.position.x-LABEL_W*ui_scale,row.get_center().y+4.0*ui_scale),CHIP_TYPE,CHIP_TRACK,Color(Linen.INK,0.8))
	var track := _groove_track(row)
	var groove := track.grow_individual(GROOVE_H*0.5*ui_scale,0.0,GROOVE_H*0.5*ui_scale,0.0)
	var box := StyleBoxFlat.new()
	box.bg_color = SWATCH_EDGE
	box.set_corner_radius_all(roundi(GROOVE_H*0.5*ui_scale)+1)
	box.anti_aliasing = true
	_body.draw_style_box(box,groove.grow(line))
	# The gradient, in steps, clipped to the rounded groove by its end caps.
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	for s in range(GROOVE_STEPS+1):
		var t := float(s)/GROOVE_STEPS
		var hsv := _hsv
		hsv[channel] = t
		var c := Color.from_hsv(hsv.x,hsv.y,hsv.z)
		var x := lerpf(track.position.x,track.end.x,t)
		points.append_array([Vector2(x,track.position.y),Vector2(x,track.end.y)])
		colours.append_array([c,c])
	for s in range(GROOVE_STEPS):
		var quad := PackedVector2Array([points[s*2],points[s*2+2],points[s*2+3],points[s*2+1]])
		_body.draw_polygon(quad,PackedColorArray([colours[s*2],colours[s*2+2],colours[s*2+3],colours[s*2+1]]))
	var r := GROOVE_H*0.5*ui_scale
	var start := _hsv
	start[channel] = 0.0
	var end := _hsv
	end[channel] = 1.0
	_body.draw_circle(Vector2(track.position.x,track.get_center().y),r,Color.from_hsv(start.x,start.y,start.z),true,-1.0,true)
	_body.draw_circle(Vector2(track.end.x,track.get_center().y),r,Color.from_hsv(end.x,end.y,end.z),true,-1.0,true)
	_body.draw_rect(Rect2(track.position,Vector2(track.size.x,1.5*ui_scale)),SWATCH_FOOT)
	Linen.dashed_round(_body,groove.grow(-2.0*ui_scale),maxf(r-2.0*ui_scale,1.0),SWATCH_STITCH,line,ui_scale)
	var h := maxf(_hover_of(item),1.0 if _drag.get("kind","") == "groove" and int(_drag.value) == channel else 0.0)
	_knot_dot(Vector2(lerpf(track.position.x,track.end.x,_hsv[channel]),track.get_center().y),GROOVE_KNOT*0.5*ui_scale,lerpf(KNOT_HALO_REST,KNOT_HALO_HOVER,h)*ui_scale)

func _knot_centre(rect_content: Rect2) -> Vector2:
	var rect := _local(rect_content)
	return Vector2(rect.position.x+(3.0+GUTTER*0.3)*ui_scale,rect.get_center().y).round()

func _draw_knot(item: Dictionary, line: float) -> void:
	var h := _hover_of(item)
	_knot_dot(_knot_centre(item.rect),KNOT_SIZE*0.5*ui_scale,lerpf(KNOT_HALO_REST,KNOT_HALO_HOVER,h)*ui_scale)

## A cream knot of radius `r` with its halo `halo` wide, its drop under it and
## the shade along its foot.
func _knot_dot(centre: Vector2, r: float, halo: float) -> void:
	if halo > 0.0: _body.draw_circle(centre,r+halo,KNOT_HALO,true,-1.0,true)
	_body.draw_circle(centre+Vector2(0.0,1.0*ui_scale),r,KNOT_DROP,true,-1.0,true)
	_body.draw_circle(centre,r,KNOT,true,-1.0,true)
	_body.draw_arc(centre,r-0.5*ui_scale,0.2*PI,0.8*PI,10,KNOT_SHADE,1.0*ui_scale,true)

## "Unpin", on a small dark patch up and right of the knot.
func _draw_tip(item: Dictionary, alpha: float) -> void:
	var centre := _knot_centre(item.rect)
	var size := roundi(12.0*ui_scale)
	var width := _name_font.get_string_size("Unpin",HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var rect := Rect2(centre+Vector2(8.0*ui_scale,-22.0*ui_scale),Vector2(width+12.0*ui_scale,17.0*ui_scale))
	rect = Rect2(rect.position.round(),rect.size.round())
	Linen.fill_round(_body,rect,4.0*ui_scale,Color(TIP,TIP.a*alpha))
	_body.draw_string(_name_font,Vector2(rect.position.x+6.0*ui_scale,rect.end.y-5.0*ui_scale),"Unpin",HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(Linen.INK,alpha))

## The pressed patch when `on`, else the hover patch as far as hovered.
func _state_patch(item: Dictionary, rect: Rect2, on: bool, radius: float) -> void:
	if on: _patch(rect,radius,Linen.PRESSED,Linen.PRESSED_SHADE)
	else:
		var h := _hover_of(item)
		if h > 0.0: _patch(rect,radius,Color(Linen.HOVER,Linen.HOVER.a*h),Color(Linen.HOVER_SHADE,Linen.HOVER_SHADE.a*h))

## 4c's pressed patch (hud_linen `pressed_patch`) at any radius, design px.
func _patch(rect: Rect2, radius: float, patch: Color, shade: Color) -> void:
	if patch.a <= 0.0: return
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

# --- Type -------------------------------------------------------------------------

## Faked small caps (capitals at CAPS of `type`, tracked `track` em) drawn at
## `baseline_at` in local pixels. Returns the letters' width (the trailing
## tracking left off).
func _caps(item: CanvasItem, text: String, baseline_at: Vector2, type: float, track: float, colour: Color) -> float:
	text = text.to_upper()
	var size := maxi(6,roundi(type*CAPS*ui_scale))
	_caps_font.spacing_glyph = roundi(track*type*ui_scale)
	item.draw_string(_caps_font,baseline_at.round(),text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,colour)
	return _caps_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x-_caps_font.spacing_glyph

## The same width in design pixels.
func _caps_width(text: String, type: float, track: float) -> float:
	text = text.to_upper()
	var size := maxi(6,roundi(type*CAPS*ui_scale))
	_caps_font.spacing_glyph = roundi(track*type*ui_scale)
	return (_caps_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x-_caps_font.spacing_glyph)/ui_scale

## `text` on one line if it fits `width` design pixels, else two lines split
## where the longer is shortest (balanced).
func _balanced(text: String, width: float, type: float, track: float) -> PackedStringArray:
	if _caps_width(text,type,track) <= width: return PackedStringArray([text])
	var words := text.split(" ")
	var best := PackedStringArray([text])
	var best_w := INF
	for i in range(1,words.size()):
		var a := " ".join(words.slice(0,i))
		var b := " ".join(words.slice(i))
		var w := maxf(_caps_width(a,type,track),_caps_width(b,type,track))
		if w < best_w:
			best_w = w
			best = PackedStringArray([a,b])
	return best
