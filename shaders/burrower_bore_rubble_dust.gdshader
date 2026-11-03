shader_type spatial;
// The dust of a spur or plug the surge smashed (scripts/endless/bore_rubble.gd): one mesh of
// quads, faced to the eye here. COLOR: where along the stick (r), round it (g), how far out
// (b), how hard thrown (a). NORMAL: life, size, carry. UV the corner. Unshaded, as the plume's
// dust (burrower_bore_plume.gdshader), dimmed for the bore's dark, hot for a moment.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float now = 0.0;
uniform float lit_at = -1000.0;
uniform vec3 from = vec3(0.0);
uniform vec3 seg = vec3(0.0, 1.0, 0.0);
uniform float girth = 2.0;
uniform vec3 blast = vec3(0.0);
uniform float taper = 0.3;
// Out off the stick (m/s), carried by the blast (share), the air's drag (1/s).
uniform vec2 throw_speed = vec2(2.0, 9.0);
uniform vec2 carry = vec2(0.05, 0.4);
uniform float drag = 1.6;
// A puff's size: a share of the girth at birth, and how much it grows; its life (s).
uniform vec2 size_share = vec2(0.6, 1.3);
uniform float grow = 2.2;
uniform vec2 life = vec2(1.2, 3.2);
uniform float near_fade = 6.0;
uniform float soft = 1.5;
uniform float opacity = 0.45;
uniform vec3 dust : source_color = vec3(0.30, 0.25, 0.20);
uniform vec3 dust_hot : source_color = vec3(0.85, 0.52, 0.30);

varying float v_a;
varying float v_hot;
varying float v_seed;
varying vec2 v_uv;
varying float v_up;

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
	float t = now - lit_at;
	float u = COLOR.r;
	vec3 axis = normalize(seg + vec3(0.0, 1e-5, 0.0));
	vec3 s1 = normalize(cross(axis, abs(axis.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	vec3 s2 = cross(axis, s1);
	float ang = COLOR.g * 6.2831853;
	vec3 rad = s1 * cos(ang) + s2 * sin(ang);
	float r = girth * mix(1.0, taper, u);
	vec3 start = from + seg * u + rad * r * sqrt(COLOR.b);
	float born = NORMAL.z * 0.12;
	float age = t - born;
	float lasts = mix(life.x, life.y, NORMAL.x);
	float a = max(age, 0.0);
	vec3 v = rad * mix(throw_speed.x, throw_speed.y, COLOR.a) + blast * mix(carry.x, carry.y, NORMAL.z);
	vec3 w = start + v * (1.0 - exp(-a * drag)) / drag + vec3(0.0, 0.6 * a, 0.0);
	float k = a / lasts;
	float size = girth * mix(size_share.x, size_share.y, NORMAL.y) * mix(1.0, 0.6, u) * (1.0 + grow * sqrt(k));
	vec4 vw = VIEW_MATRIX * vec4(w, 1.0);
	float alpha = opacity * smoothstep(0.0, 0.04, k) * (1.0 - k) * (1.0 - k);
	alpha *= clamp((-vw.z - size * 0.3) / near_fade, 0.0, 1.0);
	if (age < 0.0 || k > 1.0) {
		VERTEX = vec3(0.0, 0.0, 1.0);
		alpha = 0.0;
	} else {
		VERTEX = vw.xyz + vec3(UV * size, 0.0);
	}
	float spin = (NORMAL.y + NORMAL.z * a * 0.6) * 6.0;
	NORMAL = vec3(0.0, 0.0, 1.0);
	v_a = alpha;
	float o = 1.0 - clamp(a / 0.5, 0.0, 1.0);
	v_hot = o * o;
	v_seed = (COLOR.g + COLOR.b * 3.0) * 40.0;
	v_up = UV.y;
	v_uv = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin))) * UV;
}

void fragment() {
	float ang = atan(v_uv.y, v_uv.x);
	float edge = 1.0 + 0.22 * sin(3.0 * ang + v_seed * 5.0) + 0.14 * sin(5.0 * ang + v_seed * 9.0);
	float d = dot(v_uv, v_uv) / (edge * edge);
	float a = (1.0 - smoothstep(0.1, 1.0, d)) * v_a;
	a *= 1.0 - smoothstep(0.62, 0.98, length(v_uv));
	float n = vnoise(v_uv * 2.6 + vec2(v_seed * 3.1, v_seed * 7.3)) * 0.7 + vnoise(v_uv * 5.5 + v_seed) * 0.3;
	a *= smoothstep(0.15, 0.7, n) * 1.5;
	float z = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 wp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z, 1.0);
	a *= clamp((VERTEX.z - wp.z / wp.w) / soft, 0.0, 1.0);
	float top = 0.7 + 0.45 * (v_up * 0.5 + 0.5) + 0.3 * (n - 0.5);
	ALBEDO = mix(dust * top, dust_hot, v_hot);
	if (a < 0.003) discard;
	ALPHA = clamp(a, 0.0, 1.0);
}
