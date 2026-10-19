shader_type spatial;
// A raindrop's streak as the plane flies through it (scripts/plane_weather.gd
// `rain`): a soft line, thin and faint at its edges, its tail fading behind
// its head, fading in from the lens (near_fade m) and out into the rain's
// distance (far_fade m). The particle's colour varies each drop's strength.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.78, 0.82, 0.9, 0.2);
uniform float near_fade = 4.0;
uniform float far_fade = 30.0;

varying float seen_at;

void vertex() {
	seen_at = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	float across = abs(UV.x * 2.0 - 1.0);
	float body = 1.0 - across * across;
	// UV.y 0 at the head (leading, down the velocity), 1 at the tail.
	float tail = smoothstep(1.0, 0.25, UV.y) * smoothstep(0.0, 0.08, UV.y);
	float near = smoothstep(1.5, near_fade, seen_at);
	float far = 1.0 - smoothstep(far_fade * 0.4, far_fade, seen_at);
	ALBEDO = tint.rgb * COLOR.rgb;
	ALPHA = tint.a * COLOR.a * body * tail * near * far;
}
