shader_type canvas_item;
// The vapour over the glide's view (scripts/sky_flight.gd): deep in a cloud
// or down in the cloud sea's top, the view goes softly white. Thickest at
// the edges, ragged and drifting, so it reads as cloud streaming past and
// never as a flat fade.
#include "res://shaders/reference_globals.gdshaderinc"

uniform float amount = 0.0;

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

void fragment() {
	vec2 p = (UV - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float t = zs_motion_time;
	// Wisps streaming out from the middle, as if flown through.
	float r = length(p);
	vec2 flow = p / max(r, 1e-3) * t * 0.35;
	float n = vapour_noise(p * 3.0 - flow) * 0.6 + vapour_noise(p * 7.0 - flow * 1.7 + 3.1) * 0.4;
	float edge = smoothstep(0.15, 0.75, r);
	float cover = clamp(amount * (0.55 + 0.45 * edge) + (n - 0.5) * 0.5 * amount, 0.0, 1.0);
	vec3 white = min(zs_cloud_sky * 0.9 + zs_cloud_sun * 0.35, vec3(1.0));
	COLOR = vec4(white, cover * 0.92);
}
