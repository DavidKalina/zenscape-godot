shader_type canvas_item;
render_mode unshaded;
// The look pass grade on its own, for biomes whose native volumetric fog
// hides the display-fog blend that normally carries it; with the light
// shafts, from the same depth copy the blend reads (scripts/look_pass.gd).
#include "res://shaders/look_grade.gdshaderinc"
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D surface_depth : repeat_disable, filter_nearest;
#include "res://shaders/look_rays.gdshaderinc"

void fragment() {
	vec3 color = texture(scene_color, SCREEN_UV).rgb;
	color += zs_look_rays(SCREEN_UV, SCREEN_PIXEL_SIZE, FRAGCOORD.xy, 0.0);
	// No depth here to tell land from sky: the night look takes the whole frame.
	COLOR = vec4(zs_look_night(zs_look_grade(color, SCREEN_UV, SCREEN_PIXEL_SIZE), 1.0), 1.0);
}
