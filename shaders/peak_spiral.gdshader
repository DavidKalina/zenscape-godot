shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_front, shadows_disabled, fog_disabled;
// One tower's ribbon of cloud (scripts/endless/peak_spirals.gd): a box round
// the axis, its back faces drawn so the eye may be inside, and from each
// pixel a short march through a density that is a formula, not a slab. The
// ribbon is one helix round the axis, level rings on a leaning axis (a shear,
// so a straight ray stays straight). A point's nearest coil comes from its
// height and bearing alone, so empty air costs no texture reads: the march
// leaps it. Stopped at the land's depth, thinned near the eye: no clip edge,
// no collision, a veil when flown through. In the clouds' own light
// (shaders/cumulus_light.gdshaderinc) and the land's haze, as the cloud sheet
// lays it (shaders/endless_cloud_composite.gdshader).
#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/cumulus_light.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"

global uniform float zs_cloud_under;

uniform vec3 base = vec3(0.0);
uniform vec3 tip = vec3(0.0, 400.0, 0.0);
uniform float radius = 150.0;
// Turns from the root to the tip, the way round (+1 or -1).
uniform float turns = 4.0;
uniform float hand = 1.0;
// The turn so far (radians), and how far the cloud has run along the ribbon.
uniform float spin = 0.0;
uniform float flow = 0.0;
uniform float seed = 0.0;
// 1 idle; under 1 the tip is drawn in down the ribbon (PeakSpirals `rouse`).
uniform float tip_left = 1.0;
uniform sampler3D noise : repeat_enable, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
// The cloud sheet's coverage and distance: field cloud nearer than the ribbon
// stands in front of it (the sheet draws first, whatever the distance).
uniform sampler2D cloud_shape : hint_default_black, filter_nearest, repeat_disable;
// The land's haze as the cloud sheet has it, and this cloud's share of it.
uniform vec4 haze = vec4(120.0, 7600.0, 0.75, 0.8);
uniform float haze_height = 650.0;
uniform float sea_y = -40.0;
uniform float sun_scatter = 0.18;
uniform float haze_share = 0.45;

const float TAU_ = 6.28318530718;
// The ribbon's radius at the tip as a share of the root's.
const float TAPER = 0.42;
// How much tighter the coils get: 0 even, 1 a tip pitch a third of the root's.
const float TIGHTEN = 0.45;
// The ribbon's half width and half height as shares of the radius and pitch.
const float WIDE = 0.3;
const float THICK = 0.24;
// Density reaches past the ellipse by this much at most (the noise's bite).
const float REACH = 1.7;
// How thick a crossing of the middle is (optical depth).
const float OPTICAL = 5.0;
// Cloud thinned to nothing at the eye, whole by NEAR.y m: the veil flown through.
const vec2 NEAR = vec2(10.0, 170.0);
// The white of being in it, gone by GLOW.y m from the eye.
const vec2 GLOW = vec2(50.0, 300.0);
// The march's steps.
const int STEPS = 64;
// Past these distances (m) the fine and the middle noise drop out.
const vec2 FINE = vec2(500.0, 1100.0);
const vec2 MIDDLE = vec2(1500.0, 3500.0);
const float LIFT = 1.25;
const vec3 BOUNCE_TINT = vec3(0.78, 0.9, 0.82);
const vec3 UNDER_ROSE = vec3(1.0, 0.42, 0.52);

struct Here {
	float e;       // 0 on the ribbon's centre line, 1 at its ellipse.
	float dr;      // Out from the centre line (m).
	float dh;      // Up from the centre line (m).
	float a;       // Half width (m).
	float b;       // Half height (m).
	float along;   // Turns along the ribbon from its root.
	float fade;    // 0 off either end of the ribbon, 1 along its length.
	vec2 out_dir;  // Outward from the axis, level.
	vec2 q;        // From the axis, level (m).
};

Here here_at(vec3 p) {
	Here o;
	float rise = tip.y - base.y;
	float h = (p.y - base.y) / rise;
	vec2 q = p.xz - mix(base.xz, tip.xz, h);
	float r = length(q);
	float hc = clamp(h, 0.0, 1.0);
	// Turns climbed at this height, and turns per unit of height.
	float s = turns * (h + TIGHTEN * h * h) / (1.0 + TIGHTEN);
	float rate = turns * (1.0 + 2.0 * TIGHTEN * hc) / (1.0 + TIGHTEN);
	float pitch = rise / rate;
	float turned = hand * (atan(q.y, q.x) + spin) / TAU_;
	float u = s - turned;
	float du = u - round(u);
	float along = s - du;
	float share = clamp(along / turns, 0.0, 1.0);
	// Both ends dissolve rather than come to a point.
	float grown = mix(0.5, 1.0, smoothstep(0.0, 0.13, along / turns));
	float thin = grown * pow(1.0 - share, 0.55);
	o.fade = smoothstep(0.0, 0.16, along / turns) * (1.0 - smoothstep(0.86 * tip_left, 0.985 * tip_left, along / turns));
	// The line wanders and swells a little so it never reads as machined.
	float w1 = sin(along * 2.1 + seed * 3.0);
	// Two whole cycles over the flow's period (PeakSpirals.FLOW_WRAP).
	float w2 = sin(along * 4.7 + seed * 5.0 + flow * 0.00194828);
	float w3 = sin(along * 1.3 + seed * 1.7);
	float swell = 1.0 + 0.2 * w3 + 0.16 * sin(along * 7.3 + seed * 4.0) + 0.1 * sin(along * 13.1 + seed);
	float centre = radius * mix(1.0, TAPER, pow(hc, 0.85)) * (1.0 + 0.09 * w1 + 0.05 * w2);
	o.a = max(WIDE * radius * mix(1.0, 0.45, hc) * thin * swell, 0.5);
	o.b = max(THICK * pitch * thin * swell, 0.5);
	o.dr = r - centre;
	o.dh = (du + 0.07 * w1 * thin) * pitch;
	o.e = length(vec2(o.dr / o.a, o.dh / o.b));
	o.along = along;
	o.out_dir = q / max(r, 1e-3);
	o.q = q;
	return o;
}

// The cloud's density at a place on the ribbon, 0..1; t the distance from the
// eye, `lump` how far this bit of it bulges, for the light.
float density_at(Here o, float t, out float lump) {
	lump = 0.0;
	if (o.e >= REACH || o.fade <= 0.0) return 0.0;
	float metres = o.along * TAU_ * radius * 0.7 - flow;
	vec3 c = vec3(metres / 430.0, o.dr / 200.0, o.dh / 170.0) + seed * 0.37;
	vec2 big = textureLod(noise, c, 0.0).rg;
	// Tight on the inside, torn on the outside, where the wind drags it.
	float outer = smoothstep(-1.0, 1.0, o.dr / o.a);
	float shape = 1.0 - o.e + (big.g - 0.5) * mix(1.0, 1.7, outer);
	lump = big.g - 0.5;
	float keep_mid = 1.0 - smoothstep(MIDDLE.x, MIDDLE.y, t);
	if (keep_mid > 0.0) {
		// Whole multiples along the ribbon, so the flow's wrap never shows.
		vec2 mid = textureLod(noise, c * vec3(2.0, 2.7, 2.7) + 0.31, 0.0).rg;
		shape += ((mid.r - 0.55) * 0.75 + (mid.g - 0.5) * 0.5 * smoothstep(0.35, 1.0, o.e)) * keep_mid;
		lump += (mid.r - 0.55) * 0.8 * keep_mid;
		float keep_fine = 1.0 - smoothstep(FINE.x, FINE.y, t);
		if (keep_fine > 0.0) {
			vec2 fine = textureLod(noise, c * vec3(5.0, 7.1, 7.1) + 0.67, 0.0).rg;
			shape += (fine.g - 0.5) * 0.38 * keep_fine;
			lump += (fine.r - 0.55) * 0.3 * keep_fine;
		}
	}
	return smoothstep(0.0, 0.34, shape) * o.fade;
}

void fragment() {
	vec3 eye = CAMERA_POSITION_WORLD;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, 1.0, 1.0);
	vec3 rd = normalize(mat3(INV_VIEW_MATRIX) * (view.xyz / view.w));

	// The ray into the leaning cylinder that holds the ribbon.
	float rise = tip.y - base.y;
	vec2 lean = (tip.xz - base.xz) / rise;
	float reach = radius * (1.0 + WIDE * REACH * 1.3 + 0.16);
	vec2 o2 = eye.xz - base.xz - lean * (eye.y - base.y);
	vec2 d2 = rd.xz - lean * rd.y;
	float qa = max(dot(d2, d2), 1e-6);
	float qb = dot(o2, d2);
	float qc = dot(o2, o2) - reach * reach;
	float disc = qb * qb - qa * qc;
	if (disc <= 0.0) discard;
	float sq = sqrt(disc);
	float t0 = (-qb - sq) / qa;
	float t1 = (-qb + sq) / qa;
	float pad = 30.0;
	if (abs(rd.y) > 1e-5) {
		float ta = (base.y - pad - eye.y) / rd.y;
		float tb = (tip.y + pad - eye.y) / rd.y;
		t0 = max(t0, min(ta, tb));
		t1 = min(t1, max(ta, tb));
	}
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
	float low_sun = 1.0 - smoothstep(0.55, 0.95, sun.y);
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
		Here o = here_at(p);
		if (o.e >= REACH) {
			// Clear air: a leap to the ribbon's reach, never past it.
			t += clamp((o.e - REACH) * min(o.a, o.b) * 0.7, 2.0 + t * 0.003, 90.0);
			continue;
		}
		// The last step stops at the land, so what lies in front of it never
		// shows the steps as contour lines.
		float ds = min(max(o.b * 0.16, 2.5 + t * 0.002), t1 - t + 0.01);
		float lump;
		float d = density_at(o, t, lump);
		if (d > 0.004) {
			float veil = smoothstep(NEAR.x, NEAR.y, t);
			float sigma = OPTICAL / max(o.b * 2.0, 8.0);
			float alpha = 1.0 - exp(-d * sigma * ds * veil);
			// The ribbon's round: its own surface toward the sun and the sky,
			// broken by the lumps so it never reads as a tube.
			vec3 ng = vec3(o.out_dir.x * o.dr / o.a, o.dh / o.b, o.out_dir.y * o.dr / o.a);
			float deep = clamp(length(ng), 0.0, 1.0);
			ng = normalize(ng + vec3(0.0, 1e-3, 0.0));
			float toward = dot(ng, sun) * deep + lump * 1.1;
			float sun_light = smoothstep(-0.55, 0.7, toward);
			// A step toward the sun: is more of the ribbon in the way?
			if (t < 2600.0) {
				float reach_sun = max(o.b * 0.8, 14.0);
				Here s = here_at(p + sun * reach_sun);
				float s_lump;
				float over = density_at(s, t, s_lump);
				sun_light *= mix(1.0, exp(-over * 1.6), 1.0 - smoothstep(1400.0, 2600.0, t));
			}
			// The far side of the coil, behind the tower from the sun.
			float behind = -dot(o.q, sun_flat);
			float aside = abs(o.q.x * sun_flat.y - o.q.y * sun_flat.x);
			float hid = smoothstep(0.0, radius * 0.25, behind) * (1.0 - smoothstep(radius * 0.3, radius * 0.75, aside)) * low_sun;
			sun_light *= 1.0 - 0.72 * hid;
			float up_face = ng.y * 0.5 + 0.5;
			// The sky's share falls with the sun, so a low sun's colour shows.
			float ambient = mix(0.6, 0.85, up_face) * (1.0 + lump * 0.5) * mix(0.3, 1.0, high);
			float under = (1.0 - up_face) * (1.0 - up_face);
			vec3 lit = ambient * c_shade + (sun_light * 1.55 + lining * sun_light) * c_sun + under * 0.22 * c_sun * BOUNCE_TINT;
			if (zs_cloud_under > 0.0) {
				float sun_side = dot(normalize(rd.xz + 1e-4), sun_flat) * 0.5 + 0.5;
				vec3 under_col = mix(c_sun, UNDER_ROSE * max(c_sun.r, max(c_sun.g, c_sun.b)), 0.5);
				lit += under * under * under_col * 1.6 * zs_cloud_under * mix(0.55, 1.0, sun_side);
			}
			lit *= ZS_CUMULUS_LIT_SHARE * day;
			// Flown through: the white of being in cloud, warmer toward the sun.
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

	// The haze between, the cloud sheet's: by distance, thinner the higher.
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
