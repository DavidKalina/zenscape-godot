shader_type spatial;
// The chunks of a spur or plug the surge smashed (scripts/endless/bore_rubble.gd): one mesh of
// lumps, each corner's VERTEX its offset off the lump's middle; this places, spins and sizes
// each. COLOR: where along the stick (r), round it (g), how far out (b), how hard thrown (a).
// UV: size, spin. UV2: carried by the blast, born. Lit as the spur is (no sky, no haze, a faint
// fill of its own), the broken faces hot for a moment.
render_mode diffuse_burley, specular_schlick_ggx, ambient_light_disabled, fog_disabled, cull_disabled, skip_vertex_transform;

uniform float now = 0.0;
uniform float lit_at = -1000.0;
uniform vec3 from = vec3(0.0);
uniform vec3 seg = vec3(0.0, 1.0, 0.0);
uniform float girth = 2.0;
uniform vec3 blast = vec3(0.0);
// The stick's radius at the tip, a share of the root's.
uniform float taper = 0.3;
// Thrown off the stick (m/s, least and most), carried by the blast (share, least and most),
// lifted (m/s), how fast the air takes it (1/s), gravity (m/s²).
uniform vec2 throw_speed = vec2(5.0, 24.0);
uniform vec2 carry = vec2(0.12, 0.85);
uniform float lift = 5.0;
uniform float drag = 1.1;
uniform float gravity = 9.8;
// A chunk's size, a share of the girth (least, most); its life (s).
// The pieces' size over what the girth alone gives (a wide burst of small stone).
uniform float lump = 1.0;
uniform vec2 size_share = vec2(0.06, 0.28);
uniform vec2 life = vec2(1.4, 3.4);
// Closer to the eye than this (m) a chunk goes, so none fills the view; it shrinks over
// near_shrink m before that.
uniform float near_cut = 3.0;
uniform float near_shrink = 8.0;
uniform vec3 rock_lo : source_color = vec3(0.13, 0.11, 0.10);
uniform vec3 rock_hi : source_color = vec3(0.34, 0.29, 0.25);
uniform float fill = 0.12;
uniform vec3 ember : source_color = vec3(1.0, 0.5, 0.2);
uniform float ember_glow = 4.0;
uniform float cool = 0.45;

varying float v_tone;
varying float v_hot;

mat3 turn(vec3 a, float ang) {
	float s = sin(ang);
	float c = cos(ang);
	float o = 1.0 - c;
	return mat3(
		vec3(o * a.x * a.x + c, o * a.x * a.y + a.z * s, o * a.z * a.x - a.y * s),
		vec3(o * a.x * a.y - a.z * s, o * a.y * a.y + c, o * a.y * a.z + a.x * s),
		vec3(o * a.z * a.x + a.y * s, o * a.y * a.z - a.x * s, o * a.z * a.z + c));
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
	vec3 start = from + seg * u + rad * r * sqrt(COLOR.b) * 0.85;
	float born = UV2.y * 0.06;
	float age = t - born;
	float lasts = mix(life.x, life.y, UV.x * 0.5 + UV2.x * 0.5);
	vec3 v = rad * mix(throw_speed.x, throw_speed.y, COLOR.a) + blast * mix(carry.x, carry.y, UV2.x)
		+ vec3(0.0, lift * COLOR.b, 0.0);
	float a = max(age, 0.0);
	vec3 w = start + v * (1.0 - exp(-a * drag)) / drag + vec3(0.0, -0.5 * gravity * a * a, 0.0);
	float size = girth * lump * mix(size_share.x, size_share.y, UV.x * UV.x) * mix(1.0, 0.55, u);
	size *= 1.0 - smoothstep(0.75, 1.0, a / lasts);
	vec3 spin_axis = normalize(vec3(UV.y - 0.5, COLOR.a - 0.5, UV2.x - 0.5) + vec3(0.01, 0.02, 0.0));
	mat3 rot = turn(spin_axis, UV.y * 20.0 + a * mix(2.0, 11.0, UV.y));
	float eye = length((VIEW_MATRIX * vec4(w, 1.0)).xyz);
	size *= smoothstep(near_cut, near_cut + near_shrink, eye - size);
	vec3 lp = rot * VERTEX * size;
	vec4 vw = VIEW_MATRIX * vec4(w + lp, 1.0);
	if (age < 0.0 || age > lasts || size <= 0.001) {
		VERTEX = vec3(0.0, 0.0, 1.0);
	} else {
		VERTEX = vw.xyz;
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(rot * NORMAL, 0.0)).xyz);
	v_tone = COLOR.b * 0.5 + UV.y * 0.5;
	v_hot = exp(-a / cool) * step(0.45, UV2.y);
}

void fragment() {
	vec3 rock = mix(rock_lo, rock_hi, v_tone);
	ALBEDO = rock;
	ROUGHNESS = 0.9;
	SPECULAR = 0.3;
	EMISSION = rock * fill + ember * ember_glow * v_hot;
}
