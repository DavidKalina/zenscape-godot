shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;
// The rain seen through the air (scripts/endless/weather_rain.gd; lifted
// from the old storm's storm_rain_air.gdshader, keyed to the rain field): a
// sheet over the screen, drawn just after the clouds' sheet (EndlessClouds
// RENDER_PRIORITY -6), that walks each pixel's ray through the rain under
// the cloud (zs_rain_at, from the sea up to `rise`, fading over it) to the
// scene's depth or the sky, and lays a grey over it by how much rain the ray
// crossed. So from kilometres off a cell reads as a soft grey shaft hanging
// under the cloud, its sides the field's own kilometre feathers, leaning
// downwind as it falls, with lit land showing beyond it; in a storm's steady
// rain the distance greys a little; near, nothing (the streaks are the rain
// there). No cards, so nothing has an edge or a box. Cost: one full-screen
// pass of TAPS reads of the field a pixel; the node is hidden while no rain
// falls anywhere.

#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/weather.gdshaderinc"

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
// What lies behind (the sea's copy of the screen, shared): the rain is a
// grey of its brightness, "behind_dark" of it, partly the light's own
// grey ("own_light"), so a shaft reads darker against a bright sky and
// greys dark land beyond, at any hour.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float behind_dark = 0.6;
uniform float own_light = 0.35;
uniform float sea_y = -40.0;
// The rain's air: whole up to rise.x m over the sea, gone by rise.y (the
// cloud's bases are 115-190 m over the sea, its towers' feet lower; the
// shaft's top frays into them).
uniform vec2 rise = vec2(450.0, 1250.0);
// Extinction per metre at a rain of 1: 3 km through a cell's heart about
// half grey.
uniform float sigma = 0.0007;
// The share of the rain between the cells (a storm's floor) that greys the
// air: less than the cells', so the cells stand out as shafts.
uniform float floor_share = 0.5;
// The most grey laid (the land always shows through), and how near the eye
// it starts (m): the near rain is the streaks'.
uniform float most = 0.8;
uniform vec2 near_eye = vec2(150.0, 900.0);
// How far the march reaches (m): past it the scene's haze has it.
uniform float reach = 14000.0;
// The fall's lean downwind (m across per m down).
uniform float shear = 0.35;
// Fibres: the shaft's fall streaks, broad enough to read from kilometres.
uniform float fibres = 0.35;
uniform float opacity = 1.0;
uniform vec3 tint = vec3(0.72, 0.76, 0.79);
// The light on the rain while the eye is out of it (the cell's own shade).
uniform float shade = 0.5;
uniform float brightness = 1.0;
// The clouds' march (EndlessClouds' resolved shape: x its cover, y its
// cover-weighted distance), so rain behind a cloud is seen only through it.
uniform sampler2D cloud_shape : filter_nearest, repeat_disable;
uniform float clouds_on = 0.0;

uniform int debug_view = 0;

const int TAPS = 16;

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
	v_light = tint * vec3(luma) * mix(shade, 1.0, zs_weather.z) * brightness;
}

void fragment() {
	if (zs_rain_field.z <= 0.0) discard;
	vec3 eye = CAMERA_POSITION_WORLD;
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec3 vp = view.xyz / view.w;
	vec3 rd = normalize(mat3(INV_VIEW_MATRIX) * vp);
	float t1 = depth <= 1e-6 ? 1e6 : length(vp);
	float top = sea_y + rise.y;
	// Clipped to the air under the rain's top and over the sea.
	float t0 = near_eye.x;
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
	t1 = min(t1, reach);
	if (t1 <= t0) discard;
	float dt = (t1 - t0) / float(TAPS);
	// Taps nudged per pixel (interleaved gradient noise) so they never band.
	float jit = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	float cover = 0.0;
	float t_cloud = 1e9;
	if (clouds_on > 0.5) {
		vec4 cb = texelFetch(cloud_shape, min(ivec2(FRAGCOORD.xy), textureSize(cloud_shape, 0) - 1), 0);
		cover = clamp(cb.x, 0.0, 1.0);
		if (cover > 0.003) t_cloud = cb.y / cover;
	}
	vec4 field = zs_rain_field;
	field.w *= floor_share;
	vec2 lean = zs_wind_direction * shear;
	vec2 side = vec2(-zs_wind_direction.y, zs_wind_direction.x);
	float tau = 0.0;
	for (int k = 0; k < TAPS; k++) {
		float t = t0 + (float(k) + jit) * dt;
		vec3 p = eye + rd * t;
		float h = p.y - sea_y;
		float up = 1.0 - smoothstep(rise.x, rise.y, h);
		// Where this drop left the cloud: upwind of it, the higher the more.
		vec2 src = p.xz - lean * (top - p.y);
		float rain = zs_rain_field_at(src, field);
		// The fall's fibres: across the wind, falling with it.
		float f = ra_noise(vec2(dot(src, side) / 160.0, dot(src, zs_wind_direction) / 420.0));
		float heavy = mix(1.0 - fibres, 1.0 + fibres, f);
		float nearby = smoothstep(near_eye.x, near_eye.y, t);
		// The cloud's distance a hard step along the ray: the share of this
		// tap's stretch before it, so the jitter makes no grain.
		float before = clamp((t_cloud - (t0 + float(k) * dt)) / dt, 0.0, 1.0);
		tau += rain * up * heavy * nearby * dt * (before + (1.0 - before) * (1.0 - cover));
	}
	float a = (1.0 - exp(-tau * sigma)) * most * opacity;
	if (debug_view == 7) {
		ALBEDO = vec3(a, tau * 0.0002, 0.0);
		ALPHA = 1.0;
	} else if (debug_view == 6) {
		vec3 fw = -INV_VIEW_MATRIX[2].xyz;
		vec2 fxz = normalize(fw.xz);
		ALBEDO = vec3(zs_rain_at(eye.xz + fxz * SCREEN_UV.x * 8000.0), 0.0, 0.0);
		ALPHA = 1.0;
	} else if (debug_view == 5) {
		float tq = t0 + 5.5 * dt;
		vec3 pq = eye + rd * tq;
		vec2 sq = pq.xz - lean * (top - pq.y);
		ALBEDO = vec3(zs_rain_field_at(sq, field), zs_rain_field_at(pq.xz, zs_rain_field), tq / 20000.0);
		ALPHA = 1.0;
	} else if (debug_view == 4) {
		vec3 pp = eye + rd * 4500.0;
		float uu = 1.0 - smoothstep(rise.x, rise.y, pp.y - sea_y);
		vec2 ss = pp.xz - lean * (top - pp.y);
		ALBEDO = vec3(uu, zs_rain_field_at(ss, field), (t1 - t0) / 10000.0);
		ALPHA = 1.0;
	} else if (debug_view == 3) {
		ALBEDO = vec3(tau * 0.0002);
		ALPHA = 1.0;
	} else if (debug_view == 2) {
		ALBEDO = vec3(tau * 0.0005, cover, t1 / 20000.0);
		ALPHA = 1.0;
	} else {
		if (a < 0.002) discard;
		vec3 bg = texture(screen_tex, SCREEN_UV).rgb;
		float bl = dot(bg, vec3(0.2126, 0.7152, 0.0722));
		ALBEDO = mix(tint * bl * behind_dark, v_light, own_light);
		ALPHA = clamp(a, 0.0, 1.0);
	}
}
