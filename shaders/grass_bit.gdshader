shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// A bit of grass blade thrown up by the wash (scripts/endless/endless_motes.gd):
// both faces lit alike by the scene's light, as the pollen specks are
// (shaders/pollen_speck.gdshader), so a tumbling bit never flips dark. The
// instance colour is its own (sRGB, as the mesh's light-at-the-tip shading).
#include "res://shaders/reference_globals.gdshaderinc"
// Its own little light (1 in clear air, 0 under a storm's core, where the
// bit is darkened too).
uniform float self_light = 1.0;
varying vec3 tint;

void vertex() {
	tint = COLOR.rgb;
}

void fragment() {
	vec3 light = zs_key_irradiance / PI * zs_celestial_clear * zs_daylight + zs_hemi_sky * zs_hemi_energy / PI;
	// Under a storm's core darker too: the scene's key light here is not
	// the storm's dimmed sun (StormFront `shade`), and the bits glowed.
	ALBEDO = tint * (light * 0.85 + vec3(0.12) * self_light) * mix(0.35, 1.0, self_light);
}
