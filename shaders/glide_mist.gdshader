shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// The cloud round the eye while it flies through one (scripts/glide_air.gd):
// soft clots of mist held in a box that wraps round the eye, as the
// streaks are (shaders/glide_streaks.gdshader), each keeping its place in
// the world till the eye leaves it behind. Flown through, they swell past
// and part round the eye with true depth, the near ones quick, the far
// slow, so the cloud reads as a body of air and never as a pattern on the
// glass. Lit as the clouds are: brighter on the side to the sun and above.
// Instance custom data: a seed (x), a size (y, m) and a thickness (z).
#include "res://shaders/reference_globals.gdshaderinc"

uniform float box = 56.0;
// How deep the eye is in cloud (0 hides them).
uniform float strength = 0.0;

varying vec2 across;
varying float opacity;
varying float seed;
varying vec3 shade;

float mist_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float mist_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mist_hash(i), mist_hash(i + vec2(1.0, 0.0)), f.x),
		mix(mist_hash(i + vec2(0.0, 1.0)), mist_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vec3 eye = INV_VIEW_MATRIX[3].xyz;
	vec3 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 centre = eye + mod(base - eye + 0.5 * box, box) - 0.5 * box;
	float away = distance(eye, centre);
	float size = INSTANCE_CUSTOM.y;
	seed = INSTANCE_CUSTOM.x;
	// A slow turn of its own.
	float turn = seed * 6.283 + zs_motion_time * (seed - 0.5) * 0.15;
	vec2 v = vec2(cos(turn) * VERTEX.x - sin(turn) * VERTEX.y, sin(turn) * VERTEX.x + cos(turn) * VERTEX.y);
	vec3 world = centre + (INV_VIEW_MATRIX[0].xyz * v.x + INV_VIEW_MATRIX[1].xyz * v.y) * size * 2.0;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	across = VERTEX.xy * 2.0;
	// Thin as it reaches the eye, so it parts round it rather than
	// slapping the glass; gone towards the box's edge, where it wraps.
	opacity = smoothstep(size * 0.25, size * 1.3, away) * (1.0 - smoothstep(box * 0.3, box * 0.5, away)) * INSTANCE_CUSTOM.z * strength;
	vec3 sun = normalize(zs_sun_direction + vec3(0.0, 1e-4, 0.0));
	vec3 ray = (centre - eye) / max(away, 1e-3);
	float sunward = clamp(dot(ray, sun) * 0.3 + ray.y * 0.3 + 0.55, 0.0, 1.0);
	shade = min(zs_cloud_sky * 0.95 + zs_cloud_sun * (0.3 + 0.45 * sunward), vec3(1.05));
	shade = mix(shade, vec3(0.97, 0.98, 1.0) * max(max(shade.r, shade.g), shade.b), 0.4);
}

void fragment() {
	float r = length(across);
	vec2 q = across * 1.4 + seed * 31.0;
	float n = mist_noise(q) * 0.6 + mist_noise(q * 2.4 + 3.3) * 0.4;
	float soft = 1.0 - smoothstep(0.2, 1.0, r + (n - 0.5) * 0.6);
	ALBEDO = shade;
	ALPHA = soft * soft * (0.55 + 0.45 * n) * opacity;
}
