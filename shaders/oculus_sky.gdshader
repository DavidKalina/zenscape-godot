shader_type sky;
// The oculus sky (scripts/underground/underground.gd, preset `oculus`): the
// underground seen
// from the dark. Above, a cavern roof of carved rock with one vast round
// opening, a thick rock throat round it that catches the key light, and
// through it the open sky with a deck of billowing cloud seen from beneath.
// Below, the abyss filled with a heaped sea of mist lit faintly from within.
// Everything is traced from the camera (POSITION), so the opening has true
// parallax, the clouds slide across it as he walks, and it is seen
// foreshortened when it lies off to one side.
//
// Round 2 stops painting soft noise. The rock is faceted: broad slabs and
// ribs with clean seams, each facet its own tone and tilt, so the spill from
// the opening picks out some and leaves others dark. The clouds are heaped
// domes (the opal sea's puffs) whose undersides are shaded and whose rims
// are lit. The mist is the same heaped puffs seen from above. Every seam and
// rim is as wide as a pixel at least and fades out by its footprint, so
// nothing shimmers.
uniform vec3 oculus = vec3(0.0, 400.0, 0.0);   // the opening's centre (world)
uniform float radius = 160.0;                  // its radius (m)
uniform float throat = 150.0;                  // how thick the rock round it is (m)
uniform float cloud_height = 900.0;            // the cloud deck over the opening (m)
uniform float sea_y = -120.0;                  // the mist sea's surface (world y)
uniform vec3 sun_dir = vec3(0.3, 0.8, 0.5);    // toward the sun
uniform float glory = 1.0;                     // the opening's brightness gain
uniform float sea_glow = 1.0;                  // the mist's inner light
uniform float vault_lift = 1.0;                // the roof's own light
uniform vec3 spill_color : source_color = vec3(1.0, 0.70, 0.42);
uniform vec3 haze_color : source_color = vec3(0.10, 0.16, 0.18);
uniform vec3 sea_deep : source_color = vec3(0.07, 0.15, 0.17);
uniform vec3 sea_pale : source_color = vec3(0.50, 0.70, 0.70);
uniform vec3 pool_at = vec3(0.0, 0.0, 0.0);    // where the shaft lands (world), the sea lit under it
uniform float haze_reach = 1500.0;             // m to the horizon's full haze

const float PIX = 0.0020;                      // a pixel's angle (rad), for the footprint fades

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
vec2 h22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
// Fractal noise whose finer octaves fade where they would shimmer (`blur` is
// the pattern's footprint per pixel, in cells).
float fbm(vec2 p, float blur) {
	float s = 0.0, a = 0.5, n = 0.0;
	for (int i = 0; i < 4; i++) {
		float keep = i == 0 ? 1.0 : 1.0 - smoothstep(0.25, 0.7, blur);
		s += a * mix(0.5, vn(p), keep);
		p = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 2.07 + 11.3;
		blur *= 2.07;
		a *= 0.5;
	}
	return s;
}

// Jittered cells: x the nearest point's distance, y the second's, zw the
// nearest cell's id. `wrap` > 0 makes the cells repeat every `wrap` along x
// (a ring of ribs round the opening has no seam).
vec4 vor(vec2 p, float wrap) {
	vec2 i = floor(p), f = fract(p);
	float d1 = 9.0, d2 = 9.0;
	vec2 best = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 c = i + g;
			if (wrap > 0.0) c.x = mod(c.x, wrap);
			float d = length(g + h22(c) - f);
			if (d < d1) { d2 = d1; d1 = d; best = c; }
			else if (d < d2) d2 = d;
		}
	}
	return vec4(d1, d2, best);
}

// Heaped puffs (the opal cloud sea's: a dome on a jittered lattice, the
// tallest at each point, neighbours meeting in soft creases).
float puffs(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	float top = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 c = i + g;
			vec2 d = g + vec2(h21(c), h21(c + vec2(17.3, 5.1))) - f;
			float r = 0.6 + 0.4 * h21(c + vec2(3.7, 11.9));
			float dome = sqrt(max(1.0 - dot(d, d) / (r * r), 0.0)) * r;
			float k = clamp(0.5 + 0.5 * (dome - top) / 0.22, 0.0, 1.0);
			top = mix(top, dome, k) + 0.22 * k * (1.0 - k);
		}
	}
	return top;
}
// Two sizes of puffs, the small riding the large; the small fade out by footprint.
float heap(vec2 p, float foot) {
	float k2 = 1.0 - smoothstep(0.3, 0.8, foot * 2.4);
	float k3 = 1.0 - smoothstep(0.3, 0.8, foot * 5.5);
	float h = puffs(p) * 0.72;
	h += mix(0.35, puffs(p * 2.4 + 7.3), k2) * 0.28;
	h += (mix(0.35, puffs(p * 5.5 + 3.1), k3) - 0.35) * 0.1;
	return h;
}

// The rim of the opening: lobes and bites, quiet in the middle distance.
float wobble(float phi) {
	return (vn(vec2(phi * 3.0, 1.7)) - 0.5) * 0.22 + (vn(vec2(phi * 9.0, 4.1)) - 0.5) * 0.09 + (vn(vec2(phi * 23.0, 8.3)) - 0.5) * 0.03;
}

// --- The open sky ---------------------------------------------------------------

// The sky through the opening, from the eye `P` along `d`: opal blue that
// pales to pearl toward the rim, a glory about the sun, and two decks of
// heaped cloud seen from beneath, their rims lit and their hearts shaded,
// with rifts onto the blue between.
vec3 sky_through(vec3 P, vec3 d, vec3 sun) {
	float up = max(d.y, 0.1);
	vec3 zenith = vec3(0.10, 0.28, 0.95);
	vec3 pearl = vec3(0.98, 0.92, 1.0);
	float low = 1.0 - smoothstep(0.1, 0.9, d.y);
	vec3 col = mix(zenith, pearl, low * 0.85);
	float toward = max(dot(d, sun), 0.0);
	vec3 warm = vec3(1.0, 0.80, 0.55);
	col += warm * (pow(toward, 5.0) * 0.22 + pow(toward, 60.0) * 0.7);
	// The high deck: a thin, wide, drifting veil, lit gold toward the sun.
	{
		float t = (oculus.y + cloud_height * 2.3 - P.y) / up;
		vec2 p = (P.xz + d.xz * t) / 700.0 + vec2(TIME * 0.0032, TIME * 0.0015);
		float foot = t * PIX / up / 700.0;
		float v = fbm(p * vec2(1.0, 2.4), foot);
		float veil = smoothstep(0.5, 0.74, v) * 0.55 * smoothstep(0.1, 0.4, d.y);
		col = mix(col, mix(pearl, warm * 1.1, pow(toward, 3.0) * 0.7) * 0.95, veil);
	}
	// The low deck: heaped billows.
	{
		float t = (oculus.y + cloud_height - P.y) / up;
		float cell = 230.0;
		vec2 p = (P.xz + d.xz * t) / cell + vec2(TIME * 0.0045, TIME * 0.0020);
		float foot = t * PIX / up / cell;
		float warp_keep = 1.0 - smoothstep(0.1, 0.4, foot);
		p += (vec2(vn(p * 0.45 + 3.1), vn(p * 0.45 + 9.4)) - 0.5) * 0.6 * warp_keep;
		float h = heap(p, foot);
		float side = 0.09;
		vec2 sx = normalize(sun.xz + 1e-4);
		float ahead = heap(p + sx * side, foot);
		float lit = clamp((ahead - h) * 7.0 + 0.5, 0.0, 1.0);
		float soft = max(0.06, foot * 1.1);
		float edge_h = 0.52;
		float cover = smoothstep(edge_h - soft, edge_h + soft, h);
		float rim = cover * (1.0 - smoothstep(edge_h + soft, edge_h + soft + 0.22, h));
		// From beneath: thin cloud is bright, lit through; the thick heart a cool shade.
		float thick = smoothstep(0.6, 1.1, h);
		vec3 heart = vec3(0.40, 0.44, 0.62) * (0.8 + 0.4 * lit);
		vec3 thin = mix(vec3(0.92, 0.9, 1.0), vec3(1.15, 0.98, 0.8), lit * (0.5 + 0.5 * toward));
		vec3 cl = mix(thin, heart, thick * 0.9);
		cl += warm * rim * (0.35 + 0.5 * toward) * lit;
		float horizon_fade = smoothstep(0.08, 0.35, d.y);
		col = mix(col, cl, cover * (0.7 + 0.3 * horizon_fade));
	}
	return col;
}

// --- The rock ---------------------------------------------------------------------

// A face of the roof or the throat: `tone` its value, `seam` the cut line
// between facets (1 on it), `edge` the chamfer lit beside the seam, `tilt`
// the facet's own lean. `foot` is the footprint in cells; seams and
// the per-facet variation fade out as it grows.
struct Facet { float tone; float seam; float edge; vec2 tilt; };
Facet facet_of(vec4 v, float foot, float strength) {
	Facet f;
	vec2 r = h22(v.zw + 3.7);
	float keep = 1.0 - smoothstep(0.25, 0.8, foot);
	f.tone = mix(0.4, 1.1, h21(v.zw + 8.3));
	f.tone = mix(0.8, f.tone, keep);
	f.tilt = (r - 0.5) * 2.0 * keep * strength;
	float gap = v.y - v.x;
	float w = max(0.035, foot * 1.3);
	f.seam = (1.0 - smoothstep(w * 0.5, w, gap)) * (1.0 - smoothstep(0.35, 0.9, foot));
	f.edge = smoothstep(w * 0.8, w * 2.2, gap) * (1.0 - smoothstep(w * 2.2, w * 7.0 + 0.04, gap)) * (1.0 - smoothstep(0.3, 0.7, foot));
	return f;
}

// Grain on rock: strata or flutes (`along` the stretch) plus fine flecks,
// faded by footprint `foot_m` in metres.
float grain(vec2 p, float foot_m) {
	float fine = 1.0 - smoothstep(0.4, 2.0, foot_m);
	float g = vn(p * 0.35) * 0.6 + vn(p * 1.1 + 4.0) * 0.4 * fine;
	return (g - 0.5) * (0.35 + 0.65 * fine);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 sun = normalize(sun_dir);
	vec3 P = POSITION;
	vec3 col;
	vec3 haze = haze_color;
	if (d.y < -0.002) {
		// --- The mist sea: heaped billows seen from above, lit from within. ---
		float t = (sea_y - P.y) / d.y;
		vec2 p = P.xz + d.xz * t;
		float cell = 170.0;
		float foot = t * PIX / max(-d.y, 0.04) / cell;
		vec2 q = p / cell + vec2(TIME * 0.0030, -TIME * 0.0013);
		float warp_keep = 1.0 - smoothstep(0.1, 0.45, foot);
		q += (vec2(vn(q * 0.4 + 3.1), vn(q * 0.4 + 9.4)) - 0.5) * 0.7 * warp_keep;
		float h = heap(q * 0.8, foot * 0.8);
		vec2 sx = normalize(sun.xz + 1e-4);
		float ahead = heap(q * 0.8 + sx * 0.1, foot * 0.8);
		float lit = clamp((h - ahead) * 7.0 + 0.5, 0.0, 1.0);
		// Broad swells so the heaps gather into banks and clearings.
		float bank = smoothstep(0.25, 0.75, vn(q * 0.18 + 5.0) * 0.6 + vn(q * 0.07 + 1.0) * 0.4);
		// Heaped cloud, seen from above: pale pearl on the crowns, jade in the
		// creases between, each heap's side to the key lit and its far side in
		// shade. The light comes up from within, so even the creases glow.
		float tt = smoothstep(0.18, 0.95, h * (0.85 + 0.3 * bank));
		vec3 crease_c = sea_deep * vec3(0.7, 1.0, 1.1);
		vec3 base = mix(crease_c, sea_pale * vec3(1.45, 1.4, 1.3), pow(tt, 1.35));
		float shade = 0.82 + 0.36 * lit;
		vec3 sea = base * shade;
		// A pale edge where the slope turns to the key.
		sea += sea_pale * smoothstep(0.72, 1.0, lit) * smoothstep(0.2, 0.6, tt) * 0.22;
		float pool = exp(-pow(length(p - pool_at.xz) / 230.0, 2.0));
		sea = mix(sea, sea * vec3(1.45, 1.22, 0.95) + spill_color * 0.03, pool * 0.65);
		sea *= sea_glow;
		float far = 1.0 - exp(-pow(t / haze_reach, 0.8));
		col = mix(sea, haze * 1.7 + sea_pale * 0.1 * sea_glow, far);
	} else {
		// --- Above: the roof, the throat and the sky. ---
		float t0 = (oculus.y - P.y) / max(d.y, 0.0005);
		vec2 p = P.xz + d.xz * t0;
		vec2 rel = p - oculus.xz;
		float r = length(rel);
		float phi = atan(rel.y, rel.x);
		float R = radius * (1.0 + wobble(phi));
		float over = r - R;
		float foot_m = t0 * PIX / max(d.y, 0.04);
		vec3 spill_warm = spill_color;
		if (over < 0.0) {
			// Inside the opening: the throat's wall, or the sky if the ray clears it.
			vec2 d2 = d.xz;
			float a = max(dot(d2, d2), 1e-6);
			float Rw = R;
			float u = 0.0;
			for (int k = 0; k < 3; k++) {
				float b = dot(rel, d2);
				float c = dot(rel, rel) - Rw * Rw;
				u = (-b + sqrt(max(b * b - a * c, 0.0))) / a;
				vec2 hit = rel + d2 * u;
				Rw = radius * (1.0 + wobble(atan(hit.y, hit.x)));
			}
			vec2 hit = rel + d2 * u;
			float phi_w = atan(hit.y, hit.x);
			float depth = d.y * u;                    // how high up the throat the ray strikes
			float wall_h = throat * (0.75 + 0.5 * vn(vec2(phi_w * 2.0, 9.1)));
			if (depth < wall_h) {
				// The throat's wall: fluted, bedded, catching the key light.
				float t_w = t0 + u;
				float foot_w = t_w * PIX / max(abs(dot(normalize(vec3(-hit.x, 0.0, -hit.y)), d)), 0.08);
				float arc = phi_w * Rw;
				vec2 wp = vec2(arc, depth);
				vec4 v = vor(vec2(arc / 46.0, depth / 80.0), 0.0);
				float fc = foot_w / 46.0;
				Facet f = facet_of(v, fc, 1.0);
				vec3 n = normalize(vec3(-hit.x, 0.0, -hit.y));
				// Beds across the flutes.
				float bed = 0.5 + 0.5 * sin(depth * 0.42 + vn(wp * 0.05) * 6.0);
				float rockv = f.tone * (0.78 + 0.22 * bed) * (1.0 + grain(wp, foot_w));
				float facing = max(dot(vec3(n.x + f.tilt.x * 0.4, f.tilt.y * 0.4, n.z), vec3(sun.x, 0.0, sun.z)) * 1.4 + 0.1, 0.0);
				float lit = pow(clamp(facing, 0.0, 1.0), 0.8);
				// Sky light falls down the throat: brightest at its lip, gone by its foot.
				float skylight = exp(-(wall_h - depth) / (throat * 0.5)) ;
				vec3 stone = vec3(0.30, 0.285, 0.27);
				vec3 c = stone * rockv * (lit * spill_warm * 2.2 * glory + skylight * vec3(0.5, 0.6, 0.7) * glory * 0.7 + vec3(0.03, 0.05, 0.06));
				c += stone * spill_warm * f.edge * lit * 0.8 * glory * skylight;
				c *= 1.0 - f.seam * 0.8;
				// A warm lip where the wall's top meets the sky, and a dark cut where it meets the roof.
				float lip = exp(-(wall_h - depth) / 7.0);
				c += spill_warm * lip * 0.6 * glory * (0.5 + 0.5 * lit);
				c *= mix(0.25, 1.0, smoothstep(0.0, 14.0, depth));
				col = c;
			} else {
				vec3 through = sky_through(P, d, sun) * glory * 0.8;
				// A brighter sky just inside the lip, as the eye adapts.
				col = through * (1.0 + 0.25 * exp(-max(wall_h - depth, 0.0) / 25.0));
			}
		} else {
			// The roof: carved slabs and ribs, lit by what spills from the opening.
			// Near the opening the facets run as ribs out from it (log-polar cells),
			// far from it as broad slabs.
			float N = 16.0;
			vec2 lp = vec2(phi / 6.2831853 * N, log(max(r, 1.0)) * 2.0);
			// Seams wander: faults, not a drawn grid.
			lp += (vec2(vn(lp * 0.7 + 4.0), vn(lp * 0.7 + 13.0)) - 0.5) * 0.5;
			vec4 v1 = vor(lp, N);
			float size1 = max(r, 1.0) * 0.4;
			Facet f1 = facet_of(v1, foot_m / size1, 1.1);
			// A finer set of facets cut into each rib, its seams fainter.
			vec4 v1b = vor(lp * 2.3 + 17.0, 0.0);
			Facet f1b = facet_of(v1b, foot_m / (size1 * 0.43), 0.7);
			f1.seam = max(f1.seam, f1b.seam * 0.4);
			f1.edge = max(f1.edge, f1b.edge * 0.5);
			f1.tone *= mix(1.0, f1b.tone, 0.45);
			f1.tilt += f1b.tilt * 0.5;
			vec2 cp = rel / 90.0 + (vec2(vn(rel / 200.0), vn(rel / 200.0 + 7.0)) - 0.5) * 0.5;
			vec4 v2 = vor(cp, 0.0);
			Facet f2 = facet_of(v2, foot_m / 90.0, 0.9);
			float far_mix = smoothstep(1.8 * radius, 5.0 * radius, r);
			Facet f;
			f.tone = mix(f1.tone, f2.tone, far_mix * 0.7);
			f.tilt = mix(f1.tilt, f2.tilt, far_mix);
			f.seam = max(f1.seam * (1.0 - far_mix * 0.6), f2.seam * 0.55 * far_mix);
			f.edge = max(f1.edge * (1.0 - far_mix * 0.5), f2.edge * 0.4);
			// Hanging masses: a few great knuckles of rock between the ribs.
			float wash = vn(rel / 420.0 + 21.0) * 0.65 + vn(rel / 150.0 + 3.0) * 0.35;
			// Broad painted washes with clean edges: value laid in steps, not a haze.
			float mass = mix(floor(wash * 4.0) / 4.0, wash, 0.25);
			float stratum = grain(rel * 0.8, foot_m);
			vec2 to_hole = -rel / max(r, 1.0);
			// How the facet turns to the opening: half-Lambert against its direction.
			vec3 L = normalize(vec3(to_hole.x, 0.35, to_hole.y));
			vec3 nf = normalize(vec3(f.tilt.x + to_hole.x * 0.35, -1.0, f.tilt.y + to_hole.y * 0.35));
			float turn = clamp(0.5 + 0.9 * dot(nf, L), 0.0, 1.0);
			float fall = exp(-max(over, 0.0) / (radius * 0.55));
			float fall_far = exp(-max(over, 0.0) / (radius * 2.4));
			vec3 stone = vec3(0.26, 0.255, 0.25);
			float rockv = f.tone * (1.0 + stratum * 0.5) * (0.6 + 0.9 * mass);
			vec3 vault = stone * rockv * (
				spill_warm * pow(turn, 1.6) * fall * 1.5 * glory * vault_lift
				+ vec3(0.35, 0.55, 0.58) * (0.25 + 0.75 * turn) * fall_far * 0.1 * vault_lift
				+ vec3(0.022, 0.038, 0.044));
			vault += stone * spill_warm * f.edge * fall * 0.55 * glory * vault_lift * turn;
			vault *= 1.0 - f.seam * 0.75;
			// The roof's lip against the throat: a thin hot line.
			vault += spill_warm * exp(-over / (radius * 0.02)) * 0.5 * glory * vault_lift;
			// Far roof sinks into the cavern's haze.
			float far = 1.0 - exp(-t0 / (haze_reach * 1.6));
			vault = mix(vault, haze * 0.7, far);
			col = vault;
			// Lens glow just past the rim (bloom does the rest).
			col += spill_warm * exp(-over / (radius * 0.1)) * 0.03 * glory;
		}
		// Grazing rays to the horizon: dim haze, the roof going away.
		col = mix(col, haze * 1.4, smoothstep(0.22, 0.0, d.y) * 0.85);
	}
	// A pale line of mist-light where roof meets sea: the horizon the city sets itself against.
	col = mix(col, haze * 2.3 + sea_pale * 0.05, exp(-abs(d.y) * 22.0) * 0.55);
	COLOR = col;
}
