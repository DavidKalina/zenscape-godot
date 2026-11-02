shader_type spatial;
// The canopy's panes: a deep tinted glass that gives back the sky at a slant.
// Written by art/blender/hero_plane/hero_plane_build.py.
render_mode blend_mix, cull_back, diffuse_lambert, specular_schlick_ggx, depth_draw_always;
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
uniform vec3 tint : source_color = vec3(0.13, 0.21, 0.27);
uniform float depth = 0.78;
uniform float roof = 0.0;
uniform float roof_dim = 0.82;
void fragment() {
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 r = reflect(-(INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz, n);
	vec3 sky = mix(zs_hemi_ground, zs_hemi_sky, r.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	ALBEDO = tint;
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.7;
	ALPHA = mix(depth, 0.97, edge);
	EMISSION = (sky * (0.25 + 1.4 * edge) + tint * sky * 0.8) * (1.0 - roof * roof_dim);
}
