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
## An opening meant to be flown keeps its toy-era width in wingspans
## (`opening`): the toy width times the plane times RATIO (1.0: the toy
## era's flight felt right, so every opening keeps its toy-era width in
## wingspans exactly). Each file names
## its openings' toy widths. `--opening-ratio=<x>` overrides RATIO for a
## run; `--plane-scale=1 --opening-ratio=1` gives back every toy width
## exactly. `gap(room)` (span plus steering room in toy spans) stays for
## spacing with no toy width (the bell spires); SNUG floors `opening`.

## The game's sizes: the knobs.
const PLANE := 2.0
const WANDERER := 1.0

## Measured off the toy figures, the base the sizes multiply.
## The toy plane's span (plane_figure.gd SPAN) and its height from the
## wheels' bottom to the upper wing's top (WHEEL_DROP 0.41 + UPPER_Y 0.3 +
## the wing).
const TOY_SPAN := 1.4
const TOY_TALL := 0.74
## The toy's reach from its middle down to the wheels' bottom (the most of
## its body off the middle across the span's way; the roof is less).
const TOY_KEEL := 0.45
## The walker (his model, assets/models/pilot.glb) over the cockpit pilot (plane_pilot.gd in
## the toy rig): 0.44 m shoulders to cap top over 0.185, 2.38. A plane PLANE
## times the toy seats a pilot this over PLANE times the walker's size.
const PILOT_RATIO := 2.4
## The most the cockpit pilot is drawn over his own size and still sits in
## the cockpit (his head and shoulders clear of its rim and windscreen).
const PILOT_MOST := 1.25

## The walker's clips' height, cap top over his soles (m): his drawn
## height is this times `wanderer` (`wanderer_tall`).
const WANDERER_TALL := 1.19

## The sizes in force (the flags', or the knobs).
static var plane: float = _flag("--plane-scale=",PLANE)
static var wanderer: float = _flag("--wanderer-scale=",WANDERER)
## The walker's drawn height (m): what a figure sized against him asks.
static var wanderer_tall: float = WANDERER_TALL*wanderer
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
## PLANE 2 each toy span is 0.7 m past each wingtip). ROOM: the default
## room for `gap`, 1.4 m past each tip. SNUG: 1.2 m past each tip, the
## floor under `opening` (a knife-edge slot is sized on its own, `knife`).
const ROOM := 2.0
const SNUG := 2.4/TOY_SPAN

## How far the plane reaches sideways off its middle, rolled `roll`
## radians: half its span wings level, its keel on its side (m). The
## flight's solids are grown by this round its middle.
static func reach_rolled(roll: float) -> float:
	return maxf(span*0.5*absf(cos(roll)),TOY_KEEL*plane*absf(sin(roll)))

## A gap the plane flies through sized by steering room, not by a toy
## width: its span and `room` toy spans of room (both sides together),
## ROOM by default. gap(SNUG) is 5.2 m at plane 2, 3.8 for the toy.
static func gap(room := ROOM) -> float:
	return span+TOY_SPAN*room

## The share of its toy-era ratio to the wingspan every flown opening keeps:
## RATIO by default, `--opening-ratio=<x>` for a run.
const RATIO := 1.0
static var ratio: float = _flag("--opening-ratio=",RATIO)

## An opening the plane flies through, from its toy-era width (its width
## when the plane was the 1.4 m toy): toy_width*plane*ratio, so it keeps
## `ratio` of its old width in wingspans (2x the toy width at the
## defaults: THREAD 3.5 -> 7.0).
## Floored at gap(SNUG) (1.2 m past each wingtip) so a small ratio never
## closes an opening onto the wings; but the floor never reaches past the
## toy width grown with the plane (toy_width*plane), so at ratio 1 it never
## acts (plane 1, ratio 1: every toy width exactly), and a toy width that
## was itself under SNUG's room (a token's wing box) floors at its own toy
## ratio, not wider.
static func opening(toy_width: float) -> float:
	return opening_at(toy_width,ratio)

## `opening` at another ratio: for a layout drawn round the openings of an
## older ratio (DRAWN_RATIO), so it can be told how far they have grown.
static func opening_at(toy_width: float, at_ratio: float) -> float:
	var grown := toy_width*plane
	return maxf(grown*at_ratio,minf(gap(SNUG),grown))

## The ratio some hand-drawn layouts were drawn round (the aqueduct isle's
## island outlines, the Sundered line's bay counts): they shift or trim by
## how far `opening` has grown past `opening_at(DRAWN_RATIO)`.
const DRAWN_RATIO := 0.9

## A slot the plane is meant to pass only on a knife edge (on a wingtip):
## its height on its side (the toy's TOY_TALL times the plane) and `room`
## toy spans of it either side together, KNIFE_ROOM by default (0.21 m a
## side): 1.9 m at plane 2. Narrower than the span, so level it can't pass.
const KNIFE_ROOM := 0.3
static func knife(room := KNIFE_ROOM) -> float:
	return TOY_TALL*plane+TOY_SPAN*room

## How far past each wingtip an opening `width` m across leaves the plane
## flown level through its middle.
static func past_tip(width: float) -> float:
	return (width-span)*0.5

static func _flag(prefix: String, otherwise: float) -> float:
	for arg: String in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with(prefix): return maxf(0.1,float(arg.get_slice("=",1)))
	return otherwise
