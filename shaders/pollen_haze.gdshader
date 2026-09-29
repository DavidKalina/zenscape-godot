shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// The soft haze over a pollen cloud (scripts/pollen_cloud.gd): camera-facing
// puffs of light with a round soft falloff, thinning as the cloud spreads and
// settles. Instance colour is the pollen's colour; its alpha the brightness.
// No fog: added over the whole quad, it painted each puff as a pale square.
#include "res://shaders/reference_globals.gdshaderinc"
varying float bright;
varying vec3 tint;

void vertex() {
	bright = COLOR.a;
	tint = COLOR.rgb;
	// Face the camera, keeping the instance's scale.
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 world = centre + (right * VERTEX.x + up * VERTEX.y) * size * 0.5;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float soft = exp(-d * d * 3.5) * (1.0 - smoothstep(0.8, 1.0, d));
	vec3 light = zs_key_irradiance / PI * zs_celestial_clear * zs_daylight + zs_hemi_sky * zs_hemi_energy / PI;
	ALBEDO = tint * (light * 0.6 + vec3(0.05)) * soft * bright;
}
