shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// The miniature on the lodestone (scripts/lodestone_miniatures.gd): the
// real set piece's stone at a few hundredths of its size, coloured by its
// vertices and lit as the ruins are (shaders/ruin_stone.gdshader, the
// sky's hemisphere as emission), then hazed as a far place is: it pales
// into a warm mist low down (the cloud it stands in) and toward its
// fringe, so it reads as a place seen from far off, not a model on a
// shelf. Its frame is the set piece's own (metres), so the haze's
// heights and reach are the real place's. `water` (1) draws the
// channel's water instead: a pale glassy blue with a little light of its
// own, glinting as it runs.
#include "res://shaders/reference_globals.gdshaderinc"

uniform float hum = 0.0;
uniform float clock = 0.0;
uniform float fill = 1.5;
// The air between: a far place's shade is never black, it fills with
// the mist's light.
uniform float air = 0.2;
uniform float rim = 0.3;
// The haze: the mist's colour (lit by the sky), the heights (the set
// piece's metres) between which it thins out going up, how thick it is
// low down, and the fringe: the middle and the reach past which the
// place fades into the mist (x, z, inner radius, outer radius).
uniform vec3 mist : source_color = vec3(0.93, 0.92, 0.9);
uniform vec2 haze_heights = vec2(-6.0, 6.0);
uniform float haze = 0.4;
uniform vec4 fringe = vec4(0.0, 0.0, 60.0, 110.0);
uniform float water = 0.0;
uniform vec3 water_colour : source_color = vec3(0.62, 0.8, 0.86);

varying vec3 lm_local;

void vertex() {
	lm_local = VERTEX;
}

void fragment() {
	vec3 base = COLOR.rgb;
	vec3 own = vec3(0.0);
	if (water > 0.5) {
		float glint = pow(0.5 + 0.5 * sin(lm_local.x * 1.7 - clock * 3.0 + sin(lm_local.z * 3.0) * 1.5), 6.0);
		base = water_colour;
		ROUGHNESS = 0.08;
		SPECULAR = 0.8;
		own = water_colour * (0.25 + 0.25 * hum + glint * 0.5);
	} else {
		ROUGHNESS = 0.9;
		SPECULAR = 0.35;
	}
	vec3 normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, normal.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 lit = base * hemi * fill + mix(base, vec3(0.5), 0.4) * zs_hemi_sky * zs_hemi_energy * edge * rim;
	// How far into the mist: low down, and out at the fringe.
	float low = 1.0 - smoothstep(haze_heights.x, haze_heights.y, lm_local.y);
	float out_far = smoothstep(fringe.z, fringe.w, length(lm_local.xz - fringe.xy));
	float h = clamp(max(low * haze, out_far), 0.0, 1.0);
	vec3 mist_lit = mist * (zs_hemi_sky * zs_hemi_energy / PI * 1.6 + vec3(0.06 + 0.08 * hum));
	ALBEDO = mix(base, mist * 0.6, h * 0.8);
	EMISSION = mix(lit + own + mist_lit * air, mist_lit, h * 0.8) + base * vec3(1.0, 0.86, 0.6) * 0.08 * hum;
}
