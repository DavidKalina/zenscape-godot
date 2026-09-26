shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/reference_surface_haze.gdshaderinc"
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D air_color : repeat_disable, filter_linear;
// Look pass (scripts/look_pass.gd). All zero leaves the composite untouched.
uniform float grade_strength = 0.0;
uniform vec3 grade_shadow = vec3(1.0);
uniform vec3 grade_highlight = vec3(1.0);
uniform float grade_saturation = 1.0;
uniform float vignette = 0.0;
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
	if (grade_strength > 0.0) {
		float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
		vec3 toned = color * mix(grade_shadow, grade_highlight, smoothstep(0.05, 0.85, luma));
		toned = mix(vec3(dot(toned, vec3(0.2126, 0.7152, 0.0722))), toned, grade_saturation);
		color = mix(color, toned, grade_strength);
	}
	if (vignette > 0.0) {
		vec2 centered = (SCREEN_UV - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
		color *= 1.0 - vignette * smoothstep(0.35, 1.0, length(centered) * 1.4);
	}
	COLOR = vec4(color, 1.0);
}
