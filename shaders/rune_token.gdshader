shader_type spatial;
// The rune token (scripts/rune_token.gd): the diamond's flat facets in its
// tint, glowing more toward their edges as seen (a fresnel rim), and the
// ring (band 1) glowing through. `glow` and `inner` are the glyph token's,
// set by scripts/glyph_pickup.gd by day, by night and in the pickup.
render_mode cull_back;

uniform vec3 tint : source_color = vec3(0.6, 0.86, 0.95);
uniform vec3 glow_tint : source_color = vec3(0.8, 0.95, 1.0);
uniform float glow = 0.35;
uniform float inner = 0.0;
// 0 the diamond, 1 the ring.
uniform float band = 0.0;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.0);
	ALBEDO = tint * mix(0.55, 0.3, band);
	ROUGHNESS = 0.22;
	SPECULAR = 0.8;
	float lit = glow * (0.4 + 1.3 * rim + 1.2 * band) + inner * 2.0 + 0.12;
	EMISSION = glow_tint * lit;
}
