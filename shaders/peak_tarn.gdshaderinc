// The Peak's tarn: a black mirror with another sky in it (crown loop, lane
// `lake`). Included by endless_ground.gdshader after the sky and display
// includes; two hooks there, gated on `peak_tarn.w`: the water (in the river
// path's `if (wet > 0.0)`) and the ground round it (after the snow's paint).
// Flag --peak-tarn=0 leaves w at 0.
//
// Uniforms (scripts/endless/peak_tarn.gd, from the massif's pond entry):
//   peak_tarn   x z centre, y level, w on
//   peak_tarn_a radius, lobe 2 share, lobe 2 phase, lobe 3 share
//   peak_tarn_b lobe 3 phase, lobe 5 share, lobe 5 phase, shore reach (m)
//   peak_tarn_c the massif's facing (xz): the other sky's planet hangs over
//               the way in
// Outline as land_ponds.gd: r = R (1 + l2 sin(2a+p2) + l3 sin(3a+p3) + l5 sin(5a+p5)).

uniform vec4 peak_tarn = vec4(0.0);
uniform vec4 peak_tarn_a = vec4(50.0, 0.2, 0.0, 0.1);
uniform vec4 peak_tarn_b = vec4(0.0, 0.05, 0.0, 40.0);
uniform vec4 peak_tarn_c = vec4(1.0, 0.0, 0.0, 0.0);

float pt_h(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

vec2 pt_h2(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

float pt_n(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(pt_h(i), pt_h(i + vec2(1.0, 0.0)), f.x), mix(pt_h(i + vec2(0.0, 1.0)), pt_h(i + vec2(1.0, 1.0)), f.x), f.y);
}

// x nearest distance, y gap to the second nearest (0 on a crack), z cell id.
vec3 pt_cells(vec2 p) {
	vec2 ip = floor(p);
	vec2 fq = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 dv = g + pt_h2(ip + g) - fq;
			float dd = dot(dv, dv);
			if (dd < d1) {
				d2 = d1;
				d1 = dd;
				id = pt_h(ip + g + 17.3);
			} else if (dd < d2) {
				d2 = dd;
			}
		}
	}
	return vec3(sqrt(d1), sqrt(d2) - sqrt(d1), id);
}

// (x signed distance outside the lobed edge in m, y angle, z distance from centre)
vec3 pt_edge(vec2 xz) {
	vec2 q = xz - peak_tarn.xy;
	float r = length(q);
	float a = atan(q.y, q.x);
	float R = peak_tarn_a.x;
	float e = R * (1.0 + peak_tarn_a.y * sin(2.0 * a + peak_tarn_a.z) + peak_tarn_a.w * sin(3.0 * a + peak_tarn_b.x) + peak_tarn_b.y * sin(5.0 * a + peak_tarn_b.z));
	float de = R * (2.0 * peak_tarn_a.y * cos(2.0 * a + peak_tarn_a.z) + 3.0 * peak_tarn_a.w * cos(3.0 * a + peak_tarn_b.x) + 5.0 * peak_tarn_b.y * cos(5.0 * a + peak_tarn_b.z)) / max(r, 1.0);
	return vec3((r - e) / sqrt(1.0 + de * de), a, r);
}

// 1 where (x, z) is near enough the tarn to be its water (the river path's
// other pixels, anywhere else, keep their own).
float peak_tarn_in(vec2 xz) {
	float widest = peak_tarn_a.x * (1.0 + peak_tarn_a.y + peak_tarn_a.w + peak_tarn_b.y);
	return 1.0 - step(widest + 8.0, distance(xz, peak_tarn.xy));
}

// The ice: plates broken by cracks, thin and loose out on the water, thick
// and nearly joined at the shore. `thick` 0..1 (1 at the shore), `fp` the
// pixel's footprint (m). cover: the plate is there (1) or open water (0);
// crack: dark fracture lines over a plate; lip: a bright edge; tint: a
// plate's own shade; id: its hash (its tilt, in the sky it mirrors).
void pt_ice(vec2 xz, float thick, float fp, out float cover, out float crack, out float lip, out float tint, out float id) {
	const float SC = 9.0;
	vec2 w = vec2(pt_n(xz / 19.0), pt_n(xz / 19.0 + 7.7)) - 0.5;
	vec2 w2 = vec2(pt_n(xz / 6.0 + 3.0), pt_n(xz / 6.0 + 11.1)) - 0.5;
	vec3 c = pt_cells(xz / SC + w * 1.1 + w2 * 0.35);
	float em = c.y * 0.5 * SC;
	id = c.z;
	float present = step(c.z, thick * 1.12 - 0.05);
	float gap = mix(0.8, 0.05, smoothstep(0.3, 0.95, thick));
	float aa = fp * 0.7 + 0.04;
	cover = present * smoothstep(gap, gap + aa + 0.1, em);
	lip = present * (1.0 - smoothstep(gap + 0.04, gap + 0.5 + aa, em)) * cover;
	tint = 0.55 * c.z + 0.45 * pt_n(xz / 2.5);
	vec3 c2 = pt_cells(xz / 4.2 + w * 2.0 + 3.1);
	float em2 = c2.y * 0.5 * 4.2;
	crack = (1.0 - smoothstep(0.008, 0.035 + fp * 0.5, em2)) * smoothstep(0.5, 0.95, thick) * (1.0 - smoothstep(0.5, 2.2, fp));
	float mean_cover = clamp(thick * 1.05, 0.0, 1.0) * 0.88;
	cover = mix(cover, mean_cover, smoothstep(2.0, 6.0, fp));
}

// A plate's colour as an albedo (cold, a little green): dark and clear when
// thin, paler and milky thick.
vec3 pt_ice_colour(vec2 xz, float tint, float crack, float lip, float thick) {
	vec3 c = mix(vec3(0.05, 0.12, 0.19), vec3(0.30, 0.50, 0.66), clamp(tint * 0.6 + thick * 0.55, 0.0, 1.0));
	// Blown snow lying on the thick ice in drifts, and a slower swell of shade over it.
	float dust = smoothstep(0.50, 0.78, pt_n(xz / 6.5 + 2.0) * 0.6 + pt_n(xz / 2.2) * 0.4) * smoothstep(0.35, 0.9, thick);
	c = mix(c, vec3(0.46, 0.55, 0.64), dust * 0.75);
	c *= 0.85 + 0.3 * pt_n(xz / 21.0 + 9.0);
	c = mix(c, vec3(0.015, 0.05, 0.09), crack * 0.75);
	return c + lip * vec3(0.10, 0.14, 0.16);
}

// A sky that is not this one's, in display colour (r a unit direction, y >= 0;
// t the clock in s). A dusk that doesn't end: a jade-grey glow low, a dark
// indigo above it, slow curtains of green and violet light, a banded planet
// over the way in.
vec3 pt_other_sky(vec3 r, float t) {
	float h = clamp(r.y, 0.0, 1.0);
	vec3 sky = mix(vec3(0.040, 0.075, 0.075), vec3(0.028, 0.055, 0.090), smoothstep(0.0, 0.26, h));
	sky = mix(sky, vec3(0.012, 0.010, 0.040), smoothstep(0.22, 0.95, h));
	sky += vec3(0.07, 0.10, 0.075) * (1.0 - smoothstep(0.0, 0.03, h)) * smoothstep(0.0, 0.006, h);
	// (Noise over the circle of azimuths, so there is no seam behind.)
	vec2 ring = normalize(r.xz + vec2(1e-5));
	vec2 drift = vec2(cos(t * 0.0165), sin(t * 0.0165));
	vec2 rc = vec2(ring.x * drift.x - ring.y * drift.y, ring.x * drift.y + ring.y * drift.x);
	float band = smoothstep(0.07, 0.22, h) * (1.0 - smoothstep(0.34, 0.80, h));
	float fold = smoothstep(0.32, 0.78, pt_n(rc * 2.6 + vec2(h * 2.3 + t * 0.012, 5.0)));
	float rays = 0.55 * pt_n(rc * 9.0 + 3.0) + 0.45 * pt_n(rc * 21.0 + vec2(t * 0.04, 8.0));
	float aur = band * fold * (0.35 + 0.9 * rays);
	vec3 aur_c = mix(vec3(0.05, 0.50, 0.42), vec3(0.34, 0.12, 0.52), smoothstep(0.12, 0.6, h));
	sky += aur_c * aur * 0.30;
	// The planet: over the way in (against the massif's facing), 15 degrees up.
	vec2 fc = normalize(peak_tarn_c.xy + vec2(1e-4));
	vec3 pl = normalize(vec3(-fc.x * 0.96 - fc.y * 0.28, 0.27, -fc.y * 0.96 + fc.x * 0.28));
	float rad = 0.10;
	float ang = acos(clamp(dot(r, pl), -1.0, 1.0));
	vec3 e1 = normalize(cross(vec3(0.0, 1.0, 0.0), pl));
	vec3 e2 = cross(pl, e1);
	vec3 off = r - pl * dot(r, pl);
	vec2 xy = vec2(dot(off, e1), dot(off, e2)) / sin(rad);
	float zz = sqrt(max(1.0 - dot(xy, xy), 0.0));
	vec3 nrm = normalize(xy.x * e1 + xy.y * e2 + zz * pl);
	float lit = smoothstep(-0.12, 0.45, dot(nrm, normalize(vec3(0.75, 0.25, 0.45))));
	float bands = 0.5 + 0.5 * sin(xy.y * 8.0 + 1.6 * pt_n(vec2(xy.x * 2.0, xy.y * 5.0)));
	float disc = (1.0 - smoothstep(rad - 0.004, rad, ang)) * step(0.0, dot(r, pl));
	vec3 pl_c = mix(vec3(0.30, 0.27, 0.25), vec3(0.58, 0.52, 0.44), bands) * mix(0.10, 1.0, lit) * (0.45 + 0.55 * zz);
	sky = mix(sky, pl_c * 0.62, disc);
	sky += vec3(0.05, 0.06, 0.05) * exp(-ang * 16.0) * (1.0 - disc) * 0.5;
	sky *= mix(0.2, 1.0, smoothstep(0.0, 0.10, h));
	return sky;
}

// Hook A: the ground round the tarn. `rw` = (roughness, weight).
// From the water out: an ice shelf (cracked plates, 1.5 to 9 m, never the
// same two places), dark wet rock under and beyond it (2 to 12 m), then snow
// drifted thin over rock, dirtier and bluer near the water, the rock
// breaking through in patches and giving way to the land's own snow at the
// shore's reach.
vec3 peak_tarn_shore(vec3 albedo, vec3 p, float fp, out vec2 rw) {
	rw = vec2(0.0);
	float reach = peak_tarn_b.w;
	// (Most of the land is far from the tarn: out before any of the maths.)
	if (distance(p.xz, peak_tarn.xy) > peak_tarn_a.x * (1.0 + peak_tarn_a.y + peak_tarn_a.w + peak_tarn_b.y) + reach + 8.0) return albedo;
	vec3 e = pt_edge(p.xz);
	float d = e.x;
	if (d > reach + 6.0 || d < -3.0) return albedo;
	float fine = 1.0 - smoothstep(1.0, 4.0, fp);
	float a = e.y;
	// Each stretch of the shore its own: wide wet rock here, a snow bank to
	// the water there, the shelf wide or none.
	float lobe_r = pt_n(vec2(a * 2.3 + 1.3, 0.7));
	float lobe_s = pt_n(vec2(a * 3.1 + 5.1, 4.2));
	float n1 = pt_n(p.xz / 13.0);
	float n2 = pt_n(p.xz / 4.1);
	float dd = d + (n1 - 0.5) * 9.0 + (n2 - 0.5) * 2.5 * fine;
	float pebbles = pt_n(p.xz / 1.5) * fine + 0.5 * (1.0 - fine);
	float slabs = pt_n(p.xz / 5.5 + 4.0);
	vec3 rock = mix(vec3(0.030, 0.034, 0.040), vec3(0.090, 0.092, 0.098), clamp(pebbles * 0.5 + slabs * 0.55, 0.0, 1.0));
	float wet_w = mix(1.2, 7.0, lobe_r);
	float wetness = 1.0 - smoothstep(wet_w * 0.5, wet_w + 3.0, dd);
	rock = rock * mix(1.0, 0.5, wetness);
	// Snow over the rock: a few metres' bare rim, then patchy cover that
	// thickens outward; the patches long with the wind.
	vec2 wd = vec2(0.82, 0.57);
	vec2 wp = vec2(dot(p.xz, wd), dot(p.xz, vec2(-wd.y, wd.x)));
	float drift = pt_n(vec2(wp.x / 14.0, wp.y / 5.0)) * 0.55 + pt_n(vec2(wp.x / 5.0, wp.y / 2.0) + 5.0) * 0.45;
	drift = mix(drift, 0.5, smoothstep(0.8, 3.0, fp));
	float cov = clamp((dd - wet_w * 0.8) / (reach * 0.8), 0.0, 1.0);
	cov = mix(cov, 1.0, lobe_s * 0.5 * smoothstep(0.0, 8.0, dd));
	float snowc = smoothstep(0.0, 0.22, cov * 1.35 + drift * 0.4 - 0.5);
	// The snow itself, bluer and a shade lower near the water.
	vec3 snow = albedo * mix(vec3(0.62, 0.72, 0.85), vec3(1.0), smoothstep(0.0, reach * 0.9, dd));
	vec3 surf = mix(rock, snow, snowc);
	float shelf_w = mix(0.8, 9.0, pt_n(vec2(a * 2.6 + 2.3, 7.1))) * (0.6 + 0.8 * n2);
	float shelf = 1.0 - smoothstep(shelf_w - 2.0, shelf_w, d);
	float cover;
	float crack;
	float lip;
	float tint;
	float id;
	pt_ice(p.xz, 1.0, fp, cover, crack, lip, tint, id);
	vec3 ice = pt_ice_colour(p.xz, tint, crack, lip, 1.0);
	// Plates breaking apart at the shelf's outer rim: the rock and snow show
	// between them.
	float ice_w = shelf * mix(0.6, 1.0, cover);
	surf = mix(surf, ice, ice_w);
	float w = 1.0 - smoothstep(reach + 1.0, reach + 6.0, d);
	rw.x = mix(mix(0.85, 0.3, wetness), 0.12, ice_w);
	rw.y = max((1.0 - snowc) * wetness, ice_w) * w;
	return mix(albedo, surf, w);
}

// Hook B: the water in display colour.
vec3 peak_tarn_water(vec3 p, vec3 eye, float fp, float t, vec3 ambient, vec3 key, float shaded) {
	vec3 e = pt_edge(p.xz);
	float din = max(-e.x, 0.0);
	float R = peak_tarn_a.x;
	float k = 1.0 - smoothstep(0.5, 3.0, fp);
	// Nearly still: a slow swell off the middle, a tremor over it.
	vec2 sl = vec2(sin(p.x * 0.9 + t * 0.55 + pt_n(p.xz / 7.0) * 6.0), cos(p.z * 1.1 - t * 0.43)) * 0.0035 * k;
	vec2 ru = (p.xz - peak_tarn.xy) / max(e.z, 1.0);
	sl += ru * cos(e.z * 0.36 - t * 0.7) * exp(-e.z / (R * 0.8)) * 0.0045 * k;
	vec3 n = normalize(vec3(-sl.x, 1.0, -sl.y));
	vec3 refl = reflect(-eye, n);
	refl.y = abs(refl.y);
	vec3 sky = pt_other_sky(refl, t);
	float fres = 0.20 + 0.80 * pow(1.0 - max(dot(eye, n), 0.0), 4.0);
	vec3 body = vec3(0.004, 0.009, 0.014);
	body += vec3(0.020, 0.026, 0.022) * (1.0 - smoothstep(0.0, 7.0, din)) * 0.7;
	float mid = e.z / (R * 0.5);
	body += vec3(0.004, 0.026, 0.024) * exp(-mid * mid) * (0.6 + 0.4 * sin(t * 0.35));
	vec3 col = body + sky * fres * 1.7;
	// How thick the ice is (1 at the shore, none past ~30 m in), by stretch.
	float wob = mix(0.55, 1.6, pt_n(vec2(e.y * 2.3 + 4.0, 1.7)));
	float thick = 1.0 - smoothstep(-5.0, 30.0, din * wob + (pt_n(p.xz / 26.0) - 0.5) * 16.0);
	if (thick > 0.01) {
		float cover;
		float crack;
		float lip;
		float tint;
		float id;
		pt_ice(p.xz, thick, fp, cover, crack, lip, tint, id);
		vec3 ice = pt_ice_colour(p.xz, tint, crack, lip, thick);
		vec3 lit = ice * (ambient * 1.15 + key * 0.35) * vec3(0.8, 0.96, 1.2) * (1.0 - 0.4 * shaded);
		vec3 ice_d = zs_scene_to_display(lit);
		// Each plate lies a little askew: it mirrors its own bit of the other
		// sky, so the plates glint differently.
		vec2 tilt = (pt_h2(vec2(id * 91.7, id * 13.3)) - 0.5) * 0.30;
		vec3 ri = reflect(-eye, normalize(vec3(tilt.x, 1.0, tilt.y)));
		ri.y = abs(ri.y);
		float fi = 0.08 + 0.5 * pow(1.0 - max(dot(eye, vec3(0.0, 1.0, 0.0)), 0.0), 3.0);
		ice_d += pt_other_sky(ri, t) * fi * (1.0 - 0.5 * thick);
		col = mix(col, ice_d, cover);
	}
	return clamp(col, vec3(0.0), vec3(1.0));
}
