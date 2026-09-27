shader_type spatial;
#include "res://shaders/world_play_bend.gdshaderinc"
#include "res://shaders/scene_palette.gdshaderinc"
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/grass_look.gdshaderinc"
#include "res://shaders/conifer_wind.gdshaderinc"
#include "res://shaders/foliage_tread.gdshaderinc"
#include "res://shaders/reference_autumn.gdshaderinc"
#include "res://shaders/reference_season.gdshaderinc"
#include "res://shaders/reference_char.gdshaderinc"
#include "res://shaders/reference_cloud_field.gdshaderinc"
#include "res://shaders/reference_alpenglow.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
#include "res://shaders/reference_inversion.gdshaderinc"
#include "res://shaders/cave_cutaway.gdshaderinc"
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform bool brush_visible = false;
uniform vec2 brush_center = vec2(0.0);
uniform float brush_radius = 1.0;
uniform vec4 brush_color : source_color = vec4(1.0, 0.91, 0.61, 1.0);

uniform vec4 base_color : source_color = vec4(1.0);
uniform vec3 emissive_color = vec3(0.0);
uniform float roughness_value = 1.0;
// Per-resident moisture; independent of ground wetness and weather changes.
uniform float coat_wetness : hint_range(0.0, 1.0) = 0.0;
uniform float metalness_value = 0.0;
uniform bool sway_enabled = false;
uniform bool conifer_sway = false;
uniform bool tree_tread = false;
uniform float tree_tread_height = 4.26;
uniform vec4 sway_shape = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 sway_frequency = vec4(1.0, 2.0, 1.0, 0.5);
uniform vec3 sway_phase = vec3(0.9, 0.7, 1.3);
uniform bool flat_faces = false;
uniform bool wet_ground = false;
uniform float wet_droop = 0.0;
uniform bool terrain_growth = false;
uniform bool plant_growth = false;
// Opt-in for the single-chunk cozy regeneration prototype.
uniform bool cozy_prop_growth = false;
// Opt-in for thin foliage; trunks and other shared surfaces stay opaque.
#define ZS_FOLIAGE_TRANSMISSION
uniform float foliage_transmission : hint_range(0.0, 1.0) = 0.0;
uniform bool bird_wings = false;
// The pond fish's tail beat (scripts/land_life.gd, after the source's
// fish.js): a travelling wave down the body, rigid from the nose to x and
// swinging fully by y (model z), z metres across at the tail, w radians of
// wave per metre of body.
uniform bool fish_swim = false;
uniform vec4 fish_wave = vec4(0.07, -0.21, 0.042, 11.0);
// The painterly grass tuft (scripts/grass_tuft_mesh.gd): UV.y runs root to
// tip. Mass normals, the rolling wind wave, straw patches and tip glow from
// shaders/grass_look.gdshaderinc, as the dense meadow has them. How round a
// tuft lights, how much of it goes to straw, and how its tips glow.
uniform bool grass_blades = false;
uniform float grass_round = 0.55;
uniform float grass_dry = 0.25;
uniform float grass_tip_glow = 0.55;
// The tuft mesh's own root and tip colours (GrassTuft.dress, linear): the
// vertex colour over these keeps each blade's jitter and any instance tint,
// while the colour itself is the family's living green (grass_look).
uniform vec3 grass_source_root = vec3(0.0396, 0.1329, 0.0423);
uniform vec3 grass_source_tip = vec3(0.2917, 0.5271, 0.1145);
// How far the family's grass leans to living green, and each tuft's
// brightness jitter either way.
uniform float grass_living = 0.4;
uniform float grass_variation = 0.12;
// How much of the contact darkening the tufts keep; their root shade
// already darkens the base.
uniform float grass_contact = 0.4;
uniform bool source_bird_flight = false;
// How this part follows the seasons (scripts/scene_look.gd leaf_season): x
// autumn gold and spring freshness, y winter leaf fall, z spring blossom
// share, w winter die-back. The default keeps the source's autumn only.
uniform vec4 leaf_season = vec4(1.0, 0.0, 0.0, 0.0);
varying vec3 leaf_local;
varying vec2 plant_root;
varying float foliage_gust;
varying float grass_along;
varying float grass_bow;
varying float inversion_transmit;
// Fire, written per instance by GardenView.set_object_fire: (char, burn).
uniform bool instance_fire_enabled = false;
// Emerged births, written per instance by GardenView into INSTANCE_CUSTOM.ba.
uniform bool instance_birth_enabled = false;
uniform vec2 object_fire = vec2(0.0);
// Cave earth walls only (BigfootLairRoom): the room's unrotated world origin,
// the wall's outward normal, and how far its middle has dissolved.
uniform vec3 cutaway_origin = vec3(0.0);
uniform vec3 cutaway_normal = vec3(0.0);
uniform float cutaway_half_width = 14.2;
uniform float cutaway_ceiling = 8.3;
uniform float cutaway_reveal = 0.0;
varying vec2 char_state;
varying flat float char_clump;
varying float char_seed;
varying vec3 world_normal;
varying vec3 world_position;
// Height above the object's own origin: props and plants sit on theirs, so
// low parts are nearer the ground and see less of the sky.
varying float contact_height;
// The precipitation height map: 128 texels over the 32 m plate, alpha the
// water surface height (-1000 where dry). Read for wet banks only.
global uniform sampler2D zs_water_map;

#include "res://shaders/terrain_geology.gdshaderinc"

// Chunk atlas: borders that meet a neighbour (n, e, s, w as 1) stay at their
// pinned height while the live chunk folds down or grows back, so a seam never
// opens mid-regeneration (the source's SEAM_HOLD).
uniform vec4 atlas_hold = vec4(0.0);
uniform float atlas_hold_width = 3.2;
float zs_atlas_hold_at(vec2 p) {
	float d = 1.0e3;
	if (atlas_hold.x > 0.5) d = min(d, p.y + 14.0);
	if (atlas_hold.y > 0.5) d = min(d, 14.0 - p.x);
	if (atlas_hold.z > 0.5) d = min(d, 14.0 - p.y);
	if (atlas_hold.w > 0.5) d = min(d, p.x + 14.0);
	return 1.0 - smoothstep(0.0, atlas_hold_width, d);
}

void vertex() {
	leaf_local = VERTEX;
	plant_root = MODEL_MATRIX[3].xz;
	if (leaf_season.w > 0.0) VERTEX *= zs_season_dieback(leaf_season.w);
	foliage_gust = 0.0;
	grass_along = grass_blades ? clamp(UV.y, 0.0, 1.0) : 0.0;
	grass_bow = 0.0;
	vec2 grass_tilt = vec2(0.0);
	char_state = instance_fire_enabled ? INSTANCE_CUSTOM.rg : object_fire;
	char_clump = zs_char_clump(VERTEX);
	char_seed = zs_char_seed(MODEL_MATRIX[3].xz);
	if (terrain_growth) {
		float grown = max(max(smoothstep(UV.x, UV.x + 0.3, zs_growth_now().x), UV.y), zs_atlas_hold_at(VERTEX.xz));
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
	if (fish_swim) {
		float phase = MODEL_MATRIX[3].x * 2.3 + MODEL_MATRIX[3].z * 1.7;
		float whip = smoothstep(fish_wave.x, fish_wave.y, VERTEX.z);
		VERTEX.x += sin(zs_motion_time * 9.0 + phase + VERTEX.z * fish_wave.w) * whip * fish_wave.z;
	}
	if (conifer_sway) {
		VERTEX += zs_conifer_offset(VERTEX, MODEL_MATRIX);
	}
	if (sway_enabled && !conifer_sway) {
		vec2 root = MODEL_MATRIX[3].xz;
		float phase = dot(root, sway_phase.xy);
		float bend = smoothstep(sway_shape.x, sway_shape.y, VERTEX.y);
		float wave = sway_frequency.z * sin(zs_motion_time * sway_frequency.x + phase)
			+ sway_frequency.w * sin(zs_motion_time * sway_frequency.y + phase * sway_phase.z);
		float g = zs_gust_field(root);
		float gust = 0.22 + 1.15 * g * g;
		// Wind is a world-space direction; asset yaw must not rotate the air.
		vec2 lean = zs_wind_direction * zs_wind_strength * zs_wind_strength * sway_shape.z * 0.55 * bend * gust;
		vec2 flap = zs_wind_direction * (wave * bend * sway_shape.z * zs_wind_strength * gust);
		float shiver = sin(zs_motion_time * 9.3 + phase * 4.7) * smoothstep(0.5, 0.85, g) * 0.35;
		vec2 side = vec2(-zs_wind_direction.y, zs_wind_direction.x)
			* ((sin(zs_motion_time * sway_frequency.y * 1.7 + phase * 2.1) + shiver) * bend * sway_shape.w * zs_wind_strength);
		vec2 motion = lean + flap + side;
		if (grass_blades) {
			// The long wind waves the dense meadow rolls with (grass_look).
			float crest = zs_grass_crest(root, ZS_GRASS_WAVE_LENGTH, ZS_GRASS_WAVE_SPEED, zs_grass_offset);
			float grass_air = min(zs_wind_strength, 1.5);
			float blade_arm = max(VERTEX.y, 0.0) * length(MODEL_MATRIX[1].xyz);
			motion += zs_wind_direction * min(grass_air * ZS_GRASS_WAVE_STRENGTH * crest * gust, 0.95) * grass_along * blade_arm;
			grass_bow = crest * min(grass_air, 1.0) * gust;
			grass_tilt = motion * 1.7;
		}
		float instance_scale = length(MODEL_MATRIX[1].xyz);
		VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(motion.x, 0.0, motion.y) * instance_scale;
		float arm = max(VERTEX.y - sway_shape.x, 0.25);
		VERTEX.y -= min(dot(motion, motion) / (2.0 * arm), arm * 0.7);
		foliage_gust = clamp(gust * zs_wind_strength * bend * 0.5, 0.0, 1.0);
		// A walker's tread (shaders/foliage_tread.gdshaderinc): stems inside a
		// tread lean away from it and lie over, and whatever is under the
		// foot itself is pressed flat. World-space like the wind above.
		if (zs_tread_0.w > 0.0 && !tree_tread) {
			float press = 0.0;
			vec2 shove = zs_tread_push(root, press) * (arm * ZS_TREAD_REACH * bend);
			if (press > 0.0) {
				VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(shove.x, 0.0, shove.y) * instance_scale;
				float lean_sq = min(dot(shove, shove), arm * arm * 0.96);
				VERTEX.y -= (arm - sqrt(arm * arm - lean_sq)) + arm * bend * press * ZS_TREAD_FLATTEN;
			}
		}
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

	}
	if (tree_tread && zs_tread_0.w > 0.0) VERTEX += zs_tree_tread(VERTEX, MODEL_MATRIX, tree_tread_height);
	if (cozy_prop_growth && !plant_growth) VERTEX *= smoothstep(0.70, 0.98, zs_growth_now().x);
	// An emerged instance also pops in at its own birth, INSTANCE_CUSTOM.ba =
	// (born, seconds); instances without one stay at 1 (scripts/emergence.gd).
	float birth = instance_birth_enabled && !bird_wings ? zs_birth_growth(INSTANCE_CUSTOM.b, INSTANCE_CUSTOM.a) : 1.0;
	if (plant_growth || birth < 1.0) {
		float t = birth;
		if (plant_growth) {
			float seed = fract(sin(dot(MODEL_MATRIX[3].xz, vec2(12.9898, 78.233))) * 43758.5453);
			t = min(t, clamp((min(zs_growth_now().y, zs_growth_wave_at(MODEL_MATRIX[3].xz)) - seed * 0.72) / 0.28, 0.0, 1.0));
		}
		float b = t - 1.0;
		VERTEX *= 1.0 + 2.70158 * b * b * b + 1.70158 * b * b;
	}
	// Trunks, deadwood and stone char but never curl or thin.
	zs_char_curl(VERTEX, char_state.x, char_clump, palette_role != 3 && palette_role != 4);
	play_deform(VERTEX, NORMAL);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	if (grass_blades) {
		// Light the tuft as part of the field's soft mass: the ground's
		// normal from the height map, domed outward toward the tips.
		ivec2 texel = clamp(ivec2(floor((plant_root + 16.0) * 4.0)), ivec2(0), ivec2(126));
		float h00 = texelFetch(zs_water_map, texel, 0).g;
		float h10 = texelFetch(zs_water_map, texel + ivec2(1, 0), 0).g;
		float h01 = texelFetch(zs_water_map, texel + ivec2(0, 1), 0).g;
		vec2 slope = min(h00, min(h10, h01)) > -100.0 ? vec2(h10 - h00, h01 - h00) * 4.0 : vec2(0.0);
		vec3 ground_normal = normalize(vec3(-slope.x, 1.0, -slope.y));
		vec2 out_dir = (mat3(MODEL_MATRIX) * vec3(leaf_local.x, 0.0, leaf_local.z)).xz;
		world_normal = normalize(mix(world_normal, zs_grass_mass_normal(ground_normal, out_dir, grass_along, grass_round, grass_tilt), 0.9));
	}
	contact_height = (terrain_growth || bird_wings) ? 1000.0 : world_position.y - MODEL_MATRIX[3].y;
}

void fragment() {
	if (cutaway_reveal > 0.0 && cave_cutaway(world_position - cutaway_origin, cutaway_normal, cutaway_half_width, cutaway_ceiling, cutaway_reveal, FRAGCOORD.xy)) discard;
	if (leaf_season.y > 0.0 && zs_leaf_fallen(leaf_local, plant_root, leaf_season.y)) discard;
	vec3 face_normal = world_normal;
	if (grass_blades) {
		face_normal = normalize(face_normal);
		NORMAL = normalize((VIEW_MATRIX * vec4(face_normal, 0.0)).xyz);
	}
	if (flat_faces && !grass_blades) {
		face_normal = normalize(cross(dFdx(world_position), dFdy(world_position)));
		// Three.js flat DoubleSide surfaces shade the face toward the viewer.
		if (dot(face_normal, zs_camera_position - world_position) < 0.0) face_normal = -face_normal;
		NORMAL = normalize((VIEW_MATRIX * vec4(face_normal, 0.0)).xyz);
	}
	vec3 tint = scene_palette(base_color.rgb * COLOR.rgb);
	if (grass_blades) {
		// The family's grass leaned to living green, dark at the root and
		// sunlit at the tip like the dense meadow, with straw patches as
		// accents and the paling of blades a passing wave bows. The vertex
		// colour over the mesh's own gradient keeps blade jitter and tints.
		vec3 grass_src = max(mix(grass_source_root, grass_source_tip, grass_along), vec3(0.002));
		vec3 own = clamp(COLOR.rgb / grass_src, vec3(0.0), vec3(3.0));
		vec3 living = zs_grass_living(zs_palette_grass * ZS_GRASS_SOURCE, grass_living, ZS_GRASS_LIVING_SATURATION);
		float tuft_shade = 1.0 + (fract(sin(dot(plant_root, vec2(37.1, 91.7))) * 43758.5453) - 0.5) * 2.0 * grass_variation;
		float dry = zs_grass_dry(plant_root, ZS_GRASS_DRY_SCALE, zs_grass_offset) * grass_dry;
		tint = zs_grass_paint(living * base_color.rgb * own, grass_along, dry, ZS_GRASS_STRAW, ZS_GRASS_ROOT_SHADE, ZS_GRASS_TIP_LIFT, ZS_GRASS_TIP_CURVE) * tuft_shade;
		tint *= 1.0 + ZS_GRASS_WAVE_SHEEN * grass_bow * grass_along;
	}
	if (terrain_growth && (rock_treatment > 0 || inland_rock_amount > 0.0 || desert_enabled)) tint = terrain_geology(tint,world_position,face_normal);
	zs_autumn_paint(tint, world_position, zs_autumn * leaf_season.x);
	if (palette_role == 2) zs_season_leaves(tint, leaf_local, plant_root, face_normal, leaf_season.x, leaf_season.z);
	else if (palette_role == 1 || palette_role == 5) zs_season_grass(tint, leaf_season.x);
	if (plant_growth) tint *= mix(1.0, 0.62, zs_foliage_wet) * (1.0 + 0.10 * foliage_gust);
	// Order is palette -> autumn -> season -> char -> wet -> snow: rain still darkens a
	// charred crown and snow still settles on it.
	float char_scorch = 0.0;
	vec3 char_ember = vec3(0.0);
	if (char_state.x > 0.004 || char_state.y > 0.004) {
		bool char_foliage = palette_role != 3 && palette_role != 4;
		if (zs_char_gone(char_state.x, char_clump, char_foliage)) discard;
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
	if (wet_ground && zs_look_shore > 0.0) {
		// Look pass: ground just above a pond or stream reads damp. The nearest
		// water within half a metre sets the line; a little noise breaks it.
		float water = -1000.0;
		for (int i = 0; i < 5; i++) {
			vec2 offset = i == 0 ? vec2(0.0) : vec2(cos(float(i) * 1.5708), sin(float(i) * 1.5708)) * 0.45;
			ivec2 texel = ivec2(floor((world_position.xz + offset + 16.0) * 4.0));
			if (all(greaterThanEqual(texel, ivec2(0))) && all(lessThan(texel, ivec2(128))))
				water = max(water, texelFetch(zs_water_map, texel, 0).a);
		}
		float above = world_position.y - water;
		float line = 0.16 + 0.10 * zs_noise(world_position.xz * 1.7);
		float bank = water > -100.0 ? (1.0 - smoothstep(line * 0.4, line, above)) * step(-0.3, above) : 0.0;
		bank *= smoothstep(-0.2, 0.3, face_normal.y) * zs_look_shore * (1.0 - zs_ice);
		surface_wet = max(surface_wet, bank);
		tint *= 1.0 - bank * 0.32;
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
	tint *= mix(1.0, 0.56, coat_wetness);
	ALBEDO = tint;
	ROUGHNESS = mix(roughness_value, mix(0.58, 0.20, mineral), surface_wet);
	ROUGHNESS = mix(ROUGHNESS, 0.48, coat_wetness);
	ROUGHNESS = mix(ROUGHNESS, 1.0, char_scorch);
	METALLIC = metalness_value;
	// The source scene has no environment map; sky reflection would lift and
	// desaturate every shaded facet.
	SPECULAR = 0.35 * coat_wetness;
	// Three.js RE_IndirectDiffuse_Physical applies BRDF_Lambert (albedo / PI)
	// to hemisphere irradiance. Emission bypasses Godot's BRDF, so include it here.
	// Look pass: ambient-only contact occlusion. Emission bypasses Godot's SSAO,
	// so the hemisphere term is where grounding has to happen.
	float contact = mix(1.0, 0.42 + 0.58 * smoothstep(0.0, 0.85, contact_height), zs_look_ao);
	if (grass_blades) contact = mix(1.0, contact, grass_contact);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, face_normal.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	EMISSION = emissive_color + tint * hemi * contact;
	if (zs_look_rim > 0.0) {
		// Sky sheen on silhouettes, stronger against the sun; ground-facing
		// and flat-lying faces stay out so meadows do not glaze over.
		vec3 view_dir = normalize(zs_camera_position - world_position);
		float edge = pow(1.0 - abs(dot(face_normal, view_dir)), 4.0);
		float backlit = 0.5 + 0.5 * max(dot(-view_dir, zs_sun_direction), 0.0);
		float upright = 1.0 - smoothstep(0.6, 0.9, face_normal.y);
		EMISSION += mix(tint, vec3(0.5), 0.35) * zs_hemi_sky * zs_hemi_energy * edge * backlit * upright * contact * zs_look_rim;
	}
	vec3 alpen_normal = normalize(cross(dFdx(world_position), dFdy(world_position)));
	if (dot(alpen_normal, face_normal) < 0.0) alpen_normal = -alpen_normal;
	EMISSION += zs_afterglow(world_position, alpen_normal, tint) + char_ember;
	inversion_transmit = zs_inversion_paint(world_position, EMISSION);
}

#define ZS_GRASS_TRANSLUCENCY
#define ZS_GRASS_ALONG grass_along
#define ZS_GRASS_GLOW (grass_blades ? grass_tip_glow : 0.0)
#include "res://shaders/reference_direct_light.gdshaderinc"
