shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/reference_surface_haze.gdshaderinc"
#include "res://shaders/look_grade.gdshaderinc"
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D air_color : repeat_disable, filter_linear;
// Look pass light shafts (scripts/look_pass.gd). Zero leaves the composite untouched.
uniform float rays_strength = 0.0;
// xy: sun position in screen UV; z: shaft strength from sun height and cloud.
uniform vec3 rays_sun = vec3(0.5, 0.5, 0.0);
uniform vec3 rays_color = vec3(1.0);

float sky_at(vec2 uv) {
	return texture(surface_depth, uv).r <= 0.0 ? 1.0 : 0.0;
}

void fragment() {
	vec4 air = texture(air_color, SCREEN_UV);
	vec3 color = air.rgb + zs_surface_haze(texture(scene_color, SCREEN_UV).rgb, SCREEN_UV) * (1.0 - air.a);
	if (rays_strength > 0.0 && rays_sun.z > 0.0) {
		// Light shafts: open sky between here and the sun, gathered along the
		// line toward it. Ridges and crowns that block the sky cast the gaps.
		vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
		float reach = length((rays_sun.xy - SCREEN_UV) * aspect);
		float falloff = 1.0 - smoothstep(0.1, 0.85, reach);
		if (falloff > 0.0) {
			const int TAPS = 24;
			float jitter = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
			float open = 0.0;
			for (int i = 0; i < TAPS; i++) {
				float t = (float(i) + jitter) / float(TAPS);
				open += sky_at(mix(SCREEN_UV, rays_sun.xy, t * 0.8)) * (1.0 - t * 0.6);
			}
			open /= float(TAPS) * 0.76;
			color += rays_color * open * falloff * falloff * rays_strength * rays_sun.z * (1.0 - air.a * 0.6);
		}
	}
	color = zs_look_grade(color, SCREEN_UV, SCREEN_PIXEL_SIZE);
	color = zs_look_night(color, max(1.0 - sky_at(SCREEN_UV), air.a));
	COLOR = vec4(color, 1.0);
}
