// Forward partner of scene_linear_for_display: Godot ACES with the fidelity
// scene's white point 16 and exposure convention. Output is display sRGB.
vec3 zs_scene_to_display(vec3 linear_color) {
	mat3 input_matrix = mat3(vec3(0.59719, 0.07600, 0.02840), vec3(0.35458, 0.90834, 0.13383), vec3(0.04823, 0.01566, 0.83777));
	mat3 output_matrix = mat3(vec3(1.60475, -0.10208, -0.00327), vec3(-0.53108, 1.10813, -0.07276), vec3(-0.07367, -0.00605, 1.07602));
	vec3 x = input_matrix * (linear_color * (1.8 * zs_exposure));
	vec3 mapped = (x * (x + 0.0245786) - 0.000090537) / (x * (0.983729 * x + 0.432951) + 0.238081);
	float w = 16.0 * 1.8;
	float white_scale = (w * (w + 0.0245786) - 0.000090537) / (w * (0.983729 * w + 0.432951) + 0.238081);
	vec3 color = clamp(output_matrix * mapped / white_scale, vec3(0.0), vec3(1.0));
	return mix(color * 12.92, 1.055 * pow(color, vec3(1.0 / 2.4)) - 0.055, greaterThan(color, vec3(0.0031308)));
}
// This must receive the COMPLETE lit water surface, not just hemisphere emission.
// Reflection and glints are then mixed before returning to native HDR storage.
vec3 zs_lake_display_composite(vec3 lit_water, vec3 sky, float reflection_weight, vec4 glint) {
	vec3 display_color = mix(zs_scene_to_display(lit_water), sky, reflection_weight);
	display_color = mix(display_color, glint.rgb, glint.a);
	return scene_linear_for_display(display_color);
}
// Source water.js: water reflection, ice reflection, then celestial glints.
vec3 zs_lake_ice_composite(vec3 lit_water, vec3 sky, float reflection_weight, vec3 ice_sky, float ice_weight, vec4 glint) {
	vec3 color = mix(zs_scene_to_display(lit_water), sky, reflection_weight);
	color = mix(color, ice_sky, ice_weight);
	color = mix(color, glint.rgb, glint.a);
	return scene_linear_for_display(color);
}
