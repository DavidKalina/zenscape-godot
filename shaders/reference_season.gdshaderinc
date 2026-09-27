// Seasons on plants. studies/fidelity.gd publishes zs_season from
// WeatherScheduler.season_plants only when it changes:
//   x spring bloom, y deciduous leaf fall, z winter dormancy, w how far
//   into autumn (0 outside it).
// Each part says how it follows them with its own `leaf_season` uniform
// (scripts/scene_look.gd leaf_season). Include after reference_wind, which
// supplies zs_noise.
#ifndef ZS_REFERENCE_SEASON
#define ZS_REFERENCE_SEASON
global uniform vec4 zs_season;

float zs_season_noise3(vec3 p) {
	float layer = floor(p.y);
	float a = zs_noise(p.xz + vec2(layer * 31.7));
	float b = zs_noise(p.xz + vec2((layer + 1.0) * 31.7));
	float t = fract(p.y);
	return mix(a, b, t * t * (3.0 - 2.0 * t));
}

float zs_season_tree_hash(vec2 root) {
	return fract(sin(dot(root, vec2(41.3, 289.1))) * 17371.713);
}

// True where a deciduous crown has already let its leaves go. `local` is the
// crown's own vertex position, so the gaps ride with the tree as it sways;
// `drop` is how much of this plant's crown can fall (shrubs keep some).
bool zs_leaf_fallen(vec3 local, vec2 root, float drop) {
	float bare = zs_season.y * drop;
	if (bare <= 0.001) return false;
	float n = zs_season_noise3(local * 2.4 + vec3(root.x, 0.0, root.y) * 0.37);
	// Each tree goes bare a little before or after its neighbours.
	float early = (zs_season_tree_hash(root) - 0.5) * 0.16;
	return n < bare * 1.25 - 0.12 + early;
}

// Spring on leaves: fresh yellow-green, and blossom on a share of the trees
// that opens as the bloom rises. `turn` is 0 on evergreens.
void zs_season_leaves(inout vec3 color, vec3 local, vec2 root, vec3 normal, float turn, float blossom) {
	if (turn <= 0.0 || zs_season.x <= 0.004) return;
	float green = clamp((color.g - max(color.r, color.b)) * 6.0, 0.0, 1.0);
	color = mix(color, color * vec3(1.10, 1.22, 0.80), zs_season.x * green * 0.55 * turn);
	float tree = zs_season_tree_hash(root + vec2(7.1, 3.3));
	if (tree < blossom) {
		float fleck = zs_season_noise3(local * 7.5 + vec3(tree * 13.0));
		float open = smoothstep(0.66, 0.70, fleck + 0.2 * zs_season.x - 0.2) * smoothstep(-0.3, 0.4, normal.y);
		vec3 petal = mix(vec3(0.66, 0.40, 0.48), vec3(0.68, 0.64, 0.56), step(0.5, fract(tree * 17.0)));
		color = mix(color, petal, open * zs_season.x * turn);
	}
}

// Autumn on a tree whose stand has its own character (`stand` 0..1,
// scripts/tree_stands.gd autumn); the source's zs_autumn_paint, which
// keys on world noise, stays for every other plant. Low stands hang on green
// and stop at gold, the middle stops at amber, high stands turn first and go
// on to copper-red. How far into autumn is the clock's (zs_season.w,
// WeatherScheduler.season_plants) or, without one, the gold itself, which
// alone reaches mid-autumn. One offset per tree, never per fragment, so a
// stand turns as one faceted grove. Same green and warm keys as the source.
void zs_autumn_stand_paint(inout vec3 color, vec2 root, float amount, float stand) {
	if (amount <= 0.004) return;
	float green = clamp((color.g - max(color.r, color.b)) * 6.0, 0.0, 1.0);
	float warm = smoothstep(0.20, 0.50, color.r / max(color.g, 1e-4));
	float along = max(0.65 * amount, zs_season.w) + (zs_season_tree_hash(root + vec2(3.7, 11.9)) - 0.5) * 0.08;
	float onset = mix(0.62, 0.0, stand);
	float turn = smoothstep(onset, onset + 0.3, along) * smoothstep(0.004, 0.3, amount) * green * warm;
	if (turn <= 0.003) return;
	float reach = mix(0.1, 0.45, smoothstep(0.0, 0.6, stand)) + 0.55 * smoothstep(0.55, 0.85, stand);
	float depth = reach * smoothstep(onset + 0.1, onset + 0.9, along);
	vec3 hue = mix(vec3(1.00, 0.66, 0.14), vec3(1.00, 0.52, 0.10), smoothstep(0.0, 0.35, depth));
	hue = mix(hue, vec3(0.50, 0.16, 0.05), smoothstep(0.35, 1.0, depth));
	float lum = dot(color, vec3(0.30, 0.55, 0.15));
	color = mix(color, hue * (lum * 2.9), smoothstep(0.0, 0.55, turn));
}

// Grass and green ground through the year: fresher in spring, straw in winter.
// Keyed on how green the colour is, like the autumn paint, so rock, earth and
// gold that autumn already turned are left alone.
void zs_season_grass(inout vec3 color, float amount) {
	if (amount <= 0.0 || (zs_season.x <= 0.004 && zs_season.z <= 0.004)) return;
	float green = clamp((color.g - max(color.r, color.b)) * 6.0, 0.0, 1.0) * amount;
	color = mix(color, color * vec3(1.06, 1.12, 0.90), zs_season.x * green * 0.5);
	float lum = dot(color, vec3(0.30, 0.55, 0.15));
	color = mix(color, vec3(1.16, 0.98, 0.66) * lum, zs_season.z * green * 0.6);
}

// Flowers and ferns shrink away through winter and stand a little taller in
// spring. Multiply the plant's own vertex by this.
float zs_season_dieback(float amount) {
	return (1.0 - amount * zs_season.z) * (1.0 + 0.10 * amount * zs_season.x);
}
#endif
