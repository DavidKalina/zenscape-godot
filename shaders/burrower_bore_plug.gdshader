shader_type spatial;
#include "res://shaders/burrower_grit.gdshaderinc"
// A plug of rubble the burrower brought down across a bore (scripts/endless/bore_plug.gd):
// broken rock, flat-faced, as a spur's. COLOR.r 1 is the collar, the crack round the bore
// where it comes down: only its veins draw, from `lit_at`, glowing through the hold,
// dark after. The
// rest is the wall: from `lit_at` + `hold` it drops from `top` (over the crown, local y)
// over `drop` s, every point falling from there to its place, so the wall unrolls down
// like a curtain and lands. Lit as the rock is; a faint fill of its own.
render_mode diffuse_burley, specular_schlick_ggx, ambient_light_disabled, fog_disabled, cull_disabled;

uniform vec3 rock_lo : source_color = vec3(0.12, 0.10, 0.09);
uniform vec3 rock_hi : source_color = vec3(0.44, 0.38, 0.32);
uniform float fill = 0.1;
uniform float now = 0.0;
uniform float hold = 1.1;
uniform float drop = 0.42;
uniform vec3 seam : source_color = vec3(1.0, 0.5, 0.2);
uniform float seam_glow = 5.0;
uniform float cool = 0.9;
instance uniform float lit_at = -1000.0;
instance uniform float top = 0.0;

varying vec3 wpos;
varying float v_collar;
varying float v_heat;
varying float v_lit;

void vertex() {
	v_collar = COLOR.r;
	float t = now - lit_at;
	v_lit = step(0.0, t);
	// The collar glows up through the hold, then cools.
	v_heat = v_collar > 0.5 ? smoothstep(0.0, hold, t) * exp(-max(t - hold - drop, 0.0) / cool) : exp(-max(t - hold - drop, 0.0) / cool);
	if (v_collar < 0.5) {
		float k = clamp((t - hold) / drop, 0.0, 1.0);
		float e = k * k;
		VERTEX.y = top - (top - VERTEX.y) * e;
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float wn = g_noise(wpos * 0.45 + 4.0);
	float vein = 1.0 - smoothstep(0.0, 0.022 + fwidth(wn), abs(wn - 0.5));
	// Only some of the seams: the rest of the rubble is plain rock.
	float some = smoothstep(0.55, 0.7, g_noise(wpos * 0.13 + 9.0));
	if (v_collar > 0.5) {
		if (vein * some < 0.3 || v_lit < 0.5) discard;
	}
	vec3 n = normalize(cross(dFdy(wpos), dFdx(wpos)));
	vec3 to_eye = CAMERA_POSITION_WORLD - wpos;
	if (dot(n, to_eye) < 0.0) n = -n;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float mott = g_noise(wpos * 0.9);
	vec3 rock = mix(rock_lo, rock_hi, 0.35 + 0.5 * mott);
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
	if (v_collar > 0.5) {
		ALBEDO = rock * 0.4;
		EMISSION = seam * seam_glow * v_heat * vein * some;
	} else {
		EMISSION = rock * fill + seam * seam_glow * 0.35 * v_heat * vein * some;
	}
}
