shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 tint = vec4(1.0);
uniform float opacity = 0.0;
void fragment() {
	ALBEDO = tint.rgb;
	ALPHA = opacity;
}
