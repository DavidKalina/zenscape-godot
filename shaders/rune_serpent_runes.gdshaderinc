#ifndef ZS_RUNE_SERPENT_RUNES
#define ZS_RUNE_SERPENT_RUNES
// The rune serpent's light (scripts/rune_serpent.gd), carved into the
// Olmec's weathered stone (shaders/olmec_stone.gdshader, `runes` on): runes
// in bands round the flanks where the grass snake has its dark bars, a
// glowing rune collar behind the head, a line of runes running back along
// the spine with its speed (`scroll`, as the stone plane's deck runes run:
// shaders/stone_plane_runes.gdshader), a sigil on the brow, the eyes, the
// mouth and the tongue. A slow pulse runs down the bands from head to tail.
//
// Per vertex (the serpent's mesh): CUSTOM0 (what the face is, the glyph
// cell's length over its height, metres back from the snout, the face's
// seed); CUSTOM1 (the face's own square: along 0..1 over the band's
// segment, across 0..1 over the face; its glyphs along; spare).
//   what: 0 stone, 1 spine, 2 rune band, 3 collar, 4 eye, 5 mouth,
//         6 tongue, 7 sigil.

#include "res://shaders/rune_glyphs.gdshaderinc"

// The runes' light: their colour, how bright (the script raises it at
// night), the eyes' colour and brightness.
uniform vec3 glow : source_color = vec3(1.0, 0.8, 0.5);
uniform float energy = 1.0;
uniform vec3 eye_glow : source_color = vec3(1.0, 0.86, 0.56);
uniform float eye_energy = 5.0;
// The eyes are the Olmec's (scripts/enemies/inhaler_head_look.gd): pale
// polished stone (its EYE_STONE), warming toward the light as they light
// (`eye_lit`, 0 at rest to 1 watching).
uniform vec3 eye_stone : source_color = vec3(0.62, 0.58, 0.48);
uniform float eye_lit = 0.0;
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
// The soft glow round each stroke in the stone: its share of the stroke's
// light and how far it spreads (in stroke widths, squared). The script
// raises both at night (night light round 1), so the runes keep a soft
// halo instead of blowing out to white.
uniform float halo = 0.32;
uniform float halo_spread = 10.0;

// A rune's light at `p` (its middle at 0): a bright cut stroke and a soft
// glow round it in the stone, antialiased over the pixel.
float rs_light(vec2 p, float h, float width) {
	float d = rs_rune(p, h);
	float aa = max(fwidth(d), 1e-4);
	float core = 1.0 - smoothstep(width - aa, width + aa, d);
	float soft = exp(-d * d / (width * width * halo_spread));
	return core + halo * soft;
}

// The light on a face: `info` its CUSTOM0, `face` its CUSTOM1, `t` the
// time. Returns how lit; `tint` and `boost` its colour and gain, `dark`
// the share its stone keeps (the eyes' sockets go dark).
float rs_serpent(vec4 info, vec4 face, float t, out vec3 tint, out float boost, out float dark) {
	float what = floor(info.x + 0.5);
	float along = info.z;
	vec2 uv = face.xy;
	float lit = 0.0;
	tint = glow;
	boost = 1.0;
	dark = 1.0;
	float wave = 0.5 + 0.5 * sin(6.28318 * (along / pulse_wave - t / pulse_period));
	float pulse = 1.0 - pulse_amp * 0.5 + pulse_amp * wave * wave;
	if (what == 1.0) {
		// The spine: a soft seam of light down its middle, and on it a rune
		// in about every other cell, running back toward the tail.
		float u = (along - scroll) / spine_cell;
		float id = floor(u);
		vec2 p = vec2((fract(u) - 0.5) * info.y, uv.y - 0.5) * vec2(1.0, 1.15);
		float seam = exp(-pow((uv.y - 0.5) / 0.07, 2.0)) * 0.22;
		float glyph = rs_hash(id + 3.0) < spine_share ? rs_light(p, rs_hash(id + 17.0), 0.05) : 0.0;
		lit = max(glyph, seam);
		lit *= 1.0 - smoothstep(spine_reach - 10.0, spine_reach, along);
		lit *= 0.8 + 0.4 * wave;
	} else if (what == 2.0 || what == 3.0 || what == 7.0) {
		// A band (or the collar, or the brow's sigil): the face's glyphs
		// side by side along its segment.
		float n = max(face.z, 1.0);
		float u = uv.x * n;
		float id = floor(u);
		vec2 p = vec2((fract(u) - 0.5) * info.y, uv.y - 0.5);
		float w = what == 7.0 ? 0.06 : 0.05;
		lit = rs_light(p * (what == 7.0 ? 1.0 : 1.12), rs_hash(info.w * 31.0 + id), w);
		lit *= pulse;
		if (what == 3.0) boost = 1.5;
		if (what == 7.0) boost = 1.2;
	} else if (what == 5.0) {
		lit = 0.5 + 0.25 * wave;
		boost = 0.8;
	} else if (what == 6.0) {
		lit = 1.0;
		tint = eye_glow;
		boost = 0.8;
	}
	return lit;
}

// The eye (what 4), carved as the Olmec's are (art/blender/inhaler_head/
// inhaler_head_build.py): an almond eyeball set back between a heavy upper
// lid, drooping at its outer (back) corner, and a thin lower lid, a deep
// crease round it. `e` the eye's square from its middle, -1..1, x back to
// front, y foot to brow (the patch the script lays on the face). Returns
// the eyeball's share; `crease` the dark carved line round it and under
// the lid, `lid` the upper lid's stone, `dome` the eyeball's swell (0 at
// its rim, 1 at its middle), `h` the carving's height (m).
float rs_eye(vec2 e, out float crease, out float lid, out float dome, out float h) {
	float aa = max(fwidth(e.x) + fwidth(e.y), 1e-4);
	// The opening: an almond, pinched at the ends, a little low.
	float r = length(vec2(e.x, (e.y + 0.06) * 1.6)) + 0.2 * abs(e.x);
	float open = 1.0 - smoothstep(0.78 - aa, 0.78 + aa, r);
	// The upper lid's edge, across the opening's top, drooping behind.
	float back = max(0.0, -e.x);
	float lid_y = 0.18 - 0.3 * back * back + 0.04 * (1.0 - e.x * e.x);
	float under = 1.0 - smoothstep(lid_y - aa, lid_y + aa, e.y);
	float ball = open * under;
	lid = open * (1.0 - under);
	dome = sqrt(max(0.0, 1.0 - (r / 0.78) * (r / 0.78)));
	// The crease: round the opening and along under the lid's edge, kept
	// a pixel and a half wide so it reads from a distance.
	float cw = max(0.06, aa * 1.5);
	crease = max(exp(-pow((r - 0.78) / cw, 2.0)), open * exp(-pow((e.y - lid_y) / cw, 2.0)));
	// The lower lid: a thin roll just under the opening.
	float low = exp(-pow((r - 0.9) / 0.07, 2.0)) * smoothstep(0.1, -0.25, e.y);
	// All of it gone by the patch's edge, where it is the face again.
	float frame = 1.0 - smoothstep(0.95, 1.15, r);
	h = (ball * (-0.03 + 0.06 * dome) + lid * 0.035 + low * 0.025 - crease * 0.05) * frame;
	crease *= frame;
	return ball;
}
#endif
