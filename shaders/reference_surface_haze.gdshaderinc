// aerial.js AERIAL_FOG_GLSL, applied after tone mapping as in Three.js.
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/reference_inversion_surface.gdshaderinc"
uniform sampler2D surface_depth : repeat_disable, filter_nearest;
uniform vec2 camera_planes;
uniform mat3 surface_camera_basis;
uniform bool surface_orthographic = false;
uniform vec2 surface_projection_scale;
uniform bool surface_inversion_enabled = true;
uniform float surface_density = 0.0;
uniform float aerial_gain = 1.0;
uniform vec3 surface_fog_color;
uniform vec3 aerial_sun_color;

vec3 zs_surface_haze(vec3 color, vec2 uv) {
	vec2 depth_sample = texture(surface_depth, uv).rg;
	float depth = depth_sample.r;
	if (depth <= 0.0) return color;
	float view_depth = camera_planes.x * camera_planes.y / (camera_planes.x + depth * (camera_planes.y - camera_planes.x));
	vec3 view_ray = vec3((uv.x * 2.0 - 1.0) * surface_projection_scale.x, (1.0 - uv.y * 2.0) * surface_projection_scale.y, -1.0);
	vec3 offset = surface_camera_basis * view_ray * view_depth;
	float ray_length = max(length(offset), 0.001);
	vec3 ray = offset / ray_length;
	vec3 ray_origin = zs_camera_position;
	if (surface_orthographic) {
		view_depth = mix(camera_planes.y, camera_planes.x, depth);
		vec3 lateral = surface_camera_basis * vec3(view_ray.xy, 0.0);
		ray_origin += lateral;
		ray = -surface_camera_basis[2];
		offset = lateral + ray * view_depth;
	}
	float multiplier = 1.0;
	vec3 fog_color = surface_fog_color;
	if (aerial_gain > 0.0) {
		float relief = max(zs_summit.y - 0.15, 1.0);
		float a = 1.6 / relief;
		float c = (ray_origin.y - 0.15 - 0.85 * relief) * a;
		float p = c + (surface_orthographic ? ray.y * view_depth : offset.y) * a;
		float mean_density = abs(p - c) > 0.001 ? (exp(-c) - exp(-p)) / (p - c) : exp(-c);
		multiplier = mix(1.0, clamp(mean_density, 0.4, 2.2), aerial_gain);
		vec3 tint = mix(vec3(0.88, 0.87, 0.87), vec3(1.10, 1.12, 1.18), smoothstep(-0.3, 0.3, ray.y));
		fog_color *= mix(vec3(1.0), tint, aerial_gain);
		float sun = max(dot(ray, zs_cloud_direction), 0.0);
		fog_color = mix(fog_color, aerial_sun_color, (pow(sun, 4.0) * 0.7 + sun * 0.3) * aerial_gain);
	}
	float d = surface_density * view_depth * multiplier;
	vec3 result = mix(color, fog_color, 1.0 - exp(-d * d));
	if (surface_inversion_enabled) {
		float inversion = zs_inversion_surface_amount(zs_camera_position + offset);
		result = mix(result, zs_inversion_color, inversion);
	}
	return mix(color, result, depth_sample.g);
}
