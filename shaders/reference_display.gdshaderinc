#include "res://shaders/reference_globals.gdshaderinc"
vec3 scene_linear_for_display(vec3 display_color) {
	// ZenScape's raw sky shader writes display RGB directly. Undo Godot's
	// output transform here so the same gradient survives its HDR pipeline.
	vec3 desired = mix(display_color / 12.92, pow((display_color + 0.055) / 1.055, vec3(2.4)), greaterThan(display_color, vec3(0.04045)));
	mat3 input_matrix = mat3(vec3(0.59719, 0.07600, 0.02840), vec3(0.35458, 0.90834, 0.13383), vec3(0.04823, 0.01566, 0.83777));
	mat3 output_matrix = mat3(vec3(1.60475, -0.10208, -0.00327), vec3(-0.53108, 1.10813, -0.07276), vec3(-0.07367, -0.00605, 1.07602));
	float w = 16.0 * 1.8;
	float white_scale = (w * (w + 0.0245786) - 0.000090537) / (w * (0.983729 * w + 0.432951) + 0.238081);
	vec3 y = inverse(output_matrix) * desired * white_scale;
	vec3 a = y * 0.983729 - 1.0;
	vec3 b = y * 0.432951 - 0.0245786;
	vec3 c = y * 0.238081 + 0.000090537;
	vec3 x = (-b - sqrt(max(b * b - 4.0 * a * c, vec3(0.0)))) / (2.0 * a);
	return max(inverse(input_matrix) * x / (1.8 * zs_exposure), vec3(0.0));
}

