extends Node
## The gamepad in the shell (docs/gamepad.md): what the pad does in each
## place the game can be, read through the named actions of scripts/pad.gd.
## The keyboard and mouse are never switched off; whichever was used last
## names the prompts.
##
## - **Building** (the world, no screen up): the left stick moves a soft
##   cursor that stands for the mouse. It eases in, speeds up while held, and
##   rests on the land: once it stops it keeps to the land point under it
##   while the camera orbits or zooms and the world turns. It moves the
##   system pointer and sends the pointer's own events, so the hand
##   (scripts/hand_reach.gd), the roll, the case, the almanac and the first
##   steps' card take A as a left press and its hold as a drag, and X held as
##   Shift. The right stick orbits (scripts/camera_rig.gd `orbit_pixels`), the
##   triggers zoom toward the cursor, the shoulders step the tool on the roll,
##   the D-pad's left and right step the case's specimens and its up and down
##   the size. B puts down what is in hand; held, it undoes. Y steps the tool's
##   mode; held, it redoes. View steps into the walker's eyes where the cursor
##   is (as V); held, watch mode. L3 photo mode, R3 the overview, Menu the
##   pause.
## - **Walking and flying** are the wanderer's own (scripts/wanderer_eye.gd);
##   Menu pauses from there too.
## - **Photo mode** takes the sticks and triggers (scripts/photo_mode.gd
##   `pad_step`) and its keys' verbs from the face buttons.
## - **Watch mode**: any button comes back.
## - **Screens**: the front page, the pause panel, the field notes and the
##   Settings dialog are focus-driven; the pad's A and B are in ui_accept and
##   ui_cancel. The library and the New world panel speak keys, so the pad's
##   moves are handed to them as the keys they already read, and the library's
##   action row, links and delete card take real focus on the pad. A stitched
##   ring (`FocusRing`) shows the focus while the pad is in hand.
##
## Made by studies/cozy_worlds.gd once the shell is up.

const Pad = preload("res://scripts/pad.gd")
const Linen = preload("res://scripts/hud_linen.gd")
## The cursor: screen heights a second at a full push, the share of that it
## starts at, and the seconds it takes to come up to full speed.
const CURSOR_SPEED := 0.75
const CURSOR_START := 0.4
const CURSOR_RAMP := 0.6
## Pixels the cursor follows its land point by before it sends a move.
const ANCHOR_SLACK := 0.5
## The orbit: screen heights of drag a second at a full push, side to side
## and up and down (a screen height is a full turn), and the zoom's factor a
## second at a full pull.
const ORBIT := 0.24
const TILT := 0.1
const ZOOM := 2.2
## A press held this long is a hold (B undoes, Y redoes, View watches).
const HOLD := 0.5
## A second press within this many milliseconds and pixels is a double click.
const DOUBLE_MS := 350
const DOUBLE_PIXELS := 14.0
## Photo mode: the left stick pans this many screen heights a second (walks
## WALK m a second in the ground eye), the right turns at TURN of a drag's
## screen height, the triggers dolly DOLLY notches a second.
const PHOTO_PAN := 0.5
const PHOTO_WALK := 1.6
const PHOTO_TURN := 0.5
const PHOTO_DOLLY := 6.0

var scene: Node3D
## The cursor, viewport pixels, and whether the pad has moved it yet.
var cursor := Vector2.ZERO
var _placed := false
## The land point the resting cursor keeps to (terrain-local), or null.
var _anchor: Variant = null
var _held_for := 0.0
var _pressing := false
var _last_press_ms := -100000
var _last_press_at := Vector2.INF
var _shift := false
## Buttons with a tap and a hold: action -> seconds held (-1 once the hold fired).
var _holds := {}
var _hid_pointer := false
var _context := ""
var _layer: CanvasLayer
var reticle: Control
var ring: Control
## Library: -1 on the strip of worlds, 0 the action row, 1 the links.
var _library_line := -1
var _library_at := 0
## Pushes the library has taken this session, for tests.
var counts := {}

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	name = "PadInput"
	Pad.ensure()
	_layer = CanvasLayer.new()
	_layer.layer = 96
	add_child(_layer)
	reticle = Reticle.new()
	reticle.pad = self
	_layer.add_child(reticle)
	ring = FocusRing.new()
	ring.pad = self
	_layer.add_child(ring)
	get_tree().root.window_input.connect(_window_input)
	Pad.hub.device_changed.connect(_device_changed)

func _exit_tree() -> void:
	if get_tree().root.window_input.is_connected(_window_input): get_tree().root.window_input.disconnect(_window_input)
	if Pad.hub.device_changed.is_connected(_device_changed): Pad.hub.device_changed.disconnect(_device_changed)

## Where the game is, for the pad: "world", "eye", "photo", "watch", "front",
## "library", "new_world", "pause", "notes", "settings", or "" before the shell.
func context() -> String:
	if scene == null or not scene.get("shell_ready"): return ""
	var settings: Window = scene.get("_settings")
	if settings != null and settings.visible: return "settings"
	var fresh: Control = scene.get("new_world_panel")
	if fresh != null and fresh.visible: return "new_world"
	var title: Control = scene.get("world_title")
	if scene.get("titled"): return "library" if scene.get("library_open") and title != null and title.visible else "front"
	var pause: Control = scene.get("pause_panel")
	if pause != null and pause.is_open: return "pause"
	var notes: Control = scene.get("field_notes")
	if notes != null and notes.is_open: return "notes"
	if scene._menu != null and scene._menu.visible: return "front"
	var eye: Node = scene.get("wanderer")
	if eye != null and eye.active: return "eye"
	var photo: Node = scene.get("photo")
	if photo != null and photo.active: return "photo"
	var watch: Node = scene.get("watch")
	if watch != null and watch.active: return "watch"
	return "world" if scene._has_world else ""

# --- Devices ------------------------------------------------------------------------

func _window_input(event: InputEvent) -> void:
	Pad.note(event)
	# The mouse moved by hand: the cursor goes where it is.
	if event is InputEventMouseMotion and event.device != Pad.PAD_DEVICE:
		cursor = event.position
		_anchor = null

func _device_changed(pad: bool) -> void:
	if not pad:
		_release_pad_focus()
		_show_pointer()

# --- Events -----------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion): return
	_context = context()
	var used := false
	match _context:
		"world": used = _world_event(event)
		"eye":
			if Pad.pressed(event,"menu"):
				scene.show_menu()
				used = true
		"photo": used = _photo_event(event)
		"watch":
			if event is InputEventJoypadButton and event.pressed: scene.watch.leave()
			used = true
		"front": used = _front_event(event)
		"pause":
			if Pad.pressed(event,"menu"):
				scene.pause_panel._resume()
				used = true
			# Only up and down step the panel; nothing behind it takes focus.
			used = used or event.is_action("ui_left") or event.is_action("ui_right")
		"library": used = _library_event(event)
		"new_world": used = _new_world_event(event)
	if used: get_viewport().set_input_as_handled()

## Building. Every pad event is taken, so no control's focus moves under it.
func _world_event(event: InputEvent) -> bool:
	if Pad.pressed(event,"build_press"): _press(true)
	elif Pad.released(event,"build_press"): _press(false)
	elif Pad.pressed(event,"build_shift"): _set_shift(true)
	elif Pad.released(event,"build_shift"): _set_shift(false)
	elif Pad.pressed(event,"build_put_down"): _holds["build_put_down"] = 0.0
	elif Pad.released(event,"build_put_down"): _release_hold("build_put_down")
	elif Pad.pressed(event,"build_mode"): _holds["build_mode"] = 0.0
	elif Pad.released(event,"build_mode"): _release_hold("build_mode")
	elif Pad.pressed(event,"step_in"): _holds["step_in"] = 0.0
	elif Pad.released(event,"step_in"): _release_hold("step_in")
	elif Pad.pressed(event,"build_tool_prev"): _materials_call("cycle_tool",-1)
	elif Pad.pressed(event,"build_tool_next"): _materials_call("cycle_tool",1)
	elif Pad.pressed(event,"build_material_prev"): _materials_call("cycle_material",-1)
	elif Pad.pressed(event,"build_material_next"): _materials_call("cycle_material",1)
	elif Pad.pressed(event,"build_size_up"): _size(1)
	elif Pad.pressed(event,"build_size_down"): _size(-1)
	elif Pad.pressed(event,"photo"): scene.enter_photo()
	elif Pad.pressed(event,"overview"):
		if scene.camera_rig != null: scene.camera_rig.overview()
	elif Pad.pressed(event,"menu"):
		_let_go()
		if scene.mood_open(): scene.toggle_mood()
		else: scene.show_menu()
	return true

func _materials() -> Node:
	var reach: Node = scene.get("hand_reach")
	return reach.materials if reach != null else null

func _materials_call(method: String, way: int) -> void:
	var materials := _materials()
	if materials != null and not _pressing: materials.call(method,way)

func _size(way: int) -> void:
	var materials := _materials()
	if materials != null and materials.roll != null: materials.set_size(materials.roll.size_level+way)

## A tap (released before HOLD) of a button with a hold.
func _release_hold(action: String) -> void:
	var held: float = _holds.get(action,-1.0)
	_holds.erase(action)
	if held < 0.0: return
	match action:
		"build_put_down": _put_down()
		"build_mode": _materials_call("step_mode",1)
		"step_in":
			var eye: Node = scene.get("wanderer")
			if eye != null:
				_let_go()
				eye.summon(cursor if _placed else scene.get_viewport().get_mouse_position())

## Held past HOLD: B undoes, Y redoes, View watches.
func _fire_hold(action: String) -> void:
	_holds[action] = -1.0
	match action:
		"build_put_down":
			scene._chunk_editor.undo()
			Pad.pulse(0.25,0.0,0.08)
		"build_mode":
			scene._chunk_editor.redo()
			Pad.pulse(0.25,0.0,0.08)
		"step_in":
			_let_go()
			scene.toggle_watch()

## B: a page, the palette or the moods close as Esc closes them; else what is
## in hand goes down. Nothing at all with nothing in hand.
func _put_down() -> void:
	var materials := _materials()
	if scene.mood_open():
		scene.toggle_mood()
		return
	if materials != null and ((materials.pages != null and materials.pages.is_open()) or (materials.palette != null and materials.palette.is_open())):
		bridge_key(KEY_ESCAPE)
		return
	if materials != null and not _pressing: materials.put_down()

# --- The cursor ------------------------------------------------------------------------

func _process(delta: float) -> void:
	_context = context()
	for action: String in _holds.keys():
		if float(_holds[action]) < 0.0: continue
		_holds[action] = float(_holds[action])+delta
		if float(_holds[action]) >= HOLD: _fire_hold(action)
	match _context:
		"world": _world_frame(delta)
		"photo": _photo_frame(delta)
		"settings": _settings_frame()
		"front": _front_frame()
	if _context != "world":
		if _pressing: _press(false)
		if _shift: _set_shift(false)
		_holds.clear()
		_show_pointer()
	if _context != "library": _library_line = -1

func _world_frame(delta: float) -> void:
	var view := scene.get_viewport()
	var screen := view.get_visible_rect().size
	if not _placed:
		cursor = view.get_mouse_position()
		if not Rect2(Vector2.ZERO,screen).has_point(cursor) or cursor == Vector2.ZERO: cursor = screen*0.5
	var push := Pad.curve(Pad.stick("cursor_left","cursor_right","cursor_up","cursor_down"))
	if push != Vector2.ZERO:
		_held_for += delta
		var speed := CURSOR_SPEED*screen.y*lerpf(CURSOR_START,1.0,smoothstep(0.0,CURSOR_RAMP,_held_for))
		_move_to((cursor+push*speed*delta).clamp(Vector2.ZERO,screen-Vector2.ONE))
		_anchor = null
	else:
		_held_for = 0.0
		_keep_to_land()
	var rig: Node = scene.get("camera_rig")
	if rig != null and rig.live:
		var look := Pad.curve(Pad.stick("look_left","look_right","look_up","look_down"),1.6)
		if look != Vector2.ZERO:
			rig.turn.stop()
			rig.orbit_pixels(Vector2(look.x*ORBIT,look.y*TILT)*screen.y*delta)
		var zoom := Pad.trigger("zoom_out")-Pad.trigger("zoom_in")
		if absf(zoom) > 0.0: rig.zoom_at(cursor,pow(ZOOM,zoom*delta))
	if Pad.using_pad() and _placed: _hide_pointer()

## Puts the cursor at `at` and tells the pointer: the system's moves there,
## and its motion event (with the press and Shift held) goes round.
func _move_to(at: Vector2) -> void:
	var step := at-cursor
	cursor = at
	_placed = true
	if step.length() < 0.01: return
	if DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE) and scene.get_window().has_focus():
		scene.get_viewport().warp_mouse(cursor)
	var motion := InputEventMouseMotion.new()
	motion.device = Pad.PAD_DEVICE
	motion.position = cursor
	motion.global_position = cursor
	motion.relative = step
	motion.screen_relative = step
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if _pressing else 0
	motion.shift_pressed = _shift
	Input.parse_input_event(motion)

## The resting cursor keeps to the land point under it while the view moves.
func _keep_to_land() -> void:
	if not _placed or _pressing: return
	var editor: Node = scene.get("_chunk_editor")
	if editor == null: return
	var materials := _materials()
	if _anchor == null:
		if materials != null and materials.tray_under(cursor): return
		_anchor = editor.pick(cursor)
		return
	var camera: Camera3D = scene.camera
	var at: Vector3 = editor.terrain.to_global(_anchor)
	if camera.is_position_behind(at): return
	var screen := camera.unproject_position(at)
	var size := scene.get_viewport().get_visible_rect().size
	if not Rect2(Vector2.ZERO,size).has_point(screen):
		_anchor = null
		return
	if screen.distance_to(cursor) > ANCHOR_SLACK: _move_to(screen)

## A: the left button at the cursor. A second press soon after, near the
## first, is a double click (the camera glides there).
func _press(down: bool) -> void:
	if down == _pressing: return
	_pressing = down
	if not _placed:
		cursor = scene.get_viewport().get_mouse_position()
		_placed = true
	var button := InputEventMouseButton.new()
	button.device = Pad.PAD_DEVICE
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = down
	button.position = cursor
	button.global_position = cursor
	button.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	button.shift_pressed = _shift
	if down:
		var now := Time.get_ticks_msec()
		button.double_click = now-_last_press_ms <= DOUBLE_MS and cursor.distance_to(_last_press_at) <= DOUBLE_PIXELS
		_last_press_ms = -100000 if button.double_click else now
		_last_press_at = cursor
		var editor: Node = scene.get("_chunk_editor")
		if editor != null and editor.pick(cursor) != null: Pad.pulse(0.12,0.0,0.05)
	Input.parse_input_event(button)

func _let_go() -> void:
	if _pressing: _press(false)

## X held is Shift, for everything that reads it (thinning, plucking, a turn
## that does not wind time).
func _set_shift(down: bool) -> void:
	if down == _shift: return
	_shift = down
	var key := InputEventKey.new()
	key.device = Pad.PAD_DEVICE
	key.keycode = KEY_SHIFT
	key.physical_keycode = KEY_SHIFT
	key.pressed = down
	Input.parse_input_event(key)

func _hide_pointer() -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE: return
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_hid_pointer = true

func _show_pointer() -> void:
	if not _hid_pointer: return
	_hid_pointer = false
	if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## A key the screens already read, pressed and let go, marked as the pad's.
static func bridge_key(code: Key, shift := false) -> void:
	for down: bool in [true,false]:
		var key := InputEventKey.new()
		key.device = Pad.PAD_DEVICE
		key.keycode = code
		key.physical_keycode = code
		key.shift_pressed = shift
		key.pressed = down
		Input.parse_input_event(key)

# --- Photo and watch ------------------------------------------------------------------

func _photo_frame(delta: float) -> void:
	var photo: Node = scene.photo
	var move := Pad.curve(Pad.stick("cursor_left","cursor_right","cursor_up","cursor_down"))
	var look := Pad.curve(Pad.stick("look_left","look_right","look_up","look_down"),1.6)
	var dolly := Pad.trigger("zoom_out")-Pad.trigger("zoom_in")
	if move == Vector2.ZERO and look == Vector2.ZERO and dolly == 0.0: return
	var height := scene.get_viewport().get_visible_rect().size.y
	photo.pad_step(move*(PHOTO_WALK if photo.ground else PHOTO_PAN*height)*delta,look*PHOTO_TURN*height*delta,dolly*PHOTO_DOLLY*delta)

## Photo mode's buttons are its keys' verbs.
func _photo_event(event: InputEvent) -> bool:
	var keys := {"photo_capture":KEY_SPACE,"photo_leave":KEY_ESCAPE,"photo_ground":KEY_G,"photo_focus":KEY_F,
		"photo_lens_prev":KEY_BRACKETLEFT,"photo_lens_next":KEY_BRACKETRIGHT,"photo_clean":KEY_H,"photo_reset":KEY_R}
	for action: String in keys:
		if Pad.pressed(event,action):
			bridge_key(keys[action])
			return true
	if Pad.pressed(event,"photo_exposure_up"): bridge_key(KEY_BRACKETRIGHT,true)
	elif Pad.pressed(event,"photo_exposure_down"): bridge_key(KEY_BRACKETLEFT,true)
	elif Pad.pressed(event,"menu"):
		scene.photo.leave()
		scene.show_menu()
	return true

# --- Screens ----------------------------------------------------------------------------

## The front page: Godot's focus walks its entries. With none focused, the
## first push of the pad focuses the first.
func _front_event(event: InputEvent) -> bool:
	var focus := scene.get_viewport().gui_get_focus_owner()
	if focus == null and event.is_pressed() and (event.is_action("ui_up") or event.is_action("ui_down") or event.is_action("ui_accept")):
		_front_frame()
		return true
	return false

func _front_frame() -> void:
	if not Pad.using_pad() or scene.get_viewport().gui_get_focus_owner() != null: return
	for button: Node in scene._menu.find_children("*","Button",true,false):
		if button.is_visible_in_tree() and not button.disabled and button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus()
			return

## The Settings dialog: with the pad, every row can be reached (the sound's
## rows keep out of the mouse's focus), and the first takes the focus if
## nothing holds it.
func _settings_frame() -> void:
	if not Pad.using_pad(): return
	var dialog: Window = scene._settings
	var first: Control = null
	for node: Node in dialog.find_children("*","Control",true,false):
		if not (node is BaseButton or node is Range): continue
		if node.focus_mode == Control.FOCUS_NONE: node.focus_mode = Control.FOCUS_ALL
		if first == null and node.is_visible_in_tree(): first = node
	if first != null and dialog.gui_get_focus_owner() == null: first.grab_focus()

## The library: the pad's moves are the keys it reads (left and right
## browse, A enters, B goes back), up lifts focus onto the action row and
## then the links, X starts a new world, and on the delete card left and
## right choose and A presses (Keep it first, so one press never deletes).
func _library_event(event: InputEvent) -> bool:
	var title: Control = scene.world_title
	var accept := Pad.pressed(event,"ui_accept")
	var cancel := Pad.pressed(event,"ui_cancel")
	var left := event.is_action_pressed("ui_left",true)
	var right := event.is_action_pressed("ui_right",true)
	var up := event.is_action_pressed("ui_up")
	var down := event.is_action_pressed("ui_down")
	if title.mode == "delete":
		var card: Array = [title.keep_button,title.let_go_button]
		var focus := scene.get_viewport().gui_get_focus_owner()
		if not focus in card: _pad_focus(title.keep_button)
		if left or right: _pad_focus(card[1 if right else 0])
		elif accept:
			var pressed: BaseButton = scene.get_viewport().gui_get_focus_owner()
			_release_pad_focus()
			pressed.pressed.emit()
		elif cancel:
			_release_pad_focus()
			bridge_key(KEY_ESCAPE)
		return true
	if title.mode == "rename":
		if accept: bridge_key(KEY_ENTER)
		elif cancel: bridge_key(KEY_ESCAPE)
		return true
	var lines := _library_lines(title)
	if _library_line < 0:
		if left or right: bridge_key(KEY_RIGHT if right else KEY_LEFT)
		elif accept: bridge_key(KEY_ENTER)
		elif cancel: bridge_key(KEY_ESCAPE)
		elif Pad.pressed(event,"library_new"): title.new_world_requested.emit()
		elif up and not lines[0].is_empty(): _library_go(0,0)
		return true
	var line: Array = lines[_library_line]
	if left or right: _library_go(_library_line,clampi(_library_at+(1 if right else -1),0,line.size()-1))
	elif up and _library_line == 0: _library_go(1,0)
	elif down and _library_line == 1 and not lines[0].is_empty(): _library_go(0,0)
	elif down or cancel:
		_library_line = -1
		_release_pad_focus()
	elif accept:
		var pressed: BaseButton = line[_library_at]
		_library_line = -1
		_release_pad_focus()
		pressed.pressed.emit()
	return true

## The library's focus lines: the selected world's action row, and the
## Settings and Back links.
func _library_lines(title: Control) -> Array:
	var row: Array = [title.enter_button,title.rename_button,title.duplicate_button,title.delete_button].filter(func(button: Control) -> bool: return button.visible)
	return [row,[title.settings_button,title.quit_button]]

func _library_go(line: int, at: int) -> void:
	var lines := _library_lines(scene.world_title)
	if lines[line].is_empty(): return
	_library_line = line
	_library_at = clampi(at,0,lines[line].size()-1)
	_pad_focus(lines[line][_library_at])
	counts["library_focus"] = int(counts.get("library_focus",0))+1

## New world: the pad's moves are the panel's keys (up and down the lands,
## left and right the kind, A begins, B goes back); X rolls a new seed and Y
## goes to the name.
func _new_world_event(event: InputEvent) -> bool:
	var panel: Control = scene.new_world_panel
	if Pad.pressed(event,"ui_accept"): bridge_key(KEY_ENTER)
	elif Pad.pressed(event,"ui_cancel"): bridge_key(KEY_ESCAPE)
	elif event.is_action_pressed("ui_up",true) or event.is_action_pressed("ui_down",true):
		bridge_key(KEY_DOWN if event.is_action("ui_down") else KEY_UP)
	elif event.is_action_pressed("ui_left",true) or event.is_action_pressed("ui_right",true):
		if panel.name_edit.has_focus(): panel.name_edit.release_focus()
		bridge_key(KEY_RIGHT if event.is_action("ui_right") else KEY_LEFT)
	elif Pad.pressed(event,"new_world_roll"): panel.roll()
	elif Pad.pressed(event,"new_world_name"): panel.name_edit.grab_focus()
	return true

## Focus a control the screens keep out of focus, for the pad only: it is
## made focusable for as long as it holds it.
func _pad_focus(control: Control) -> void:
	_release_pad_focus()
	if control.focus_mode == Control.FOCUS_NONE:
		control.focus_mode = Control.FOCUS_ALL
		control.set_meta("pad_focus",true)
	control.grab_focus()

func _release_pad_focus() -> void:
	if scene == null or not scene.is_inside_tree(): return
	var focus := scene.get_viewport().gui_get_focus_owner()
	if focus != null and focus.has_meta("pad_focus"):
		focus.release_focus()
		focus.focus_mode = Control.FOCUS_NONE
		focus.remove_meta("pad_focus")

# --- Drawing --------------------------------------------------------------------------

## The pad's cursor in the world: a small stitched ring round a soft dot, in
## the linen's thread, where the hand reaches.
class Reticle extends Control:
	var pad: Node
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
	func _process(_delta: float) -> void:
		visible = Pad.using_pad() and pad._context == "world" and pad._placed
		if visible: queue_redraw()
	func _draw() -> void:
		var px := Linen.hud_scale_for(get_viewport_rect().size)
		var at: Vector2 = pad.cursor
		var r := (9.0 if pad._pressing else 11.0)*px
		draw_circle(at,r+4.0*px,Color(0.078,0.055,0.031,0.18),true,-1.0,true)
		Linen.dashed_circle(self,at,r,Color(Linen.INK,0.9),maxf(1.0,1.5*px),px)
		draw_circle(at,2.2*px,Color(Linen.INK,0.95),true,-1.0,true)
		if pad._shift: draw_arc(at,r+3.0*px,0.0,TAU,32,Color(Linen.INK,0.5),maxf(1.0,px),true)

## The focus, while the pad is in hand: a soft lift and a stitched ring
## round whatever control holds it on the screens.
class FocusRing extends Control:
	var pad: Node
	var _alpha := 0.0
	var _rect := Rect2()
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
	func target() -> Control:
		if not Pad.using_pad() or not pad._context in ["front","library","new_world","pause","notes"]: return null
		var focus := get_viewport().gui_get_focus_owner()
		if focus == null or not focus.is_visible_in_tree(): return null
		# Not round a control faded out (the card under the library) or not
		# yet faded in.
		var item: Node = focus
		var alpha := 1.0
		while item is CanvasItem:
			alpha *= (item as CanvasItem).modulate.a
			item = item.get_parent()
		return focus if alpha >= 0.1 else null
	func _process(delta: float) -> void:
		var focus := target()
		_alpha = move_toward(_alpha,1.0 if focus != null else 0.0,delta/0.15)
		if focus != null:
			var goal := focus.get_global_rect()
			_rect = goal if _rect.size == Vector2.ZERO else Rect2(_rect.position.lerp(goal.position,minf(1.0,delta*18.0)),_rect.size.lerp(goal.size,minf(1.0,delta*18.0)))
		queue_redraw()
	func _draw() -> void:
		if _alpha <= 0.0 or _rect.size == Vector2.ZERO: return
		var px := Linen.scale_for(get_viewport_rect().size)
		var box := _rect.grow(6.0*px)
		var a := Linen.eased(_alpha)
		Linen.fill_round(self,box,8.0*px,Color(1.0,0.941,0.843,0.07*a))
		Linen.dashed_round(self,box,8.0*px,Color(Linen.INK,0.85*a),maxf(1.0,1.5*px),px)
