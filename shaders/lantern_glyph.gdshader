shader_type canvas_item;
// A Lantern glyph (scripts/lantern_style.gd): a dark rim hugging the strokes,
// a faint glow in the glyph's own tint round that, and the glyph on top, so a
// warm-white line reads over bright fog and snow as well as over dark pines.
// Offsets are in UV of the 48-unit glyph box: 0.03 is about 1.5 px at a 56 slot.
uniform vec4 rim_color : source_color = vec4(0.031, 0.071, 0.094, 0.78);
uniform float rim = 0.032;
uniform float glow = 0.075;
uniform float glow_strength = 0.4;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 glyph = texture(TEXTURE, UV);
	// Built-in samplers cannot be passed to functions, so the taps are inline.
	float widest = 0.0;
	float spread = 0.0;
	for (int i = 0; i < 12; i++) {
		vec2 dir = vec2(cos(float(i) * 0.5235988), sin(float(i) * 0.5235988));
		widest = max(widest, max(texture(TEXTURE, UV + dir * rim).a, texture(TEXTURE, UV + dir * rim * 0.5).a));
		spread += texture(TEXTURE, UV + dir * glow).a / 12.0;
	}
	float rim_a = widest * rim_color.a;
	float glow_a = spread * glow_strength;
	// Glow, then rim over it, then the glyph over both.
	vec3 rgb = tint.rgb;
	float a = glow_a;
	float out_a = rim_a + a * (1.0 - rim_a);
	rgb = (rim_color.rgb * rim_a + rgb * a * (1.0 - rim_a)) / max(out_a, 1e-4);
	a = out_a;
	float g = glyph.a;
	out_a = g + a * (1.0 - g);
	rgb = (glyph.rgb * tint.rgb * g + rgb * a * (1.0 - g)) / max(out_a, 1e-4);
	COLOR = vec4(rgb, out_a * tint.a);
}
