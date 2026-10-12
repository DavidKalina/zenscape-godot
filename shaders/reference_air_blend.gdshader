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

// Night light round 3 (docs/design/night-light/round3.md): up close the
// night grade's rod grey takes only NIGHT_NEAR_GRADE of its share, so the
// near turf keeps its season's hue under the moon's blue (the turf itself
// is darkened for it in reference_surface.gdshader, NIGHT_NEAR_*), easing
// to the full share by NIGHT_NEAR_GRADE_FAR m, where the land is as before.
const float NIGHT_NEAR_GRADE = 0.55;
const vec2 NIGHT_NEAR_GRADE_FAR = vec2(12.0, 70.0);

float night_near_at(vec2 uv) {
	float depth = texture(surface_depth, uv).r;
	if (depth <= 0.0 || surface_orthographic) return 0.0;
	float view_depth = camera_planes.x * camera_planes.y / (camera_planes.x + depth * (camera_planes.y - camera_planes.x));
	vec3 view_ray = vec3((uv.x * 2.0 - 1.0) * surface_projection_scale.x, (1.0 - uv.y * 2.0) * surface_projection_scale.y, -1.0);
	return 1.0 - smoothstep(NIGHT_NEAR_GRADE_FAR.x, NIGHT_NEAR_GRADE_FAR.y, length(view_ray) * view_depth);
}

void fragment() {
	// Under the cloud sea (glide_below) the plate's air, marched from the
	// plate's ground up, would stand as a wall of fog three hundred metres
	// thick over the lower world: there it is left out.
	vec4 air = texture(air_color, SCREEN_UV) * (1.0 - glide_below);
	vec3 color = air.rgb + zs_surface_haze(texture(scene_color, SCREEN_UV).rgb, SCREEN_UV) * (1.0 - air.a);
	color += zs_look_rays(SCREEN_UV, SCREEN_PIXEL_SIZE, FRAGCOORD.xy, air.a);
	color = zs_look_grade(color, SCREEN_UV, SCREEN_PIXEL_SIZE);
	float land = max(1.0 - sky_at(SCREEN_UV), air.a);
	color = zs_look_night(color, land * mix(1.0, NIGHT_NEAR_GRADE, night_near_at(SCREEN_UV) * (1.0 - air.a)));
	COLOR = vec4(color, 1.0);
}
