shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, skip_vertex_transform;
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/reference_growth.gdshaderinc"

uniform int kind = 0; // rain, snow, impact crown
uniform float intensity = 0.0;
uniform float top = 20.0;
uniform sampler2D stream_map : filter_nearest, repeat_disable;
uniform sampler2D ground_map : filter_nearest, repeat_disable;
uniform float ground_half = 16.0;
varying float opacity;
varying float age;

float surface_at(vec2 p) {
	return zs_surface_height(textureLod(ground_map, (p + ground_half) / (ground_half * 2.0), 0.0), textureLod(stream_map, (p + ground_half) / (ground_half * 2.0), 0.0));
}

void vertex() {
	vec4 drop = INSTANCE_CUSTOM;
	vec3 home = MODEL_MATRIX[3].xyz;
	float span = max(top - surface_at(home.xz), 0.5);
	// Solve the wind-carried landing column before choosing the shared rain /
	// splash cycle. This keeps their impact beat aligned on sloping terrain.
	if (kind != 1 && drop.x > -100.0) {
		for (int i = 0; i < 3; i++) {
			float floor_y = surface_at(home.xz + zs_wind_direction * zs_wind_strength * 0.16 * span);
			if (floor_y > -100.0) span = max(top - floor_y, 0.5);
		}
	}
	float fall = mod(zs_motion_time * drop.y + drop.z * span, span);
	vec3 p = vec3(home.x, top - fall, home.z);
	opacity = 0.0;
	age = 0.0;
	if (kind == 0) {
		float tilt = zs_wind_strength * 0.16;
		p.xz += zs_wind_direction * tilt * fall;
		vec3 direction = normalize(vec3(zs_wind_direction.x * tilt, -1.0, zs_wind_direction.y * tilt));
		float end = VERTEX.y;
		p -= direction * end * (0.12 + drop.y * 0.021);
		opacity = intensity * (0.10 + 0.26 * drop.w) * (1.0 - end * 0.6);
		if (p.y < surface_at(p.xz)) opacity = 0.0;
		VERTEX = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
	} else if (kind == 1) {
		float gust = zs_gust_field(home.xz);
		float hard = smoothstep(0.45, 0.85, gust) * min(zs_wind_strength, 2.0);
		vec2 drift = zs_wind_direction * zs_wind_strength * (0.32 + 0.5 * gust) * fall;
		float wander = 0.3 * (1.0 - 0.3 * hard);
		p.xz += drift + vec2(sin(zs_motion_time * 1.15 + drop.z * 43.0 + fall * 0.8), cos(zs_motion_time * 0.74 + drop.z * 91.0 + fall * 0.5)) * wander;
		opacity = intensity * (0.5 + 0.5 * drop.w) * (0.72 + 0.28 * hard);
		if (p.y < surface_at(p.xz)) opacity = 0.0;
		VERTEX = (VIEW_MATRIX * vec4(p, 1.0)).xyz + vec3(VERTEX.xy * (0.03 + 0.045 * drop.w), 0.0);
	} else {
		age = (fall / span) / 0.14;
		p.xz += zs_wind_direction * zs_wind_strength * 0.16 * span;
		p.y = surface_at(p.xz) + 0.03;
		opacity = (1.0 - age) * intensity * 0.32;
		if (age > 1.0 || intensity < 0.02) opacity = 0.0;
		VERTEX = (VIEW_MATRIX * vec4(p, 1.0)).xyz + vec3(VERTEX.xy * (0.05 + 0.30 * age), 0.0);
	}
	if (max(abs(p.x), abs(p.z)) > ground_half || surface_at(p.xz) < -100.0) opacity = 0.0;
}

void fragment() {
	float alpha = opacity;
	if (kind > 0) {
		float r = length(UV - 0.5) * 2.0;
		alpha *= kind == 1 ? (1.0 - smoothstep(0.35, 1.0, r)) : (1.0 - smoothstep(0.72, 1.0, r)) * smoothstep(0.30, 0.70, r);
	}
	if (alpha < 0.005) discard;
	vec3 tint = kind == 0 ? vec3(0.72, 0.80, 0.92) : (kind == 1 ? vec3(0.93, 0.95, 1.0) : vec3(0.85, 0.92, 1.0));
	// Transparent particles blend in the HDR scene before the output transform.
	ALBEDO = tint * mix(0.12, 1.0, zs_daylight);
	ALPHA = alpha;
}
