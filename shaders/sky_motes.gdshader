shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Motes of light adrift in the open air round the floating plate
// (scripts/sky_motes.gd): the faint mystical touch over the cloud sea. A
// camera-facing soft point with a pale halo. Each wanders on its own slow
// loop and rises a little, fading in and out over many seconds as it goes,
// so none of them ever blinks. Instance custom data: a seed (x), a size (y)
// and a brightness (z). Warm white by day, the sun's colour at golden hour,
// a pale teal at night.
#include "res://shaders/reference_globals.gdshaderinc"

// 0 hides them; the look pass sets it with the cloud sea.
uniform float strength = 0.0;
// How far each one rises in a life, and how long a life lasts (seconds).
uniform float rise = 6.0;
uniform float life = 34.0;

varying float opacity;
varying vec3 tint;

void vertex() {
	vec4 seed = INSTANCE_CUSTOM;
	float t = zs_motion_time;
	float phase = fract(t / (life * (0.8 + 0.4 * seed.x)) + seed.x * 7.13);
	vec3 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// A slow loop of a couple of metres, and a gentle rise through the life.
	vec3 wander = vec3(
		sin(t * (0.05 + 0.03 * seed.x) + seed.x * 31.0),
		0.4 * sin(t * (0.04 + 0.02 * seed.x) + seed.x * 17.0),
		cos(t * (0.045 + 0.025 * seed.x) + seed.x * 23.0)) * 2.2;
	vec3 centre = base + wander + vec3(0.0, (phase - 0.5) * rise, 0.0);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	// Kept a few pixels across at any distance, as the stars are.
	float away = length(centre - INV_VIEW_MATRIX[3].xyz);
	float size = max(seed.y, away * 0.006);
	vec3 world = centre + (right * VERTEX.x + up * VERTEX.y) * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	// In over the first fifth of a life, out over the last third.
	opacity = smoothstep(0.0, 0.2, phase) * (1.0 - smoothstep(0.67, 1.0, phase)) * seed.z * strength;
	float night = zs_night * zs_celestial_clear;
	// At night only a third of them stay, so they never pass for stars.
	opacity *= mix(1.0, step(seed.x, 0.34), night);
	vec3 sun = max(zs_cloud_sun, vec3(0.0));
	vec3 warm = mix(vec3(1.0, 0.93, 0.78), sun / max(max(sun.r, max(sun.g, sun.b)), 1e-3), 0.6);
	tint = mix(warm * 0.22, vec3(0.45, 0.95, 0.88) * 0.18, night) * mix(1.0, 0.45, 1.0 - zs_celestial_clear);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float d2 = dot(q, q);
	float core = exp(-d2 * 30.0);
	float halo = exp(-d2 * 4.0) * 0.35 * (1.0 - smoothstep(0.6, 1.0, d2));
	ALBEDO = tint * (core + halo) * opacity;
}
