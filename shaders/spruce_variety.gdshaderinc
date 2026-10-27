#ifndef ZS_SPRUCE_VARIETY_INC
#define ZS_SPRUCE_VARIETY_INC
// The spruces' green and blue variety and their mid-distance contrast
// (--spruce-look=g; scripts/hero_trees.gd SPRUCE_G, docs/design/endless-flight/
// spruce-plastic-handoff.md round 1). No dependencies, so the near and far
// crowns (spruce_paint.gdshaderinc), the rings and the sprites all read the
// one hash of a tree's foot and agree on which trees are blue.
//
// `v` is (share of blue trees, grove scale m, grove lean, a green tree's own
// blue), all of it off while v.y (the scale) is 0.

const vec3 ZS_SV_GLAUCOUS = vec3(0.50, 1.08, 1.45);
// The fresh outer needles' lift and the older inner needles' olive (multipliers).
const vec3 ZS_SV_FRESH = vec3(1.16, 1.20, 0.86);
const vec3 ZS_SV_INNER = vec3(0.80, 0.84, 0.60);

float zs_sv_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float zs_sv_cell(vec2 p) {
	return fract(sin(dot(p, vec2(41.31, 17.77))) * 21895.3);
}

float zs_sv_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(zs_sv_cell(i), zs_sv_cell(i + vec2(1.0, 0.0)), f.x), mix(zs_sv_cell(i + vec2(0.0, 1.0)), zs_sv_cell(i + vec2(1.0, 1.0)), f.x), f.y);
}

// 0..1, low in a grove that leans green and high in one that leans blue: a
// world-space noise a few hundred metres across, so a patch shares a lean.
float zs_sv_grove(vec2 root, float scale) {
	vec2 p = root / max(scale, 1.0);
	float n = zs_sv_noise(p) * 0.65 + zs_sv_noise(p * 2.3 + vec2(17.0, 5.0)) * 0.35;
	return clamp((n - 0.5) * 2.4 + 0.5, 0.0, 1.0);
}

// How blue the tree at `root` is: 0 green, 1 blue. The share of blue trees is
// `v.x` over the land, a grove moves its own threshold by `v.z`.
float zs_sv_blueness(vec2 root, vec4 v) {
	float thr = 1.0 - v.x - (zs_sv_grove(root, v.y) - 0.5) * v.z * 1.6;
	return smoothstep(thr - 0.07, thr + 0.07, zs_sv_hash(root));
}

// The strength of the glaucous mix on that tree (before the blue knob): a
// green tree's own little, a blue tree's 0.62 to 1.12 by its own rank.
float zs_sv_blue_k(vec2 root, float rank, vec4 v) {
	return mix(v.w, mix(0.62, 1.12, rank), zs_sv_blueness(root, v));
}

// Where the crown's own value reads at range: the older inner needles darker
// and olive, the fresh outer tips lighter, from the generator's grey bake
// (0.42 core, 0.55 at the trunk, 1.02 at the tips). `inner` and `fresh` are
// the knobs. Not eased with distance: a sprite's atlas holds the same.
vec3 zs_sv_needles(vec3 tint, float bake, float inner, float fresh) {
	float old = 1.0 - smoothstep(0.45, 0.88, bake);
	float tip = smoothstep(0.78, 1.0, bake);
	tint *= mix(vec3(1.0), ZS_SV_INNER, old * inner);
	tint *= mix(vec3(1.0), ZS_SV_FRESH, tip * fresh);
	return tint;
}

// The tip share alone (for the rim's glow).
float zs_sv_tip(float bake) {
	return smoothstep(0.78, 1.0, bake);
}

// A mid-distance wood keeps its outline against the meadow: from 80 m out the
// crown's colour is pulled back toward its own (saturation up, a little
// darker), the share `haze` of what it would lose to the air, the effect
// peaking by 300 m and easing off again past 900 m as the real fog takes over.
vec3 zs_sv_keep(vec3 c, float dist, float haze) {
	if (haze <= 0.0) return c;
	float w = smoothstep(80.0, 300.0, dist) * (1.0 - 0.6 * smoothstep(900.0, 2000.0, dist)) * haze;
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(vec3(l), c, 1.0 + 0.45 * w);
	return c * (1.0 - 0.04 * w);
}
#endif
