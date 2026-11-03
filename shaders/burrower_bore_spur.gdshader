shader_type spatial;
#include "res://shaders/burrower_grit.gdshaderinc"
// A spur of rock the burrower left in a bore (scripts/endless/bore_spurs.gd): broken
// rock, flat-faced, paler toward its torn tip. VERTEX.y is the way up it, 0 at the bore's
// rock and 1 at the tip. Lit as the rock is: the glows, the mouths, his own glow. No sky
// fill, no haze. A faint fill of its own so it shows in the dark between the glows.
render_mode diffuse_burley, specular_schlick_ggx, ambient_light_disabled, fog_disabled, cull_disabled;

uniform vec3 rock_lo : source_color = vec3(0.13, 0.11, 0.10);
uniform vec3 rock_hi : source_color = vec3(0.46, 0.40, 0.34);
uniform float fill = 0.1;

varying vec3 wpos;
varying float v_up;

void vertex() {
	v_up = VERTEX.y;
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
	EMISSION = rock * fill;
}
