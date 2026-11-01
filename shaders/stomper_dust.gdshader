shader_type spatial;
// The stomper's dust (scripts/endless/stomper_fall.gd): one MultiMesh, written
// once at a landing and moved from then on by `now` alone. Per instance:
//   the transform's origin  where the puff starts
//   its first column        the way it is thrown (m/s, at the start)
//   its second column's x   the seconds it spends that way in
//   CUSTOM = (born, life s, size m, seed)
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform float now = 0.0;
uniform vec3 top = vec3(0.74, 0.66, 0.52);
uniform vec3 foot = vec3(0.42, 0.35, 0.27);
uniform float thick = 0.62;
// How many times its size a puff ends at, and how soft it lies on the ground (m).
uniform float grow = 2.6;
uniform float soft = 26.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying float v_k;
varying float v_seed;
varying vec2 v_uv;
// The view depth: VERTEX here is the raw quad under a transform that holds data.
varying float v_depth;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	float age = now - INSTANCE_CUSTOM.x;
	float k = age / max(INSTANCE_CUSTOM.y, 0.01);
	v_k = k;
	v_seed = INSTANCE_CUSTOM.w * 256.0;
	v_uv = UV;
	if (k < 0.0 || k >= 1.0) {
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);
	} else {
		float tau = MODEL_MATRIX[1].x;
		vec3 way = MODEL_MATRIX[0].xyz * tau * (1.0 - exp(-age / tau));
		vec3 c = MODEL_MATRIX[3].xyz + way;
		float s = INSTANCE_CUSTOM.z * mix(1.0, grow, sqrt(k));
		vec3 w = c + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * s;
		vec4 view = VIEW_MATRIX * vec4(w, 1.0);
		v_depth = -view.z;
		POSITION = PROJECTION_MATRIX * view;
	}
}

void fragment() {
	vec2 d = v_uv * 2.0 - 1.0;
	float ang = atan(d.y, d.x);
	float edge = 1.0 + 0.2 * sin(3.0 * ang + v_seed * 5.0) + 0.12 * sin(5.0 * ang + v_seed * 9.0);
	float r = dot(d, d) / (edge * edge);
	float n = vnoise(d * 2.2 + vec2(v_seed * 3.1, v_seed * 7.3)) * 0.65 + vnoise(d * 5.0 + v_seed) * 0.35;
	float a = (1.0 - smoothstep(0.15, 1.0, r)) * smoothstep(0.18, 0.7, n) * 1.5;
	a *= 1.0 - smoothstep(0.72, 1.0, max(abs(d.x), abs(d.y)));
	a *= smoothstep(0.0, 0.06, v_k) * pow(1.0 - v_k, 1.6) * thick;
	float z = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 wp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z, 1.0);
	float behind = -wp.z / wp.w - v_depth;
	a *= clamp(behind / soft, 0.0, 1.0);
	ALBEDO = mix(foot, top, clamp(1.0 - v_uv.y + (n - 0.5) * 0.6, 0.0, 1.0));
	ALPHA = clamp(a, 0.0, 1.0);
}
