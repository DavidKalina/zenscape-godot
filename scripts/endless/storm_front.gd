extends RefCounted
## The storm front (docs/design/endless-flight/spec-storm-front.md): one
## front at a time, a straight line LENGTH m long moving along its heading at
## SPEED m/s. Everything about it is a function of its clock and a point, so
## the clouds, rain, lightning and gust read the same storm on the CPU (the
## queries below) and on the GPU (the zs_storm_* globals it publishes each
## frame, mirrored in shaders/storm_front.gdshaderinc).
##
## Across the line it has bands by `d`, the signed distance from the leading
## edge (positive ahead, not yet arrived):
##   gust      GUST_DEPTH m ahead to the edge, the wind rising to its peak at
##             the edge and dying GUST_BEHIND m behind it;
##   shelf     the cloud's leading shelf, SHELF_AHEAD m ahead to -200 m;
##   core      CORE_FROM to -CORE_DEPTH m, under it the rain and lightning;
##   clearing  the trailing CLEAR m, the cloud thinning out.
## Along it, the line's ends taper off over END_TAPER m, so it has ends you
## could fly round.
##
## Off unless asked: --storm (a front upwind of the start on the land's own
## wind, coming down it), --storm-start[=m] (its leading edge m ahead of the
## start, START_AHEAD by default, its middle on the start's line, coming at
## the plane; the land's wind is turned to blow with it), --storm=0 none.
## --storm-speed=X m/s, --storm-length=X m, --storm-debug a line of d,
## amount, rain and gust at the plane. With none of them nothing is built.
##
## It never touches the plane: nothing here is read by the flight.

const LaunchArgs = preload("res://scripts/launch_args.gd")

const LENGTH := 10000.0
const SPEED := 15.0
const START_AHEAD := 3500.0
const END_TAPER := 1000.0
const GUST_DEPTH := 800.0
const GUST_BEHIND := 500.0
const SHELF_AHEAD := 400.0
const CORE_FROM := -300.0
const CORE_DEPTH := 3000.0
const CLEAR := 1000.0
## The rain's own edges inside the core: in from RAIN_IN.x to RAIN_IN.y
## behind the edge, out over RAIN_OUT behind the core's end.
const RAIN_IN := Vector2(-100.0,-600.0)
const RAIN_OUT := Vector2(300.0,-500.0)
## The light under it, by the amount at the eye: celestial.storm (scripts/
## shared/celestial.gd: the sky, fill and fog greyed and darkened) to GLOOM,
## and the sun (the key) left at SUN_LEFT of its own. Celestial's own grades
## were drawn for the isle's sky: `storm` at 1, or its `cloud` (overcast) at
## all, turn the endless sky near black, and neither dims the sun much.
const GLOOM := 0.6
const SUN_LEFT := 0.25

var length := LENGTH
var speed := SPEED
## The leading edge's middle at time 0 (xz), and its heading (unit xz).
var origin := Vector2.ZERO
var _heading := Vector2.RIGHT
var _side := Vector2.DOWN
## The storm's own clock (s): it waits while the menu holds the flight.
var time := 0.0
## The amount at the eye as of the last step (zs_storm_here).
var here := 0.0
var debug := false
## The grade's two (--storm-gloom=X, --storm-sun=X to try a value).
var gloom := GLOOM
var sun_left := SUN_LEFT

## The front the flags ask for, or null (nothing built). `start` the
## start's xz, `forward` the plane's heading there (unit xz), `wind` the
## land's own wind heading (unit xz).
static func from_args(start: Vector2, forward: Vector2, wind: Vector2) -> RefCounted:
	var asked := false
	var ahead := NAN
	var speed_arg := SPEED
	var length_arg := LENGTH
	var debug_arg := false
	for a: String in LaunchArgs.user_args():
		if a == "--storm": asked = true
		elif a.begins_with("--storm="): asked = a.get_slice("=",1) != "0"
		elif a == "--storm-start": ahead = START_AHEAD
		elif a.begins_with("--storm-start="): ahead = a.get_slice("=",1).to_float()
		elif a.begins_with("--storm-speed="): speed_arg = maxf(0.0,a.get_slice("=",1).to_float())
		elif a.begins_with("--storm-length="): length_arg = maxf(2.0*END_TAPER,a.get_slice("=",1).to_float())
		elif a == "--storm-debug": debug_arg = true
	if "--storm=0" in LaunchArgs.user_args(): return null
	if not asked and is_nan(ahead): return null
	var s: RefCounted = load("res://scripts/endless/storm_front.gd").new()
	s.speed = speed_arg
	s.length = length_arg
	s.debug = debug_arg
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--storm-sun="): s.sun_left = a.get_slice("=",1).to_float()
		elif a.begins_with("--storm-gloom="): s.gloom = a.get_slice("=",1).to_float()
	if not is_nan(ahead):
		# Ahead of the plane, coming at it.
		s.aim(start+forward*ahead,-forward)
	else:
		# Upwind of the start, coming down the wind.
		s.aim(start-wind*START_AHEAD,wind)
	return s

## The leading edge's middle at time 0 and the way it moves.
func aim(edge: Vector2, heading_to: Vector2) -> void:
	origin = edge
	_heading = heading_to.normalized()
	_side = Vector2(-_heading.y,_heading.x)

func on() -> bool:
	return true

func heading() -> Vector2:
	return _heading

## The leading edge's middle now (xz).
func edge() -> Vector2:
	return origin+_heading*speed*time

## The signed distance from the leading edge (m): positive ahead.
func edge_distance(p: Vector2) -> float:
	return (p-edge()).dot(_heading)

## Along the line from its middle (m).
func along(p: Vector2) -> float:
	return (p-edge()).dot(_side)

## 0 at `a`, 1 at `b` (either way round), smooth.
static func ramp(a: float, b: float, x: float) -> float:
	var t := clampf((x-a)/(b-a),0.0,1.0)
	return t*t*(3.0-2.0*t)

## 1 along the line, 0 past its ends.
func _ends(p: Vector2) -> float:
	var half := length*0.5
	return ramp(half,half-END_TAPER,absf(along(p)))

## How deep in the storm (0..1): the cloud over it and the gloom under it.
func amount_at(p: Vector2) -> float:
	var d := edge_distance(p)
	return ramp(SHELF_AHEAD,CORE_FROM,d)*ramp(-CORE_DEPTH-CLEAR,-CORE_DEPTH,d)*_ends(p)

## The rain (0..1): under the core.
func rain_at(p: Vector2) -> float:
	var d := edge_distance(p)
	return ramp(RAIN_IN.x,RAIN_IN.y,d)*ramp(-CORE_DEPTH-RAIN_OUT.x,-CORE_DEPTH-RAIN_OUT.y,d)*_ends(p)

## The gust front's wind (0..1): rising to its peak at the edge, dying
## under the shelf.
func gust_at(p: Vector2) -> float:
	var d := edge_distance(p)
	var g := ramp(GUST_DEPTH,0.0,d) if d > 0.0 else ramp(-GUST_BEHIND,0.0,d)
	return g*_ends(p)

## One frame: the clock on (unless `held`), the amount at `eye`, the
## globals published.
func step(delta: float, eye: Vector3, held := false) -> void:
	if not held: time += delta
	here = amount_at(Vector2(eye.x,eye.z))
	publish()

func publish() -> void:
	var e := edge()
	RenderingServer.global_shader_parameter_set("zs_storm_line",Vector4(e.x,e.y,_heading.x,_heading.y))
	RenderingServer.global_shader_parameter_set("zs_storm_shape",Vector4(length,CORE_DEPTH,GUST_DEPTH,1.0))
	RenderingServer.global_shader_parameter_set("zs_storm_here",here)

## The light's grade under it, on the look's Celestial (each frame,
## before it advances).
func grade(celestial: RefCounted) -> void:
	celestial.storm = here*gloom

## The sun dimmed under it (each frame, after the look has set its energy).
func shade(sun: DirectionalLight3D) -> void:
	sun.light_energy *= lerpf(1.0,sun_left,here)

## --storm-debug's line at `p`.
func note(p: Vector3) -> String:
	var q := Vector2(p.x,p.z)
	return "storm  d %.0f m  ·  along %.0f m  ·  amount %.2f  ·  rain %.2f  ·  gust %.2f  ·  here %.2f  ·  t %.0f s" % [
		edge_distance(q),along(q),amount_at(q),rain_at(q),gust_at(q),here,time]
