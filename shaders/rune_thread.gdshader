shader_type spatial;
// The rune token's bead and thread (scripts/rune_token.gd): light only,
// added over what's behind. The thread fades out as it rises, so the stone
// hangs from nothing you can see the end of, and now and then a bright
// drop slides down it into the stone. The bead (`bead` 1) just glows.
// `glow` and `inner` are the glyph token's (scripts/glyph_pickup.gd).
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.45, 0.4);
uniform float glow = 0.35;
uniform float inner = 0.0;
// The token's size (m) and the thread's length (share of it).
uniform float size = 1.0;
uniform float thread_share = 1.1;
uniform float bead = 0.0;

varying float rise;

void vertex() {
	// 0 at the thread's foot (the bead), 1 at its top.
	rise = clamp(VERTEX.y / (size * thread_share) + 0.5, 0.0, 1.0);
}

void fragment() {
	float strength = 0.35 + 0.6 * glow + inner;
	if (bead > 0.5) {
		ALBEDO = tint * (0.9 + 1.2 * glow + inner);
	} else {
		float fade = pow(1.0 - rise, 2.2);
		float drop = mod(TIME * 0.45, 3.0);
		float d = exp(-pow((rise - (1.0 - drop)) / 0.05, 2.0));
		ALBEDO = tint * (fade * strength + d * 1.4 * (0.4 + fade));
	}
}
