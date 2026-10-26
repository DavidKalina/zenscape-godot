shader_type canvas_item;
render_mode unshaded;
// The near-miss HUD's gilt numbers (scripts/endless/near_miss_hud_glyph.gd):
// cream at the top of the glyphs to dark ochre at their foot, as the title's
// gilt (shaders/title_gilt.gdshader), times a tint (the multiplier's heat),
// washed to white by `flash`. `top` and `height` are the glyphs' band in the
// label's own units.
uniform float top = 0.0;
uniform float height = 64.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float flash = 0.0;
varying float glyph_y;
void vertex() {
	glyph_y = (VERTEX.y - top) / max(height, 1.0);
}
void fragment() {
	vec4 ink = texture(TEXTURE, UV) * COLOR;
	float t = clamp(glyph_y, 0.0, 1.0);
	vec3 gilt = t < 0.45 ? mix(vec3(1.0,0.973,0.906), vec3(0.929,0.839,0.620), t/0.45) : mix(vec3(0.929,0.839,0.620), vec3(0.659,0.502,0.282), (t-0.45)/0.55);
	vec3 c = mix(gilt * tint.rgb, vec3(1.0), flash);
	COLOR = vec4(ink.rgb * c, ink.a);
}
