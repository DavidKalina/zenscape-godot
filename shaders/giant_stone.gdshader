shader_type spatial;
render_mode diffuse_lambert;
// The giants' stone (scripts/endless/giant_ruins.gd): the masonry and cracks
// baked from the full mesh (`relief`, `shade`), worn in broad blotches laid on
// by world position, with the land's straw and soil settled on what faces up.
uniform sampler2D mask : filter_linear_mipmap, repeat_enable;
uniform sampler2D relief : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D shade : filter_linear_mipmap;
uniform vec3 stone_a : source_color = vec3(0.50, 0.50, 0.50);
uniform vec3 stone_b : source_color = vec3(0.31, 0.32, 0.34);
uniform float shade_low = 0.72;
uniform float soil_from = 0.86;
uniform vec3 soil : source_color = vec3(0.42, 0.38, 0.26);
varying vec3 world;
varying vec3 world_normal;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

float tri(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= w.x + w.y + w.z;
	return texture(mask, p.zy).r * w.x + texture(mask, p.xz).r * w.y + texture(mask, p.xy).r * w.z;
}

void fragment() {
	vec3 n = normalize(world_normal);
	float broad = tri(world * 0.006, n);
	float fine = tri(world * 0.05, n);
	float ao = texture(shade, UV).r;
	vec3 stone = mix(stone_b, stone_a, smoothstep(0.25, 0.75, broad * 0.7 + fine * 0.3));
	stone *= mix(shade_low, 1.05, smoothstep(0.0, 0.8, ao));
	float settled = n.y + (broad - 0.5) * 0.8 + (fine - 0.5) * 0.3 + (1.0 - ao) * 0.2;
	float s = smoothstep(soil_from, soil_from + 0.16, settled);
	ALBEDO = mix(stone, soil, s);
	NORMAL_MAP = texture(relief, UV).xyz;
	NORMAL_MAP_DEPTH = mix(0.9, 0.4, s);
	AO = mix(0.6, 1.0, ao);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
