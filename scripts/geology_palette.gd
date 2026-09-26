extends RefCounted
## Desert geology colours: sand, three strata bands, desert varnish and salt.
## DEFAULTS are the colours `shaders/terrain_geology.gdshaderinc` used to
## hard-code; a world without its own geology (every save before this, and
## hand-formed deserts) still gets exactly these. Generated deserts derive
## theirs from the world palette, leaning each default toward the palette's
## rock or earth hue, so they stay close to the old look. A palette family
## may supply its own `bases` (pale limestone, deep rust) in place of DEFAULTS.
const DEFAULTS := {
	"sand_a":"e0b36f","sand_b":"cf9d58",
	"band_a":"a5502f","band_b":"8f3f2a","band_c":"c9875a",
	"varnish":"7d3a26","salt":"e7dfc9"}
## Which palette colour each geology colour leans toward, and how far.
const LEAN := {
	"sand_a":["earth",0.35],"sand_b":["earth",0.35],
	"band_a":["rock",0.4],"band_b":["rock",0.4],"band_c":["rock",0.4],
	"varnish":["earth",0.3],"salt":["rock",0.15]}

static func derive(colors: Dictionary,seed_value: int,bases: Dictionary = {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*7919+5557
	var result := {}
	for key: String in DEFAULTS:
		var base := Color(bases.get(key,DEFAULTS[key]))
		var toward: Color = colors[LEAN[key][0]]
		var hue := fposmod(base.h+wrapf(toward.h-base.h,-0.5,0.5)*float(LEAN[key][1]),1.0)
		var sat := clampf(base.s*rng.randf_range(0.9,1.1),0.0,1.0)
		var value := clampf(base.v*rng.randf_range(0.96,1.04),0.0,1.0)
		result[key] = Color.from_hsv(hue,sat,value).to_html(false)
	return result

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=DEFAULTS.size(): return false
	for key in DEFAULTS:
		var c: Variant = value.get(key)
		if not c is String or c.length()!=6 or not c.is_valid_html_color(): return false
	return true
