// The painterly grass look shared by every tier (docs/scenic/grass-look.md):
// the dense Ultra meadow (shaders/dense_grass.gdshader) and the dressed
// grass tufts every tier draws (reference_surface.gdshader with
// `grass_blades`). Both call these so the two read as one grass. Include after
// reference_wind, which supplies zs_noise and the wind globals.
#ifndef ZS_GRASS_LOOK
#define ZS_GRASS_LOOK

// Shifts the world-scale grass noise (dry patches, wave wander) per world
// seed, so every tier puts them in the same places (scripts/dense_grass.gd).
// Declared with the wind globals (reference_globals), so flowers and other
// low plants ride the same waves.
#ifndef ZS_GRASS_OFFSET_DECLARED
global uniform vec2 zs_grass_offset;
#endif

// Defaults both use; dense grass exposes each as a uniform of the same name
// without the prefix, the tufts use these as they are (the tufts' straw
// share is their own `grass_dry` uniform). The wave itself is the shared
// breeze's (reference_wind, docs/scenic/breeze.md).
const float ZS_GRASS_WAVE_LENGTH = ZS_BREEZE_WAVE_LENGTH;
const float ZS_GRASS_WAVE_SPEED = ZS_BREEZE_WAVE_SPEED;
const float ZS_GRASS_WAVE_STRENGTH = ZS_BREEZE_WAVE;
const float ZS_GRASS_WAVE_SHEEN = 0.34;
const vec3 ZS_GRASS_ROOT_SHADE = vec3(0.46, 0.53, 0.46);
const vec3 ZS_GRASS_TIP_LIFT = vec3(1.30, 1.28, 0.84);
const float ZS_GRASS_TIP_CURVE = 0.8;
const float ZS_GRASS_TIP_TRANSLUCENCY = 0.55;
const float ZS_GRASS_DRY_SCALE = 0.16;
const vec3 ZS_GRASS_STRAW = vec3(1.18, 1.0, 0.62);
// Living colour. Palette families tint grass by their ratio to the source's
// grass green (#5d9e53, ZS_GRASS_SOURCE in linear). On a muted family such as
// Chalk & turquoise (#929c72) that ratio is about (2.6, 1.0, 1.9), which
// turns the tuft's yellow-green tips to straw and its roots to grey. Grass
// instead takes the family's own grass colour and leans it toward living
// green (ZS_GRASS_LIVING_HUE is the source green at unit luminance), keeping
// the family's lightness and some of its hue. The pull is `grass_living` on
// the tufts and `living_pull` on the dense grass, both 0.4.
const vec3 ZS_GRASS_SOURCE = vec3(0.1094, 0.3419, 0.0865);
const vec3 ZS_GRASS_LIVING_HUE = vec3(0.4678, 1.4621, 0.3699);
const float ZS_GRASS_LIVING_SATURATION = 1.12;

// A family's grass colour leaned `g_pull` of the way to living green at the
// same luminance, then saturated a little.
vec3 zs_grass_living(vec3 g_family, float g_pull, float g_saturation) {
	float g_lum = dot(g_family, vec3(0.30, 0.55, 0.15));
	vec3 g_color = mix(g_family, ZS_GRASS_LIVING_HUE * g_lum, clamp(g_pull, 0.0, 1.0));
	float g_after = dot(g_color, vec3(0.30, 0.55, 0.15));
	return max(mix(vec3(g_after), g_color, g_saturation), vec3(0.0));
}

// 0..1: how near a wind wave's crest this root stands. Long waves roll
// downwind on the air's own travel (zs_gust_distance), so they move with the
// gust field and are frame-rate independent; a noise bends their crests
// (zs_wave_crest_at, shared with every plant the breeze bends).
float zs_grass_crest(vec2 g_root, float g_wave_length, float g_wave_speed, vec2 g_offset) {
	return zs_wave_crest_at(g_root, g_wave_length, g_wave_speed, g_offset, zs_gust_distance);
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
