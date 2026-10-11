shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// The rune serpent's stone (scripts/rune_serpent.gd): faceted rings of the
// ruins' eroded basalt, coloured by their vertices and lit as the ruin
// stone is (shaders/ruin_stone.gdshader, shaders/folk_surface.gdshaderinc):
// the sky's hemisphere fills the shade and a faint sky rim, a plain Lambert
// terminator so each cut face reads as its own plane. Into it, light: runes
// carved in bands round the flanks where the grass snake has its dark bars,
// a glowing rune collar behind the head, a line of runes running back along
// the spine with its speed (`scroll`, as the stone plane's deck runes run:
// shaders/stone_plane_runes.gdshader), a sigil on the brow, the eyes, the
// mouth and the tongue. A slow pulse runs down the bands from head to tail.
//
// Per vertex: COLOR the stone's tone (linear); UV the face's own square
// (along 0..1 over the band's segment, across 0..1 over the face); UV2 the
// face's seed and its glyphs along; CUSTOM0 (what the face is, the glyph
// cell's length over its height, metres back from the snout, spare).
//   what: 0 stone, 1 spine, 2 rune band, 3 collar, 4 eye, 5 mouth,
//         6 tongue, 7 sigil.
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;

uniform float roughness_value : hint_range(0.0, 1.0) = 0.95;
// The eroded basalt's hemisphere fill and sky rim (scripts/ruin_stone_style.gd).
uniform float fill = 1.45;
uniform float rim = 0.2;
// The runes' light: their colour, how bright (the script raises it at
// night), the eyes' colour and brightness.
uniform vec3 glow : source_color = vec3(1.0, 0.8, 0.5);
uniform float energy = 1.0;
uniform vec3 eye_glow : source_color = vec3(1.0, 0.86, 0.56);
uniform float eye_energy = 5.0;
// The spine's runes: metres they have run back (integrated by the script),
// a glyph's length along the spine (m), and how far down the body they
// still show (m from the snout, fading out over the last few).
uniform float scroll = 0.0;
uniform float spine_cell = 1.5;
uniform float spine_reach = 78.0;
// The share of the spine's cells that bear a rune.
uniform float spine_share = 0.5;
// The pulse down the bands: metres apart, seconds a wave takes to pass a
// point, and how much it lifts them.
uniform float pulse_wave = 22.0;
uniform float pulse_period = 5.5;
uniform float pulse_amp = 0.55;
// How much a lit groove darkens the stone round its light (carved, not painted).
uniform float groove = 0.5;

varying vec4 info;

void vertex() {
	info = CUSTOM0;
}

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

// A rune's light at `p` (its middle at 0): a bright cut stroke and a soft
// glow round it in the stone, antialiased over the pixel.
float rs_light(vec2 p, float h, float width) {
	float d = rs_rune(p, h);
	float aa = max(fwidth(d), 1e-4);
	float core = 1.0 - smoothstep(width - aa, width + aa, d);
	float halo = exp(-d * d / (width * width * 10.0));
	return core + 0.32 * halo;
}

void fragment() {
	vec3 base = COLOR.rgb;
	float what = floor(info.x + 0.5);
	float along = info.z;
	float lit = 0.0;
	vec3 tint = glow;
	float boost = 1.0;
	float wave = 0.5 + 0.5 * sin(6.28318 * (along / pulse_wave - TIME / pulse_period));
	float pulse = 1.0 - pulse_amp * 0.5 + pulse_amp * wave * wave;
	if (what == 1.0) {
		// The spine: glyphs end to end, running back toward the tail.
		// The spine: a soft seam of light down its middle, and on it a rune
		// in about every other cell, running back toward the tail.
		float u = (along - scroll) / spine_cell;
		float id = floor(u);
		vec2 p = vec2((fract(u) - 0.5) * info.y, UV.y - 0.5) * vec2(1.0, 1.15);
		float seam = exp(-pow((UV.y - 0.5) / 0.07, 2.0)) * 0.22;
		float glyph = rs_hash(id + 3.0) < spine_share ? rs_light(p, rs_hash(id + 17.0), 0.05) : 0.0;
		lit = max(glyph, seam);
		lit *= 1.0 - smoothstep(spine_reach - 10.0, spine_reach, along);
		lit *= 0.8 + 0.4 * wave;
	} else if (what == 2.0 || what == 3.0 || what == 7.0) {
		// A band (or the collar, or the brow's sigil): the face's glyphs
		// side by side along its segment.
		float n = max(UV2.y, 1.0);
		float u = UV.x * n;
		float id = floor(u);
		vec2 p = vec2((fract(u) - 0.5) * info.y, UV.y - 0.5);
		float w = what == 7.0 ? 0.06 : 0.05;
		lit = rs_light(p * (what == 7.0 ? 1.0 : 1.12), rs_hash(UV2.x * 31.0 + id), w);
		lit *= pulse;
		if (what == 3.0) boost = 1.5;
		if (what == 7.0) boost = 1.2;
	} else if (what == 4.0) {
		// The eye: an almond of light in a dark socket (UV.x along the
		// head, UV.y across), brightest at its middle, with a slit pupil
		// standing across it, as a snake's.
		vec2 e = (UV - 0.5) * 2.0;
		float aa = fwidth(e.y) * 1.5;
		float almond = 1.0 - smoothstep(0.82 - aa, 0.82 + aa, length(vec2(e.x * 1.05, e.y * 1.3)) + 0.18 * abs(e.x));
		float slit = smoothstep(0.07, 0.15, abs(e.x) + 0.05 * e.y * e.y);
		lit = almond * mix(0.12, 0.7 + 0.3 * (1.0 - dot(e, e)), slit);
		tint = eye_glow;
		boost = eye_energy / max(energy, 0.05);
		base *= 0.2;
	} else if (what == 5.0) {
		lit = 0.5 + 0.25 * wave;
		boost = 0.8;
	} else if (what == 6.0) {
		lit = 1.0;
		tint = eye_glow;
		boost = 0.8;
	}
	base *= 1.0 - groove * clamp(lit, 0.0, 1.0) * step(what, 3.5);
	ALBEDO = base;
	ROUGHNESS = roughness_value;
	vec3 normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, normal.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = base * hemi * fill + mix(base, vec3(0.5), 0.4) * zs_hemi_sky * zs_hemi_energy * edge * rim;
	EMISSION += tint * lit * energy * boost;
}
