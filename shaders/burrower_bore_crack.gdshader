shader_type spatial;
#include "res://shaders/burrower_grit.gdshaderinc"
// The cracked blister before a spur (scripts/endless/bore_tell.gd): a patch on the bore's
// rock. It rises where the burrower has passed, cracks run out from its middle and glow,
// and when the spur snaps through (`hold` s on) it sags and cools, and stays, cold, round
// the spur's root. UV is the patch (-1..1 each way), UV2 (whole: 0 where a shaft has no
// rock, a random 0..1 for the rubble), NORMAL the way off the rock. Lit as the rock is.
render_mode diffuse_burley, specular_schlick_ggx, ambient_light_disabled, fog_disabled, cull_disabled;

uniform float now = 0.0;
// From him passing to the snap (s), the blister's rise (s), the cracks' run to their ends
// (s), how long the glow takes to cool after the snap (s).
uniform float hold = 0.8;
uniform float pop = 0.2;
uniform float run = 0.3;
uniform float cool = 2.5;
// What stands after the snap (a share), the tremble in the hold (a share), how far under
// the rock the patch's edge lies (m).
uniform float stays = 0.6;
uniform float tremble = 0.09;
uniform float under = 0.3;
uniform vec3 torn_lo : source_color = vec3(0.12, 0.10, 0.09);
uniform vec3 torn_hi : source_color = vec3(0.3, 0.26, 0.22);
uniform vec3 seam : source_color = vec3(1.0, 0.5, 0.2);
// The cracks' glow, the wash of it under the blister's skin, the rock's faint fill.
uniform float seam_glow = 12.0;
uniform float wash = 1.1;
uniform float fill = 0.06;
// How wide a crack is at its root (m).
uniform float crack_m = 0.55;

instance uniform float lit_at = 0.0;
instance uniform float tall = 3.0;
instance uniform float wide = 8.0;
instance uniform float seed = 0.0;

varying float v_age;
varying float v_whole;
varying float v_wide;
varying float v_seed;
varying vec2 v_uv;
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

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

void vertex() {
	float age = now - lit_at;
	v_age = age;
	v_uv = UV;
	v_whole = UV2.x;
	v_wide = wide;
	v_seed = seed;
	float b = max(1.0 - dot(UV, UV), 0.0);
	float up = smoothstep(0.0, pop, age) * mix(1.0, stays, smoothstep(hold, hold + 0.25, age));
	float shake = age < hold ? 1.0 + tremble * sin(now * 47.0 + UV2.y * 40.0) : 1.0;
	float lift = tall * b * up * shake * (0.84 + 0.32 * UV2.y);
	VERTEX += NORMAL * (lift - under);
	wpos = VERTEX;
}

// The crack of `n` arms round the middle nearest `p`: 1 on it, 0 off it. `from`: it starts
// this far out; `grown`: how far the cracks have run (0..1); `m`: a UV unit in metres; `px`
// a pixel in metres, under which no crack goes, so it still shows from far off.
float arms(vec2 p, float n, float sd, float from, float grown, float m, float px, float w) {
	float r = length(p);
	float a = atan(p.y, p.x) / TAU + 0.5;
	float k = floor(a * n);
	float c = (k + 0.5 + 0.5 * (hash1(k + sd) - 0.5)) / n;
	float end = mix(0.68, 1.0, hash1(k + sd + 3.3));
	float wob = 0.2 * (vn1(r * 4.0 + k * 7.1 + sd) - 0.5) + 0.07 * (vn1(r * 12.0 + k * 3.7 + sd) - 0.5);
	float d = abs((a - c) * TAU * r + wob * smoothstep(0.0, 0.3, r)) * m;
	float wm = max(w * mix(1.0, 0.3, clamp(r / end, 0.0, 1.0)), px);
	float body = 1.0 - smoothstep(wm * 0.5, wm + px * 0.5, d);
	float len = min(end, grown * 1.1);
	return body * smoothstep(from, from + 0.04, r) * (1.0 - smoothstep(len - 0.06, len, r));
}

// The shattered rock at the blister's middle: 1 on a cell's edge.
float shatter(vec2 p, float px) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = g + hash2(i + g) - f;
			float d = dot(o, o);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	float e = sqrt(d2) - sqrt(d1);
	return 1.0 - smoothstep(0.06, 0.1 + px, e);
}

void fragment() {
	if (v_whole < 0.5 || dot(v_uv, v_uv) > 1.02) discard;
	vec3 n = normalize(cross(dFdy(wpos), dFdx(wpos)));
	vec3 to_eye = CAMERA_POSITION_WORLD - wpos;
	if (dot(n, to_eye) < 0.0) n = -n;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float r = length(v_uv);
	float px = length(fwidth(v_uv)) * v_wide * 0.7;
	float grown = smoothstep(0.0, run, v_age);
	float line = arms(v_uv, 8.0, v_seed, 0.0, grown, v_wide, px, crack_m);
	line = max(line, arms(v_uv * mat2(vec2(0.92, 0.39), vec2(-0.39, 0.92)), 15.0, v_seed + 17.0, 0.34, grown, v_wide, px, crack_m * 0.6));
	line = max(line, shatter(v_uv * 5.0 + v_seed, length(fwidth(v_uv)) * 5.0) * (1.0 - smoothstep(0.2, 0.5, r)) * step(r, grown));
	// How hot: rising through the hold, a jump at the snap, cooling after.
	float flick = 0.85 + 0.15 * sin(now * 37.0) * sin(now * 23.0);
	float heat = v_age < hold ? mix(0.55, 1.0, v_age / hold) * flick : 1.5 * exp(-(v_age - hold) / cool * 2.0);
	float mott = g_noise(wpos * 0.9);
	vec3 rock = mix(torn_lo, torn_hi, (1.0 - r * 0.6) * (0.45 + 0.55 * mott));
	vec3 land = mix(rock, grit_albedo(wpos * 0.7, rock * 1.2, 0.5, 0.0), 0.6);
	ALBEDO = mix(land, vec3(0.012, 0.009, 0.008), line);
	ROUGHNESS = 0.9;
	SPECULAR = 0.35;
	float h = grit_height(wpos * 0.7, 0.0);
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	NORMAL = normalize(abs(det) * NORMAL - 0.03 * sign(det) * (dFdx(h) * r1 + dFdy(h) * r2));
	float skin = exp(-r * 2.4) * grown * (1.0 - smoothstep(0.35, 0.9, r));
	EMISSION = rock * fill + seam * heat * (seam_glow * line + wash * skin);
}
