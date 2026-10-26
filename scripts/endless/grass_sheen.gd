class_name GrassSheen
extends RefCounted
## The wind's sheen across far grass: light and dark swells rolling over the
## meadow past the near tufts (shaders/grass_sheen.gdshaderinc, docs/design/
## endless-flight/grass-sheen-handoff.md). Shading only, on the painted ground
## and the far tufts, from the wind the near tufts sway to.
## --sheen=X: strength (default STRENGTH; 0 off). --sheen-far=X: how much more
## it reads far off. --sheen-set=name=v: any grass_sheen* uniform, by hand.

const LaunchArgs = preload("res://scripts/launch_args.gd")
## Strength: how far the swells swing the grass's tone (1: about 30% light
## and dark on the crests).
const STRENGTH := 0.8
## The ring distance (m) it comes in over past the near tufts.
const IN := Vector2(28.0, 85.0)
## How much more it reads at 400 m than near (aerial haze takes contrast).
const FAR := 0.25

static var strength := _arg("--sheen=",STRENGTH)
static var far := _arg("--sheen-far=",FAR)
## The far blade read on the painted ground (shaders/grass_sheen.gdshaderinc
## zs_blade_paint): strength (--blades=X, 0 off) and the three streak widths (m).
const BLADES := 1.0
const BLADE_WIDTHS := Vector3(1.3,3.2,8.0)
static var blades := _arg("--blades=",BLADES)

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
	if not tufts: m.set_shader_parameter("grass_far_blades",Vector4(blades if on > 0.0 else 0.0,BLADE_WIDTHS.x,BLADE_WIDTHS.y,BLADE_WIDTHS.z))
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--sheen-set="):
			var kv := a.substr(12).split("=")
			if kv.size() == 2:
				var parts := kv[1].split(",")
				if parts.size() == 1: m.set_shader_parameter(kv[0],parts[0].to_float())
				elif parts.size() == 2: m.set_shader_parameter(kv[0],Vector2(parts[0].to_float(),parts[1].to_float()))
				elif parts.size() == 3: m.set_shader_parameter(kv[0],Vector3(parts[0].to_float(),parts[1].to_float(),parts[2].to_float()))
