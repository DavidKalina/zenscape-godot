// The painterly grass look shared by every tier (docs/scenic/grass-look.md):
// the dense Ultra meadow (shaders/dense_grass.gdshader) and the dressed
// grass tufts every tier draws (reference_surface.gdshader with
// `grass_blades`). Both call these so the two read as one grass. Include after
// reference_wind, which supplies zs_noise and the wind globals.
#ifndef ZS_GRASS_LOOK
#define ZS_GRASS_LOOK

// Shifts the world-scale grass noise (dry patches, wave wander) per world
// seed, so every tier puts them in the same places (scripts/dense_grass.gd).
global uniform vec2 zs_grass_offset;

// Defaults both use; dense grass exposes each as a uniform of the same name
// without the prefix, the tufts use these as they are.
const float ZS_GRASS_WAVE_LENGTH = 6.5;
const float ZS_GRASS_WAVE_SPEED = 1.0;
const float ZS_GRASS_WAVE_STRENGTH = 0.6;
const float ZS_GRASS_WAVE_SHEEN = 0.22;
const vec3 ZS_GRASS_ROOT_SHADE = vec3(0.46, 0.53, 0.46);
const vec3 ZS_GRASS_TIP_LIFT = vec3(1.30, 1.28, 0.84);
const float ZS_GRASS_TIP_CURVE = 0.8;
const float ZS_GRASS_TIP_TRANSLUCENCY = 0.55;
const float ZS_GRASS_DRY_SCALE = 0.16;
const vec3 ZS_GRASS_STRAW = vec3(1.18, 1.0, 0.62);

// 0..1: how near a wind wave's crest this root stands. Long waves roll
// downwind on the air's own travel (zs_gust_distance), so they move with the
// gust field and are frame-rate independent; a noise bends their crests.
float zs_grass_crest(vec2 g_root, float g_wave_length, float g_wave_speed, vec2 g_offset) {
	float g_along = dot(g_root, zs_wind_direction);
	float g_side = dot(g_root, vec2(-zs_wind_direction.y, zs_wind_direction.x));
	float g_wander = zs_noise(vec2(g_side * 0.16, g_along * 0.05) + g_offset) * 3.0;
	float g_crest = 0.5 + 0.5 * sin((g_along - zs_gust_distance * g_wave_speed) * TAU / g_wave_length + g_wander);
	return g_crest * g_crest;
}

// 0..1: how far this spot has gone to straw, from world noise.
float zs_grass_dry(vec2 g_root, float g_scale, vec2 g_offset) {
	return smoothstep(0.5, 0.78, zs_noise(g_root * g_scale + g_offset * 0.73 + 5.0));
}

// Straw patches, then dark at the root and sunlit toward the tip.
vec3 zs_grass_paint(vec3 g_tint, float g_along, float g_dry, vec3 g_straw, vec3 g_root_shade, vec3 g_tip_lift, float g_tip_curve) {
	float g_lum = dot(g_tint, vec3(0.30, 0.55, 0.15));
	g_tint = mix(g_tint, g_lum * g_straw, clamp(g_dry, 0.0, 1.0));
	return g_tint * mix(g_root_shade, g_tip_lift, pow(clamp(g_along, 0.0, 1.0), g_tip_curve));
}

// The field's soft-mass normal: the ground's, domed outward over the tuft
// toward its tips (`out_dir` from the tuft's centre), tipped by `tilt`.
vec3 zs_grass_mass_normal(vec3 g_ground_normal, vec2 g_out_dir, float g_along, float g_roundness, vec2 g_tilt) {
	vec2 g_dome = g_out_dir / max(length(g_out_dir), 0.02) * g_roundness * g_along + g_tilt;
	return normalize(g_ground_normal + vec3(g_dome.x, 0.0, g_dome.y));
}

// Sunlight through the thin tips, strongest looking toward the sun. Called
// from light() under ZS_GRASS_TRANSLUCENCY with the shadowed light energy.
vec3 zs_grass_translucency(vec3 g_to_light, vec3 g_to_view, vec3 g_albedo, float g_along, float g_strength) {
	float g_toward = pow(max(dot(-g_to_light, g_to_view), 0.0), 4.0);
	return g_albedo * vec3(1.0, 1.12, 0.62) * g_strength * g_along * g_along * (0.2 + 0.8 * g_toward) / PI;
}
#endif
