// The endless land's painted rock (shaders/endless_ground.gdshader), as a
// function any shader can include and call, so a rock mesh (an arch, a
// stack) is coloured as the land's rock is:
//
//   #include "res://shaders/endless_rock.gdshaderinc"
//   ...
//   vec3 bumped = n;                                  // world normal
//   float fp3 = er_footprint(world_position);         // call at top level
//   vec3 albedo = er_rock(world_position, n, fp3, sun, mossy, vec2(0.0), bumped, glow);
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
// Pass 2: big forms broken into flat painted planes (0 off), how much of the
// shade is lifted and coloured by bounce light, and the first pass's look.
uniform float rock_facets : hint_range(0.0, 1.5) = 1.0;
uniform float rock_bounce : hint_range(0.0, 2.0) = 1.0;
uniform bool rock_pass1 = false;

// Erosion round: a tileable relief of runnels (down the face), ledges (along
// it) and rounded bulges, projected in world space on three axes at two sizes.
// rock_relief is its strength (0 off), rock_relief_size scales both tiles,
// rock_calm (0..1) quiets pass 2's painted plane tones and facets so the relief
// does the work; rock_flat gives pass 2 exactly as it was.
uniform sampler2D rock_erosion_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float rock_relief : hint_range(0.0, 3.0) = 1.2;
uniform float rock_relief_size : hint_range(0.25, 4.0) = 1.0;
uniform float rock_calm : hint_range(0.0, 1.0) = 0.5;
uniform bool rock_flat = false;

// Carve round (land_field.gd carves the steep rock's shape): the carve's
// groove darkened and its crests lit (rock_carve_shade, 0 off), pass 2's bed
// seams and lips kept at rock_seams of their old strength, its planes' tone
// and tilt calmed only by rock_plane_calm (rock_calm still quiets the rest),
// the relief's big tile at rock_relief_big of its old strength, and the
// relief restarted per 70 m block with its own offset and spacing.
uniform float rock_carve_shade : hint_range(0.0, 2.0) = 1.0;
uniform float rock_seams : hint_range(0.0, 1.0) = 0.12;
uniform float rock_beds : hint_range(0.0, 1.0) = 0.65;
uniform float rock_plane_calm : hint_range(0.0, 1.0) = 0.1;
uniform float rock_relief_big : hint_range(0.0, 1.0) = 0.45;

const vec3 ER_SHADOW1 = vec3(0.105, 0.115, 0.150);
const vec3 ER_SHADOW = vec3(0.135, 0.130, 0.175);
const vec3 ER_SKY_BOUNCE = vec3(0.30, 0.38, 0.72);
const vec3 ER_GROUND_BOUNCE = vec3(0.95, 0.60, 0.34);
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

float er_snap(float x, float w, out float id) {
	id = floor(x);
	return id + smoothstep(0.5 - w, 0.5 + w, x - id) ;
}

// The surface normal broken into flat planes: its direction (azimuth and
// elevation) snapped to steps, warped by slow noise so the planes' edges
// wander, and `id` a number per plane for its own tone.
vec3 er_planes(vec3 n, vec3 p, float steps_az, float steps_el, float w, out vec2 id) {
	float warp_a = (er_vnoise(p / 53.0 + vec3(2.0, 6.0, 1.0)) - 0.5) * 0.9;
	float warp_e = (er_vnoise(p / 41.0 + vec3(7.0, 3.0, 5.0)) - 0.5) * 0.5;
	float az = atan(n.z, n.x) + warp_a;
	float el = asin(clamp(n.y, -1.0, 1.0)) + warp_e;
	float ia;
	float ie;
	float a = er_snap(az / 6.2831853 * steps_az + 0.5, w, ia);
	float e = er_snap(el / 1.5707963 * steps_el + 0.5, w * 1.3, ie);
	id = vec2(ia, ie);
	az = (a - 0.5) / steps_az * 6.2831853 - warp_a;
	el = (e - 0.5) / steps_el * 1.5707963 - warp_e;
	el = clamp(el, -1.45, 1.45);
	return vec3(cos(el) * cos(az), sin(el), cos(el) * sin(az));
}

// Relief: the sum of two tiles' normal offsets (world), and `cav` the cavity
// (0 hollow .. 1 proud, 0.5 flat), faded as pixels widen past each tile's forms.
// `rnd` restarts the pattern per block (offset, spacing); unless rock_flat a
// second, shifted and wider sample blends in by a slow noise, so the flutes'
// spacing and width wander.
vec4 er_relief_tap(vec3 p, vec3 w, float T, vec2 sh, vec2 dx, vec2 dy, out float a_h) {
	vec4 a = textureGrad(rock_erosion_tex, vec2(p.x, -p.y) / T + sh, dx, dy);
	vec4 b = textureGrad(rock_erosion_tex, vec2(p.z + 37.0, -p.y) / T + sh, dx, dy);
	vec4 c = textureGrad(rock_erosion_tex, vec2(p.x + 11.0, p.z) / T + sh, dx, dy);
	vec2 ta = a.xy * 2.0 - 1.0;
	vec2 tb = b.xy * 2.0 - 1.0;
	vec2 tc = c.xy * 2.0 - 1.0;
	a_h = w.z * a.a + w.x * b.a + w.y * c.a;
	// A top face's runnels have no down-slope; keep it to the bulges.
	return vec4(w.z * vec3(ta.x, -ta.y, 0.0) + w.x * vec3(0.0, -tb.y, tb.x) + w.y * 0.5 * vec3(tc.x, 0.0, tc.y), a.b);
}

vec3 er_relief(vec3 p, vec3 n, float fp, vec3 rnd, out float cav) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z + 1e-5);
	vec3 off = vec3(0.0);
	cav = 0.5;
	float tiles[2] = float[2](110.0, 38.0);
	float amps[2] = float[2](1.0, 0.55);
	float keeps[2] = float[2](14.0, 5.0);
	float mixer = rock_flat ? 0.0 : smoothstep(0.3, 0.7, er_vnoise(p / 47.0 + vec3(3.0, 9.0, 1.0)));
	for (int k = 0; k < 2; k++) {
		float T = tiles[k] * rock_relief_size * (rock_flat ? 1.0 : 0.82 + 0.36 * rnd.z);
		float kp = er_keep(keeps[k] * rock_relief_size, fp);
		if (kp <= 0.0) continue;
		float amp = amps[k] * (k == 0 && !rock_flat ? rock_relief_big : 1.0);
		vec2 g = vec2(fp / T);
		vec2 dx = vec2(g.x, 0.0);
		vec2 dy = vec2(0.0, g.y);
		vec2 sh = vec2(float(k) * 0.37, float(k) * 0.61) + (rock_flat ? vec2(0.0) : rnd.xy * 7.31);
		float ha;
		vec4 o = er_relief_tap(p, w, T, sh, dx, dy, ha);
		if (o.w < 0.1) return vec3(0.0);
		if (mixer > 0.0) {
			// The second: half again as wide, shifted, its own block offset.
			float hb;
			float T2 = T * 1.47;
			vec4 o2 = er_relief_tap(p + vec3(19.0, 0.0, 23.0), w, T2, sh.yx * 1.7 + 0.29, dx / 1.47, dy / 1.47, hb);
			o.xyz = mix(o.xyz, o2.xyz * 0.9, mixer);
			ha = mix(ha, hb, mixer);
		}
		off += o.xyz * amp * kp;
		cav += (ha - 0.5) * amp * kp * 0.5;
	}
	return off;
}

// The rock's albedo at world point `p` on a surface of world normal `n`;
// `bumped` comes back the normal to light it with. See the file's head.
vec3 er_rock(vec3 p, vec3 n, float fp, vec3 sun, vec3 mossy, vec2 carved, inout vec3 bumped, out vec3 glow) {
	glow = vec3(0.0);
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
	vec2 plane_id = vec2(0.0);
	vec2 cell_c = vec2(1.0, 1.0);
	vec3 rnd_c = vec3(0.5);
	float plane_calm = rock_flat ? 0.0 : rock_plane_calm;
	float facet_k = 0.0;
	if (!rock_pass1 && rock_facets > 0.0) {
		// Flat planes that follow the form (the normal snapped), each tilted a
		// little more by its own random cell, then smaller planes up close.
		float steep = smoothstep(0.97, 0.55, n.y);
		facet_k = rock_facets * (0.7 + 0.3 * steep);
		vec3 np = er_planes(n, p / sz, 9.0, 6.0, 0.05 + fq * 0.004, plane_id);
		cell_c = er_cells(vec3(q.x, q.y * 1.3, q.z) / 70.0 + vec3(1.0, 8.0, 2.0), rnd_c);
		np = er_tilt(np, rnd_c, 0.34 * rock_bump * (1.0 - 0.5 * plane_calm));
		nf = normalize(mix(nf, np, clamp(0.95 * facet_k, 0.0, 1.0)));
		nf = er_tilt(nf, rnd_b, 0.34 * rock_bump * er_keep(38.0, fq) * facet_k * (1.0 - 0.5 * plane_calm));
	}
	float cav = 0.5;
	if (!rock_pass1 && !rock_flat && rock_relief > 0.0) {
		vec3 off = er_relief(p, n, fp, rnd_c, cav);
		nf = normalize(nf + off * rock_relief);
	}
	vec3 rnd_f = vec3(0.5);
	vec2 cell_f = vec2(1.0, 1.0);
	float keep_f = er_keep(7.5, fq);
	if (keep_f > 0.0) {
		cell_f = er_cells(vec3(q.x, q.y * 2.6, q.z) / 7.5 + vec3(9.0, 4.0, 2.0), rnd_f);
		nf = er_tilt(nf, rnd_f, (rock_pass1 ? 0.035 : 0.11 * (0.4 + 0.6 * facet_k)) * rock_bump * keep_f);
	}

	// The painted light: the facet's own sun, in steps from shadow to warm lit.
	float lit = dot(nf, sun) * 0.5 + 0.5;
	// Down a deep groove (the carve's, a canyon's: `carved.x`) the sun seldom
	// reaches: its painted light leans to the shade tone, so a wall in real
	// shadow is not painted with sunlit facets (they read as pale sheets).
	if (!rock_flat) lit = mix(lit, min(lit, 0.3), smoothstep(0.6, 1.0, carved.x) * rock_carve_shade);
	lit += (rnd_b.x - 0.5) * 0.07 * er_keep(38.0, fq) + (rnd_f.y - 0.5) * 0.02 * keep_f;
	float steps = 3.0;
	float soft = 0.18 + clamp(fq * 0.02, 0.0, 0.3);
	float tier = lit * steps;
	float t = floor(tier) + smoothstep(0.5 - soft, 0.5 + soft, fract(tier));
	t = clamp(t / (steps - 1.0) - 0.0, 0.0, 1.0);
	t = mix(lit, t, 0.7);
	vec3 shadow_tone = rock_pass1 ? ER_SHADOW1 : ER_SHADOW;
	t = rock_pass1 ? 0.22 + t * 0.78 : 0.26 + t * 0.74;
	vec3 col = t < 0.5 ? mix(shadow_tone, ER_MID, t * 2.0) : mix(ER_MID, ER_LIT, t * 2.0 - 1.0);
	if (!rock_pass1 && facet_k > 0.0) {
		// Each plane its own tone and a hue leaning warm or cool.
		vec3 hp = er_hash3(ivec3(int(plane_id.x), int(plane_id.y), 19));
		col *= (1.0 + (hp.x - 0.5) * 0.26 * facet_k * (1.0 - plane_calm))
			* mix(vec3(0.94, 0.97, 1.08), vec3(1.08, 1.02, 0.90), hp.y);
	}
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
		col *= 1.0 + (h.x - 0.5) * 2.0 * amps[k] * kp * (rock_flat ? 1.0 : rock_beds);
		if (k < 2) col *= mix(vec3(1.0), mix(vec3(0.90, 0.97, 1.08), vec3(1.10, 1.02, 0.86), h.z), kp * 1.0);
		// Thin dark seam at a bed's foot, a pale lip at the top of the one below.
		float w = max(0.045, fq / s * 0.9);
		float seam = (1.0 - smoothstep(0.0, w * 1.5, f)) * (0.5 + 0.5 * h.y);
		float edge = smoothstep(1.0 - w * 4.0, 1.0 - w * 1.2, f) * (1.0 - smoothstep(1.0 - w * 1.2, 1.0, f));
		float seams = rock_flat ? 1.0 : rock_seams;
		crack = max(crack, seam * kp * (k == 0 ? 0.75 : (k == 1 ? 1.0 : 0.35)) * seams);
		lip = max(lip, edge * kp * (0.5 + 0.5 * h.z) * seams);
	}
	// Vertical joints between blocks, each bed's own spacing and offset, some
	// missing; and long fissures running down the face.
	// The way along the face snapped to one of 16 (the joints' coordinate is
	// world-sized, so a face's interpolated normal turning by a hair would
	// slide them metres and smear them into streaks down long triangles).
	float az_j = round(atan(n.x, -n.z) / 0.39269908) * 0.39269908;
	vec2 along = vec2(cos(az_j), sin(az_j));
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
	crack = max(crack, joint * (rock_flat ? 0.8 : 0.4));
	col *= 1.0 - fissure * 0.28;
	// Cracks down the seams between facets.
	float seam_f = (1.0 - smoothstep(0.0, 0.035 + fq / 7.5 * 0.5, cell_f.y)) * keep_f * 0.0;
	float seam_b = (1.0 - smoothstep(0.0, 0.035 + fq / 38.0 * 0.5, cell_b.y)) * er_keep(38.0, fq) * 0.25;
	float seam_c = (1.0 - smoothstep(0.0, 0.012 + fq / 70.0 * 0.6, cell_c.y)) * er_keep(70.0, fq) * 0.3 * facet_k;
	crack = max(crack, max(max(seam_f, seam_b), seam_c) * (rock_flat ? 1.0 : min(1.0, rock_seams * 2.0)));
	// Dry-brush strokes along the beds: light flecks on the lit side.
	float stroke = er_vnoise(vec3(q.x / 7.0, q.y / 0.8, q.z / 7.0) + vec3(4.0, 1.0, 8.0));
	float sk = er_keep(0.8, fq);
	col *= 1.0 + (smoothstep(0.55, 0.62, stroke) - 0.5) * 0.4 * sk * (0.4 + t) * (1.0 - 0.6 * (rock_flat ? 0.0 : rock_calm));
	// Weathering streaks running down the face.
	float gully = er_vnoise(vec3(q.x / 2.6, q.y / 36.0, q.z / 2.6) + vec3(2.0, 0.0, 5.0));
	float gk = er_keep(2.6, fq);
	col *= 1.0 - smoothstep(0.55, 0.8, gully) * 0.5 * gk * (1.0 - nf.y);
	// A pale lip along the facet's top and along the lit side of a seam.
	float shade = rock_pass1 ? 0.0 : 1.0 - smoothstep(0.05, 0.6, dot(nf, sun));
	// In shade the lips keep a cool glint and the cracks stay violet, not black.
	vec3 glint = mix(ER_GLINT, vec3(0.40, 0.40, 0.54), shade);
	vec3 crack_col = mix(ER_CRACK, vec3(0.085, 0.075, 0.135), shade);
	float calm_k = rock_flat ? 0.0 : rock_calm;
	crack *= 1.0 - 0.45 * calm_k;
	lip *= 1.0 - 0.4 * calm_k;
	col = mix(col, glint, lip * (0.35 + 0.6 * t + 0.15 * shade) * 0.9);
	col = mix(col, crack_col, clamp(crack, 0.0, 1.0) * (0.85 - 0.2 * shade));

	// Turf and moss settle where the face lies back, ragged by the facets.
	float lay = nf.y + (er_vnoise(q / 7.0) - 0.5) * 0.2 + (er_vnoise(q / 2.3) - 0.5) * 0.1 * er_keep(2.3, fq);
	float settle = smoothstep(0.50, 0.68, lay) * rock_moss;
	// More on the lip of a bed, none in a crack.
	settle = clamp(settle + lip * 0.25 * smoothstep(0.3, 0.6, lay) * rock_moss, 0.0, 1.0) * (1.0 - crack * 0.9);
	col = mix(col, mossy * mix(vec3(0.85), vec3(1.0, 1.05, 0.7), er_vnoise(q / 13.0)), settle * 0.8);

	// The sun's own light takes the facets' normal.
	bumped = normalize(mix(n, nf, rock_pass1 ? 0.7 : 0.92));
	col = mix(col, ER_MID * 1.2, 1.0 - rock_paint);
	if (!rock_flat && !rock_pass1) {
		// Hollows a little darker, proud ledges a little lighter.
		col *= 1.0 + (cav - 0.5) * 0.5 * clamp(rock_relief, 0.0, 1.5);
		// The carved land's grooves deep and cool, its crests catching light
		// (more where they face the sun).
		float cv = clamp(carved.x, 0.0, 1.0) * rock_carve_shade;
		float cr = clamp(carved.y, 0.0, 1.0) * rock_carve_shade;
		float sunny = smoothstep(-0.1, 0.5, dot(nf, sun));
		col = mix(col, col * vec3(0.50, 0.50, 0.66), clamp(cv * 0.55, 0.0, 0.7));
		col = mix(col, col * vec3(1.30, 1.22, 1.08), clamp(cr * (0.25 + 0.5 * sunny), 0.0, 0.8));
	}
	if (!rock_pass1 && rock_bounce > 0.0) {
		// Bounce light the sun does not give: cool sky from above, warm from
		// the valley floor below, strongest in the shade.
		float up = nf.y * 0.5 + 0.5;
		float low = smoothstep(170.0, 10.0, p.y + 40.0);
		vec3 bounce = ER_SKY_BOUNCE * (0.35 + 0.65 * up)
			+ ER_GROUND_BOUNCE * (1.0 - up) * (0.3 + 0.7 * low) * 0.8;
		glow = col * bounce * (0.12 + 0.88 * shade) * 0.22 * rock_bounce
			* (1.0 - 0.5 * clamp(carved.x * rock_carve_shade, 0.0, 1.0));
	}
	return col;
}
