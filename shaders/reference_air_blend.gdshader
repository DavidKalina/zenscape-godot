shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/reference_surface_haze.gdshaderinc"
#include "res://shaders/look_grade.gdshaderinc"
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D air_color : repeat_disable, filter_linear;
// Look pass light shafts (scripts/look_pass.gd).
#include "res://shaders/look_rays.gdshaderinc"

float sky_at(vec2 uv) {
	return texture(surface_depth, uv).r <= 0.0 ? 1.0 : 0.0;
}

void fragment() {
	// Under the cloud sea (glide_below) the plate's air, marched from the
	// plate's ground up, would stand as a wall of fog three hundred metres
	// thick over the lower world: there it is left out.
	vec4 air = texture(air_color, SCREEN_UV) * (1.0 - glide_below);
	vec3 color = air.rgb + zs_surface_haze(texture(scene_color, SCREEN_UV).rgb, SCREEN_UV) * (1.0 - air.a);
	color += zs_look_rays(SCREEN_UV, SCREEN_PIXEL_SIZE, FRAGCOORD.xy, air.a);
	color = zs_look_grade(color, SCREEN_UV, SCREEN_PIXEL_SIZE);
	color = zs_look_night(color, max(1.0 - sky_at(SCREEN_UV), air.a));
	COLOR = vec4(color, 1.0);
}
