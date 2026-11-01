shader_type spatial;
// Written by art/blender/ship/ship_build.py. Lit as the world is: no ambient,
// the sky's hemisphere added as emission (shaders/folk_surface.gdshaderinc),
// so a stock material would go black out of the sun.
render_mode diffuse_lambert, cull_disabled;
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float fill = 1.6;
uniform float rim = 0.3;
uniform float through = 0.4;
void fragment() {
	vec4 t = texture(albedo_tex, UV);
	vec3 base = t.rgb * COLOR.rgb;
	ALBEDO = base;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
	BACKLIGHT = base * through;
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, n.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	EMISSION = base * hemi * fill + base * zs_hemi_sky * zs_hemi_energy * edge * rim;
}
