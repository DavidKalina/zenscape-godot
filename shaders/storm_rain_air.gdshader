shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;
// The rain's air (scripts/endless/storm_rain.gd): the grey a downpour lays
// over everything seen through it. A sheet over the screen, drawn just after
// the clouds' sheet (EndlessClouds RENDER_PRIORITY -6), that walks each
// pixel's ray through the rain under the deck (the storm's rain band by d,
// from the ground up to the cloud base, fading over it) to the scene's
// depth, the sea's level or the sky, and lays a grey over it by how much
// rain the ray crossed. So the distance under the deck goes grey and joins
// the base: no clean strip of sky shows under a storm from inside it or
// from kilometres out, and the near land softens in a downpour. Heavier
// shafts of rain (noise on the storm's own frame, riding it) make the grey
// uneven. Cost: one full-screen pass of a few cheap taps; discarded where a
// ray never meets rain.

#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/storm_front.gdshaderinc"

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform float sea_y = -40.0;
// The rain's air: whole up to rise.x m over the sea, gone by rise.y (the
// deck's base is 190 to 240 m, lifted over high ground; over it the air
// greys the cloud's foot, joining the two).
uniform vec2 rise = vec2(240.0, 650.0);
// Extinction per metre in full rain: how fast a view through the rain goes
// grey (3 km of it nearly wholly).
uniform float sigma = 0.0011;
// How uneven the rain: the share taken by the heavier shafts.
uniform float shafts = 0.55;
uniform float opacity = 1.0;
uniform vec3 tint = vec3(0.70, 0.75, 0.76);
// The light on the rain seen from out in the sun (the storm's own shade).
uniform float shade = 0.6;
uniform float brightness = 1.0;
uniform float clock = 0.0;
// The shafts' drift across the storm (m/s).
uniform float drift = 6.0;

const int TAPS = 12;

float ra_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float ra_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(ra_hash(i), ra_hash(i + vec2(1.0, 0.0)), u.x),
		mix(ra_hash(i + vec2(0.0, 1.0)), ra_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

varying vec3 v_light;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
	vec3 sky = zs_hemi_sky * zs_hemi_energy / PI;
	vec3 sun = zs_key_irradiance / PI * zs_daylight;
	vec3 lit = sky * 1.25 + sun * 0.08 + vec3(0.003);
	float luma = dot(lit, vec3(0.2126, 0.7152, 0.0722));
	v_light = tint * mix(vec3(luma), lit, 0.2) * mix(shade, 1.0, zs_storm_here) * brightness;
}

void fragment() {
	if (!zs_storm_on()) discard;
	vec3 eye = CAMERA_POSITION_WORLD;
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec3 vp = view.xyz / view.w;
	vec3 rd = normalize(mat3(INV_VIEW_MATRIX) * vp);
	float t1 = depth <= 1e-6 ? 1e6 : length(vp);
	float top = sea_y + rise.y;
	// Clipped to the air under the deck's reach and over the sea.
	float t0 = 0.0;
	if (abs(rd.y) > 1e-5) {
		float t_top = (top - eye.y) / rd.y;
		float t_sea = (sea_y - eye.y) / rd.y;
		if (rd.y > 0.0) {
			t1 = min(t1, t_top);
			t0 = max(t0, t_sea);
		} else {
			t0 = max(t0, t_top);
			t1 = min(t1, t_sea);
		}
	} else if (eye.y > top || eye.y < sea_y) {
		discard;
	}
	// ...and to the rain's band by d (linear along the ray).
	float core = zs_storm_shape.y;
	float d_hi = ZS_STORM_RAIN_IN.x;
	float d_lo = -core - ZS_STORM_RAIN_OUT.x;
	float d0 = zs_storm_d(eye.xz);
	float dd = dot(rd.xz, zs_storm_line.zw);
	if (abs(dd) > 1e-5) {
		float ta = (d_hi - d0) / dd;
		float tb = (d_lo - d0) / dd;
		t0 = max(t0, min(ta, tb));
		t1 = min(t1, max(ta, tb));
	} else if (d0 > d_hi || d0 < d_lo) {
		discard;
	}
	t1 = min(t1, 30000.0);
	if (t1 <= t0) discard;
	// Taps spread evenly, nudged per pixel so the steps never band.
	float dt = (t1 - t0) / float(TAPS);
	float jit = ra_hash(FRAGCOORD.xy);
	vec2 side = vec2(-zs_storm_line.w, zs_storm_line.z);
	float tau = 0.0;
	for (int i = 0; i < TAPS; i++) {
		float t = t0 + (float(i) + jit) * dt;
		vec3 p = eye + rd * t;
		float rain = zs_storm_rain(p.xz);
		if (rain <= 0.0) continue;
		float h = p.y - sea_y;
		float up = 1.0 - smoothstep(rise.x, rise.y, h);
		// The shafts: on the storm's frame, drifting along the line.
		vec2 q = vec2(dot(p.xz - zs_storm_line.xy, side) + clock * drift, zs_storm_d(p.xz));
		float n = ra_noise(q / vec2(520.0, 700.0)) * 0.65 + ra_noise(q / vec2(190.0, 260.0) + 7.3) * 0.35;
		float heavy = mix(1.0 - shafts, 1.0 + shafts, smoothstep(0.25, 0.75, n));
		tau += rain * up * heavy * dt;
	}
	float a = (1.0 - exp(-tau * sigma)) * opacity;
	if (a < 0.002) discard;
	ALBEDO = v_light;
	ALPHA = clamp(a, 0.0, 1.0);
}
