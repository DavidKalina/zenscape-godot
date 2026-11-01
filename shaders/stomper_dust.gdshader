shader_type spatial;
// The stomper's dust (scripts/endless/stomper_fall.gd): one MultiMesh, written
// once at a landing and moved from then on by `now` alone. Per instance:
//   the transform's origin  where the puff starts
//   its first column        the way it is thrown (m/s, at the start)
//   its second column       x the seconds it spends that way in, y how thick it
//                           is (a share of `thick`), z the share of its life it
//                           takes to come up
//   its third column        x how tall it is, a share of its width
//   CUSTOM = (born, life s, size m, seed)
// Unshaded, so it costs no light loop: each puff is drawn as a lumpy ball that
// takes the sky's own sun and fill (the globals the land and the trees read), so
// it has a sun side and a shade side at any hour and looks like part of the land.
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;

global uniform vec3 zs_sun_direction;
global uniform vec3 zs_cloud_sun;
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;

uniform float now = 0.0;
// What the dust is made of, the land's soil.
uniform vec3 soil = vec3(0.7, 0.62, 0.54);
uniform float thick = 0.62;
// How far the noise tips a puff's ball, and the sun let through against the light.
uniform float lumps = 2.4;
uniform float through = 0.5;
// How much of the sky's fill it takes, and the sun that reaches a puff's shade
// side, carried round through the dust. The sun's colour goes in by its square
// root: dust scatters it and it never turns as orange as a lit stone.
uniform float fill_gain = 0.9;
uniform float scatter = 0.42;
// How many times its size a puff ends at, and how soft it lies on the ground (m).
uniform float grow = 2.6;
uniform float soft = 26.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying float v_k;
varying float v_seed;
varying float v_thick;
varying float v_rise;
varying vec2 v_uv;
varying vec3 v_sun;
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
	v_thick = MODEL_MATRIX[1].y;
	v_rise = MODEL_MATRIX[1].z;
	v_sun = (VIEW_MATRIX * vec4(zs_sun_direction, 0.0)).xyz;
	if (k < 0.0 || k >= 1.0) {
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);
	} else {
		float tau = MODEL_MATRIX[1].x;
		vec3 way = MODEL_MATRIX[0].xyz * tau * (1.0 - exp(-age / tau));
		vec3 c = MODEL_MATRIX[3].xyz + way;
		float s = INSTANCE_CUSTOM.z * mix(1.0, grow, sqrt(k));
		vec3 w = c + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y * MODEL_MATRIX[2].x) * s;
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
	vec2 q = d * 2.2 + vec2(v_seed * 3.1, v_seed * 7.3);
	float n0 = vnoise(q);
	float n = n0 * 0.65 + vnoise(d * 5.0 + v_seed) * 0.35;
	float a = (1.0 - smoothstep(0.15, 1.0, r)) * smoothstep(0.18, 0.7, n) * 1.5;
	a *= 1.0 - smoothstep(0.72, 1.0, max(abs(d.x), abs(d.y)));
	a *= smoothstep(0.0, v_rise, v_k) * pow(1.0 - v_k, 1.6) * thick * v_thick;
	float z = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 wp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z, 1.0);
	float behind = -wp.z / wp.w - v_depth;
	a *= clamp(behind / soft, 0.0, 1.0);
	a = clamp(a, 0.0, 1.0);
	// The ball, tipped by the noise's slope so the lumps take the sun too.
	vec2 slope = vec2(vnoise(q + vec2(0.3, 0.0)), vnoise(q + vec2(0.0, 0.3))) - n0;
	vec2 ball = vec2(d.x, -d.y) - vec2(slope.x, -slope.y) * lumps;
	vec3 nrm = normalize(vec3(ball, sqrt(max(1.0 - min(dot(d, d), 1.0), 0.05))));
	float sunny = smoothstep(-0.3, 0.75, dot(nrm, v_sun));
	// Thin dust against the light glows.
	sunny = max(sunny, through * clamp(-v_sun.z, 0.0, 1.0) * (1.0 - a));
	float up = nrm.y * INV_VIEW_MATRIX[1].y * 0.5 + 0.5;
	vec3 fill = mix(zs_hemi_ground, zs_hemi_sky, up) * zs_hemi_energy;
	ALBEDO = soil * (fill * fill_gain + sqrt(zs_cloud_sun) * mix(scatter, 1.0, sunny));
	ALPHA = a;
}
