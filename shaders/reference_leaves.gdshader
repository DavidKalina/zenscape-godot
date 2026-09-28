shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, skip_vertex_transform;
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
varying float opacity;
varying vec3 leaf_color;

void vertex() {
	vec3 home = MODEL_MATRIX[3].xyz;
	vec4 leaf = INSTANCE_CUSTOM; // ground, speed, release phase, size
	float span = max(home.y - leaf.x, 0.3);
	float rest = span * (0.8 + leaf.z * 1.4);
	float cycle = mod(zs_motion_time * leaf.y + leaf.z * (span + rest) * 7.0, span + rest);
	float fall = min(cycle, span);
	float air = 1.0 - step(span, cycle);
	float g = zs_breeze_field(home.xz);
	float blow_shiver;
	vec2 blow = zs_blow_at(home.xz, leaf.z * 17.0, blow_shiver);
	float g0 = zs_gust_field_at(home.xz, zs_gust_distance - zs_gust_speed * cycle / leaf.y);
	float hard = smoothstep(0.5, 0.85, g) * min(zs_wind_strength, 2.0);
	float sw = sin(zs_motion_time * 2.1 + leaf.z * 37.0 + fall * 1.7);
	float sw2 = cos(zs_motion_time * 1.3 + leaf.z * 61.0 + fall * 1.1);
	float wob = mix(0.12 + 0.5 * hard, 1.0 + 0.5 * hard, air);
	vec2 drift = zs_wind_direction * zs_wind_strength * (0.28 + 0.4 * g) * fall + blow * 0.8 * fall;
	float lift = air * hard * 0.22 * fall / span;
	vec3 p = vec3(home.x + drift.x + sw * 0.3 * wob, max(home.y - fall + lift, leaf.x + 0.04), home.z + drift.y + sw2 * 0.3 * wob);
	vec3 view = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
	float radius = 0.045 + 0.05 * leaf.w;
	float pixels_per_unit = VIEWPORT_SIZE.y * abs(PROJECTION_MATRIX[1][1]) * 0.5;
	float size_pixels = clamp(radius * pixels_per_unit / max(-view.z, 0.1), 1.0, 14.0);
	VERTEX = view + vec3(VERTEX.xy * size_pixels * max(-view.z, 0.1) / pixels_per_unit, 0.0);
	float shed = smoothstep(0.12, 0.85, zs_autumn) * 0.72;
	float strip = 0.2 * min(zs_wind_strength, 2.0) * smoothstep(0.5, 0.85, g0);
	float go = smoothstep(leaf.z, leaf.z + 0.08, shed + strip);
	float resting = clamp((cycle - span) / rest, 0.0, 1.0);
	opacity = go * (1.0 - smoothstep(0.45, 1.0, resting)) * (0.75 + 0.25 * leaf.w);
	leaf_color = COLOR.rgb;
}

void fragment() {
	float radius = length(UV - 0.5) * 2.0;
	float alpha = smoothstep(1.0, 0.55, radius) * opacity;
	if (alpha < 0.01) discard;
	ALBEDO = scene_linear_for_display(clamp(leaf_color, vec3(0.0), vec3(0.98)));
	ALPHA = alpha;
}
