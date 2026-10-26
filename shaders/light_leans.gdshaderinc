#ifndef ZS_LIGHT_LEANS
#define ZS_LIGHT_LEANS
// The light's hues for materials that paint some of their own light
// (scripts/shared/celestial.gd, light follow; docs/design/endless-flight/
// light-pass-handoff.md):
//   - zs_sun_hue: the key's colour at luma 1;
//   - zs_shadow_tint: the shade's, at luma 1: the sky fill's hue turned with
//     the zenith and cooled against a warm sun. The sky fill (zs_hemi_sky) is
//     this hue at the fill's strength, so every surface's shade is lit by it.
//   - zs_sun_lean, zs_shade_lean: those hues over the reference look's (the
//     default mood at 8.6 h), luma 1: (1, 1, 1) there, warmer or cooler as
//     the hour and the mood turn the light. --light-follow=0 holds them at 1.
// A painted warm tone (a sunlit facet, a warm patch, a glint) is the
// material's own nudge times zs_warm; a painted cool tone (a shaded facet, a
// cool patch, a crack) times zs_cool. `k` is how far it follows (1 as the
// light moves).
global uniform vec3 zs_sun_hue;
global uniform vec3 zs_shadow_tint;
global uniform vec3 zs_sun_lean;
global uniform vec3 zs_shade_lean;
// --light-follow (1 on, 0 the light as before the light pass).
global uniform float zs_light_follow;

vec3 zs_warm(vec3 c, float k) {
	return c * pow(max(zs_sun_lean, vec3(1e-3)), vec3(k));
}

vec3 zs_cool(vec3 c, float k) {
	return c * pow(max(zs_shade_lean, vec3(1e-3)), vec3(k));
}

// A glint's colour (`c`, the material's own for the reference light) turned
// with the sun, its brightest channel kept.
vec3 zs_glint(vec3 c) {
	vec3 g = c * zs_sun_lean;
	return g * max(c.r, max(c.g, c.b)) / max(max(g.r, max(g.g, g.b)), 1e-4);
}
#endif
