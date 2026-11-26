extends Control
## The settings page (docs/design/ui/mock/Main.dc.html, the Settings screen):
## a slip down the left with Graphics, Sound and Controls, each row a setting
## of scripts/endless/ui/game_settings.gd, changed and kept the moment it is
## touched.
##
##     var page: Control = preload("res://scripts/endless/ui/settings_page.gd").new()
##     page.setup(self)                    # before it enters the tree
##     page.closed.connect(_settings_closed)
##     layer.add_child(page)
##
## The contract with whoever opens it:
## - It fills the viewport, draws its own wash over what is under it, and
##   runs while the tree is paused. It does not pause the tree: the host does.
## - While up it takes every key, mouse and pad event in `_input` (marked
##   handled) and shows the mouse; on leaving it puts the mouse mode back.
## - `closed` is emitted once when the player leaves (Esc, B, or Back), then
##   it frees itself.
## - If the graphics preset was changed, the flight starts again on it after
##   `closed` (GameSettings.restart: the tree unpaused, the scene opened
##   again, behind its title if the scene's `stage` is up), as F3 does.
##
## Keys: Up Down or W S select, Left Right or A D change, Enter or Space
## steps a row's options or takes Back, Esc leaves. Mouse: pointing selects,
## a click picks an option, a click or drag sets a slider. Pad: the d-pad or
## left stick, A, B.

signal closed

const Kit = preload("res://scripts/endless/ui/ui_kit.gd")
const Pad = preload("res://scripts/pad.gd")
const GameSettings = preload("res://scripts/endless/ui/game_settings.gd")
const StickSteps = preload("res://scripts/endless/ui/stick_steps.gd")

## The rows, top to bottom: a heading, a row that picks one of `opts`, a
## slider, or Back. `id` is the setting's name in GameSettings.
const ROWS: Array[Dictionary] = [
	{"head":"Graphics"},
	{"id":"preset","label":"Preset","opts":["Performance","Quality","Full"]},
	{"id":"grass","label":"Grass","opts":["Ultra","High","Medium","Low"]},
	{"id":"scale","label":"3D resolution","opts":["100%","85%","75%","67%"]},
	{"id":"dynamic","label":"Dynamic resolution","opts":["On","Off"]},
	{"id":"display","label":"Display","opts":["Fullscreen","Windowed"]},
	{"id":"vsync","label":"VSync","opts":["On","Off"]},
	{"id":"lock60","label":"Locked 60","opts":["On","Off"]},
	{"head":"Sound"},
	{"id":"master","label":"Master","slider":true},
	{"id":"effects","label":"Effects","slider":true},
	{"id":"ambience","label":"Ambience","slider":true},
	{"head":"Controls"},
	{"id":"mouse","label":"Mouse sensitivity","slider":true},
	{"id":"invert","label":"Invert pitch","opts":["On","Off"]},
	{"id":"hints","label":"HUD hints","opts":["On","Off"]},
	{"back":true},
]
## The mock-up's measures (px in its 1280x800 frame).
const SLIP_AT := Vector2(72.0,150.0)
const SLIP_W := 452.0
const PAD_TOP := 8.0
const PAD_FOOT := 12.0
const HEAD_H := 30.0
const ROW_H := 28.0
const BACK_H := 30.0
const BACK_GAP := 8.0
const WASH_T := 0.2
## The footer's prompts: keys, pad, word.
const FOOT := [["Up Down","D-pad","select"],["Left Right","Left Right","change"],["Esc","B","back"]]

## Whoever opened it (the flight, a menu).
var host: Node
## The row selected: an index into ROWS.
var sel := 1
var _sel_t := PackedFloat32Array()
var _on_t := PackedFloat32Array()
var _on := PackedInt32Array()
var _age := 0.0
var _drag := -1
var _stick := StickSteps.new()
var _mouse_was := Input.MOUSE_MODE_VISIBLE
var _closing := false

## Call before it enters the tree.
func setup(by: Node) -> void:
	host = by

func _init() -> void:
	name = "SettingsPage"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sel_t.resize(ROWS.size())
	_on_t.resize(ROWS.size())
	_on.resize(ROWS.size())
	for i in ROWS.size():
		_sel_t[i] = 0.0 if i == sel else Kit.OFF
		_on_t[i] = Kit.ON
		_on[i] = -1

func _enter_tree() -> void:
	_mouse_was = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not Pad.hub.device_changed.is_connected(_device_changed): Pad.hub.device_changed.connect(_device_changed)
	if not GameSettings.hub.changed.is_connected(_setting_changed): GameSettings.hub.changed.connect(_setting_changed)
	for i in ROWS.size():
		if ROWS[i].has("opts"): _on[i] = GameSettings.index(str(ROWS[i]["id"]))

func _exit_tree() -> void:
	if Pad.hub.device_changed.is_connected(_device_changed): Pad.hub.device_changed.disconnect(_device_changed)
	if GameSettings.hub.changed.is_connected(_setting_changed): GameSettings.hub.changed.disconnect(_setting_changed)

func _device_changed(_pad: bool) -> void:
	queue_redraw()

func _setting_changed(_key: String) -> void:
	queue_redraw()

# --- The rows ----------------------------------------------------------------------------

static func is_row(i: int) -> bool:
	return i >= 0 and i < ROWS.size() and not ROWS[i].has("head")

## The id of the row selected ("back" on Back).
func selected() -> String:
	return "back" if ROWS[sel].has("back") else str(ROWS[sel]["id"])

## Selects row `i` of ROWS (a heading is not a row).
func select(i: int) -> void:
	if not is_row(i) or i == sel: return
	_sel_t[sel] = -0.0001
	sel = i
	_sel_t[i] = 0.0
	queue_redraw()

## The row `n` rows down (up when negative) from the one selected, round the ends.
func move(n: int) -> void:
	var i := sel
	for _s in absi(n):
		i = posmod(i+signi(n),ROWS.size())
		while not is_row(i): i = posmod(i+signi(n),ROWS.size())
	select(i)

## Left or Right on the row selected: the option before or after (it stops
## at the ends), a slider one step.
func change(dir: int) -> void:
	var row := ROWS[sel]
	if row.has("back"): return
	var id := str(row["id"])
	if row.has("slider"):
		GameSettings.nudge(id,dir)
	else:
		var n := (row["opts"] as Array).size()
		var to := clampi(GameSettings.index(id)+dir,0,n-1)
		if to != GameSettings.index(id): GameSettings.pick(id,to)
	queue_redraw()

## Enter on the row selected: Back leaves, a row of options steps to its
## next (round the end).
func accept() -> void:
	var row := ROWS[sel]
	if row.has("back"):
		close()
	elif row.has("opts"):
		var id := str(row["id"])
		GameSettings.pick(id,(GameSettings.index(id)+1)%(row["opts"] as Array).size())
		queue_redraw()

## Leaves: `closed`, the page freed, and the flight again if the preset changed.
func close() -> void:
	if _closing: return
	_closing = true
	_drag = -1
	Input.mouse_mode = _mouse_was
	var tree := get_tree()
	closed.emit()
	queue_free()
	if tree == null or not GameSettings.preset_pending(): return
	var scene := tree.current_scene
	if scene == null or scene.scene_file_path.is_empty(): return
	# Behind its title again if the title is up (the flight's `stage`).
	var title := "stage" in scene and scene.get("stage") != null
	GameSettings.restart(tree,scene.scene_file_path,title)

# --- Layout ------------------------------------------------------------------------------

func _k() -> float:
	return Kit.scale_of(size)

## The slip at rest, on whole pixels.
func slip_rect() -> Rect2:
	var k := _k()
	var h := PAD_TOP+PAD_FOOT
	for row: Dictionary in ROWS:
		h += HEAD_H if row.has("head") else (BACK_GAP+BACK_H if row.has("back") else ROW_H)
	return Rect2((SLIP_AT*k).round(),Vector2(roundf(SLIP_W*k),roundf(h*k)))

## The top of row `i` of ROWS, in screen px.
func row_top(i: int) -> float:
	var k := _k()
	var y := SLIP_AT.y+PAD_TOP
	for j in ROWS.size():
		var row := ROWS[j]
		if row.has("back"): y += BACK_GAP
		if j == i: break
		y += HEAD_H if row.has("head") else (BACK_H if row.has("back") else ROW_H)
	return roundf(SLIP_AT.y*k)+(y-SLIP_AT.y)*k

## The rect of row `i` (what pointing at it hits).
func row_rect(i: int) -> Rect2:
	return Kit.row_rect(slip_rect(),row_top(i),_k(),BACK_H if ROWS[i].has("back") else ROW_H)

## The rects of a row's options, for a click.
func option_rects(i: int) -> Array[Rect2]:
	var row := ROWS[i]
	return Kit.seg_rects(slip_rect(),row_top(i),_k(),PackedStringArray(row["opts"] as Array),GameSettings.index(str(row["id"])),ROW_H)

## A slider row's track, for a click or a drag.
func track_rect(i: int) -> Rect2:
	return Kit.slider_rect(slip_rect(),row_top(i),_k(),ROW_H)

func _row_at(at: Vector2) -> int:
	for i in ROWS.size():
		if is_row(i) and row_rect(i).has_point(at): return i
	return -1

# --- Time and drawing --------------------------------------------------------------------

func _process(delta: float) -> void:
	_age += delta
	var moving := _age < maxf(Kit.T_SLIP,WASH_T)+0.1 or _drag >= 0
	for i in ROWS.size():
		if not is_row(i): continue
		# A row's selection is a time (the kit's sel_t): up from 0 while
		# selected, down from 0 once not, at rest past half a second.
		var t := _sel_t[i]
		if i == sel: t = Kit.ON if t > 0.5 else maxf(t,0.0)+delta
		else: t = Kit.OFF if t < -0.5 else minf(t,0.0)-delta
		_sel_t[i] = t
		if absf(t) < 0.6: moving = true
		if not ROWS[i].has("opts"): continue
		# The option shown is the game's own state, read each frame: a change
		# from anywhere (a key under the page, a window the system moved)
		# shows, and its underline runs in.
		var now := GameSettings.index(str(ROWS[i]["id"]))
		if now != _on[i]:
			_on[i] = now
			_on_t[i] = 0.0
		_on_t[i] = Kit.ON if _on_t[i] > 0.5 else _on_t[i]+delta
		if _on_t[i] < 0.6: moving = true
	_step_stick(delta)
	if moving: queue_redraw()

func _draw() -> void:
	var k := _k()
	var arrive := Kit.slip_in(_age)
	var a := arrive.y
	draw_rect(Rect2(Vector2.ZERO,size),Color(Kit.NIGHT,Kit.WASH_A*clampf(_age/WASH_T,0.0,1.0)))
	var slip := slip_rect()
	slip.position.x -= roundf(arrive.x*k)
	Kit.slip(self,slip,k,a)
	for i in ROWS.size():
		var row := ROWS[i]
		var y := row_top(i)
		if row.has("head"):
			Kit.head(self,slip,y,k,str(row["head"]),HEAD_H,6.0,38.0,a)
		elif row.has("back"):
			Kit.row(self,slip,y,k,"Back",_sel_t[i],BACK_H,15.0,"B" if Pad.using_pad() else "Esc",42.0,a)
		elif row.has("slider"):
			var id := str(row["id"])
			Kit.slider_row(self,slip,y,k,str(row["label"]),GameSettings.frac(id),GameSettings.shown(id),_sel_t[i],ROW_H,15.0,a)
		else:
			Kit.seg_row(self,slip,y,k,str(row["label"]),PackedStringArray(row["opts"] as Array),maxi(_on[i],0),_sel_t[i],_on_t[i],ROW_H,15.0,a)
	Kit.prompts(self,Kit.pick(FOOT),size-Vector2(28.0,50.0)*k,k,true,false,a)

# --- Input -------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _closing or not is_visible_in_tree(): return
	# Kept from before the event is acted on: leaving can start the flight
	# again, which takes the page out of the tree at once.
	var view := get_viewport()
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed: _key(key.keycode,key.echo)
	elif event is InputEventMouseMotion:
		_point((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed: _click(button.position)
			else: _drag = -1
	elif event is InputEventJoypadButton:
		var joy := event as InputEventJoypadButton
		if joy.pressed: _button(joy.button_index)
	elif event is InputEventJoypadMotion:
		# The left stick is read as steps in `_step_stick`; its events stop here.
		pass
	else: return
	if view != null: view.set_input_as_handled()

func _key(code: Key, echo: bool) -> void:
	match code:
		KEY_UP, KEY_W: move(-1)
		KEY_DOWN, KEY_S: move(1)
		KEY_LEFT, KEY_A: change(-1)
		KEY_RIGHT, KEY_D: change(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if not echo: accept()
		KEY_ESCAPE:
			if not echo: close()

func _button(index: JoyButton) -> void:
	match index:
		JOY_BUTTON_DPAD_UP: move(-1)
		JOY_BUTTON_DPAD_DOWN: move(1)
		JOY_BUTTON_DPAD_LEFT: change(-1)
		JOY_BUTTON_DPAD_RIGHT: change(1)
		JOY_BUTTON_A: accept()
		JOY_BUTTON_B: close()

## The left stick as steps: one when it leans, then repeats while held
## (stick_steps.gd).
func _step_stick(delta: float) -> void:
	if _closing or not is_visible_in_tree():
		_stick.rest()
		return
	var dir := _stick.step(delta)
	if dir.y != 0: move(dir.y)
	elif dir.x != 0: change(dir.x)

func _point(at: Vector2) -> void:
	if _drag >= 0:
		GameSettings.slide(str(ROWS[_drag]["id"]),Kit.slider_frac(track_rect(_drag),at.x))
		queue_redraw()
		return
	var i := _row_at(at)
	if i >= 0: select(i)

func _click(at: Vector2) -> void:
	var i := _row_at(at)
	if i < 0: return
	select(i)
	var row := ROWS[i]
	var k := _k()
	if row.has("back"):
		close()
	elif row.has("slider"):
		var track := track_rect(i)
		if at.x < track.position.x-8.0*k or at.x > track.end.x+8.0*k: return
		_drag = i
		_point(at)
	else:
		var rects := option_rects(i)
		for o in rects.size():
			if rects[o].grow_individual(8.0*k,0.0,8.0*k,0.0).has_point(at):
				GameSettings.pick(str(row["id"]),o)
				queue_redraw()
				return
