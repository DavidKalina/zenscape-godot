shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// The glow in a gothic glyph stone's carving (scripts/ruin_kit.gd): the
// cut's floor and walls, dark stone giving off a pale sky-green light that
// breathes slowly; by day a faint lit thread, by night (`night`, 0 to 1)
// enough to read across the dark, as if the ruin were quietly awake. The
// vertex colour's red is how much a face gives (the floor all of it, the
// walls less).
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;

uniform vec4 albedo : source_color = vec4(0.13, 0.15, 0.16, 1.0);
uniform vec4 glow : source_color = vec4(0.62, 0.95, 0.88, 1.0);
uniform float day_energy = 0.32;
uniform float night_energy = 2.6;
uniform float night : hint_range(0.0, 1.0) = 0.0;
// Seconds a breath takes, and how deep it goes (a share of the glow).
uniform float breath = 8.0;
uniform float breath_depth = 0.25;

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 1.0;
	vec3 normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, normal.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float pulse = 1.0 - breath_depth * (0.5 + 0.5 * sin(TIME * TAU / breath));
	float energy = mix(day_energy, night_energy, night) * pulse * COLOR.r;
	EMISSION = albedo.rgb * hemi + glow.rgb * energy;
}
