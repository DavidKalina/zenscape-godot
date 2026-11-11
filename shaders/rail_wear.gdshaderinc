#ifndef ZS_RAIL_WEAR_INC
#define ZS_RAIL_WEAR_INC
// The railroad spans' weathering (scripts/endless/rail_span.gd), over the
// vertex colours (each member's own tone) and the stone tile or timber grain.
// Needs kit_weather.gdshaderinc's noise (ZS_STONE_WEATHER defined, its
// weather itself may be off). Every term is tied to where it would happen:
// the sun and rain on the tops, soot under the arches and the deck, rain
// running down the upright faces, the wet and moss at the foot of a pier
// standing in the sea (`sea_y`) or flagged damp by its vertex alpha (0.6).
// `rail_wear_amt` 0 leaves the colours as they were. Worldwide noise is for
// the broad terms only (the world's coordinates run into the thousands); the
// fine ones use the piece's own frame and fade by pixel footprint.
uniform float rail_wear_amt : hint_range(0.0, 2.0) = 1.0;
uniform float sea_y = -40.0;
// Sky fill added to faces turned from the sun, so shade keeps its colour.
uniform float rail_fill = 0.3;

// The height of the surface's relief at `h`, laid on the normal `n` (view
// space) from the screen derivatives of the view position `vtx`.
vec3 rw_bump(vec3 n, vec3 vtx, float h, float strength) {
	vec3 sx = dFdx(vtx);
	vec3 sy = dFdy(vtx);
	vec3 r1 = cross(sy, n);
	vec3 r2 = cross(n, sx);
	float det = dot(sx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	return normalize(abs(det) * n - strength * grad);
}

#ifdef ZS_RAIL_STONE
float rail_wear(inout vec3 base, inout vec3 n, vec3 wn, vec3 wp, vec3 lp, vec4 col, vec3 vtx, vec2 uv) {
	float w = rail_wear_amt;
	float px = length(fwidth(lp));
	float f_mid = 1.0 - smoothstep(0.05, 0.25, px);
	float f_far = 1.0 - smoothstep(0.25, 0.9, px);
	float up = clamp(wn.y, 0.0, 1.0);
	float down = clamp(-wn.y, 0.0, 1.0);
	float side = 1.0 - abs(wn.y);
	float sunward = clamp(dot(wn, zs_key_direction), 0.0, 1.0);
	float lum0 = dot(base, vec3(0.2126, 0.7152, 0.0722));

	// Tone by pier and tier: a broad wash a pier across, another a tier tall,
	// a cool or warm cast; nothing like the even sheet of the vertex colour.
	float n_pier = kw_noise(wp * vec3(0.085, 0.05, 0.085) + 3.0);
	float n_tier = kw_noise(vec3(wp.x * 0.025, wp.y * 0.12, wp.z * 0.025) + 9.0);
	float n_cast = kw_noise(wp * 0.04 + 21.0);
	float tone = mix(0.62, 1.2, smoothstep(0.25, 0.75, n_pier)) * mix(0.8, 1.12, smoothstep(0.25, 0.75, n_tier));
	vec3 cast = mix(vec3(1.1, 1.0, 0.84), vec3(0.95, 0.97, 0.98), smoothstep(0.3, 0.7, n_cast));
	base *= mix(vec3(1.0), cast * tone, w);

	// Rain running down the upright faces in long dark streaks; heavier low
	// down where it has gathered, and a pale wash where it ran clean.
	float rs = kw_noise(vec3(lp.x * 3.2, lp.y * 0.16, lp.z * 3.2) + 5.0) * 0.6 + kw_noise(vec3(lp.x * 8.0, lp.y * 0.3, lp.z * 8.0) + 15.0) * 0.4 * f_mid;
	float streak = smoothstep(0.5, 0.78, rs) * side;
	float clean = smoothstep(0.22, 0.05, rs) * side;
	base *= 1.0 - 0.36 * streak * w;
	base *= 1.0 + 0.1 * clean * w;

	// Soot under the arches and the decks: what faces down, in patches.
	float soot_n = kw_noise(lp * 0.55 + 31.0) * 0.7 + kw_noise(lp * 2.1 + 3.0) * 0.3;
	float soot = smoothstep(0.2, 0.75, down) * smoothstep(0.25, 0.65, soot_n);
	base = mix(base, base * vec3(0.52, 0.49, 0.47), soot * 0.7 * w);

	// The sea's tide and wet and moss at a pier's foot (and the damp-flagged
	// stone along a river).
	float damp = 1.0 - smoothstep(0.0, 0.03, abs(col.a - 0.6));
	float ragged = (kw_noise(vec3(lp.x * 1.3, lp.y * 0.3, lp.z * 1.3) + 40.0) - 0.5) * 1.0;
	float h = wp.y - sea_y - ragged;
	float wet = max(1.0 - smoothstep(1.2, 1.9, h), damp);
	float line_dark = (1.0 - smoothstep(2.6, 3.4, h)) * smoothstep(0.9, 1.6, h);
	float low = max(1.0 - smoothstep(1.0, 8.0, h), damp * 0.8);
	float moss_n = kw_fbm(lp * vec3(0.9, 1.2, 0.9) + 61.0);
	float moss_fine = f_mid > 0.0 ? kw_noise(lp * 9.0 + 2.0) : 0.5;
	float moss = smoothstep(0.42, 0.68, moss_n) * low * (0.7 + 0.5 * moss_fine) * (1.0 - 0.4 * down);
	// Sparse moss on the shaded upright faces higher up too.
	float shade_side = 1.0 - smoothstep(0.0, 0.5, sunward);
	moss += smoothstep(0.7, 0.82, moss_n) * shade_side * (0.35 + 0.65 * up) * 0.6;
	moss = clamp(moss, 0.0, 1.0);
	base *= 1.0 - 0.45 * wet * w;
	base = mix(base, base * vec3(0.5, 0.6, 0.45), line_dark * 0.85 * w);
	vec3 moss_c = mix(vec3(0.075, 0.11, 0.035), vec3(0.14, 0.17, 0.05), smoothstep(0.3, 0.7, moss_fine));
	base = mix(base, moss_c, moss * 0.75 * w);

	// Shade keeps its colour: the faces turned from the sun a touch cooler
	// and greyer, not brown.
	float shade = 1.0 - sunward;
	base = mix(base, vec3(dot(base, vec3(0.2126, 0.7152, 0.0722))) * vec3(1.02, 1.0, 0.97), 0.16 * shade * w);

	// Relief: the weathering catches light; moss and soot are soft, the
	// wet band smooth.
	float rel = ((kw_noise(lp * 14.0) - 0.5) * f_mid * 0.5 + (kw_noise(lp * 4.0 + 8.0) - 0.5) * f_far * 0.8 + moss * 0.5 - streak * 0.2) * 0.012;
	n = rw_bump(n, vtx, rel * w, 1.0 * (0.3 + 0.7 * f_mid));
	float rough_n = (kw_noise(lp * 1.6 + 12.0) - 0.5) * 0.3;
	return (rough_n + moss * 0.15 + soot * 0.1 - wet * 0.3 - clean * 0.1) * w;
}
#else
float rail_wear(inout vec3 base, inout vec3 n, vec3 wn, vec3 wp, vec3 lp, vec4 col, vec3 vtx, vec2 uv) {
	float w = rail_wear_amt;
	float px = length(fwidth(lp));
	float f_mid = 1.0 - smoothstep(0.05, 0.25, px);
	float f_far = 1.0 - smoothstep(0.25, 0.9, px);
	float up = clamp(wn.y, 0.0, 1.0);
	float down = clamp(-wn.y, 0.0, 1.0);
	float side = 1.0 - abs(wn.y);
	float shelter = 1.0 - clamp(col.a, 0.0, 1.0);
	float sunward = clamp(dot(wn, zs_key_direction), 0.0, 1.0);
	float lum = dot(base, vec3(0.2126, 0.7152, 0.0722));
	// Old timber sits darker and browner than new-cut.
	base = mix(vec3(lum), base, 1.18) * 0.8;
	lum *= 0.8;

	// Silvered where the sun and rain reach (the tops and the open faces),
	// patchy along the run, and brown and dark where it is sheltered.
	float open = clamp((0.45 + 0.55 * up) * (1.0 - shelter * 1.4), 0.0, 1.0);
	float patch = smoothstep(0.25, 0.75, kw_noise(wp * vec3(0.11, 0.2, 0.11) + 13.0));
	float silver = open * mix(0.25, 1.0, patch);
	vec3 grey = vec3(lum) * vec3(1.05, 1.0, 0.93) * 1.1;
	base = mix(base, grey, silver * 0.42 * w);
	base *= mix(1.0, 0.7, clamp(shelter * 1.3, 0.0, 1.0) * w);
	base *= mix(vec3(1.0), vec3(1.06, 0.97, 0.88), clamp(shelter * 1.3, 0.0, 1.0) * w);

	// Dark stains running down from the joints and bolts: long, thin,
	// on the upright faces only.
	float st_a = kw_noise(vec3(lp.x * 5.0, lp.y * 0.14, lp.z * 5.0) + 5.0);
	float st_b = kw_noise(vec3(lp.x * 13.0, lp.y * 0.35, lp.z * 13.0) + 2.0);
	float stain = smoothstep(0.58, 0.82, st_a * 0.7 + st_b * 0.3 * f_mid) * side * (1.0 - 0.5 * down);
	base *= 1.0 - 0.42 * stain * w;
	base = mix(base, base * vec3(0.9, 0.78, 0.7), stain * 0.4 * w);

	// Soot and oil under the deck and under the members where the trains
	// pass: what faces down, blotched.
	float soot_n = kw_noise(lp * 0.5 + 31.0) * 0.7 + kw_noise(lp * 1.9 + 3.0) * 0.3;
	float soot = (smoothstep(0.3, 0.8, down) + shelter * 0.5) * smoothstep(0.3, 0.7, soot_n);
	base = mix(base, base * vec3(0.5, 0.47, 0.45), clamp(soot, 0.0, 1.0) * 0.6 * w);

	// Damp, dark and green, at the foot of timber standing near the sea.
	float h = wp.y - sea_y;
	float wet = 1.0 - smoothstep(0.5, 4.0, h);
	float moss = wet * smoothstep(0.4, 0.65, kw_fbm(lp * vec3(1.1, 1.5, 1.1) + 61.0));
	base *= 1.0 - 0.3 * wet * w;
	base = mix(base, vec3(0.08, 0.11, 0.04), moss * 0.55 * w);

	// Shade keeps its colour.
	float shade = 1.0 - sunward;
	base = mix(base, vec3(dot(base, vec3(0.2126, 0.7152, 0.0722))) * vec3(0.98, 0.99, 1.03), 0.12 * shade * w);

	// The deck's planks (the one wide face looking up, vertex alpha 1): laid
	// across the line, each its own tone, the butts and seams dark, oil and
	// soot along where the trains run.
	if (col.a > 0.97 && up > 0.9) {
		float pk = uv.x / 0.32;
		float pid = floor(pk);
		float row = floor(uv.y / 2.4);
		float ptone = tg_hash(vec2(pid, row));
		base *= mix(0.78, 1.14, ptone);
		base = mix(base, vec3(lum) * 1.1, 0.4 * step(0.72, tg_hash(vec2(pid + 5.0, row))));
		float seam = 1.0 - smoothstep(0.0, 0.012 + px * 1.5, min(fract(pk), 1.0 - fract(pk)) * 0.32);
		base *= 1.0 - 0.55 * seam * f_far * w;
		float oil = smoothstep(0.55, 0.8, tg_noise(vec2(uv.x * 0.12 + 2.0, uv.y * 0.9)) * 0.6 + tg_noise(vec2(uv.x * 0.4, uv.y * 4.0 + 7.0)) * 0.4);
		base = mix(base, base * vec3(0.5, 0.47, 0.44), oil * 0.55 * w);
	}

	// Relief: grain lifted, checks cut in, a worn tooth.
	float grain_h = (tg_noise(vec2(uv.x * 1.2 + 3.1, uv.y * 28.0)) - 0.5) * f_mid;
	float check = smoothstep(0.88, 0.96, tg_noise(vec2(uv.x * 0.22 + 1.7, uv.y * 16.0 + 4.0))) * f_mid;
	float rel = (grain_h * 0.35 - check * 1.2 + (kw_noise(lp * 4.0 + 8.0) - 0.5) * f_far * 0.5) * 0.01;
	n = rw_bump(n, vtx, rel * w, 0.9 * (0.3 + 0.7 * f_mid));
	// Dry silvered wood is dull, stained and damp wood smoother, with
	// variation along the member.
	float rough_n = (tg_noise(vec2(uv.x * 0.4 + 9.0, uv.y * 3.0)) - 0.5) * 0.3;
	return (rough_n + silver * 0.1 - stain * 0.12 - wet * 0.15 + check * 0.1) * w;
}
#endif
#endif
