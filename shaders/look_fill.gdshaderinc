#ifndef ZS_LOOK_FILL
#define ZS_LOOK_FILL
// The look pass's light into the shade (scripts/look_pass.gd, 0 elsewhere):
//   - `zs_look_bounce`: the sunlit cloud sea below lighting what faces down
//     on it, the isles' bellies and keels and the undersides of beams, in
//     the cloud's own light (zs_cloud_sun, which leans on the moon by night);
//   - `zs_look_fill`: more of the sky's hemisphere where the sun does not
//     reach, so shaded crag and stone keep their form instead of going black.
// The includer declares zs_cloud_sun, zs_hemi_sky and zs_hemi_energy.
global uniform float zs_look_bounce;
global uniform float zs_look_fill;

// How much of the cloud sea below a face sees: all of it facing straight
// down, a quarter upright, none facing up.
float zs_cloud_below(vec3 normal) {
	float down = clamp(0.5 - 0.5 * normal.y, 0.0, 1.0);
	return down * down;
}

// The bounce's irradiance over PI, for a face's world normal.
vec3 zs_look_bounce_light(vec3 normal) {
	return zs_cloud_sun * zs_cloud_below(normal) * zs_look_bounce;
}

// The sky fill's irradiance over PI, for how much of the face is in shade.
vec3 zs_look_fill_light(float shade) {
	return zs_hemi_sky * zs_hemi_energy / PI * zs_look_fill * shade;
}
#endif
