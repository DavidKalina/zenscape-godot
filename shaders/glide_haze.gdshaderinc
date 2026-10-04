#ifndef ZS_GLIDE_HAZE
#define ZS_GLIDE_HAZE
// The glide's aerial perspective (scripts/sky_haze.gd, which keeps the same
// curve on the CPU as `fog`): how much of a thing at `dist` metres, standing
// at height `y`, has gone into the sky's colour. A gentle curve, so what is
// near keeps its colour, scaled by the reach (zs_glide_haze.y); thicker
// low down toward the cloud sea (zs_glide_haze.w); and whole by
// zs_glide_haze.z, where islets are built and islands let go, so nothing
// ever shows up out of clear air. Not scaled by zs_glide_haze.x: callers
// lay it on by that.
#include "res://shaders/reference_globals.gdshaderinc"

float zs_glide_fog(float dist, float y) {
	float low = smoothstep(zs_glide_haze.w + 75.0, zs_glide_haze.w, y);
	float reach = dist * (1.0 + 0.6 * low) / max(zs_glide_haze.y, 1.0);
	float seen = exp(-reach * reach) * (1.0 - smoothstep(zs_glide_haze.z * 0.72, zs_glide_haze.z, dist));
	return 1.0 - seen;
}
#endif
