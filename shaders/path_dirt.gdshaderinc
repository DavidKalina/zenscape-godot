#ifndef ZS_PATH_DIRT
#define ZS_PATH_DIRT
// Worn paths drawn per pixel on the ground (reference_surface, ground only):
// the isle hands its paths' segments in (`path_segs`, world x z of each end;
// scripts/kit_isle/path_dirt.gd), and each pixel finds how worn it is from
// its distance to them, so the edge is the path's own, ragged, with grass
// pushing in, not the turf mesh's facets blurred. Inside, packed earth in the
// isle's dirt colour: damp patches darker, the trodden crown paler, a grain,
// pebbles, and a little relief for the light. 0 segments (the default): no
// path, the ground as before. Include after reference_wind (zs_noise).
uniform int path_count = 0;
uniform vec4 path_segs[48];
// The dirt (linear, as the turf's vertex colours are).
uniform vec3 path_dirt : source_color = vec3(0.16, 0.12, 0.08);
// The wear's reach (m) and how much of it is full: wear = full - d / reach,
// as the isle's own path_wear (1.25 - d / 1.5).
uniform vec2 path_wear_curve = vec2(1.25, 1.5);
// The pebbles: their share of cells and a cell's size (m).
uniform vec2 path_pebbles = vec2(0.13, 0.22);

float zs_path_distance(vec2 p) {
	float d = 1.0e9;
	for (int i = 0; i < 48; i++) {
		if (i >= path_count) break;
		vec2 a = path_segs[i].xy;
		vec2 b = path_segs[i].zw;
		vec2 ab = b - a;
		float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
		d = min(d, length(p - a - ab * t));
	}
	return d;
}

// How worn `p` is (0..1), and in `crown` how near the middle (0..1).
float zs_path_wear(vec2 p, out float crown) {
	float d = zs_path_distance(p);
	// The edge wanders: a broad sway and a finer tear.
	float rag = (zs_noise(p * 0.45) - 0.5) * 0.9 + (zs_noise(p * 2.3 + 11.0) - 0.5) * 0.4;
	float raw = clamp(path_wear_curve.x - (d + rag) / path_wear_curve.y, 0.0, 1.0);
	crown = smoothstep(0.75, 1.0, raw);
	float wear = smoothstep(0.18, 0.5, raw);
	// Grass holding on in tufts off the trodden middle.
	float island = smoothstep(0.66, 0.74, zs_noise(p * 1.4 + 37.0)) * (1.0 - smoothstep(0.55, 0.9, raw));
	return wear * (1.0 - island * 0.9);
}

// A pebble at `p`: its cover (0..1) and its rise (for the light), faded out
// where a pixel is wider than a pebble.
float zs_path_pebble(vec2 p, float px, out float rise) {
	vec2 cell = floor(p / path_pebbles.y);
	float pick = zs_noise_hash(cell + 3.1);
	rise = 0.0;
	if (pick > path_pebbles.x) return 0.0;
	vec2 at = (cell + 0.25 + 0.5 * vec2(zs_noise_hash(cell + 7.7), zs_noise_hash(cell + 1.9))) * path_pebbles.y;
	float r = path_pebbles.y * mix(0.14, 0.3, zs_noise_hash(cell + 5.3));
	float d = length((p - at) * vec2(1.0, mix(0.7, 1.3, zs_noise_hash(cell + 9.1)))) / r;
	float cover = 1.0 - smoothstep(0.8, 1.0, d);
	rise = sqrt(max(0.0, 1.0 - d * d));
	return cover * (1.0 - smoothstep(0.02, 0.06, px));
}

// The ground's colour `ground` (linear) worn to dirt by `wear` at `p`.
vec3 zs_path_colour(vec3 ground, vec2 p, float wear, float crown, float px) {
	vec3 dirt = path_dirt;
	// Damp hollows darker and a little cooler; the trodden crown paler.
	float damp = smoothstep(0.55, 0.8, zs_noise(p * 0.32 + 5.0));
	dirt *= mix(vec3(1.0), vec3(0.74, 0.76, 0.82), damp);
	dirt = mix(dirt, dirt * 1.22 + vec3(0.012, 0.01, 0.006), crown * (1.0 - damp) * 0.7);
	// Grain: a scuffed, uneven earth.
	dirt *= mix(1.0, 0.86 + 0.28 * zs_noise(p * 7.0), 1.0 - smoothstep(0.03, 0.1, px));
	dirt *= 0.93 + 0.14 * zs_noise(p * 1.7 + 3.0);
	// Pebbles: pale stone, a shade apart each.
	float rise;
	float pebble = zs_path_pebble(p, px, rise) * smoothstep(0.35, 0.7, wear);
	// A shade or two off the dirt, greyer: stones in it, not dots on it.
	float luma = dot(dirt, vec3(0.2126, 0.7152, 0.0722));
	vec3 stone = mix(dirt, vec3(luma), 0.6) * mix(0.8, 1.45, zs_noise_hash(floor(p / path_pebbles.y) + 2.2)) * (0.75 + 0.35 * rise);
	dirt = mix(dirt, stone, pebble);
	return mix(ground, dirt, wear);
}

// The light's normal on the path: the earth's low relief and the pebbles' rise.
vec3 zs_path_normal(vec3 n, vec2 p, float wear, float px) {
	float e = 0.06;
	float h0 = zs_noise(p * 2.2);
	float hx = zs_noise((p + vec2(e, 0.0)) * 2.2);
	float hz = zs_noise((p + vec2(0.0, e)) * 2.2);
	vec2 slope = vec2(hx - h0, hz - h0) / e * 0.05;
	float rise;
	float rx;
	float rz;
	float c = zs_path_pebble(p, px, rise);
	zs_path_pebble(p + vec2(0.02, 0.0), px, rx);
	zs_path_pebble(p + vec2(0.0, 0.02), px, rz);
	slope += vec2(rx - rise, rz - rise) / 0.02 * 0.025 * c;
	return normalize(mix(n, normalize(n - vec3(slope.x, 0.0, slope.y)), wear));
}
#endif
