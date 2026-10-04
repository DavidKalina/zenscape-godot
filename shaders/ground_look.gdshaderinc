// The grass ground's look (docs/scenic/grass-look.md, "Round three: a calm
// field"). The terrain mesh paints every face one of three palette greens
// plus a random shimmer (NativeTerrainPalette), which reads as a mosaic of
// light and dark triangles. On the ground (reference_surface with
// terrain_growth and palette_role 1) these functions pull each grass face
// most of the way to one broad field: soft sunlit and deep patches over
// tens of metres, the tufts' dry patches, lusher green beside water. A
// little of the face's own colour stays, so the facets still show, faintly.
//
// zs_ground_color is the one place the ground's colour is made; later tints
// (meadow drifts under flowers) belong in zs_ground_meadow_tint below.
//
// Include after scene_palette, reference_wind and grass_look (zs_noise,
// zs_grass_dry, zs_grass_living), and after `zs_water_map` is declared.
#ifndef ZS_GROUND_LOOK
#define ZS_GROUND_LOOK

// NativeTerrainPalette.grass in linear: the middle, sunlit and deep greens
// the mesh paints (tests/test_ground_look.gd keeps these in step).
const vec3 ZS_GROUND_GREEN = vec3(0.1296, 0.3563, 0.1597);
const vec3 ZS_GROUND_SUNLIT = vec3(0.2012, 0.4365, 0.1964);
const vec3 ZS_GROUND_DEEP = vec3(0.1004, 0.2565, 0.1318);
// A dry patch: a little lighter and warmer, still green (a straw colour
// would go tan under Chalk & turquoise's (2.6, 1.0, 1.9) grass ratio).
const vec3 ZS_GROUND_DRY = vec3(0.1850, 0.3900, 0.1350);
// Beside water: deeper and fuller.
const vec3 ZS_GROUND_LUSH = vec3(0.0880, 0.3150, 0.1250);

// The ground's tunables (uniforms on the terrain's reference_surface).
// calm: how far a grass face goes to the field (1 hides every facet's own
// colour). soft: how much of the light follows the smoothed ground instead
// of the face (grass only; rock and snow stay faceted). dry, lush: the
// patches' strength. living: how far the family's grass leans to living
// green, as the tufts do (grass_look zs_grass_living).
// patch: how far the broad field leans to the sunlit and deep greens (0.65
// in round three; "somewhere in between" lifts it so the field has visible
// light and shade over tens of metres). warm: how much warmer and lighter
// grass on slopes turned to the sun reads (zs_ground_sun_warm).
uniform float ground_calm : hint_range(0.0, 1.0) = 0.6;
uniform float ground_soft : hint_range(0.0, 1.0) = 0.6;
uniform float ground_patch : hint_range(0.0, 1.5) = 1.3;
uniform float ground_warm : hint_range(0.0, 1.0) = 0.5;
uniform float ground_dry : hint_range(0.0, 1.0) = 0.45;
uniform float ground_lush : hint_range(0.0, 1.0) = 0.6;
uniform float ground_living : hint_range(0.0, 1.0) = 0.3;

// Round five, the land's own colour (docs/scenic/grass-look.md):
// hue: how far the broad patches drift warm or cool as well as light or
// deep. hollow, crest: lusher, cooler green where the land dips and drier,
// paler green on crests, convex edges and high ground. steep: grass on steep
// slopes thinning toward a dry olive. shade: the darker, cooler, mossy floor
// under trees (scripts/ground_shade.gd).
uniform float ground_hue : hint_range(0.0, 1.0) = 0.85;
uniform float ground_hollow : hint_range(0.0, 1.0) = 0.7;
uniform float ground_crest : hint_range(0.0, 1.0) = 0.7;
uniform float ground_steep : hint_range(0.0, 1.0) = 0.6;
uniform float ground_shade : hint_range(0.0, 1.0) = 0.9;
// Source-space multipliers for the broad patches' hue drift.
const vec3 ZS_GROUND_WARM_DRIFT = vec3(1.38, 1.06, 0.60);
const vec3 ZS_GROUND_COOL_DRIFT = vec3(0.76, 0.96, 1.20);
// Linear multipliers, after the palette: a hollow's lusher green, a crest's
// drier one, and the floor under trees (darker, cooler, a little mossy).
const vec3 ZS_GROUND_HOLLOW = vec3(0.76, 0.88, 0.92);
const vec3 ZS_GROUND_CREST = vec3(1.22, 1.12, 0.72);
const vec3 ZS_GROUND_SHADE = vec3(0.50, 0.62, 0.55);
// How much of the snow the trees' shade keeps off the floor.
const float ZS_GROUND_SNOW_SHELTER = 0.45;

// 0..1: how much a face colour (source space, before the palette) is the
// palette's grass. The three greens and their shimmer sit within about 0.06
// of each other in chromaticity; bare earth, rock, sand, snow and most
// painted colours are 0.2 or more away, and a face half earth half grass
// about 0.2, so cover edges and paint keep their own colour.
float zs_ground_grassness(vec3 g_face) {
	vec3 g_chroma = g_face / max(g_face.r + g_face.g + g_face.b, 0.001);
	vec3 g_green = ZS_GROUND_GREEN / (ZS_GROUND_GREEN.r + ZS_GROUND_GREEN.g + ZS_GROUND_GREEN.b);
	return 1.0 - smoothstep(0.08, 0.16, distance(g_chroma, g_green));
}

// The calm field's grass colour at world point `g_p` (source space), with
// `g_lush` 0..1 near water. Two broad noises (about 16 m and 6 m) lean the
// green toward the palette's sunlit or deep shade; the dry patches are the
// tufts' own (zs_grass_dry), so ground and tufts dry out together.
vec3 zs_ground_field(vec2 g_p, float g_lush) {
	float g_broad = zs_noise(g_p * 0.06 + zs_grass_offset * 0.41 + 17.0) - 0.5;
	float g_mid = zs_noise(g_p * 0.16 + zs_grass_offset * 0.57 + 41.0) - 0.5;
	float g_sun = clamp(g_broad * 2.8 + g_mid * 0.9, -1.0, 1.0);
	vec3 g_color = mix(ZS_GROUND_GREEN, g_sun > 0.0 ? ZS_GROUND_SUNLIT : ZS_GROUND_DEEP, abs(g_sun) * ground_patch);
	// The meadow drifts in hue over about 9 m, mostly with the broad light:
	// sun-warmed patches yellower, deep ones cooler and bluer (ground_hue).
	// Hue more than light, so the drift reads as meadow, not as noise.
	float g_drift = zs_noise(g_p * 0.11 + zs_grass_offset * 0.73 + 73.0) - 0.5;
	float g_warm = clamp(g_drift * 2.2 + g_broad * 1.4, -1.0, 1.0);
	g_color *= mix(vec3(1.0), g_warm > 0.0 ? ZS_GROUND_WARM_DRIFT : ZS_GROUND_COOL_DRIFT, abs(g_warm) * ground_hue);
	float g_dry = zs_grass_dry(g_p, ZS_GRASS_DRY_SCALE, zs_grass_offset) * ground_dry * (1.0 - g_lush);
	g_color = mix(g_color, ZS_GROUND_DRY, g_dry);
	return mix(g_color, ZS_GROUND_LUSH, g_lush * ground_lush);
}

// The hook for later ground tints: the meadow's drifts lean the ground
// under them toward their flowers' colour here. `g_ground` is the final
// palette-tinted ground colour (linear) and `g_p` the world point.
vec3 zs_ground_meadow_tint(vec3 g_ground, vec3 g_p) {
	return g_ground;
}

// Grass on a slope turned to the sun reads a little warmer and lighter,
// and on one turned away a little deeper, over the smoothed ground normal
// `g_n` (world space), so rises and hollows show as broad soft light and
// shade: `g_grass` the face's zs_ground_grassness, `g_sun` the direction
// to the sun. Flat ground is left as it is.
vec3 zs_ground_sun_warm(vec3 g_tint, vec3 g_n, vec3 g_sun, float g_grass) {
	vec2 g_toward = g_sun.xz / max(length(g_sun.xz), 0.001);
	float g_facing = clamp(dot(g_n.xz, g_toward) * 3.0, -1.0, 1.0) * smoothstep(-0.05, 0.15, g_sun.y);
	vec3 g_shift = g_facing > 0.0 ? vec3(1.10, 1.05, 0.88) : vec3(0.90, 0.95, 1.0);
	return g_tint * mix(vec3(1.0), g_shift, abs(g_facing) * ground_warm * g_grass);
}

// The ground's colour: face colour `g_face` (base colour times vertex
// colour, source space) at world point `g_p`, `g_lush` 0..1 near water and
// `g_grass` its zs_ground_grassness. Returns the palette-tinted colour the
// rest of the surface shader works on.
vec3 zs_ground_color(vec3 g_face, vec3 g_p, float g_lush, float g_grass) {
	vec3 g_field = zs_ground_field(g_p.xz, g_lush);
	vec3 g_source = mix(g_face, g_field, g_grass * ground_calm);
	vec3 g_tint = scene_palette_ground(g_source);
	// Muted families keep their lightness but stay a living sage, not grey.
	g_tint = mix(g_tint, zs_grass_living(g_tint, ground_living, 1.0), g_grass);
	return zs_ground_meadow_tint(g_tint, g_p);
}

// The ground height (`zs_water_map` green) at plate point `g_p`, bilinear
// over the map's 0.25 m texels; `g_ok` false off the plate or over void.
float zs_ground_height(vec2 g_p, out bool g_ok) {
	vec2 g_t = (g_p + 16.0) * 4.0 - 0.5;
	ivec2 g_i = ivec2(floor(g_t));
	vec2 g_f = g_t - floor(g_t);
	g_ok = all(greaterThanEqual(g_i, ivec2(0))) && all(lessThan(g_i, ivec2(127)));
	if (!g_ok) return 0.0;
	float g_00 = texelFetch(zs_water_map, g_i, 0).g;
	float g_10 = texelFetch(zs_water_map, g_i + ivec2(1, 0), 0).g;
	float g_01 = texelFetch(zs_water_map, g_i + ivec2(0, 1), 0).g;
	float g_11 = texelFetch(zs_water_map, g_i + ivec2(1, 1), 0).g;
	g_ok = min(min(g_00, g_10), min(g_01, g_11)) > -100.0;
	return mix(mix(g_00, g_10, g_f.x), mix(g_01, g_11, g_f.x), g_f.y);
}

// The ground's smoothed normal at plate vertex `g_v` (central differences
// over 0.6 m of the height map, which the faceted surface fills), faded
// back to `g_face` where the map does not match the vertex: off the plate,
// mid-growth, mid-sculpt before the map catches up, or on a neighbouring
// chunk that does not own the map.
vec3 zs_ground_smooth_normal(vec3 g_v, vec3 g_face) {
	bool g_ok;
	bool g_ok_x0;
	bool g_ok_x1;
	bool g_ok_z0;
	bool g_ok_z1;
	float g_h = zs_ground_height(g_v.xz, g_ok);
	float g_x0 = zs_ground_height(g_v.xz - vec2(0.6, 0.0), g_ok_x0);
	float g_x1 = zs_ground_height(g_v.xz + vec2(0.6, 0.0), g_ok_x1);
	float g_z0 = zs_ground_height(g_v.xz - vec2(0.0, 0.6), g_ok_z0);
	float g_z1 = zs_ground_height(g_v.xz + vec2(0.0, 0.6), g_ok_z1);
	if (!(g_ok && g_ok_x0 && g_ok_x1 && g_ok_z0 && g_ok_z1)) return g_face;
	vec3 g_smooth = normalize(vec3(-(g_x1 - g_x0) / 1.2, 1.0, -(g_z1 - g_z0) / 1.2));
	float g_match = 1.0 - smoothstep(0.12, 0.35, abs(g_h - g_v.y));
	return normalize(mix(g_face, g_smooth, g_match));
}

// 0..1: how near open water plate vertex `g_v` stands (the map's alpha is
// the water surface): full within about 0.9 m, half by 1.8 m, none on
// ground more than a metre above that water.
float zs_ground_lush_at(vec3 g_v) {
	// Only the chunk that owns the map: a neighbour's vertex shares its
	// local coordinates but not its ground.
	bool g_ok;
	float g_h = zs_ground_height(g_v.xz, g_ok);
	if (!g_ok || abs(g_h - g_v.y) > 0.35) return 0.0;
	float g_lush = 0.0;
	for (int g_k = 0; g_k < 8; g_k++) {
		float g_angle = float(g_k) * 0.785398;
		for (int g_r = 0; g_r < 2; g_r++) {
			float g_reach = g_r == 0 ? 0.9 : 1.8;
			vec2 g_p = g_v.xz + vec2(cos(g_angle), sin(g_angle)) * g_reach;
			ivec2 g_texel = ivec2(floor((g_p + 16.0) * 4.0));
			if (any(lessThan(g_texel, ivec2(0))) || any(greaterThanEqual(g_texel, ivec2(128)))) continue;
			float g_water = texelFetch(zs_water_map, g_texel, 0).a;
			if (g_water < -100.0) continue;
			float g_above = g_v.y - g_water;
			g_lush = max(g_lush, (g_r == 0 ? 1.0 : 0.5) * (1.0 - smoothstep(0.4, 1.0, g_above)) * step(-0.3, g_above));
		}
	}
	return g_lush;
}

// The trees' shade at plate point `g_p` (zs_ground_shade, bilinear over its
// 0.5 m texels), 0..1. An unset texture (green 1) reads as none.
float zs_ground_shade_at(vec2 g_p) {
	vec2 g_t = (g_p + 16.0) * 2.0 - 0.5;
	ivec2 g_i = ivec2(floor(g_t));
	vec2 g_f = g_t - floor(g_t);
	ivec2 g_hi = ivec2(63);
	vec2 g_00 = texelFetch(zs_ground_shade, clamp(g_i, ivec2(0), g_hi), 0).rg;
	float g_10 = texelFetch(zs_ground_shade, clamp(g_i + ivec2(1, 0), ivec2(0), g_hi), 0).r;
	float g_01 = texelFetch(zs_ground_shade, clamp(g_i + ivec2(0, 1), ivec2(0), g_hi), 0).r;
	float g_11 = texelFetch(zs_ground_shade, clamp(g_i + ivec2(1, 1), ivec2(0), g_hi), 0).r;
	if (g_00.g > 0.5 || any(lessThan(g_p, vec2(-16.0))) || any(greaterThan(g_p, vec2(16.0)))) return 0.0;
	return mix(mix(g_00.r, g_10, g_f.x), mix(g_01, g_11, g_f.x), g_f.y);
}

// (bowl, shade) at plate vertex `g_v`. bowl: metres the ground round about
// stands above it (a hollow, +) or below it (a crest or a convex edge, -),
// over two rings at 1.5 and 3.5 m; shade: zs_ground_shade_at. Both 0 where
// the map does not match the vertex (a neighbouring chunk, off the plate).
vec2 zs_ground_form_at(vec3 g_v) {
	bool g_ok;
	float g_h = zs_ground_height(g_v.xz, g_ok);
	if (!g_ok || abs(g_h - g_v.y) > 0.6) return vec2(0.0);
	float g_rise = 0.0;
	float g_count = 0.0;
	for (int g_k = 0; g_k < 8; g_k++) {
		float g_angle = float(g_k) * 0.785398 + 0.39;
		for (int g_r = 0; g_r < 2; g_r++) {
			vec2 g_p = g_v.xz + vec2(cos(g_angle), sin(g_angle)) * (g_r == 0 ? 1.5 : 3.5);
			ivec2 g_texel = ivec2(floor((g_p + 16.0) * 4.0));
			if (any(lessThan(g_texel, ivec2(0))) || any(greaterThanEqual(g_texel, ivec2(128)))) continue;
			float g_ground = texelFetch(zs_water_map, g_texel, 0).g;
			if (g_ground < -100.0) continue;
			// The near ring reads curvature at a stride's scale, the far one
			// the land's; the far one counts a little less.
			float g_weight = g_r == 0 ? 1.0 : 0.6;
			g_rise += (g_ground - g_h) * g_weight;
			g_count += g_weight;
		}
	}
	return vec2(g_count > 0.0 ? g_rise / g_count : 0.0, zs_ground_shade_at(g_v.xz));
}

// The floor under trees: `g_tint` darkened toward the wood's cool, mossy
// shade by `g_shade` (0..1); `g_grass` 1 for grass, less for bare earth,
// rock and paint, which only darken a little.
vec3 zs_ground_shaded(vec3 g_tint, float g_shade, float g_grass) {
	float g_amount = clamp(g_shade * ground_shade, 0.0, 1.0);
	vec3 g_floor = mix(vec3(0.74, 0.74, 0.78), ZS_GROUND_SHADE, g_grass);
	return g_tint * mix(vec3(1.0), g_floor, g_amount * mix(0.6, 1.0, g_grass));
}

// The land's own colour on the ground's tint (after the palette): `g_p` the
// world point, `g_form` (lush, bowl, shade) from the vertex stage
// (zs_ground_lush_at, zs_ground_form_at), `g_n` the smoothed ground normal,
// `g_grass` the face's zs_ground_grassness. Hollows go lusher and cooler,
// crests, convex edges and high ground drier and paler, steep grass thins
// toward a dry olive, and the floor under trees darkens. Painted ground,
// rock and earth keep their own colour except for the trees' shade.
vec3 zs_ground_form(vec3 g_tint, vec3 g_p, vec3 g_form, vec3 g_n, float g_grass) {
	float g_hollow = smoothstep(0.05, 0.6, g_form.y);
	float g_crest = smoothstep(0.05, 0.6, -g_form.y);
	float g_high = smoothstep(0.35, 0.9, (g_p.y - 0.15) / max(zs_summit.y - 0.15, 1.0));
	float g_wet = max(g_hollow, g_form.x * 0.5);
	float g_dry = max(g_crest, g_high * 0.6) * (1.0 - g_wet);
	g_tint *= mix(vec3(1.0), ZS_GROUND_HOLLOW, g_hollow * ground_hollow * g_grass);
	g_tint *= mix(vec3(1.0), ZS_GROUND_CREST, g_dry * ground_crest * g_grass);
	// Steep grass thins toward a dry olive of the same lightness.
	float g_steep = 1.0 - smoothstep(0.62, 0.92, g_n.y);
	float g_luma = dot(g_tint, vec3(0.2126, 0.7152, 0.0722));
	vec3 g_thin = vec3(g_luma) * vec3(1.18, 1.0, 0.70);
	g_tint = mix(g_tint, g_thin, g_steep * ground_steep * 0.6 * g_grass);
	return zs_ground_shaded(g_tint, g_form.z, g_grass);
}
#endif
