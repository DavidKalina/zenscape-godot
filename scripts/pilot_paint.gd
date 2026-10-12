extends RefCounted
## The pilot on foot's own paint (not the islanders' lacquer, scripts/
## person_kit.gd): a material for each of the model's surfaces, by its name
## (art/blender/pilot/pilot_build.py PALETTE, the same colours), all drawn by
## shaders/pilot_paint.gdshader: soft toon bands, warm light and cool
## shade, a gentle rim, no gloss, a painted mottle that stays on the cloth.
## The wanderer's sheet (docs/design/wanderer-look/round1.md): the hat in
## terracotta felt, the face a dark brown shadow with two glowing cyan eyes
## painted on it, a navy scarf, a charcoal-brown jacket, denim trousers,
## brown mitts and boots with tan fleece, gold bracelets with a glowing
## stripe, a charcoal cape. The sheet's hexes: terracotta c9644a, brown
## 5a3a2c, tan d9bc9c, navy 2e4fa3, cyan 5fe6e6, charcoal 4a4848 (the
## plane's livery shares them); the rest are shades between.

const PAINT := preload("res://shaders/pilot_paint.gdshader")
## The sheet's glow (the eyes, the bracelets' stripes, the cap's rotor).
const GLOW := Color("5fe6e6")
## The surfaces that are the hat (hidden on the head while it flies as the
## pocket sail, scripts/pocket_sail_figure.gd).
const HAT := ["pilot_hat","pilot_hat_band"]
## Each surface: its colour, then what it changes of the paint's defaults.
const SURFACES := {
	# The face in the hat's shade, the eyes painted on it (the shader's
	# `eyes`, driven by scripts/pilot_figure.gd).
	"pilot_face": [Color("3b2a22"), {"mottle":0.05,"streaks":0.02,"rim":0.18,"eyes":1.0}],
	# Soft felt: a fine, fuzzy mottle.
	"pilot_hat": [Color("c9644a"), {"mottle":0.12,"streaks":0.04,"paint_scale":26.0,"rim":0.16}],
	"pilot_hat_band": [Color("4a2f24"), {}],
	# Chunky knit.
	"pilot_scarf": [Color("2e4fa3"), {"mottle":0.12,"streaks":0.05,"paint_scale":30.0}],
	"pilot_jacket": [Color("4a403c"), {"rim":0.16}],
	"pilot_strap": [Color("5a3a2c"), {}],
	"pilot_gold": [Color("d9a441"), {"mottle":0.05,"streaks":0.02,"rim":0.35,"sheen":0.35}],
	"pilot_glow": [GLOW, {"mottle":0.0,"streaks":0.0,"glow":2.2}],
	"pilot_mitt": [Color("7a4e38"), {}],
	"pilot_trousers": [Color("2c3b62"), {"mottle":0.12,"streaks":0.09}],
	"pilot_boots": [Color("7a4a32"), {}],
	"pilot_fleece": [Color("d9bc9c"), {"mottle":0.1,"streaks":0.03,"paint_scale":22.0}],
	"pilot_cape": [Color("4a4848"), {"mottle":0.12,"streaks":0.08,"rim":0.18}],
}

## The materials, keyed by the model's surface names.
static func outfit() -> Dictionary:
	var out := {}
	for key: String in SURFACES:
		var m := ShaderMaterial.new()
		m.shader = PAINT
		m.resource_name = key
		m.set_shader_parameter("albedo",SURFACES[key][0])
		var tweaks: Dictionary = SURFACES[key][1]
		for p: String in tweaks: m.set_shader_parameter(p,tweaks[p])
		out[key] = m
	return out
