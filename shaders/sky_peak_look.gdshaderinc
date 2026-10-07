#ifndef ZS_SKY_PEAK_LOOK
#define ZS_SKY_PEAK_LOOK
// A sky peak's rock and snow up close (shaders/reference_surface.gdshader,
// gated on `sea_cut`): what makes a range a few hundred metres high read as
// one, not as a model of one. Its faces are a 4 m grid, each flat and one
// colour (scripts/sky_peak.gd `_tone`), which on its own reads as a toy: the
// same step everywhere and nothing smaller to measure it by. So, all in the
// range's own frame (`rel`: the point less its mesh's origin, so the skyline
// and the full range, laid alike, paint alike and a swap moves nothing):
//   the snow's edge runs across the faces, not face by face: the season's
//     margin (sky_season zs_sky_peak_margin) ragged by a noise over tens of
//     metres, softened over a few, and a little lower on the lee faces;
//   on the steep snowfields the snow breaks into flutes down the fall line
//     with dark rock ribs between, as on the Karakoram's faces, more rock
//     the steeper;
//   the basalt carries its beds' fine layering, blotches and cracks inside
//     each face, a few metres across, faded out before they alias, so near
//     faces show many lines and the facet itself steps back;
//   the low air: the rock pales into the cloud's mist toward the sea (its
//     top riding up the gullies and down off the spurs, never level) and
//     through a slow, drifting band of mist on its flanks (as `sea_mist`).
// On the peaks alone, and each part skipped where it can't show: the grain
// past the distance it resolves at, the low air above its reach, the
// flutes off the snow.

// The snow line's rag (m either way) and its wavelength (m), the soft edge
// (m), and how much lower (m) it comes on a face turned square to the lee.
const float ZS_PEAK_SNOW_RAG = 14.0;
const float ZS_PEAK_SNOW_RAG_WAVE = 46.0;
const float ZS_PEAK_SNOW_SOFT = 3.5;
const float ZS_PEAK_SNOW_LEE = 12.0;
// The flutes: their spacing across the fall line and their run down it (m),
// the slope (gradient) they start at and where the snow is mostly ribs, and
// the share of a fluted face left rock at the steepest.
const float ZS_PEAK_FLUTE_WIDE = 4.5;
const float ZS_PEAK_FLUTE_RUN = 70.0;
const vec2 ZS_PEAK_FLUTE_SLOPE = vec2(0.75, 2.1);
const float ZS_PEAK_FLUTE_BARE = 0.62;
// The rock's fine layering: its spacing (m), the beds' wander (m) and how
// strong (a share of the colour) on a cliff; blotches (m, share); cracks
// (m apart, how dark).
const float ZS_PEAK_LAYER = 2.6;
const float ZS_PEAK_LAYER_WANDER = 7.0;
const float ZS_PEAK_LAYER_STRENGTH = 0.24;
const float ZS_PEAK_BLOTCH = 9.0;
const float ZS_PEAK_BLOTCH_STRENGTH = 0.16;
const float ZS_PEAK_CRACK = 5.5;
const float ZS_PEAK_CRACK_DARK = 0.32;
// The low air: over this many metres above the sea's top the rock goes this
// far into the mist; a band of mist this high (m) over the sea, wandering
// this much (m) either way, this thick (m, half), at most this strong, and
// drifting this fast (m/s).
const float ZS_PEAK_LOW_AIR = 160.0;
const float ZS_PEAK_LOW_AIR_MOST = 0.3;
const float ZS_PEAK_BAND_AT = 115.0;
const float ZS_PEAK_BAND_WANDER = 45.0;
const float ZS_PEAK_BAND_HALF = 20.0;
const float ZS_PEAK_BAND_MOST = 0.5;
const float ZS_PEAK_BAND_DRIFT = 2.2;
// The low air's top isn't level: it rides this many metres up and down
// either way over this wavelength (m) along the range, so its edge climbs
// the gullies and dips off the spurs instead of ruling a line across.
const float ZS_PEAK_LOW_AIR_RAG = 55.0;
const float ZS_PEAK_LOW_AIR_RAG_WAVE = 190.0;

// The prevailing wind over the ranges (world xz), for the lee: the snow
// gathers on the faces turned away from it. Not the plate's breeze, which
// turns with the weather; snow lies where the winters have laid it.
uniform vec2 peak_lee = vec2(0.8, 0.6);

// Hash and value noise without sin(), steady however far from the origin.
float zs_peak_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float zs_peak_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(zs_peak_hash(i), zs_peak_hash(i + vec2(1.0, 0.0)), f.x),
		mix(zs_peak_hash(i + vec2(0.0, 1.0)), zs_peak_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float zs_peak_fbm(vec2 p) {
	return zs_peak_noise(p) * 0.57 + zs_peak_noise(p * 2.03 + 17.1) * 0.29 + zs_peak_noise(p * 4.07 - 5.3) * 0.14;
}
// 1 while a pattern `wave` m across is coarser than the pixels (`px` m a
// pixel), 0 once it would shimmer.
float zs_peak_resolved(float px, float wave) {
	return 1.0 - smoothstep(0.22, 0.55, px / wave);
}
// The ground's steepness (gradient) for a normal.
float zs_peak_slope(vec3 n) {
	return sqrt(max(0.0, 1.0 - n.y * n.y)) / max(n.y, 0.001);
}

// A ribbed streak field, `p` (across the fall line, down it) in metres: 1
// on a flute's crest, 0 in the groove between.
float zs_peak_flute(vec2 p) {
	vec2 q = vec2(p.x / ZS_PEAK_FLUTE_WIDE, p.y / ZS_PEAK_FLUTE_RUN);
	q.x += (zs_peak_noise(q * vec2(0.13, 1.7) + 3.1) - 0.5) * 1.6;
	return 1.0 - abs(zs_peak_noise(q) * 2.0 - 1.0);
}

// How much of the snow lies here, 0 to 1: `margin` the season's (world m),
// `rel` the range's frame, `n` the ground's broad lie (world), `px` metres a
// pixel.
float zs_peak_snow_cover(float margin, vec3 rel, vec3 n, float px) {
	vec2 flat_n = n.xz;
	float lie = length(flat_n);
	vec2 down = lie > 1e-4 ? flat_n / lie : vec2(1.0, 0.0);
	float rag = (zs_peak_fbm(rel.xz / ZS_PEAK_SNOW_RAG_WAVE) - 0.5) * 2.0 * ZS_PEAK_SNOW_RAG;
	float lee = dot(down, normalize(peak_lee)) * min(lie * 2.0, 1.0) * ZS_PEAK_SNOW_LEE;
	float cover = smoothstep(-ZS_PEAK_SNOW_SOFT, ZS_PEAK_SNOW_SOFT, margin + rag + lee);
	if (cover <= 0.0) return 0.0;
	float steep = smoothstep(ZS_PEAK_FLUTE_SLOPE.x, ZS_PEAK_FLUTE_SLOPE.y, zs_peak_slope(n));
	if (steep > 0.0) {
		// Across the fall line fine, down it long: ribbed streaks, read
		// along the frame's two level axes and blended by which way the
		// face looks (a projection on the face's own way would swim).
		vec2 w = pow(abs(down), vec2(4.0));
		w /= max(w.x + w.y, 1e-4);
		float flute = w.x * zs_peak_flute(vec2(rel.z, rel.y)) + w.y * zs_peak_flute(vec2(rel.x, rel.y) + 57.0);
		float bare = ZS_PEAK_FLUTE_BARE * steep;
		float mask = smoothstep(bare - 0.1, bare + 0.1, flute);
		// Seen from far the flutes blend to the share of snow they leave.
		mask = mix(1.0 - bare, mask, zs_peak_resolved(px, ZS_PEAK_FLUTE_WIDE));
		cover *= mask;
	}
	return cover;
}

// The snow's own grain, wind-packed.
vec3 zs_peak_snow_grain(vec3 snow, vec3 rel, float px) {
	float grain = zs_peak_noise(rel.xz / 6.0 + rel.y * 0.05) - 0.5;
	return snow * (1.0 + grain * 0.07 * zs_peak_resolved(px, 6.0));
}

float zs_peak_blotch(vec2 p) {
	return zs_peak_noise(p / ZS_PEAK_BLOTCH) * 0.65 + zs_peak_noise(p / (ZS_PEAK_BLOTCH * 0.37) + 9.0) * 0.35;
}

float zs_peak_joint(vec2 p) {
	return 1.0 - abs(zs_peak_noise(vec2(p.x, p.y * 0.35) / ZS_PEAK_CRACK) * 2.0 - 1.0);
}

// The basalt's fine layering, blotches and cracks over `rock` (its face's
// colour), stronger the steeper `n` stands.
vec3 zs_peak_rock_grain(vec3 rock, vec3 rel, vec3 n, float px) {
	// Far off none of it resolves: the face's own colour.
	if (px > ZS_PEAK_BLOTCH * 0.2) return rock;
	float steep = smoothstep(0.4, 1.4, zs_peak_slope(n));
	float shade = 1.0;
	// Layering: thin beds, gently tilted and wandering, inside each face.
	float wander = (zs_peak_fbm(rel.xz / 70.0) - 0.5) * 2.0 * ZS_PEAK_LAYER_WANDER + dot(rel.xz, vec2(0.031, 0.047));
	float layer = zs_peak_noise(vec2((rel.y + wander) / ZS_PEAK_LAYER, 0.37 + rel.x * 0.004));
	shade += (layer - 0.5) * 2.0 * ZS_PEAK_LAYER_STRENGTH * mix(0.25, 1.0, steep) * zs_peak_resolved(px, ZS_PEAK_LAYER);
	// Blotches: from above on the gentle, along the face on the steep
	// (each read in the frame's own axes and blended, never swimming).
	vec2 w = pow(abs(n.xz) + 1e-3, vec2(4.0));
	w /= w.x + w.y;
	float flat_b = zs_peak_blotch(rel.xz);
	float wall_b = w.x * zs_peak_blotch(rel.zy + 23.0) + w.y * zs_peak_blotch(rel.xy - 11.0);
	shade += (mix(flat_b, wall_b, steep) - 0.5) * 2.0 * ZS_PEAK_BLOTCH_STRENGTH * zs_peak_resolved(px, ZS_PEAK_BLOTCH * 0.37);
	// Cracks: thin dark joints down the cliffs.
	float joint = w.x * zs_peak_joint(rel.zy) + w.y * zs_peak_joint(rel.xy + 31.0);
	shade *= 1.0 - ZS_PEAK_CRACK_DARK * pow(joint, 10.0) * steep * zs_peak_resolved(px, ZS_PEAK_CRACK * 0.5);
	return rock * max(shade, 0.4);
}

// How far (m) the low air rides up (+) or down (-) at `rel`.
float zs_peak_low_air_lift(vec3 rel) {
	return (zs_peak_fbm(rel.xz / ZS_PEAK_LOW_AIR_RAG_WAVE + 13.7) - 0.5) * 2.0 * ZS_PEAK_LOW_AIR_RAG;
}

// How far into the mist the low air takes the rock (`above` m over the
// sea's top), and the drifting band's share.
float zs_peak_low_air(float above, vec3 rel, float time) {
	if (above > max(ZS_PEAK_LOW_AIR, ZS_PEAK_BAND_AT + ZS_PEAK_BAND_WANDER + ZS_PEAK_BAND_HALF * 2.5) + ZS_PEAK_LOW_AIR_RAG) return 0.0;
	above = max(above - zs_peak_low_air_lift(rel), 0.0);
	float low = 1.0 - smoothstep(0.0, ZS_PEAK_LOW_AIR, above);
	vec2 drift = rel.xz + normalize(peak_lee) * time * ZS_PEAK_BAND_DRIFT;
	float lay = zs_peak_fbm(drift / 160.0);
	float centre = ZS_PEAK_BAND_AT + (lay - 0.5) * 2.0 * ZS_PEAK_BAND_WANDER;
	float d = (above - centre) / ZS_PEAK_BAND_HALF;
	float band = exp(-d * d) * smoothstep(0.42, 0.66, zs_peak_fbm(drift / 95.0 + 41.0));
	return clamp(low * low * ZS_PEAK_LOW_AIR_MOST + band * ZS_PEAK_BAND_MOST, 0.0, 0.7);
}
#endif
