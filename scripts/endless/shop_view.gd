extends Control
## The shop's overlay (shop_sites.gd opens it on its strip; the game's
## `overlay` while up): the stock by slot (shop_stock.gd), each with its
## price or whether it is owned or worn, and the money. The choice is tried
## on the plane standing by. Keys: W S or the arrows (the pad's stick or
## d-pad) choose, Enter (the pad's X) buys or wears, Esc (B) leaves;
## Boost takes off, and that leaves too (shop_sites.gd).

const ShopStock = preload("res://scripts/endless/shop_stock.gd")
const Pad = preload("res://scripts/pad.gd")
const WORDS = preload("res://assets/fonts/newsreader-latin.woff2")
const NUMS = preload("res://assets/fonts/barlow-semi-condensed-800-latin.woff2")

const GOLD := Color("ffd36b")
const CREAM := Color("f6f3ea")
const DIM := Color(0.96,0.95,0.92,0.55)
const LOST := Color("ff8a6b")
const INK := Color(0.07,0.06,0.05,0.78)
const WIDE := 440.0

var book: RefCounted
var figure: Node3D
var _leave: Callable
## The rows in order: [{id, slot, row: Control, price: Label, mark: Label}].
var _rows: Array = []
var chosen := 0
var _money: Label
var _note: Label
var _note_left := 0.0
var _words := {}

func setup(b: RefCounted, f: Node3D, leave: Callable) -> void:
	book = b
	figure = f
	_leave = leave

func _ready() -> void:
	name = "ShopView"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = INK
	box.set_corner_radius_all(6)
	box.content_margin_left = 26.0
	box.content_margin_right = 26.0
	box.content_margin_top = 20.0
	box.content_margin_bottom = 18.0
	box.border_color = Color(GOLD,0.55)
	box.border_width_left = 2
	panel.add_theme_stylebox_override("panel",box)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -WIDE-48.0
	panel.offset_right = -48.0
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation",4)
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := _label("The Shop",_word(34.0,0.02),CREAM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_money = _label("",NUMS,GOLD,34)
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_money)
	for slot: String in ShopStock.SLOTS:
		var sec := _label(String(ShopStock.SLOT_NAMES.get(slot,slot)).to_upper(),_word(15.0,0.18),DIM)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0,8)
		col.add_child(gap)
		col.add_child(sec)
		for i: Dictionary in ShopStock.items(slot):
			col.add_child(_row(i))
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0,6)
	col.add_child(gap2)
	_note = _label("",_word(17.0,0.0),LOST)
	col.add_child(_note)
	var hint := _label(Pad.pick("W S choose  ·  Enter buy or wear  ·  Esc leave  ·  Space take off",
		"Stick choose  ·  X buy or wear  ·  B leave  ·  A take off"),_word(15.0,0.0),DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(hint)
	# Start on what is worn.
	var worn := ShopStock.worn(book,ShopStock.SLOTS[0])
	for k in _rows.size():
		if _rows[k].id == worn: chosen = k
	_refresh()

func _row(i: Dictionary) -> Control:
	var row := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0,0,0,0)
	box.set_corner_radius_all(4)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 3.0
	box.content_margin_bottom = 3.0
	row.add_theme_stylebox_override("panel",box)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation",12)
	row.add_child(line)
	line.add_child(_swatch(i))
	var nm := _label(String(i.name),_word(22.0,0.0),CREAM)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(nm)
	var mark := _label("",_word(16.0,0.12),GOLD)
	line.add_child(mark)
	var price := _label("",NUMS,GOLD,22)
	price.custom_minimum_size = Vector2(56,0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(price)
	_rows.append({"id":i.id,"slot":i.slot,"row":row,"box":box,"price":price,"mark":mark,"name":nm})
	return row

## The item's colours side by side.
func _swatch(i: Dictionary) -> Control:
	var cols: Array = []
	if i.has("livery"):
		var l: Dictionary = i.livery
		cols = [l.get("body",Color.WHITE),l.get("trim",Color.WHITE),l.get("wing",Color.WHITE)]
	elif i.has("colours"): cols = i.colours
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation",0)
	strip.custom_minimum_size = Vector2(42,18)
	if cols.is_empty():
		var none := ColorRect.new()
		none.color = Color(1,1,1,0.12)
		none.custom_minimum_size = Vector2(42,18)
		strip.add_child(none)
	for c: Color in cols:
		var r := ColorRect.new()
		r.color = c
		r.custom_minimum_size = Vector2(42.0/cols.size(),18)
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		strip.add_child(r)
	return strip

func _label(text: String, font: Font, colour: Color, px := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font",font)
	if px > 0: l.add_theme_font_size_override("font_size",px)
	elif _words.has(font): l.add_theme_font_size_override("font_size",int(_words[font]))
	l.add_theme_color_override("font_color",colour)
	l.add_theme_color_override("font_shadow_color",Color(0,0,0,0.5))
	l.add_theme_constant_override("shadow_offset_y",1)
	return l

## Newsreader 700 at `px`, tracked `track` em.
func _word(px: float, track: float) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = WORDS
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):700}
	f.spacing_glyph = roundi(px*track)
	_words[f] = roundi(px)
	return f

func _process(delta: float) -> void:
	# Over a CanvasLayer the anchors alone leave it no size: the screen's.
	var screen := get_viewport_rect().size
	if size != screen:
		position = Vector2.ZERO
		size = screen
	if _note_left > 0.0:
		_note_left -= delta
		if _note_left <= 0.0: _note.text = ""

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_W, KEY_UP: choose(-1)
			KEY_S, KEY_DOWN: choose(1)
			KEY_ENTER, KEY_KP_ENTER: act()
			KEY_ESCAPE: leave()
			_: return
		get_viewport().set_input_as_handled()
	elif Pad.pressed(event,&"move_forward"):
		choose(-1)
		get_viewport().set_input_as_handled()
	elif Pad.pressed(event,&"move_back"):
		choose(1)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_DPAD_UP: choose(-1)
			JOY_BUTTON_DPAD_DOWN: choose(1)
			JOY_BUTTON_X: act()
			JOY_BUTTON_B: leave()
			_: return
		get_viewport().set_input_as_handled()

func choose(by: int) -> void:
	chosen = wrapi(chosen+by,0,_rows.size())
	_refresh()

## The chosen item worn, bought first if it is not had (when the money
## stretches).
func act() -> void:
	var r: Dictionary = _rows[chosen]
	var id: String = r.id
	if not ShopStock.has(book,id):
		var price := int(ShopStock.item(id).price)
		if not ShopStock.buy(book,id):
			_say("%d short" % (price-int(book.money)))
			return
	book.wear(r.slot,id)
	_refresh()

func leave() -> void:
	if _leave.is_valid(): _leave.call()

func _say(text: String) -> void:
	_note.text = text
	_note_left = 1.6

func _refresh() -> void:
	_money.text = "%d" % int(book.money)
	var try := {}
	for k in _rows.size():
		var r: Dictionary = _rows[k]
		var id: String = r.id
		var had := ShopStock.has(book,id)
		var on := ShopStock.worn(book,r.slot) == id
		var price := int(ShopStock.item(id).price)
		(r.price as Label).text = "" if had else "%d" % price
		(r.price as Label).add_theme_color_override("font_color",GOLD if price <= int(book.money) else LOST)
		(r.mark as Label).text = "WORN" if on else ("OWNED" if had and price > 0 else "")
		(r.box as StyleBoxFlat).bg_color = Color(GOLD,0.2) if k == chosen else Color(0,0,0,0)
		(r.box as StyleBoxFlat).border_color = GOLD
		var edge := 1 if k == chosen else 0
		(r.box as StyleBoxFlat).border_width_left = edge*3
		if k == chosen: try[r.slot] = id
	# Tried on: the chosen item, the rest as worn.
	ShopStock.dress(figure,book,try)

## The chosen row's item id (for drivers).
func chosen_id() -> String:
	return String(_rows[chosen].id)
