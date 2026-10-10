shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
// A soft glow ribbon behind a stone plane seam (scripts/stone_plane_figure.gd),
// facing the chase camera: it fades across (v) and toward its ends (u). It
// stands in for a glow the game's look pass doesn't give at a distance;
// `strength` is the channel's level, scaled with the eye's distance.
uniform vec3 glow : source_color = vec3(1.0, 0.886, 0.659);
uniform float strength = 0.0;

void fragment() {
	float v = UV.y * 2.0 - 1.0;
	float across = pow(max(1.0 - abs(v), 0.0), 1.6);
	float ends = min(min(UV.x * 5.0, (1.0 - UV.x) * 5.0), 1.0);
	ALBEDO = glow * across * ends * strength;
}
