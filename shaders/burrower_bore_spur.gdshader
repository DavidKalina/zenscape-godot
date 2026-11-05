shader_type spatial;
#include "res://shaders/burrower_grit.gdshaderinc"
// A spur of rock the burrower left in a bore (scripts/endless/bore_spurs.gd): broken
// rock, flat-faced, paler toward its torn tip. VERTEX.y is the way up it, 0 at the bore's
// rock and 1 at the tip. Lit as the rock is: the glows, the mouths, his own glow. No sky
// fill, no haze. A faint fill of its own so it shows in the dark between the glows. Fresh
// out it's hot at the root (`lit_at`, when he passed), cooling as the crack round it does.
// A cracked one (`cracked` 1) is paler, split by seams of his glow that run up it and round
// it and never cool: a parried rock smashes it.
render_mode diffuse_burley, specular_schlick_ggx, ambient_light_disabled, fog_disabled, cull_disabled;

uniform vec3 rock_lo : source_color = vec3(0.13, 0.11, 0.10);
uniform vec3 rock_hi : source_color = vec3(0.46, 0.40, 0.34);
uniform float fill = 0.1;
uniform float now = 0.0;
uniform float hold = 0.8;
uniform vec3 seam : source_color = vec3(1.0, 0.5, 0.2);
uniform float seam_glow = 5.0;
uniform float cool = 1.4;
instance uniform float lit_at = -1000.0;
instance uniform float cracked = 0.0;
uniform vec3 pale : source_color = vec3(0.86, 0.79, 0.68);
uniform vec3 crack_seam : source_color = vec3(1.0, 0.62, 0.22);
uniform float crack_glow = 6.0;
uniform float crack_fill = 0.35;
uniform float crack_width = 0.02;

varying vec3 wpos;
varying float v_up;
varying float v_heat;
varying vec3 v_loc;

void vertex() {
	v_up = VERTEX.y;
	v_loc = VERTEX;
	v_heat = exp(-max(now - lit_at - hold, 0.0) / cool);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(cross(dFdy(wpos), dFdx(wpos)));
	vec3 to_eye = CAMERA_POSITION_WORLD - wpos;
	if (dot(n, to_eye) < 0.0) n = -n;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float mott = g_noise(wpos * 0.9);
	vec3 rock = mix(rock_lo, rock_hi, clamp(v_up, 0.0, 1.0) * 0.6 + 0.4 * mott);
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
	float root = 1.0 - smoothstep(0.02, 0.42, v_up + 0.3 * (g_noise(wpos * 0.45) - 0.5));
	float wn = g_noise(wpos * 0.8 + 4.0);
	float vein = 1.0 - smoothstep(0.0, 0.035 + fwidth(wn), abs(wn - 0.5));
	// A cracked one keeps little of the hot root: its own seams are its glow.
	vec3 glow = seam * seam_glow * v_heat * root * vein * (1.0 - 0.8 * cracked);
	vec3 self_lit = rock * fill;
	if (cracked > 0.5) {
		// Pale, bone-dry stone, split tip to root by jagged seams of his glow, with
		// short branches off them, and one ring round it.
		ALBEDO = mix(ALBEDO, pale * (0.8 + 0.4 * mott), 0.85);
		self_lit = ALBEDO * crack_fill;
		float a = atan(v_loc.z, v_loc.x) / 6.2831853;
		float j = g_noise(wpos * 1.7) - 0.5;
		float p1 = 0.05 * sin(v_up * 23.0) + 0.035 * sin(v_up * 61.0 + 1.3) + 0.03 * j;
		float p2 = 0.05 * sin(v_up * 19.0 + 2.0) + 0.035 * sin(v_up * 67.0) - 0.03 * j;
		// Four seams round it, a quarter turn apart, so one always faces the eye.
		float d1 = abs(fract((a - p1) * 2.0 + 0.5) - 0.5) * 0.5;
		float d2 = abs(fract((a - p2) * 2.0) - 0.5) * 0.5;
		float d = min(d1, d2);
		float up = smoothstep(0.0, 0.06, v_up) * (1.0 - smoothstep(0.9, 0.99, v_up));
		float lines = (1.0 - smoothstep(crack_width, crack_width + fwidth(d) * 1.5, d)) * up;
		// Branches: short diagonal splits off the seams.
		float b = abs(fract((a - p1) * 2.0 + v_up * 3.0) - 0.5);
		float near_seam = 1.0 - smoothstep(0.03, 0.11, d);
		float branch = (1.0 - smoothstep(crack_width * 0.6, crack_width * 0.6 + fwidth(b) * 1.5, b)) * near_seam * up;
		float rd = abs(v_up - 0.5 - 0.04 * sin(a * 18.85 + 0.7) - 0.02 * j);
		float ring = 1.0 - smoothstep(crack_width * 0.7, crack_width * 0.7 + fwidth(rd) * 1.5, rd);
		float c = max(max(lines, branch), ring);
		float pulse = 0.85 + 0.15 * sin(now * 3.0 + v_up * 4.0);
		ALBEDO = mix(ALBEDO, vec3(0.05, 0.03, 0.02), c);
		glow += crack_seam * crack_glow * c * pulse + crack_seam * 0.25 * near_seam * up;
	}
	EMISSION = self_lit + glow;
}
