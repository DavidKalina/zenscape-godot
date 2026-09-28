shader_type spatial;
#include "res://shaders/world_play_bend.gdshaderinc"
#include "res://shaders/scene_palette.gdshaderinc"
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/conifer_wind.gdshaderinc"
#include "res://shaders/reference_autumn.gdshaderinc"
#include "res://shaders/reference_cloud_field.gdshaderinc"
#include "res://shaders/reference_alpenglow.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
#include "res://shaders/reference_inversion.gdshaderinc"
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
// Branchwork that does not sway still bends with its crown under the wind
// tool (zs_blow_bend), over the crown's `blow_shape` (bend from, height).
uniform bool blow_enabled = false;
uniform vec2 blow_shape = vec2(0.5, 6.0);
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
// Opt-in for thin foliage; trunks and other shared surfaces stay opaque.
#define ZS_FOLIAGE_TRANSMISSION
uniform float foliage_transmission : hint_range(0.0, 1.0) = 0.0;
uniform bool bird_wings = false;
uniform bool source_bird_flight = false;
varying float foliage_gust;
varying float inversion_transmit;
varying vec3 world_normal;
varying vec3 world_position;

void vertex() {
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
	if (blow_enabled && !sway_enabled && !conifer_sway) {
		float blow_shiver;
		VERTEX += zs_blow_bend(VERTEX, MODEL_MATRIX, blow_shape.x, blow_shape.y, blow_shiver);
	}
	if (sway_enabled && !conifer_sway) {
		vec2 root = MODEL_MATRIX[3].xz;
		float phase = dot(root, sway_phase.xy);
		float bend = smoothstep(sway_shape.x, sway_shape.y, VERTEX.y);
		float wave = sway_frequency.z * sin(zs_motion_time * sway_frequency.x + phase)
			+ sway_frequency.w * sin(zs_motion_time * sway_frequency.y + phase * sway_phase.z);
		float g = zs_breeze_field(root);
		float gust = 0.22 + 1.15 * g * g;
		// Wind is a world-space direction; asset yaw must not rotate the air.
		vec2 lean = zs_wind_direction * zs_wind_strength * zs_wind_strength * sway_shape.z * 0.55 * bend * gust;
		vec2 flap = zs_wind_direction * (wave * bend * sway_shape.z * zs_wind_strength * gust);
		float shiver = sin(zs_motion_time * 9.3 + phase * 4.7) * smoothstep(0.5, 0.85, g) * 0.35;
		vec2 side = vec2(-zs_wind_direction.y, zs_wind_direction.x)
			* ((sin(zs_motion_time * sway_frequency.y * 1.7 + phase * 2.1) + shiver) * bend * sway_shape.w * zs_wind_strength);
		vec2 motion = lean + flap + side;
		float instance_scale = length(MODEL_MATRIX[1].xyz);
		VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(motion.x, 0.0, motion.y) * instance_scale;
		float arm = max(VERTEX.y - sway_shape.x, 0.25);
		VERTEX.y -= min(dot(motion, motion) / (2.0 * arm), arm * 0.7);
		foliage_gust = clamp(gust * zs_wind_strength * bend * 0.5, 0.0, 1.0);
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
	play_deform(VERTEX, NORMAL);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 face_normal = world_normal;
	if (flat_faces) {
		face_normal = normalize(cross(dFdx(world_position), dFdy(world_position)));
		// Three.js flat DoubleSide surfaces shade the face toward the viewer.
		if (dot(face_normal, zs_camera_position - world_position) < 0.0) face_normal = -face_normal;
		NORMAL = normalize((VIEW_MATRIX * vec4(face_normal, 0.0)).xyz);
	}
	vec3 tint = scene_palette(base_color.rgb * COLOR.rgb);
	zs_autumn_paint(tint, world_position, zs_autumn);
	if (plant_growth) tint *= mix(1.0, 0.62, zs_foliage_wet) * (1.0 + 0.10 * foliage_gust);
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
	METALLIC = metalness_value;
	// The source scene has no environment map; sky reflection would lift and
	// desaturate every shaded facet.
	SPECULAR = 0.0;
	// Three.js RE_IndirectDiffuse_Physical applies BRDF_Lambert (albedo / PI)
	// to hemisphere irradiance. Emission bypasses Godot's BRDF, so include it here.
	vec3 hemisphere = mix(zs_hemi_ground, zs_hemi_sky, face_normal.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	EMISSION = emissive_color + tint * hemisphere * (1.0 - tactile);
	IRRADIANCE = vec4(hemisphere * tactile, 1.0);
	vec3 alpen_normal = normalize(cross(dFdx(world_position), dFdy(world_position)));
	if (dot(alpen_normal, face_normal) < 0.0) alpen_normal = -alpen_normal;
	EMISSION += zs_afterglow(world_position, alpen_normal, tint);
	inversion_transmit = zs_inversion_paint(world_position, EMISSION);
}

#include "res://shaders/reference_direct_light.gdshaderinc"
