shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
// Explicit simulation time keeps the moving trails frozen with the wind field.
uniform float clock = 0.0;
uniform float opacity = 1.0;
uniform float width = 0.10;
uniform float flow_speed = 0.65;
uniform vec4 tint : source_color = vec4(0.79, 0.93, 0.88, 1.0);
void vertex() {
	// Expand each ribbon toward camera-up, so it stays readable from above.
	vec3 camera_up_local = (inverse(MODEL_MATRIX) * vec4(INV_VIEW_MATRIX[1].xyz, 0.0)).xyz;
	VERTEX += camera_up_local * (UV.y - 0.5) * width;
}
void fragment() {
	float phase = fract(UV.x - clock * flow_speed + COLOR.r);
	float stroke = smoothstep(0.03, 0.22, phase) * (1.0 - smoothstep(0.48, 0.55, phase));
	float edge = 1.0 - smoothstep(0.20, 0.50, abs(UV.y - 0.5));
	float ends = smoothstep(0.0, 0.12, UV.x) * (1.0 - smoothstep(0.82, 1.0, UV.x));
	ALBEDO = tint.rgb;
	ALPHA = edge * ends * stroke * opacity;
}
