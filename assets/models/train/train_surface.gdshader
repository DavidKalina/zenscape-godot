shader_type spatial;
// Written by art/blender/train/train_build.py. Lit as the world is: no ambient,
// the sky's hemisphere added as emission (the pirate ship's surface), so a stock
// material would go black out of the sun. Albedo: the tile times the vertex
// colour (the paint, its grime baked in).
render_mode diffuse_lambert, specular_schlick_ggx;
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_depth = 0.0;
uniform float roughness_value = 0.9;
uniform float metallic_value = 0.0;
uniform float fill = 1.6;
uniform float rim = 0.3;
void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb * COLOR.rgb;
	ALBEDO = base;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	if (normal_depth > 0.0) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_depth;
	}
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, n.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	EMISSION = base * hemi * fill + base * zs_hemi_sky * zs_hemi_energy * edge * rim;
}
