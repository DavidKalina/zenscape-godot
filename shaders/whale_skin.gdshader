shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx, cull_back;
// The whale's skin (scripts/endless/whale_body.gd, art/blender/whale/whale_build.py):
// the painted skin (rgb its colour, a how dry and rough: scars, barnacle rash),
// the barnacles' crust by the vertex colour's red, the creases' shade by its
// green. Out of the water it is wet: a tight shine, the sky off it edge on, and
// while `sheet` is up, water running down it in pale threads. Under the water's
// level (`surface_y`) it dims and goes to the water's colour; the sea's own
// sheet, drawn over it, does the rest.

global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;

uniform sampler2D skin : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 crust_tint : source_color = vec3(0.47, 0.44, 0.37);
uniform vec3 under_tint : source_color = vec3(0.03, 0.13, 0.19);
// The water's level (world y) and how fast it dims under it (per m).
uniform float surface_y = -40.0;
uniform float under_fade = 0.35;
// The sky's fill on it, and its mirror edge on (wet skin).
uniform float fill = 1.0;
uniform float mirror = 0.55;
// Water running off it (0 to 1).
uniform float sheet = 0.0;

varying vec3 world_p;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.55);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 m = texture(skin, UV);
	vec3 base = m.rgb;
	float rough = mix(0.14, 0.62, m.a);
	// The skin's grain: fine leathery wrinkles, by the paint's own frame.
	float grain = vnoise(UV * vec2(900.0, 420.0)) * 0.6 + vnoise(UV * vec2(2300.0, 1100.0)) * 0.4;
	base *= 0.82 + 0.36 * grain;
	rough += (grain - 0.5) * 0.18;
	float crust = COLOR.r;
	base = mix(base, crust_tint * (0.6 + 0.6 * grain), crust);
	rough = mix(rough, 0.85, crust);
	base *= mix(0.55, 1.0, COLOR.g);

	vec3 world_n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float above = world_p.y - surface_y;
	// Water running down: threads along the fall line, thick just out of the
	// water and where the sheet is fresh.
	float thread = 0.0;
	if (sheet > 0.0) {
		vec2 q = vec2(dot(world_p.xz, vec2(0.83, 0.55)) * 7.0, world_p.y * 0.45 + TIME * 2.2);
		float run = vnoise(q) * 0.6 + vnoise(q * vec2(2.7, 1.9) + 5.0) * 0.4;
		thread = smoothstep(0.6, 0.85, run) * sheet * smoothstep(0.0, 0.6, above);
		thread *= 0.35 + 0.65 * clamp(1.0 - world_n.y, 0.0, 1.0);
	}
	base = mix(base, vec3(0.72, 0.8, 0.84), thread * 0.3);
	rough = mix(rough, 0.08, max(thread, sheet * 0.5 * (1.0 - crust)));

	ALBEDO = base;
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	SPECULAR = 0.6;
	vec3 hemi = mix(zs_hemi_ground * 0.6, zs_hemi_sky, world_n.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	vec3 mirror_way = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, NORMAL), 0.0)).xyz;
	vec3 sky = mix(zs_hemi_ground * 0.6, zs_hemi_sky, clamp(mirror_way.y, -1.0, 1.0) * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge_on = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float wet = (1.0 - crust * 0.8) * (1.0 - rough);
	EMISSION = base * hemi * fill + sky * mirror * wet * (0.1 + 0.9 * pow(edge_on, 3.0));
	// Under the water: dim, the water's colour, no shine.
	float t = smoothstep(0.0, 0.5, -above) * (0.55 + 0.45 * (1.0 - exp(-max(-above, 0.0) * under_fade)));
	ALBEDO = mix(ALBEDO, under_tint, t) * (1.0 - 0.6 * t);
	SPECULAR *= 1.0 - smoothstep(0.0, 0.5, t);
	ROUGHNESS = mix(ROUGHNESS, 1.0, t);
	EMISSION = mix(EMISSION, mix(base, under_tint, 0.6) * hemi * fill * 0.6, t);
}
