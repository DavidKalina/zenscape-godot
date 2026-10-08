shader_type canvas_item;
// The vapour over the glide's view (scripts/sky_flight.gd): deep in a cloud
// or down in the cloud sea's top, the view goes softly white. A soft fog,
// thickest at the edges, rolling in slow, folded billows, a little brighter
// overhead and cooler underfoot. It never streams out from the middle: the
// cloud flying past is the mist round the eye (scripts/glide_air.gd), in
// the world, so it moves as the eye does.
#include "res://shaders/reference_globals.gdshaderinc"

uniform float amount = 0.0;
// Under --below (scripts/sky_below.gd) the sea's vapour closes whole at
// its thickest, so the swap to the lower world is never seen: 0 leaves the
// vapour as it was.
uniform float whole = 0.0;

float vapour_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vapour_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(vapour_hash(i), vapour_hash(i + vec2(1.0, 0.0)), f.x),
		mix(vapour_hash(i + vec2(0.0, 1.0)), vapour_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float vapour_fbm(vec2 p) {
	return vapour_noise(p) * 0.55 + vapour_noise(p * 2.03 + 1.7) * 0.3 + vapour_noise(p * 4.1 - 3.2) * 0.15;
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float t = zs_motion_time;
	// Billows folded over themselves, rolling slowly.
	vec2 fold = vec2(vapour_fbm(p * 1.7 + vec2(t * 0.06, 0.0)), vapour_fbm(p * 1.7 + vec2(4.3, -t * 0.05)));
	float n = vapour_fbm(p * 2.6 + fold * 1.6 + vec2(t * 0.03, t * 0.02));
	float edge = smoothstep(0.1, 0.8, length(p));
	float cover = clamp(amount * (0.4 + 0.45 * edge) + (n - 0.5) * 0.8 * amount, 0.0, 1.0);
	// A sunlit cloud's heart: bright and faintly cool, never grey.
	vec3 white = min(zs_cloud_sky * 0.95 + zs_cloud_sun * 0.5, vec3(1.0));
	white = mix(white, vec3(0.97, 0.98, 1.0) * max(max(white.r, white.g), white.b), 0.45);
	white *= mix(vec3(0.94, 0.96, 1.0), vec3(1.05), 1.0 - UV.y);
	cover = max(cover, smoothstep(0.85, 1.0, amount) * whole);
	COLOR = vec4(min(white, vec3(1.0)), cover * mix(0.85, 1.0, whole));
}
