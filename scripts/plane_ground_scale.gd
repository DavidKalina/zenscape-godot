extends RefCounted
## The plane's ground scale (docs/design/plane-ground-scale.md): a scale
## cheat. In flight the plane is the toy it is (scripts/plane_figure.gd SPAN
## 1.4) and stays exactly so; on its wheels it is drawn FACTOR times bigger,
## so the pilot seated in its cockpit is the size of the wanderer on foot
## beside it. The change hides in the motion the camera is already doing:
## it is driven by the ground speed, full size at or under BIG_BELOW m/s and
## flight size from SMALL_ABOVE m/s (under the hand landing's ROLL_TOP), so
## a landing grows as the slide bleeds its speed and a takeoff roll shrinks
## it back before it rolls off the edge. Off the edge and dipping it
## shrinks the rest of the way fast (DIP_EASE s); flying, it is 1.0.
## Eased (EASE s) and rate-held (RATE of the whole change a second), so it
## never pops. The figure is scaled about its wheels' contact (scripts/
## plane_strip.gd WHEEL_DROP, WHEEL), so the wheels stay on the turf.
##
## `--plane-ground-scale=<x>` sets FACTOR (default DEFAULT); 1 turns it off.
## Plain state over the figure's transform: scripts/manual_landing.gd and
## the flight never see it.

const PlaneStrip = preload("res://scripts/plane_strip.gd")

## Measured: the on-foot wanderer (scripts/pilot_figure.gd, 1.19 m) stands
## 0.44 m from his shoulders to the top of his cap and 0.34 m across his
## shoulders; the cockpit pilot (scripts/plane_pilot.gd in the 0.92 rig)
## 0.185 m and 0.156 m: 2.38 and 2.2. The head and cap read most, so
## DEFAULT matches them.
const DEFAULT := 2.4
const BIG_BELOW := 3.0
const SMALL_ABOVE := 10.0
const EASE := 0.22
const RATE := 1.4
const DIP_EASE := 0.12
## The wheels' contact in the figure's frame: the point it is scaled about.
const PIVOT := Vector3(0.0,-PlaneStrip.WHEEL_DROP,-PlaneStrip.WHEEL)

## The ground factor and the scale now (1 in flight).
var factor := DEFAULT
var k := 1.0

func _init() -> void:
	for arg: String in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--plane-ground-scale="):
			factor = maxf(1.0,float(arg.get_slice("=",1)))

## True when the cheat is on at all.
func active() -> bool:
	return factor > 1.0001

## Starts at its ground size (`on_ground`) or flight size, no easing.
func reset(on_ground: bool) -> void:
	k = factor if on_ground else 1.0

## The size it wants on the ground at `speed` m/s.
func target(speed: float) -> float:
	return lerpf(factor,1.0,smoothstep(BIG_BELOW,SMALL_ABOVE,speed))

## One frame: `on_ground` on its wheels (rolling, stopped, getting out or
## hopping in), else `dipping` off an edge before the wings catch, else
## flying (exactly 1).
func step(delta: float, on_ground: bool, dipping: bool, glide: RefCounted) -> void:
	if not active():
		k = 1.0
		return
	if not on_ground and not dipping:
		k = 1.0
		return
	if dipping:
		k = lerpf(k,1.0,1.0-exp(-delta/DIP_EASE))
		if k < 1.002: k = 1.0
		return
	var v: Vector3 = glide.velocity
	var want := target(Vector2(v.x,v.z).length())
	var eased := lerpf(k,want,1.0-exp(-delta/EASE)) if delta > 0.0 else want
	var most := (factor-1.0)*RATE*delta
	k = clampf(eased,k-most,k+most)

## Scales `figure` (posed this frame at flight size) about its wheels by
## `size` (default the scale now). At 1 it is left alone.
func apply(figure: Node3D, size := NAN) -> void:
	var s := k if is_nan(size) else size
	if s == 1.0: return
	figure.transform = figure.transform*Transform3D(Basis.from_scale(Vector3.ONE*s),PIVOT*(1.0-s))

## Where a point on the flight-size plane (global) is on the plane drawn
## at `size`: scaled about the wheels of `figure` (posed now, scaled or not).
func point(figure: Node3D, at: Vector3, size := NAN) -> Vector3:
	var s := k if is_nan(size) else size
	var wheels := figure.global_transform*PIVOT
	return wheels+(at-wheels)*s

## The chase camera's lift: the plane's middle (0.61 m over its wheels at
## flight size) as far up as it has grown.
func lift() -> Vector3:
	return Vector3.UP*(PlaneStrip.FIGURE_DROP+PlaneStrip.WHEEL_DROP)*(k-1.0)

## Where the pilot hops out to, (left, ahead) of the plane's middle in m, at
## the ground size: at flight size `side` and `ahead` (kit_isle's HOP_SIDE,
## HOP_AHEAD); grown, to its left between the lower wing's trailing edge
## and the tailplane (figure frame x -0.42, z 0.38), clear of both.
func hop_offset(side: float, ahead: float) -> Vector2:
	if not active(): return Vector2(side,ahead)
	return Vector2(0.42*factor,-PIVOT.z-(0.38-PIVOT.z)*factor)
