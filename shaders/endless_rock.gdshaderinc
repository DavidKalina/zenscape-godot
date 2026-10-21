// The endless land's painted rock (shaders/endless_ground.gdshader), as a
// function any shader can include and call, so a rock mesh (an arch, a
// stack) is coloured as the land's rock is:
//
//   #include "res://shaders/endless_rock.gdshaderinc"
//   ...
//   vec3 bumped = n;                                  // world normal
//   float fp3 = er_footprint(world_position);         // call at top level
//   vec3 albedo = er_rock(world_position, n, fp3, sun, mossy, bumped);
//   // then light with `bumped` (NORMAL = (VIEW_MATRIX * vec4(bumped, 0)).xyz)
//
// `sun` is zs_sun_direction (toward the sun), `mossy` the turf colour that
// settles on its ledges (pass the land's grass, or a plain green).
//
// Everything is world-space 3D (no top-down projection, so no stretch at any
// slope): broad planes and facets (cells, each tilting the surface a little
// so the sun catches some and not others), strata that follow height and
// are waved and tilted, cracks along the cells' seams, a light lip on each
// ledge, turf and moss on what lies back. Light is painted in steps from a
// cool shadow tone to a warm lit one, on top of the sun's own lighting.
// Each scale fades to its mean tone where a pixel is wider than it, so far
// rock is the near rock's average and nothing shimmers.

// How much facets tilt the lit normal (0 none), the painted light's share,
// the moss's share, and a scale on every pattern's size.
uniform float rock_bump : hint_range(0.0, 1.5) = 0.55;
uniform float rock_paint : hint_range(0.0, 1.0) = 0.75;
uniform float rock_moss : hint_range(0.0, 2.0) = 1.0;
uniform float rock_size : hint_range(0.25, 4.0) = 1.0;

const vec3 ER_SHADOW = vec3(0.105, 0.115, 0.150);
const vec3 ER_MID = vec3(0.250, 0.225, 0.200);
const vec3 ER_LIT = vec3(0.580, 0.470, 0.330);
const vec3 ER_GLINT = vec3(0.780, 0.680, 0.520);
const vec3 ER_CRACK = vec3(0.045, 0.045, 0.060);

vec3 er_hash3(ivec3 c) {
	uvec3 v = uvec3(c) * 1664525u + 1013904223u;
	v.x += v.y * v.z;
	v.y += v.z * v.x;
	v.z += v.x * v.y;
	v ^= v >> 16u;
	v.x += v.y * v.z;
	v.y += v.z * v.x;
	v.z += v.x * v.y;
	return vec3(v & uvec3(65535u)) / 65535.0;
}

float er_vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = p - i;
	f = f * f * (3.0 - 2.0 * f);
	ivec3 q = ivec3(i);
	float a = mix(mix(er_hash3(q).x, er_hash3(q + ivec3(1, 0, 0)).x, f.x),
		mix(er_hash3(q + ivec3(0, 1, 0)).x, er_hash3(q + ivec3(1, 1, 0)).x, f.x), f.y);
	float b = mix(mix(er_hash3(q + ivec3(0, 0, 1)).x, er_hash3(q + ivec3(1, 0, 1)).x, f.x),
		mix(er_hash3(q + ivec3(0, 1, 1)).x, er_hash3(q + ivec3(1, 1, 1)).x, f.x), f.y);
	return mix(a, b, f.z);
}

// A pixel's footprint in the world (m), between its short and long sides.
float er_footprint(vec3 p) {
	float a = length(dFdx(p));
	float b = length(dFdy(p));
	return mix(min(a, b), max(a, b), 0.45);
}

// 3D cells with a random point each: x the nearest point's distance, y the
// seam's closeness (second minus first, 0 on a seam), zw unused; `rnd` the
// nearest cell's three random numbers.
vec2 er_cells(vec3 p, out vec3 rnd) {
	vec3 i = floor(p);
	vec3 f = p - i;
	float d1 = 9.0;
	float d2 = 9.0;
	rnd = vec3(0.5);
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 o = vec3(float(x), float(y), float(z));
				vec3 h = er_hash3(ivec3(i) + ivec3(x, y, z));
				float d = length(o + h - f);
				if (d < d1) {
					d2 = d1;
					d1 = d;
					rnd = er_hash3(ivec3(i) + ivec3(x, y, z) + ivec3(71, 13, 5));
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return vec2(d1, d2 - d1);
}

float er_keep(float scale, float fp) {
	return 1.0 - smoothstep(scale * 0.2, scale * 0.65, fp);
}

// A tilted unit normal from three random numbers, mostly sideways of `n`.
vec3 er_tilt(vec3 n, vec3 rnd, float amount) {
	vec3 r = rnd * 2.0 - 1.0;
	r -= n * dot(r, n);
	return normalize(n + r * amount);
}

// The rock's albedo at world point `p` on a surface of world normal `n`;
// `bumped` comes back the normal to light it with. See the file's head.
vec3 er_rock(vec3 p, vec3 n, float fp, vec3 sun, vec3 mossy, inout vec3 bumped) {
	float sz = rock_size;
	vec3 q = p / sz;
	float fq = fp / sz;
	// Broad drift of warm and cool over hundreds of metres.
	float drift = er_vnoise(p / 230.0 + vec3(5.0, 2.0, 9.0));
	// Waved, tilted strata: the bed coordinate.
	float warp = (er_vnoise(q / 55.0 + vec3(1.0, 7.0, 3.0)) - 0.5) * 16.0
		+ (er_vnoise(q / 17.0 + vec3(8.0, 2.0, 4.0)) - 0.5) * 3.4 * er_keep(17.0, fq);
	float sy = q.y + warp + q.x * 0.08 + q.z * 0.05;

	// Planes: coarse cells (a good 20 m) tilt the face, fine cells (6 m) break
	// it into facets.
	vec3 rnd_b;
	vec2 cell_b = er_cells(vec3(q.x, q.y * 1.5, q.z) / 38.0 + vec3(3.0, 1.0, 6.0), rnd_b);
	vec3 nf = er_tilt(n, rnd_b, 0.09 * rock_bump * er_keep(38.0, fq));
	vec3 rnd_f = vec3(0.5);
	vec2 cell_f = vec2(1.0, 1.0);
	float keep_f = er_keep(7.5, fq);
	if (keep_f > 0.0) {
		cell_f = er_cells(vec3(q.x, q.y * 2.6, q.z) / 7.5 + vec3(9.0, 4.0, 2.0), rnd_f);
		nf = er_tilt(nf, rnd_f, 0.035 * rock_bump * keep_f);
	}

	// The painted light: the facet's own sun, in steps from shadow to warm lit.
	float lit = dot(nf, sun) * 0.5 + 0.5;
	lit += (rnd_b.x - 0.5) * 0.07 * er_keep(38.0, fq) + (rnd_f.y - 0.5) * 0.02 * keep_f;
	float steps = 3.0;
	float soft = 0.18 + clamp(fq * 0.02, 0.0, 0.3);
	float tier = lit * steps;
	float t = floor(tier) + smoothstep(0.5 - soft, 0.5 + soft, fract(tier));
	t = clamp(t / (steps - 1.0) - 0.0, 0.0, 1.0);
	t = mix(lit, t, 0.7);
	t = 0.22 + t * 0.78;
	vec3 col = t < 0.5 ? mix(ER_SHADOW, ER_MID, t * 2.0) : mix(ER_MID, ER_LIT, t * 2.0 - 1.0);
	// A rock of its own: warm sandy to cool grey over the drift.
	col *= mix(vec3(0.86, 0.92, 1.08), vec3(1.14, 1.04, 0.84), smoothstep(0.25, 0.75, drift));

	// Beds: a tone step each bed (18, 6.4 and 2.2 m), crisp cracks between.
	float lip = 0.0;
	float crack = 0.0;
	float scales[3] = float[3](18.0, 6.4, 2.2);
	float amps[3] = float[3](0.42, 0.36, 0.12);
	float wide_k = 0.0;
	for (int k = 0; k < 3; k++) {
		float s = scales[k];
		float kp = er_keep(s, fq);
		if (kp <= 0.0) continue;
		float b = sy / s;
		float id = floor(b);
		float f = b - id;
		vec3 h = er_hash3(ivec3(int(id), k * 17 + 3, 11));
		col *= 1.0 + (h.x - 0.5) * 2.0 * amps[k] * kp;
		if (k < 2) col *= mix(vec3(1.0), mix(vec3(0.90, 0.97, 1.08), vec3(1.10, 1.02, 0.86), h.z), kp * 1.0);
		// Thin dark seam at a bed's foot, a pale lip at the top of the one below.
		float w = max(0.045, fq / s * 0.9);
		float seam = (1.0 - smoothstep(0.0, w * 1.5, f)) * (0.5 + 0.5 * h.y);
		float edge = smoothstep(1.0 - w * 4.0, 1.0 - w * 1.2, f) * (1.0 - smoothstep(1.0 - w * 1.2, 1.0, f));
		crack = max(crack, seam * kp * (k == 0 ? 0.75 : (k == 1 ? 1.0 : 0.35)));
		lip = max(lip, edge * kp * (0.5 + 0.5 * h.z));
	}
	// Vertical joints between blocks, each bed's own spacing and offset, some
	// missing; and long fissures running down the face.
	vec2 along = normalize(vec2(-n.z, n.x) + vec2(0.0001));
	float u = dot(q.xz, along);
	float joint = 0.0;
	{
		float bs = 6.4;
		float jk = er_keep(bs, fq);
		float bid = floor(sy / bs);
		vec3 hb = er_hash3(ivec3(int(bid), 5, 23));
		float len = 7.0 + hb.x * 9.0;
		float uu = u / len + hb.y * 5.0;
		float ju = floor(uu);
		float fu = uu - ju;
		float present = step(0.4, er_hash3(ivec3(int(ju), int(bid), 41)).x);
		float jw = max(0.02, fq / len * 0.9);
		joint = (1.0 - smoothstep(0.0, jw * 1.6, fu)) * present * jk * smoothstep(0.55, 0.3, n.y);
		// Each block catches the light a little differently.
		col *= 1.0 + (er_hash3(ivec3(int(ju), int(bid), 77)).y - 0.5) * 0.22 * jk * smoothstep(0.55, 0.3, n.y);
	}
	float fis = er_vnoise(vec3(q.x / 11.0, q.y / 80.0, q.z / 11.0) + vec3(6.0, 3.0, 1.0));
	float fisk = er_keep(2.0, fq);
	float fissure = (1.0 - smoothstep(0.0, 0.07 + fq / 11.0 * 0.5, abs(fis - 0.5))) * fisk * smoothstep(0.7, 0.4, n.y);
	crack = max(crack, joint * 0.8);
	col *= 1.0 - fissure * 0.28;
	// Cracks down the seams between facets.
	float seam_f = (1.0 - smoothstep(0.0, 0.035 + fq / 7.5 * 0.5, cell_f.y)) * keep_f * 0.0;
	float seam_b = (1.0 - smoothstep(0.0, 0.035 + fq / 38.0 * 0.5, cell_b.y)) * er_keep(38.0, fq) * 0.25;
	crack = max(crack, max(seam_f, seam_b));
	// Dry-brush strokes along the beds: light flecks on the lit side.
	float stroke = er_vnoise(vec3(q.x / 7.0, q.y / 0.8, q.z / 7.0) + vec3(4.0, 1.0, 8.0));
	float sk = er_keep(0.8, fq);
	col *= 1.0 + (smoothstep(0.55, 0.62, stroke) - 0.5) * 0.4 * sk * (0.4 + t);
	// Weathering streaks running down the face.
	float gully = er_vnoise(vec3(q.x / 2.6, q.y / 36.0, q.z / 2.6) + vec3(2.0, 0.0, 5.0));
	float gk = er_keep(2.6, fq);
	col *= 1.0 - smoothstep(0.55, 0.8, gully) * 0.5 * gk * (1.0 - nf.y);
	// A pale lip along the facet's top and along the lit side of a seam.
	col = mix(col, ER_GLINT, lip * (0.35 + 0.6 * t) * 0.9);
	col = mix(col, ER_CRACK, clamp(crack, 0.0, 1.0) * 0.85);

	// Turf and moss settle where the face lies back, ragged by the facets.
	float lay = nf.y + (er_vnoise(q / 7.0) - 0.5) * 0.2 + (er_vnoise(q / 2.3) - 0.5) * 0.1 * er_keep(2.3, fq);
	float settle = smoothstep(0.50, 0.68, lay) * rock_moss;
	// More on the lip of a bed, none in a crack.
	settle = clamp(settle + lip * 0.25 * smoothstep(0.3, 0.6, lay) * rock_moss, 0.0, 1.0) * (1.0 - crack * 0.9);
	col = mix(col, mossy * mix(vec3(0.85), vec3(1.0, 1.05, 0.7), er_vnoise(q / 13.0)), settle * 0.8);

	// The sun's own light takes the facets' normal.
	bumped = normalize(mix(n, nf, 0.7));
	return mix(col, ER_MID * 1.2, 1.0 - rock_paint) ;
}
