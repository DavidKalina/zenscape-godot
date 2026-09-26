shader_type spatial;
// Dense meadow grass for the Ultra tier (scripts/dense_grass.gd). Every tile
// shares one MultiMesh of blade clumps whose transforms are all identity:
// the clump's root comes from its instance ID on the tile's grid, its height
// from the precipitation ground map, and its colour and density from a mask
// baked from the terrain mesh, so blades only stand where the ground is green.
#include "res://shaders/scene_palette.gdshaderinc"
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/foliage_tread.gdshaderinc"
#include "res://shaders/reference_autumn.gdshaderinc"
#include "res://shaders/reference_season.gdshaderinc"
#include "res://shaders/reference_cloud_field.gdshaderinc"
#include "res://shaders/reference_alpenglow.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
#include "res://shaders/reference_inversion.gdshaderinc"
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;

// rgb: the terrain's own linear colour; a: how grassy it is (0..1).
uniform sampler2D grass_mask : filter_linear, repeat_disable;
// g: ground height, a: water surface height; -1000 where there is none.
global uniform sampler2D zs_water_map;
instance uniform vec2 tile_origin;
uniform int grid_side = 32;
uniform float spacing = 0.11;
uniform float blade_height = 0.26;
uniform float blade_width = 1.0;
uniform float density = 1.0;
// Beyond fade_start the clumps thin out and widen to keep the cover.
uniform float fade_start = 22.0;
uniform float fade_end = 58.0;
uniform float metalness_value = 0.0;
#define ZS_FOLIAGE_TRANSMISSION
uniform float foliage_transmission = 0.35;

varying vec3 world_position;
varying vec3 blade_normal;
varying vec3 ground_color;
varying float blade_t;
// Per clump: a spring wildflower when below the bloom's share, and its colour.
varying float flower_pick;
varying float inversion_transmit;

float grass_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec4 ground_texel(ivec2 texel) {
	return texelFetch(zs_water_map, clamp(texel, ivec2(0), ivec2(127)), 0);
}

void vertex() {
	vec2 cell = vec2(float(INSTANCE_ID % grid_side), float(INSTANCE_ID / grid_side));
	vec2 seed = tile_origin * 3.17 + cell;
	vec2 root = tile_origin + (cell + vec2(grass_hash(seed), grass_hash(seed + 19.3))) * spacing;
	// Bilinear ground height from four texels; any void or water tap drops the clump.
	vec2 g = (root + 16.0) * 4.0 - 0.5;
	ivec2 base = ivec2(floor(g));
	vec2 f = fract(g);
	vec4 a = ground_texel(base);
	vec4 b = ground_texel(base + ivec2(1, 0));
	vec4 c = ground_texel(base + ivec2(0, 1));
	vec4 d = ground_texel(base + ivec2(1, 1));
	float low = min(min(a.g, b.g), min(c.g, d.g));
	float ground = mix(mix(a.g, b.g, f.x), mix(c.g, d.g, f.x), f.y);
	float water = max(max(a.a, b.a), max(c.a, d.a));
	vec2 gradient = vec2((b.g - a.g) + (d.g - c.g), (c.g - a.g) + (d.g - b.g)) * 2.0;
	vec4 mask = texture(grass_mask, (root + 16.0) / 32.0);
	float n = zs_noise(root * 0.85 + 3.1);
	float keep = mask.a * density * (0.45 + 0.55 * n)
		* (1.0 - smoothstep(0.55, 0.95, length(gradient)))
		* step(-100.0, low) * step(water, ground - 0.04);
	float distance_to_eye = length(vec3(root.x, ground, root.y) - zs_camera_position);
	float thin = 1.0 - 0.6 * smoothstep(fade_start, fade_end, distance_to_eye);
	float grown = smoothstep(grass_hash(seed + 7.7) * 0.6, grass_hash(seed + 7.7) * 0.6 + 0.4, min(zs_growth.y, zs_growth_wave_at(root)));
	float height = blade_height * (0.55 + 0.9 * zs_noise(root * 0.37 + 11.0)) * (0.7 + 0.3 * mask.a)
		* (0.8 + 0.4 * grass_hash(seed + 2.9)) * grown * (1.0 - 0.75 * smoothstep(0.1, 0.7, zs_snow))
		* (1.0 - 0.3 * zs_season.z);
	flower_pick = grass_hash(seed + 23.7);
	if (grass_hash(seed + 5.1) > keep * thin || height < 0.01) {
		VERTEX = vec3(0.0, -1000.0, 0.0);
		blade_t = 0.0;
		ground_color = vec3(0.0);
		blade_normal = vec3(0.0, 1.0, 0.0);
		world_position = VERTEX;
	} else {
		float yaw = grass_hash(seed + 13.1) * TAU;
		mat2 turn = mat2(vec2(cos(yaw), sin(yaw)), vec2(-sin(yaw), cos(yaw)));
		blade_t = UV.y;
		vec2 across = turn * VERTEX.xz * vec2(blade_width / thin, 1.0);
		// Wind: the scene's lean, flap and gusts, as the tufts sway, stronger at the tip.
		float phase = dot(root, vec2(0.9, 0.7)) + UV2.x * 2.3;
		float gust = 0.22 + 1.15 * zs_gust_field(root);
		float wave = sin(zs_motion_time * 1.9 + phase) * 0.6 + sin(zs_motion_time * 3.4 + phase * 1.3) * 0.25;
		float bend = blade_t * blade_t;
		vec2 motion = zs_wind_direction * (zs_wind_strength * zs_wind_strength * 0.5 + wave * zs_wind_strength * 0.45) * gust * bend * height;
		motion += UV2.y * turn * vec2(0.0, 0.25) * bend * height;
		float press = 0.0;
		if (zs_tread_0.w > 0.0) {
			vec2 shove = zs_tread_push(root, press) * height * ZS_TREAD_REACH * bend;
			motion += shove;
		}
		float lift = blade_t * height;
		lift -= min(dot(motion, motion) / (2.0 * max(height, 0.01)), lift * 0.7) + lift * press * ZS_TREAD_FLATTEN;
		lift -= zs_foliage_wet * bend * height * 0.2;
		VERTEX = vec3(root.x + across.x + motion.x, ground - 0.03 + lift, root.y + across.y + motion.y);
		world_position = VERTEX;
		// Mostly the ground's normal, so the meadow shades like the land it
		// covers; a little of the blade's own facing keeps the texture.
		vec3 ground_normal = normalize(vec3(-gradient.x, 1.0, -gradient.y));
		blade_normal = normalize(mix(vec3(-sin(yaw), 0.0, cos(yaw)), ground_normal, 0.7));
		ground_color = mask.rgb;
	}
	NORMAL = blade_normal;
}

void fragment() {
	NORMAL = normalize((VIEW_MATRIX * vec4(blade_normal, 0.0)).xyz);
	vec3 tint = scene_palette(ground_color);
	// Dark at the root where the blades crowd, sun-bleached toward the tip.
	tint *= mix(vec3(0.62), vec3(1.12, 1.14, 0.92), blade_t);
	zs_autumn_paint(tint, world_position, zs_autumn);
	// Fresh in spring, straw through winter, and a scatter of wildflowers
	// opening at the tips as the spring bloom rises.
	zs_season_grass(tint, 1.0);
	if (zs_season.x > 0.004 && flower_pick < 0.07 * zs_season.x && blade_t > 0.78) {
		float kind = fract(flower_pick * 97.0);
		tint = kind < 0.45 ? vec3(0.66, 0.64, 0.57) : (kind < 0.8 ? vec3(0.68, 0.50, 0.10) : vec3(0.40, 0.29, 0.58));
	}
	tint *= mix(1.0, 0.72, zs_foliage_wet);
	tint = mix(tint, vec3(0.88, 0.91, 0.95), smoothstep(0.3, 0.9, zs_snow) * blade_t * 0.6);
	float cloud_shade = cloudShadeAt(vec3(world_position.x, 0.6, world_position.z), zs_cloud_direction);
	tint *= mix(1.0, 0.42 + 0.58 * cloud_shade, min(1.0, zs_cloud.x * 1.35) * 0.85);
	ALBEDO = tint;
	ROUGHNESS = 0.9;
	float contact = mix(1.0, 0.5 + 0.5 * blade_t, max(zs_look_ao, 0.5));
	EMISSION = tint * mix(zs_hemi_ground, zs_hemi_sky, blade_normal.y * 0.5 + 0.5) * zs_hemi_energy / PI * contact;
	EMISSION += zs_afterglow(world_position, blade_normal, tint);
	inversion_transmit = zs_inversion_paint(world_position, EMISSION);
}

#include "res://shaders/reference_direct_light.gdshaderinc"
