#ifndef ZS_KIT_WEATHER
#define ZS_KIT_WEATHER
// The ruin kit's weathered basalt (shaders/ruin_stone.gdshader, with
// ZS_STONE_WEATHER): the Olmec's weathering (shaders/olmec_stone.gdshader,
// docs/design/roguelike/olmec-weathered.md) brought onto the kit's blocks,
// so the ruins and the Olmec read as one stone. Painted in solid noise over
// the piece's own frame (the kit's stone stands still, so its model space is
// its rest pose), on top of the kit's face colours:
//   - broad washes, lighter and darker, a wall's length and a block's,
//   - rain streaks run down the upright faces,
//   - grain: stippled light and dark flecks, and small pits,
//   - sparse cracks, and the worn high points (the tops and the worn
//     arrises and chips the eroded look cuts) paler, broken in chipped facets,
//   - grime under the overhangs, in the halls' shelter and at the foot of
//     the streaks,
//   - dry lichen, pale green and ochre, in blooms on the tops.
// The kit carries no baked crevice occlusion (its vertex alpha is the halls'
// shelter), so the crevices are read from the facing (undersides), the
// shelter, and the arrises from the faces the erosion tipped between a top
// and a side. Fine layers fade by pixel footprint so whole isles never
// shimmer; the washes and streaks carry it at gameplay range. Cost: at most
// two cellular lookups a pixel (cracks, chips), each taken only where its
// mask is on and near enough to see; everything else is value noise.

// How much (0 the kit's old smooth stone; RuinKit sets it from
// --kit-stone=, scripts/ruin_stone_style.gd `weather`).
uniform float stone_weather : hint_range(0.0, 2.0) = 0.0;
uniform float weather_bump = 0.7;
// How strong the washes and flecks, the rain streaks and the cracks are (1
// the ruin stone's; the isles' rock, KitLook, takes them stronger).
uniform float weather_tone = 1.0;
uniform float weather_streak = 1.0;
uniform float weather_crack = 1.0;
uniform vec3 weather_grime = vec3(0.4, 0.39, 0.38);
uniform vec3 weather_pale = vec3(1.55, 1.5, 1.4);
uniform vec3 weather_lichen_a : source_color = vec3(0.46, 0.52, 0.34);
uniform vec3 weather_lichen_b : source_color = vec3(0.70, 0.60, 0.33);

float kw_h31(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

vec3 kw_h33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float kw_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(kw_h31(i), kw_h31(i + vec3(1, 0, 0)), f.x),
			mix(kw_h31(i + vec3(0, 1, 0)), kw_h31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(kw_h31(i + vec3(0, 0, 1)), kw_h31(i + vec3(1, 0, 1)), f.x),
			mix(kw_h31(i + vec3(0, 1, 1)), kw_h31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float kw_fbm(vec3 p) {
	return kw_noise(p) * 0.6 + kw_noise(p * 2.13 + 7.7) * 0.4;
}

// Cellular: x the nearest point's distance, y the second's, z the nearest
// cell's own random number.
vec3 kw_cells(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 9.0;
	float d2 = 9.0;
	float id = 0.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = kw_h33(i + g);
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

// Weathers colour `c` (linear) at rest point `p` (m); `n` the view-space
// normal (bumped in place), `wn` the world normal, `vtx` the view-space
// position, `shelter` 0 open air to 1 under a roof. Returns how much
// rougher the stone is.
float kit_weather(inout vec3 c, inout vec3 n, vec3 wn, vec3 p, vec3 vtx, float shelter, float w) {
	float px = length(fwidth(p));
	float f_fine = 1.0 - smoothstep(0.012, 0.05, px);
	float f_mid = 1.0 - smoothstep(0.05, 0.2, px);
	float f_far = 1.0 - smoothstep(0.2, 0.6, px);

	float up = clamp(wn.y, 0.0, 1.0);
	float down = clamp(-wn.y, 0.0, 1.0);
	float side = 1.0 - abs(wn.y);
	// The arrises and chips the erosion cut (faces tipped between a top and
	// a side), and the tops: the stone's high points.
	float arris = smoothstep(0.22, 0.45, wn.y) * (1.0 - smoothstep(0.8, 0.93, wn.y));
	float exposed = max(arris, smoothstep(0.85, 0.97, up) * 0.45) * (1.0 - shelter);
	float crev = clamp(down * 0.75 + shelter * 0.6, 0.0, 1.0);

	// Broad washes: a wall's length, then a block's.
	float tone = mix(0.84, 1.12, smoothstep(0.3, 0.7, kw_noise(p * 0.22 + 41.0)));
	tone *= mix(0.76, 1.16, smoothstep(0.3, 0.7, kw_fbm(p * 0.9 + 3.0)));
	tone *= mix(0.9, 1.08, smoothstep(0.3, 0.7, kw_noise(p * 3.2 + 11.0)) * f_far + 0.5 * (1.0 - f_far));

	// Rain streaks down the upright faces, heavier lower on the stone and
	// under the overhangs; their feet gather grime.
	float streak_n = kw_noise(vec3(p.x * 5.0, p.y * 0.6, p.z * 5.0) + 5.0) * 0.65
			+ kw_noise(vec3(p.x * 13.0, p.y * 1.3, p.z * 13.0) + 1.0) * 0.35 * f_mid;
	float streak = smoothstep(0.52, 0.8, streak_n) * side * (0.55 + 0.45 * f_far);
	tone *= 1.0 - clamp(streak * 0.42 * weather_streak, 0.0, 0.85);

	// Grain: flecks light and dark, two sizes, and pits; the finer ones
	// only near enough to see.
	float g_big = 0.5;
	float g_mid = 0.5;
	float g_fine = 0.5;
	if (f_far > 0.0) g_big = kw_noise(p * 8.0 + 2.0);
	if (f_mid > 0.0) g_mid = kw_noise(p * 19.0 + 8.0);
	if (f_fine > 0.0) g_fine = kw_noise(p * 47.0 + 4.0);
	float fleck_light = (smoothstep(0.7, 0.86, g_big) * 0.9 + smoothstep(0.74, 0.88, g_mid) * 0.7 * f_mid) * f_far;
	float fleck_dark = (smoothstep(0.3, 0.12, g_big) * 0.7 + smoothstep(0.26, 0.1, g_mid) * 0.8 * f_mid) * f_far;
	float tooth = (g_fine - 0.5) * f_fine + (g_mid - 0.5) * f_mid * 0.6;
	float pit = smoothstep(0.16, 0.04, g_mid) * f_mid;
	tone *= 1.0 + fleck_light * 0.2 - fleck_dark * 0.16 + tooth * 0.28;

	// Cracks: cell borders, only where a slow mask lets them run, kept a
	// pixel and a half wide, gone once a pixel is a hand across.
	float cracks = 0.0;
	float crack_mask = smoothstep(0.62 - 0.12 * (weather_crack - 1.0), 0.8, kw_noise(p * 0.8 + 29.0)) * f_far;
	if (crack_mask > 0.0) {
		vec3 cr = kw_cells(p * 1.6 + 17.0);
		float crack_w = max(0.04, px * 1.6 * 1.5);
		cracks = (1.0 - smoothstep(0.0, crack_w, cr.y - cr.x)) * crack_mask;
	}

	// The worn high points: paler, broken into chipped facets of fresh-cut
	// stone near to.
	float worn = exposed * smoothstep(0.3, 0.65, kw_noise(p * 1.7 + 13.0));
	float chip = 0.0;
	float chip_edge = 1.0;
	if (worn > 0.0 && f_mid > 0.0) {
		vec3 ch = kw_cells(p * 5.0 + 23.0);
		chip = worn * step(0.5, fract(ch.z * 7.13)) * f_mid;
		chip_edge = smoothstep(0.0, 0.1, ch.y - ch.x);
	}

	// Grime: under the overhangs, in the halls, and where the streaks end.
	float grime_n = kw_noise(p * 2.6 + 19.0);
	float grime = smoothstep(0.1, 0.65, crev * (0.6 + 0.8 * grime_n) + streak * 0.25 * (1.0 - up));

	// Assemble.
	tone = max(0.2, 1.0 + (tone - 1.0) * weather_tone);
	vec3 o = c * mix(1.0, tone, w);
	o = mix(o, o * weather_pale, clamp(worn * 0.45 + chip * 0.4, 0.0, 1.0) * 0.75 * w);
	o *= 1.0 - chip * (1.0 - chip_edge) * 0.3 * w;
	o = mix(o, o * weather_grime, clamp(grime, 0.0, 1.0) * 0.75 * w);
	o = mix(o, o * 0.25, cracks * 0.75 * w);
	o *= 1.0 - pit * 0.22 * w;

	// Lichen: blooms of rosettes on the tops, not on the worn crowns or under
	// a roof; the rosettes broken up by fine noise near to.
	float li_zone = smoothstep(0.45, 0.8, up) * (1.0 - shelter) * (1.0 - worn * 0.7);
	float li = 0.0;
	if (li_zone > 0.0) {
		float bloom = smoothstep(0.6, 0.76, kw_fbm(p * 1.4 + 61.0));
		float dots = mix(0.75, smoothstep(0.45, 0.62, kw_noise(p * 11.0 + 71.0)), f_mid);
		li = li_zone * bloom * (0.45 + 0.65 * dots);
		vec3 li_col = mix(weather_lichen_a, weather_lichen_b, smoothstep(0.35, 0.65, kw_noise(p * 4.0 + 5.0)));
		o = mix(o, li_col * (0.5 + 0.4 * tone), clamp(li, 0.0, 1.0) * 0.6 * w);
	}
	c = o;

	// The normal: pits and cracks cut in, the grain a little raised.
	float height = (tooth * 0.35 - pit * 0.6 - cracks * 0.9 + fleck_light * 0.1) * 0.02 * w;
	vec3 sx = dFdx(vtx);
	vec3 sy = dFdy(vtx);
	vec3 r1 = cross(sy, n);
	vec3 r2 = cross(n, sx);
	float det = dot(sx, r1);
	vec3 grad = sign(det) * (dFdx(height) * r1 + dFdy(height) * r2);
	float bump = weather_bump * (0.2 + 0.8 * f_mid);
	n = normalize(abs(det) * n - bump * grad);
	return ((pit + cracks) * 0.05 - worn * 0.08) * w;
}
#endif
