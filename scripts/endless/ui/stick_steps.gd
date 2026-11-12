extends RefCounted
## The left stick as menu steps: one step when it leans, then repeats while
## it is held, as a held key does. Every menu that takes the stick reads it
## here, once a frame:
##
##     var _stick := StickSteps.new()
##     func _process(delta: float) -> void:
##         if not taking(): _stick.rest()
##         else:
##             var d := _stick.step(delta)
##             if d.y != 0: move(d.y)
##             elif d.x != 0: change(d.x)
##
## Why not `event.is_action_pressed(&"ui_up")`: a stick sends a motion event
## for every change of its value, and each one past the action's dead zone
## reads as pressed, so one push moved the selection several rows. A menu's
## `_input` leaves InputEventJoypadMotion to this (`is_stick`).
##
## The stick is read through the pad's own actions (scripts/pad.gd `menu_*`,
## the left stick's four ways), so a remap moves it and a driver's parsed
## events reach it.

const Pad = preload("res://scripts/pad.gd")

## How far the stick must lean to step, and how far back it must come to let
## go (so a stick held at the edge of ON does not chatter).
const ON := 0.55
const OFF := 0.3
## The wait before a held stick repeats, and between repeats (s).
const WAIT := 0.38
const EVERY := 0.11

var _dir := Vector2i.ZERO
var _repeat := 0.0
## The stick has been at rest since the menu took the input: a stick held
## as the menu opens (the plane's, pulled back) steps nothing until let go.
var _armed := false

## True for the stick's own events, which a menu's `_input` leaves alone.
static func is_stick(event: InputEvent) -> bool:
	return event is InputEventJoypadMotion

## The stick now: x right, y down, each -1..1.
static func lean() -> Vector2:
	if not InputMap.has_action(&"menu_up"): Pad.ensure()
	return Vector2(Input.get_action_raw_strength(&"menu_right")-Input.get_action_raw_strength(&"menu_left"),
		Input.get_action_raw_strength(&"menu_down")-Input.get_action_raw_strength(&"menu_up"))

## Call each frame the menu is not taking input: the stick must come back to
## rest before it steps again.
func rest() -> void:
	_armed = false
	_dir = Vector2i.ZERO

## One frame: the step to take now, (0, 0) for none. One axis at a time, the
## one leant further; y is down.
func step(delta: float) -> Vector2i:
	var v := lean()
	if not _armed:
		_armed = maxf(absf(v.x),absf(v.y)) < OFF
		return Vector2i.ZERO
	var dir := Vector2i.ZERO
	if absf(v.y) >= absf(v.x):
		if absf(v.y) > (OFF if _dir.y != 0 else ON): dir.y = 1 if v.y > 0.0 else -1
	elif absf(v.x) > (OFF if _dir.x != 0 else ON): dir.x = 1 if v.x > 0.0 else -1
	if dir != _dir:
		_dir = dir
		_repeat = WAIT
		return dir
	if dir == Vector2i.ZERO: return dir
	_repeat -= delta
	if _repeat > 0.0: return Vector2i.ZERO
	_repeat = EVERY
	return dir
