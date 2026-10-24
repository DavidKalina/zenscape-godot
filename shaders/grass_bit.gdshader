shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// A bit of grass blade thrown up by the wash (scripts/endless/endless_motes.gd):
// both faces lit alike by the scene's light, as the pollen specks are
// (shaders/pollen_speck.gdshader), so a tumbling bit never flips dark. The
// instance colour is its own (sRGB, as the mesh's light-at-the-tip shading).
#include "res://shaders/reference_globals.gdshaderinc"
varying vec3 tint;

void vertex() {
	tint = COLOR.rgb;
}

void fragment() {
	vec3 light = zs_key_irradiance / PI * zs_celestial_clear * zs_daylight + zs_hemi_sky * zs_hemi_energy / PI;
	ALBEDO = tint * (light * 0.85 + vec3(0.12));
}
