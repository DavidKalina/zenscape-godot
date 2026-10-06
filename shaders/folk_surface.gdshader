shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;
// The sky folk's cloth, skin, leather and brass (scripts/person_kit.gd). The
// world takes no ambient light (scripts/landscape_lighting.gd): its own
// surfaces add the sky's hemisphere as emission (reference_surface), so a
// plain material goes black out of the sun. The folk take that same
// hemisphere, a softer terminator (wrapped diffuse), and a faint sky rim so a
// figure in shade still reads against the ground.
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 1.0;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
uniform float coat : hint_range(0.0, 1.0) = 0.0;
uniform float coat_roughness : hint_range(0.0, 1.0) = 0.12;
// How much of the hemisphere fills the shade; above 1 lifts the folk a
// little over the land so they read as the focus up close.
uniform float fill = 1.6;
uniform float rim = 0.5;

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = coat_roughness;
	vec3 normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, normal.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 diffuse = albedo.rgb * (1.0 - metallic_value);
	EMISSION = diffuse * hemi * fill + mix(diffuse, vec3(0.5), 0.4) * zs_hemi_sky * zs_hemi_energy * edge * rim;
}
