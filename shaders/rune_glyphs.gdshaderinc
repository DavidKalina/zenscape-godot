#ifndef ZS_RUNE_GLYPHS
#define ZS_RUNE_GLYPHS
// The rune language (the rune serpent's, shaders/rune_serpent_runes.gdshaderinc, and
// the ruins' night runes, shaders/ruin_runes.gdshader): a glyph's strokes as
// a distance field, picked by a hash.

float rs_hash(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

float rs_seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// The distance to a rune's strokes, `p` from its middle (its height runs
// -0.5..0.5 across the face), the glyph picked by `h`: a stave with
// branches (the commonest), two staves joined, or a lozenge on legs.
float rs_rune(vec2 p, float h) {
	float kind = fract(h * 7.31);
	int bits = int(fract(h * 13.7) * 64.0);
	float d;
	if (kind < 0.55) {
		d = rs_seg(p, vec2(0.0, -0.34), vec2(0.0, 0.34));
		if ((bits & 1) != 0) d = min(d, rs_seg(p, vec2(0.0, 0.34), vec2(0.2, 0.14)));
		if ((bits & 2) != 0) d = min(d, rs_seg(p, vec2(0.0, 0.34), vec2(-0.2, 0.14)));
		if ((bits & 4) != 0) d = min(d, rs_seg(p, vec2(0.0, 0.02), vec2(0.2, 0.2)));
		if ((bits & 8) != 0) d = min(d, rs_seg(p, vec2(0.0, 0.02), vec2(-0.2, -0.16)));
		if ((bits & 16) != 0) d = min(d, rs_seg(p, vec2(0.0, -0.34), vec2(0.2, -0.16)));
		if ((bits & 15) == 0) d = min(d, rs_seg(p, vec2(0.0, 0.12), vec2(0.2, -0.08)));
	} else if (kind < 0.8) {
		d = min(rs_seg(p, vec2(-0.16, -0.34), vec2(-0.16, 0.34)), rs_seg(p, vec2(0.16, -0.34), vec2(0.16, 0.34)));
		if ((bits & 1) != 0) d = min(d, rs_seg(p, vec2(-0.16, 0.2), vec2(0.16, -0.2)));
		else d = min(d, rs_seg(p, vec2(-0.16, 0.04), vec2(0.16, 0.04)));
		if ((bits & 2) != 0) d = min(d, rs_seg(p, vec2(-0.16, -0.18), vec2(0.16, 0.22)));
	} else {
		vec2 c = vec2(0.0, 0.1);
		d = min(min(rs_seg(p, c + vec2(0.0, 0.2), c + vec2(0.17, 0.0)), rs_seg(p, c + vec2(0.17, 0.0), c + vec2(0.0, -0.2))),
			min(rs_seg(p, c + vec2(0.0, -0.2), c + vec2(-0.17, 0.0)), rs_seg(p, c + vec2(-0.17, 0.0), c + vec2(0.0, 0.2))));
		if ((bits & 1) != 0) d = min(d, rs_seg(p, c + vec2(0.0, -0.2), vec2(0.18, -0.34)));
		if ((bits & 2) != 0 || (bits & 1) == 0) d = min(d, rs_seg(p, c + vec2(0.0, -0.2), vec2(-0.18, -0.34)));
	}
	return d;
}
#endif
