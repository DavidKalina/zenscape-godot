#ifndef ZS_REFERENCE_GLOBALS
#define ZS_REFERENCE_GLOBALS
global uniform vec3 zs_local_ambient_velocity;
global uniform vec4 zs_local_gust_origin_0;
global uniform vec4 zs_local_gust_vector_0;
global uniform vec4 zs_local_gust_origin_1;
global uniform vec4 zs_local_gust_vector_1;
global uniform vec4 zs_local_gust_origin_2;
global uniform vec4 zs_local_gust_vector_2;
global uniform vec4 zs_local_gust_origin_3;
global uniform vec4 zs_local_gust_vector_3;
global uniform vec4 zs_local_gust_origin_4;
global uniform vec4 zs_local_gust_vector_4;
global uniform vec4 zs_local_gust_origin_5;
global uniform vec4 zs_local_gust_vector_5;
global uniform vec4 zs_local_gust_origin_6;
global uniform vec4 zs_local_gust_vector_6;
global uniform vec4 zs_local_gust_origin_7;
global uniform vec4 zs_local_gust_vector_7;
global uniform float zs_motion_time;
global uniform float zs_wind_strength;
global uniform vec2 zs_wind_direction;
global uniform vec2 zs_wind_offset;
global uniform float zs_gust_distance;
global uniform float zs_gust_speed;
global uniform vec4 zs_puff_0;
global uniform vec4 zs_puff_1;
global uniform vec4 zs_puff_2;
global uniform vec4 zs_puff_3;
global uniform vec4 zs_puff_4;
global uniform vec4 zs_puff_5;
global uniform vec4 zs_tread_0;
global uniform vec4 zs_tread_1;
global uniform vec4 zs_tread_2;
global uniform vec4 zs_tread_3;
global uniform vec4 zs_tread_4;
global uniform vec4 zs_tread_5;
global uniform vec4 zs_tread_6;
global uniform vec4 zs_tread_7;
global uniform vec4 zs_tree_tread_weights_0;
global uniform vec4 zs_tree_tread_weights_1;
global uniform vec4 zs_flash;
global uniform vec3 zs_alpen;
global uniform bool zs_surface_post;
global uniform vec2 zs_inversion;
global uniform vec3 zs_inversion_color;
global uniform vec3 zs_alpen_direction;
global uniform vec4 zs_clap;
global uniform vec3 zs_sky_down;
global uniform vec3 zs_sky_up;
global uniform vec3 zs_sky_glow;
global uniform vec3 zs_sun_direction;
// Look pass (scripts/look_pass.gd): contact occlusion, silhouette rim and shore strengths.
global uniform float zs_look_ao;
global uniform float zs_look_rim;
// Shoreline foam on water and wet-bank darkening on the ground beside it.
global uniform float zs_look_shore;
global uniform vec3 zs_moon_direction;
global uniform vec3 zs_moon_shadow_direction;
global uniform float zs_dusk_direction;
global uniform float zs_belt;
global uniform float zs_bow;
global uniform float zs_bow_grow;
global uniform vec2 zs_bow_shape;
global uniform vec4 zs_aurora;
global uniform float zs_night;
global uniform float zs_celestial_clear;
global uniform float zs_daylight;
global uniform float zs_exposure;
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
global uniform vec4 zs_cloud;
global uniform vec3 zs_cloud_drift;
global uniform vec4 zs_summit;
global uniform float zs_condensation;
global uniform vec3 zs_cloud_sun;
global uniform vec3 zs_cloud_sky;
global uniform vec3 zs_camera_position;
global uniform vec3 zs_cloud_direction;
global uniform float zs_haze;
global uniform vec2 zs_growth;
global uniform float zs_water_growth;
// Chunk atlas (scripts/chunk_atlas_view.gd): a frozen neighbour chunk is drawn
// fully grown and settled, whatever the live chunk's growth, stroke waves and
// emergence clock are doing. Read growth through the *_now() helpers below.
uniform bool zs_atlas_frozen = false;
vec2 zs_growth_now() { return zs_atlas_frozen ? vec2(1.0) : zs_growth; }
float zs_water_growth_now() { return zs_atlas_frozen ? 1.0 : zs_water_growth; }
global uniform float zs_ice;
global uniform float zs_snow;
global uniform float zs_autumn;
// Total burning intensity, 0..1, from FireField.total_intensity().
global uniform float zs_fire;
global uniform float zs_ground_wet;
global uniform float zs_foliage_wet;
global uniform float zs_flow_time;
// Stroke feedback (scripts/stroke_feedback.gd). Reveal: xz centre, radius,
// strength of the hole a land stroke opens in the fog. Growth waves: xz
// centre, radius (0 = idle), progress: -1..0 shrinks away, 0..1 grows back in.
global uniform vec4 zs_reveal;
global uniform vec4 zs_growth_wave_0;
global uniform vec4 zs_growth_wave_1;
global uniform vec4 zs_growth_wave_2;
global uniform vec4 zs_growth_wave_3;
global uniform vec4 zs_growth_wave_4;
global uniform vec4 zs_growth_wave_5;

// 1 away from recent strokes. Inside them, the furthest-along covering wave's
// grow-in, so a plant pops once per pass however many waves overlap it; a
// plant's pop reads min(zs_growth.y, this).
float zs_growth_wave_at(vec2 p) {
	if (zs_atlas_frozen) return 1.0;
	vec4 waves[6] = vec4[6](zs_growth_wave_0, zs_growth_wave_1, zs_growth_wave_2, zs_growth_wave_3, zs_growth_wave_4, zs_growth_wave_5);
	float grown = -1.0;
	for (int i = 0; i < 6; i++) {
		vec4 w = waves[i];
		if (w.z <= 0.0) continue;
		float reach = 1.0 - smoothstep(w.z * 0.65, w.z, distance(p, w.xy));
		if (reach > 0.0) grown = max(grown, mix(1.0, abs(w.w), reach));
	}
	return grown < 0.0 ? 1.0 : grown;
}

// Emergence (scripts/emergence.gd): the clock its births are stamped on.
global uniform float zs_emergence_time;
// Far past every birth: a frozen chunk's ponds and streams stand full.
float zs_emergence_now() { return zs_atlas_frozen ? 1.0e7 : zs_emergence_time; }

// Grow-in 0..1 of one emerged instance born at `born` that rises over
// `seconds`. 1 with no birth (seconds <= 0), and for a birth from another
// clock (far in the future), so a stale stamp never hides a plant.
float zs_birth_growth(float born, float seconds) {
	if (seconds <= 0.0 || zs_atlas_frozen) return 1.0;
	float age = zs_emergence_time - born;
	if (age < -20.0) return 1.0;
	return clamp(age / seconds, 0.0, 1.0);
}

// Fog kept at p: 1 outside the stroke reveal, down to 1 - strength inside.
float zs_reveal_keep(vec2 p) {
	if (zs_reveal.w <= 0.0) return 1.0;
	return 1.0 - zs_reveal.w * (1.0 - smoothstep(zs_reveal.z * 0.45, zs_reveal.z, distance(p, zs_reveal.xy)));
}

// Fog pour (scripts/world_rumble.gd). zs_pour: amount, lid depth above the
// plate floor (m), front 0..1, flow clock. zs_pour_area: xz centre and radius
// of a local pour; radius 0 pours over the whole plate from upwind.
global uniform vec4 zs_pour;
global uniform vec4 zs_pour_area;

// Pour density at p over `ground`, on a plate floored at `floor_y`. `churn` is
// a 0..1 noise the caller advects with zs_pour.w. The fog fills the low ground
// up to a churning lid, so it follows the drawn terrain as it forms and peaks
// rise out of it; a thin skin clings to the slopes above.
float zs_pour_at(vec3 p, float ground, float floor_y, float churn) {
	if (zs_pour.x <= 0.0 || ground < -100.0) return 0.0;
	float wave = churn - 0.5;
	float reach;
	if (zs_pour_area.z > 0.0) {
		float d = distance(p.xz, zs_pour_area.xy) / zs_pour_area.z;
		reach = (1.0 - smoothstep(zs_pour.z - 0.3, zs_pour.z + 0.05, d + wave * 0.35)) * (1.0 - smoothstep(0.8, 1.0, d));
	} else {
		float along = dot(p.xz, zs_wind_direction) / 14.0;
		float at = mix(-1.5, 1.5, zs_pour.z);
		reach = 1.0 - smoothstep(at - 0.4, at + 0.05, along + wave * 0.5);
	}
	if (reach <= 0.0) return 0.0;
	float over = p.y - ground;
	float lid = floor_y + zs_pour.y + wave * 0.9;
	float body = 1.0 - smoothstep(lid - 0.6, lid + 0.5, p.y);
	float skin = 0.35 * exp(-max(over, 0.0) * 2.5) * smoothstep(0.0, 0.6, zs_pour.y);
	return zs_pour.x * reach * max(body, skin) * smoothstep(-0.3, 0.2, over) * (0.55 + 0.9 * churn);
}
#endif

global uniform vec3 zs_key_direction;
global uniform vec3 zs_key_irradiance;
global uniform vec3 zs_rim_direction;
global uniform vec3 zs_rim_irradiance;

global uniform vec4 zs_meteor_head;
global uniform vec3 zs_meteor_tail;
