shader_type spatial;
// The burrower's wake on the game's water (scripts/burrower/wake_sheet.gd): a
// clear ribbon laid over the sea, a lake or a river along the head's track.
// It draws only the wake, on whatever water lies under it: the rings of
// burrower_pond.gdshader, the froth down the track and the bulge's white lip,
// with the same uniforms (burrower.gd `_feed_pond`). One pass over the points
// a pixel: the slope is worked out with the rings.
//
// wake[i] = (x, z, born, strength) in world space; strength 0 is unused.
// head = (x, z, strength, speed), head_way its heading (unit xz).
// UV.x -1..1 across the ribbon, UV.y 0 at the ends of a stretch, 1 along it.
//
// The ground's river water rides a little over its level (its ripples lift
// it), so the plain depth test would hide the ribbon outright: it tests by
// hand against the opaque depth, hidden only by what stands stand_hide m over
// the ribbon (a bank, a tree, the plane).
render_mode blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled;

const int WAKES = 64;
uniform float now = 0.0;
uniform vec4 wake[WAKES];
uniform vec4 head = vec4(0.0);
uniform vec2 head_way = vec2(1.0, 0.0);
uniform float ring_speed = 5.5;
uniform float ring_len = 2.6;
uniform float ring_amp = 0.2;
uniform float ring_decay = 0.75;
uniform float bulge = 0.6;
uniform vec3 tint : source_color = vec3(0.34, 0.42, 0.42);
uniform vec3 murk : source_color = vec3(0.34, 0.36, 0.26);
uniform vec3 foam : source_color = vec3(0.90, 0.93, 0.92);
// How much slope turns into the ribbon showing, and how much of its light.
uniform float slope_show = 1.6;
uniform float slope_light = 2.2;

uniform vec2 stand_hide = vec2(0.45, 0.9);
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest;

varying vec3 v_world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_world.xz;
	float kk = 6.2831853 / ring_len;
	float ring = 0.0;
	float fr = 0.0;
	vec2 slope = vec2(0.0);
	for (int i = 0; i < WAKES; i++) {
		vec4 w = wake[i];
		if (w.w <= 0.0) continue;
		float a = now - w.z;
		if (a <= 0.0 || a > 6.0) continue;
		vec2 to = p - w.xy;
		float d = length(to);
		if (a < 2.0) {
			float s = 1.0 + 1.2 * a;
			fr = max(fr, w.w * exp(-d * d / (s * s)) * (1.0 - a / 2.0));
		}
		float r = ring_speed * a;
		float x = d - r;
		float width = 1.1 + 0.35 * a;
		if (abs(x) > width * 3.0) continue;
		float env = w.w * ring_amp * exp(-x * x / (width * width)) * exp(-ring_decay * a) / sqrt(1.0 + 0.25 * r);
		ring += env * sin(kk * x);
		slope += to / max(d, 0.01) * env * kk * cos(kk * x);
	}
	// The bulge: long along the head's way, a trough behind it.
	vec2 d = p - head.xy;
	vec2 cross_way = vec2(-head_way.y, head_way.x);
	float along = dot(d, head_way);
	float across = dot(d, cross_way);
	float len = 3.0 + head.w * 0.06;
	float m0 = exp(-pow((along - 0.8) / len, 2.0) - pow(across / 2.3, 2.0));
	float t0 = exp(-pow((along + len * 1.4) / (len * 0.9), 2.0) - pow(across / 2.0, 2.0));
	float mound = head.z * (m0 - 0.45 * t0);
	slope -= 2.0 * bulge * head.z * m0 * ((along - 0.8) / (len * len) * head_way + across / (2.3 * 2.3) * cross_way);
	float m = clamp(mound, 0.0, 1.0);
	// Froth breaks into flecks, and crests of the rings whiten near the head.
	float fleck = vnoise(p * 1.7 + vec2(now * 0.3, 0.0)) * 0.6 + vnoise(p * 4.3) * 0.4;
	float white = smoothstep(0.35, 0.75, fr * (0.55 + 0.9 * fleck));
	float lip = exp(-pow((along - len * 0.9) / 1.1, 2.0) - pow(across / 2.6, 2.0)) * head.z;
	white = max(white, smoothstep(0.3, 0.8, lip * (0.6 + 0.8 * fleck)));
	white = max(white, smoothstep(0.45, 0.9, m * (0.5 + 1.0 * fleck)) * 0.8);
	float near = exp(-length(d) / 7.0) * head.z;
	white = max(white, smoothstep(0.1, 0.2, ring) * near * 0.8);
	vec3 n = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float tilt = clamp(length(slope) * slope_show, 0.0, 0.85);
	// Faces of a ring turned to the eye go pale, the others dark.
	vec3 eye = normalize(CAMERA_POSITION_WORLD - v_world);
	float face = clamp(dot(slope, -eye.xz) * slope_light + 0.5, 0.0, 1.0);
	vec3 c = mix(tint * 0.45, tint * 1.5, face);
	c = mix(c, murk, m * 0.85);
	c = mix(c, foam, white);
	ALBEDO = c;
	float edge = (1.0 - smoothstep(0.7, 1.0, abs(UV.x))) * smoothstep(0.0, 0.5, UV.y);
	vec4 scene = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, textureLod(scene_depth, SCREEN_UV, 0.0).x, 1.0);
	scene /= scene.w;
	float scene_y = (INV_VIEW_MATRIX * scene).y;
	float clear = 1.0 - smoothstep(stand_hide.x, stand_hide.y, scene_y - v_world.y);
	ALPHA = clamp(max(max(white, m * 0.6), tilt), 0.0, 1.0) * edge * clear;
	ROUGHNESS = mix(0.2, 0.6, white);
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
