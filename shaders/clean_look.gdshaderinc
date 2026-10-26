#ifndef ZS_CLEAN_LOOK
#define ZS_CLEAN_LOOK
// The look's shared light (scripts/endless/clean_look.gd): one soft-banded sun for ground, grass and trees, as the rock
// paints it, with a cool shade and a warm sun side.
#include "res://shaders/reference_globals.gdshaderinc"

// The sun's tint on lit sides and the sky's on shaded ones: globals the look
// sets each frame from the published light (zs_cl_warm from the sun's colour,
// zs_cl_cool from the sky's fill), not fixed colours.
#define ZS_CLEAN_WARM zs_cl_warm
#define ZS_CLEAN_COOL zs_cl_cool

// Three soft steps from shade to full sun over wrapped n.l (0..1), the rock's
// ramp (endless_rock.gdshaderinc), mapped to a share of the sun (0.1..0.86).
float zs_clean_steps(float ndl) {
	float lit = ndl * 0.5 + 0.5;
	float tier = lit * 3.0;
	float t = floor(tier) + smoothstep(0.32, 0.68, fract(tier));
	t = clamp(t / 2.0, 0.0, 1.0);
	t = mix(lit, t, 0.8);
	return (0.10 + 0.90 * t) * 0.86;
}

// The banded sun as a share of the light, kept level with Lambert on flat
// ground (so the steps move light about the mean rather than raising it).
float zs_clean_banded(float ndl) {
	float flat_n = clamp(zs_sun_direction.y, 0.12, 1.0);
	return zs_clean_steps(ndl) * flat_n / zs_clean_steps(flat_n);
}

// The factor on an albedo that turns the engine's Lambert sun into the
// banded one: banded / n.l where the sun reaches.
float zs_clean_sun_ratio(vec3 n) {
	float ndl = dot(n, zs_sun_direction);
	float r = zs_clean_banded(ndl) / max(ndl, 0.12);
	return clamp(r, 0.35, 2.4);
}

// The sun side warm, as a tint on the albedo the sun lights.
vec3 zs_clean_sun_tint() {
	return ZS_CLEAN_WARM;
}

// The shade's fill leaning to the sky's blue-violet.
vec3 zs_clean_cool_fill(vec3 hemi) {
	return hemi * ZS_CLEAN_COOL;
}
#endif
