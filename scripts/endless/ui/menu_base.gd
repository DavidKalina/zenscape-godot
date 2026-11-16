extends Control
## What the flight UI's menus share (docs/design/ui/spec-flight-ui.md, the
## mock-up docs/design/ui/mock/Main.dc.html): a list of rows on a slip with
## the selection's times, the keyboard, mouse and pad navigation, the footer
## prompts, the toast, and a page opened over the menu. The title
## (title_menu.gd), the pause menu (pause_menu.gd) and the pages
## (controls_page.gd, credits_page.gd) extend it and draw themselves with
## the kit (ui_kit.gd).
##
## Navigation: Up / Down, W / S, the d-pad or the stick move the selection
## (`move`); Enter, Space or the pad's A pick (`pick`); Esc or the pad's B
## go back (`back`); the mouse selects the row it moves over and picks the
## one it clicks.
##
## A page is a Control with `setup(host)` and a `closed` signal: `open_page`
## adds it over the menu, whose slip stays hidden until it closes.
## `open_settings` is the one way into the settings page.

const Kit = preload("res://scripts/endless/ui/ui_kit.gd")
const Pad = preload("res://scripts/pad.gd")
const StickSteps = preload("res://scripts/endless/ui/stick_steps.gd")

## The game's name, as the title and the credits show it. The one place.
const GAME_NAME := "ZENSCAPE"
## The credits' "a game by" line.
const GAME_BY := "[YOUR NAME]"
## The settings page (lane settings). Until it is there, a toast.
const SETTINGS_PAGE := "res://scripts/endless/ui/settings_page.gd"
## The hangar's page (loaded when opened: it preloads this file's own kit).
const HANGAR_PAGE := "res://scripts/endless/ui/hangar_page.gd"
## How long a toast shows (s), and its fade at the end.
const TOAST_S := 2.4
const TOAST_FADE := 0.3
## The footer's prompts, as `Kit.pick` triples [keys, pad, word].
const P_SELECT := ["Up Down","D-pad","select"]
const P_CHOOSE := ["Enter","A","choose"]
const P_BACK := ["Esc","B","back"]

## The game (studies/endless_flight.gd), or null.
var host: Node
## The rows: {id, label, key (a quiet hint at the right, for the keyboard),
## pad (the same, for the pad), gap (mock px before it)}.
var rows: Array = []
var sel := 0
## Taking input.
var active := true
## The page over this menu, or null.
var page: Control
## Seconds since the slip was shown (its arrival runs off it).
var age := 0.0
var _sel_t := PackedFloat32Array()
var _rects: Array[Rect2] = []
var _toast := ""
var _toast_t := 0.0
var _closed_frame := -1
var _stick := StickSteps.new()

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The pause menu runs while the tree is held, and its pages with it.
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	Pad.hub.device_changed.connect(_device_changed)

func _exit_tree() -> void:
	if Pad.hub.device_changed.is_connected(_device_changed): Pad.hub.device_changed.disconnect(_device_changed)

func _device_changed(_pad: bool) -> void:
	queue_redraw()

## The one scale of the new UI here.
func k() -> float:
	return Kit.scale_of(size)

# --- The selection -----------------------------------------------------------------------

## Selects row `i`: its band and tick run in, the one before leans back.
## With `snap` it is there at once.
func select(i: int, snap := false) -> void:
	if rows.is_empty(): return
	i = clampi(i,0,rows.size()-1)
	if _sel_t.size() != rows.size():
		_sel_t.resize(rows.size())
		_sel_t.fill(Kit.OFF)
	if snap:
		_sel_t.fill(Kit.OFF)
		_sel_t[i] = Kit.ON
	elif i != sel or _sel_t[i] < 0.0:
		if sel < _sel_t.size() and _sel_t[sel] >= 0.0: _sel_t[sel] = -0.001
		_sel_t[i] = 0.0
	sel = i
	queue_redraw()

## The slip shown anew: its arrival and the selection's run-in start over.
func arrive(at := 0) -> void:
	age = 0.0
	_sel_t.resize(rows.size())
	_sel_t.fill(Kit.OFF)
	sel = clampi(at,0,maxi(rows.size()-1,0))
	if not rows.is_empty(): _sel_t[sel] = 0.0
	queue_redraw()

## The id of the row selected.
func selected_id() -> String:
	return str(rows[sel].id) if sel < rows.size() else ""

## Up or down by one, round the ends.
func move(step: int) -> void:
	if rows.is_empty(): return
	select(posmod(sel+step,rows.size()))

## Row `i` picked. Override.
func pick(_i: int) -> void:
	pass

## Esc or the pad's B. Override.
func back() -> void:
	pass

## An event the navigation did not take; true if used. Override.
func other_input(_event: InputEvent) -> bool:
	return false

## One frame while visible, after the times moved on. Override.
func tick(_delta: float) -> void:
	pass

## True while this menu, not a page over it, reads the input.
func taking() -> bool:
	return active and page == null and is_visible_in_tree() and Engine.get_process_frames() != _closed_frame

func _process(delta: float) -> void:
	# The stick steps only after it has been let go under this menu.
	if not taking(): _stick.rest()
	if not is_visible_in_tree(): return
	age += delta
	var moving := age < 0.3
	for i in _sel_t.size():
		var t := _sel_t[i]
		if absf(t) > 0.5: continue
		_sel_t[i] = t+delta if t >= 0.0 else t-delta
		moving = true
	if _toast_t > 0.0:
		_toast_t -= delta
		moving = true
	if moving: queue_redraw()
	if taking():
		var lean := _stick.step(delta)
		if lean.y != 0: move(lean.y)
	tick(delta)

func _input(event: InputEvent) -> void:
	if not taking(): return
	if event is InputEventMouseMotion:
		var over := row_at(_local(event))
		if over >= 0 and over != sel: select(over)
		return
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if not b.pressed: return
		var over := row_at(_local(event)) if b.button_index == MOUSE_BUTTON_LEFT else -1
		if over >= 0:
			_taken()
			select(over)
			pick(over)
		elif other_input(event): _taken()
		return
	# The stick's leans are steps in `_process` (stick_steps.gd): each of its
	# motion events past the dead zone would read as a press here.
	if StickSteps.is_stick(event): return
	var step := 0
	if event.is_action_pressed(&"ui_up",true) or _is_key(event,KEY_W): step = -1
	elif event.is_action_pressed(&"ui_down",true) or _is_key(event,KEY_S): step = 1
	if step != 0:
		_taken()
		move(step)
	elif event.is_action_pressed(&"ui_accept"):
		_taken()
		pick(sel)
	elif event.is_action_pressed(&"ui_cancel"):
		_taken()
		back()
	elif other_input(event): _taken()

func _taken() -> void:
	get_viewport().set_input_as_handled()

func _local(event: InputEvent) -> Vector2:
	return (make_input_local(event) as InputEventMouse).position

## A key pressed (its repeats too), by its label or its place on the board.
func _is_key(event: InputEvent, code: Key) -> bool:
	var key := event as InputEventKey
	return key != null and key.pressed and (key.keycode == code or (key.keycode == KEY_NONE and key.physical_keycode == code))

## The row under `at` (this control's px), or -1.
func row_at(at: Vector2) -> int:
	for i in _rects.size():
		if _rects[i].has_point(at): return i
	return -1

# --- Drawing -----------------------------------------------------------------------------

## The rows' height on a slip, in mock px, each `h` tall with its gap.
func rows_height(h: float) -> float:
	var out := 0.0
	for r: Dictionary in rows: out += h+float(r.get("gap",0.0))
	return out

## The rows down `slip` from screen `y`, each `h` mock px tall, their rects
## kept for the mouse. Returns the y under the last.
func draw_rows(slip: Rect2, y: float, s: float, h: float, px: float, key_pad: float, a := 1.0) -> float:
	_rects.clear()
	var pad := Pad.using_pad()
	for i in rows.size():
		var r: Dictionary = rows[i]
		y += float(r.get("gap",0.0))*s
		var key := str(r.get("pad","")) if pad else str(r.get("key",""))
		_rects.append(Kit.row(self,slip,y,s,str(r.label),_sel_t[i] if i < _sel_t.size() else Kit.OFF,h,px,key,key_pad,a))
		y += h*s
	return y

## The footer's prompts, lower right, for the device last used.
func draw_footer(triples: Array, s: float, a := 1.0) -> void:
	Kit.prompts(self,Kit.pick(triples),size-Vector2(28.0,50.0)*s,s,true,false,a)

## A line on a dark chip, lower left, for TOAST_S s.
func say(text: String) -> void:
	_toast = text
	_toast_t = TOAST_S
	queue_redraw()

func draw_toast(s: float) -> void:
	if _toast_t <= 0.0 or _toast.is_empty(): return
	var a := clampf(_toast_t/TOAST_FADE,0.0,1.0)
	Kit.chip(self,[Kit.part(_toast,Kit.MED,12.0,0.08,Kit.TOAST)],Vector2(72.0*s,size.y-54.0*s),s,24.0,12.0,20.0,false,a)

# --- Pages -------------------------------------------------------------------------------

## Opens `p` (a Control with `setup(host)` and a `closed` signal) over this
## menu; the slip is hidden until it closes.
func open_page(p: Control) -> void:
	if page != null: return
	page = p
	p.setup(host if host != null else self)
	add_child(p)
	p.closed.connect(_page_closed.bind(p),CONNECT_ONE_SHOT)
	queue_redraw()

func _page_closed(p: Control) -> void:
	if page == p: page = null
	p.queue_free()
	# The key that closed the page is not this menu's too.
	_closed_frame = Engine.get_process_frames()
	arrive(sel)

## The settings page (lane settings): the title's and the pause menu's
## Settings rows both come here.
func open_settings() -> void:
	if ResourceLoader.exists(SETTINGS_PAGE): open_page((load(SETTINGS_PAGE) as GDScript).new())
	else: say("Settings: coming")

## The hangar (hangar_page.gd), where the plane's look is set: the title's
## and the pause menu's Hangar rows both come here.
func open_hangar() -> void:
	open_page((load(HANGAR_PAGE) as GDScript).new())
