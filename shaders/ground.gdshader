shader_type spatial;
render_mode diffuse_burley;

uniform vec2 brush_center = vec2(0.0);
uniform float brush_radius = 2.0;
uniform bool brush_visible = false;
uniform vec4 brush_color : source_color = vec4(1.0, 0.91, 0.61, 1.0);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 color = COLOR.rgb;
	if (brush_visible) {
		float distance_to_brush = length(world_position.xz - brush_center);
		float aa = max(fwidth(distance_to_brush), 0.025);
		float ring = 1.0 - smoothstep(0.025, 0.025 + aa, abs(distance_to_brush - brush_radius));
		float fill = (1.0 - smoothstep(0.0, brush_radius, distance_to_brush)) * 0.13;
		color = mix(color, brush_color.rgb, max(ring * 0.9, fill));
	}
	ALBEDO = color;
	ROUGHNESS = 0.95;
}
