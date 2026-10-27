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
## The push on the field's clouds (the storm is the field's own cumulus
## grown: shaders/storm_cloud.glslinc storm_push, the composite's
## zs_storm_cloud_weight, keep the numbers equal): built from PUSH_AHEAD.x m
## ahead of the leading edge to whole at .y, held over the core, let go over
## PUSH_BEHIND m from PUSH_BEHIND_FROM past the core's end, faded over
## PUSH_ENDS (m past, m inside the line's ends).
const PUSH_AHEAD := Vector2(3800.0,250.0)
const PUSH_BEHIND_FROM := -200.0
const PUSH_BEHIND := 1400.0
const PUSH_ENDS := Vector2(1500.0,900.0)
## The storm builds: its whole strength (`intensity`) rises from GROW_FROM
## to 1 over its first GROW seconds (eased), so the cumulus ahead fills up,
## swells and darkens in view. --storm-grow=S (0: whole from the start),
## --storm-grow-from=X.
const GROW := 60.0
const GROW_FROM := 0.1
## The rain (and so the lightning, which strikes in it) comes in as the
## clouds over it build: none below WET.x of the strength, whole from WET.y.
const WET := Vector2(0.4,0.85)
## Enveloped (shaders/storm_cloud.glslinc SE_*, keep the numbers equal):
## deep in the core the storm closes round the plane. Its base drops as a
## dark lumpy deck (ENV_DECK: its base over the sea where the envelope is
## whole, and where it begins; ENV_THICK thick), scud races under it, the
## air greys with rain. The envelope comes in from ENV_IN.x m behind the
## edge to whole at .y, lets go from ENV_OUT.x m before the core's end to
## none .y past it, tapers at the line's ends, and waits for the storm to
## build (ENV_STRENGTH of its intensity). Nothing of it comes nearer the
## ground than ENV_GROUND m, nor the meadows than the clouds' meadow
## clearance. --storm-envelope=0 leaves it out; --storm-murk=X,
## --storm-scud=X, --storm-deck=X scale its three parts (1).
const ENV_IN := Vector2(-150.0,-1000.0)
const ENV_OUT := Vector2(300.0,-400.0)
const ENV_STRENGTH := Vector2(0.55,0.95)
const ENV_DECK := Vector2(200.0,700.0)
const ENV_THICK := 380.0
const ENV_GROUND := 40.0
## The light deep in it, on top of the core's grade: more gloom, the sun
## left at ENV_SUN of what the core leaves; inside its cloud (`immersed`)
## more again (IMMERSED_GLOOM, IMMERSED_SUN).
const ENV_GLOOM := 0.2
const ENV_SUN := 0.45
const IMMERSED_GLOOM := 0.1
const IMMERSED_SUN := 0.5

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
## The storm's whole strength (0..1), on every place's push (`push_at`),
## driven by its clock (GROW).
var intensity := 1.0
var grow := GROW
var grow_from := GROW_FROM
var held_strength := NAN
## The churn's phase (s): the storm's clock run at its intensity, so its
## heaps boil faster as it builds (shaders/storm_cloud.glslinc storm_carve).
var churn := 0.0
## How fast the churn runs (--storm-churn=X; 0 holds the heaps still).
var churn_rate := 1.0
## The envelope (ENV_*): on, its murk's, scud's and deck's scales, its
## amount at the eye as of the last step, and how deep in cloud the eye is
## (0..1, smoothed; the study sets it from the clouds' `cloud_depth`).
var envelope := true
var env_scale := Vector3.ONE
var env_here := 0.0
var immersed := 0.0

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
		elif a.begins_with("--storm-grow="): s.grow = maxf(0.0,a.get_slice("=",1).to_float())
		elif a.begins_with("--storm-strength="): s.held_strength = clampf(a.get_slice("=",1).to_float(),0.0,1.0)
		elif a.begins_with("--storm-grow-from="): s.grow_from = clampf(a.get_slice("=",1).to_float(),0.0,1.0)
		elif a.begins_with("--storm-churn="): s.churn_rate = maxf(0.0,a.get_slice("=",1).to_float())
		elif a.begins_with("--storm-envelope="): s.envelope = a.get_slice("=",1) != "0"
		elif a.begins_with("--storm-murk="): s.env_scale.x = maxf(0.0,a.get_slice("=",1).to_float())
		elif a.begins_with("--storm-scud="): s.env_scale.y = maxf(0.0,a.get_slice("=",1).to_float())
		elif a.begins_with("--storm-deck="): s.env_scale.z = maxf(0.0,a.get_slice("=",1).to_float())
	s.intensity = s.strength_at(0.0)
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

## How hard the storm pushes the field's clouds at `p` (0..1): the one
## storm-intensity input per place the clouds grow by.
func push_at(p: Vector2) -> float:
	return place_at(p)*clampf(intensity,0.0,1.0)

## The push at `p` by the front's place alone (the storm whole): which
## kind a pushed cell turns to reads this, so a cell never changes kind as
## the storm builds, only grows.
func place_at(p: Vector2) -> float:
	var d := edge_distance(p)
	var half := length*0.5
	return ramp(PUSH_AHEAD.x,PUSH_AHEAD.y,d) 		*ramp(-CORE_DEPTH+PUSH_BEHIND_FROM-PUSH_BEHIND,-CORE_DEPTH+PUSH_BEHIND_FROM,d) 		*ramp(half+PUSH_ENDS.x,half-PUSH_ENDS.y,absf(along(p)))

## The storm's whole strength at its clock `t` (s).
func strength_at(t: float) -> float:
	if not is_nan(held_strength): return held_strength
	if grow <= 0.0: return 1.0
	return lerpf(grow_from,1.0,ramp(0.0,grow,t))

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

## The envelope (0..1): how far the storm has closed in at `p`.
func envelope_at(p: Vector2) -> float:
	if not envelope: return 0.0
	var d := edge_distance(p)
	return ramp(ENV_IN.x,ENV_IN.y,d)*ramp(-CORE_DEPTH+ENV_OUT.y,-CORE_DEPTH+ENV_OUT.x,d)*_ends(p)*ramp(ENV_STRENGTH.x,ENV_STRENGTH.y,intensity)

## The deck's smooth base (world y) at envelope `e` over the floor `floor_y`
## (world y), `sea` the sea's y.
static func deck_base(e: float, floor_y: float, sea: float) -> float:
	return maxf(sea+lerpf(ENV_DECK.y,ENV_DECK.x,e),floor_y)

## How deep in cloud the eye is (`depth` m, the clouds' cloud_depth),
## smoothed over a moment.
func immerse(depth: float, delta: float) -> void:
	var goal := ramp(-5.0,40.0,depth)
	immersed = lerpf(immersed,goal,1.0-exp(-delta/0.35))

## The rain (0..1): under the core.
func rain_at(p: Vector2) -> float:
	var d := edge_distance(p)
	return ramp(RAIN_IN.x,RAIN_IN.y,d)*ramp(-CORE_DEPTH-RAIN_OUT.x,-CORE_DEPTH-RAIN_OUT.y,d)*_ends(p)*wet()

## The rain's share of itself as the storm builds (zs_storm_wet).
func wet() -> float:
	return ramp(WET.x,WET.y,intensity)

## The gust front's wind (0..1): rising to its peak at the edge, dying
## under the shelf.
func gust_at(p: Vector2) -> float:
	var d := edge_distance(p)
	var g := ramp(GUST_DEPTH,0.0,d) if d > 0.0 else ramp(-GUST_BEHIND,0.0,d)
	return g*_ends(p)

## One frame: the clock on (unless `held`), the amount at `eye`, the
## globals published.
func step(delta: float, eye: Vector3, held := false) -> void:
	if not held:
		time += delta
		intensity = strength_at(time)
		churn += delta*intensity*churn_rate
	here = amount_at(Vector2(eye.x,eye.z))
	env_here = envelope_at(Vector2(eye.x,eye.z))
	publish()

func publish() -> void:
	var e := edge()
	RenderingServer.global_shader_parameter_set("zs_storm_line",Vector4(e.x,e.y,_heading.x,_heading.y))
	RenderingServer.global_shader_parameter_set("zs_storm_shape",Vector4(length,CORE_DEPTH,GUST_DEPTH,1.0))
	RenderingServer.global_shader_parameter_set("zs_storm_here",here)
	RenderingServer.global_shader_parameter_set("zs_storm_wet",wet())

## The light's grade under it, on the look's Celestial (each frame,
## before it advances).
func grade(celestial: RefCounted) -> void:
	celestial.storm = minf(here*gloom+env_here*ENV_GLOOM+immersed*IMMERSED_GLOOM,0.95)

## The sun dimmed under it (each frame, after the look has set its energy).
func shade(sun: DirectionalLight3D) -> void:
	sun.light_energy *= lerpf(1.0,sun_left,here)*lerpf(1.0,ENV_SUN,env_here)*lerpf(1.0,IMMERSED_SUN,immersed)

## --storm-debug's line at `p`.
func note(p: Vector3) -> String:
	var q := Vector2(p.x,p.z)
	return "storm  d %.0f m  ·  along %.0f m  ·  amount %.2f  ·  rain %.2f  ·  gust %.2f  ·  here %.2f  ·  envelope %.2f  ·  in cloud %.2f  ·  t %.0f s  ·  strength %.2f" % [
		edge_distance(q),along(q),amount_at(q),rain_at(q),gust_at(q),here,env_here,immersed,time,intensity]
