// The endless ground's patch noise (shaders/endless_ground.gdshader), which
// the grass carpet's tufts read too (scripts/endless/endless_patch.gd, its
// twin in GDScript, tints each tuft by it on the worker that grows it), so
// the tufts carry the painted ground's patches and the carpet sits in the
// field it fades into. Value noise over an integer hash, so the CPU and the
// GPU get the same lattice.

uint ep_hash(ivec2 q) {
	uint h = uint(q.x) * 1597334677u ^ uint(q.y) * 3812015801u;
	h ^= h >> 16u;
	h *= 2246822519u;
	h ^= h >> 13u;
	h *= 3266489917u;
	h ^= h >> 16u;
	return h;
}

float ep_lattice(ivec2 q) {
	return float(ep_hash(q) >> 8u) / 16777215.0;
}

float ep_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	f = f * f * (3.0 - 2.0 * f);
	ivec2 q = ivec2(i);
	return mix(mix(ep_lattice(q), ep_lattice(q + ivec2(1, 0)), f.x),
		mix(ep_lattice(q + ivec2(0, 1)), ep_lattice(q + ivec2(1, 1)), f.x), f.y);
}

// Noise at `scale` m round its mean (-0.5..0.5), faded to the mean where a
// pixel's footprint `fp` (m) grows past a share of the scale.
float ep_fade(vec2 p, float scale, float fp) {
	float keep = 1.0 - smoothstep(scale * 0.18, scale * 0.6, fp);
	if (keep <= 0.0) return 0.0;
	return (ep_noise(p / scale) - 0.5) * keep;
}

// The same as a patch with a defined edge (-0.5 or 0.5 either side), the
// edge widening to a blur as the pixel grows, faded to its mean far off.
float ep_patch(vec2 p, float scale, float fp) {
	float keep = 1.0 - smoothstep(scale * 0.18, scale * 0.6, fp);
	if (keep <= 0.0) return 0.0;
	float w = 0.07 + fp / scale * 1.2;
	return (smoothstep(0.5 - w, 0.5 + w, ep_noise(p / scale)) - 0.5) * keep;
}

// --- Grass colour regions and flower drifts (look round 5) -----------------
// Both on the same hash, mirrored in scripts/endless/endless_patch.gd
// (`region`, `bloom`), so the tufts' tint (near and far ring), the flowers
// grown on the workers and the painted ground agree at every distance.
// `off` is the land seed's offset (m; endless_patch.gd `seed_offset`).

// The regions' hues over the grass (linear multipliers): lush deep green,
// fresh lime, sage blue-green, golden straw, a heather tinge on high ground.
const vec3 EP_LUSH = vec3(0.44, 0.78, 0.58);
const vec3 EP_LIME = vec3(1.33, 1.20, 0.30);
const vec3 EP_SAGE = vec3(0.92, 0.90, 1.65);
const vec3 EP_STRAW = vec3(2.05, 1.22, 0.48);
const vec3 EP_HEATHER = vec3(1.39, 0.74, 1.46);

// The grass areas (look round 6): kilometres across, each a whole meadow of
// one grass, the borders a few hundred metres wide and wandering (warped by
// the regions' own noise). A noise at 2600 m keeps today's bright lime past
// its cut (none: about 45% of the land); under it a noise at 2100 m in three
// bands: a vivid emerald lush (low), a cool sage green (middle), amber straw
// (high; the Amberlands' carpet hue). Each is a colour at the grass's own
// light (its luma the area's brightness), mixed in by its weight, so the grass keeps
// its patches' light and shade. Mirrored in endless_patch.gd `area` and
// grass_cell.h.
const vec3 EP_AREA_LUSH = vec3(0.24, 1.36, 0.39);
const vec3 EP_AREA_SAGE = vec3(0.50, 1.18, 0.62);
const vec3 EP_AREA_AMBER = vec3(1.21, 1.04, 0.50);
const vec3 EP_AREA_MIX = vec3(0.60, 0.45, 0.55);   // lush, sage, amber
// Under the areas the smaller regions as a lighter variation inside them.
const float EP_REGION_UNDER = 0.8;

// The areas at q (p + off), a and b the regions' noises (the border's warp),
// `areas` how strongly (0: none), `edge` x where they fade out (x..y; y <= x:
// nowhere). rgb the area's colours by their weights, a the weights' sum:
// the grass becomes grass * (1 - a) + luma(grass) * rgb.
vec4 ep_area(vec2 q, float px, float a, float b, float areas, vec2 edge) {
	if (edge.y > edge.x) areas *= 1.0 - smoothstep(edge.x, edge.y, px);
	if (areas <= 0.0) return vec4(0.0);
	vec2 w = q + vec2(a - 0.5, b - 0.5) * 900.0;
	float rest = 1.0 - smoothstep(0.47, 0.65, ep_noise(w / 2600.0 + vec2(-7.3, 4.1)));
	float n2 = ep_noise(vec2(w.x * 0.6 + w.y * 0.8, w.y * 0.6 - w.x * 0.8) / 2100.0 + vec2(2.6, -5.9));
	float lush = 1.0 - smoothstep(0.36, 0.44, n2);
	float amber = smoothstep(0.58, 0.66, n2);
	vec3 k = vec3(lush, 1.0 - lush - amber, amber) * rest * EP_AREA_MIX * areas;
	return vec4(EP_AREA_LUSH * k.x + EP_AREA_SAGE * k.y + EP_AREA_AMBER * k.z, k.x + k.y + k.z);
}

// The region's hue at p (a multiplier over the grass; 1: none), `amount`
// how strongly (0: off), `over` m over the sea (the heather's); the areas
// (ep_area, `areas` 0: none) in `area`.
vec3 ep_region(vec2 p, float over, float amount, float areas, vec2 edge, vec2 off, out vec4 area) {
	area = vec4(0.0);
	areas = min(areas, 1.6);
	if (amount <= 0.0 && areas <= 0.0) return vec3(1.0);
	vec2 q = p + off;
	vec2 r = vec2(q.x * 0.8 - q.y * 0.6, q.x * 0.6 + q.y * 0.8);
	float a = ep_noise(r / 380.0 + vec2(3.7, 1.3)) * 0.8 + ep_noise(r / 130.0 + vec2(-4.1, 2.2)) * 0.2;
	float b = ep_noise(q.yx / 300.0 + vec2(-2.1, 8.4)) * 0.8 + ep_noise(q / 110.0 + vec2(6.3, -1.7)) * 0.2;
	area = ep_area(q, p.x, a, b, areas, edge);
	amount *= mix(1.0, EP_REGION_UNDER, min(area.a / 0.55, 1.0));
	if (amount <= 0.0) return vec3(1.0);
	float c = ep_noise(r.yx / 220.0 + vec2(5.5, -3.3));
	vec3 m = mix(vec3(1.0), EP_LUSH, (1.0 - smoothstep(0.30, 0.42, a)) * amount);
	m *= mix(vec3(1.0), EP_LIME, smoothstep(0.58, 0.70, a) * amount);
	m *= mix(vec3(1.0), EP_SAGE, (1.0 - smoothstep(0.30, 0.42, b)) * amount);
	m *= mix(vec3(1.0), EP_STRAW, smoothstep(0.60, 0.72, b) * amount);
	m *= mix(vec3(1.0), EP_HEATHER, smoothstep(0.55, 0.68, c) * smoothstep(16.0, 34.0, over) * amount);
	return m;
}

// The drifts' washes (linear; the ground under a drift, its heads' colour,
// scripts/meadow_types.gd FLOWER_KEYS `wash`), by the kind index `ep_bloom`
// gives (endless_patch.gd KINDS in the same order).
vec3 ep_wash(int k) {
	if (k == 0) return vec3(0.815, 0.509, 0.018);   // buttercup
	if (k == 1) return vec3(0.900, 0.880, 0.780);   // oxeye daisy
	if (k == 2) return vec3(0.687, 0.064, 0.025);   // poppy
	if (k == 3) return vec3(0.255, 0.140, 0.527);   // lupine
	if (k == 4) return vec3(0.730, 0.188, 0.392);   // cosmos pink
	if (k == 5) return vec3(0.480, 0.060, 0.250);   // cosmos magenta
	return vec3(0.800, 0.480, 0.012);               // dandelion
}

// The kind (0..6) a drift's hash picks: 16 slots, yellow the most.
int ep_kind(uint slot) {
	const int KINDS[16] = int[16](0, 0, 0, 1, 1, 6, 6, 2, 2, 3, 3, 3, 4, 5, 0, 4);
	return KINDS[slot & 15u];
}

// One layer of drifts: round blobs on a `cell` m lattice, each cell's one
// there at `chance`, its centre, radius (a share `rad` of the cell) and kind
// from its hash; the strongest blob over q kept in `best` (x the weight,
// y the kind).
void ep_drift_layer(vec2 q, float cell, float chance, vec2 rad, int salt, inout vec2 best) {
	// A blob stands within its cell's middle 0.2..0.8 and reaches at most
	// half a cell, so only the four cells round q's nearest corner can
	// hold it.
	ivec2 c0 = ivec2(floor(q / cell - 0.5));
	for (int j = 0; j <= 1; j++) {
		for (int i = 0; i <= 1; i++) {
			ivec2 c = c0 + ivec2(i, j);
			uint h = ep_hash(c + ivec2(salt, salt * 3));
			if (float(h & 255u) / 255.0 >= chance) continue;
			vec2 centre = (vec2(c) + 0.2 + 0.6 * vec2(float((h >> 8u) & 255u), float((h >> 16u) & 255u)) / 255.0) * cell;
			float radius = cell * mix(rad.x, rad.y, float((h >> 24u) & 15u) / 15.0);
			float w = 1.0 - smoothstep(0.35, 1.0, length(q - centre) / radius);
			if (w > best.x) best = vec2(w, float(ep_kind(h >> 28u)));
		}
	}
}

// The flower drifts at p: x their weight (0 none .. 1 a drift's heart), y
// the drift's kind (ep_wash). `amount` scales how many drifts there are (0:
// none). Drifts (DRIFT m cells) and small patches (PATCH m), their edges
// ragged by a warp.
vec2 ep_bloom(vec2 p, float amount, vec2 off) {
	vec2 best = vec2(0.0);
	if (amount <= 0.0) return best;
	vec2 q = p + off;
	q += (vec2(ep_noise(q / 41.0 + vec2(4.2, -2.6)), ep_noise(q / 41.0 + vec2(-3.3, 7.9))) - 0.5) * 30.0;
	ep_drift_layer(q, 46.0, 0.44 * amount, vec2(0.28, 0.5), 7151, best);
	ep_drift_layer(q, 15.0, 0.16 * amount, vec2(0.2, 0.38), 9241, best);
	// Clumps: a drift thick in places, thin in others.
	best.x *= mix(0.45, 1.0, smoothstep(0.3, 0.68, ep_noise(q / 6.5 + vec2(2.9, -8.1))));
	return best;
}
