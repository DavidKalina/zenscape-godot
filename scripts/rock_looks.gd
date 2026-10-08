extends RefCounted
## Rock looks for every sky islet's earth sides (scripts/sky_islets.gd
## `_side_material`): the clusters' members (their motif's palettes) and the
## lone islets between them (`seeded`), so the whole sky's rock is one
## family with the peaks' dark basalt rather than the plate's layer cake.
## The earth sides' strata (scripts/strata.gd, the shader's zs strata
## uniforms) are recoloured: a thin turf and topsoil skin over close, dark,
## nearly neutral tones, the bands still there but quiet. Each look is
## sRGB, by band.
##
## Variety, member by member: `tone` brightens or darkens one a little;
## `vary` (0 to 1, from its seed, VARIANTS steps) moves its bands up or
## down by up to SHIFT and leans its colour a touch warm or cool (LEAN), so
## the islets of one cluster differ side by side. Its facets stand apart in
## light and dark by FACETS (the shader's `side_facets`; the plate's sides
## keep their own, softer), so the rock reads as faceted solid, as the
## peaks' basalt does; and its colours are its own, never the world's
## ground palette (the shader's `side_own`), as the peaks' are.

const Strata = preload("res://scripts/strata.gd")

const LOOKS := {
	"basalt": {"topsoil":"352c27","clay":"393735","sand":"36373a","shale":"2c2c2f","shale_dark":"222226",
		"bedrock":"313236","core_a":"46474b","core_b":"515257","core_c":"3a3b3f"},
	"basalt_warm": {"topsoil":"382e28","clay":"3b3836","sand":"3a3836","shale":"302f2e","shale_dark":"252424",
		"bedrock":"353432","core_a":"4a4846","core_b":"55534f","core_c":"3f3d3b"},
	"slate": {"topsoil":"352d28","clay":"3f4044","sand":"484a4f","shale":"313439","shale_dark":"25282c",
		"bedrock":"383b41","core_a":"484c53","core_b":"53575e","core_c":"3c4045"},
}
## Every look cools this much toward the peaks' blue-grey (scripts/
## sky_peak.gd COOL_HUE), so under a warm sun it reads as their family.
const COOL := Color(0.94,0.98,1.08)
## The looks are authored dark; drawn on the earth sides' shading they read
## near black, so they are lifted this much to sit with the peaks' basalt.
const LIFT := 1.55
## The bands' floors (m): a thin topsoil, then the dark rock close under it.
const FLOORS := Vector4(-0.3,-0.75,-1.3,-2.1)
## Per member: how far its bands move (m either way), how far its colour
## leans warm or cool (share), in how many steps.
const SHIFT := 0.45
const LEAN := 0.05
const VARIANTS := 5
## How far its facets' shades spread (a share, half of it either way; the
## plate's sides 0.14).
const FACETS := 0.45
## A lone islet's look (`seeded`): palettes by weight, tone range, and how
## much deeper than its own its rock hangs (`keel`), as a cluster's.
const LONE := {"basalt":1.0,"slate":0.7,"basalt_warm":0.55}
const LONE_TONE := Vector2(0.86,1.1)
const LONE_KEEL := Vector2(1.35,1.85)

## Sets a look's colours (at `tone`, 1 as authored; `vary`, 0 to 1, its
## variant) on an earth sides material already given its strata (Strata
## `apply`); with `bed` (m), the rock's beds that high instead of the
## strata's own (a sea cliff's, scripts/sea_cliffs.gd).
static func apply(material: ShaderMaterial, look: String, tone := 1.0, vary := 0.5, bed := 0.0) -> void:
	var colours: Dictionary = LOOKS.get(look,LOOKS.basalt)
	var lean := (step_of(vary)-0.5)*2.0*LEAN
	var tint := Color(1.0+lean,1.0,1.0-lean)*COOL
	for key: String in colours:
		var c := Color(colours[key])*tone*LIFT*tint
		c = Color(minf(c.r,1.0),minf(c.g,1.0),minf(c.b,1.0)).srgb_to_linear()
		material.set_shader_parameter("strata_"+key,Vector3(c.r,c.g,c.b))
	var shift := (step_of(vary)-0.5)*2.0*SHIFT
	material.set_shader_parameter("strata_floors",FLOORS+Vector4.ONE*shift)
	material.set_shader_parameter("side_facets",FACETS)
	material.set_shader_parameter("side_own",true)
	if bed > 0.0: material.set_shader_parameter("strata_core",Vector4(Strata.CORE_FROM,Strata.CORE_BASE,bed,Strata.SHALE_BED))

## `vary` snapped to its VARIANTS steps (so islets share materials).
static func step_of(vary: float) -> float:
	return (floorf(clampf(vary,0.0,0.999)*VARIANTS)+0.5)/VARIANTS

## A member's variant, from its seed.
static func vary_of(seed_value: int) -> float:
	return float(hash([seed_value,"rock"]) % 1000)/1000.0

## A lone islet's rock, by its seed: {palette, tone, vary}, and `deep`, the
## keel range's draw (`keel`).
static func seeded(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value,"rock look"])
	var total := 0.0
	for k: String in LONE: total += float(LONE[k])
	var roll := rng.randf()*total
	var palette: String = LONE.keys()[0]
	for k: String in LONE:
		roll -= float(LONE[k])
		if roll <= 0.0:
			palette = k
			break
	return {"rock":{"palette":palette,"tone":rng.randf_range(LONE_TONE.x,LONE_TONE.y),"vary":rng.randf()},
		"deep":rng.randf_range(LONE_KEEL.x,LONE_KEEL.y)}

## How much deeper than its own an islet of `radius` hangs, `deep` its
## draw: the whole of it on a big islet, less on a small one, so a run of
## small ones reads as rocks, not teeth.
static func keel(radius: float, deep: float) -> float:
	return lerpf(1.0,deep,clampf((radius-2.0)/7.0,0.25,1.0))
