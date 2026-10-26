#ifndef ZS_BACKLIGHT_INC
#define ZS_BACKLIGHT_INC
// Backlight (light pass round 2, docs/design/endless-flight/
// light-pass-2-handoff.md): grass tips and the edges of spruce crowns seen
// against a low sun catch it, a glow in the sun's own colour through the
// leaf. zs_backlight (scripts/shared/celestial.gd BACKLIGHT_E) is 1 at
// golden hour under a clear sky and 0 above sun height 0.42, at night and
// with --backlight=0, so the day's look is untouched.
global uniform float zs_backlight;
// How much of the glow keeps the leaf's own hue (the rest white, so the
// sun's colour leads: gold, not green).
const float ZS_BACKLIGHT_LEAF = 0.45;

// How strongly a thin edge glows: `toward` is the view ray's cosine to the
// sun (1 looking straight at it: dot(-LIGHT, VIEW) in light()), `thin` how
// thin the spot is (a tip's share, a silhouette's rim), `gain` the
// material's own.
float zs_backlight_amount(float toward, float thin, float gain) {
	float t = max(toward, 0.0);
	return zs_backlight * gain * thin * (0.6 * pow(t, 8.0) + 0.9 * pow(t, 32.0));
}

// How bright the light through a leaf is (times the sun's light), whatever
// the leaf's own albedo: a dark spruce's needles glow as a pale blade does.
const float ZS_BACKLIGHT_THROUGH = 0.25;

// The DIFFUSE_LIGHT (or BACKLIGHT) multiplier for a glow `amount` on
// `albedo`: Godot multiplies diffuse light by the albedo, so this divides
// it back out, leaving the glow at ZS_BACKLIGHT_THROUGH, its hue mostly
// the sun's with ZS_BACKLIGHT_LEAF of the leaf's.
vec3 zs_backlight_tint(vec3 albedo, float amount) {
	vec3 a = max(albedo, vec3(0.02));
	float l = dot(a, vec3(0.2126, 0.7152, 0.0722));
	vec3 hue = mix(vec3(1.0), clamp(a / l, vec3(0.0), vec3(3.0)), ZS_BACKLIGHT_LEAF);
	return amount * ZS_BACKLIGHT_THROUGH * hue / a;
}
#endif
