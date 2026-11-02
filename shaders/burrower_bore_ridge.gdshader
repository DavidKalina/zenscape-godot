shader_type spatial;
#include "res://shaders/burrower_grit.gdshaderinc"
// The burrower's ridge in a bore (scripts/endless/burrower_bore.gd): a strip laid on
// the bore's rock along his line, its rows fixed, each raised by how far he's past it:
// `age`, m behind his head (negative ahead of it). UV.x is across (-1..1), UV.y the
// row's distance along the path, UV2 (whole: 0 where a shaft has no rock, a random
// 0..1 for the row's rubble), NORMAL the way the ridge rises. Lit as the rock is: the
// glows, the mouths, his own glow. No sky fill, no haze.
render_mode diffuse_burley, specular_schlick_ggx, ambient_light_disabled, fog_disabled, cull_disabled;

uniform float head_s = 0.0;
// 1 going up the path, -1 down it.
uniform float way = 1.0;
uniform float now = 0.0;
// 0 standing, 1 sunk back into the rock (the chase over).
uniform float sink = 0.0;
// The bow's lead (m), the heave at his head (m), what stands behind him (m), how soon
// it falls to that (m), and how far under the rock the strip's edge lies.
uniform float bow = 18.0;
uniform float heave = 2.6;
uniform float stands = 1.3;
uniform float fall = 14.0;
uniform float under = 0.35;
// The rubble: a share of the height, more at the head. The head's churn (share, rad/s).
uniform float rubble = 0.55;
uniform float churn = 0.22;
uniform float churn_rate = 14.0;
uniform vec3 torn_lo : source_color = vec3(0.12, 0.10, 0.09);
uniform vec3 torn_hi : source_color = vec3(0.42, 0.36, 0.31);
uniform vec3 seam : source_color = vec3(1.0, 0.5, 0.2);
// The seam's glow (linear, times `seam`), how far back from his head it lasts (m), and
// the torn rock's own faint fill so it reads in the dark between the glows.
uniform float seam_glow = 3.5;
uniform float seam_m = 45.0;
uniform float fill = 0.06;

varying float v_age;
varying float v_u;
varying float v_s;
varying float v_whole;
varying vec3 wpos;

float hash1(float x) {
	return fract(sin(x * 91.7) * 43758.5453);
}

float vn1(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash1(i), hash1(i + 1.0), f);
}

void vertex() {
	float age = (head_s - UV.y) * way;
	float u = UV.x;
	v_age = age;
	v_u = u;
	v_s = UV.y;
	v_whole = UV2.x;
	float r;
	if (age < 0.0) {
		float s = smoothstep(-bow, 0.0, age);
		r = s * s;
	} else {
		r = mix(stands / heave, 1.0, exp(-age / fall));
	}
	float hk = age < 0.0 ? smoothstep(-bow, 0.0, age) : exp(-age / fall);
	float ch = 1.0 + churn * hk * sin(now * churn_rate + UV.y * 0.9);
	float b = max(1.0 - u * u, 0.0);
	// Slabs along the run rather than an even worm.
	float slab = 0.72 + 0.56 * vn1(UV.y * 0.17 + 3.0);
	float lift = heave * r * ch * slab * b * (1.0 + rubble * (UV2.y - 0.5) * (0.6 + hk));
	VERTEX += NORMAL * (lift * UV2.x * (1.0 - sink) - under);
	wpos = VERTEX;
}

void fragment() {
	if (v_age < -bow || v_whole < 0.5) discard;
	// Facets: the rubble reads as broken rock, not a smooth bank.
	vec3 n = normalize(cross(dFdy(wpos), dFdx(wpos)));
	vec3 to_eye = CAMERA_POSITION_WORLD - wpos;
	if (dot(n, to_eye) < 0.0) n = -n;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float mott = vn1(wpos.x * 1.7 + wpos.y * 2.3 + wpos.z * 1.1);
	float crest = 1.0 - smoothstep(0.1, 0.62, abs(v_u));
	vec3 rock = mix(torn_lo, torn_hi, crest * (0.45 + 0.55 * mott));
	// Broken rock's crumbs and their relief, so it holds up beside the bore's own.
	ALBEDO = mix(rock, grit_albedo(wpos * 0.7, rock * 1.2, 0.5, 0.0), 0.6);
	ROUGHNESS = 0.9;
	SPECULAR = 0.35;
	float h = grit_height(wpos * 0.7, 0.0);
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	NORMAL = normalize(abs(det) * NORMAL - 0.03 * sign(det) * (dFdx(h) * r1 + dFdy(h) * r2));
	// The seam along the crest, hot near his head and cooling behind him.
	float rag = 0.09 * (vn1(v_s * 0.8 + 7.0) - 0.5);
	float line = 1.0 - smoothstep(0.02, 0.11 + rag * 0.5, abs(v_u + rag));
	float hot = exp(-max(v_age, 0.0) / seam_m) * smoothstep(-bow, 0.0, v_age) * (1.0 - sink);
	EMISSION = rock * fill + seam * seam_glow * line * hot;
}
