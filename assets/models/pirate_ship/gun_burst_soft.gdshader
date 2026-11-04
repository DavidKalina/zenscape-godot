shader_type spatial;
// The soft part of a gun's burst (ShipGuns): a muzzle blast's flash, its ring
// of smoke and the cloud that hangs; a splash's skirt of spray, its mist, the
// foam ring spreading on the water and the patch in it; a land hit's dust
// (`dirt`). Discs turned to the eye (the ring and the patch lie flat), soft
// at the edge, faded against what's behind; the flash glows, the rest is lit
// in the clouds' colours (gun_fx.gdshaderinc). Animated by the node's `age`.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;
#define GUN_BURST
#include "res://assets/models/pirate_ship/gun_fx.gdshaderinc"

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
// The flash's brightness (over 1 glows); smoke's and water's white against
// the lit cloud's value; the dust's colour; how near what's behind a disc
// fades it (m).
uniform float flash = 7.0;
uniform float white = 1.2;
uniform vec3 dust = vec3(0.6, 0.52, 0.41);
uniform float soft_reach = 2.5;

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

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	if (v_alpha <= 0.0) discard;
	float r = length(v_q);
	float a = atan(v_q.y, v_q.x);
	float shape;
	float fade;
	if (v_role == GUN_RING) {
		// A ring of foam, broken up, thinning as it spreads.
		float n = noise(vec2(a * 4.0 + v_seed * 20.0, r * 3.0)) * 0.6 + noise(vec2(a * 11.0, v_seed * 7.0)) * 0.4;
		float inner = mix(0.55, 0.8, v_u);
		shape = smoothstep(inner - 0.12, inner + 0.06, r) * (1.0 - smoothstep(0.9, 1.0, r)) * smoothstep(0.25, 0.55, n);
		fade = (1.0 - smoothstep(0.3, 1.0, v_u)) * smoothstep(0.0, 0.05, v_u);
	} else if (v_role == GUN_PATCH) {
		// The foam left where it went in: lacy, going to holes as it fades.
		float n = noise(v_q * 3.5 + v_seed * 13.0) * 0.6 + noise(v_q * 9.0 - v_seed * 5.0) * 0.4;
		shape = (1.0 - smoothstep(0.35, 1.0, r + (n - 0.5) * 0.5)) * smoothstep(v_u * 0.75, v_u * 0.75 + 0.2, n);
		fade = 1.0 - smoothstep(0.5, 1.0, v_u);
	} else {
		float reach = gun_fx_reach(a, v_seed);
		// Soft ones (smoke, mist) ragged with noise that turns as they age.
		float n = noise(v_q * 2.3 + vec2(v_seed * 17.0, v_u * 1.7));
		reach *= mix(0.7 + 0.4 * n, 1.0, v_hard);
		float edge = mix(0.85, 0.12, v_hard);
		shape = 1.0 - smoothstep(reach - edge, reach, r);
		fade = v_role == GUN_FLASH ? 1.0 - smoothstep(0.25, 1.0, v_u) : pow(1.0 - v_u, 1.3) * smoothstep(0.0, 0.04, v_u);
	}
	float alpha = shape * fade * v_alpha;
	if (alpha < 0.004) discard;
	float t = length(VERTEX);
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	alpha *= smoothstep(0.0, soft_reach, length(behind.xyz / behind.w) - t) * smoothstep(2.0, 12.0, t);
	if (alpha < 0.004) discard;
	if (v_role == GUN_FLASH) {
		ALBEDO = v_tint * flash * (0.6 + 0.4 * (1.0 - r));
	} else {
		vec3 rd = normalize(mat3(INV_VIEW_MATRIX) * VERTEX);
		vec2 q = (v_role == GUN_RING || v_role == GUN_PATCH) ? vec2(0.0, 0.6) : v_q;
		float side;
		vec2 light = gun_fx_light(q, mat3(INV_VIEW_MATRIX), rd, side);
		// Soft stuff takes the light through it: its shaded side not far off.
		float value = light.x + light.y * (0.45 + 0.75 * side + 0.3 * v_glow);
		ALBEDO = mix(v_tint * white, dust * 1.4, dirt) * value;
	}
	ALPHA = alpha;
}
