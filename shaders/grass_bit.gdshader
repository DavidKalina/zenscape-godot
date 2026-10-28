shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;
// A clipped grass blade thrown up by the wash (scripts/endless/endless_motes.gd).
// The mesh is a strip (UV.x across 0..1, UV.y along 0..1); its shape is made
// here from the instance's custom data: x its width (m), y its length (m), z
// a phase (0..1), w how hard it flutters (0..1). A blunt cut end at UV.y 0,
// the tip at 1: a creased cross-section (a midrib), a twist and a bow along
// it, and a flutter that runs down it while the air pulls at it.
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
const float THROUGH = 0.3;
const float CUT_SHADE = 0.78;

varying float along;

void vertex() {
	float v = UV.y;
	float u = UV.x * 2.0 - 1.0;
	float width = INSTANCE_CUSTOM.x;
	float len = INSTANCE_CUSTOM.y;
	float phase = INSTANCE_CUSTOM.z * 6.2831853;
	float flutter = INSTANCE_CUSTOM.w;
	along = v;
	// Mostly parallel, tapering to the point over its last part.
	float half_w = 0.5 * width * (1.0 - pow(v, 2.6));
	float x = u * half_w;
	float yc = abs(u) * half_w * CREASE;
	float t = (v - 0.5) * TWIST * (fract(INSTANCE_CUSTOM.z * 7.31) < 0.5 ? -1.0 : 1.0);
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
	// The cross-section's normal (each half of the crease its own), turned by
	// the twist, tilted by the bow's and the flutter's slope.
	vec2 nc = normalize(vec2(-sign(u) * CREASE, 1.0));
	if (abs(u) < 0.01) nc = vec2(0.0, 1.0);
	vec2 nt = vec2(nc.x * ct - nc.y * st, nc.x * st + nc.y * ct);
	NORMAL = normalize(vec3(nt.x, nt.y, -dy));
}

void fragment() {
	vec3 c = COLOR.rgb * mix(CUT_SHADE, 1.04, smoothstep(0.0, 1.0, along));
	ALBEDO = c;
	ROUGHNESS = 0.45;
	SPECULAR = 0.5;
	BACKLIGHT = vec3(THROUGH);
	// The sky's hemisphere on the face we see (Godot has flipped NORMAL to it),
	// leaning to the sky so an underside stays green rather than going brown.
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, n.y * 0.35 + 0.65) * zs_hemi_energy / PI;
	EMISSION = c * hemi * 0.8;
}
