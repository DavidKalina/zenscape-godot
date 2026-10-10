shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never;
// The rune serpent's trailing lights (scripts/rune_serpent.gd): two whiskers
// from the corners of its mouth and a fin of light off its tail's tip, each
// a soft ribbon laid by the script through where its root has been, turned
// to face the eye. UV.x runs 0 at the root to 1 at the tip, UV.y across;
// COLOR.a is the ribbon's own strength. Soft (the style's rule for what
// flows or glows): no hard edge anywhere, a few knots of light running out
// along it, brighter after dark.
uniform vec3 colour : source_color = vec3(1.0, 0.8, 0.5);
uniform float strength = 0.7;
uniform float night = 0.0;

void fragment() {
	float across = abs(UV.y * 2.0 - 1.0);
	float edge = 1.0 - smoothstep(0.2, 1.0, across);
	float along = UV.x;
	float fade = smoothstep(0.0, 0.06, along) * (1.0 - smoothstep(0.45, 1.0, along));
	float run = 0.8 + 0.2 * sin(along * 22.0 - TIME * 2.6);
	ALBEDO = colour * (1.15 + 0.9 * night) * run;
	ALPHA = clamp(COLOR.a * edge * edge * fade * strength, 0.0, 1.0);
}
