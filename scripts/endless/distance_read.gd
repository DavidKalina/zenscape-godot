extends RefCounted
## The land reading with depth from flying height (docs/design/endless-flight/
## handoff-distance-read.md): three parts, each with its own flag (0 or off
## turns it off, a number scales it):
##   --far-haze=X   the haze fuller through the middle distance (FOG_CURVE
##                  below in place of endless_look's 0.75, more of the sky's
##                  blue in it) and the tree crowns a share more of it on top
##                  (TREE_HAZE x X), so a wood a kilometre off goes pale.
##   --wood-floor=X the grass darker and cooler where the woods stand (the
##                  forest floor's weight, wood_map.gd), with the floor
##                  sheet's own colour (land_trees FLOOR_COLOUR) a little
##                  darker and cooler.
##   --meadow-tone=X the grass pulled off lime toward a natural meadow (0 the
##                  old look, 1 the default; zs_meadow, MEADOW_* below), for
##                  the ground's paint and every tuft alike.
##   --tree-vary=X  each spruce its own value and hue (a hash of its foot,
##                  the same on every ring: blue-black, olive, the odd pale
##                  or grey one).
## Fine knobs: --haze-curve=C (the depth fog's curve), --tree-haze=S (the
## crowns' extra share at full), --wood-shade=S (how far the grass goes
## toward the floor's shade), --wood-shrink=S (how much the tufts shrink
## under the woods).
## They reach the shaders as the globals zs_dread (x tree haze, y wood
## shade, z tree spread, w tuft shrink) and zs_haze_tint (the haze's colour,
## scene linear, set each frame by endless_look `_haze`), and the texture
## zs_wood_map; shaders/distance_read.gdshaderinc reads them.
const LaunchArgs = preload("res://scripts/launch_args.gd")

## The depth fog's curve with --far-haze on: 1 km now takes ~0.2 of the
## haze (0.09 at 0.75), 2 km ~0.4, 3 km ~0.57, 150 m ~0.01.
const FOG_CURVE := 0.5
## The old curve, aerial share, for --far-haze=0.
const FOG_CURVE_OFF := 0.75
## Godot's aerial perspective (the sky's blurred light behind each pixel)
## with --far-haze on: the middle distance bluer, toward the dome.
const AERIAL := 0.42
## The crowns' extra haze at full (shaders/distance_read.gdshaderinc
## zs_tree_haze: in from 150 m, full by 1.8 km).
const TREE_HAZE := 0.35
## The crowns' extra haze is the haze's colour this much toward its own grey
## (the horizon's colour is the sky's, more saturated than the air before a
## wood a kilometre off reads), and this much lighter.
const TREE_TINT := Vector2(0.55,1.1)
## At a low sun (celestial zs_haze_sun 1) this share of the change goes (the
## curve back toward the old one, the crowns' extra haze off), and all of it
## once the sun is down: `day_share`.
const GOLD := 0.8
## How far the grass under a full wood goes to the floor's shade.
const WOOD_SHADE := 0.7
## How much the tufts under a full wood shrink (so the floor shows).
const WOOD_SHRINK := 0.35
## The trees' spread (1: as tuned).
const TREE_VARY := 1.0

## --meadow-tone at 1: the saturation kept, the red lost (blue gained 0.6x
## that), the value kept.
const MEADOW_SAT := 0.68
const MEADOW_YELLOW := 0.2
const MEADOW_VALUE := 0.88

static func _arg(name: String, fallback: float) -> float:
	for a in LaunchArgs.user_args():
		if a == "--%s=off" % name: return 0.0
		if a.begins_with("--%s=" % name): return maxf(0.0,float(a.get_slice("=",1)))
	return fallback

static func far_haze() -> float: return _arg("far-haze",1.0)
static func wood_floor() -> float: return _arg("wood-floor",1.0)
static func meadow_tone() -> float: return _arg("meadow-tone",1.0)
static func tree_vary() -> float: return _arg("tree-vary",1.0)

## The depth fog's curve.
static func fog_curve() -> float:
	if far_haze() <= 0.0: return FOG_CURVE_OFF
	return _arg("haze-curve",lerpf(FOG_CURVE_OFF,FOG_CURVE,minf(far_haze(),1.0)))

## The aerial share (the low sun's own, endless_look AERIAL_SUN, stays).
static func aerial(old: float) -> float:
	return lerpf(old,AERIAL,minf(far_haze(),1.0))

## How much of the change shows now (0..1, `day_share`): all of it by day,
## GOLD less at a low sun (golden-hour weight `k`, celestial zs_haze_sun),
## none once the sun is down (`sun_y` its height): a wood against the glow
## reads dark, and the haze toward a low sun is brighter than the land.
static func day_share(k: float, sun_y: float) -> float:
	return smoothstep(-0.02,0.25,sun_y)*(1.0-k*GOLD)

## The crowns' haze colour from the haze's (scene linear), and in w the share
## of their extra haze shown now (`day_share`).
static func tree_tint(c: Color, day: float) -> Vector4:
	var v := Vector3(c.r,c.g,c.b)
	var l := v.dot(Vector3(0.2126,0.7152,0.0722))
	v = v.lerp(Vector3(l,l,l),TREE_TINT.x)*TREE_TINT.y
	return Vector4(v.x,v.y,v.z,day)

## The globals the shaders read (but zs_haze_tint, which goes each frame).
static func publish() -> void:
	var tone := meadow_tone()
	RenderingServer.global_shader_parameter_set(&"zs_meadow",Vector4(minf(tone,1.0),_arg("meadow-sat",MEADOW_SAT),_arg("meadow-yellow",MEADOW_YELLOW),_arg("meadow-value",MEADOW_VALUE)))
	var wood := wood_floor()
	RenderingServer.global_shader_parameter_set(&"zs_dread",Vector4(
		_arg("tree-haze",TREE_HAZE)*far_haze(),
		_arg("wood-shade",WOOD_SHADE)*wood,
		TREE_VARY*tree_vary(),
		_arg("wood-shrink",WOOD_SHRINK)*minf(wood,1.0)))
