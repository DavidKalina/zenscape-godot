shader_type spatial;
// Dense meadow grass for the Ultra tier (scripts/dense_grass.gd). Every tile
// shares one MultiMesh of blade tufts whose transforms are all identity:
// the tuft's root comes from its instance ID on the tile's grid, its height
// from the precipitation ground map, and its colour and density from a mask
// baked from the terrain mesh, so blades only stand where the ground is green.
// The look is a painterly meadow (docs/scenic/grass-look.md): tufts gather
// into tussocks with gaps between, blades arc outward and run dark at the
// root to a sunlit tip, the field shades as one soft mass, wind rolls across
// it in long waves, and a few tufts carry a seed head or a small flower.
#include "res://shaders/scene_palette.gdshaderinc"
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/grass_look.gdshaderinc"
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
// Emerged cover per 0.5 m meadow cell of the 28 m plate (56 x 56), from
// scripts/dense_grass.gd: r the cell's birth on zs_emergence_time, g the share
// of its tufts that stood before, a 1 where there is a birth.
uniform sampler2D emergence_map : hint_default_black, filter_nearest, repeat_disable;
uniform float emergence_creep = 3.0;
uniform float emergence_rise = 1.4;
instance uniform vec2 tile_origin;
uniform int grid_side = 32;
uniform float spacing = 0.11;
uniform float blade_height = 0.34;
uniform float blade_width = 1.0;
uniform float density = 1.0;
// Beyond fade_start the tufts thin out and widen to keep the cover, and drop
// blades down to far_blades each.
uniform float fade_start = 22.0;
uniform float fade_end = 58.0;
uniform float far_blades = 3.0;
uniform float metalness_value = 0.0;
// Every world-scale noise below is shifted by zs_grass_offset (grass_look),
// so each seed has its own tussocks, dry patches and flower drifts.

// Tussocks: a noise of this frequency (per metre) gathers tufts into clumps;
// tuft_contrast is how bare the gaps between them go (0 even, 1 bare), and
// tuft_lift how much taller the heart of a tussock stands.
uniform float tuft_scale = 1.3;
uniform float tuft_contrast = 0.7;
uniform float tuft_lift = 0.75;
// How much lusher grass grows within about 0.75 m of water.
uniform float water_lush = 0.35;
// How far the blades of a tuft splay (scales the mesh's baked root spread and
// lean) and how their arc bends (higher keeps the stem upright, the tip over).
uniform float tuft_spread = 1.0;
uniform float blade_lean = 1.0;
uniform float blade_curve = 1.8;

// Colour, as multipliers of the palette-tinted ground colour.
uniform vec3 root_shade = vec3(0.46, 0.53, 0.46);
uniform vec3 tip_lift = vec3(1.30, 1.28, 0.84);
uniform float tip_curve = 0.8;
// How far the palette-tinted ground colour leans to living green, so muted
// families (Chalk & turquoise) grow a green meadow, not a grey one
// (grass_look zs_grass_living).
uniform float living_pull = 0.4;
uniform float living_saturation = 1.12;
// World-noise patches gone to straw, as accents: how much, how big (per
// metre) and colour.
uniform float dry_amount = 0.25;
uniform float dry_scale = 0.16;
uniform vec3 straw_tint = vec3(1.18, 1.0, 0.62);
// Per-tuft brightness jitter.
uniform float tuft_variation = 0.12;

// Mass shading: how much the field lights as one soft surface rather than
// blade by blade, and how round each tuft's own dome reads.
uniform float mass_shading = 0.9;
uniform float tuft_round = 0.55;
// Sun through backlit tips when looking toward it.
uniform float tip_translucency = 0.55;

// Wind: the shared breeze (reference_wind, docs/scenic/breeze.md), long
// waves rolling downwind across the field on the same air travel as the
// gust field, so they are frame-rate independent. Metres per wave, speed as
// a share of the air's travel, lean a crest adds per unit of breeze (in
// zs_blow_at's units), paling as the blades bow, and a per-blade flutter.
uniform float wave_length = 9.0;
uniform float wave_speed = 1.0;
uniform float wave_strength = 0.42;
uniform float wave_sheen = 0.34;
uniform float flutter = 0.06;

// Accents: shares of tufts that carry a flower (in drifts) or a seed head,
// spring's extra bloom, head sizes in metres, and how far flower colours lean
// toward the palette's earth.
uniform float flower_amount = 0.035;
uniform float spring_flowers = 0.08;
uniform float seed_amount = 0.04;
uniform float flower_size = 0.026;
uniform vec2 seed_head_size = vec2(0.008, 0.075);
uniform float flower_palette_pull = 0.3;

varying vec3 world_position;
varying vec3 blade_normal;
varying vec3 ground_color;
varying float blade_t;
varying float inversion_transmit;
// Per tuft: how dry, its brightness jitter, and how far a wind wave bows it.
varying float dry;
varying float tuft_shade;
varying float wind_bow;
// 0 blade, 1 accent stem, 2 accent head; the accent's kind (1 seed head,
// 2..5 flowers) and, on a flower head, the distance from its eye (0..1).
varying float accent_part;
varying float accent_kind;
varying float head_r;

float grass_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec4 ground_texel(ivec2 texel) {
	return texelFetch(zs_water_map, clamp(texel, ivec2(0), ivec2(ZS_MAP_TEXELS - 1)), 0);
}

// 1 where this texel holds water standing above its ground.
float wet_texel(ivec2 texel) {
	vec4 t = ground_texel(texel);
	return step(-100.0, t.a) * step(t.g, t.a);
}

void vertex() {
	vec2 cell = vec2(float(INSTANCE_ID % grid_side), float(INSTANCE_ID / grid_side));
	vec2 seed = tile_origin * 3.17 + cell;
	vec2 root = tile_origin + (cell + vec2(grass_hash(seed), grass_hash(seed + 19.3))) * spacing;
	// Bilinear ground height from four texels; any void or water tap drops the clump.
	vec2 g = (root + zs_map_half) * 4.0 - 0.5;
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
	vec4 mask = texture(grass_mask, (root + zs_map_half) / (zs_map_half * 2.0));
	float n = zs_noise(root * 0.85 + 3.1);
	// Tussocks and the bare gaps between them.
	float tussock = smoothstep(0.28, 0.72, zs_noise(root * tuft_scale + zs_grass_offset) * 0.75 + n * 0.25);
	float keep = mask.a * density * (0.45 + 0.55 * n) * mix(1.0, tussock, tuft_contrast)
		* (1.0 - smoothstep(0.55, 0.95, length(gradient)))
		* step(-100.0, low) * step(water, ground - 0.04);
	float near_water = max(max(wet_texel(base + ivec2(3, 0)), wet_texel(base - ivec2(3, 0))),
		max(wet_texel(base + ivec2(0, 3)), wet_texel(base - ivec2(0, 3))));
	float distance_to_eye = length(vec3(root.x, ground, root.y) - zs_camera_position);
	float thin = 1.0 - 0.6 * smoothstep(fade_start, fade_end, distance_to_eye);
	float grown = smoothstep(grass_hash(seed + 7.7) * 0.6, grass_hash(seed + 7.7) * 0.6 + 0.4, min(zs_growth_now().y, zs_growth_wave_at(root)));
	// Emerged cover (scripts/emergence.gd): as the cell thickens, each new
	// tuft rises from the ground in keep order, the first at the cell's birth
	// and the last emergence_creep seconds later. Tufts it had before stay.
	vec4 birth = texture(emergence_map, (floor((root + zs_plate_half) * 2.0) + 0.5) / (zs_plate_half * 4.0));
	if (birth.a > 0.5) {
		float rank = grass_hash(seed + 5.1) / max(keep * thin, 0.0001);
		if (rank >= birth.g) {
			float start = birth.r + emergence_creep * (rank - birth.g) / max(1.0 - birth.g, 0.0001);
			grown = min(grown, smoothstep(0.0, 1.0, clamp((zs_emergence_now() - start) / emergence_rise, 0.0, 1.0)));
		}
	}
	float height = blade_height * (0.55 + 0.9 * zs_noise(root * 0.37 + 11.0)) * (0.7 + 0.3 * mask.a)
		* (0.8 + 0.4 * grass_hash(seed + 2.9)) * grown * (1.0 - 0.75 * smoothstep(0.1, 0.7, zs_snow))
		* (1.0 - 0.3 * zs_season.z);
	height *= (1.0 - 0.5 * tuft_lift + tuft_lift * tussock) * (1.0 + water_lush * near_water);
	// Per tuft: an accent when below its share, and which kind.
	float flower_pick = grass_hash(seed + 23.7);
	// This vertex's part of the tuft (scripts/dense_grass.gd _clump_mesh).
	float part = CUSTOM1.w;
	float kept_blades = mix(16.0, far_blades, smoothstep(fade_start, fade_end, distance_to_eye));
	// Accents: flowers gather in drifts of one kind, spring adds more and
	// winter takes them; seed heads stand where the grass is drier.
	dry = zs_grass_dry(root, dry_scale, zs_grass_offset) * dry_amount * (1.0 - near_water);
	float drift = smoothstep(0.42, 0.78, zs_noise(root * 0.42 + zs_grass_offset * 1.3 + 7.0));
	float flower_share = (flower_amount + spring_flowers * zs_season.x) * (1.0 - zs_season.z) * drift * 2.0;
	float seed_share = seed_amount * (0.6 + dry * 2.0);
	accent_kind = 0.0;
	if (flower_pick < flower_share) {
		float kind = fract(flower_pick * 97.0 + zs_noise(root * 0.21 + zs_grass_offset) * 1.3);
		accent_kind = 2.0 + min(floor(kind * 4.0), 3.0);
	} else if (flower_pick > 1.0 - seed_share) {
		accent_kind = 1.0;
	}
	bool hidden = grass_hash(seed + 5.1) > keep * thin || height < 0.01
		|| (part < 0.5 && CUSTOM1.z >= kept_blades) || (part > 0.5 && accent_kind < 0.5);
	accent_part = part;
	head_r = 1.0;
	dry += (grass_hash(seed + 41.3) - 0.5) * 0.12;
	tuft_shade = 1.0 + (grass_hash(seed + 37.1) - 0.5) * 2.0 * tuft_variation;
	wind_bow = 0.0;
	if (hidden) {
		VERTEX = vec3(0.0, -1000.0, 0.0);
		blade_t = 0.0;
		ground_color = vec3(0.0);
		blade_normal = vec3(0.0, 1.0, 0.0);
		world_position = VERTEX;
	} else {
		float yaw = grass_hash(seed + 13.1) * TAU;
		mat2 turn = mat2(vec2(cos(yaw), sin(yaw)), vec2(-sin(yaw), cos(yaw)));
		blade_t = UV.y;
		// Each blade's own height, where it roots in the tuft, its width
		// across and its outward arc, lying over more toward the tip.
		float blade_h = height * CUSTOM0.z;
		vec2 offset = turn * CUSTOM1.xy * tuft_spread;
		vec2 across = turn * VERTEX.xz * (blade_width / thin);
		float arc = pow(blade_t, blade_curve);
		vec2 bow = turn * CUSTOM0.xy * blade_lean * arc * blade_h;
		// Wind: the shared breeze (zs_breeze_lean_wave): long waves rolling
		// downwind with wandering crests, slow gust bands and the gust
		// field's patches. The tip lags the air and sways round its lean a
		// beat behind the root, each tuft at its own phase; a light flutter
		// over it.
		float bend = blade_t * blade_t;
		float bowed;
		float breeze_lean = zs_breeze_lean_wave(root, ZS_BREEZE_LAG * blade_h * blade_t, wave_strength / ZS_BREEZE_WAVE, wave_length, wave_speed, bowed);
		wind_bow = bowed;
		float sway_phase = dot(root, vec2(0.43, 0.71)) + CUSTOM0.w * 0.6;
		float pace = zs_breeze_pace(blade_h);
		float swing = sin(zs_motion_time * pace + sway_phase - blade_t * 0.9) * 0.7
			+ sin(zs_motion_time * pace * 1.63 + sway_phase * 1.7 - blade_t * 1.3) * 0.3;
		float shiver = sin(zs_motion_time * 5.3 + CUSTOM0.w * TAU + dot(root, vec2(1.7, 1.3))) * flutter * zs_breeze_air();
		vec2 motion = zs_wind_direction * min(breeze_lean * (1.0 + ZS_BREEZE_SWING * swing), 0.95) * bend * blade_h;
		motion += vec2(-zs_wind_direction.y, zs_wind_direction.x) * shiver * bend * blade_h;
		// Local gusts (the wind tool's, scripts/wind_gust.gd, and the
		// resident's) bow the blades their own way, as they bend the trees in
		// reference_surface, and the bowed blades catch the sky.
		vec3 air = zs_local_wind(vec3(root.x, ground + 0.5, root.y));
		float air_speed = length(air);
		if (air_speed > 0.001) {
			float give = air_speed / (air_speed + 10.0);
			motion += air.xz / air_speed * give * 0.9 * bend * blade_h;
			wind_bow = max(wind_bow, give * 0.8);
		}
		// The wind tool (scripts/wind_gust.gd) lays the meadow over its own
		// way, in a travelling front that springs back (zs_blow_at).
		float blow_shiver;
		vec2 blow = zs_blow_at(root, CUSTOM0.w * TAU, blow_shiver);
		motion += (blow + vec2(-blow.y, blow.x) * blow_shiver * 0.12 * sin(zs_motion_time * 13.0 + CUSTOM0.w * 40.0)) * zs_blow_give(blade_h) * bend * blade_h;
		wind_bow = max(wind_bow, max(length(blow), blow_shiver) * 0.8);
		float press = 0.0;
		if (zs_tread_0.w > 0.0) {
			vec2 shove = zs_tread_push(root, press) * blade_h * ZS_TREAD_REACH * bend;
			motion += shove;
		}
		vec2 lean = bow + motion;
		float lift = blade_t * blade_h;
		lift -= min(dot(lean, lean) / (2.0 * max(blade_h, 0.01)), lift * 0.7) + lift * press * ZS_TREAD_FLATTEN;
		lift -= zs_foliage_wet * bend * blade_h * 0.2;
		vec3 placed = vec3(offset.x + across.x + lean.x, lift, offset.y + across.y + lean.y);
		vec3 ground_normal = normalize(vec3(-gradient.x, 1.0, -gradient.y));
		vec3 facing = vec3(-sin(yaw), 0.0, cos(yaw));
		if (part > 1.5) {
			// A flower's flat face or a seed head's slim spike, on its stem's tip.
			if (UV.x < 0.5) {
				head_r = length(VERTEX.xz);
				float petal = accent_kind > 1.5 ? flower_size : 0.0;
				placed += vec3(turn * VERTEX.xz * petal, 0.0).xzy;
			} else {
				vec2 spike = accent_kind > 1.5 ? seed_head_size * vec2(0.6, 0.35) : seed_head_size;
				placed += vec3(turn * VERTEX.xz * spike.x, 0.0).xzy + vec3(0.0, VERTEX.y * spike.y, 0.0);
			}
			placed.y += blade_h * 0.02;
		}
		VERTEX = vec3(root.x + placed.x, ground - 0.03 + placed.y, root.y + placed.z);
		world_position = VERTEX;
		// Shade as a soft mass: the ground's normal, domed outward over each
		// tuft toward its tips and tipped downwind as the blades bow, with a
		// little of the blade's own facing left for texture.
		vec3 dome = zs_grass_mass_normal(ground_normal, offset + bow, blade_t, tuft_round, motion / max(blade_h, 0.01) * 0.6);
		blade_normal = normalize(mix(facing, dome, mass_shading));
		if (part > 1.5 && UV.x < 0.5) blade_normal = ground_normal;
		ground_color = mask.rgb;
	}
	NORMAL = blade_normal;
}

void fragment() {
	NORMAL = normalize((VIEW_MATRIX * vec4(blade_normal, 0.0)).xyz);
	vec3 tint = zs_grass_living(scene_palette(ground_color), living_pull, living_saturation);
	// Patches gone to straw, then dark at the root where the blades crowd
	// and sunlit toward the tip, each tuft a shade apart.
	tint = zs_grass_paint(tint, blade_t, dry, straw_tint, root_shade, tip_lift, tip_curve) * tuft_shade;
	// Blades bowed by a passing wave catch more sky and read paler.
	tint *= 1.0 + wave_sheen * wind_bow * blade_t;
	zs_autumn_paint(tint, world_position, zs_autumn);
	// Fresh in spring, straw through winter.
	zs_season_grass(tint, 1.0);
	if (accent_part > 0.5) {
		vec3 earth_pull = mix(vec3(1.0), zs_palette_earth, flower_palette_pull);
		if (accent_part < 1.5) {
			tint *= vec3(0.86, 0.94, 0.78);
		} else if (accent_kind < 1.5) {
			tint = vec3(0.60, 0.50, 0.31) * earth_pull * mix(0.85, 1.1, head_r);
		} else {
			// White daisy, buttercup, violet and clover, each with its own eye.
			vec3 petal = vec3(0.70, 0.68, 0.60);
			vec3 eye = vec3(0.70, 0.52, 0.12);
			if (accent_kind > 4.5) { petal = vec3(0.66, 0.38, 0.50); eye = vec3(0.52, 0.30, 0.40); }
			else if (accent_kind > 3.5) { petal = vec3(0.42, 0.30, 0.62); eye = vec3(0.72, 0.62, 0.30); }
			else if (accent_kind > 2.5) { petal = vec3(0.74, 0.56, 0.10); eye = vec3(0.56, 0.40, 0.08); }
			tint = mix(eye, petal, smoothstep(0.25, 0.45, head_r)) * earth_pull;
		}
	}
	tint *= mix(1.0, 0.72, zs_foliage_wet);
	tint = mix(tint, vec3(0.88, 0.91, 0.95), smoothstep(0.3, 0.9, zs_snow) * blade_t * 0.6);
	float cloud_shade = cloudShadeAt(vec3(world_position.x, 0.6, world_position.z), zs_cloud_direction);
	tint *= mix(1.0, 0.42 + 0.58 * cloud_shade, min(1.0, zs_cloud.x * 1.35) * 0.85);
	ALBEDO = tint;
	ROUGHNESS = 0.88;
	float contact = mix(1.0, 0.5 + 0.5 * blade_t, max(zs_look_ao, 0.5));
	EMISSION = tint * mix(zs_hemi_ground, zs_hemi_sky, blade_normal.y * 0.5 + 0.5) * zs_hemi_energy / PI * contact;
	EMISSION += zs_afterglow(world_position, blade_normal, tint);
	inversion_transmit = zs_inversion_paint(world_position, EMISSION);
}

#define ZS_GRASS_TRANSLUCENCY
#define ZS_GRASS_ALONG blade_t
#define ZS_GRASS_GLOW tip_translucency
#include "res://shaders/reference_direct_light.gdshaderinc"
