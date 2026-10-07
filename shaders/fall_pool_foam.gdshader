shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, specular_disabled;
// Where a terrace's fall lands in the pool below (scripts/cluster_falls_dress.gd
// `_plunge`): a flat quad on the water, white churn at its heart where the
// water beats down and rings of foam spreading out from it and thinning
// away, torn by noise so it never reads as a target. Lit as the water round
// it is, so by night it shows only where the pool's lantern light reaches.
// UV spans the quad; its middle is where the fall lands.
#include "res://shaders/reference_globals.gdshaderinc"

uniform float rings_speed = 0.42;
uniform float churn = 0.95;

varying vec3 world;

float foam_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float foam_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(foam_hash(i), foam_hash(i + vec2(1.0, 0.0)), f.x),
		mix(foam_hash(i + vec2(0.0, 1.0)), foam_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float t = zs_motion_time;
	vec2 seed = world.xz * 0.37;
	float n = foam_noise(p * 4.5 + seed + vec2(t * 1.9, -t * 1.6));
	float m = foam_noise(p * 9.0 - seed + vec2(-t * 2.4, t * 2.1));
	// The heart: beaten white where the water comes down.
	float heart = 1.0 - smoothstep(0.08, 0.42, r + (n - 0.5) * 0.3);
	// Rings spreading out, each fainter and wider as it goes.
	float rings = 0.0;
	for (int k = 0; k < 3; k++) {
		float age = fract(t * rings_speed + float(k) / 3.0);
		float at = 0.18 + age * 0.78;
		float width = 0.05 + 0.08 * age;
		float wobble = (foam_noise(p * 3.0 + vec2(float(k) * 7.1, t * 0.5)) - 0.5) * 0.12;
		rings += (1.0 - smoothstep(0.0, width, abs(r - at + wobble))) * (1.0 - age) * (1.0 - age);
	}
	float lace = smoothstep(0.3, 0.75, m * 0.7 + n * 0.5);
	float foam = clamp(heart * churn * (0.75 + 0.25 * m) + rings * lace * 0.75, 0.0, 1.0);
	ALBEDO = vec3(0.93, 0.96, 0.97);
	ROUGHNESS = 0.85;
	ALPHA = foam * (1.0 - smoothstep(0.8, 1.0, r)) * 0.92;
}
