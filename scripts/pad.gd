extends RefCounted
## The gamepad's named actions and the device last used (docs/gamepad.md).
## Every pad read in the game goes through an action in the InputMap, named
## for what it does, so a remap (or Steam Input) moves it in one place; the
## keys a verb already had are in the same action where the code polls it
## (walking, flying), and stay with their own handlers elsewhere.
##
## `ensure` adds any action the project does not define yet, and gives the
## GUI's ui_accept and ui_cancel the pad's A and B, so focus, menus and
## popups take them. An action already in the InputMap (project.godot, or a
## remap) is left as it is.
##
## `note` is handed every input event (scripts/pad_input.gd, from the root
## window's `window_input`): a pad's press or a stick pushed past NOTICE makes
## the pad the device in use; a key, a click or the mouse moving makes it the
## keyboard and mouse again. Prompts read `using_pad` and listen on
## `hub.device_changed`; nothing has to be switched by hand.
##
## Feel lives here too: the sticks' dead zone (DEAD), a response curve for the
## cursor and the camera (`curve`), and a small rumble (`pulse`) that the
## Settings dialog's "Controller vibration" turns off (user://pad.cfg).

## Radial dead zone of the sticks, and the triggers'.
const DEAD := 0.18
const TRIGGER_DEAD := 0.1
## A stick or trigger must pass this to count as the pad being picked up.
const NOTICE := 0.45
## The mouse must move this many pixels at once to count as picked up; a
## pad's cursor moves the system pointer by its own events, marked PAD_DEVICE.
const MOUSE_NOTICE := 3.0
## The device id the cursor's synthesized pointer events carry, so they are
## not taken for the mouse.
const PAD_DEVICE := 0x5ad
const SETTINGS_PATH := "user://pad.cfg"

## An action's events: ["key", physical keycode], ["button", JoyButton] or
## ["axis", JoyAxis, direction]. One table, read by `ensure`, the prompts and
## docs/gamepad.md.
const ACTIONS := {
	# Walking and flying: WASD or the arrows, or the left stick.
	"move_left":[["key",KEY_A],["key",KEY_LEFT],["axis",JOY_AXIS_LEFT_X,-1.0]],
	"move_right":[["key",KEY_D],["key",KEY_RIGHT],["axis",JOY_AXIS_LEFT_X,1.0]],
	"move_forward":[["key",KEY_W],["key",KEY_UP],["axis",JOY_AXIS_LEFT_Y,-1.0]],
	"move_back":[["key",KEY_S],["key",KEY_DOWN],["axis",JOY_AXIS_LEFT_Y,1.0]],
	# The right stick looks: round the walker's eyes, the plane, the build
	# view's orbit and photo mode's.
	"look_left":[["axis",JOY_AXIS_RIGHT_X,-1.0]],
	"look_right":[["axis",JOY_AXIS_RIGHT_X,1.0]],
	"look_up":[["axis",JOY_AXIS_RIGHT_Y,-1.0]],
	"look_down":[["axis",JOY_AXIS_RIGHT_Y,1.0]],
	"walk_jump":[["key",KEY_SPACE],["button",JOY_BUTTON_A]],
	"eye_leave":[["button",JOY_BUTTON_B],["button",JOY_BUTTON_BACK]],
	"fly_boost":[["key",KEY_SPACE],["button",JOY_BUTTON_A],["axis",JOY_AXIS_TRIGGER_RIGHT,1.0]],
	"fly_brake":[["key",KEY_SHIFT],["axis",JOY_AXIS_TRIGGER_LEFT,1.0]],
	"fly_lean_left":[["button",JOY_BUTTON_LEFT_SHOULDER]],
	"fly_lean_right":[["button",JOY_BUTTON_RIGHT_SHOULDER]],
	"fly_land":[["button",JOY_BUTTON_Y]],
	"fly_camera":[["button",JOY_BUTTON_RIGHT_STICK]],
	# The old glider (--glider): rise and dive, and its flap.
	"glide_rise":[["key",KEY_SPACE],["button",JOY_BUTTON_A],["axis",JOY_AXIS_TRIGGER_LEFT,1.0]],
	"glide_dive":[["key",KEY_SHIFT],["axis",JOY_AXIS_TRIGGER_RIGHT,1.0]],
	"glide_flap":[["button",JOY_BUTTON_X]],
	# Building: the left stick moves the hand's cursor (pad only: the keys
	# keep their own verbs), the triggers zoom.
	"cursor_left":[["axis",JOY_AXIS_LEFT_X,-1.0]],
	"cursor_right":[["axis",JOY_AXIS_LEFT_X,1.0]],
	"cursor_up":[["axis",JOY_AXIS_LEFT_Y,-1.0]],
	"cursor_down":[["axis",JOY_AXIS_LEFT_Y,1.0]],
	"build_press":[["button",JOY_BUTTON_A]],
	"build_put_down":[["button",JOY_BUTTON_B]],
	"build_shift":[["button",JOY_BUTTON_X]],
	"build_mode":[["button",JOY_BUTTON_Y]],
	"build_tool_prev":[["button",JOY_BUTTON_LEFT_SHOULDER]],
	"build_tool_next":[["button",JOY_BUTTON_RIGHT_SHOULDER]],
	"build_material_prev":[["button",JOY_BUTTON_DPAD_LEFT]],
	"build_material_next":[["button",JOY_BUTTON_DPAD_RIGHT]],
	"build_size_up":[["button",JOY_BUTTON_DPAD_UP]],
	"build_size_down":[["button",JOY_BUTTON_DPAD_DOWN]],
	"zoom_in":[["axis",JOY_AXIS_TRIGGER_RIGHT,1.0]],
	"zoom_out":[["axis",JOY_AXIS_TRIGGER_LEFT,1.0]],
	"step_in":[["button",JOY_BUTTON_BACK]],
	"photo":[["button",JOY_BUTTON_LEFT_STICK]],
	"overview":[["button",JOY_BUTTON_RIGHT_STICK]],
	"menu":[["button",JOY_BUTTON_START]],
	# Photo mode.
	"photo_capture":[["button",JOY_BUTTON_A]],
	"photo_leave":[["button",JOY_BUTTON_B]],
	"photo_ground":[["button",JOY_BUTTON_X]],
	"photo_focus":[["button",JOY_BUTTON_Y]],
	"photo_lens_prev":[["button",JOY_BUTTON_LEFT_SHOULDER]],
	"photo_lens_next":[["button",JOY_BUTTON_RIGHT_SHOULDER]],
	"photo_exposure_up":[["button",JOY_BUTTON_DPAD_UP]],
	"photo_exposure_down":[["button",JOY_BUTTON_DPAD_DOWN]],
	"photo_clean":[["button",JOY_BUTTON_BACK]],
	"photo_reset":[["button",JOY_BUTTON_RIGHT_STICK]],
	# The library's and the New world panel's own verbs, beside ui_accept,
	# ui_cancel and the ui moves.
	"library_new":[["button",JOY_BUTTON_X]],
	"new_world_roll":[["button",JOY_BUTTON_X]],
	"new_world_name":[["button",JOY_BUTTON_Y]],
}
## Glyph ids, by joypad button and by axis direction, for the prompts
## (scripts/pad_prompt.gd draws them).
const BUTTON_GLYPHS := {JOY_BUTTON_A:"A",JOY_BUTTON_B:"B",JOY_BUTTON_X:"X",JOY_BUTTON_Y:"Y",
	JOY_BUTTON_LEFT_SHOULDER:"LB",JOY_BUTTON_RIGHT_SHOULDER:"RB",JOY_BUTTON_LEFT_STICK:"L3",JOY_BUTTON_RIGHT_STICK:"R3",
	JOY_BUTTON_BACK:"VIEW",JOY_BUTTON_START:"MENU",JOY_BUTTON_DPAD_UP:"UP",JOY_BUTTON_DPAD_DOWN:"DOWN",
	JOY_BUTTON_DPAD_LEFT:"LEFT",JOY_BUTTON_DPAD_RIGHT:"RIGHT"}
const AXIS_GLYPHS := {JOY_AXIS_LEFT_X:"LS",JOY_AXIS_LEFT_Y:"LS",JOY_AXIS_RIGHT_X:"RS",JOY_AXIS_RIGHT_Y:"RS",
	JOY_AXIS_TRIGGER_LEFT:"LT",JOY_AXIS_TRIGGER_RIGHT:"RT"}
## Every glyph id a prompt may name directly, as "{A}" or "{LS}".
const GLYPHS := ["A","B","X","Y","LB","RB","LT","RT","LS","RS","L3","R3","VIEW","MENU","UP","DOWN","LEFT","RIGHT","DPAD"]

## Tells the prompts the device changed.
class Hub extends RefCounted:
	signal device_changed(pad: bool)

static var hub := Hub.new()
static var _pad := false
static var _vibration: Variant = null

## True while the pad was the last device used.
static func using_pad() -> bool:
	return _pad

static func set_pad(pad: bool) -> void:
	if pad == _pad: return
	_pad = pad
	hub.device_changed.emit(pad)

## Adds the actions the project does not define yet, and the pad's A and B to
## the GUI's accept and cancel. Safe to call any number of times.
static func ensure() -> void:
	for action: String in ACTIONS:
		if InputMap.has_action(action): continue
		InputMap.add_action(action,DEAD if action.begins_with("cursor_") or action.begins_with("look_") or action.begins_with("move_") else 0.5)
		for spec: Array in ACTIONS[action]: InputMap.action_add_event(action,_event(spec))
	_add_pad("ui_accept",JOY_BUTTON_A)
	_add_pad("ui_cancel",JOY_BUTTON_B)
	# Triggers and moves fire at a light press.
	for action: String in ["fly_boost","fly_brake","glide_rise","glide_dive","zoom_in","zoom_out"]:
		InputMap.action_set_deadzone(action,TRIGGER_DEAD)
	for action: String in ["move_left","move_right","move_forward","move_back"]:
		InputMap.action_set_deadzone(action,0.15)

static func _add_pad(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action): return
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button: return
	var pad := InputEventJoypadButton.new()
	pad.button_index = button
	pad.device = -1
	InputMap.action_add_event(action,pad)

static func _event(spec: Array) -> InputEvent:
	match str(spec[0]):
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = spec[1]
			return key
		"button":
			var button := InputEventJoypadButton.new()
			button.button_index = spec[1]
			button.device = -1
			return button
	var motion := InputEventJoypadMotion.new()
	motion.axis = spec[1]
	motion.axis_value = float(spec[2])
	motion.device = -1
	return motion

## Notes which device an event came from.
static func note(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		if event.pressed: set_pad(true)
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) >= NOTICE: set_pad(true)
	elif event is InputEventKey:
		if event.pressed and event.device != PAD_DEVICE: set_pad(false)
	elif event is InputEventMouseButton:
		if event.device != PAD_DEVICE and event.pressed: set_pad(false)
	elif event is InputEventMouseMotion:
		if event.device != PAD_DEVICE and event.relative.length() >= MOUSE_NOTICE: set_pad(false)
	elif event is InputEventGesture:
		set_pad(false)

## True for a pad event that presses `action` (not an echo).
static func pressed(event: InputEvent, action: StringName) -> bool:
	return (event is InputEventJoypadButton or event is InputEventJoypadMotion) and event.is_action_pressed(action)

static func released(event: InputEvent, action: StringName) -> bool:
	return (event is InputEventJoypadButton or event is InputEventJoypadMotion) and event.is_action_released(action)

## A stick's vector from four actions, past the radial dead zone and rescaled
## from it, so the push starts at nothing.
static func stick(left: StringName, right: StringName, up: StringName, down: StringName) -> Vector2:
	var raw := Vector2(Input.get_action_raw_strength(right)-Input.get_action_raw_strength(left),
		Input.get_action_raw_strength(down)-Input.get_action_raw_strength(up))
	var length := raw.length()
	if length <= DEAD: return Vector2.ZERO
	return raw/length*minf((length-DEAD)/(1.0-DEAD),1.0)

## A soft response: small pushes are fine, a full push is full speed.
static func curve(v: Vector2, power := 1.8) -> Vector2:
	var length := v.length()
	if length <= 0.0: return Vector2.ZERO
	return v/length*pow(length,power)

## A trigger's pull past its dead zone, 0..1.
static func trigger(action: StringName) -> float:
	var raw := Input.get_action_raw_strength(action)
	return clampf((raw-TRIGGER_DEAD)/(1.0-TRIGGER_DEAD),0.0,1.0)

# --- Prompts ------------------------------------------------------------------------

## The glyph id of `action`'s first pad binding ("A", "LT", "LS"...), or "".
static func glyph(action: StringName) -> String:
	if not InputMap.has_action(action): return ""
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton: return str(BUTTON_GLYPHS.get(event.button_index,""))
		if event is InputEventJoypadMotion: return str(AXIS_GLYPHS.get(event.axis,""))
	return ""

## `keys` with the keyboard and mouse, `pad` with the pad.
static func pick(keys: String, pad: String) -> String:
	return pad if _pad else keys

# --- Vibration -------------------------------------------------------------------------

static func vibration() -> bool:
	if _vibration == null:
		var config := ConfigFile.new()
		_vibration = config.load(SETTINGS_PATH) != OK or bool(config.get_value("pad","vibration",true))
	return bool(_vibration)

static func set_vibration(on: bool) -> void:
	_vibration = on
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("pad","vibration",on)
	config.save(SETTINGS_PATH)

## A small rumble on the pads in use: `weak` and `strong` motors 0..1 for
## `seconds`. Nothing while the keyboard and mouse are in hand, or with
## vibration off.
static var pulses := 0
static func pulse(weak: float, strong: float, seconds: float) -> void:
	if not _pad or not vibration(): return
	pulses += 1
	for device: int in Input.get_connected_joypads():
		Input.start_joy_vibration(device,weak,strong,seconds)
