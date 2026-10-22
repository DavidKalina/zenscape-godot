shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, unshaded, shadows_disabled;
// The endless flight's sea (scripts/endless/endless_sea.gd), forked from the
// lower world's ocean (shaders/sky_ocean.gdshader, kept as `--water=old`).
//
// - Waves: a few Gerstner swells heave the sheet near the eye (and their
//   normal is worked out per pixel from the rest position), with two
//   scrolling noise-normal layers at three scales for the chop. Every layer
//   fades where it is finer than a pixel, into a rougher sheen.
// - Colour by the water's real depth: a baked map of the land's height round
//   the eye (`depth_map`), so the turquoise shelf and the deep blue read the
//   same from any height; the bed behind each pixel (the depth buffer) still
//   shows through the shallows.
// - Reflective: fresnel toward the hour's sky, the cloud field mirrored from
//   the clouds' shade map (zs_cloud_shadow), what stands on screen by a short
//   march, a soft sun path and a crisp, stylised glitter.
// - Foam: a broken line at the shore, bands rolling in over the shelf, a
//   touch on the steepest crests, and the plane's wake (a trail of its recent
//   points: a churned centre line and the two arms of a V spreading out).
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
#include "res://shaders/reference_tonemap.gdshaderinc"
#include "res://shaders/reference_lake_lighting.gdshaderinc"
#include "res://shaders/reference_lake_glint.gdshaderinc"
#include "res://shaders/cloud_volume_shadow.gdshaderinc"
global uniform vec3 zs_palette_water;
uniform sampler2D sea_screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D sea_depth : hint_depth_texture, filter_nearest, repeat_disable;

// The chop's normal maps (seamless noise, EndlessSea `_detail`).
uniform sampler2D detail_a : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_b : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// The detail layers' sizes (m a tile) and strengths.
uniform vec3 detail_size = vec3(46.0, 15.0, 4.6);
uniform vec3 detail_strength = vec3(0.16, 0.12, 0.08);

// The land's height (world y) over a square round the eye: corner xz, side,
// on (EndlessSea `_depth`).
uniform sampler2D depth_map : filter_linear, repeat_disable;
uniform vec4 depth_at = vec4(0.0);
uniform float sea_level = -40.0;

// The water's colour by depth (m of water under the surface).
uniform vec3 tint_shallow : source_color = vec3(0.42, 0.90, 0.82);
uniform vec3 tint_mid : source_color = vec3(0.07, 0.52, 0.66);
uniform vec3 tint_deep : source_color = vec3(0.04, 0.27, 0.55);
uniform vec3 tint_abyss : source_color = vec3(0.02, 0.12, 0.36);
uniform vec4 tint_depths = vec4(1.5, 7.0, 22.0, 55.0);
uniform vec3 absorb = vec3(0.30, 0.075, 0.06);
uniform float bed_fade = 5.0;
uniform float water_light = 2.6;

// The swell's heading (world xz), its strength, and the chop's.
uniform vec2 swell_heading = vec2(0.8, 0.6);
uniform float swell = 1.0;
uniform float chop = 1.0;
uniform vec2 heave_reach = vec2(90.0, 150.0);
uniform vec2 paw_size = vec2(90.0, 55.0);
uniform float paws = 1.0;

// Reflection: the fresnel's floor and power, how much the cloud field is
// mirrored and the height (world y) it is taken at.
uniform float fresnel_floor = 0.05;
uniform float fresnel_power = 4.0;
uniform float cloud_mirror = 0.8;
uniform float cloud_mirror_y = 20.0;
uniform int mirror_steps = 12;
uniform vec2 mirror_march = vec2(2.5, 1.55);
uniform float mirror_calm = 0.4;
// The sun: its soft path, and the crisp glitter on the chop.
uniform float glint_share = 1.0;
uniform float glitter = 1.0;
uniform float cloud_shade = 1.0;
// The light through the crests facing the sun.
uniform float crest_glow = 0.5;

// Foam: at the shore (the line's depth, the bands' reach m deep), on the
// crests, and overall.
uniform float shore_foam = 0.7;
uniform float wash_depth = 7.0;
uniform float crest_foam = 0.6;
uniform float foam = 1.0;

// The wake: the plane's recent points (xz, the time it passed, strength),
// newest first, the clock, and the plane now (xz, strength, reach m).
const int WAKE_POINTS = 40;
uniform vec4 wake_points[40];
uniform int wake_count = 0;
uniform float wake_now = 0.0;
uniform vec4 wake_head = vec4(0.0);
uniform float wake = 1.0;
// How fast the V's arms ride out (m/s, from the plane's speed).
uniform float wake_spread = 6.0;
// 1: the water's depth (red 0..10 m, green 10..60 m), 2: foam cover.
uniform int debug_view = 0;

varying vec3 world_position;
varying vec2 rest_xz;

const int SWELLS = 4;
const float GRAVITY = 9.81;
const float DEEP = 1.0e4;

// The Gerstner swells at `p` (rest xz): the sideways shove and rise
// (`shift`), the slope, the crest's sharpness (`crest`, toward 1 at a cusp),
// each faded out where finer than `footprint`; `rough` gathers what fades.
vec2 zs_swell(vec2 p, float t, float footprint, out vec3 shift, out float crest, out float rough) {
	const float LENGTH[4] = float[4](44.0, 27.0, 17.0, 10.5);
	const float TURN[4] = float[4](0.0, 0.45, -0.38, 0.9);
	const float STEEP[4] = float[4](0.055, 0.05, 0.05, 0.045);
	const float SHARP[4] = float[4](0.55, 0.7, 0.8, 0.85);
	vec2 heading = normalize(swell_heading);
	vec2 slope = vec2(0.0);
	shift = vec3(0.0);
	crest = 0.0;
	rough = 0.0;
	float wind = 0.6 + 0.4 * min(zs_wind_strength, 1.5);
	for (int i = 0; i < SWELLS; i++) {
		float c = cos(TURN[i]), s = sin(TURN[i]);
		vec2 d = vec2(c * heading.x - s * heading.y, s * heading.x + c * heading.y);
		float k = TAU / LENGTH[i];
		float steep = STEEP[i] * swell * wind;
		float held = 1.0 - smoothstep(LENGTH[i] * 0.06, LENGTH[i] * 0.18, footprint);
		float phase = dot(p, d) * k - sqrt(GRAVITY * k) * t + float(i) * 1.7;
		float a = steep / k;
		float q = SHARP[i];
		shift.xz += d * q * a * cos(phase) * held;
		shift.y += a * sin(phase) * held;
		slope += d * steep * cos(phase) * held;
		crest += q * steep * sin(phase) * held;
		rough += 0.5 * steep * steep * (1.0 - held * held);
	}
	return slope;
}

// The chop: two noise normal maps at three scales, scrolling three ways.
vec2 zs_chop(vec2 p, float t, float air, float footprint, out float rough) {
	vec2 wind = zs_wind_direction;
	vec2 side = vec2(-wind.y, wind.x);
	vec2 d1 = wind;
	vec2 d2 = normalize(wind * 0.6 + side * 0.8);
	vec2 d3 = normalize(wind * 0.7 - side * 0.7);
	vec2 a = texture(detail_a, (p + d1 * t * 1.1) / detail_size.x).xy * 2.0 - 1.0;
	vec2 b = texture(detail_b, (p + d2 * t * 0.75) / detail_size.y).xy * 2.0 - 1.0;
	vec2 c = texture(detail_a, (p.yx * vec2(1.0, -1.0) + d3 * t * 0.5) / detail_size.z).xy * 2.0 - 1.0;
	vec3 held = vec3(1.0) - smoothstep(detail_size * 0.04, detail_size * 0.2, vec3(footprint));
	vec3 strength = detail_strength * air;
	rough = dot(strength * strength * (vec3(1.0) - held * held), vec3(0.5));
	return a * strength.x * held.x + b * strength.y * held.y + c * strength.z * held.z;
}

// How hard the wind works the sea at `p`: cat's paws and slicks.
float zs_sea_air(vec2 p, out float paw) {
	vec2 dir = zs_wind_direction;
	vec2 across = vec2(-dir.y, dir.x);
	vec2 q = p - dir * zs_gust_distance;
	vec2 a = vec2(dot(q, dir), dot(q, across));
	float big = zs_noise(a / paw_size + vec2(3.1, 7.7)) * 0.65 + zs_noise(a / (paw_size * 0.43) + vec2(11.3, 2.9)) * 0.35;
	paw = smoothstep(0.42, 0.78, big) * paws;
	float lane = zs_noise(vec2(dot(p, across) * 0.06, dot(p, dir) * 0.004 - zs_gust_distance * 0.002));
	float slick = smoothstep(0.62, 0.86, lane) * (1.0 - paw);
	float air = clamp(zs_wind_strength, 0.0, 2.5);
	return (0.45 + 0.55 * air) * (0.6 + 0.9 * paw) * (1.0 - 0.6 * slick) * chop;
}

vec3 zs_sea_receiver(vec2 uv, float depth, mat4 inv_projection, mat4 inv_view) {
	vec4 view = inv_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return (inv_view * vec4(view.xyz / view.w, 1.0)).xyz;
}

// The water's depth under `p` from the map (DEEP off it; `known` 0 there).
float zs_map_depth(vec2 p, out float known) {
	known = 0.0;
	if (depth_at.w <= 0.0) return DEEP;
	vec2 uv = (p - depth_at.xy) / depth_at.z;
	vec2 rim = min(uv, 1.0 - uv);
	known = smoothstep(0.0, 0.05, min(rim.x, rim.y));
	if (known <= 0.0) return DEEP;
	return sea_level - texture(depth_map, uv).r;
}

// The plane's wake at `p`: its foam (returned), the stirred water round it
// (`stirred`, 0..1) and the slope its ripples add. Only the nearest point of
// the track counts, so the arms are one V and not a ring per point.
float zs_wake(vec2 p, out vec2 slope, out float stirred) {
	slope = vec2(0.0);
	stirred = 0.0;
	if (wake_count < 2 || wake <= 0.0) return 0.0;
	if (distance(p, wake_head.xy) > wake_head.w) return 0.0;
	float best = 1e9;
	vec2 best_across = vec2(0.0);
	float best_age = 0.0, best_strength = 0.0;
	for (int i = 0; i < WAKE_POINTS - 1; i++) {
		if (i + 1 >= wake_count) break;
		vec4 a = wake_points[i];
		vec4 b = wake_points[i + 1];
		if (a.w <= 0.0 && b.w <= 0.0) continue;
		vec2 ab = b.xy - a.xy;
		float len2 = max(dot(ab, ab), 1e-4);
		float t = clamp(dot(p - a.xy, ab) / len2, 0.0, 1.0);
		vec2 near = a.xy + ab * t;
		float d = distance(p, near);
		if (d < best) {
			best = d;
			best_across = (p - near) / max(d, 1e-3);
			best_age = max(wake_now - mix(a.z, b.z, t), 0.0);
			best_strength = mix(a.w, b.w, t);
		}
	}
	if (best >= 1e8) return 0.0;
	float d = best, age = best_age;
	float r = 0.6 + age * wake_spread;
	float gone = 1.0 - smoothstep(3.0, 4.6, age);
	// The prop wash: a narrow churned streak, widening and fading.
	float w0 = 0.6 + age * 0.5;
	float churn = (1.0 - smoothstep(0.0, w0, d)) * exp(-age / 0.6);
	// The arms: thin foam lines riding out from the track, the V.
	float wide = 0.4 + age * 0.3;
	float arm = exp(-pow((d - r) / wide, 2.0)) * exp(-age / 2.2) * smoothstep(0.0, 0.35, age);
	float foamed = max(churn * 0.6, arm * 0.8) * best_strength * gone;
	// The water between the arms, stirred (soft, no rim).
	float inside = d / (r + 1.0);
	stirred = exp(-inside * inside * 2.5) * exp(-age / 2.6) * best_strength * gone * wake;
	// Ripples inside the arms, sloping across the track.
	float ripple = sin((d - r) * 3.1) * (1.0 - smoothstep(r * 0.4, r + 0.3, d)) * smoothstep(0.0, 0.4, d) * exp(-age / 3.5);
	slope = best_across * ripple * 0.18 * best_strength * gone * wake;
	return clamp(foamed * wake, 0.0, 1.0);
}

// Broken foam: `cover` 0..1 turned into a soft, cellular pattern.
float zs_foam_pattern(vec2 p, float t, float cover) {
	float n = zs_noise(p * 0.55 + vec2(t * 0.05, 0.0)) * 0.55 + zs_noise(p * 1.7 - vec2(0.0, t * 0.08)) * 0.3 + zs_noise(p * 4.3 + vec2(t * 0.11)) * 0.15;
	return smoothstep(1.0 - cover, 1.0 - cover + 0.22, n) * smoothstep(0.0, 0.1, cover);
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	rest_xz = world.xz;
	float reach = max(abs(VERTEX.x), abs(VERTEX.z));
	float cell = max(2.0, reach / 28.0);
	float near = 1.0 - smoothstep(heave_reach.x, heave_reach.y, reach);
	vec3 shift;
	float crest, rough;
	zs_swell(world.xz, zs_flow_time, cell, shift, crest, rough);
	VERTEX += shift * near;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 eye = normalize(CAMERA_POSITION_WORLD - world_position);
	float distance_to = length(CAMERA_POSITION_WORLD - world_position);
	float footprint = max(length(dFdx(rest_xz)), length(dFdy(rest_xz)));
	float t = zs_flow_time;
	float paw;
	float air = zs_sea_air(rest_xz, paw);
	vec3 shift;
	float crest, swell_rough, chop_rough;
	vec2 slope = zs_swell(rest_xz, t, footprint, shift, crest, swell_rough);
	vec2 detail = zs_chop(rest_xz, t, air, footprint, chop_rough);
	vec2 wake_slope;
	float stirred;
	float waked = zs_wake(rest_xz, wake_slope, stirred);
	vec3 normal = normalize(vec3(-(slope.x + detail.x + wake_slope.x), 1.0, -(slope.y + detail.y + wake_slope.y)));
	// A calmer normal for the sky's mirror, so the reflection reads as one
	// rippled image rather than noise.
	vec3 calm = normalize(vec3(-(slope.x + detail.x * 0.5), 1.0, -(slope.y + detail.y * 0.5)));
	float facing = max(dot(eye, normal), 0.0);
	float sigma = sqrt(swell_rough + chop_rough);
	float roughness = clamp(0.06 + sigma * 1.4 + footprint * 0.0015, 0.06, 0.5);
	float fresnel = fresnel_floor + (1.0 - fresnel_floor) * pow(1.0 - max(dot(eye, calm), 0.0), fresnel_power);
	fresnel *= 1.0 - 0.25 * paw * min(zs_wind_strength, 1.0);
	fresnel *= 1.0 - 0.2 * stirred;

	// The bed behind this pixel, nudged by the waves.
	vec2 uv = SCREEN_UV;
	float depth = texture(sea_depth, uv).r;
	vec3 receiver = zs_sea_receiver(uv, depth, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	float bed_depth = depth > 0.0 ? world_position.y - receiver.y : DEEP;
	vec2 bent = uv + (VIEW_MATRIX * vec4(normal.x, 0.0, normal.z, 0.0)).xy * vec2(1.0, -1.0) * 0.03 * smoothstep(0.0, 2.0, bed_depth) / (1.0 + distance_to * 0.05);
	float bent_depth = texture(sea_depth, bent).r;
	vec3 bent_receiver = zs_sea_receiver(bent, bent_depth, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	if (bent_depth <= 0.0 || bent_receiver.y < world_position.y - 0.05) {
		uv = bent;
		depth = bent_depth;
		receiver = bent_receiver;
		bed_depth = depth > 0.0 ? world_position.y - receiver.y : DEEP;
	}
	bed_depth = max(bed_depth, 0.0);
	float through = depth > 0.0 ? length(receiver - world_position) : DEEP;

	// The water's depth here: the map's where it reaches, else the bed seen.
	float known;
	float mapped = zs_map_depth(rest_xz, known);
	float waver = mix(0.8, 1.25, zs_noise(rest_xz * 0.03) * 0.7 + zs_noise(rest_xz * 0.11 + vec2(4.1, 7.3)) * 0.3);
	float fallback = max(bed_depth, through * 0.55);
	float water_depth = max(mix(fallback, mapped, known), 0.0) * waver;

	vec3 seen = exp(-absorb * through) * exp(-max(bed_depth, through * 0.4) / bed_fade);
	vec3 bed = textureLod(sea_screen, uv, 0.0).rgb;

	vec3 column = mix(tint_shallow, tint_mid, smoothstep(0.0, tint_depths.y, water_depth));
	column = mix(column, tint_deep, smoothstep(tint_depths.y * 0.6, tint_depths.z, water_depth));
	column = mix(column, tint_abyss, smoothstep(tint_depths.z, tint_depths.w, water_depth));
	column = mix(tint_shallow, column, smoothstep(0.0, tint_depths.x, water_depth) * 0.6 + 0.4);
	column *= zs_palette_water;
	vec3 ambient = zs_hemi_sky * zs_hemi_energy / PI;
	vec3 key = zs_key_irradiance * max(zs_key_direction.y, 0.0) / PI;
	vec3 light = (ambient + key * 0.8) * water_light;
	vec3 water = column * light * (vec3(1.0) - seen) + bed * seen;
	// Stirred water behind the plane: lighter with the air churned into it.
	water = mix(water, mix(tint_mid, tint_deep, 0.5) * zs_palette_water * light, stirred * 0.18);

	// Light through the crests facing the sun.
	vec3 sun = zs_sun_direction;
	vec2 sun_flat = normalize(sun.xz + vec2(1e-4));
	float toward = pow(clamp(dot(-eye.xz / max(length(eye.xz), 1e-3), sun_flat), 0.0, 1.0), 3.0);
	float lifted = smoothstep(0.06, 0.2, crest) * (0.25 + 0.75 * toward) * smoothstep(-0.05, 0.2, sun.y);
	water += tint_mid * zs_palette_water * key * lifted * crest_glow * 0.5 * smoothstep(3.0, 12.0, water_depth);

	// Foam. The shore: a broken line where the water thins out, and bands
	// rolling in over the shelf.
	float near_bed = depth > 0.0 ? min(bed_depth, mix(bed_depth, mapped, known * 0.5)) : mapped;
	float lap = shore_foam * (0.75 + 0.25 * sin(t * 0.9 + zs_noise(rest_xz * 0.2) * 6.2832));
	float line = 1.0 - smoothstep(lap * 0.3, lap, near_bed);
	float band_phase = water_depth * 1.6 + t * 0.9 + zs_noise(rest_xz * 0.035) * 4.0;
	float bands = smoothstep(0.55, 0.95, sin(band_phase)) * (1.0 - smoothstep(wash_depth * 0.35, wash_depth, water_depth)) * smoothstep(lap * 0.5, lap * 1.5, near_bed);
	float shore = max(line, bands * 0.75);
	// The crests: only the sharpest, and more where the wind works.
	float crested = smoothstep(0.12, 0.2, crest + detail.x * 0.15) * crest_foam * smoothstep(8.0, 20.0, water_depth) * (0.5 + 0.5 * paw) * min(zs_wind_strength * 1.3, 1.0);
	float cover = max(shore, crested * 0.55);
	float foamed = zs_foam_pattern(rest_xz, t, cover) * foam;
	// The wake's foam: lines broken softly rather than into islands.
	float fleck = zs_noise(rest_xz * 0.9 + vec2(t * 0.3, 0.0)) * 0.6 + zs_noise(rest_xz * 2.6 - vec2(0.0, t * 0.4)) * 0.4;
	foamed = max(foamed, (smoothstep(0.2, 0.55, waked * (0.15 + 1.3 * fleck)) * 0.9 + smoothstep(0.4, 0.85, fleck) * stirred * 0.18) * foam);
	cover = max(cover, waked);
	// Far off the pattern is finer than a pixel: an even wash instead.
	foamed = mix(foamed, cover * 0.6 * foam, smoothstep(0.15, 0.8, footprint));
	foamed = clamp(foamed, 0.0, 1.0) * float(depth > 0.0 || known > 0.0 || waked > 0.0);
	float lip = (1.0 - smoothstep(0.0, 0.15, bed_depth)) * float(depth > 0.0);
	vec3 white = vec3(0.9, 0.96, 1.0) * (ambient * 1.1 + key * 0.8);
	water = mix(water, white, foamed * 0.92);
	water += tint_shallow * (ambient + key) * lip * 0.4;

	// The mirror: the sky, the cloud field, and what stands on screen.
	vec3 reflected = reflect(-eye, calm);
	reflected.y = abs(reflected.y);
	vec3 sky = clamp(zsSkyGradient(reflected), vec3(0.0), vec3(0.98));
	if (cloud_mirror > 0.0 && zs_cloud_shadow_at.w > 0.0 && reflected.y > 0.02) {
		// Where the mirrored ray meets the cloud's height, the shade map's
		// spot under that cloud along the sun's line.
		vec3 c = world_position + reflected * ((cloud_mirror_y - world_position.y) / reflected.y);
		vec3 l = zs_cloud_shadow_light.xyz;
		vec2 q = c.xz - l.xz / max(l.y, 0.12) * (cloud_mirror_y - zs_cloud_shadow_light.w);
		vec2 cuv = (q - zs_cloud_shadow_at.xy) / max(zs_cloud_shadow_at.z, 1.0);
		if (all(greaterThan(cuv, vec2(0.0))) && all(lessThan(cuv, vec2(1.0)))) {
			// Four taps a texel and a half apart: the map is coarse, and a
			// mirror magnifies it.
			vec2 texel = 2.5 / vec2(textureSize(zs_cloud_shadow, 0));
			float thick = 0.0;
			for (int k = 0; k < 4; k++) {
				vec2 o = vec2(k % 2 == 0 ? -1.0 : 1.0, k < 2 ? -1.0 : 1.0) * texel;
				vec3 s = texture(zs_cloud_shadow, cuv + o).rgb;
				thick += 0.25 * (1.0 - s.g * s.r);
			}
			vec2 rim = min(cuv, 1.0 - cuv);
			float far = 1.0 - smoothstep(600.0, 2200.0, length(c.xz - world_position.xz));
			float cloud = smoothstep(0.0, 1.0, thick) * 0.8 * smoothstep(0.0, 0.08, min(rim.x, rim.y)) * far;
			vec3 lit_cloud = zs_scene_to_display((ambient * 1.6 + key * 0.9) * vec3(1.0, 0.99, 0.97));
			sky = mix(sky, lit_cloud, cloud * cloud_mirror);
		}
	}
	float mirrored = 0.0;
	vec3 mirror = vec3(0.0);
	if (mirror_steps > 0 && fresnel > 0.05) {
		vec3 ray = reflect(-eye, normalize(mix(vec3(0.0, 1.0, 0.0), normal, mirror_calm)));
		ray.y = abs(ray.y);
		mat4 to_clip = PROJECTION_MATRIX * VIEW_MATRIX;
		float step_length = mirror_march.x * (1.0 + distance_to * 0.01);
		float reach = step_length * (pow(mirror_march.y, float(mirror_steps)) - 1.0) / max(mirror_march.y - 1.0, 1e-3);
		float travelled = 0.0;
		float before = 0.0;
		for (int i = 0; i < 32; i++) {
			if (i >= mirror_steps) break;
			before = travelled;
			travelled += step_length;
			step_length *= mirror_march.y;
			vec3 q = world_position + ray * travelled;
			vec4 clip = to_clip * vec4(q, 1.0);
			if (clip.w <= 0.0) break;
			vec3 ndc = clip.xyz / clip.w;
			vec2 at = ndc.xy * 0.5 + 0.5;
			if (any(lessThan(at, vec2(0.0))) || any(greaterThan(at, vec2(1.0)))) break;
			float scene = texture(sea_depth, at).r;
			if (scene > ndc.z) {
				vec3 hit = zs_sea_receiver(at, scene, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
				float gap = length(hit - CAMERA_POSITION_WORLD) - length(q - CAMERA_POSITION_WORLD);
				if (gap > -(travelled - before) * 1.5 && hit.y > world_position.y - 0.2) {
					float lo = before, hi = travelled;
					for (int r = 0; r < 4; r++) {
						float mid = (lo + hi) * 0.5;
						vec4 cc = to_clip * vec4(world_position + ray * mid, 1.0);
						vec3 n = cc.xyz / cc.w;
						if (texture(sea_depth, n.xy * 0.5 + 0.5).r > n.z) hi = mid; else lo = mid;
					}
					vec4 cc = to_clip * vec4(world_position + ray * hi, 1.0);
					vec2 found = cc.xy / cc.w * 0.5 + 0.5;
					vec2 edge = smoothstep(vec2(0.0), vec2(0.06), found) * (1.0 - smoothstep(vec2(0.94), vec2(1.0), found));
					mirror = zs_scene_to_display(textureLod(sea_screen, found, 0.0).rgb);
					mirrored = edge.x * edge.y * (1.0 - smoothstep(0.2, 0.5, roughness));
					mirrored *= 1.0 - smoothstep(0.45, 1.0, hi / reach);
					vec3 surface = zs_sea_receiver(found, texture(sea_depth, found).r, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
					float behind = length(world_position + ray * hi - CAMERA_POSITION_WORLD) - length(surface - CAMERA_POSITION_WORLD);
					float thick = max(3.0, (travelled - before) * 0.125 + hi * 0.02);
					mirrored *= 1.0 - smoothstep(thick, thick * 2.0, behind);
					break;
				}
			}
		}
	}
	vec3 reflection = mix(sky, mirror, mirrored);

	// The sun: a soft path off the calm normal, and a crisp glitter off the
	// chop's own (hard-edged spots, fewer and finer far off).
	float shaded = cloud_shade > 0.0 ? zs_cloud_volume_shade(world_position) * cloud_shade : 0.0;
	vec3 smooth_n = normalize(vec3(-(slope.x + detail.x * 0.2), 1.0, -(slope.y + detail.y * 0.2)));
	vec4 path = zs_lake_glint(reflect(-eye, smooth_n), sun, zs_moon_direction, zs_celestial_clear, 0.0, glint_share);
	path.a *= 1.0 - shaded;
	float sunlight = smoothstep(-0.03, 0.12, sun.y);
	float spark_dot = dot(reflect(-eye, normal), sun);
	float spark_edge = mix(0.9993, 0.99, smoothstep(0.5, 6.0, footprint));
	float spark = smoothstep(spark_edge, spark_edge + (1.0 - spark_edge) * 0.35, spark_dot);
	spark *= smoothstep(0.85, 0.97, dot(reflect(-eye, calm), sun));
	spark *= glitter * zs_celestial_clear * sunlight * (1.0 - shaded) * (1.0 - foamed);
	vec3 lit = water + zs_lake_direct(vec3(0.0), normal, eye, zs_key_direction, zs_key_irradiance, max(roughness, 0.3)) * glint_share * 0.06 * (1.0 - foamed);
	lit *= 1.0 - 0.4 * shaded;

	float mirror_weight = fresnel * (1.0 - foamed);
	vec3 display_color = mix(zs_scene_to_display(lit), reflection, mirror_weight);
	display_color = mix(display_color, path.rgb, path.a * (1.0 - foamed));
	vec3 warm = mix(vec3(1.0, 0.62, 0.35), vec3(1.0, 0.98, 0.9), smoothstep(0.02, 0.5, sun.y));
	display_color = mix(display_color, warm, clamp(spark, 0.0, 1.0));
	if (debug_view == 1) display_color = water_depth < 5.0 ? vec3(1.0, 0.0, 0.0) : (water_depth < 20.0 ? vec3(0.0, 1.0, 0.0) : (water_depth < 60.0 ? vec3(0.0, 0.0, 1.0) : vec3(1.0))) * (0.5 + 0.5 * known);
	if (debug_view == 3) display_color = zs_scene_to_display(lit);
	if (debug_view == 4) display_color = reflection * mirror_weight;
	if (debug_view == 2) display_color = vec3(cover, foamed, waked);
	ALBEDO = scene_linear_for_display(clamp(display_color, vec3(0.0), vec3(1.0)));
	ALPHA = depth > 0.0 ? smoothstep(0.0, 0.05, bed_depth) : 1.0;
}
