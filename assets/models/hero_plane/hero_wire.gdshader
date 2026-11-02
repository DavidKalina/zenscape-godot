shader_type spatial;
// Written by art/blender/hero_plane/hero_plane_build.py. The wires, far under a
// pixel wide at chase, where they broke into dashes: each is held to `min_px`
// on screen, pushed out along its normal, and fades by what it really covers,
// so a far wire is a faint whole line. Lit as hero_surface.gdshader.
render_mode diffuse_lambert, specular_schlick_ggx, blend_mix, depth_draw_never, shadows_disabled;
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
global uniform vec3 zs_key_direction;
global uniform float zs_daylight;
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float wire_r = 0.0016;
uniform float min_px = 1.5;
uniform float darkest = 1.3;
uniform float fill = 2.2;
uniform float shade_lift = 3.0;
// By night the lift and the sky's fill give way to these shares: the land goes
// dark then, the fill does nearly all the plane's lighting (hardly the moon),
// and in full they read as lit from within.
uniform float shade_night = 0.1;
uniform float fill_night = 0.6;
// How far a roof shuts the sky out (PlaneFigure `_cover`), 0 open air to 1 under
// stone, and how much of the sky's light it takes away then.
uniform float roof = 0.0;
uniform float roof_dim = 0.82;
uniform float shade_lit = 0.3;
instance uniform float flex = 0.0;
varying float cover;
void vertex() {
	float span_out = max(abs(VERTEX.x) - 0.16, 0.0);
	VERTEX.y += flex * span_out * span_out * 0.35;
	float depth = max(-(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z, 0.01);
	float toy_px = 2.0 * depth / (abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y) / length(MODEL_MATRIX[0].xyz);
	// A three-sided tube of radius r stands about 1.6 r wide.
	float want = min_px * toy_px / 1.6;
	VERTEX += NORMAL * max(want - wire_r, 0.0);
	cover = clamp(wire_r / want * darkest, 0.0, 1.0);
}
void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb * COLOR.r;
	ALBEDO = base;
	ROUGHNESS = 0.45;
	METALLIC = 0.0;
	ALPHA = cover;
	vec3 up = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, up.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float sunward = clamp(dot(up, zs_key_direction), 0.0, 1.0);
	EMISSION = base * (hemi * fill * mix(fill_night, 1.0, zs_daylight) + zs_hemi_sky * zs_hemi_energy * shade_lift * mix(shade_night, 1.0, zs_daylight) * mix(1.0, shade_lit, sunward)) * (1.0 - roof * roof_dim);
}
