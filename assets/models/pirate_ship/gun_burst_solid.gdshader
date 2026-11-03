shader_type spatial;
// The solid part of a splash (ShipGuns `_splash_mesh`): the column's blobs, the
// crown and the drops, white water thrown up and falling back, or clods of dirt
// off land (`dirt`). Each a disc turned to the eye with a clean, lumpy edge,
// drawn opaque so the blobs sort among themselves and the sea hides what falls
// back under it; lit as a ball in the clouds' colours (gun_fx.gdshaderinc).
// Animated by the node's `age` alone: a splash costs the CPU nothing but that.
render_mode unshaded, depth_draw_opaque, cull_disabled, shadows_disabled, skip_vertex_transform;
#define GUN_BURST
#include "res://assets/models/pirate_ship/gun_fx.gdshaderinc"

// The water's white on its sunny side and its blue in shade against the lit
// cloud's value, where one turns to the other; the clods' colour.
uniform float white = 1.3;
uniform vec3 shade = vec3(0.58, 0.74, 0.9);
uniform vec2 band = vec2(0.38, 0.56);
uniform vec3 clod = vec3(0.3, 0.24, 0.18);

void vertex() {
	v_q = UV * 2.0 - 1.0;
	v_role = CUSTOM2.w;
	v_seed = CUSTOM1.w;
	v_hard = CUSTOM3.x;
	v_glow = CUSTOM3.y;
	v_tint = COLOR.rgb;
	float alpha;
	float u;
	VERTEX = gun_fx_bit(MODEL_MATRIX, VIEW_MATRIX, VERTEX, v_q, CUSTOM0, CUSTOM1, CUSTOM2, CUSTOM3, alpha, u);
	v_alpha = alpha;
	v_u = u;
}

void fragment() {
	if (v_alpha <= 0.0) discard;
	float r = length(v_q);
	float a = atan(v_q.y, v_q.x);
	float reach = gun_fx_reach(a, v_seed);
	if (r > reach) discard;
	vec3 rd = normalize(mat3(INV_VIEW_MATRIX) * VERTEX);
	float side;
	vec2 light = gun_fx_light(v_q / max(reach, 0.5), mat3(INV_VIEW_MATRIX), rd, side);
	// Two tones, as the sea's foam: white where the sun's on it, the water's
	// blue in shade, a little light through the shaded side (`glow`).
	float k = smoothstep(band.x, band.y, side);
	vec3 lit = vec3(light.x + light.y * 1.25) * white;
	vec3 dark = shade * (light.x + light.y * (0.2 + 0.3 * v_glow)) * white;
	vec3 water = v_tint * mix(dark, lit, k);
	vec3 earth = clod * (light.x + light.y * (0.25 + 1.1 * k)) * 1.6;
	ALBEDO = mix(water, earth, dirt);
}
