shader_type spatial;
// The burrower study's pond (scripts/burrower/burrower_land.gd) and the
// burrower's wake on it (scripts/burrower/burrower.gd): a wake with no boat.
//
//   bulge  a mound of water over the head, a trough behind it, the water
//          over it stirred murky.
//   rings  each wake point (dropped from the head as it goes) sends out a
//          ring that spreads at `ring_speed` and dies away; the rings of a
//          moving head add up to a V behind it.
//   froth  a white streak on the head's track, breaking up as it ages.
//
// wake[i] = (x, z, born, strength) in world space; strength 0 is unused.
// head = (x, z, strength, speed), head_way its heading (unit xz).
render_mode blend_mix, cull_back;

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
uniform vec3 water : source_color = vec3(0.16, 0.27, 0.30);
uniform vec3 murk : source_color = vec3(0.30, 0.33, 0.24);
uniform vec3 foam : source_color = vec3(0.86, 0.90, 0.88);
uniform float clarity = 0.82;

varying vec3 v_world;

// The head's mound: long along its way, a trough behind it.
float mound(vec2 p) {
	vec2 d = p - head.xy;
	float along = dot(d, head_way);
	float across = dot(d, vec2(-head_way.y, head_way.x));
	float len = 3.0 + head.w * 0.06;
	float m = exp(-pow((along - 0.8) / len, 2.0) - pow(across / 2.3, 2.0));
	float t = exp(-pow((along + len * 1.4) / (len * 0.9), 2.0) - pow(across / 2.0, 2.0));
	return head.z * bulge * (m - 0.45 * t);
}

float rings(vec2 p) {
	float h = 0.0;
	float kk = 6.2831853 / ring_len;
	for (int i = 0; i < WAKES; i++) {
		vec4 w = wake[i];
		if (w.w <= 0.0) continue;
		float a = now - w.z;
		if (a <= 0.0 || a > 6.0) continue;
		float r = ring_speed * a;
		float d = distance(p, w.xy);
		float x = d - r;
		float width = 1.1 + 0.35 * a;
		if (abs(x) > width * 3.0) continue;
		float env = exp(-x * x / (width * width)) * exp(-ring_decay * a) / sqrt(1.0 + 0.25 * r);
		h += w.w * ring_amp * env * sin(kk * x);
	}
	return h;
}

// The head's track: froth where the points are young and close.
float froth(vec2 p) {
	float f = 0.0;
	for (int i = 0; i < WAKES; i++) {
		vec4 w = wake[i];
		if (w.w <= 0.0) continue;
		float a = now - w.z;
		if (a <= 0.0 || a > 2.0) continue;
		float s = 1.0 + 1.2 * a;
		float d = distance(p, w.xy);
		f = max(f, w.w * exp(-d * d / (s * s)) * (1.0 - a / 2.0));
	}
	return f;
}

// Still water's own small stir.
float calm(vec2 p) {
	return 0.005 * (sin(dot(p, vec2(1.3, 0.4)) + now * 1.1) + sin(dot(p, vec2(-0.5, 1.7)) - now * 0.9)
		+ 0.7 * sin(dot(p, vec2(2.1, -2.3)) + now * 1.7) + 0.5 * sin(dot(p, vec2(-3.1, -1.2)) - now * 2.1));
}

float height(vec2 p) {
	return mound(p) + rings(p) + calm(p);
}

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
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += mound(w.xz) + rings(w.xz);
	v_world = w;
}

void fragment() {
	vec2 p = v_world.xz;
	float e = 0.2;
	float h0 = height(p);
	float hx = height(p + vec2(e, 0.0));
	float hz = height(p + vec2(0.0, e));
	vec3 n = normalize(vec3(-(hx - h0) / e, 1.0, -(hz - h0) / e));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float m = clamp(mound(p) / max(bulge, 0.01), 0.0, 1.0);
	float fr = froth(p);
	// Froth breaks into flecks, and crests of the rings whiten near the head.
	float fleck = vnoise(p * 1.7 + vec2(now * 0.3, 0.0)) * 0.6 + vnoise(p * 4.3) * 0.4;
	float white = smoothstep(0.35, 0.75, fr * (0.55 + 0.9 * fleck));
	// White water: the mound's front lip breaking, and the young rings' crests
	// near the head.
	vec2 d = p - head.xy;
	float along = dot(d, head_way);
	float across = dot(d, vec2(-head_way.y, head_way.x));
	float len = 3.0 + head.w * 0.06;
	float lip = exp(-pow((along - len * 0.9) / 1.1, 2.0) - pow(across / 2.6, 2.0)) * head.z;
	white = max(white, smoothstep(0.3, 0.8, lip * (0.6 + 0.8 * fleck)));
	// The water boils over the mound, joining the lip to the track.
	white = max(white, smoothstep(0.45, 0.9, m * (0.5 + 1.0 * fleck)) * 0.8);
	float near = exp(-length(d) / 7.0) * head.z;
	white = max(white, smoothstep(0.1, 0.2, rings(p)) * near * 0.8);
	vec3 c = mix(water, murk, m * 0.85);
	c = mix(c, foam, white);
	ALBEDO = c;
	ALPHA = mix(clarity, 1.0, max(white, m * 0.6));
	ROUGHNESS = mix(0.08, 0.6, white);
	METALLIC = 0.2 * (1.0 - white);
}
