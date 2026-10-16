shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_front, shadows_disabled, fog_disabled;
// A light shaft through a torn roof (scripts/hall_shafts.gd, docs/scenic/
// hall-shafts.md), as a fake volume. The mesh is each beam's closed prism
// (the roof opening's four corners at the roof and the same four sheared
// down the scene's key light by the vertex stage, `zs_key_direction`, so the
// day clock re-aims every beam with no CPU work). Only the prism's back
// faces are drawn: each such pixel integrates the beam's light along the
// whole view ray through the box (entry to exit, cut short by whatever
// stands in the beam, by the scene's depth) in a few steps. The density
// falls away smoothly toward the beam's sides, so the beam has no wall to
// show: it thins to nothing at its edge from any angle, and from inside it
// is simply air. Noise streaks scroll down it; it fades up into the roof and
// out into the dark below; it warms and brightens looking into the sun.
#include "res://shaders/reference_globals.gdshaderinc"

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform float roof_y = 11.4;
uniform float floor_y = 0.0;
uniform float max_len = 46.0;
uniform float gain = 1.0;
// How far in from a side, as a part of the beam's width, its density takes to reach full.
uniform float edge_soft = 0.32;
// The most of a ray (m) a beam lights, from where it enters: a ray running
// along a beam's side would otherwise add up its whole length and show the
// side as a line.
uniform float path_cap = 11.0;
// Light picked up a metre of beam, before the squash to 1.
uniform float per_metre = 0.11;

varying vec3 v_pm;       // this point, model space, sheared
varying vec3 v_cam;      // the camera, model space
varying vec2 v_k;        // model-space xz drift of the light a metre of drop
varying vec4 v_box;      // the opening: x0, z0, x1, z1
varying float v_h;       // the beam's vertical drop (m)
varying float v_rand;
varying float v_live;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// The key light as the shaders see it: how much there is of it, 0..1.
float light_strength() {
	vec3 k = zs_key_irradiance;
	float lum = (k.x + k.y + k.z) / 3.0;
	return clamp(lum / 2.4, 0.0, 1.0) * clamp(zs_celestial_clear, 0.0, 1.0);
}

void vertex() {
	vec3 k = zs_key_direction;
	float kl = length(k);
	vec3 way = kl > 0.5 ? -k / kl : vec3(0.0, -1.0, 0.0);
	float elev = -way.y;
	float len = min((roof_y - floor_y) / max(elev, 0.12), max_len);
	vec3 wm = inverse(mat3(MODEL_MATRIX)) * way;
	v_k = wm.xz / max(-wm.y, 0.05);
	v_h = len * -wm.y;
	v_rand = COLOR.r;
	v_box = vec4(UV, UV2);
	v_live = kl > 0.5 ? smoothstep(0.12, 0.4, elev) : 0.0;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * (way * len * COLOR.g);
	v_pm = VERTEX;
	v_cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

void fragment() {
	vec3 rd = normalize(v_pm - v_cam);
	// The ray in the beam's own (unsheared) frame: x, z across, y the drop.
	float h0 = roof_y - v_cam.y;
	vec3 o = vec3(v_cam.x - v_k.x * h0, h0, v_cam.z - v_k.y * h0);
	vec3 d = vec3(rd.x + v_k.x * rd.y, -rd.y, rd.z + v_k.y * rd.y);
	vec3 lo = vec3(v_box.x, 0.0, v_box.y);
	vec3 hi = vec3(v_box.z, v_h, v_box.w);
	vec3 ds_safe = mix(d, vec3(1e-5), step(abs(d), vec3(1e-5)));
	vec3 inv = 1.0 / ds_safe;
	vec3 ta = (lo - o) * inv;
	vec3 tb = (hi - o) * inv;
	vec3 tmin = min(ta, tb);
	vec3 tmax = max(ta, tb);
	float t0 = max(max(tmin.x, tmin.y), max(tmin.z, 0.0));
	float t1 = min(min(tmax.x, tmax.y), tmax.z);
	// Cut short where the scene stands in the beam.
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	t1 = min(t1, length(view.xyz / view.w));
	t1 = min(t1, t0 + path_cap);
	float span = t1 - t0;
	if (span <= 0.0) discard;
	// A few steps through the box, jittered per pixel so they don't band.
	const int STEPS = 6;
	float jitter = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	float ds = span / float(STEPS);
	float full = max(v_h, 0.1);
	float r = v_rand * 40.0;
	float soft = edge_soft * min(hi.x - lo.x, hi.z - lo.z);
	float sum = 0.0;
	for (int i = 0; i < STEPS; i++) {
		float tt = t0 + ds * (float(i) + jitter);
		vec3 p = o + d * tt;
		// Across the beam: thins smoothly to nothing at its sides.
		float side = min(min(p.x - lo.x, hi.x - p.x), min(p.z - lo.z, hi.z - p.z));
		float across = smoothstep(0.0, soft, side);

		float t = p.y / full;
		float along = smoothstep(0.0, 0.14, t) * (1.0 - smoothstep(0.35, 1.0, t));
		float sn = vnoise(vec2((p.x * 0.8 + p.z * 0.55) + r, p.y * 0.1 - TIME * 0.05));
		float streak = 0.05 + 3.4 * sn * sn * sn;
		float waft = 0.7 + 0.5 * vnoise(vec2(p.x * 0.45 - p.z * 0.3 - r, p.y * 0.5 - TIME * 0.11));
		// Air right round the eye is not lit: a beam is seen at a distance.
		sum += across * along * streak * waft * smoothstep(1.5, 12.0, tt);
	}
	// Looking into the sun the air lights up.
	vec3 world_way = normalize((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz - CAMERA_POSITION_WORLD);
	float into = max(dot(world_way, normalize(zs_key_direction + vec3(0.0, 1e-4, 0.0))), 0.0);
	float boost = 0.6 + 1.5 * pow(into, 3.0);
	vec3 k = zs_key_irradiance;
	float lum = max((k.x + k.y + k.z) / 3.0, 1e-3);
	vec3 tint = mix(k / lum, vec3(1.0, 0.84, 0.58), 0.4);
	float light = 0.5 * (1.0 - exp(-sum * ds * per_metre * 2.6));
	float amount = gain * light_strength() * v_live * light * boost * (0.75 + 0.25 * fract(v_rand * 7.0));
	ALBEDO = tint * amount * 0.7 * 2.4;
}
