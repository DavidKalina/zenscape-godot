extends RefCounted
## The one place the game's sizes live (docs/design/plane-ground-scale.md).
## Change PLANE or WANDERER here and the plane, the walker, his moves and
## the gaps the plane flies through all follow. Nothing else holds its own
## copy of these numbers or parses their flags.
##
## - PLANE: the plane drawn this times its toy size (scripts/plane_figure.gd,
##   1.4 m across the wings), everywhere, in flight too, about its wheels.
## - WANDERER: the walker drawn this times his clips' size (1.19 m).
## - The cockpit pilot is drawn `pilot_size` times his own size, in the
##   plane only, so he is the walker's size without the plane changing.
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
const WANDERER := 1.0

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
## The most the cockpit pilot is drawn over his own size and still sits in
## the cockpit (his head and shoulders clear of its rim and windscreen).
const PILOT_MOST := 1.25

## The sizes in force (the flags', or the knobs).
static var plane: float = _flag("--plane-scale=",PLANE)
static var wanderer: float = _flag("--wanderer-scale=",WANDERER)
## The plane's span as drawn, and how much wider and taller than the toy
## (drawn about its wheels it grows only upward).
static var span: float = TOY_SPAN*plane
static var wider: float = span-TOY_SPAN
static var taller: float = TOY_TALL*(plane-1.0)

## The cockpit pilot's draw scale (scripts/plane_figure.gd, the stone
## plane's): what makes him the walker's size in a plane drawn `plane`
## times the toy, PILOT_RATIO*wanderer/plane (1.2 at the knobs). Over
## PILOT_MOST he would not fit the cockpit, so he stays 1 and the ground
## cheat makes up the lot (the old sizes: 1, the cheat 2.4).
static var pilot_size: float = _pilot_size()

static func _pilot_size() -> float:
	var s := PILOT_RATIO*wanderer/plane
	return s if s <= PILOT_MOST else 1.0

## The ground cheat's factor (scripts/plane_ground_scale.gd): how much
## bigger the parked plane is drawn so its pilot is the walker's size, what
## the cockpit pilot's own scale leaves, PILOT_RATIO*wanderer/(plane*
## pilot_size), never under 1: exactly 1 at the knobs (no cheat), 2.4 at
## `--plane-scale=1 --wanderer-scale=1`. `--plane-ground-scale=` sets it.
static func ground_factor() -> float:
	var given := _flag("--plane-ground-scale=",NAN)
	if not is_nan(given): return maxf(1.0,given)
	var f := PILOT_RATIO*wanderer/(plane*pilot_size)
	return 1.0 if f < 1.0+1e-4 else f

## Steering room past the wings, in toy spans (both sides together; at
## PLANE 2 each toy span is 0.7 m past each wingtip). ROOM: what an
## opening the plane is meant to fly through gets by default, 1.4 m past
## each tip. SNUG: the least any flown opening gets, 1.2 m past each tip,
## unless it is a deliberate knife-edge challenge (sized on its own). The
## world is spaced out, not threading-tight (docs/design/plane-ground-
## scale.md, feature/world-spacing).
const ROOM := 2.0
const SNUG := 2.4/TOY_SPAN

## A gap the plane flies through: its span and `room` toy spans of
## steering room (both sides together), ROOM by default. E.g. RuinKit
## THREAD is gap(SNUG): 3.8 m for the toy, 5.2 for the plane at 2.
static func gap(room := ROOM) -> float:
	return span+TOY_SPAN*room

## How far past each wingtip an opening `width` m across leaves the plane
## flown level through its middle.
static func past_tip(width: float) -> float:
	return (width-span)*0.5

static func _flag(prefix: String, otherwise: float) -> float:
	for arg: String in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with(prefix): return maxf(0.1,float(arg.get_slice("=",1)))
	return otherwise
