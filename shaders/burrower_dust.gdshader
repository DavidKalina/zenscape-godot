shader_type spatial;
// The burrower's dust (scripts/burrower/burrower.gd): soft billboards in a
// MultiMesh, each instance's custom data its colour (rgb) and opacity (a).
// Each puff is ragged and wispy (lobes and value noise seeded per instance),
// so a row of them over the pond doesn't read as round blobs from above.
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
// The pond (x, z, radius, water y): over it a puff fades into the surface,
// which the depth fade can't see (the water writes no depth).
uniform vec4 pond = vec4(0.0, 0.0, -1.0, 0.0);

varying vec4 v_col;
varying float v_seed;
varying vec3 v_world;

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
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 c = MODEL_MATRIX[3].xyz;
	vec3 w = c + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * s;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
	v_col = INSTANCE_CUSTOM;
	v_seed = float(INSTANCE_ID) * 1.618;
	v_world = w;
}

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float ang = atan(d.y, d.x);
	float edge = 1.0 + 0.22 * sin(3.0 * ang + v_seed * 5.0) + 0.14 * sin(5.0 * ang + v_seed * 9.0);
	float r = dot(d, d) / (edge * edge);
	float a = (1.0 - smoothstep(0.1, 1.0, r)) * v_col.a;
	float n = vnoise(d * 2.6 + vec2(v_seed * 3.1, v_seed * 7.3)) * 0.7 + vnoise(d * 5.5 + v_seed) * 0.3;
	a *= smoothstep(0.2, 0.75, n) * 1.5;
	// Soft where it meets the ground (no hard edge cut across the puff).
	float z = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 wp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z, 1.0);
	float behind = -wp.z / wp.w - (-VERTEX.z);
	a *= clamp(behind / 1.2, 0.0, 1.0);
	if (pond.z > 0.0 && distance(v_world.xz, pond.xy) < pond.z) {
		a *= clamp((v_world.y - pond.w) / 0.9, 0.0, 1.0);
	}
	ALBEDO = v_col.rgb;
	ALPHA = clamp(a, 0.0, 1.0);
}
