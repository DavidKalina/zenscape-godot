shader_type spatial;
render_mode diffuse_lambert;
// The stomper's stone: the giants' (shaders/giant_stone.gdshader), the same blotches,
// soil and baked relief, with two changes for a body that walks and stands 250 m tall.
// The blotches are read from where a vertex stands at rest (COLOR.rgb, set by
// stomper.gd) and the soil from which way it faces at rest (COLOR.a), or they would
// slide over a limb that moves. And the shade takes the sunlit land's bounce, as a
// shaded limb goes black up close otherwise.
global uniform float zs_under;
global uniform vec3 zs_cloud_sun;
global uniform vec3 zs_key_direction;
uniform sampler2D mask : filter_linear_mipmap, repeat_enable;
uniform sampler2D relief : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D shade : filter_linear_mipmap;
uniform vec3 stone_a : source_color = vec3(0.50, 0.50, 0.50);
uniform vec3 stone_b : source_color = vec3(0.31, 0.32, 0.34);
uniform vec3 soil : source_color = vec3(0.42, 0.38, 0.26);
// Metres a colour channel's full range spans (stomper.gd).
uniform float rest_span = 290.0;
uniform vec3 land_tint : source_color = vec3(0.72, 0.68, 0.6);
uniform float land_bounce = 1.0;
varying vec3 rest;
varying float rest_up;
varying vec3 world_normal;

void vertex() {
	rest = COLOR.rgb * rest_span;
	rest_up = COLOR.a * 2.0 - 1.0;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

float tri(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= w.x + w.y + w.z;
	return texture(mask, p.zy).r * w.x + texture(mask, p.xz).r * w.y + texture(mask, p.xy).r * w.z;
}

void fragment() {
	vec3 n = normalize(world_normal);
	float broad = tri(rest * 0.006, n);
	float fine = tri(rest * 0.05, n);
	float ao = texture(shade, UV).r;
	vec3 stone = mix(stone_b, stone_a, smoothstep(0.25, 0.75, broad * 0.7 + fine * 0.3));
	stone *= mix(0.72, 1.05, smoothstep(0.0, 0.8, ao));
	// Much less soil than a ruin's: it walks.
	float s = 0.5 * smoothstep(0.9, 1.3, rest_up + (broad - 0.5) * 0.8 + (1.0 - ao) * 0.2);
	ALBEDO = mix(stone, soil, s);
	NORMAL_MAP = texture(relief, UV).xyz;
	NORMAL_MAP_DEPTH = mix(0.9, 0.4, s);
	AO = mix(0.6, 1.0, ao);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	float sunward = clamp(dot(n, zs_key_direction), 0.0, 1.0);
	EMISSION = ALBEDO * ao * zs_cloud_sun * land_tint * land_bounce * mix(0.45, 1.0, clamp(0.5 - 0.5 * n.y, 0.0, 1.0)) * (1.0 - 0.6 * sunward) * (1.0 - zs_under);
}
