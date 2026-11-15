shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;
// A clipped grass blade thrown up by the wash (scripts/endless/endless_motes.gd).
// The mesh is a strip (UV.x across 0..1, UV.y along 0..1); its shape is made
// here from the instance's custom data: x its width (m), y its length (m), z
// a phase (0..1), w how hard it flutters (0..1). A blunt cut end at UV.y 0,
// the tip at 1: a creased cross-section (a midrib), a twist and a bow along
// it, and a flutter that runs down it while the air pulls at it.
// An instance colour alpha under 0.75 marks a petal (endless_motes.gd
// PETAL_MARK): a rounded, cupped oval rather than a sliver, more light
// through it.
//
// Lit by the scene like the grass (the sun through Godot's light, the sky's
// hemisphere as emission, as shaders/endless_tuft_far.gdshader): the face
// toward the sun lit, the other darker, but with light through the leaf
// (BACKLIGHT) and the wrap's soft terminator, so a turning blade dims rather
// than flips black. The instance colour is its own (linear).
#include "res://shaders/reference_globals.gdshaderinc"

// The crease's rise across a half (a share of the half-width), the twist
// along the blade (rad, end to end), the bow (a share of the length) and the
// flutter's wave (rad/s, its rise as a share of the length at full).
const float CREASE = 0.45;
const float TWIST = 0.7;
const float BOW = 0.07;
const float FLUTTER_RATE = 17.0;
const float FLUTTER_RISE = 0.09;
// The light through the blade, and the cut end's shade against the tip.
const float THROUGH = 0.45;
const float CUT_SHADE = 0.78;
// Right by the eye (the title's camera sits in the grass) a bit shrinks away
// rather than filling the screen: gone at NEAR_GONE m, whole from NEAR_FULL.
const float NEAR_GONE = 1.5;
const float NEAR_FULL = 4.5;
const float FAR_GROW = 1.8;
const float FAR_GROW_LEN = 0.5;
const float FAR_FROM = 6.0;
const float FAR_FULL = 40.0;

varying float along;
varying float petal;

void vertex() {
	float v = UV.y;
	float u = UV.x * 2.0 - 1.0;
	float width = INSTANCE_CUSTOM.x;
	float len = INSTANCE_CUSTOM.y;
	float phase = INSTANCE_CUSTOM.z * 6.2831853;
	float flutter = INSTANCE_CUSTOM.w;
	along = v;
	petal = COLOR.a < 0.75 ? 1.0 : 0.0;
	// Mostly parallel, tapering to the point over its last part; a petal
	// round at both ends, widest past its middle, and cupped.
	float half_w = 0.5 * width * (1.0 - pow(v, 2.6));
	if (petal > 0.5) half_w = 0.5 * width * pow(max(sin(3.14159 * min(v * 0.85 + 0.08, 1.0)), 0.0), 0.6);
	float x = u * half_w;
	float yc = abs(u) * half_w * (petal > 0.5 ? 1.1 : CREASE);
	float t = (v - 0.5) * TWIST * (1.0 - petal * 0.7) * (fract(INSTANCE_CUSTOM.z * 7.31) < 0.5 ? -1.0 : 1.0);
	float ct = cos(t);
	float st = sin(t);
	float bow = BOW * (0.6 + 0.8 * fract(INSTANCE_CUSTOM.z * 3.77));
	float y = bow * len * 4.0 * v * (1.0 - v);
	float dy = bow * 4.0 * (1.0 - 2.0 * v);
	// The flutter: a wave down the blade, the free ends swinging most.
	float ends = abs(v - 0.5) * 2.0;
	float wave = TIME * FLUTTER_RATE * (0.8 + 0.4 * INSTANCE_CUSTOM.z) + phase - v * 4.0;
	float swing = flutter * FLUTTER_RISE * len * (0.25 + 0.75 * ends * ends);
	y += swing * sin(wave);
	dy += -swing * cos(wave) * 4.0 / max(len, 0.05);
	VERTEX = vec3(x * ct - yc * st, x * st + yc * ct + y, (v - 0.5) * len);
	float eye_d = length((MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
	// Farther off it grows (up to FAR_GROW more across by FAR_FULL m, a blade
	// FAR_GROW_LEN more along, a petal both ways), so a bit in the air ahead
	// still reads as a fleck from the chase view rather than a hair.
	float near = smoothstep(NEAR_GONE, NEAR_FULL, eye_d);
	float far = smoothstep(FAR_FROM, FAR_FULL, eye_d);
	VERTEX.xy *= near * (1.0 + FAR_GROW * far);
	VERTEX.z *= near * (1.0 + mix(FAR_GROW_LEN, FAR_GROW, petal) * far);
	// The cross-section's normal (each half of the crease its own), turned by
	// the twist, tilted by the bow's and the flutter's slope.
	vec2 nc = normalize(vec2(-sign(u) * (petal > 0.5 ? 1.1 : CREASE), 1.0));
	if (abs(u) < 0.01) nc = vec2(0.0, 1.0);
	vec2 nt = vec2(nc.x * ct - nc.y * st, nc.x * st + nc.y * ct);
	NORMAL = normalize(vec3(nt.x, nt.y, -dy));
}

void fragment() {
	vec3 c = COLOR.rgb * mix(mix(CUT_SHADE, 0.92, petal), 1.04, smoothstep(0.0, 1.0, along));
	ALBEDO = c;
	ROUGHNESS = 0.45;
	SPECULAR = 0.5;
	BACKLIGHT = vec3(THROUGH) * (1.0 + petal * 0.6) * mix(vec3(1.0), c / max(max(c.r, c.g), max(c.b, 1e-3)), petal);
	// The sky's hemisphere on the face we see (Godot has flipped NORMAL to it),
	// leaning to the sky so an underside stays green rather than going brown.
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, n.y * 0.35 + 0.65) * zs_hemi_energy / PI;
	EMISSION = c * hemi * 1.35;
}
