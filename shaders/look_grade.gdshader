shader_type canvas_item;
render_mode unshaded;
// The look pass grade on its own, for biomes whose native volumetric fog
// hides the display-fog blend that normally carries it.
#include "res://shaders/look_grade.gdshaderinc"
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	// No depth here to tell land from sky: the night look takes the whole frame.
	COLOR = vec4(zs_look_night(zs_look_grade(texture(scene_color, SCREEN_UV).rgb, SCREEN_UV, SCREEN_PIXEL_SIZE), 1.0), 1.0);
}
