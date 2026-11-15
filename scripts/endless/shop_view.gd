extends Control
## The shop's overlay (shop_sites.gd opens it on its strip; the game's
## `overlay` while up): the stock by slot (shop_stock.gd) as a shelf of cards
## along the screen's foot (ui/shop_shelf.gd draws it), the plane standing by
## wearing the choice. Keys: A D or W S or the arrows (the pad's stick or
## d-pad) choose, Q E (the bumpers) change section, Enter (the pad's X) buys
## or wears, Esc (B) leaves; Boost takes off, and that leaves too
## (shop_sites.gd).

const ShopStock = preload("res://scripts/endless/shop_stock.gd")
const Shelf = preload("res://scripts/endless/ui/shop_shelf.gd")
const StickSteps = preload("res://scripts/endless/ui/stick_steps.gd")

var book: RefCounted
var figure: Node3D
var _leave: Callable
## The cards in order: [{id, slot, s, pulse}] (the shelf eases `s` to 1 on the
## chosen one and runs `pulse` down after a buy).
var rows: Array = []
var chosen := 0
var _shelf: Control

func setup(b: RefCounted, f: Node3D, leave: Callable) -> void:
	book = b
	figure = f
	_leave = leave

func _ready() -> void:
	name = "ShopView"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for slot: String in ShopStock.SLOTS:
		for i: Dictionary in ShopStock.items(slot):
			rows.append({"id":i.id,"slot":i.slot,"s":0.0,"pulse":0.0})
	# Start on what is worn.
	var worn := ShopStock.worn(book,ShopStock.SLOTS[0])
	for k in rows.size():
		if rows[k].id == worn:
			chosen = k
			rows[k].s = 1.0
	_shelf = Shelf.new()
	_shelf.view = self
	add_child(_shelf)
	_refresh()

var _stick := StickSteps.new()

func _process(delta: float) -> void:
	# Over a CanvasLayer the anchors alone leave it no size: the screen's.
	var screen := get_viewport_rect().size
	if size != screen:
		position = Vector2.ZERO
		size = screen
	# The stick: one card a lean, then repeats while held (stick_steps.gd).
	var lean := _stick.step(delta)
	if lean.y != 0: choose(lean.y)
	elif lean.x != 0: choose(lean.x)

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_W, KEY_UP, KEY_A, KEY_LEFT: choose(-1)
			KEY_S, KEY_DOWN, KEY_D, KEY_RIGHT: choose(1)
			KEY_Q: choose_slot_by(-1)
			KEY_E, KEY_TAB: choose_slot_by(1)
			KEY_ENTER, KEY_KP_ENTER: act()
			KEY_ESCAPE: leave()
			_: return
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_LEFT: choose(-1)
			JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT: choose(1)
			JOY_BUTTON_LEFT_SHOULDER: choose_slot_by(-1)
			JOY_BUTTON_RIGHT_SHOULDER: choose_slot_by(1)
			JOY_BUTTON_X: act()
			JOY_BUTTON_B: leave()
			_: return
		get_viewport().set_input_as_handled()

func choose(by: int) -> void:
	choose_to(wrapi(chosen+by,0,rows.size()))

func choose_to(index: int) -> void:
	chosen = clampi(index,0,rows.size()-1)
	_refresh()

## The next (or previous) section: its worn item chosen.
func choose_slot_by(by: int) -> void:
	var at := ShopStock.SLOTS.find(rows[chosen].slot)
	choose_slot(ShopStock.SLOTS[wrapi(at+by,0,ShopStock.SLOTS.size())])

func choose_slot(slot: String) -> void:
	if rows[chosen].slot == slot: return
	var worn := ShopStock.worn(book,slot)
	for k in rows.size():
		if rows[k].id == worn:
			choose_to(k)
			return

## The chosen item worn, bought first if it is not had (when the money
## stretches).
func act() -> void:
	var r: Dictionary = rows[chosen]
	var id: String = r.id
	if not ShopStock.has(book,id):
		if not ShopStock.buy(book,id):
			if _shelf != null: _shelf.shake = 1.0
			return
		r.pulse = 1.0
	book.wear(r.slot,id)
	_refresh()

func leave() -> void:
	if _leave.is_valid(): _leave.call()

func _refresh() -> void:
	# Tried on: the chosen item, the rest as worn.
	ShopStock.dress(figure,book,{rows[chosen].slot:rows[chosen].id})

## The chosen card's item id (for drivers).
func chosen_id() -> String:
	return String(rows[chosen].id)
