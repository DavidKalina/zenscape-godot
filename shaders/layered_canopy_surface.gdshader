shader_type spatial;
#include "res://shaders/world_play_bend.gdshaderinc"
#include "res://shaders/scene_palette.gdshaderinc"
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/conifer_wind.gdshaderinc"
#include "res://shaders/reference_autumn.gdshaderinc"
#include "res://shaders/reference_season.gdshaderinc"
#include "res://shaders/reference_char.gdshaderinc"
#include "res://shaders/reference_cloud_field.gdshaderinc"
#include "res://shaders/reference_alpenglow.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
#include "res://shaders/reference_inversion.gdshaderinc"
#include "res://shaders/layered_clump_motion.gdshaderinc"
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;

// Throwaway pond study: broad material cues, no fine normal noise.
uniform float tactile = 0.0;
uniform vec3 pond_center = vec3(1.0, -0.25, 0.0);
uniform bool brush_visible = false;
uniform vec2 brush_center = vec2(0.0);
uniform float brush_radius = 1.0;
uniform vec4 brush_color : source_color = vec4(1.0, 0.91, 0.61, 1.0);

uniform vec4 base_color : source_color = vec4(1.0);
uniform vec3 emissive_color = vec3(0.0);
uniform float roughness_value = 1.0;
uniform float metalness_value = 0.0;
uniform bool sway_enabled = false;
uniform bool conifer_sway = false;
// Opt-in many-pieces motion (layered_clump_motion): each lump, baked with its
// pivot and phase in CUSTOM1, swings whole instead of the crown moving as one
// block with a per-vertex jiggle. 0..2 scales how far the lumps swing.
uniform bool clump_sway = false;
uniform float clump_gain : hint_range(0.0, 2.0) = 1.0;
uniform vec4 sway_shape = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 sway_frequency = vec4(1.0, 2.0, 1.0, 0.5);
uniform vec3 sway_phase = vec3(0.9, 0.7, 1.3);
uniform bool flat_faces = false;
uniform bool wet_ground = false;
uniform float wet_droop = 0.0;
uniform bool terrain_growth = false;
uniform bool plant_growth = false;
// Emerged births, written per instance by GardenView into INSTANCE_CUSTOM.ba.
uniform bool instance_birth_enabled = false;
// An emerged tree's stand autumn (zs_instance_autumn), -1 for everything else.
varying flat float stand_autumn;
// Opt-in for thin foliage; trunks and other shared surfaces stay opaque.
#define ZS_FOLIAGE_TRANSMISSION
uniform float foliage_transmission : hint_range(0.0, 1.0) = 0.0;
uniform bool bird_wings = false;
uniform bool source_bird_flight = false;
varying float foliage_gust;
varying float inversion_transmit;
varying vec3 world_normal;
varying vec3 world_position;
varying vec3 crown_position;
// Seasons, as on reference_surface: (turn, leaf fall, blossom, die-back).
uniform vec4 leaf_season = vec4(1.0, 0.0, 0.0, 0.0);
varying vec2 plant_root;
varying float leaf_thinness;
// Fire, written per instance by GardenView.set_object_fire: (char, burn).
uniform bool instance_fire_enabled = false;
uniform vec2 object_fire = vec2(0.0);
varying vec2 char_state;
varying flat float char_clump;
varying float char_seed;

void vertex() {
	crown_position = VERTEX;
	plant_root = MODEL_MATRIX[3].xz;
	char_state = instance_fire_enabled ? INSTANCE_CUSTOM.rg : object_fire;
	char_clump = zs_char_clump(VERTEX);
	char_seed = zs_char_seed(MODEL_MATRIX[3].xz);
	// The skeleton phase runs through the canopy's own thinness channel rather
	// than an alpha scissor: the tiers keep their silhouette and go sheer.
	leaf_thinness = mix(COLOR.a, 1.0, smoothstep(0.5, 1.0, char_state.x));
	foliage_gust = 0.0;
	if (terrain_growth) {
		float grown = max(smoothstep(UV.x, UV.x + 0.3, zs_growth_now().x), UV.y);
		VERTEX.y = mix(0.6, UV2.y, grown);
		vec3 living = mix(CUSTOM0.rgb, COLOR.rgb, smoothstep(0.6, 1.0, grown));
		vec3 dirt = vec3(0.1441, 0.0976, 0.0630) * (0.88 + 0.24 * UV2.x);
		COLOR.rgb = mix(dirt, living, smoothstep(0.02, 0.42, grown));
	}
	if (bird_wings && source_bird_flight) {
		float span = abs(VERTEX.x);
		float lever = smoothstep(0.07, 1.12, span);
		float angle = sin(INSTANCE_CUSTOM.g) * INSTANCE_CUSTOM.r * lever * lever;
		float ca = cos(angle), sa = sin(angle);
		float side = sign(VERTEX.x);
		vec2 rotated = vec2(span * ca - VERTEX.y * sa, span * sa + VERTEX.y * ca);
		VERTEX.x = rotated.x * side;
		VERTEX.y = rotated.y;
	} else if (bird_wings) {
		float wing = smoothstep(0.09, 0.65, abs(VERTEX.x));
		float phase = float(INSTANCE_ID) * 1.7;
		float flap = smoothstep(0.45, 0.85, sin(zs_motion_time * 0.65 + phase));
		float angle = sin(zs_motion_time * 7.5 + phase) * 0.40 * flap * wing;
		VERTEX.y += abs(VERTEX.x) * sin(angle);
		VERTEX.x *= cos(angle);
	}
	if (conifer_sway) {
		VERTEX += zs_conifer_offset(VERTEX, MODEL_MATRIX);
	}
	if (sway_enabled && !conifer_sway && clump_sway) {
		vec3 pivot = CUSTOM1.xyz;
		float cphase = CUSTOM1.w;
		mat3 inv = inverse(mat3(MODEL_MATRIX));
		float scale = length(MODEL_MATRIX[1].xyz);
		float air_now = zs_breeze_air();
		float t = zs_motion_time;
		vec3 pivot_world = (MODEL_MATRIX * vec4(pivot, 1.0)).xyz;
		float span = max(sway_shape.y - sway_shape.x, 0.05);
		float k = clamp(max(pivot.y - sway_shape.x, 0.0) / span, 0.0, 1.5);
		// The air at this lump: the breeze's lean there (the tip a beat behind
		// the root, as for the wood), and the wind tool's front, which reaches
		// each lump at its own moment so a gust rolls through the crown.
		float bow;
		float lean = zs_breeze_lean_at(pivot_world.xz, ZS_BREEZE_LAG * span * scale * min(k, 1.0), 0.0, bow);
		float shiver;
		vec2 blow = zs_blow_at(pivot_world.xz, cphase, shiver);
		float blow_size = length(blow);
		vec2 wd = zs_wind_direction;
		float along = dot(pivot_world.xz, wd);
		float across = dot(pivot_world.xz, vec2(-wd.y, wd.x));
		// A ripple of air a couple of metres long running downwind through the crown.
		float ripple = 0.5 + 0.5 * sin(along * 2.2 - t * (1.6 + 1.2 * air_now) + zs_noise(vec2(across * 0.7, along * 0.25)) * 5.0);
		// Translate the lump whole: the trunk's lean read at its pivot.
		float breeze_gust;
		vec2 motion = zs_breeze_offset_lean(pivot, MODEL_MATRIX, sway_shape.x, sway_shape.y, zs_breeze_flex(sway_shape.z), 0.0, lean, breeze_gust);
		float arm = max(pivot.y - sway_shape.x, 0.05) * scale;
		vec3 shift = inv * vec3(motion.x, 0.0, motion.y);
		shift.y -= min(dot(motion, motion) / (2.0 * arm), arm * 0.7) / max(scale, 0.001);
		shift.y -= zs_foliage_wet * smoothstep(sway_shape.x, sway_shape.y, pivot.y) * wet_droop;
		float bend = smoothstep(sway_shape.x, sway_shape.y, pivot.y);
		foliage_gust = clamp(breeze_gust * bend * 0.5, 0.0, 1.0);
		vec3 air = zs_local_wind((MODEL_MATRIX * vec4(pivot, 1.0)).xyz);
		float speed = length(air);
		if (speed > 0.001) {
			float response = speed / (speed + 10.0);
			float flutter = 0.90 + 0.10 * sin(t * 12.0 + cphase);
			shift += inv * (air / speed * response * max(sway_shape.z, sway_shape.w) * 3.0 * bend * flutter);
			foliage_gust = max(foliage_gust, response * bend);
		}
		float blow_shiver;
		shift += zs_blow_bend(pivot, MODEL_MATRIX, sway_shape.x, sway_shape.y, blow_shiver);
		shift += zs_bough_sway(pivot, MODEL_MATRIX, air_now);
		foliage_gust = max(foliage_gust, max(blow_shiver, shiver) * bend);
		// Swing the lump about its pivot: leaning with the air, lagging it
		// and settling, each lump out of step with its neighbours.
		vec2 push = wd * (lean * 1.4 + 0.1 * air_now * ripple) + blow * 1.1;
		float push_size = length(push);
		vec2 push_dir = push_size > 0.0001 ? push / push_size : wd;
		vec3 push_local = inv * vec3(push_dir.x, 0.0, push_dir.y);
		push_local = normalize(vec3(push_local.x, 0.0, push_local.z) + vec3(0.00001, 0.0, 0.0));
		vec3 nod_axis = normalize(cross(vec3(0.0, 1.0, 0.0), push_local));
		float quick = sin(t * (1.3 + 0.9 * fract(cphase * 0.37)) + cphase * 7.0);
		float nod = clump_gain * (0.05 * air_now * (0.4 + ripple) + 0.30 * push_size
			+ (0.04 * air_now * (0.4 + clamp(lean / 0.5, 0.0, 1.0)) + 0.10 * shiver) * quick);
		float twist = clump_gain * ((0.05 + 0.18 * push_size) * sin(t * (0.8 + 0.5 * fract(cphase * 0.61)) + cphase * 3.1 + ripple * 2.0) * (0.5 + 0.5 * min(air_now, 1.5))
			+ 0.08 * shiver * sin(t * 4.0 + cphase * 5.0));
		nod = clamp(nod, -0.3, 0.45);
		twist = clamp(twist, -0.3, 0.3);
		VERTEX = pivot + zs_clump_rot(zs_clump_rot(VERTEX - pivot, nod_axis, nod), vec3(0.0, 1.0, 0.0), twist);
		NORMAL = zs_clump_rot(zs_clump_rot(NORMAL, nod_axis, nod), vec3(0.0, 1.0, 0.0), twist);
		VERTEX += shift;
	} else if (sway_enabled && !conifer_sway) {
		vec2 root = MODEL_MATRIX[3].xz;
		float phase = dot(root, sway_phase.xy);
		float bend = smoothstep(sway_shape.x, sway_shape.y, VERTEX.y);
		// The ambient breeze (reference_wind, docs/scenic/breeze.md), as the
		// reference plants have it; the branchwork takes the same bend.
		float breeze_gust;
		float breeze_bow;
		vec2 motion = zs_breeze_offset(VERTEX, MODEL_MATRIX, sway_shape.x, sway_shape.y,
			zs_breeze_flex(sway_shape.z), zs_breeze_flutter(sway_shape.z), breeze_gust, breeze_bow);
		float instance_scale = length(MODEL_MATRIX[1].xyz);
		VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(motion.x, 0.0, motion.y);
		float arm = max(VERTEX.y - sway_shape.x, 0.05) * instance_scale;
		VERTEX.y -= min(dot(motion, motion) / (2.0 * arm), arm * 0.7) / max(instance_scale, 0.001);
		foliage_gust = clamp(breeze_gust * bend * 0.5, 0.0, 1.0);
		VERTEX.y -= zs_foliage_wet * bend * wet_droop;
		// Local gusts have a true world direction, even for rotated/scaled assets.
		// Anchored roots stay fixed; flexible crowns bend with bounded amplitude.
		vec3 air = zs_local_wind((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz);
		float speed = length(air);
		if (speed > 0.001) {
			float response = speed / (speed + 10.0);
			float flutter = 0.90 + 0.10 * sin(zs_motion_time * 12.0 + phase);
			float flexibility = max(sway_shape.z, sway_shape.w);
			vec3 displacement = air / speed * response * flexibility * 3.0 * bend * flutter;
			VERTEX += inverse(mat3(MODEL_MATRIX)) * displacement;
			foliage_gust = max(foliage_gust, response * bend);
		}
		// The wind tool (scripts/wind_gust.gd): its gusts, bursts and the
		// blowing hand bend the plant its own way, with spring-back and
		// sway after (zs_blow_bend).
		float blow_shiver;
		VERTEX += zs_blow_bend(VERTEX, MODEL_MATRIX, sway_shape.x, sway_shape.y, blow_shiver);
		foliage_gust = max(foliage_gust, blow_shiver * bend);

	}
	// An emerged instance also pops in at its own birth, INSTANCE_CUSTOM.ba =
	// (born, seconds, with the stand's autumn packed above); instances without
	// one stay at 1 (scripts/emergence.gd).
	stand_autumn = instance_birth_enabled && !bird_wings ? zs_instance_autumn(INSTANCE_CUSTOM.a) : -1.0;
	float birth = instance_birth_enabled && !bird_wings ? zs_birth_growth(INSTANCE_CUSTOM.b, zs_instance_rise(INSTANCE_CUSTOM.a)) : 1.0;
	if (plant_growth || birth < 1.0) {
		float t = birth;
		if (plant_growth) {
			float seed = fract(sin(dot(MODEL_MATRIX[3].xz, vec2(12.9898, 78.233))) * 43758.5453);
			t = min(t, clamp((min(zs_growth_now().y, zs_growth_wave_at(MODEL_MATRIX[3].xz)) - seed * 0.72) / 0.28, 0.0, 1.0));
		}
		float b = t - 1.0;
		VERTEX *= 1.0 + 2.70158 * b * b * b + 1.70158 * b * b;
	}
	zs_char_curl(VERTEX, char_state.x, char_clump, palette_role != 3 && palette_role != 4);
	play_deform(VERTEX, NORMAL);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	if (leaf_season.y > 0.0 && zs_leaf_fallen(crown_position, plant_root, leaf_season.y)) discard;
	vec3 face_normal = world_normal;
	if (flat_faces) {
		face_normal = normalize(cross(dFdx(world_position), dFdy(world_position)));
		// Three.js flat DoubleSide surfaces shade the face toward the viewer.
		if (dot(face_normal, zs_camera_position - world_position) < 0.0) face_normal = -face_normal;
		NORMAL = normalize((VIEW_MATRIX * vec4(face_normal, 0.0)).xyz);
	}
	vec3 tint = scene_palette(base_color.rgb * COLOR.rgb);
	if (stand_autumn >= 0.0) zs_autumn_stand_paint(tint, plant_root, zs_autumn * leaf_season.x, stand_autumn);
	else zs_autumn_paint(tint, world_position, zs_autumn * leaf_season.x);
	zs_season_leaves(tint, crown_position, plant_root, face_normal, leaf_season.x, leaf_season.z);
	if (plant_growth) tint *= mix(1.0, 0.62, zs_foliage_wet) * (1.0 + 0.10 * foliage_gust);
	// Order is palette -> autumn -> season -> char -> wet -> snow.
	float char_scorch = 0.0;
	vec3 char_ember = vec3(0.0);
	if (char_state.x > 0.004 || char_state.y > 0.004) {
		zs_char_paint(tint, char_scorch, char_ember, world_position, face_normal, char_state.x, char_state.y, char_seed, TIME);
	}
	float surface_wet = 0.0;
	float mineral = 0.0;
	if (wet_ground && zs_ground_wet > 0.001) {
		float exposure = smoothstep(-0.3, 0.0, face_normal.y) * mix(0.6, 1.0, smoothstep(0.0, 0.6, face_normal.y));
		float patch = zs_noise(world_position.xz * 0.65 + world_position.y * 0.17);
		surface_wet = smoothstep(patch * 0.28, 0.72 + patch * 0.28, zs_ground_wet) * exposure;
		float green = max(0.0, tint.g - max(tint.r, tint.b));
		mineral = 1.0 - smoothstep(0.015, 0.10, green);
		surface_wet *= 1.0 - smoothstep(0.55, 0.8, min(tint.r, min(tint.g, tint.b)));
		tint *= 1.0 - surface_wet * mix(0.20, 0.40, mineral);
	}
	if (!bird_wings && zs_snow > 0.004) {
		float noise = zs_noise(world_position.xz * 0.85);
		float line = mix(zs_summit.y + 2.0, 0.15 - 2.5, pow(zs_snow, 0.7));
		float cover = smoothstep(line - 0.6, line + 2.4, world_position.y + (noise - 0.5) * 3.0)
			* smoothstep(0.35, 0.72, face_normal.y) * smoothstep(0.0, 0.1, zs_snow);
		tint = mix(tint, vec3(0.88, 0.91, 0.95) * (0.90 + 0.18 * noise), cover);
		surface_wet *= 1.0 - cover;
	}
	float cloud_shade = cloudShadeAt(vec3(world_position.x, 0.6, world_position.z), zs_cloud_direction);
	tint *= mix(1.0, 0.42 + 0.58 * cloud_shade, min(1.0, zs_cloud.x * 1.35) * 0.85);
	if (brush_visible) {
		float distance_to_brush = length(world_position.xz - brush_center);
		float aa = max(fwidth(distance_to_brush), 0.025);
		float ring = 1.0 - smoothstep(0.025, 0.025 + aa, abs(distance_to_brush - brush_radius));
		float fill = (1.0 - smoothstep(0.0, brush_radius, distance_to_brush)) * 0.13;
		tint = mix(tint, brush_color.rgb, max(ring * 0.9, fill));
	}
	float pond_distance = length((world_position.xz - pond_center.xz) / vec2(1.15, 1.0));
	float bank = (1.0 - smoothstep(3.2, 5.8, pond_distance)) * (1.0 - smoothstep(pond_center.y + 0.08, pond_center.y + 0.7, world_position.y));
	float broad_noise = zs_noise(world_position.xz * 0.7 + world_position.y * 0.21);
	float study_wet = 0.0;
	if (palette_role == 1 || palette_role == 3) {
		study_wet = bank * tactile;
		tint *= 1.0 - 0.32 * study_wet;
		tint *= mix(1.0, 0.94 + 0.12 * broad_noise, tactile);
	}
	if (palette_role == 3) {
		float moss = smoothstep(0.35, 0.8, face_normal.y) * smoothstep(0.43, 0.68, broad_noise);
		moss *= 1.0 - smoothstep(4.0, 7.0, pond_distance);
		tint = mix(tint, tint * vec3(0.66, 0.91, 0.48), moss * tactile * 0.65);
	}
	if (palette_role == 2) {
		float lower_crown = 1.0 - smoothstep(1.4, 5.0, world_position.y);
		tint *= mix(vec3(1.0), vec3(0.77, 0.87, 0.89), tactile * lower_crown * 0.55);
	}
	ALBEDO = tint;
	ROUGHNESS = mix(roughness_value, mix(0.58, 0.20, mineral), surface_wet);
	if (palette_role == 3) ROUGHNESS = mix(ROUGHNESS, mix(0.78, 0.29, bank), tactile);
	if (palette_role == 1) ROUGHNESS = mix(ROUGHNESS, mix(0.98, 0.48, bank), tactile);
	if (palette_role == 2) ROUGHNESS = mix(ROUGHNESS, 0.82, tactile);
	ROUGHNESS = mix(ROUGHNESS, 1.0, char_scorch);
	METALLIC = metalness_value;
	// The source scene has no environment map; sky reflection would lift and
	// desaturate every shaded facet.
	SPECULAR = 0.0;
	// Three.js RE_IndirectDiffuse_Physical applies BRDF_Lambert (albedo / PI)
	// to hemisphere irradiance. Emission bypasses Godot's BRDF, so include it here.
	vec3 hemisphere = mix(zs_hemi_ground, zs_hemi_sky, face_normal.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	// Broad crown depth only: avoid noisy per-leaf texture and black undersides.
	float crown_exposure = smoothstep(0.2, 1.0, length((crown_position - vec3(0.0,4.2,0.0)) / vec3(2.8,1.7,2.5)));
	hemisphere *= mix(vec3(0.66,0.80,0.92),vec3(1.0),crown_exposure);
	hemisphere += zs_hemi_sky * zs_hemi_energy / PI * 0.16 * (1.0 - smoothstep(-0.3,0.4,face_normal.y));
	EMISSION = emissive_color + tint * hemisphere * (1.0 - tactile);
	IRRADIANCE = vec4(hemisphere * tactile, 1.0);
	vec3 alpen_normal = normalize(cross(dFdx(world_position), dFdy(world_position)));
	if (dot(alpen_normal, face_normal) < 0.0) alpen_normal = -alpen_normal;
	EMISSION += zs_afterglow(world_position, alpen_normal, tint) + char_ember;
	inversion_transmit = zs_inversion_paint(world_position, EMISSION);
}

#include "res://shaders/layered_canopy_light.gdshaderinc"
