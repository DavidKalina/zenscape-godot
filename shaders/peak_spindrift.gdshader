shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Spindrift (scripts/endless/peak_spindrift.gd): ribbons of blown snow, every
// one a strip turned to the eye round its own line, which runs from a root on
// the rock off down zs_wind_direction, climbing a little, widening, wandering.
// Streaks in the noise run down it at the wind's speed. Soft against the land,
// in the clouds' light and the land's haze. Nothing here touches the CPU.
#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/cumulus_light.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"

// Vertex attributes (PeakSpindrift):
//   VERTEX   the root
//   UV       (s 0 root .. 1 tail, side -1..1)
//   CUSTOM0  length, half width at the root, at the tail (m), seed
//   CUSTOM1  the way across its ridge (x, z; zero at a tip), climb per metre, power

uniform sampler3D noise : repeat_enable, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D cloud_shape : hint_default_black, filter_nearest, repeat_disable;
uniform vec4 haze = vec4(120.0, 7600.0, 0.75, 0.8);
uniform float haze_height = 650.0;
uniform float sea_y = -40.0;
uniform float sun_scatter = 0.18;
uniform float haze_share = 0.45;
// How thick a veil is at its fullest.
uniform float opacity = 0.54;

// The snow's speed down the ribbon (m/s) and the noise's tile (m).
const float RUN = 26.0;
const float TILE = 430.0;
// The veil fades against the land over this (m), and near the eye.
const float SOFT = 26.0;
const vec2 NEAR = vec2(14.0, 130.0);
// Past these distances the middle streaks drop out.
const vec2 MIDDLE = vec2(1800.0, 4200.0);
const float LIFT = 1.25;

varying float v_s;
varying float v_v;
varying float v_len;
varying float v_w;
varying flat float v_seed;
varying float v_show;

// The line at s, `len` long, off a root: down the wind, climbing, wandering
// more toward the tail, the wander itself running down the wind.
vec3 line_at(float s, float len, float seed, float rise, vec3 wind, vec3 lat) {
	float d = s * len;
	float wander = sin(d / 190.0 - zs_motion_time * 0.16 + seed * 20.0) + 0.5 * sin(d / 83.0 - zs_motion_time * 0.27 + seed * 41.0);
	float heave = sin(d / 240.0 - zs_motion_time * 0.11 + seed * 13.0);
	return wind * d + lat * wander * 26.0 * s + vec3(0.0, d * rise + heave * 15.0 * s, 0.0);
}

void vertex() {
	vec3 root = VERTEX;
	float s = UV.x;
	float seed = CUSTOM0.w;
	vec2 wd = normalize(zs_wind_direction + vec2(1e-4, 0.0));
	vec3 wind = vec3(wd.x, 0.0, wd.y);
	vec3 lat = vec3(-wd.y, 0.0, wd.x);
	// A ridge sends snow off only with the wind across it.
	float across = 1.0;
	if (dot(CUSTOM1.xy, CUSTOM1.xy) > 0.25) across = smoothstep(0.3, 0.75, abs(dot(wd, CUSTOM1.xy)));
	// Each breathes slowly: it blows, slackens, blows again.
	float breath = 0.5 + 0.5 * sin(zs_motion_time * (0.07 + 0.06 * seed) + seed * 37.0);
	breath = mix(0.45, 1.0, breath * breath * (3.0 - 2.0 * breath));
	float blow = clamp(zs_wind_strength * 1.5, 0.35, 1.2);
	float len = CUSTOM0.x * mix(0.6, 1.0, breath) * mix(0.75, 1.1, clamp(blow, 0.0, 1.0));
	vec3 c = root + line_at(s, len, seed, CUSTOM1.z, wind, lat);
	vec3 next = root + line_at(s + 0.02, len, seed, CUSTOM1.z, wind, lat);
	vec3 t = normalize(next - c);
	vec3 cam = MAIN_CAM_INV_VIEW_MATRIX[3].xyz;
	vec3 to = normalize(cam - c);
	vec3 side = cross(t, to);
	float sl = length(side);
	float w = mix(CUSTOM0.y, CUSTOM0.z, pow(s, 0.8));
	VERTEX = c + side / max(sl, 1e-3) * UV.y * w;
	v_s = s;
	v_v = UV.y;
	v_len = len;
	v_w = w;
	v_seed = seed;
	// A ribbon seen end on has no face to show.
	v_show = CUSTOM1.w * across * breath * smoothstep(0.08, 0.3, sl) * min(blow * 1.4, 1.0);
}

void fragment() {
	if (v_show < 0.003) discard;
	float t = length(VERTEX);
	vec3 eye = CAMERA_POSITION_WORLD;
	vec3 rd = mat3(INV_VIEW_MATRIX) * (VERTEX / t);
	float soft = 1.0;
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	if (depth > 1e-6) {
		vec4 up = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
		soft = smoothstep(0.0, SOFT, length(up.xyz / up.w) - t);
	}
	if (soft <= 0.0) discard;

	float s = v_s;
	float d = s * v_len;
	float run = fract(zs_motion_time * RUN / TILE);
	// Streaks: long down the ribbon, tight across it, and thinning to threads
	// toward the tail.
	vec3 c = vec3(d / TILE - run, v_v * v_w / 58.0, v_seed * 3.7);
	float big = textureLod(noise, c, 0.0).g;
	float keep = 1.0 - smoothstep(MIDDLE.x, MIDDLE.y, t);
	float mid = keep > 0.0 ? textureLod(noise, c * vec3(2.0, 3.3, 1.0) + 0.31, 0.0).r : 0.5;
	float edge = 1.0 - v_v * v_v;
	float shape = edge * 1.25 - 0.62 + (big - 0.5) * 1.5 + (mid - 0.5) * 0.9 * keep - s * 0.5;
	float along = smoothstep(0.0, 0.035, s) * (1.0 - smoothstep(0.45, 1.0, s));
	float a = smoothstep(0.0, 0.72, shape) * along * v_show * opacity;
	a *= soft * smoothstep(NEAR.x, NEAR.y, t);
	if (a < 0.003) discard;

	vec3 sun = normalize(zs_sun_direction + vec3(0.0, 1e-4, 0.0));
	vec3 sun_hue;
	vec3 c_sun;
	vec3 c_shade;
	float lining;
	zs_cumulus_palette(rd, sun, sun_hue, c_sun, c_shade, lining);
	float toward_sun = max(dot(rd, sun), 0.0);
	float high = smoothstep(0.02, 0.4, sun.y);
	// Fine ice: bright, whiter still toward the sun, cold in its thin parts.
	float thick = smoothstep(0.1, 0.9, shape);
	vec3 lit = (0.8 * c_shade * mix(0.3, 1.0, high) + (1.05 + 0.5 * thick + lining + 1.2 * pow(toward_sun, 5.0)) * c_sun);
	lit *= ZS_CUMULUS_LIT_SHARE * mix(1.0, LIFT, zs_daylight);
	lit = mix(lit, lit * vec3(0.86, 0.93, 1.06), 1.0 - thick);

	// The haze between, the cloud sheet's: by distance, thinner the higher.
	float y0 = max(eye.y - sea_y, 0.0);
	float y1 = max(eye.y + rd.y * t - sea_y, 0.0);
	float climb = y1 - y0;
	float airmass = abs(climb) > 1.0 ? haze_height * (exp(-y0 / haze_height) - exp(-y1 / haze_height)) / climb : exp(-y0 / haze_height);
	float dist = t * airmass / exp(-min(y0, 150.0) / haze_height);
	float fog = pow(clamp((dist - haze.x) / (haze.y - haze.x), 0.0, 1.0), haze.z) * haze.w * haze_share;
	vec3 behind_it = normalize(vec3(rd.x, max(rd.y, 0.0), rd.z));
	vec3 dome = zsSkyBase(behind_it);
	dome *= 0.98 / max(max(max(dome.r, dome.g), dome.b), 0.98);
	vec3 sky = scene_linear_for_display(dome);
	ALBEDO = mix(lit, sky, fog);

	float front = 1.0;
	vec4 sheet = texelFetch(cloud_shape, min(ivec2(FRAGCOORD.xy), textureSize(cloud_shape, 0) - 1), 0);
	float cloud_a = clamp(sheet.x, 0.0, 1.0);
	if (cloud_a > 0.003 && sheet.y / cloud_a < t) front = 1.0 - cloud_a;
	ALPHA = a * front;
}
