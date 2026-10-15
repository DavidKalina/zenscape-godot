shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_disabled;
// The ground cover's skin (scripts/underground/ground_cover.gd): a thin
// painted layer lying on a stone top, so bare stone gets the grass ground's
// living, shaded, wind-moved look. In world x, z, so it runs on from the
// terrain's own ground and from one piece to the next.
//   mode 0 dust    drifted dust or ash: ripples across the wind that creep,
//                  a pale sheen on the gusts, grit (underground_dust.gdshaderinc)
//   mode 1 moss    cool dark green with a faint glow in patches that breathes
//   mode 2 turf    the floor under sparse grass: dusty sage patches, no ripple
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/grass_look.gdshaderinc"
#include "res://shaders/underground_dust.gdshaderinc"

uniform int mode = 0;
uniform vec3 tone : source_color = vec3(0.42, 0.37, 0.30);
uniform vec3 tone_deep : source_color = vec3(0.30, 0.26, 0.21);
uniform vec3 tone_lit : source_color = vec3(0.52, 0.47, 0.39);
uniform vec3 glow_color : source_color = vec3(0.25, 0.95, 0.7);
uniform float glow = 0.0;
uniform float glow_scale = 1.0;
// The preset's warmth on the ground (ground_cover.gd WARM).
uniform vec3 grade = vec3(1.0);
uniform float amount : hint_range(0.0, 1.0) = 1.0;
// The area's middle and half sizes in the node's own x, z, and how far in
// from its edge the cover thins out (m).
uniform vec4 box = vec4(0.0, 0.0, 1.0, 1.0);
uniform float fade = 0.4;
uniform bool boxed = true;

varying vec3 v_local;
varying vec3 v_world;

void vertex() {
	v_local = VERTEX;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_world.xz;
	float d = 9.0;
	if (boxed) d = min(box.z - abs(v_local.x - box.x), box.w - abs(v_local.z - box.y));
	float ragged = zs_noise(p * 2.7) * 0.6 + zs_noise(p * 8.3) * 0.4;
	float edge = smoothstep(0.0, max(fade, 0.02), d + (ragged - 0.45) * fade * 1.1);
	// A little thinner in patches, so stone shows through at the margins.
	float thin = smoothstep(0.08, 0.5, zs_noise(p * 0.31 + zs_grass_offset * 0.4 + 5.0) + 0.25 * edge);
	ALPHA = edge * mix(0.75, 1.0, thin) * amount;
	float broad = zs_noise(p * 0.13 + zs_grass_offset * 0.5 + 23.0);
	float mid = zs_noise(p * 0.5 + 8.0);
	vec3 c = mix(tone_deep, tone, smoothstep(0.2, 0.6, broad));
	c = mix(c, tone_lit, smoothstep(0.55, 0.85, broad * 0.6 + mid * 0.5) * 0.8);
	vec3 n = vec3(0.0, 1.0, 0.0);
	EMISSION = vec3(0.0);
	if (mode == 0) {
		c = zs_dust_tone(c, p, 1.0);
		float h = zs_dust_ripple(p);
		vec2 g = vec2(zs_dust_ripple(p + vec2(0.06, 0.0)) - h, zs_dust_ripple(p + vec2(0.0, 0.06)) - h) / 0.06;
		float drift = smoothstep(0.38, 0.72, zs_noise(p * 0.19 + zs_grass_offset * 0.6 + 31.0));
		n = normalize(vec3(-g.x * 0.07 * drift, 1.0, -g.y * 0.07 * drift));
	} else if (mode == 1) {
		float patch = smoothstep(0.45, 0.8, zs_noise(p * 0.9 + 41.0) * 0.6 + zs_noise(p * 3.1) * 0.4);
		c *= 0.8 + 0.5 * zs_noise(p * 11.0);
		float breathe = 0.65 + 0.35 * sin(TIME * 0.7 + zs_noise(p * 0.4) * 12.0);
		float crest = zs_grass_crest(p, 7.0, ZS_GRASS_WAVE_SPEED, zs_grass_offset);
		EMISSION = glow_color * glow * glow_scale * patch * breathe * (0.55 + 0.6 * crest);
		c = mix(c, c * 1.25, crest * 0.3);
	} else {
		float crest = zs_grass_crest(p, ZS_GRASS_WAVE_LENGTH, ZS_GRASS_WAVE_SPEED, zs_grass_offset);
		c *= 0.85 + 0.35 * zs_noise(p * 6.0);
		c = mix(c, c * vec3(1.2, 1.18, 1.0), crest * 0.35);
	}
	ALBEDO = c * grade;
	ROUGHNESS = 1.0;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}
