#ifndef ZS_CLEAN_LOOK
#define ZS_CLEAN_LOOK
// The clean look's shared light (scripts/endless/clean_look.gd; zs_clean 0..1
// mixes it in): one soft-banded sun for ground, grass and trees, as the rock
// paints it, with a cool shade and a warm sun side.
#include "res://shaders/reference_globals.gdshaderinc"

// The sun's tint on lit sides and the sky's on shaded ones.
const vec3 ZS_CLEAN_WARM = vec3(1.05, 1.0, 0.93);
const vec3 ZS_CLEAN_COOL = vec3(0.86, 0.90, 1.22);

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

// The factor on an albedo that turns the engine's Lambert sun into the
// banded one: banded / n.l where the sun reaches, 1 off (zs_clean 0).
float zs_clean_sun_ratio(vec3 n) {
	float ndl = dot(n, zs_sun_direction);
	float banded = zs_clean_steps(ndl);
	float r = banded / max(ndl, 0.12);
	return mix(1.0, clamp(r, 0.35, 2.4), zs_clean);
}

// The sun side warm, as a tint on the albedo the sun lights.
vec3 zs_clean_sun_tint() {
	return mix(vec3(1.0), ZS_CLEAN_WARM, zs_clean);
}

// The shade's fill leaning to the sky's blue-violet.
vec3 zs_clean_cool_fill(vec3 hemi) {
	return mix(hemi, hemi * ZS_CLEAN_COOL * 1.0, zs_clean);
}
#endif
