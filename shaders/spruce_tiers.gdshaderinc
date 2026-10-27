#ifndef ZS_SPRUCE_TIERS_INC
#define ZS_SPRUCE_TIERS_INC
// The spruces' painterly look (--spruce-look=b; scripts/hero_trees.gd
// SPRUCE_BL, docs/design/endless-flight/spruce-plastic-handoff.md round 2):
// a crown read as a few big painted shapes. Shared by the near and mid crowns
// (spruce_paint.gdshaderinc, reference_direct_light.gdshaderinc), the rings,
// the sprites and the sprites' normal bake, so all of them paint a tier alike.
// Needs spruce_variety.gdshaderinc (its value noise).
#include "res://shaders/spruce_variety.gdshaderinc"
//
// `t` is (tilt, band, top, coolshade) and `t2` (warmlit, dab gain, dab size in
// px, the distance the dabs come in from m), all off at 0.
//
// The coordinate down a tier is the generator's grey bake: 0.42 in the dark core,
// 0.55 where a bough leaves the trunk, 1.02 at its tips (tools/blender_trees/
// spruce_sprays.py), so 0 high on the tier, 1 at its skirt.

// The shade's hues over its luminance: olive (the world's shadow, round 4) and
// a cool blue-green; `coolshade` moves between them.
const vec3 ZS_ST_OLIVE = vec3(1.20, 1.05, 0.22);
const vec3 ZS_ST_COOL = vec3(0.62, 1.02, 1.30);
// The sunlit side's warm yellow-green (a multiplier over the lit term).
const vec3 ZS_ST_WARM = vec3(1.16, 1.06, 0.74);
// The dark band under a tier's skirt (cool, deep) and a tier's lit top (warm).
const vec3 ZS_ST_BAND = vec3(0.68, 0.78, 0.90);
const vec3 ZS_ST_TOP = vec3(1.18, 1.13, 0.86);
// The distance dabs' tones (as spruce_paint's SPRUCE_SUNLIT and SPRUCE_DEEP).
const vec3 ZS_ST_DAB_LIT = vec3(1.15, 1.13, 1.02);
const vec3 ZS_ST_DAB_DEEP = vec3(0.80, 0.85, 0.93);

vec3 zs_st_shade(float cool) {
	return mix(ZS_ST_OLIVE, ZS_ST_COOL, cool);
}

// Where on its tier a point is, from the bake: `dark` the shade under the tier
// above's skirt (the core cone and the inner sheet, bake under 0.8), `top` the
// sheet's lit slope (0.8 to 0.93), `skirt` the tip zone at the lower edge
// (over 0.93). On a visible crown the bake is 0.55 to 1.02 times the tree's own
// tone (0.86 to 1.04), so the edges are a little different tree to tree.
// The edges are short, a painted step rather than a ramp.
// `far` (0 near, 1 past 200 m, the rings and the sprites') narrows the dark zone to the core
// and the trunk end: a distance crown is one skirt from the apex, whose inner half
// is its lit top, not a shade.
vec3 zs_st_zones(float bake, float far) {
	float dark = 1.0 - smoothstep(0.72 - 0.14 * far, 0.82 - 0.14 * far, bake);
	float skirt = smoothstep(0.90, 0.96, bake);
	float top = (1.0 - dark) * (1.0 - skirt);
	return vec3(dark, top, skirt);
}

// The crown's light normal turned by where it is on its tier: tipped up on the
// sheet's lit slope, down in the shade under a skirt and at the skirt's edge, as
// a stack of cones is lit, so the painted steps break across each tier and not
// down the tree.
vec3 zs_st_normal(vec3 n, float bake, float tilt, float far) {
	vec3 z = zs_st_zones(bake, far);
	n.y += tilt * (0.9 * z.y - 0.55 * z.z - 0.3 * z.x);
	return normalize(n);
}

// The tier's own painted tones in the albedo: a lit warm slope, a cool dark
// band under the skirt (and the tip zone where the face looks down). `under` 0
// where the face looks up, 1 where it looks down.
vec3 zs_st_paint(vec3 tint, float bake, float under, vec4 t, float far) {
	vec3 z = zs_st_zones(bake, far);
	float dim = z.x * mix(0.75, 1.0, under) + z.z * under * 0.7;
	tint *= mix(vec3(1.0), ZS_ST_TOP, clamp(z.y * (1.0 - 0.5 * under) * t.z, 0.0, 1.0));
	tint *= mix(vec3(1.0), ZS_ST_BAND, clamp(dim * t.y, 0.0, 1.0));
	return tint;
}

// A dab with an edge, -0.5 or 0.5 either side, the edge a blur of a pixel or so.
float zs_st_patch(vec2 p, float scale, float fp) {
	float w = 0.05 + fp / scale * 0.7;
	return smoothstep(0.5 - w, 0.5 + w, zs_sv_noise(p / scale)) - 0.5;
}

// Painted break-up in place of texture b's facets, which are gone past 110 m:
// dabs in the tree's own frame (`p`, m from its foot, height folded in) whose
// size grows with distance, so a dab stays `t2.z` pixels wide (`pxm` is the
// metres a pixel spans at this distance). The size steps by octaves and the
// two nearest cross-fade, so nothing swims as the eye moves.
vec3 zs_st_dabs(vec3 tint, vec2 p, float dist, float pxm, vec4 t2) {
	if (t2.y <= 0.0) return tint;
	float far = smoothstep(t2.w * 0.55, t2.w * 1.15, dist) * (1.0 - 0.7 * smoothstep(1500.0, 3500.0, dist));
	if (far <= 0.0) return tint;
	float size = max(t2.z * pxm, 0.25);
	float l = log2(size / 0.25);
	float s0 = 0.25 * exp2(floor(l));
	float f = smoothstep(0.0, 1.0, fract(l));
	float d = mix(zs_st_patch(p, s0, pxm), zs_st_patch(p + vec2(23.0, 7.0), s0 * 2.0, pxm), f) * 2.0;
	d = clamp(d * t2.y * far, -1.0, 1.0);
	return tint * mix(vec3(1.0), d > 0.0 ? ZS_ST_DAB_LIT : ZS_ST_DAB_DEEP, abs(d));
}

// How far a crown at `dist` m is a distance crown (zs_st_zones' `far`).
float zs_st_far(float dist) {
	return smoothstep(80.0, 200.0, dist);
}

// The metres a pixel spans at distance `dist` (the projection and the viewport's).
float zs_st_pixel(float dist, float proj_y, float viewport_y) {
	return dist * 2.0 / max(viewport_y * proj_y, 1.0);
}
#endif
