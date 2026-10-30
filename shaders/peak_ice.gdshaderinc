// The Peak's glacier ice (scripts/endless/peak_ice.gd feeds it; endless_ground
// includes it): painted per pixel out of the rock shader's buckets and tones,
// on the ground and on the seracs (scripts/endless/rocks/peak_serac.gd).
//
// Everything on the ground follows one thing, the ice's line: a polyline from
// its head to its toe, each point's world xz, half-width and metres along it,
// and how much ice lies there and how dirty. From it each pixel has `s` (m
// down the flow), `t` (m off the middle) and the flow's direction, so the
// tongue may bend any way: nothing here knows the massif's axis.
//
// Depth comes from the eye: crevasses are slits the eye looks down into
// (`peak_ice_slit`, how far down the wall it meets), and veins lie under the
// surface and shift against it as the plane moves. Every scale eases to its
// mean as the pixel outgrows it, so the far ice is the near ice's average.

// 1: this paint; 0: the older ice in endless_ground (--peak-ice=0).
uniform float peak_ice_on = 0.0;
// 1: all ice (the seracs' own material); -1: none (bare rocks standing on it).
uniform float peak_ice_solid = 0.0;
uniform int peak_ice_count = 0;
// x, z, half-width, s (m along) of each point, head to toe.
uniform vec4 peak_ice_line[32];
// Each point's cover (0 no ice, 1 ice) and debris (0 clean, 1 buried).
uniform vec2 peak_ice_more[32];
// The line's reach in xz (min x, min z, max x, max z), past its widest.
uniform vec4 peak_ice_box = vec4(0.0);

const vec3 ICE_MILK = vec3(0.56, 0.66, 0.73);
const vec3 ICE_CRUST = vec3(0.72, 0.80, 0.86);
// A wall in the sun, pale and milky; turned from it, a pale clear blue. ICE_BLUE
// and ICE_DEEP only down cracks and under overhangs.
const vec3 ICE_SUNLIT = vec3(0.80, 0.87, 0.92);
const vec3 ICE_SHADE = vec3(0.40, 0.62, 0.78);
const vec3 ICE_BLUE = vec3(0.14, 0.40, 0.62);
const vec3 ICE_DEEP = vec3(0.012, 0.075, 0.20);
const vec3 ICE_PALE = vec3(0.30, 0.60, 0.78);
const vec3 ICE_GRIT = vec3(0.050, 0.053, 0.060);
const vec3 ICE_GRIT_PALE = vec3(0.150, 0.155, 0.168);
const vec3 ICE_SNOW = vec3(0.86, 0.89, 0.93);

// The nearest place on the line: returns (s, t, half-width, on the line's
// reach: 1), `flow` its way down, `more` its cover and debris.
vec4 peak_ice_frame(vec2 q, out vec2 flow, out vec2 more) {
	flow = vec2(1.0, 0.0);
	more = vec2(0.0);
	if (peak_ice_count < 2) return vec4(0.0, 0.0, 100.0, 0.0);
	if (q.x < peak_ice_box.x || q.y < peak_ice_box.y || q.x > peak_ice_box.z || q.y > peak_ice_box.w) return vec4(0.0, 0.0, 100.0, 0.0);
	float best = 1e12;
	int at = 0;
	float at_h = 0.0;
	float side = 1.0;
	for (int i = 0; i < peak_ice_count - 1; i++) {
		vec2 a = peak_ice_line[i].xy;
		vec2 e = peak_ice_line[i + 1].xy - a;
		float h = clamp(dot(q - a, e) / max(dot(e, e), 0.001), 0.0, 1.0);
		vec2 d = q - a - e * h;
		float dd = dot(d, d);
		if (dd < best) {
			best = dd;
			at = i;
			at_h = h;
			side = e.x * d.y - e.y * d.x;
		}
	}
	vec4 a = peak_ice_line[at];
	vec4 b = peak_ice_line[at + 1];
	// The way down, eased through the corners.
	vec2 before = a.xy - peak_ice_line[max(at - 1, 0)].xy;
	vec2 after = peak_ice_line[min(at + 2, peak_ice_count - 1)].xy - b.xy;
	vec2 e = b.xy - a.xy;
	vec2 w0 = normalize(normalize(before + e * 0.001) + normalize(e));
	vec2 w1 = normalize(normalize(after + e * 0.001) + normalize(e));
	flow = normalize(mix(w0, w1, at_h));
	more = mix(peak_ice_more[at], peak_ice_more[at + 1], at_h);
	return vec4(mix(a.w, b.w, at_h), sqrt(best) * (side < 0.0 ? -1.0 : 1.0), mix(a.z, b.z, at_h), 1.0);
}

// The ice at `p`, 0..1, with its ragged edge up the sides; `frame` and `flow`
// as peak_ice_frame.
float peak_ice_mask(vec3 p, float zone, out vec4 frame, out vec2 flow, out vec2 more) {
	frame = peak_ice_frame(p.xz, flow, more);
	if (peak_ice_solid > 0.5) return 1.0;
	if (peak_ice_solid < -0.5 || frame.w < 0.5) return 0.0;
	float rag = (zs_noise(p.xz / 37.0) - 0.5) * 0.16 + (zs_noise(p.xz / 9.0) - 0.5) * 0.06;
	return (1.0 - smoothstep(0.92, 1.06, abs(frame.y) / frame.z + rag)) * more.x * zone;
}

// A slit of half-width `w` at `ds` off its middle: returns how much of the
// pixel it fills; `down` how far down its wall the eye meets it, `v` the eye's
// slope across the slit (m across per m up).
float peak_ice_slit(float ds, float w, float v, float fp, out float down) {
	float f = max(fp, 0.001);
	float cover = clamp((w - abs(ds)) / f + 0.5, 0.0, 1.0) * min(1.0, 2.0 * w / f);
	float gap = v > 0.0 ? w + ds : w - ds;
	down = max(gap, 0.0) / max(abs(v), 0.03);
	return cover;
}

// One family of crevasses across the flow, `gap` m apart, up to `wide` m
// across, bowed downstream at the margins: `ds` how far off the nearest,
// returns that one's half-width here (0 where it has pinched out).
float peak_ice_crevasse(float s, float t, float half_w, float gap, float wide, float seed, float keep, out float ds) {
	float across = t / half_w;
	float bent = s - across * across * gap * 1.5
		+ (zs_noise(vec2(t / (gap * 1.3), seed)) - 0.5) * gap * 0.9
		+ (zs_noise(vec2(t / (gap * 0.21), s / (gap * 0.21) + seed)) - 0.5) * gap * 0.09 * keep;
	float x = bent / gap;
	float cell = floor(x);
	float rnd = fract(sin(cell * 12.9898 + seed) * 43758.5453);
	ds = (fract(x) - 0.5 + (rnd - 0.5) * 0.5) * gap;
	float run = zs_noise(vec2(t / (gap * 1.7) + rnd * 9.0, cell * 3.7 + seed));
	return wide * smoothstep(0.40, 0.70, run) * (0.45 + 0.75 * rnd);
}

// The normal bent by a height (m) over the surface, from its screen
// derivatives (Mikkelsen's surface gradient).
vec3 peak_ice_bump(vec3 n, vec3 p, float h) {
	vec3 dx = dFdx(p);
	vec3 dy = dFdy(p);
	vec3 r1 = cross(dy, n);
	vec3 r2 = cross(n, dx);
	float det = dot(dx, r1);
	// (Where the normal stands nearly in the face's own plane there is no bump to
	// take.)
	if (abs(det) < 0.2 * length(cross(dx, dy))) return n;
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	vec3 bent = abs(det) * n - grad;
	float l = length(bent);
	return l > 0.0 ? bent / l : n;
}

// The ice's face on the ground: flow stripes, ogives, crevasses, veins, debris.
// `col` its colour; returns the bump's height (m); `gloss` 1 bare wet ice, 0 crust.
float peak_ice_floor(vec3 p, vec3 eye, vec4 frame, vec2 flow, vec2 more, float fp, float fp_far, out vec3 col, out float gloss) {
	float s = frame.x;
	float t = frame.y;
	float half_w = frame.z;
	vec2 perp = vec2(-flow.y, flow.x);
	vec2 q = p.xz;
	// The lines wander, as ice sheared round a bend does.
	float tw = t + (zs_noise(vec2(s / 260.0, t / 95.0) + 3.1) - 0.5) * 34.0
		+ (zs_noise(vec2(s / 80.0, t / 28.0) + 7.7) - 0.5) * 9.0;
	float k_21 = 1.0 - smoothstep(10.0, 40.0, fp);
	float k_8 = 1.0 - smoothstep(3.0, 13.0, fp);
	float k_3 = 1.0 - smoothstep(1.0, 4.0, fp);
	float k_1 = 1.0 - smoothstep(0.25, 1.1, fp);
	// Flow stripes: bands of blue bubble-free ice in the milky, long down the flow.
	float fol = mix(0.5, zs_noise(vec2(s / 300.0, tw / 21.0)), k_21) * 0.5
		+ mix(0.5, zs_noise(vec2(s / 190.0, tw / 8.0) + 5.0), k_8) * 0.32
		+ mix(0.5, zs_noise(vec2(s / 70.0, tw / 2.6) + 9.0), k_3) * 0.18;
	float blue = smoothstep(0.42, 0.58, fol);
	// Ogives: arcs bowed down the flow, the year's bands below a fall.
	float arc = sin((s - (t * t / half_w) * 0.55 + (zs_noise(vec2(s / 130.0, t / 70.0)) - 0.5) * 50.0) * TAU / 104.0);
	// Old ice: milky crust in patches, its bubbles and frost.
	float w = (zs_noise(q / 46.0) - 0.5) * mix(0.0, 1.2, 1.0 - smoothstep(14.0, 60.0, fp))
		+ (zs_noise(q / 13.0 + 3.0) - 0.5) * 0.7 * k_8 + (zs_noise(q / 3.7 + 8.0) - 0.5) * 0.35 * k_3 + arc * 0.14;
	float old = smoothstep(-0.12, 0.34, w);
	col = mix(mix(ICE_MILK, ICE_BLUE, 0.20), mix(ICE_MILK, ICE_BLUE, 0.72), blue);
	col = mix(col, ICE_CRUST, old * 0.72);
	// Under the surface, seen through it: veins that shift against the crust.
	vec2 under = eye.xz / max(eye.y, 0.3) * 0.62;
	vec2 shift = vec2(dot(under, flow), dot(under, perp));
	vec2 q1 = vec2(s, t) - shift * 2.4;
	vec2 q2 = vec2(s, t) - shift * 7.0;
	float v1 = smoothstep(0.56, 0.78, zs_noise(vec2(q1.x / 15.0, q1.y / 2.3) + 4.0));
	float v2 = smoothstep(0.50, 0.80, zs_noise(vec2(q2.x / 34.0, q2.y / 7.0) + 11.0));
	col = mix(col, ICE_BLUE * 0.8, (v1 * 0.34 * k_1 + v2 * 0.42 * k_3) * (1.0 - old * 0.7));
	// Crevasses: the eye looks down the slit, pale near its lip, dark deep.
	float v_s = dot(eye.xz, flow) / max(eye.y, 0.04);
	float band = smoothstep(0.34, 0.58, zs_noise(vec2(s / 150.0, 2.3)));
	float ds;
	float wide_a = peak_ice_crevasse(s, t, half_w, 41.0, 3.1, 1.7, k_3, ds) * band;
	float down_a;
	float a_on = peak_ice_slit(ds, wide_a, v_s, fp, down_a);
	// (A lip only where its crevasse is open; a pinched-out one left a groove no
	// wider than a pixel, whose bump broke into lines of dots.)
	float lip_a = (1.0 - smoothstep(wide_a, wide_a * 2.6 + 0.7, abs(ds))) * smoothstep(0.0, 0.5, wide_a);
	float wide_b = peak_ice_crevasse(s + 11.0, t, half_w, 13.0, 0.75, 6.1, k_1, ds) * (0.35 + 0.65 * band);
	float down_b;
	float b_on = peak_ice_slit(ds, wide_b, v_s, fp, down_b);
	float lip_b = (1.0 - smoothstep(wide_b, wide_b * 2.6 + 0.2, abs(ds))) * smoothstep(0.0, 0.15, wide_b);
	float wide_c = peak_ice_crevasse(s - 5.0, t + 17.0, half_w, 4.3, 0.09, 3.3, k_1, ds);
	float down_c;
	float c_on = peak_ice_slit(ds, wide_c, v_s, fp, down_c);
	vec3 slit_a = mix(ICE_DEEP, ICE_PALE, exp(-down_a / 5.0));
	vec3 slit_b = mix(ICE_DEEP, ICE_PALE, exp(-down_b / 2.0));
	col = mix(col, col * vec3(0.72, 0.84, 0.96), max(lip_a, lip_b) * 0.5);
	col = mix(col, ICE_BLUE * 0.55, c_on * 0.7);
	col = mix(col, slit_b, b_on);
	col = mix(col, slit_a, a_on);
	float slit = max(a_on, b_on);
	// Debris: dark stripes down the flow, the margins, dust in patches, more
	// toward the toe.
	// (Narrow: a few metres of stones, swelling and pinching down the flow, their
	// edges broken, so near the eye a stripe is scattered rock and not a road.)
	float tn = tw / half_w + ((zs_noise(q / 17.0 + 1.3) - 0.5) * 0.030 + (zs_noise(q / 5.3 + 6.7) - 0.5) * 0.016 * k_8) * (1.0 - smoothstep(30.0, 90.0, fp));
	float pinch = 0.55 + 0.9 * zs_noise(vec2(s / 95.0, 4.4));
	float mid_a = 1.0 - smoothstep(0.004, 0.022 * pinch, abs(tn + 0.50 + 0.05 * sin(s / 210.0)));
	float mid_b = 1.0 - smoothstep(0.005, 0.028 * pinch, abs(tn - 0.08 + 0.06 * sin(s / 170.0 + 2.0)));
	float mid_c = 1.0 - smoothstep(0.003, 0.018 * pinch, abs(tn - 0.57 + 0.04 * sin(s / 240.0 + 4.0)));
	float stripes = max(mid_a, max(mid_b, mid_c));
	float edge = smoothstep(0.74, 1.0, abs(t) / half_w);
	float patches = zs_noise(q / 31.0) * 0.6 + mix(0.5, zs_noise(q / 8.0 + 5.0), k_8) * 0.4;
	float dirt = max(stripes * (0.62 + 0.45 * zs_noise(vec2(s / 40.0, 1.0))), edge);
	dirt = max(dirt, smoothstep(0.66 - more.y * 0.34, 0.86 - more.y * 0.2, patches) * (0.32 + more.y * 0.5));
	float grit = smoothstep(0.34, 0.60, dirt + (zs_noise(q / 1.9) - 0.5) * 0.62 * k_3 + (zs_noise(q / 0.6) - 0.5) * 0.3 * k_1);
	vec3 stone = mix(ICE_GRIT, ICE_GRIT_PALE, smoothstep(0.3, 0.72, mix(0.5, zs_noise(q / 2.9 + 2.0), k_3)));
	col = mix(col, stone, grit * (1.0 - slit));
	gloss = (1.0 - old) * (1.0 - grit) * (1.0 - slit * 0.8);
	// Bump: melt hummocks and scallops, lips falling into the slits, grit raised.
	// (Faded by distance alone, each by its own width: `fp` jumps across triangles,
	// and the bump's derivative turned any jump or sub-pixel step in the height
	// into a pair of dark and pale pixels, so a bump must end before its feature
	// reaches a pixel. `eye.y`: seen at a glance a pixel runs long along the view,
	// so the bump must go by that length, or the hummocks beat against the rows of
	// pixels in lines across the view, loudest in the shade where sky sheen is all
	// the light. It runs smooth across the triangles, as fp_far does.)
	float fb = fp_far * 2.5 / max(eye.y, 0.05);
	// (Down the flow by `s` and `t`, the line's own measure. A world point dotted
	// with `flow` is no length: `flow` turns along a bend, and at a few km from the
	// origin the smallest turn runs that dot through a whole noise cell in a metre.
	// That was the ripple across the ice.)
	float h = (zs_noise(vec2(s / 8.0, t / 4.6)) - 0.5) * 0.9 * (1.0 - smoothstep(1.2, 6.0, fb))
		+ (zs_noise(q / 2.1 + 6.0) - 0.5) * 0.28 * (1.0 - smoothstep(0.35, 1.4, fb))
		+ (zs_noise(q / 0.55 + 3.0) - 0.5) * 0.05 * (1.0 - smoothstep(0.08, 0.3, fb));
	h -= lip_a * 0.8 * (1.0 - smoothstep(0.25, 1.0, fb)) + lip_b * 0.25 * (1.0 - smoothstep(0.05, 0.2, fb));
	h += grit * 0.12 * (1.0 - smoothstep(0.1, 0.4, fb));
	return h;
}

// How much of a pixel a thin line fills: `f` how far (in the noise's units) off
// its level, `f_w` the noise's change over a pixel, `w` the line's half-width
// (m). Under a pixel it fades to a faint even line and does not break into dots.
float peak_ice_thin(float f, float f_w, float w, float fp) {
	float wide = w / max(fp, 0.001);
	return clamp(wide - f / max(f_w, 0.00001) + 0.5, 0.0, 1.0) * min(1.0, wide * 2.0);
}

// The ice's face on a steep one (a serac's, a fall's riser). Pale and milky in
// the sun; a clear pale blue turned from it; deep blue only in the cracks, under
// overhangs and low in the hollows. Strata tilted down the flow, in three sizes,
// with dust along them; fractures up it. `solid` 0: a wall of the ground, whose
// long triangles can't hold the fractures, so they stay faint there.
float peak_ice_wall(vec3 p, vec3 n, vec3 eye, vec2 flow, float fp, float tone, float open, float solid, vec3 sun, out vec3 col, out float gloss) {
	float k_7 = 1.0 - smoothstep(2.0, 8.0, fp);
	float k_2 = 1.0 - smoothstep(0.5, 2.2, fp);
	float k_h = 1.0 - smoothstep(0.1, 0.5, fp);
	// Strata: bands of dirty and clear ice, each size easing to its mean.
	float y = p.y + dot(p.xz, flow) * 0.26 + (er_vnoise(p / 23.0) - 0.5) * 7.0;
	float b_1 = zs_noise(vec2(y / 5.1, 3.3));
	float b_2 = zs_noise(vec2(y / 1.45, 8.1));
	float b_3 = zs_noise(vec2(y / 0.43, 5.7));
	float k_16 = 1.0 - smoothstep(4.0, 16.0, fp);
	float band = mix(0.5, b_1, k_16) * 0.52 + mix(0.5, b_2, k_7) * 0.32 + mix(0.5, b_3, k_2) * 0.16;
	float strata = smoothstep(0.34, 0.66, band);
	float dust = smoothstep(0.30, 0.20, b_2) * k_7 + smoothstep(0.24, 0.16, b_1) * 0.7 * k_16;
	// Fractures up the face: straight sheets (the walls of tall cells, some of
	// them), not a noise's level lines. The ground's walls have none.
	float crack_a = 0.0;
	float crack_b = 0.0;
	float near_a = 0.0;
	if (solid > 0.5) {
		vec3 r_a;
		vec3 r_b;
		vec2 c_a = er_cells(vec3(p.x + p.y * 0.12, p.y * 0.30, p.z - p.y * 0.08) / 8.5 + 3.0, r_a);
		vec2 c_b = er_cells(vec3(p.x, p.y * 0.42, p.z) / 3.1 + 11.0, r_b);
		float on_a = step(0.42, r_a.x);
		crack_a = peak_ice_thin(c_a.y, fwidth(c_a.y), 0.03 + 0.07 * r_a.y, fp) * on_a;
		crack_b = peak_ice_thin(c_b.y, fwidth(c_b.y), 0.03, fp) * step(0.6, r_b.x) * k_2;
		// (The blue seeping out round a fracture.)
		near_a = (1.0 - smoothstep(0.0, 0.14, c_a.y)) * on_a * k_7;
	}
	// How deep a blue: its hollows and overhangs first, then turned from the sun,
	// the block's own tone, broad clouding, the bands.
	float lit = smoothstep(-0.20, 0.42, dot(n, sun));
	float under = clamp(-n.y * 2.5, 0.0, 1.0);
	float cloud = er_vnoise(p / 11.0 + 7.0) - 0.5;
	float depth = (1.0 - open) * 0.62 + (1.0 - lit) * 0.24 + under * 0.55 + (tone - 0.5) * 0.36
		+ (0.5 - strata) * 0.32 + cloud * 0.40 * mix(0.5, 1.0, solid) + (1.0 - solid) * 0.30;
	depth = clamp(depth, 0.0, 1.0);
	col = mix(ICE_SUNLIT, ICE_SHADE, smoothstep(0.04, 0.54, depth));
	col = mix(col, ICE_BLUE, smoothstep(0.50, 0.92, depth));
	col = mix(col, ICE_DEEP * 1.6, smoothstep(0.86, 1.0, depth) * 0.6);
	// Bright clear bands against the dull ones, dust grey along the beds.
	col *= 0.90 + 0.20 * strata;
	col = mix(col, ICE_GRIT_PALE * vec3(0.95, 1.0, 1.1), clamp(dust, 0.0, 1.0) * 0.30);
	// Under the surface, as on the floor, read off the face.
	vec3 q1 = p - eye * 1.5;
	float v1 = smoothstep(0.52, 0.78, er_vnoise(vec3(q1.x, q1.y * 0.3, q1.z) / 3.4 + 2.0));
	col = mix(col, ICE_SHADE, v1 * 0.34 * k_2 * (1.0 - depth * 0.5));
	col = mix(col, ICE_BLUE, near_a * 0.5);
	col = mix(col, ICE_DEEP * 1.5, max(crack_a, crack_b * 0.85) * 0.9);
	gloss = 0.15 + 0.35 * depth;
	float h = (-near_a * 0.3 * k_2 + (strata - 0.5) * 0.22 * k_2
		+ (er_vnoise(p / 1.1 + 4.0) - 0.5) * 0.12 * k_h) * mix(0.4, 1.0, solid);
	return h;
}

// The ice's paint: `col` over the ground's, the lit normal, its glow (blue in
// the shade: the ice's scatter, which the hemisphere alone leaves grey), its
// roughness and specular. `tone` a block's own (0.5 on the ground), `open` how
// exposed (1 on the ground), `rim` 1 on a block's edge falling to 0 at its face's
// middle (0 on the ground), `fp_far` a pixel's size by distance alone (`fp` jumps
// from one long triangle of a ground wall to the next).
void peak_ice_paint(vec3 p, vec3 n, vec3 eye, vec4 frame, vec2 flow, vec2 more, float fp, float fp_far, float tone, float open, float rim, out vec3 col, inout vec3 lit_n, out vec3 glow, out float rough, out float spec) {
	vec3 sun = zs_sun_direction;
	float solid = step(0.5, peak_ice_solid);
	// (The walls' own paint from where the face turns steep; the floor keeps a
	// serac's flat tops under their crust.)
	float steep = solid > 0.5 ? smoothstep(0.80, 0.62, n.y) : smoothstep(0.86, 0.42, n.y);
	vec3 c_floor = vec3(0.0);
	vec3 c_wall = vec3(0.0);
	float g_floor = 0.0;
	float g_wall = 0.0;
	float h = 0.0;
	if (steep < 1.0) {
		if (solid > 0.5) {
			// A serac's top: wind-packed snow over old ice, torn at its edges.
			float crust = smoothstep(0.32, 0.62, zs_noise(p.xz / 3.3 + 2.0) * 0.6 + zs_noise(p.xz / 0.9) * 0.4 * (1.0 - smoothstep(0.2, 1.0, fp)) + 0.05);
			c_floor = mix(ICE_MILK, ICE_SNOW, crust);
			g_floor = 0.2;
			h = (zs_noise(p.xz / 1.7) - 0.5) * 0.14 * (1.0 - smoothstep(0.3, 1.5, fp));
		} else {
			h = peak_ice_floor(p, eye, frame, flow, more, fp, fp_far, c_floor, g_floor);
		}
	}
	if (steep > 0.0) {
		float h_w = peak_ice_wall(p, n, eye, flow, solid > 0.5 ? fp : fp_far, tone, open, solid, sun, c_wall, g_wall);
		h = mix(h, h_w, steep);
	}
	col = mix(c_floor, c_wall, steep);
	float gloss = mix(g_floor, g_wall, steep);
	// A block's edges, sharp and bright: `rim` runs straight across each of its
	// face's fan triangles, so its slope gives the way to the edge in metres.
	float edge = 0.0;
	if (solid > 0.5) {
		float to_edge = (1.0 - rim) / max(fwidth(rim), 0.00001) * fp;
		// (Wider and narrower along an edge, stronger on what lies up to the light.)
		float worn = smoothstep(0.30, 0.70, zs_noise(p.xz / 5.3 + p.y / 4.1));
		float edge_w = max(0.07 + 0.16 * worn, fp * 1.1);
		edge = (1.0 - smoothstep(edge_w * 0.5, edge_w, to_edge)) * (0.25 + 0.75 * open) * (0.55 + 0.45 * clamp(n.y * 2.0 + dot(n, sun), 0.0, 1.0));
		col = mix(col, ICE_SNOW * 1.1, edge * 0.92);
		gloss *= 1.0 - edge;
	}
	lit_n = peak_ice_bump(n, p, h);
	rough = mix(0.62, 0.26, gloss);
	spec = mix(0.32, 0.62, gloss);
	// The sky's sheen across the ice at a glance, and the blue scatter: most
	// where it is blue, none on grit.
	float ndv = clamp(dot(lit_n, eye), 0.0, 1.0);
	float shine = pow(1.0 - ndv, 4.0) * (0.25 + 0.75 * gloss);
	vec3 sky = zs_hemi_sky * zs_hemi_energy;
	float tint = clamp((col.b - col.r) * 2.4, 0.0, 1.0);
	glow = sky * shine * 0.20 + (ICE_BLUE * 0.45 + col * 0.25) * sky * tint * 0.42 + col * sky * edge * 0.30;
	// A block's ice lets the day through: its shaded faces glow pale, not dark.
	glow += col * dot(sky, vec3(0.3, 0.59, 0.11)) * solid * 0.17;
}
