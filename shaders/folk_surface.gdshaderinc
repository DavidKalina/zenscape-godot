#ifndef ZS_FOLK_SURFACE
#define ZS_FOLK_SURFACE
// The sky folk's cloth, skin, leather and brass (scripts/person_kit.gd), and
// their plane's paint, cloth and fittings (scripts/plane_figure.gd). The
// world takes no ambient light (scripts/landscape_lighting.gd): its own
// surfaces add the sky's hemisphere as emission (reference_surface), so a
// plain material goes black out of the sun. The folk take that same
// hemisphere, a softer terminator (wrapped diffuse), and a faint sky rim so a
// figure in shade still reads against the ground. Solids are drawn by
// shaders/folk_surface.gdshader; the scarf's two-sided ribbon, coloured by
// its vertices, by shaders/folk_ribbon.gdshader.
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
// Weathered paint: a soft mottle over the part's own shape (`wear_scale`
// patches a metre), lighter where the sun has faded it and duller where
// hands and weather wore the coat; 0 is new paint.
uniform float wear : hint_range(0.0, 1.0) = 0.0;
uniform float wear_scale = 14.0;

varying vec3 local;

void vertex() {
	local = VERTEX;
}

float wear_hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float wear_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(wear_hash(i), wear_hash(i + vec3(1, 0, 0)), f.x),
			mix(wear_hash(i + vec3(0, 1, 0)), wear_hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(wear_hash(i + vec3(0, 0, 1)), wear_hash(i + vec3(1, 0, 1)), f.x),
			mix(wear_hash(i + vec3(0, 1, 1)), wear_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void fragment() {
	vec3 base = albedo.rgb;
	float dull = 0.0;
	if (wear > 0.0) {
		vec3 p = local * wear_scale;
		float m = wear_noise(p) * 0.65 + wear_noise(p * 2.7 + 4.1) * 0.35;
		// Faded patches lift toward a chalky pale; worn ones lose their coat.
		base = mix(base, mix(base, vec3(0.93, 0.88, 0.78), 0.35), smoothstep(0.55, 0.85, m) * wear);
		base *= 1.0 - (0.5 - m) * 0.18 * wear;
		dull = smoothstep(0.35, 0.75, m) * wear;
	}
#ifdef ZS_FOLK_VERTEX_COLOR
	base *= COLOR.rgb;
#endif
	ALBEDO = base;
	ROUGHNESS = mix(roughness_value, 1.0, dull * 0.5);
	METALLIC = metallic_value;
	CLEARCOAT = coat * (1.0 - dull * 0.6);
	CLEARCOAT_ROUGHNESS = coat_roughness;
	vec3 normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, normal.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 diffuse = base * (1.0 - metallic_value);
	EMISSION = diffuse * hemi * fill + mix(diffuse, vec3(0.5), 0.4) * zs_hemi_sky * zs_hemi_energy * edge * rim;
}
#endif
