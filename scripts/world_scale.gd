extends RefCounted
## The one place the game's sizes live (docs/design/plane-ground-scale.md).
## Change PLANE or WANDERER here and the plane, the walker, his moves and
## the gaps the plane flies through all follow. Nothing else holds its own
## copy of these numbers or parses their flags.
##
## - PLANE: the plane drawn this times its toy size (scripts/plane_figure.gd,
##   1.4 m across the wings), everywhere, in flight too, about its wheels.
## - WANDERER: the walker drawn this times his clips' size (1.19 m).
## - `--plane-scale=<x>` and `--wanderer-scale=<x>` override them for a run
##   (`=1` both: the old toy plane and full-size walker, and every gap and
##   move back to its old number). `--plane-ground-scale=<x>` overrides the
##   ground cheat (scripts/plane_ground_scale.gd).
##
## Read once, when this script first loads (static vars): a scene opened
## from the scene picker with other flags keeps the command line's sizes
## (scripts/launch_args.gd's caveat).
##
## A gap meant to be flown is the plane's span plus steering room
## (`gap`): the room is counted in toy spans and does not grow with the
## plane, since the flight's speeds and turns don't. At PLANE 1 each gap is
## its old number exactly.

## The game's sizes: the knobs.
const PLANE := 2.0
const WANDERER := 0.83

## Measured off the toy figures, the base the sizes multiply.
## The toy plane's span (plane_figure.gd SPAN) and its height from the
## wheels' bottom to the upper wing's top (WHEEL_DROP 0.41 + UPPER_Y 0.3 +
## the wing).
const TOY_SPAN := 1.4
const TOY_TALL := 0.74
## The walker (pilot_figure.gd) over the cockpit pilot (plane_pilot.gd in
## the toy rig): 0.44 m shoulders to cap top over 0.185, 2.38. A plane PLANE
## times the toy seats a pilot this over PLANE times the walker's size.
const PILOT_RATIO := 2.4

## The sizes in force (the flags', or the knobs).
static var plane: float = _flag("--plane-scale=",PLANE)
static var wanderer: float = _flag("--wanderer-scale=",WANDERER)
## The plane's span as drawn, and how much wider and taller than the toy
## (drawn about its wheels it grows only upward).
static var span: float = TOY_SPAN*plane
static var wider: float = span-TOY_SPAN
static var taller: float = TOY_TALL*(plane-1.0)

## The ground cheat's factor (scripts/plane_ground_scale.gd): how much
## bigger the parked plane is drawn so its pilot is the walker's size,
## PILOT_RATIO*wanderer/plane, never under 1 (1 at the knobs: no cheat);
## `--plane-ground-scale=` sets it.
static func ground_factor() -> float:
	var given := _flag("--plane-ground-scale=",NAN)
	if not is_nan(given): return maxf(1.0,given)
	return maxf(1.0,PILOT_RATIO*wanderer/plane)

## A gap the plane flies through: its span and `room` toy spans of
## steering room (both sides together). E.g. THREAD is gap(1.5): 3.5 m for
## the toy, 4.9 for the plane at 2.
static func gap(room: float) -> float:
	return span+TOY_SPAN*room

static func _flag(prefix: String, otherwise: float) -> float:
	for arg: String in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with(prefix): return maxf(0.1,float(arg.get_slice("=",1)))
	return otherwise
