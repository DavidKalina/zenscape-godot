extends RefCounted
## The pilot on foot's own paint (not the islanders' lacquer, scripts/
## person_kit.gd): a material for each of the model's surfaces, by its name
## (art/blender/pilot/pilot_build.py PALETTE, the same colours), all drawn by
## shaders/pilot_paint.gdshader: soft toon bands, warm light and cool
## shade, a gentle rim, no gloss, a painted mottle that stays on the cloth;
## the eyes hidden behind the goggles' dark sky-tinted lenses.

const PAINT := preload("res://shaders/pilot_paint.gdshader")
## Each surface: its colour, then what it changes of the paint's defaults.
const SURFACES := {
	# A plain weathered face, a little ruddy in the mottle.
	"pilot_skin": [Color("c99a78"), {"mottle":0.08,"streaks":0.02,"paint_scale":16.0}],
	"pilot_cap": [Color("5c3826"), {}],
	"pilot_fleece": [Color("f1e6cf"), {"mottle":0.09,"streaks":0.03,"paint_scale":22.0}],
	"pilot_jacket": [Color("a8743f"), {}],
	"pilot_hem": [Color("7a4a2a"), {}],
	"pilot_trousers": [Color("4f6478"), {}],
	"pilot_mitt": [Color("6b4029"), {}],
	"pilot_boots": [Color("4a3226"), {}],
	"pilot_strap": [Color("3a2418"), {}],
	"pilot_brass": [Color("8a7046"), {"rim":0.15}],
	"pilot_lens": [Color("26343f"), {"mottle":0.0,"streaks":0.0,"rim":0.0,"fill":0.6,"sun":0.15,"sheen":1.0}],
	"pilot_scarf": [Color("cc2f2f"), {}],
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
