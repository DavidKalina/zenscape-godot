class_name GrassSheen
extends RefCounted
## The wind's sheen across far grass: light and dark swells rolling over the
## meadow past the near tufts (shaders/grass_sheen.gdshaderinc, docs/design/
## endless-flight/grass-sheen-handoff.md). Shading only, on the painted ground
## and the far tufts, from the wind the near tufts sway to.
## --sheen=X: strength (default STRENGTH; 0 off). --sheen-far=X: how much more
## it reads far off. --sheen-set=name=v: any grass_sheen* uniform, by hand.
## A world asks for grass that blows as one with `swell()` and `pace()`
## (--swell=0 today's sheen back; --swell=X,Y,Z and --sheen-pace=X to try values).

const LaunchArgs = preload("res://scripts/launch_args.gd")
## Strength: how far the swells swing the grass's tone (1: about 30% light
## and dark on the crests).
const STRENGTH := 0.8
## The ring distance (m) it comes in over past the near tufts.
const IN := Vector2(28.0, 85.0)
## How much more it reads at 400 m than near (aerial haze takes contrast).
const FAR := 0.25

## Grass that blows as one (grass_sheen.gdshaderinc `grass_swell`): how far, the
## far tufts' lean on a crest (m of tip per m of tuft), the swell's share of the
## colour. PACE: the swells' speed as a share of the air's.
const SWELL := Vector3(1.0,0.7,0.65)
const PACE := 0.35

## The far grass as a fine lawn (shaders/far_lawn.gdshaderinc, ported from the
## clean look's round 8; docs/design/endless-flight/far-lawn-handoff.md):
## strength (--lawn=X, 0 off), the nap's share (--nap=X), the ring distance
## it comes in over (m) and the two scales (m one tile of the baked
## assets/textures/far_turf.png covers, tools/bake_turf.gd).
const LAWN := 1.0
const NAP := 1.0
const LAWN_RING := Vector2(140.0,230.0)
const LAWN_TILES := Vector2(64.0,39.0)
const LAWN_TEXTURE := "res://assets/textures/far_turf.png"

static var strength := _arg("--sheen=",STRENGTH)
static var far := _arg("--sheen-far=",FAR)
static var lawn := _arg("--lawn=",LAWN)
static var nap := _arg("--nap=",NAP)
## --high-paint=old: the high-up streaks and washes as they were (lattice
## noise, hard-edged), for A/B against the smooth ones.
static var high_paint_old := 1.0 if _text("--high-paint=") == "old" else 0.0

## This world's paint.ground and paint.far `grass_swell`, flags over SWELL.
static func swell() -> Vector3:
	var t := _text("--swell=")
	if t == "": return SWELL
	var v := t.split_floats(",")
	return Vector3(v[0],v[1],v[2]) if v.size() == 3 else Vector3(v[0],0.0,1.0)

## This world's paint.sheen_pace, flags over PACE (1 when the swell is off).
static func pace() -> float:
	if swell().x <= 0.0: return 1.0
	return _arg("--sheen-pace=",PACE)

static func _text(key: String) -> String:
	for a: String in LaunchArgs.user_args():
		if a.begins_with(key): return a.get_slice("=",1)
	return ""

static func _arg(key: String, d: float) -> float:
	for a: String in LaunchArgs.user_args():
		if a.begins_with(key): return maxf(a.get_slice("=",1).to_float(),0.0)
	return d

## The sheen on grass material `m` (ground or far tuft).
static func apply(m: ShaderMaterial, tufts := false) -> void:
	# --sheen-tier=ground|tufts: only that tier (for A/B).
	var only := _text("--sheen-tier=")
	var on := strength if only == "" or (only == "tufts") == tufts else 0.0
	m.set_shader_parameter("grass_sheen",Vector4(on,IN.x,IN.y,far))
	if not tufts:
		m.set_shader_parameter("grass_lawn",Vector4(lawn if on > 0.0 else 0.0,LAWN_RING.x,LAWN_RING.y,nap))
		m.set_shader_parameter("grass_lawn_tiles",LAWN_TILES)
		m.set_shader_parameter("grass_lawn_tex",load(LAWN_TEXTURE) as Texture2D)
		m.set_shader_parameter("high_paint_old",high_paint_old)
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--sheen-set="):
			var kv := a.substr(12).split("=")
			if kv.size() == 2:
				var parts := kv[1].split(",")
				if parts.size() == 1: m.set_shader_parameter(kv[0],parts[0].to_float())
				elif parts.size() == 2: m.set_shader_parameter(kv[0],Vector2(parts[0].to_float(),parts[1].to_float()))
				elif parts.size() == 3: m.set_shader_parameter(kv[0],Vector3(parts[0].to_float(),parts[1].to_float(),parts[2].to_float()))
