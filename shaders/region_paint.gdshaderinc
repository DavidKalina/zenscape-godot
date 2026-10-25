#ifndef ZS_REGION_PAINT
#define ZS_REGION_PAINT
// A world of regions painting per spot (--world=regions, scripts/endless/
// world/profiles/regions.gd, spec-world-regions.md): zs_region_map holds
// the region weights round the eye (rgba = regions 0..3, a texel ~128 m,
// linear, so the band eases), zs_region_rect its min x, min z, size in m
// and 1 once it is drawn (0: no regions, nothing read). A material that
// paints by region carries each region's value of a paint key in a `<key>_r`
// array (the profile writes them with `region_paint_on`) and mixes them by
// the weights at its spot; elsewhere it keeps the key itself (the eye's
// blend). The near grass and trees keep the eye's (the shader globals):
// within their few hundred metres the weights barely move.
global uniform sampler2D zs_region_map : filter_linear, repeat_disable;
global uniform vec4 zs_region_rect;
// This material's `<key>_r` arrays are written (by the regions profile).
uniform bool region_paint_on = false;

// Whether this material paints by the region map here.
bool zs_region_paints() {
	return region_paint_on && zs_region_rect.w > 0.0;
}

bool zs_region_live() {
	return zs_region_rect.w > 0.0;
}

// The region weights at world xz (clamped at the map's rim), summing to 1.
vec4 zs_region_at(vec2 xz) {
	vec2 uv = clamp((xz - zs_region_rect.xy) / zs_region_rect.z, vec2(0.0), vec2(1.0));
	vec4 w = textureLod(zs_region_map, uv, 0.0);
	return w / max(w.r + w.g + w.b + w.a, 0.001);
}

vec3 zs_region_mix3(vec4 w, vec3 v[4]) {
	return v[0] * w.x + v[1] * w.y + v[2] * w.z + v[3] * w.w;
}
#endif
