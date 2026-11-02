shader_type spatial;
// Written by art/blender/hero_plane/hero_plane_build.py. Lit as the world is: no
// ambient, the sky's hemisphere added as emission (shaders/folk_surface.
// gdshaderinc). The albedo is the plane's own paint; the livery tints by
// slot/default through the mask (R body, G trim, B wing, A dark), so stains and
// wear stay and bared metal doesn't take the paint. COLOR is baked darkness.
render_mode diffuse_lambert, specular_schlick_ggx;
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D mask_tex : hint_default_black, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 paint_body : source_color = vec3(0.725, 0.345, 0.231);
uniform vec3 paint_trim : source_color = vec3(0.184, 0.4, 0.439);
uniform vec3 paint_wing : source_color = vec3(0.925, 0.886, 0.784);
uniform vec3 paint_dark : source_color = vec3(0.184, 0.29, 0.31);
const vec3 BASE_BODY = vec3(0.485, 0.0976, 0.0437);
const vec3 BASE_TRIM = vec3(0.0284, 0.133, 0.162);
const vec3 BASE_WING = vec3(0.838, 0.76, 0.578);
const vec3 BASE_DARK = vec3(0.0284, 0.0685, 0.0781);
uniform float normal_depth = 1.0;
uniform float fill = 2.2;
uniform float rim = 0.3;
uniform float bounce = 4.0;
uniform float coat_roughness = 0.08;
// set_wear: 0 new; faded, dusty and dull at 1, as the old paint did.
uniform float wear : hint_range(0.0, 1.0) = 0.0;
uniform vec3 wear_dust : source_color = vec3(0.71, 0.65, 0.55);
uniform float flex = 0.0;
void vertex() {
	float span_out = max(abs(VERTEX.x) - 0.16, 0.0);
	VERTEX.y += flex * span_out * span_out * 0.35;
}
void fragment() {
	vec4 m = texture(mask_tex, UV);
	vec3 orm = texture(orm_tex, UV).rgb;
	vec3 base = texture(albedo_tex, UV).rgb;
	vec3 tint = vec3(1.0);
	tint = mix(tint, paint_body / BASE_BODY, m.r);
	tint = mix(tint, paint_trim / BASE_TRIM, m.g);
	tint = mix(tint, paint_wing / BASE_WING, m.b);
	tint = mix(tint, paint_dark / BASE_DARK, m.a);
	base *= tint;
	vec3 up = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float dull = 0.0;
	if (wear > 0.0) {
		float painted = clamp(m.r + m.g + m.b + m.a, 0.0, 1.0);
		base = mix(base, vec3(dot(base, vec3(0.3, 0.55, 0.15))), 0.28 * wear * painted);
		float dust = smoothstep(0.15, 0.85, up.y) * wear;
		base = mix(base, wear_dust, dust * 0.34);
		dull = wear * 0.7;
	}
	base *= COLOR.r;
	ALBEDO = base;
	ROUGHNESS = clamp(mix(orm.r, 1.0, dull * 0.6), 0.0, 1.0);
	// The sky isn't in the reflections, so a true metal would go black: a
	// third of one keeps its colour and its sheen.
	METALLIC = orm.g * 0.35;
	CLEARCOAT = orm.b * (1.0 - dull * 0.8);
	CLEARCOAT_ROUGHNESS = coat_roughness;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	// What looks down takes the sunlit land's bounce: a thin wing with nothing but
	// the world's dark ground term under it reads black, where a round body didn't.
	vec3 hemi = mix(zs_hemi_ground * bounce, zs_hemi_sky, up.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 diffuse = base * (1.0 - orm.g * 0.3);
	EMISSION = diffuse * hemi * fill + mix(diffuse, vec3(0.5), 0.4) * zs_hemi_sky * zs_hemi_energy * edge * rim;
}
