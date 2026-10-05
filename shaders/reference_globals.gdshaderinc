#ifndef ZS_REFERENCE_GLOBALS
#define ZS_REFERENCE_GLOBALS
// The plate's reach (scripts/plate.gd, published by Plate.publish_shader_globals):
// zs_plate_half the land's half-extent, zs_map_half the half-extent of the
// ground, stream and shade maps (the plate and a margin), both in metres. The
// maps hold 4 texels a metre (zs_water_map, ground_map, stream_map) and 2
// (zs_ground_shade), so their sizes follow from zs_map_half.
global uniform float zs_plate_half;
global uniform float zs_map_half;
#define ZS_MAP_TEXELS int(zs_map_half * 8.0)
#define ZS_SHADE_TEXELS int(zs_map_half * 4.0)
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
// The ambient breeze plants lean in (studies/atmosphere.gd `breeze`,
// docs/scenic/breeze.md): the air's strength lifted to a gentle floor and
// breathing slowly. 0 is a dead calm; a light day is about 0.53.
global uniform float zs_breeze;
// The breeze's gust fronts (studies/gust_fronts.gd, docs/scenic/gust-fronts.md):
// per slot, a = origin x, z and way x, z; b = age s, speed m/s, peak lean,
// half width m. An empty slot is all zeros.
global uniform vec4 zs_front_0_a;
global uniform vec4 zs_front_0_b;
global uniform vec4 zs_front_1_a;
global uniform vec4 zs_front_1_b;
// Breeze ribbons' heads (scripts/breeze_ribbons.gd `publish`): x, z and
// their way scaled by how hard they bow plants (0 a free slot); lift_a/b
// their heights above the ground, slots 0-3 and 4-7.
global uniform vec4 zs_ribbon_0;
global uniform vec4 zs_ribbon_1;
global uniform vec4 zs_ribbon_2;
global uniform vec4 zs_ribbon_3;
global uniform vec4 zs_ribbon_4;
global uniform vec4 zs_ribbon_5;
global uniform vec4 zs_ribbon_6;
global uniform vec4 zs_ribbon_7;
global uniform vec4 zs_ribbon_lift_a;
global uniform vec4 zs_ribbon_lift_b;
// Shifts the world-scale grass noise per world seed (scripts/dense_grass.gd),
// declared here so any plant can roll with the meadow's waves (grass_look).
global uniform vec2 zs_grass_offset;
#define ZS_GRASS_OFFSET_DECLARED
global uniform vec4 zs_puff_0;
global uniform vec4 zs_puff_1;
global uniform vec4 zs_puff_2;
global uniform vec4 zs_puff_3;
global uniform vec4 zs_puff_4;
global uniform vec4 zs_puff_5;
// Parcel headings (scripts/wind_gust.gd): parcel 2i in xy, 2i+1 in zw; zero
// rides zs_wind_direction.
global uniform vec4 zs_puff_heading_0;
global uniform vec4 zs_puff_heading_1;
global uniform vec4 zs_puff_heading_2;
// The wind tool's own air for foliage (scripts/wind_gust.gd `_publish_blow`,
// read by zs_blow_at). Lanes N=0..3: a (origin x, z, heading x, z), b (s since
// release, run s, head's start m, its travel m), c (lean at the head, half
// width m, reach m, 0). Burst: a (centre x, z, s since release, lean), b (run,
// start, travel, reach). The blowing hand: a (origin x, z, heading x, z), b
// (reach or swept m, strength, half width, mode 0 none, 1 holding, 2 dragging).
global uniform vec4 zs_blow_0_a;
global uniform vec4 zs_blow_0_b;
global uniform vec4 zs_blow_0_c;
global uniform vec4 zs_blow_1_a;
global uniform vec4 zs_blow_1_b;
global uniform vec4 zs_blow_1_c;
global uniform vec4 zs_blow_2_a;
global uniform vec4 zs_blow_2_b;
global uniform vec4 zs_blow_2_c;
global uniform vec4 zs_blow_3_a;
global uniform vec4 zs_blow_3_b;
global uniform vec4 zs_blow_3_c;
global uniform vec4 zs_burst_a;
global uniform vec4 zs_burst_b;
global uniform vec4 zs_aim_a;
global uniform vec4 zs_aim_b;
// The Feather's live wake (scripts/wind_gust.gd `_publish_wake`, read by
// zs_wake_at): its path oldest first, zs_wake_N (x, z, when the feather passed
// on zs_wake_a.x's clock, lean there; negative where a stroke starts), a (now,
// points, half width m, 0), b (the feather's heading x, z, speed m/s, 0), c
// (the box its air reaches: min x, z, max x, z).
global uniform vec4 zs_wake_a;
global uniform vec4 zs_wake_b;
global uniform vec4 zs_wake_c;
global uniform vec4 zs_wake_0;
global uniform vec4 zs_wake_1;
global uniform vec4 zs_wake_2;
global uniform vec4 zs_wake_3;
global uniform vec4 zs_wake_4;
global uniform vec4 zs_wake_5;
global uniform vec4 zs_wake_6;
global uniform vec4 zs_wake_7;
global uniform vec4 zs_wake_8;
global uniform vec4 zs_wake_9;
global uniform vec4 zs_wake_10;
global uniform vec4 zs_wake_11;
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
// Plants trailing the block's dip (scripts/pull_feel.gd): the part of a
// plant above its bend stretches up by this share (shrinks when negative),
// most at the tip. Zero at rest.
global uniform float zs_heave;
global uniform vec3 zs_sky_down;
global uniform vec3 zs_sky_up;
global uniform vec3 zs_sky_glow;
global uniform vec3 zs_sun_direction;
// The room's turn about the vertical (radians, studies/celestial.gd
// room_yaw): the sky's stars and horizon are drawn in the room, which keeps
// its bearing to the camera while the diorama turns under it.
global uniform float zs_room_yaw;
// The glide's view of the Opal cloud sea (scripts/sky_flight.gd): xy how far
// the eye has flown since stepping off, in depths of the sea below it, in
// the room's frame; z the eye's height over the sea as a share of its
// height at the step off (1 at rest); w how far the sea parts beneath it
// (0 closed, 1 wide open).
global uniform vec4 zs_sea_flight;
// The glide's aerial perspective (scripts/sky_haze.gd): x how much of it is
// on (0 in the build view), y the reach (m) its gentle curve is scaled by,
// z the distance (m) where it is whole, w the cloud sea's height (m), where
// the air lies thickest.
global uniform vec4 zs_glide_haze;
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
global uniform float zs_bow_double;
global uniform vec4 zs_aurora;
// A moonbow's strength (studies/celestial.gd moon_bow), drawn about the antilunar point.
global uniform float zs_moonbow;
global uniform float zs_night;
// The night sky's style (scripts/look_pass.gd NIGHT_STYLES; shaders/night_sky.gdshaderinc):
// 0 Nocturne, 1 Opal, 2 Storybook, 3 Mystic.
global uniform int zs_night_style;
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

// An emerged tree's INSTANCE_CUSTOM.a packs its stand's autumn above its rise
// seconds, in whole ZS_RISE_SPANs of 1 + 15 * autumn (GardenView._custom), so
// a plain rise, or 0, reads as before. Rises stay under the span.
#define ZS_RISE_SPAN 4.0
float zs_instance_rise(float packed) { return mod(packed, ZS_RISE_SPAN); }
// The stand's autumn 0..1, or -1 for an instance with none.
float zs_instance_autumn(float packed) {
	float code = floor(packed / ZS_RISE_SPAN + 1e-4);
	return code >= 1.0 ? (code - 1.0) / 15.0 : -1.0;
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
