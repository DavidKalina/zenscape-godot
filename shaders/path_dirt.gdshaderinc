#ifndef ZS_PATH_DIRT
#define ZS_PATH_DIRT
// Worn paths drawn per pixel on the ground (reference_surface, ground only):
// the isle hands its paths' segments in (`path_segs`, world x z of each end;
// scripts/shared/path_dirt.gd), and each pixel finds how worn it is from
// its distance to them, so the edge is the path's own, ragged, with grass
// pushing in, not the turf mesh's facets blurred. Inside, packed earth in the
// isle's dirt colour: soil in clumps and tones, damp patches darker, the
// trodden crown paler and dustier, scuffs along the way it is walked, fine
// crumbs and dust up close, a richer, darker soil at the grass's edge, and a
// little relief for the light. 0 segments (the default): no
// path, the ground as before. Include after reference_wind (zs_noise).
uniform int path_count = 0;
uniform vec4 path_segs[48];
// The dirt (linear, as the turf's vertex colours are).
uniform vec3 path_dirt : source_color = vec3(0.16, 0.12, 0.08);
// The wear's reach (m) and how much of it is full: wear = full - d / reach,
// as the isle's own path_wear (1.25 - d / 1.5).
uniform vec2 path_wear_curve = vec2(1.25, 1.5);

// The nearest segment's distance, and in `way` its direction.
float zs_path_distance(vec2 p, out vec2 way) {
	float d = 1.0e9;
	way = vec2(1.0, 0.0);
	for (int i = 0; i < 48; i++) {
		if (i >= path_count) break;
		vec2 a = path_segs[i].xy;
		vec2 b = path_segs[i].zw;
		vec2 ab = b - a;
		float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
		float di = length(p - a - ab * t);
		if (di < d) {
			d = di;
			way = ab / max(length(ab), 1e-6);
		}
	}
	return d;
}

// How worn `p` is (0..1); in `crown` how near the middle (0..1), in `way`
// the way the path runs there.
float zs_path_wear(vec2 p, out float crown, out vec2 way) {
	float d = zs_path_distance(p, way);
	// The edge wanders: a broad sway and a finer tear.
	float rag = (zs_noise(p * 0.45) - 0.5) * 0.9 + (zs_noise(p * 2.3 + 11.0) - 0.5) * 0.4;
	float raw = clamp(path_wear_curve.x - (d + rag) / path_wear_curve.y, 0.0, 1.0);
	crown = smoothstep(0.75, 1.0, raw);
	float wear = smoothstep(0.18, 0.5, raw);
	// Grass holding on in tufts off the trodden middle.
	float island = smoothstep(0.66, 0.74, zs_noise(p * 1.4 + 37.0)) * (1.0 - smoothstep(0.55, 0.9, raw));
	return wear * (1.0 - island * 0.9);
}

// The ground's colour `ground` (linear) worn to dirt by `wear` at `p`.
vec3 zs_path_colour(vec3 ground, vec2 p, float wear, float crown, vec2 way, float px) {
	// Detail fades out as a pixel grows wider than it (no shimmer far off).
	float fine = 1.0 - smoothstep(0.012, 0.05, px);
	float mid = 1.0 - smoothstep(0.05, 0.25, px);
	vec2 q = vec2(dot(p, way), dot(p, vec2(-way.y, way.x)));
	vec3 dirt = path_dirt;
	// Soil in clumps, three sizes over each other.
	float clump = zs_noise(p * 0.6) * 0.5 + zs_noise(p * 1.7 + 3.0) * 0.3 + zs_noise(p * 4.3 + 9.0) * 0.2 * mid;
	dirt *= mix(0.8, 1.16, clump);
	// Here a warmer, redder earth, there a greyer one.
	float warm = zs_noise(p * 0.22 + 17.0);
	dirt *= mix(vec3(0.96, 0.98, 1.04), vec3(1.07, 0.98, 0.86), warm);
	// Damp hollows darker and a little cooler.
	float damp = smoothstep(0.58, 0.82, zs_noise(p * 0.32 + 5.0));
	dirt *= mix(vec3(1.0), vec3(0.78, 0.79, 0.84), damp);
	// The trodden crown: paler, dustier, greyer.
	float luma = dot(dirt, vec3(0.2126, 0.7152, 0.0722));
	dirt = mix(dirt, mix(dirt, vec3(luma), 0.35) * 1.18, crown * (1.0 - damp) * 0.65);
	// Scuffs along the way it is walked: soft streaks, long and narrow.
	float scuff = zs_noise(vec2(q.x * 0.8, q.y * 6.5) + 21.0) * 0.6 + zs_noise(vec2(q.x * 2.0, q.y * 14.0) + 4.0) * 0.4;
	dirt *= mix(1.0, mix(0.88, 1.1, scuff), mid * smoothstep(0.4, 0.9, wear));
	// Up close, crumbs of darker earth and specks of pale dust.
	float crumb = smoothstep(0.7, 0.92, zs_noise(p * 31.0 + 2.0)) * fine;
	float dust = smoothstep(0.78, 0.95, zs_noise(p * 24.0 + 13.0)) * fine * (0.4 + 0.6 * crown);
	dirt *= (1.0 - 0.26 * crumb) * (1.0 + 0.3 * dust);
	dirt *= mix(1.0, 0.9 + 0.2 * zs_noise(p * 12.0 + 6.0), fine);
	// Where the grass gives way, a richer, darker soil among its roots.
	float rim = smoothstep(0.02, 0.3, wear) * (1.0 - smoothstep(0.4, 0.8, wear));
	dirt *= mix(vec3(1.0), vec3(0.74, 0.72, 0.7), rim);
	return mix(ground, dirt, wear);
}

// The light's normal on the path: the earth's low relief and its scuffs.
vec3 zs_path_normal(vec3 n, vec2 p, float wear, vec2 way, float px) {
	float e = 0.05;
	float mid = 1.0 - smoothstep(0.05, 0.25, px);
	vec2 across = vec2(-way.y, way.x);
	float h0 = zs_noise(p * 2.2) + 0.35 * zs_noise(vec2(dot(p, way) * 0.8, dot(p, across) * 6.5) + 21.0) * mid;
	vec2 px1 = p + vec2(e, 0.0);
	vec2 pz1 = p + vec2(0.0, e);
	float hx = zs_noise(px1 * 2.2) + 0.35 * zs_noise(vec2(dot(px1, way) * 0.8, dot(px1, across) * 6.5) + 21.0) * mid;
	float hz = zs_noise(pz1 * 2.2) + 0.35 * zs_noise(vec2(dot(pz1, way) * 0.8, dot(pz1, across) * 6.5) + 21.0) * mid;
	vec2 slope = vec2(hx - h0, hz - h0) / e * 0.045;
	return normalize(mix(n, normalize(n - vec3(slope.x, 0.0, slope.y)), wear));
}
#endif
