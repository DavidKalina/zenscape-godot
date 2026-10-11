shader_type canvas_item;
// The isle card's band (scripts/isle_splash.gd): a soft dark wash behind
// the text, deepest through its middle, thinning out toward both ends and
// feathered top and bottom, so it has no edge.
uniform vec4 tint : source_color = vec4(0.035, 0.05, 0.08, 1.0);
uniform float strength = 0.5;
// Share of the half-width from the middle where it starts to thin, and the feather's share of
// the height at top and bottom.
uniform float fade_from = 0.55;
uniform float feather = 0.3;

void fragment() {
	float across = 1.0 - smoothstep(fade_from, 1.0, abs(UV.x * 2.0 - 1.0));
	across *= across;
	float down = smoothstep(0.0, feather, UV.y) * smoothstep(0.0, feather, 1.0 - UV.y);
	COLOR = vec4(tint.rgb, tint.a * strength * across * down);
}
