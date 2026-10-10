shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// The lodestone itself (scripts/lodestone.gd): a faceted chip of sky island,
// a moss-grey top the miniature stands on and a keel of dark warm stone
// hanging under it, each face one flat facet coloured by its vertices and
// lit as the ruins and the folk are (shaders/folk_surface.gdshaderinc: the
// sky's hemisphere as emission, so it never goes black in shade). The lode
// shows in its veins: facets whose vertex alpha is under 1 glow a pale warm
// gold from within, softly, each breathing at its own pace, brighter as the
// stone hums; and the whole stone takes a faint warm rim as it hums.
#include "res://shaders/reference_globals.gdshaderinc"

uniform float hum = 0.0;
uniform float clock = 0.0;
uniform vec3 vein : source_color = vec3(1.0, 0.76, 0.42);
uniform float vein_glow = 0.5;
// The faint sky rim on faces seen edge on (0 for a big flat island top).
uniform float sheen = 0.3;
uniform float specular_amount = 0.3;
uniform float fill = 1.25;
uniform float rim = 0.25;

void fragment() {
	vec3 base = COLOR.rgb;
	ALBEDO = base;
	ROUGHNESS = 0.82;
	SPECULAR = specular_amount;
	vec3 normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, normal.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = base * hemi * fill + mix(base, vec3(0.5), 0.4) * zs_hemi_sky * zs_hemi_energy * edge * sheen;
	// The vein: alpha under 1 marks a facet of the lode; its breath runs
	// at the facet's own pace (its seed in UV.x).
	float lode = 1.0 - COLOR.a;
	if (lode > 0.0) {
		float facet = UV.x;
		float breath = 0.65 + 0.35 * sin(clock * mix(0.6, 1.4, facet) + facet * 30.0);
		EMISSION += vein * lode * vein_glow * breath * (0.35 + 0.9 * hum) * (0.6 + 0.4 * edge);
		ROUGHNESS = 0.55;
	}
	EMISSION += vein * edge * rim * hum;
}
