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
#ifdef ZS_NIGHT_STONE
// The ruins at night (night light round 2, docs/design/night-light/
// round2.md; set by scripts/kit_isle/kit_night_lights.gd, 0 elsewhere):
// the stone catches and holds the moon (`night_catch`: a cool lift on the
// faces turned to the moon and on the tops, so the masonry reads against
// the dark turf), and takes a soft warm bounce from the lanterns near it
// (`night_lamps` xyz, w its strength; within `night_bounce_reach` m).
global uniform vec3 zs_moon_direction;
global uniform vec4 zs_moon_light;
uniform float night_catch = 0.0;
uniform float night_bounce = 0.0;
uniform float night_bounce_reach = 7.0;
uniform vec3 night_bounce_colour : source_color = vec3(1.0, 0.66, 0.38);
uniform vec4 night_lamps[16];
varying vec3 world_at;
#endif

void vertex() {
	local = VERTEX;
#ifdef ZS_NIGHT_STONE
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
#endif
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
#ifdef ZS_SHELTER_BOUNCE
	// Under a roof (the ruins' halls): the vertex colour's alpha carries how
	// sheltered a face is (1 open air, 0 deep under the roof). The sky
	// that falls in through the gaps and the sunlit floor bounce round the
	// stone: a soft warm fill, strongest on faces that look down or across
	// (the undersides of beams, the columns' sides), so the carving reads.
	float shelter = 1.0 - COLOR.a;
	float facing = 0.75 + 0.45 * clamp(-normal.y, 0.0, 1.0) - 0.3 * clamp(normal.y, 0.0, 1.0);
	EMISSION += diffuse * mix(zs_hemi_sky, shelter_tint, 0.65) * zs_hemi_energy / PI * shelter_fill * facing * shelter;
#endif
#ifdef ZS_NIGHT_STONE
	if (night_catch > 0.0) {
		// The moon held in the stone: strongest on faces turned to it, a
		// little on every top, eased so a face's own plane still reads.
		float moonward = clamp(dot(normal, zs_moon_direction), 0.0, 1.0);
		float hold = moonward * moonward * 0.75 + clamp(normal.y, 0.0, 1.0) * 0.25 + 0.06;
		EMISSION += mix(diffuse, vec3(dot(diffuse, vec3(0.333))), 0.5) * zs_moon_light.rgb * night_catch * hold;
	}
	if (night_bounce > 0.0) {
		vec3 warm = vec3(0.0);
		for (int i = 0; i < 16; i++) {
			vec4 lamp = night_lamps[i];
			if (lamp.w <= 0.0) continue;
			vec3 to = lamp.xyz - world_at;
			float r = length(to);
			if (r >= night_bounce_reach) continue;
			float fall = 1.0 - r / night_bounce_reach;
			float turned = 0.35 + 0.65 * clamp(dot(normal, to / max(r, 0.001)), 0.0, 1.0);
			warm += vec3(lamp.w * fall * fall * turned);
		}
		EMISSION += diffuse * night_bounce_colour * night_bounce * warm;
	}
#endif
}
#endif
