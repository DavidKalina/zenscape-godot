shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_front, shadows_disabled, fog_disabled;
// A spiral's strike (scripts/endless/peak_strike.gd): the ribbon's cloud drawn
// out along a bent line. The same noise and the same light as
// shaders/peak_spiral.gdshader, the shape one solid body round the line, its grain
// stretched along it and running toward the head, which comes to a point.
//
// A box round the line, its back faces drawn, as the spiral does. Each pixel
// first tests a few spheres (one per GROUP segments), then those segments, and
// keeps the near ones in a mask: pixels that miss cost a few dots, and a step of
// the march only reads the segments near its own ray. The lighting block is a
// copy of the spiral's; keep them together.
#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/cumulus_light.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"

global uniform float zs_cloud_under;

// PeakStrike.POINTS, and segments a group (PeakStrike.GROUP).
const int POINTS = 65;
const int GROUP = 8;
const int GROUPS = 8;

// The line: xyz world, w metres along from the tail. `normals` is the body's up,
// so its grain stays put round it.
uniform vec4 pts[65];
uniform vec3 normals[65];
uniform vec4 groups[8];
uniform int count = 0;
// Metres along of the head.
uniform float head_s = 0.0;
// The body's radius (m) at the head, along the body and at the tail.
uniform vec3 girth = vec3(52.0, 27.0, 10.0);
uniform float flow = 0.0;
uniform float seed = 0.0;
uniform sampler3D noise : repeat_enable, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D cloud_shape : hint_default_black, filter_nearest, repeat_disable;
uniform vec4 haze = vec4(120.0, 7600.0, 0.75, 0.8);
uniform float haze_height = 650.0;
uniform float sea_y = -40.0;
uniform float sun_scatter = 0.18;
uniform float haze_share = 0.45;

// One tile of the noise along the body (m) and round it (shares of the girth):
// long streaks, drawn in to the head's point because they scale with the girth.
const float ALONG = 645.0;
const float ROUND_ = 1.6;
// The head: its point to its widest (m), back from there to the body (m). Across
// the point the section is a diamond, wider than it's tall (HEAD_WIDE, HEAD_FLAT),
// with its noise bite cut to HEAD_CRISP.
const float HEAD_LEN = 120.0;
const float NECK_LEN = 260.0;
const float HEAD_WIDE = 1.2;
const float HEAD_FLAT = 0.72;
const float HEAD_CRISP = 0.35;
// The head's grain drawn harder in the light, and the body a shade under it, so
// head-on the point stands off the body behind it.
const float HEAD_GRAIN = 2.2;
const float BODY_SHADE = 0.74;
const float TAIL_LEN = 320.0;
const float REACH = 1.7;
const float OPTICAL = 5.0;
// Past REACH_OUT girths nothing is drawn: what the bounds test keeps.
const float REACH_OUT = 2.0;
const vec2 NEAR = vec2(10.0, 90.0);
const vec2 GLOW = vec2(30.0, 150.0);
const int STEPS = 56;
const vec2 FINE = vec2(500.0, 1100.0);
const vec2 MIDDLE = vec2(1500.0, 3500.0);
const float LIFT = 1.25;
const vec3 BOUNCE_TINT = vec3(0.78, 0.9, 0.82);
const vec3 UNDER_ROSE = vec3(1.0, 0.42, 0.52);

struct Here {
	float e;       // 0 on the line, 1 at the body's edge.
	float r;       // The body's radius here (m).
	float rho;     // Out from the line (m).
	float s;       // Metres along the line.
	float m;       // 1 in the head, 0 in the body.
	float side;    // Across the body, in girths: along `normals`' right.
	float rise;    // And up it.
	vec3 out_dir;  // Out from the line, unit.
	vec3 along;    // Along the line, unit.
};

float rope(float s) {
	float back = max(head_s - s, 0.0);
	float k = back / HEAD_LEN;
	float g = k < 1.0 ? girth.x * pow(k, 0.8) : girth.y + (girth.x - girth.y) * (1.0 - smoothstep(0.0, 1.0, (back - HEAD_LEN) / NECK_LEN));
	return mix(girth.z, g, smoothstep(0.0, TAIL_LEN, s));
}

Here here_at(vec3 p, uvec2 mask) {
	Here o;
	float best = 1e12;
	int bi = 0;
	float bu = 0.0;
	vec3 bv = vec3(0.0);
	vec3 bt = vec3(0.0, 1.0, 0.0);
	for (int word = 0; word < 2; word++) {
		uint m = word == 0 ? mask.x : mask.y;
		while (m != 0u) {
			int i = int(findLSB(m)) + word * 32;
			m &= m - 1u;
			vec3 a = pts[i].xyz;
			vec3 ab = pts[i + 1].xyz - a;
			float u = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-3), 0.0, 1.0);
			vec3 v = p - a - ab * u;
			float d = dot(v, v);
			if (d < best) {
				best = d;
				bi = i;
				bu = u;
				bv = v;
				bt = ab;
			}
		}
	}
	float rho = sqrt(best);
	float s = mix(pts[bi].w, pts[bi + 1].w, bu);
	vec3 t = normalize(bt);
	vec3 n = mix(normals[bi], normals[bi + 1], bu);
	n = normalize(n - t * dot(n, t) + vec3(1e-4, 0.0, 0.0));
	vec3 w = cross(t, n);
	float g = max(rope(s), 0.5);
	float x = dot(bv, w);
	float y = dot(bv, n);
	float back = head_s - s;
	o.m = 1.0 - smoothstep(HEAD_LEN * 0.9, HEAD_LEN + NECK_LEN * 0.6, back);
	float round_e = rho / g;
	float diamond = abs(x) / (g * HEAD_WIDE) + abs(y) / (g * HEAD_FLAT);
	o.e = mix(round_e, diamond, o.m);
	o.r = g;
	o.rho = rho;
	o.s = s;
	o.side = x / g;
	o.rise = y / g;
	o.out_dir = bv / max(rho, 1e-3);
	o.along = t;
	return o;
}

float density_at(Here o, float t, out float lump) {
	lump = 0.0;
	if (o.e >= REACH) return 0.0;
	// Past the head's point there is no body.
	if (o.s >= head_s - 1.0) return 0.0;
	vec3 c = vec3((o.s - flow) / ALONG, o.side / ROUND_, o.rise / ROUND_) + seed * 0.37;
	vec2 big = textureLod(noise, c, 0.0).rg;
	float bite = mix(1.0, HEAD_CRISP, o.m);
	float shape = 1.0 - o.e + (big.g - 0.5) * 1.2 * bite;
	lump = (big.g - 0.5) * mix(1.0, HEAD_GRAIN, o.m);
	float keep_mid = 1.0 - smoothstep(MIDDLE.x, MIDDLE.y, t);
	if (keep_mid > 0.0) {
		vec2 mid = textureLod(noise, c * vec3(2.0, 2.7, 2.7) + 0.31, 0.0).rg;
		shape += ((mid.r - 0.55) * 0.6 + (mid.g - 0.5) * 0.4 * smoothstep(0.35, 1.0, o.e)) * keep_mid * bite;
		lump += (mid.r - 0.55) * 0.8 * keep_mid;
		float keep_fine = 1.0 - smoothstep(FINE.x, FINE.y, t);
		if (keep_fine > 0.0) {
			vec2 fine = textureLod(noise, c * vec3(3.0, 7.1, 7.1) + 0.67, 0.0).rg;
			shape += (fine.g - 0.5) * 0.3 * keep_fine * bite;
			lump += (fine.r - 0.55) * 0.3 * keep_fine;
		}
	}
	return smoothstep(0.0, 0.22, shape);
}

void fragment() {
	if (count < 2) discard;
	vec3 eye = CAMERA_POSITION_WORLD;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, 1.0, 1.0);
	vec3 rd = normalize(mat3(INV_VIEW_MATRIX) * (view.xyz / view.w));

	// Which segments the ray passes near, and the stretch of it they cover.
	uvec2 mask = uvec2(0u);
	float t0 = 1e9;
	float t1 = -1e9;
	for (int g = 0; g < GROUPS; g++) {
		vec4 sphere = groups[g];
		if (sphere.w <= 0.0) continue;
		vec3 oc = sphere.xyz - eye;
		float tc = dot(oc, rd);
		if (tc < -sphere.w) continue;
		if (dot(oc, oc) - tc * tc > sphere.w * sphere.w) continue;
		int last = min((g + 1) * GROUP, count - 1);
		for (int i = g * GROUP; i < last; i++) {
			vec3 a = pts[i].xyz;
			vec3 b = pts[i + 1].xyz;
			vec3 ab = b - a;
			vec3 w0 = eye - a;
			float cc = dot(ab, ab);
			float bb = dot(ab, rd);
			float dd = dot(rd, w0);
			float ee = dot(ab, w0);
			float u = clamp((ee - bb * dd) / max(cc - bb * bb, 1e-3), 0.0, 1.0);
			vec3 q = a + ab * u - eye;
			float tq = dot(q, rd);
			// All the head or none: a fat segment read without the thin ones
				// ahead of it would swell out round its end.
				float r = pts[i + 1].w > head_s - HEAD_LEN - NECK_LEN ? girth.x * REACH_OUT * HEAD_WIDE : max(rope(pts[i].w), rope(pts[i + 1].w)) * REACH_OUT;
			if (dot(q, q) - tq * tq > r * r) continue;
			mask |= 1u << uint(i);
			float ta = dot(a - eye, rd);
			float tb = dot(b - eye, rd);
			t0 = min(t0, min(ta, tb) - r);
			t1 = max(t1, max(ta, tb) + r);
		}
	}
	if (mask.x == 0u && mask.y == 0u) discard;
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	if (depth > 1e-6) {
		vec4 up = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
		t1 = min(t1, length(up.xyz / up.w));
	}
	t0 = max(t0, 0.0);
	if (t1 <= t0) discard;

	vec3 sun = normalize(zs_sun_direction + vec3(0.0, 1e-4, 0.0));
	vec2 sun_flat = normalize(sun.xz + 1e-4);
	vec3 sun_hue;
	vec3 c_sun;
	vec3 c_shade;
	float lining;
	zs_cumulus_palette(rd, sun, sun_hue, c_sun, c_shade, lining);
	float day = mix(1.0, LIFT, zs_daylight);
	float high = smoothstep(0.02, 0.4, sun.y);
	float toward_sun = max(dot(rd, sun), 0.0);

	float t = t0;
	vec3 acc = vec3(0.0);
	float kept = 1.0;
	float met = 0.0;
	float met_w = 0.0;
	for (int i = 0; i < STEPS; i++) {
		if (t >= t1 || kept < 0.02) break;
		vec3 p = eye + rd * t;
		Here o = here_at(p, mask);
		if (o.e >= REACH) {
			// Over the head's taper the body swells faster than a ray nears it.
			t += clamp((o.rho - REACH * HEAD_WIDE * o.r) * 0.45, 2.0 + t * 0.003, 60.0);
			continue;
		}
		float thin_way = o.r;
		float ds = min(max(thin_way * 0.2, 2.5 + t * 0.002), t1 - t + 0.01);
		float lump;
		float d = density_at(o, t, lump);
		if (d > 0.004) {
			float veil = smoothstep(NEAR.x, NEAR.y, t);
			float sigma = OPTICAL / max(thin_way * 2.0, 8.0);
			float alpha = 1.0 - exp(-d * sigma * ds * veil);
			// A cone's face, leaning forward in the head.
			vec3 ng = o.out_dir * min(o.e, 1.0) + o.along * o.m * 0.55;
			float deep = clamp(length(ng), 0.0, 1.0);
			ng = normalize(ng + vec3(0.0, 1e-3, 0.0));
			float toward = dot(ng, sun) * deep + lump * 1.1;
			float sun_light = smoothstep(-0.55, 0.7, toward);
			if (t < 2600.0) {
				float reach_sun = max(thin_way * 0.8, 10.0);
				Here s = here_at(p + sun * reach_sun, mask);
				float s_lump;
				float over = density_at(s, t, s_lump);
				sun_light *= mix(1.0, exp(-over * 1.6), 1.0 - smoothstep(1400.0, 2600.0, t));
			}
			float up_face = ng.y * 0.5 + 0.5;
			float ambient = mix(0.6, 0.85, up_face) * (1.0 + lump * 0.5) * mix(0.3, 1.0, high);
			float under = (1.0 - up_face) * (1.0 - up_face);
			vec3 lit = ambient * c_shade + (sun_light * 1.55 + lining * sun_light) * c_sun + under * 0.22 * c_sun * BOUNCE_TINT;
			if (zs_cloud_under > 0.0) {
				float sun_side = dot(normalize(rd.xz + 1e-4), sun_flat) * 0.5 + 0.5;
				vec3 under_col = mix(c_sun, UNDER_ROSE * max(c_sun.r, max(c_sun.g, c_sun.b)), 0.5);
				lit += under * under * under_col * 1.6 * zs_cloud_under * mix(0.55, 1.0, sun_side);
			}
			lit *= ZS_CUMULUS_LIT_SHARE * day * mix(BODY_SHADE, 1.0, o.m);
			float round_eye = 1.0 - smoothstep(GLOW.x, GLOW.y, t);
			vec3 glow = mix(vec3(0.95, 0.97, 1.0), sun_hue, 0.2) * mix(0.72, 1.0, toward_sun) * mix(1.0, 0.2, zs_night);
			lit = mix(lit, glow, round_eye * 0.8);
			acc += kept * alpha * lit;
			met += kept * alpha * t;
			met_w += kept * alpha;
			kept *= 1.0 - alpha;
		}
		t += ds;
	}
	float a = 1.0 - kept;
	if (a < 0.003) discard;
	vec3 col = acc / a;

	float y0 = max(eye.y - sea_y, 0.0);
	float m = met / max(met_w, 1e-4);
	float y1 = max(eye.y + rd.y * m - sea_y, 0.0);
	float climb = y1 - y0;
	float airmass = abs(climb) > 1.0 ? haze_height * (exp(-y0 / haze_height) - exp(-y1 / haze_height)) / climb : exp(-y0 / haze_height);
	float dist = m * airmass / exp(-min(y0, 150.0) / haze_height);
	float fog = pow(clamp((dist - haze.x) / (haze.y - haze.x), 0.0, 1.0), haze.z) * haze.w * haze_share;
	vec3 behind_it = normalize(vec3(rd.x, max(rd.y, 0.0), rd.z));
	vec3 dome = zsSkyBase(behind_it);
	dome *= 0.98 / max(max(max(dome.r, dome.g), dome.b), 0.98);
	vec3 sky = scene_linear_for_display(dome);
	sky += c_sun * pow(toward_sun, 6.0) * sun_scatter * mix(1.0, 0.45 / 0.18, zs_haze_sun) * mix(1.4, 0.7, high) * zs_celestial_clear;
	ALBEDO = mix(col, sky, fog);
	float front = 1.0;
	vec4 sheet = texelFetch(cloud_shape, min(ivec2(FRAGCOORD.xy), textureSize(cloud_shape, 0) - 1), 0);
	float cloud_a = clamp(sheet.x, 0.0, 1.0);
	if (cloud_a > 0.003 && sheet.y / cloud_a < m) front = 1.0 - cloud_a;
	ALPHA = min(a / 0.97, 1.0) * front;
}
