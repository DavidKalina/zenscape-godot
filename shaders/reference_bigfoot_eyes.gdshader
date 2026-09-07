shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never;
#include "res://shaders/reference_display.gdshaderinc"

void fragment() {
	ALBEDO = scene_linear_for_display(vec3(1.0, 0.804, 0.333));
	ALPHA = (1.0 - smoothstep(0.03, 0.28, zs_daylight)) * 0.95;
}
