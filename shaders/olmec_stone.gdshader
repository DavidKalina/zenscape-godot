shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// The Olmec's weathered basalt (scripts/enemies/inhaler_head_look.gd `stone`;
// the headless body wears it too, so the figure reads as one stone). It is
// lit as the ruin kit's stone is (shaders/ruin_stone.gdshader and
// folk_surface.gdshaderinc: the sky's hemisphere as emission, a plain Lambert
// terminator) and coloured by the vertices as that is: COLOR.rgb is the kit's
// tone times the baked crevice occlusion, COLOR.a the occlusion alone.
// On top, a painted weathering in solid noise over the model's REST pose
// (UV and UV2 carry the rest position, so the grain rides on the stone while
// the body moves):
//   - broad mottled patches of lighter and darker stone,
//   - rain streaks run down the faces,
//   - grain: hand-stippled light and dark flecks, and small pits,
//   - hairline cracks and chipped facets on the worn high points,
//   - grime settled in the crevices and the undersides,
//   - lichen, a dry pale green and ochre, on sheltered tops.
// Every edge is soft and brushy (value noise bent through smoothsteps), never
// photographic; pits and cracks also nudge the normal so the light finds
// them. Fine layers fade with distance so they never shimmer; the patches,
// streaks, cracks and flecks carry the look at gameplay range.
// The rune serpent (scripts/rune_serpent.gd) wears it too, `runes` on: its
// runes, eyes, mouth and tongue (shaders/rune_serpent_runes.gdshaderinc,
// read from CUSTOM0 and CUSTOM1) cut into the weathered stone as lit
// grooves; its eyes carved as the Olmec's are, polished pale eyeballs under
// heavy lids (`rs_eye`); the mouth and tongue are not stone and stay smooth.

global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;

uniform float fill = 1.2;
uniform float rim = 0.14;
// Light added on top (the sky dragon's night sheen; 0 for the stone).
uniform vec3 emit_add = vec3(0.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.95;
// How much of the weathering (0 the old smooth stone).
uniform float weather : hint_range(0.0, 2.0) = 1.0;
uniform float bump_strength = 0.8;
uniform vec3 grime_mul = vec3(0.34, 0.33, 0.32);
uniform vec3 pale_mul = vec3(1.7, 1.62, 1.5);
uniform vec3 lichen_a : source_color = vec3(0.46, 0.52, 0.34);
uniform vec3 lichen_b : source_color = vec3(0.70, 0.60, 0.33);
// The rune serpent's light carved in (off for the Olmec), and how deep a
// lit groove is cut into the normal.
uniform bool runes = false;
uniform float rune_cut = 0.6;
// Pebbled scales carved all over (the rune serpent's pebbled look; 0 for
// the Olmec): how strong, a scale's size in the grain's units, and the
// head's plates (metres back from the snout where they end, how much
// bigger they are; needs `runes` for where a face lies).
uniform float pebble = 0.0;
uniform float pebble_size = 0.3;
uniform vec2 pebble_head = vec2(0.0, 1.0);
// A reptile's hide rather than stone (the sky dragon): 0 stone, 1 the beads
// become scales each with a colour of its own between scale_a and scale_b
// (multipliers), a dark seam and a satin sheen on the dome; no cracks, chips
// or lichen.
uniform float reptile : hint_range(0.0, 1.0) = 0.0;
uniform vec3 scale_a = vec3(0.7, 0.8, 0.78);
uniform vec3 scale_b = vec3(1.3, 1.1, 0.85);

#include "res://shaders/rune_serpent_runes.gdshaderinc"

varying vec3 rest;
varying vec4 rune_info;
varying vec4 rune_face;

void vertex() {
	rest = vec3(UV, UV2.x);
	rune_info = runes ? CUSTOM0 : vec4(0.0);
	rune_face = runes ? CUSTOM1 : vec4(0.0);
}

float h31(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

vec3 h33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x),
			mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x),
			mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.13 + 7.7) * 0.3 + vnoise(p * 4.37 + 3.1) * 0.15;
}

// Cellular: x the nearest point's distance, y the second's, z the nearest
// cell's own random number.
vec3 cells(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 9.0;
	float d2 = 9.0;
	float id = 0.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = h33(i + g);
				float d = length(g + o - f);
				if (d < d1) {
					d2 = d1;
					d1 = d;
					id = o.x;
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return vec3(d1, d2, id);
}

void fragment() {
	vec3 base = COLOR.rgb;
	float occ = clamp(COLOR.a, 0.0, 1.0);
	float w = weather;
	// The serpent's light: how lit, its colour and gain; the carved share
	// (the stone's runes, not the mouth or tongue, which stay smooth); its
	// eye, carved in the stone (the eyeball's share, the crease, the lid,
	// the eyeball's swell, the carving's height).
	vec3 r_tint = vec3(0.0);
	float r_boost = 0.0;
	float r_dark = 1.0;
	float r_lit = 0.0;
	float carve = 0.0;
	vec2 eye_e = vec2(0.0);
	float eye = 0.0;
	float e_crease = 0.0;
	float e_lid = 0.0;
	float e_dome = 0.0;
	float e_h = 0.0;
	if (runes) {
		r_lit = rs_serpent(rune_info, rune_face, TIME, r_tint, r_boost, r_dark);
		float what = floor(rune_info.x + 0.5);
		// (Worked out on every face, kept on the eye's, so its derivatives
		// are taken in step.)
		float is_eye = what == 4.0 ? 1.0 : 0.0;
		eye_e = (rune_face.xy - 0.5) * 2.0;
		eye = rs_eye(eye_e, e_crease, e_lid, e_dome, e_h) * is_eye;
		e_crease *= is_eye;
		e_lid *= is_eye;
		e_h *= is_eye;
		if (what > 4.5 && what < 6.5) w = 0.0;
		carve = clamp(r_lit, 0.0, 1.0) * step(what, 3.5);
		base *= r_dark;
	}
	// How big a pixel is on the stone (m): fine layers fade as it grows.
	float px = length(fwidth(rest));
	float f_fine = 1.0 - smoothstep(0.012, 0.05, px);
	float f_mid = 1.0 - smoothstep(0.05, 0.2, px);

	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float up = clamp(wn.y, 0.0, 1.0);
	float down = clamp(-wn.y, 0.0, 1.0);
	float crev = 1.0 - occ;

	// Broad patches: stone lighter and darker, in soft-edged washes.
	float broad = fbm(rest * 1.1 + 3.0);
	float patch = smoothstep(0.32, 0.68, broad);
	float tone = mix(0.7, 1.2, patch);
	// A second, smaller mottle across it.
	float mid = fbm(rest * 3.6 + 11.0);
	tone *= mix(0.86, 1.1, smoothstep(0.3, 0.7, mid));

	// Rain streaks: stretched down the stone, dark where they run, and
	// stronger toward the lower faces and under overhangs.
	float streak_n = vnoise(vec3(rest.x * 7.0, rest.y * 0.8, rest.z * 7.0) + 5.0)
			* 0.65 + vnoise(vec3(rest.x * 17.0, rest.y * 1.7, rest.z * 17.0) + 1.0) * 0.35;
	float streak = smoothstep(0.52, 0.82, streak_n) * (0.35 + 0.65 * (1.0 - up)) * (0.5 + 0.5 * f_mid + 0.5 * f_fine);
	tone *= 1.0 - streak * 0.5;

	// Grain: stippled flecks, two sizes, light and dark, plus pits.
	float g_big = vnoise(rest * 9.0 + 2.0);
	float g_mid = vnoise(rest * 21.0 + 8.0);
	float g_fine = vnoise(rest * 52.0 + 4.0);
	float fleck_light = smoothstep(0.7, 0.86, g_big) * 0.9 + smoothstep(0.74, 0.88, g_mid) * 0.7 * f_mid;
	float fleck_dark = smoothstep(0.34, 0.16, g_big) * 0.9 + smoothstep(0.28, 0.12, g_mid) * 0.8 * f_mid;
	float tooth = (g_fine - 0.5) * f_fine + (g_mid - 0.5) * f_mid * 0.6;
	float pit = smoothstep(0.2, 0.06, g_mid) * (0.4 + 0.6 * f_mid);
	tone *= 1.0 + fleck_light * 0.22 - fleck_dark * 0.24 + tooth * 0.3;

	// Pebbled scales: each cell a domed bead of its own tone, a dark seam
	// between; the seams kept a pixel and a half wide, the domes fading once
	// a pixel is near a scale across.
	float pb_seam = 0.0;
	float pb_h = 0.0;
	float pb_dome = 0.0;
	vec3 hue = vec3(1.0);
	if (pebble > 0.0) {
		float size = pebble_size * mix(1.0, pebble_head.y, 1.0 - smoothstep(pebble_head.x - 1.0, pebble_head.x, rune_info.z));
		vec3 pc = cells(rest / size + 51.0);
		float gap = pc.y - pc.x;
		float pb_far = 1.0 - smoothstep(0.25, 0.9, px / size);
		float seam_w = max(0.1, fwidth(gap) * 1.5);
		float dome = smoothstep(0.0, 0.5, gap);
		tone *= mix(1.0, mix(0.84, 1.12, pc.z) * mix(0.88, 1.07, dome * pb_far), pebble);
		pb_seam = (1.0 - smoothstep(0.0, seam_w, gap)) * pebble * (0.4 + 0.6 * pb_far);
		float pick = fract(pc.z * 5.31);
		hue = mix(vec3(1.0), mix(scale_a, scale_b, smoothstep(0.1, 0.9, pick)), reptile * pebble);
		// Lit scales' own shade: the dome's high side lighter, the seam's
		// low side darker, the colours fading to their mean at range.
		hue = mix(vec3(1.0), hue, 0.35 + 0.65 * pb_far);
		pb_dome = dome * pb_far * reptile * pebble;
		pb_h = sqrt(dome) * 0.2 * size * pebble * pb_far;
	}

	// Cracks: the cell borders, only where a slow mask lets them run, and
	// kept at least a pixel and a half wide so they read from a distance.
	vec3 cr = cells(rest * 2.1 + 17.0);
	float border = cr.y - cr.x;
	float crack_w = max(0.045, px * 3.0);
	float crack_mask = smoothstep(0.54, 0.76, fbm(rest * 1.6 + 29.0));
	float crack = (1.0 - smoothstep(0.0, crack_w, border)) * crack_mask;
	// A finer web of hairlines.
	vec3 cr2 = cells(rest * 6.5 + 3.0);
	float hair_w = max(0.07, px * 4.0);
	float hair_mask = smoothstep(0.55, 0.78, fbm(rest * 3.0 + 41.0));
	float hair = (1.0 - smoothstep(0.0, hair_w, cr2.y - cr2.x)) * hair_mask * (0.4 + 0.6 * f_mid);
	float cracks = clamp(crack + hair * 0.5, 0.0, 1.0) * (1.0 - reptile);

	// The worn high points: what stands clear of the crevices is paler, and
	// breaks into chipped facets, each its own tone, fresh-cut stone.
	float exposed = smoothstep(0.62, 0.98, occ);
	vec3 ch = cells(rest * 7.5 + 23.0);
	float chip_pick = step(0.5, fract(ch.z * 7.13));
	float chip_edge = smoothstep(0.0, 0.1, ch.y - ch.x);
	float worn = exposed * smoothstep(0.35, 0.7, fbm(rest * 2.2 + 13.0));
	float chip = worn * chip_pick;

	// Grime in the crevices and the joins, brushed in soft edges, and under
	// the overhangs.
	float grime_n = fbm(rest * 5.0 + 19.0);
	float grime = smoothstep(0.1, 0.65, crev * (0.6 + 0.8 * grime_n) + down * 0.2);

	// Assemble.
	vec3 c = base * mix(vec3(1.0), vec3(tone), w);
	float stone = 1.0 - reptile;
	c *= hue;
	c = mix(c, c * pale_mul, clamp(worn * 0.5 + chip * 0.5, 0.0, 1.0) * 0.8 * w * stone);
	c *= 1.0 - chip * (1.0 - chip_edge) * 0.35 * w * stone;
	c = mix(c, c * grime_mul, clamp(grime, 0.0, 1.0) * 0.8 * w);
	c = mix(c, c * 0.22, cracks * 0.82 * w * stone);
	c *= 1.0 - pb_seam * mix(0.55, 0.75, reptile);
	c *= 1.0 - pit * 0.35 * w;

	// Lichen: roundish rosettes and blooms on sheltered tops (not the crown
	// of the exposed stone, not the deep crevice).
	float li_zone = smoothstep(0.3, 0.6, up) * smoothstep(0.35, 0.7, occ) * (1.0 - exposed * 0.6);
	float li_bloom = smoothstep(0.58, 0.74, fbm(rest * 3.3 + 61.0));
	vec3 lc = cells(rest * 13.0 + 71.0);
	float li_dot = (1.0 - smoothstep(0.1, 0.34, lc.x)) * step(0.45, lc.z);
	float li = li_zone * clamp(li_bloom * (0.5 + 0.7 * li_dot) , 0.0, 1.0) * (1.0 - carve);
	vec3 li_col = mix(lichen_a, lichen_b, smoothstep(0.35, 0.65, vnoise(rest * 6.0 + 5.0)));
	li_col *= 0.55 + 0.45 * tone;
	c = mix(c, li_col, li * 0.78 * stone * w * clamp(base.g * 12.0 + 0.3, 0.0, 1.0));
	// A lit groove darkens the stone round its light (carved, not painted).
	c *= 1.0 - groove * carve;
	// The eye: the eyeball's polished pale stone, darker toward its rim and
	// in the lid's shadow, warming as it lights; the lid a worn high point;
	// the crease cut dark round them.
	vec3 ball = eye_stone * mix(0.6, 1.0, e_dome) * mix(1.0, 0.62, smoothstep(-0.25, 0.2, eye_e.y));
	ball = mix(ball, eye_glow, eye_lit * 0.5);
	c = mix(c, ball, eye);
	c = mix(c, c * pale_mul, e_lid * 0.3 * w);
	c *= 1.0 - 0.85 * e_crease;

	// The normal: pits and cracks cut in, the grain a little raised.
	float height = (tooth * 0.35 - pit * 0.6 - cracks * 0.9 + fleck_light * 0.1) * 0.02 * w * (1.0 - eye) - carve * rune_cut * 0.02;
	vec3 sx = dFdx(VERTEX);
	vec3 sy = dFdy(VERTEX);
	vec3 r1 = cross(sy, NORMAL);
	vec3 r2 = cross(NORMAL, sx);
	float det = dot(sx, r1);
	vec3 grad = sign(det) * (dFdx(height) * r1 + dFdy(height) * r2);
	float bump = bump_strength * (0.2 + 0.8 * f_mid);
	// The eye's carving, full strength at any range.
	vec3 grad_eye = sign(det) * (dFdx(e_h) * r1 + dFdy(e_h) * r2);
	// The scales' domes, at their own strength.
	float pb = pb_h * (1.0 - eye);
	vec3 grad_pb = sign(det) * (dFdx(pb) * r1 + dFdy(pb) * r2);
	NORMAL = normalize(abs(det) * NORMAL - bump * grad - grad_eye - grad_pb);

	ALBEDO = c;
	ROUGHNESS = mix(clamp(roughness_value + (pit + cracks) * 0.05 - worn * 0.1 - pb_dome * 0.3, 0.3, 1.0), 0.35, eye);
	METALLIC = 0.0;
	vec3 normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, normal.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = c * hemi * fill + mix(c, vec3(0.5), 0.4) * zs_hemi_sky * zs_hemi_energy * edge * rim;
	EMISSION += emit_add * c;
	EMISSION += r_tint * r_lit * energy * r_boost;
	EMISSION += eye_glow * eye_energy * eye * (0.45 + 0.55 * e_dome);
}
