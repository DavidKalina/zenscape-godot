shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/reference_surface_haze.gdshaderinc"
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D air_color : repeat_disable, filter_linear;
void fragment() {
	vec4 air = texture(air_color, SCREEN_UV);
	COLOR = vec4(air.rgb + zs_surface_haze(texture(scene_color, SCREEN_UV).rgb, SCREEN_UV) * (1.0 - air.a), 1.0);
}
