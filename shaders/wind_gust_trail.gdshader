shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
// A gust's ribbons of moving air (scripts/wind_gust.gd), in gust_trail's
// look (shaders/gust_trail.gdshader). Each strand is laid along the whole
// lane (or out along a spoke of a burst) when the gust goes; only the stretch
// just behind the air's head shows, so the ribbons ride with it. UV.x is
// metres along the lane, UV.y across the ribbon; COLOR.r is how many metres
// the strand lags the head, COLOR.g its dash phase.
uniform float head = -1000.0;
uniform float trail_length = 8.0;
uniform float opacity = 0.0;
uniform float clock = 0.0;
uniform float width = 0.1;
// Dashes flow along the strand this many metres a second faster than it.
uniform float flow = 6.0;
uniform vec4 tint : source_color = vec4(0.82, 0.94, 0.9, 1.0);
varying float behind;
void vertex() {
	// Expand each ribbon toward camera-up, so it stays readable from above.
	vec3 camera_up_local = (inverse(MODEL_MATRIX) * vec4(INV_VIEW_MATRIX[1].xyz, 0.0)).xyz;
	behind = head - COLOR.r - UV.x;
	// The ribbon lifts and curls a little where the air is.
	float here = exp(-behind * behind / 18.0);
	VERTEX.y += sin(UV.x * 0.9 - clock * 5.0 + COLOR.g * 6.3) * 0.12 * here;
	VERTEX += camera_up_local * (UV.y - 0.5) * width * (0.6 + 0.4 * here);
}
void fragment() {
	float phase = fract(UV.x / 3.0 - clock * flow / 3.0 + COLOR.g);
	float stroke = smoothstep(0.02, 0.18, phase) * (1.0 - smoothstep(0.55, 0.7, phase));
	float edge = 1.0 - smoothstep(0.20, 0.50, abs(UV.y - 0.5));
	float window = smoothstep(-0.4, 0.6, behind) * (1.0 - smoothstep(trail_length * 0.35, trail_length, behind));
	ALBEDO = tint.rgb;
	ALPHA = edge * window * stroke * opacity;
}
