#[compute]
#version 450
// The endless flight's clouds (scripts/endless/endless_clouds.gd), marched
// as the isles' cloud volume marches its sea and towers (shaders/
// cloud_volume_march.glsl, whose passes, bindings and outputs this keeps,
// so scripts/cloud_volume_effect.gd and shaders/cloud_volume_resolve.glsl
// run it unchanged), but over a field of cumulus that never runs out:
//
//   0 WEATHER: the map round the eye. Two lattices of cells in the wind's
//     drifting frame, each cell hashed from the land's seed: broad cumulus
//     (low ones you can fly into, mid ones standing over the flight's
//     ceiling as a roof, the odd tower), and small puffs low in the band.
//     Each texel keeps two layers, (low top, low base, high top, high
//     base), so a puff can hang under a cumulus. Over the meadows (the
//     ground map, `ground`) the low layer is lifted and thinned so the
//     turf stays landable.
//   1 CEILING: per block, the highest top and the lowest base round it, so
//     the march leaps the clear air over and under the cloud.
//   2 SHADOW: how much sun reaches up through the cloud from the sea's
//     height, over its own square (the land reads it through shaders/
//     cloud_volume_shadow.gdshaderinc).
//   3 MARCH: first the valley fog (a low layer lying along the valleys
//     over their floors, from the fog map; its own short march over the
//     slab it can fill, lit by the sun through the ridges' shade and its
//     own depth, and the sky), then the clouds as the isles' (one ray per quarter-res pixel, the light's
//     cone of taps, three scattering octaves, powder, the sky's light from
//     overhead), out to the map's reach.
//
// The cell hash is pcg3d on integers, mirrored in endless_clouds.gd
// (`clouds_in`), so the CPU knows where every cloud is.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(push_constant, std430) uniform Pass {
	int mode;
	int pad0;
	int pad1;
	int pad2;
} PASS;

layout(set = 0, binding = 0, std430) restrict readonly buffer Params {
	mat4 camera;        // 0  world from view
	vec4 lens;          // 16 tan half fov x, y, near, far
	vec4 eye;           // 20 xyz, motion time
	vec4 sun;           // 24 xyz, unused
	vec4 key;           // 28 xyz the light on the cloud (sun, moon at night), unused
	vec4 band;          // 32 sea y, slab top y, reach (m), on
	vec4 drift;         // 36 drift xz (m, the field's offset), seed salt, cover
	vec4 ground_at;     // 40 the ground map: corner xz, side, has one
	vec4 shade_sq;      // 44 the shade's square: corner xz, side, unused
	vec4 frame;         // 48 frame, unused, unused, deep night
	vec4 knobs;         // 52 small puffs' cover, low share, tower share, meadow clearance (m)
	vec4 fog_at;        // 56 the valley fog's map: corner xz, side, has one
	vec4 fog_knobs;     // 60 density scale, depth (m), steps, slab top (world y)
	vec4 fog_drift;     // 64 the patches' drift xz (m), reach (m), fade (m)
	vec4 spare[24];     // 68..163; spare[0] the valley fog's look: floor share, density scale, top thinning, -
	vec4 weather_at;    // 164 corner xz, side, texels a side
	vec4 quality;       // 168 steps, light taps, march scale, fine octaves on
	vec4 flash;         // 172 grain jitter on, organic field on, stacked clouds yield, puffs' finer lobes on
	vec4 shadow_at;     // 176 unused, shade texels, weather redrawn, shade redrawn
} P;

layout(set = 0, binding = 1) uniform sampler2D ground;
// The valley fog's map (endless_clouds.gd `fog_image`): ground y, the
// nearest valley's floor y, the fog it holds (0..1), the range round it.
layout(set = 0, binding = 2) uniform sampler2D fog_map;
layout(set = 0, binding = 3) uniform sampler3D cauliflower;
layout(set = 0, binding = 4) uniform sampler2D scene_depth;
layout(set = 0, binding = 5) uniform sampler3D body0;
layout(set = 0, binding = 6) uniform sampler3D body1;
layout(set = 0, binding = 7) uniform sampler3D body2;
layout(set = 0, binding = 8) uniform sampler3D body3;
layout(rgba16f, set = 0, binding = 9) uniform restrict writeonly image2D out_a;
layout(rgba16f, set = 0, binding = 10) uniform restrict writeonly image2D out_b;
layout(r32f, set = 0, binding = 11) uniform restrict writeonly image2D out_depth;
layout(rgba16f, set = 0, binding = 12) uniform restrict writeonly image2D out_weather;
layout(set = 0, binding = 13) uniform sampler2D weather;
layout(rgba16f, set = 0, binding = 14) uniform restrict writeonly image2D out_shadow;
layout(rgba16f, set = 0, binding = 15) uniform restrict writeonly image2D out_ceiling;
layout(set = 0, binding = 16) uniform sampler2D ceiling;

const int MODE_WEATHER = 0;
const int MODE_CEILING = 1;
const int MODE_SHADOW = 2;
const int MODE_MARCH = 3;

// --- The field (mirrored in scripts/endless/endless_clouds.gd) -----------------
// Broad cumulus: the cell (m), radius share range, base heights over the
// sea by kind (low, mid, tower) and tall-for-wide by kind.
const float BIG = 620.0;
const vec2 BIG_R = vec2(0.16, 0.40);
const vec2 LOW_BASE = vec2(26.0, 60.0);
const vec2 MID_BASE = vec2(128.0, 190.0);
const vec2 TOWER_BASE = vec2(115.0, 160.0);
const vec2 LOW_TALL = vec2(0.8, 1.4);
const vec2 MID_TALL = vec2(0.7, 1.3);
const vec2 TOWER_TALL = vec2(1.2, 1.9);
// A tower is broader than its cell's share by this.
const float TOWER_WIDE = 1.35;
// The crown's profile (lower: steeper flanks).
const float PROFILE = 0.42;
// The middle bubble's radius (share of the cloud's), and how far each
// bubble's base curls up at its rim (share of its height).
const float MAIN_R = 0.74;
const float CURL = 0.0;
const float BIG_COVER = 0.72;
// Small puffs low in the band.
const float SMALL = 230.0;
const vec2 SMALL_R = vec2(0.13, 0.30);
const vec2 SMALL_BASE = vec2(22.0, 115.0);
const vec2 SMALL_TALL = vec2(0.8, 1.5);
// The coverage's own weather: a lattice this wide (m) of clear and cloudier
// regions, scaling the cover between these.
const float REGION = 5200.0;
const vec2 REGION_SCALE = vec2(0.3, 1.45);
// No top over this far over the sea (m).
const float TOP_MAX = 1250.0;

// --- The shape ----------------------------------------------------------------------
const float CEILING_BLOCK_F = 32.0;
const int CEILING_BLOCK = 32;
const float TILE_LOW = 230.0;
const float TILE_HIGH = 460.0;
// Thin low cloud's (a puff's) lobes: their tile (m; the swells' 0.45 of it),
// fully below PUFF_THIN.x of the map's thickness, gone by .y.
const float PUFF_TILE = 70.0;
const vec2 PUFF_THIN = vec2(25.0, 90.0);
const float LOBE = 40.0;
const float MID = 95.0;
const float MID_SWELL = 14.0;
const float WISP = 3.0;
const float FINE = 34.0;
const float FINE_SWELL = 5.0;
const float FINE_NEAR = 320.0;
const vec2 SOFT = vec2(2.0, 6.0);
const vec3 BOIL = vec3(0.6, -0.35, 0.4);
const float SIGMA = 0.22;
const float SIGMA_IN = 0.06;
// How far billows may stand over a top or under a base.
const float OVER = 70.0;
const float SLOPE_MAX = 5.0;
// How far past a rim (m) the billows may still reach.
const float RIM_MARGIN = 50.0;
// The slopes' stencil, in texels each way (wider is smoother).
const float SLOPE_SPAN = 2.0;
const vec2 NEAR_FADE = vec2(3.0, 22.0);

// --- The march --------------------------------------------------------------------
const int STEPS_MAX = 160;
const vec2 STEP = vec2(2.5, 45.0);
const float STEP_GROW = 0.008;
const int TAPS_MAX = 6;
const float TAP_AT[6] = float[](4.0, 12.0, 28.0, 60.0, 120.0, 220.0);
const float TAP_LEN[6] = float[](8.0, 10.0, 22.0, 42.0, 80.0, 130.0);
const float SUN_SIGMA = 0.03;
const int OCTAVES = 3;
const float MS_A = 0.45;
const float MS_B = 0.55;
const float MS_C = 0.5;
const float PHASE_FORWARD = 0.82;
const float PHASE_BACK = -0.25;
const float PHASE_BACK_SHARE = 0.5;
const float PHASE_MAX = 14.0;
const float SUN_SCALE = 1.55;
const float FACE_SHADE = 30.0;
const float POWDER = 0.35;
const float POWDER_DEPTH = 9.0;
const float UP_SIGMA = 0.03;
const float CREASE = 0.3;
const float DEEP = 0.45;
const float SKY = 0.5;
// Light off the land and sea below on a cloud's base.
const float BOUNCE = 0.08;
const int LONG_TAPS = 3;
const float LONG_AT[3] = float[](300.0, 460.0, 650.0);
const float LONG_LEN = 140.0;

// The organic field is on (P.flash.y; --cloud-field=old: off).
bool g_new = false;

ivec2 zs_block_offset(int frame) {
	int k = frame & 3;
	return k == 0 ? ivec2(0, 0) : (k == 1 ? ivec2(1, 1) : (k == 2 ? ivec2(1, 0) : ivec2(0, 1)));
}

float sstep(float a, float b, float x) {
	float t = clamp((x - a) / (b - a), 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

// pcg3d (Jarzynski and Olano), on the cell's integer coordinates.
uvec3 pcg3d(uvec3 v) {
	v = v * 1664525u + 1013904223u;
	v.x += v.y * v.z;
	v.y += v.z * v.x;
	v.z += v.x * v.y;
	v ^= v >> 16u;
	v.x += v.y * v.z;
	v.y += v.z * v.x;
	v.z += v.x * v.y;
	return v;
}

vec3 hash3(ivec2 c, uint salt) {
	uvec3 h = pcg3d(uvec3(uint(c.x), uint(c.y), salt));
	return vec3(h >> 8u) / 16777216.0;
}

float hg(float c, float g) {
	float g2 = g * g;
	return (1.0 - g2) / pow(max(1.0 + g2 - 2.0 * g * c, 1e-4), 1.5);
}

float phase(float c, float scale) {
	return min(mix(hg(c, PHASE_FORWARD * scale), hg(c, PHASE_BACK * scale), PHASE_BACK_SHARE), PHASE_MAX);
}

// --- WEATHER --------------------------------------------------------------------------

// How cloudy the region round field point `f` is (a smooth value noise).
float region_cover(vec2 f) {
	vec2 g = f / REGION;
	ivec2 i = ivec2(floor(g));
	vec2 u = fract(g);
	u = u * u * (3.0 - 2.0 * u);
	uint salt = uint(P.drift.z) + 7u;
	float a = hash3(i, salt).x;
	float b = hash3(i + ivec2(1, 0), salt).x;
	float c = hash3(i + ivec2(0, 1), salt).x;
	float d = hash3(i + ivec2(1, 1), salt).x;
	return mix(REGION_SCALE.x, REGION_SCALE.y, mix(mix(a, b, u.x), mix(c, d, u.x), u.y));
}

// A layer's (top, base) at a texel as clouds are found: the tallest
// covering top and the lowest covering base; while nothing covers, the
// nearest cloud's base and a top falling away past its rim, so the map
// filters smoothly into clear air.
void take(inout vec2 layer, inout float gap, float top, float base, float out_by) {
	if (out_by <= 0.0) {
		if (gap > 0.0) {
			layer = vec2(top, base);
			gap = 0.0;
		} else if (g_new && (base > layer.x || top < layer.y)) {
			// Two clouds one over the other, apart: the thicker keeps the
			// texel (joined, they would stand as a pillar between them).
			if (top - base > layer.x - layer.y) layer = vec2(top, base);
		} else {
			layer = vec2(max(layer.x, top), min(layer.y, base));
		}
	} else if (gap > 0.0 && out_by < gap) {
		gap = out_by;
		layer = vec2(base - out_by, base);
	}
}

// One lattice's clouds round field point `f` into the two layers.
void lattice(vec2 f, bool big, float sea, float cover, inout vec2 low, inout float low_gap, inout vec2 high, inout float high_gap) {
	float cell = big ? BIG : SMALL;
	uint salt = uint(P.drift.z) + (big ? 101u : 211u);
	ivec2 g = ivec2(floor(f / cell));
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			ivec2 c = g + ivec2(x, y);
			vec3 h = hash3(c, salt);
			vec3 k = hash3(c, salt + 1u);
			vec2 middle = (vec2(c) + 0.2 + 0.6 * h.xy) * cell;
			float here = region_cover(middle) * cover * (big ? BIG_COVER : P.knobs.x);
			if (h.z >= here) continue;
			vec2 rr = big ? BIG_R : SMALL_R;
			float r = cell * mix(rr.x, rr.y, k.x);
			float d = length(f - middle);
			float base;
			float tall;
			bool is_low = !big;
			if (big) {
				if (k.y < P.knobs.y) {
					is_low = true;
					base = mix(LOW_BASE.x, LOW_BASE.y, k.z);
					tall = mix(LOW_TALL.x, LOW_TALL.y, fract(k.z * 7.31));
				} else if (k.y < P.knobs.y + P.knobs.z) {
					base = mix(TOWER_BASE.x, TOWER_BASE.y, k.z);
					tall = mix(TOWER_TALL.x, TOWER_TALL.y, fract(k.z * 7.31));
					r *= TOWER_WIDE;
				} else {
					base = mix(MID_BASE.x, MID_BASE.y, k.z);
					tall = mix(MID_TALL.x, MID_TALL.y, fract(k.z * 7.31));
				}
			} else {
				base = mix(SMALL_BASE.x, SMALL_BASE.y, k.y);
				tall = mix(SMALL_TALL.x, SMALL_TALL.y, k.z);
			}
			float H = min(r * tall, TOP_MAX - base);
			// The cloud as a cluster of bubbles: a broad one in the middle and
			// three round it, lower; each a round crown over a flat base that
			// curls up toward its rim, so the cloud's foot is rounded.
			vec3 b1 = hash3(c, salt + 2u);
			vec3 b2 = hash3(c, salt + 3u);
			float spin = b1.x * 6.2832;
			float top_c = -1e4;
			float base_c = 1e4;
			float out_c = 1e9;
			for (int i = 0; i < 4; i++) {
				vec2 at = middle;
				float br = r * MAIN_R;
				float bh = H;
				if (i > 0) {
					float sh = i == 1 ? b1.y : (i == 2 ? b1.z : b2.x);
					float a = spin + float(i) * 2.0944 + (i == 1 ? b2.y : (i == 2 ? b2.z : b1.y)) * 1.2;
					at = middle + vec2(cos(a), sin(a)) * r * mix(0.32, 0.58, sh);
					br = r * mix(0.36, 0.58, fract(sh * 3.7));
					bh = H * mix(0.4, 0.85, fract(sh * 5.3));
					// A tower's shoulders broad round its column.
					if (tall > MID_TALL.y + 0.1) br *= 1.25;
				}
				float bd = length(f - at);
				float u = bd / br;
				if (u < 1.0) {
					top_c = max(top_c, base + bh * pow(1.0 - u * u, PROFILE));
					base_c = min(base_c, base + bh * CURL * u * u * u * u);
				} else {
					out_c = min(out_c, bd - br);
				}
			}
			if (top_c > -1e3) {
				if (is_low) take(low, low_gap, sea + top_c, sea + base_c, 0.0);
				else take(high, high_gap, sea + top_c, sea + base_c, 0.0);
			} else {
				if (is_low) take(low, low_gap, sea + base, sea + base, out_c);
				else take(high, high_gap, sea + base, sea + base, out_c);
			}
		}
	}
}

// The ground map at world `xz`: (meadow round it, the ground's height).
vec2 ground_at(vec2 xz) {
	if (P.ground_at.w < 0.5) return vec2(0.0, P.band.x);
	vec2 uv = (xz - P.ground_at.xy) / P.ground_at.z;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return vec2(0.0, P.band.x);
	return textureLod(ground, uv, 0.0).rg;
}

// How high a cloud over world `w` reaching `reach` must keep its lowest
// point (m over the sea; the ground's highest under its footprint, and
// for a low cloud the meadows' clearance), and the most meadow under it.
// Mirrored in endless_clouds.gd (`_cloud_floor`).
vec2 cloud_floor(vec2 w, float reach, bool low) {
	float need = -1e4;
	float meadow = 0.0;
	for (int i = 0; i < 7; i++) {
		float a = float(i) * 1.0472;
		vec2 xz = w + (i == 0 ? vec2(0.0) : vec2(cos(a), sin(a)) * reach * 0.55);
		vec2 g = ground_at(xz);
		float m = clamp(g.x, 0.0, 1.0);
		float fl = max(g.y, P.band.x) + 4.0;
		need = max(need, low ? max(fl, mix(fl, g.y + P.knobs.w, m)) : fl);
		meadow = max(meadow, m);
	}
	return vec2(need - P.band.x, meadow);
}

// --- The organic field (P.flash.y = 1; --cloud-field=old is the lattice above) ----
// Mirrored in endless_clouds.gd (`_recipe`, `_bubble_span`). Cells jitter
// JIT of a cell each way from their middle, and a cloud's reach (its
// bubbles and their wobble) is held under EXT_MAX cells, so the 3x3 cells
// round a texel always hold every cloud over it (JIT + EXT_MAX <= 1.5).
const float JIT = 0.62;
const float EXT_MAX = 0.85;
// Clouds gather in fields: two octaves of value noise this wide (m) gate
// the cover between CLUSTER_GATE, so there is clear sky between groups.
const float CLUSTER = 2600.0;
const vec2 CLUSTER_GATE = vec2(0.36, 0.66);
const float BIG_COVER2 = 1.0;
const float SMALL_COVER2 = 0.27;
// Shares of the broad cells' kinds (the rest are mid cumulus).
const float FAIR_SHARE = 0.28;
const float TOWER_SHARE2 = 0.08;
const float ROW_SHARE = 0.14;
const float WISP_SHARE = 0.08;
// Sizes: a cell's share, skewed small (k^SIZE_SKEW).
const vec2 BIG_R2 = vec2(0.09, 0.44);
const vec2 SMALL_R2 = vec2(0.10, 0.32);
const float SIZE_SKEW = 1.5;
// Each bubble's rim wobbles by this share (two sines round it).
const float WOB = 0.2;
// Side bubbles hang up to this share of the cloud's height over its base.
const float LIFT = 0.3;
// A bubble stands this many times its kind's tall-for-wide over its own
// radius, so every bubble is a dome (cauliflower), never a pillar.
const float DOME = 1.6;
// Two clouds of one layer stand one over the other (and one yields) when the
// upper one's base is over the lower's base by more than this share of the
// lower's height.
const float YIELD_LEVEL = 0.5;
// How far past a cloud's reach (m) its yielding is still asked.
const float YIELD_NEAR = 80.0;
const int KIND_FAIR = 0;
const int KIND_MID = 1;
const int KIND_TOWER = 2;
const int KIND_ROW = 3;
const int KIND_WISP = 4;
const int KIND_PUFF = 5;


float value_noise(vec2 g, uint salt) {
	ivec2 i = ivec2(floor(g));
	vec2 u = fract(g);
	u = u * u * (3.0 - 2.0 * u);
	float a = hash3(i, salt).x;
	float b = hash3(i + ivec2(1, 0), salt).x;
	float c = hash3(i + ivec2(0, 1), salt).x;
	float d = hash3(i + ivec2(1, 1), salt).x;
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float cluster_gate(vec2 f) {
	uint salt = uint(P.drift.z);
	float n = 0.65 * value_noise(f / CLUSTER, salt + 17u) + 0.35 * value_noise(f / (CLUSTER * 0.43), salt + 19u);
	return sstep(CLUSTER_GATE.x, CLUSTER_GATE.y, n);
}

struct Cloud {
	vec2 middle;
	vec2 axis;
	float r;
	float base;
	float H;
	float tall;
	int n;
	int kind;
	float L;
	float W;
	float main_r;
	vec2 br;
	vec2 hs;
	float belly;
	float qb;
	float profile;
	float ext;
	bool low;
};

// The cloud of cell `c` before it is lifted over the ground (false: none):
// its kind, footprint and form.
bool recipe_shape(ivec2 c, bool big, float cover, out Cloud k) {
	float cell = big ? BIG : SMALL;
	uint salt = uint(P.drift.z) + (big ? 101u : 211u);
	vec3 h = hash3(c, salt);
	k.middle = (vec2(c) + 0.5 + JIT * (h.xy * 2.0 - 1.0)) * cell;
	float gate = cluster_gate(k.middle);
	if (!big) gate = mix(0.02, 1.0, gate * gate);
	float here = region_cover(k.middle) * cover * (big ? BIG_COVER2 : SMALL_COVER2) * gate;
	if (h.z >= here) return false;
	vec3 s = hash3(c, salt + 1u);
	vec3 m = hash3(c, salt + 2u);
	vec2 rr = big ? BIG_R2 : SMALL_R2;
	k.r = cell * mix(rr.x, rr.y, pow(s.x, SIZE_SKEW));
	float spin = m.x * 6.2832;
	k.axis = vec2(cos(spin), sin(spin));
	float t2 = fract(s.z * 7.31);
	float t3 = fract(s.z * 3.17 + m.y);
	vec2 nr;
	vec2 tall;
	vec2 belly;
	vec2 qb;
	k.profile = PROFILE;
	k.low = false;
	if (!big) {
		k.kind = KIND_PUFF;
		k.low = true;
		k.base = mix(SMALL_BASE.x, SMALL_BASE.y, s.y);
		nr = vec2(2.0, 5.0); k.L = 0.45; k.W = 0.35; k.main_r = 0.65; k.br = vec2(0.4, 0.62); k.hs = vec2(0.7, 1.1);
		tall = vec2(0.6, 1.25); belly = vec2(0.35, 0.55); qb = vec2(0.5, 0.85);
	} else if (s.y < FAIR_SHARE) {
		k.kind = KIND_FAIR;
		k.low = true;
		k.base = mix(LOW_BASE.x, LOW_BASE.y, s.z);
		nr = vec2(3.0, 6.0); k.L = 0.55; k.W = 0.38; k.main_r = 0.62; k.br = vec2(0.35, 0.6); k.hs = vec2(0.7, 1.1);
		tall = vec2(0.55, 1.0); belly = vec2(0.3, 0.5); qb = vec2(0.45, 0.8);
	} else if (s.y < FAIR_SHARE + TOWER_SHARE2) {
		k.kind = KIND_TOWER;
		k.base = mix(TOWER_BASE.x, TOWER_BASE.y, s.z);
		nr = vec2(5.0, 9.0); k.L = 0.5; k.W = 0.45; k.main_r = 0.6; k.br = vec2(0.4, 0.6); k.hs = vec2(0.6, 1.0);
		tall = vec2(1.0, 1.5); belly = vec2(0.25, 0.4); qb = vec2(0.45, 0.7);
		k.profile = 0.4;
		k.r *= 1.2;
	} else if (s.y < FAIR_SHARE + TOWER_SHARE2 + ROW_SHARE) {
		k.kind = KIND_ROW;
		k.low = t3 < 0.4;
		k.base = k.low ? mix(LOW_BASE.x, LOW_BASE.y + 30.0, s.z) : mix(MID_BASE.x, MID_BASE.y, s.z);
		nr = vec2(6.0, 9.0); k.L = 1.15; k.W = 0.18; k.main_r = 0.5; k.br = vec2(0.36, 0.55); k.hs = vec2(0.8, 1.15);
		tall = vec2(0.55, 0.95); belly = vec2(0.32, 0.5); qb = vec2(0.5, 0.8);
	} else if (s.y < FAIR_SHARE + TOWER_SHARE2 + ROW_SHARE + WISP_SHARE) {
		k.kind = KIND_WISP;
		k.base = mix(180.0, 320.0, s.z);
		nr = vec2(2.0, 4.0); k.L = 1.0; k.W = 0.4; k.main_r = 0.6; k.br = vec2(0.5, 0.8); k.hs = vec2(0.9, 1.1);
		tall = vec2(0.08, 0.16); belly = vec2(0.45, 0.5); qb = vec2(0.6, 0.7);
		k.r *= 1.3;
	} else {
		k.kind = KIND_MID;
		k.base = mix(MID_BASE.x, MID_BASE.y, s.z);
		nr = vec2(4.0, 8.0); k.L = 0.6; k.W = 0.45; k.main_r = 0.6; k.br = vec2(0.35, 0.62); k.hs = vec2(0.7, 1.15);
		tall = vec2(0.6, 1.2); belly = vec2(0.35, 0.55); qb = vec2(0.5, 0.85);
	}
	// Stretched along its axis by up to half again.
	k.L *= mix(0.8, 1.45, m.y);
	k.n = int(nr.x) + min(int(m.z * (nr.y - nr.x + 1.0)), int(nr.y - nr.x));
	k.ext = length(vec2(k.L, k.W)) + max(k.br.y, k.main_r) * (1.0 + WOB);
	k.r = min(k.r, EXT_MAX * cell / k.ext);
	k.tall = mix(tall.x, tall.y, t2) * DOME;
	k.belly = mix(belly.x, belly.y, fract(m.y * 5.13 + s.x));
	k.qb = mix(qb.x, qb.y, fract(m.z * 3.71 + h.x));
	return true;
}

// Cloud `k` (of cell `c`) lifted whole over the ground, so the belly keeps
// its round (the map's clamp under it would cut it level); a lifted cloud a
// little higher again, its own, so lifted neighbours never share a base.
// Over the meadows a low one thins.
void recipe_lift(inout Cloud k, ivec2 c, bool big) {
	uint salt = uint(P.drift.z) + (big ? 101u : 211u);
	vec3 h = hash3(c, salt);
	vec3 s = hash3(c, salt + 1u);
	vec2 fl = cloud_floor(k.middle + P.drift.xy, k.r * k.ext, k.low);
	if (fl.x > k.base) k.base = fl.x + 30.0 * fract(s.y * 13.7 + h.x);
	if (k.low) k.tall *= mix(1.0, 0.6, fl.y);
	k.H = min(k.r * k.main_r * k.tall, TOP_MAX - k.base);
}

// The cloud of cell `c` (false: none).
bool recipe(ivec2 c, bool big, float cover, out Cloud k) {
	if (!recipe_shape(c, big, cover, k)) return false;
	recipe_lift(k, c, big);
	return true;
}

// The weather map keeps one span (top, base) per layer in a texel, so two
// clouds of one layer whose footprints overlap, one standing over the
// other, cannot both be drawn there: the texels they share joined them into
// a pillar (a wisp over a cumulus stood on a stem, a mushroom) or cut one
// round the other. Such a pair is never placed: the lesser yields (a puff to
// a broad cloud, a wisp to any other, a puff to a thicker puff). Two of a
// layer at about one level still merge, as before, and the broad clouds
// other than the wisps never yield (they seldom stand stacked, and asking
// for every texel they cover costs too much). Mirrored in endless_clouds.gd
// (`_yields`).
bool clash(Cloud a, Cloud b) {
	if (a.kind == KIND_WISP || b.kind == KIND_WISP) return true;
	bool a_low = a.base <= b.base;
	float lo_base = a_low ? a.base : b.base;
	float lo_h = a_low ? a.H : b.H;
	float hi_base = a_low ? b.base : a.base;
	return hi_base > lo_base + YIELD_LEVEL * lo_h;
}

bool yields(Cloud k, ivec2 c, bool big, float cover) {
	float reach = k.r * k.ext;
	for (int pass = 0; pass < 2; pass++) {
		bool other_big = pass == 0;
		// A broad cloud never yields to a puff.
		if (big && !other_big) continue;
		float cell = other_big ? BIG : SMALL;
		ivec2 g = ivec2(floor(k.middle / cell));
		float most = reach + EXT_MAX * cell;
		for (int y = -2; y <= 2; y++) {
			for (int x = -2; x <= 2; x++) {
				ivec2 n = g + ivec2(x, y);
				if (other_big == big && n == c) continue;
				// Cheap first: a cell's middle alone can rule it out.
				uint salt = uint(P.drift.z) + (other_big ? 101u : 211u);
				vec3 h = hash3(n, salt);
				vec2 mid = (vec2(n) + 0.5 + JIT * (h.xy * 2.0 - 1.0)) * cell;
				if (length(mid - k.middle) >= most) continue;
				Cloud o;
				if (!recipe_shape(n, other_big, cover, o)) continue;
				if (o.low != k.low) continue;
				if (length(o.middle - k.middle) >= reach + o.r * o.ext) continue;
				bool wisps = k.kind == KIND_WISP || o.kind == KIND_WISP;
				if (!wisps) {
					recipe_lift(o, n, other_big);
					if (!clash(k, o)) continue;
				}
				bool me;
				bool order = c.x < n.x || (c.x == n.x && c.y < n.y);
				if (big != other_big) me = true;
				else if ((k.kind == KIND_WISP) != (o.kind == KIND_WISP)) me = k.kind == KIND_WISP;
				else if (k.kind == KIND_WISP) me = order;
				else me = k.H < o.H || (k.H == o.H && order);
				if (me) return true;
			}
		}
	}
	return false;
}

// Bubble `i` of cloud `k` (from cell `c`) over field point `f`: (top,
// bottom, rim height) where it covers f, else (-1e4, distance past its
// rim, rim height).
vec3 bubble_span(Cloud k, ivec2 c, uint salt, int i, vec2 f) {
	vec3 q = hash3(c, salt + 10u + uint(i));
	vec2 off = vec2(0.0);
	float br = k.main_r;
	float hs = 1.0;
	float lift = 0.0;
	if (i > 0) {
		float along = k.kind == KIND_ROW ? (2.0 * (float(i - 1) + q.x) / float(max(k.n - 1, 1)) - 1.0) * k.L : (q.x * 2.0 - 1.0) * k.L;
		off = vec2(along, (q.y * 2.0 - 1.0) * k.W);
		br = mix(k.br.x, k.br.y, q.z);
		hs = mix(k.hs.x, k.hs.y, fract(q.z * 5.3)) * (1.0 - 0.25 * min(length(off) / max(k.L, 0.05), 1.0));
		lift = LIFT * fract(q.z * 9.17);
	} else {
		lift = LIFT * 0.3 * fract(q.z * 9.17);
	}
	vec2 at = k.middle + (k.axis * off.x + vec2(-k.axis.y, k.axis.x) * off.y) * k.r;
	vec2 d = f - at;
	float bd = length(d);
	float a = atan(d.y, d.x + 1e-6);
	float rw = br * k.r * (1.0 + WOB * (0.6 * sin(3.0 * a + fract(q.x * 7.7) * 6.2832) + 0.4 * sin(5.0 * a + fract(q.y * 5.9) * 6.2832)));
	float u = bd / rw;
	float bh = min(br * k.r * k.tall * hs, k.H * 1.2);
	// Its own round belly: deeper or shallower, rounder or blunter than
	// its neighbours', so the cloud's underside is a run of lumps.
	float down = bh * k.belly * mix(0.75, 1.3, fract(q.y * 3.31 + q.x));
	float qb = k.qb * mix(0.8, 1.25, fract(q.x * 4.13 + q.z));
	float rim = k.base + k.H * lift + down;
	if (u >= 1.0) return vec3(-1e4, bd - br * k.r * (1.0 + WOB), rim);
	float v = 1.0 - u * u;
	return vec3(rim + max(bh - down, bh * 0.3) * pow(v, k.profile), rim - down * pow(v, qb), rim);
}

void lattice_new(vec2 f, bool big, float sea, float cover, inout vec2 low, inout float low_gap, inout vec2 high, inout float high_gap) {
	float cell = big ? BIG : SMALL;
	uint salt = uint(P.drift.z) + (big ? 101u : 211u);
	ivec2 g = ivec2(floor(f / cell));
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			ivec2 c = g + ivec2(x, y);
			Cloud k;
			if (!recipe(c, big, cover, k)) continue;
			float d = length(f - k.middle);
			float top_c = -1e4;
			float base_c = 1e4;
			float out_c = d - k.ext * k.r;
			// Whether a puff or a wisp yields is asked over its reach and a
			// margin round it, where its rim's height could still be the
			// nearest rim a texel keeps and so bend a neighbour's smoothed edge
			// (farther off it only gives the leap a shorter, safe distance).
			if (out_c < YIELD_NEAR && P.flash.z > 0.5 && (!big || k.kind == KIND_WISP) && yields(k, c, big, cover)) continue;
			// Past the rims the map keeps the nearest rim's height as the
			// base (the cloud's lowest point there would drag the smoothed
			// base down at the rim into hanging strands).
			float rim_c = k.base + k.H * 0.4;
			if (out_c <= 0.0) {
				out_c = 1e9;
				for (int i = 0; i < 9; i++) {
					if (i >= k.n) break;
					vec3 b = bubble_span(k, c, salt, i, f);
					if (b.x > -1e3) {
						top_c = max(top_c, b.x);
						base_c = min(base_c, b.y);
					} else if (b.y < out_c) {
						out_c = b.y;
						rim_c = b.z;
					}
				}
			}
			if (top_c > -1e3) {
				if (k.low) take(low, low_gap, sea + top_c, sea + base_c, 0.0);
				else take(high, high_gap, sea + top_c, sea + base_c, 0.0);
			} else {
				if (k.low) take(low, low_gap, sea + rim_c, sea + rim_c, out_c);
				else take(high, high_gap, sea + rim_c, sea + rim_c, out_c);
			}
		}
	}
}

vec4 weather_texel(vec2 xz) {
	float sea = P.band.x;
	vec2 f = xz - P.drift.xy;
	vec2 low = vec2(sea - 300.0, sea);
	vec2 high = vec2(sea - 300.0, sea);
	float low_gap = 1e9;
	float high_gap = 1e9;
	float cover = P.drift.w;
	if (g_new) {
		lattice_new(f, true, sea, cover, low, low_gap, high, high_gap);
		lattice_new(f, false, sea, cover, low, low_gap, high, high_gap);
	} else {
		lattice(f, true, sea, cover, low, low_gap, high, high_gap);
		lattice(f, false, sea, cover, low, low_gap, high, high_gap);
	}
	// The ground under it: no cloud base under the ground, and over the
	// meadows the low layer lifted clear and thinned, so the turf stays
	// landable.
	vec2 g = ground_at(xz);
	float meadow = clamp(g.x, 0.0, 1.0);
	float floor_y = max(g.y, sea) + 4.0;
	float lift = max(floor_y, mix(floor_y, g.y + P.knobs.w, meadow)) - low.y;
	if (lift > 0.0) {
		float thick = low.x - low.y;
		low.y += lift;
		low.x = low.y + (thick > 0.0 ? thick * mix(1.0, 0.5, meadow) : thick);
	}
	if (high.y < floor_y) {
		float thick = high.x - high.y;
		high.y = floor_y;
		high.x = high.y + thick;
	}
	// Faded toward the map's reach.
	float far = length(xz - P.eye.xz);
	float keep = 1.0 - sstep(P.band.z * 0.85, P.band.z, far);
	low.x = mix(low.y - 60.0, low.x, keep);
	high.x = mix(high.y - 60.0, high.x, keep);
	return vec4(low.x, low.y, high.x, high.y);
}

// --- The cloud at a point ----------------------------------------------------------------

vec4 weather_map(vec2 xz) {
	vec2 uv = (xz - P.weather_at.xy) / P.weather_at.z;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return vec4(-1e3, 0.0, -1e3, 0.0);
	return textureLod(weather, uv, 0.0);
}

// The map smoothed over two texels (four bilinear taps half a texel
// about): its texels' creases, sharp down a steep flank, never show as
// flutes in the cloud's form or its light.
vec4 weather_smooth(vec2 xz) {
	float h = 0.5 * P.weather_at.z / P.weather_at.w;
	return 0.25 * (weather_map(xz + vec2(h, h)) + weather_map(xz + vec2(-h, h)) + weather_map(xz + vec2(h, -h)) + weather_map(xz + vec2(-h, -h)));
}

// The highest top and lowest base round `xz`.
vec2 ceiling_at(vec2 xz) {
	vec2 uv = (xz - P.weather_at.xy) / P.weather_at.z;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return vec2(-1e3, 1e4);
	return textureLod(ceiling, uv, 0.0).rg;
}

// How far into one layer's cloud a point is (m); `hh` its height in it.
float layer_inside(vec3 p, float top, float base, float slope, float slope_b, float n_lobe, float n_wisp, float n_mid, float n_fine, out float hh) {
	float thick = top - base;
	hh = clamp((p.y - base) / max(thick, 4.0), 0.0, 1.0);
	float size = clamp(thick / 110.0, 0.45, 2.6);
	float billow = mix(0.3, 1.0, hh) * sstep(0.0, 14.0, thick) * size;
	float inside = (top - p.y) / sqrt(1.0 + slope * slope) + billow * LOBE * (n_lobe - 0.45) + (n_wisp - 0.5) * WISP;
	inside += billow * MID_SWELL * (n_mid - 0.45);
	inside += n_fine > 0.0 ? n_fine * sstep(-4.0, 1.0, inside) : n_fine;
	if (g_new) {
		// The underside: the map's rounded belly, carved up into lumps (only
		// up, so the map's base stays the lowest any cloud reaches).
		float lump = clamp(0.5 + (0.45 - n_lobe) * 1.2 + (0.45 - n_mid) * 1.6 + (0.5 - n_wisp) * 0.6, 0.0, 1.0);
		float under = clamp(thick * 0.28, 2.0, 40.0) * lump;
		return min(inside, (p.y - base - under) / sqrt(1.0 + slope_b * slope_b) * 1.2 + 1.0);
	}
	// A flat base, a little ragged.
	return min(inside, (p.y - base + (n_wisp - 0.5) * 10.0 + (n_lobe - 0.45) * 8.0) * 1.2 + 1.0);
}

// This pixel's jitter this frame (0..1; the march's), for the stencils.
float g_jitter = 0.5;

struct Sample {
	float density;
	float sigma;
	float inside;
	float h;
	float pocket;
	float free;
};

// How far `p` stands clear of one layer's cloud (m, a lower bound) from its
// texel's `top` and `base`: past the rim (where the map has no cloud it
// keeps how far the nearest rim is, as base - top), over the crown, or
// under the base.
float layer_free(float y, float top, float base) {
	float under = base - 6.0 - y;
	if (top < base) return max(base - top - RIM_MARGIN, under);
	return max(max(y - top - OVER, under), 0.0);
}

Sample cloud_at(vec3 p, float t, float immersed, bool fine) {
	Sample s = Sample(0.0, SIGMA, -1e3, 0.0, 0.5, 0.0);
	if (P.band.w <= 0.0 || p.y < P.band.x - 1.0 || p.y > P.band.y + OVER) return s;
	vec4 w = weather_smooth(p.xz);
	s.free = min(layer_free(p.y, w.x, w.y), layer_free(p.y, w.z, w.w));
	bool low_on = p.y > w.y - 6.0 && p.y < w.x + OVER;
	bool high_on = p.y > w.w - 6.0 && p.y < w.z + OVER;
	if (!low_on && !high_on) {
		s.inside = max(w.x - p.y, w.z - p.y);
		s.inside = min(s.inside, max(p.y - w.y, p.y - w.w) * 2.0);
		return s;
	}
	// The tops' slopes (central differences over SLOPE_SPAN texels), held under
	// SLOPE_MAX so the texels' facets never show as stripes on a flank.
	float texel = P.weather_at.z / P.weather_at.w;
	float span = texel * SLOPE_SPAN;
	vec2 at = p.xz;
	vec4 wx = weather_map(at + vec2(span, 0.0)) - weather_map(at - vec2(span, 0.0));
	vec4 wz = weather_map(at + vec2(0.0, span)) - weather_map(at - vec2(0.0, span));
	vec2 slope = vec2(length(vec2(wx.x, wz.x)), length(vec2(wx.z, wz.z))) / (2.0 * span);
	slope = min(slope, vec2(SLOPE_MAX));
	vec2 slope_b = min(vec2(length(vec2(wx.y, wz.y)), length(vec2(wx.w, wz.w))) / (2.0 * span), vec2(SLOPE_MAX));
	vec3 boil = BOIL * P.eye.w;
	float fine_w = (fine && P.quality.w > 0.5) ? 1.0 - sstep(FINE_NEAR * 0.6, FINE_NEAR, t) : 0.0;
	float hh_l = 0.0, hh_h = 0.0;
	float in_l = -1e3, in_h = -1e3;
	float wisp = 0.5;
	if (low_on) {
		vec2 n = textureLod(cauliflower, (p + boil) / TILE_LOW, 0.0).rg;
		float nm = textureLod(cauliflower, (p + boil * 1.3 + 37.0) / MID, 0.0).r;
		float nf = fine_w > 0.0 ? fine_w * FINE_SWELL * (textureLod(cauliflower, (p + boil * 1.6 + 71.0) / FINE, 0.0).r - 0.5) : 0.0;
		// A small puff is only a few of the map's texels across, under the
		// lobes' and swells' scales, so it drew as a smooth bell with a flat
		// base: thin low cloud takes its lobes and swells from finer noise
		// (P.flash.w; --cloud-puffs=old: off).
		float small_l = (1.0 - sstep(PUFF_THIN.x, PUFF_THIN.y, w.x - w.y)) * P.flash.w;
		if (small_l > 0.0) {
			n.r = mix(n.r, textureLod(cauliflower, (p + boil + 11.0) / PUFF_TILE, 0.0).r, small_l);
			nm = mix(nm, textureLod(cauliflower, (p + boil * 1.3 + 53.0) / (PUFF_TILE * 0.45), 0.0).r, small_l);
		}
		in_l = layer_inside(p, w.x, w.y, slope.x, slope_b.x, n.r, n.g, nm, nf, hh_l);
		wisp = n.g;
	}
	if (high_on) {
		vec2 n = textureLod(cauliflower, (p + boil * 1.4 + 113.0) / TILE_HIGH, 0.0).rg;
		float nm = textureLod(cauliflower, (p + boil * 1.3 + 59.0) / (MID * 1.6), 0.0).r;
		float nf = fine_w > 0.0 ? fine_w * FINE_SWELL * (textureLod(cauliflower, (p + boil * 1.6 + 23.0) / FINE, 0.0).r - 0.5) : 0.0;
		in_h = layer_inside(p, w.z, w.w, slope.y, slope_b.y, n.r, n.g, nm * 1.6 - 0.3, nf, hh_h);
		if (in_h > in_l) wisp = n.g;
	}
	float inside = max(in_l, in_h);
	float hh = in_h > in_l ? hh_h : hh_l;
	float soft = mix(SOFT.y, SOFT.x, hh) * mix(0.5, 1.0, sstep(40.0, 300.0, t));
	float d = sstep(0.0, soft, inside) * mix(0.55, 1.0, sstep(0.3, 0.68, wisp));
	if (g_new) {
		// Thin cloud in the high layer (the wisps, the mid cloud's very rims)
		// frays into strands.
		float thin = in_h > in_l ? 1.0 - sstep(10.0, 40.0, w.z - w.w) : 0.0;
		if (thin > 0.0 && d > 0.0) {
			// Streaked along the field's x, as wind-combed strands.
			float strand = textureLod(cauliflower, (p + boil * 2.0) * vec3(1.0 / 260.0, 1.0 / 24.0, 1.0 / 55.0), 0.0).r;
			d *= mix(1.0, 0.75 * sstep(0.42, 0.78, strand) * sstep(0.3, 0.6, wisp), thin);
		}
	}
	d *= sstep(P.band.x - 1.0, P.band.x + 4.0, p.y);
	// In the cloud the fog round the eye comes in wisps and pockets, never
	// clear: the whiteout closes in a few tens of metres.
	d *= mix(1.0, 0.35 + 0.65 * sstep(0.38, 0.64, wisp), immersed);
	s.inside = inside;
	if (d > 0.0) {
		s.density = d;
		s.h = hh;
		s.pocket = wisp;
		s.sigma = mix(SIGMA, SIGMA_IN, immersed);
	}
	return s;
}

// The light taps' form: the density, one noise octave.
float density_cheap(vec3 p) {
	if (p.y < P.band.x - 1.0 || p.y > P.band.y + OVER) return 0.0;
	vec4 w = weather_smooth(p.xz);
	bool low_on = p.y > w.y - 6.0 && p.y < w.x + OVER;
	bool high_on = p.y > w.w - 6.0 && p.y < w.z + OVER;
	if (!low_on && !high_on) return 0.0;
	vec2 n = textureLod(cauliflower, (p + BOIL * P.eye.w) / TILE_HIGH, 0.0).rg;
	float hh;
	float inside = -1e3;
	if (low_on) inside = layer_inside(p, w.x, w.y, 0.6, 0.6, n.r, n.g, 0.45, 0.0, hh);
	if (high_on) inside = max(inside, layer_inside(p, w.z, w.w, 0.6, 0.6, n.r, n.g, 0.45, 0.0, hh));
	return sstep(-4.0, 12.0, inside);
}

// The coarse form's distance into the cloud, for the face a ray first meets.
float inside_cheap(vec3 p) {
	vec4 w = weather_smooth(p.xz);
	vec2 n = textureLod(cauliflower, (p + BOIL * P.eye.w) / TILE_LOW, 0.0).rg;
	float hh;
	return max(layer_inside(p, w.x, w.y, 0.6, 0.6, n.r, n.g, 0.45, 0.0, hh), layer_inside(p, w.z, w.w, 0.6, 0.6, n.r, n.g, 0.45, 0.0, hh));
}

// How far a ray may leap from `p` before it can meet cloud (0: step here).
float clear_ahead(vec3 p, vec3 rd, float level) {
	vec2 c = ceiling_at(p.xz);
	float block = P.weather_at.z / P.weather_at.w * CEILING_BLOCK_F;
	float across = block * 0.9 / level;
	float over = p.y - (c.x + OVER);
	if (over > 0.0) return min(rd.y < 0.0 ? over / -rd.y : 1e9, across);
	float under = (c.y - 8.0) - p.y;
	if (under > 0.0) return min(rd.y > 0.0 ? under / rd.y : 1e9, across);
	return 0.0;
}

// --- The valley fog ------------------------------------------------------------------
// A low layer lying along the valleys, between the ridges: over each
// valley's floor (the fog map's), up to a top FOG depth over it that the
// patches raise and lower, so it is thick in pockets and thin or gone
// elsewhere, with a soft billowed top the ridges and spurs rise out of. It
// thins near the ground, so the floor's meadows show under it.
// The patches: two broad scales of the noise's soft wisps (m), slowly
// morphing (the noise's third axis, per second) and drifting on the wind.
const float FOG_PATCH = 820.0;
const float FOG_PATCH2 = 2300.0;
const float FOG_MORPH = 0.0025;
// Where the patches' sum, in its own spreads from its mean (the noise's
// soft wisps: mean 0.48, the sum's spread 0.075), turns from gap to fog.
const vec2 FOG_GATE = vec2(-0.35, 0.9);
const vec2 FOG_SUM = vec2(0.48, 0.0785);
// The top's billows (m, their scale and height) and its softness (m).
const float FOG_BILLOW = 70.0;
const float FOG_BILLOW_H = 12.0;
const float FOG_TOP_SOFT = 30.0;
// Over the ground (m) the fog thins to FOG_UNDER of itself.
const vec2 FOG_GROUND = vec2(2.0, 18.0);
const float FOG_UNDER = 0.12;
// Its density's scale (per m at 1) and the light's.
const float FOG_SIGMA = 0.032;
const float FOG_SUN_SIGMA = 0.005;
const float FOG_SKY = 1.0;
// The fog's light scatters more evenly than the cloud's (the share of the
// cloud's phase it keeps, the rest even).
const float FOG_PHASE = 0.45;
// The patches' middle scale (m).
const float FOG_PATCH3 = 340.0;
const float FOG_BOUNCE = 0.16;
// The sun's shade by the ridges: taps along the light (m).
const vec4 FOG_SHADE_AT = vec4(30.0, 80.0, 170.0, 320.0);

vec4 fog_texel(vec2 xz) {
	if (P.fog_at.w < 0.5) return vec4(0.0, -1e3, 0.0, 0.0);
	vec2 uv = (xz - P.fog_at.xy) / P.fog_at.z;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return vec4(0.0, -1e3, 0.0, 0.0);
	return textureLod(fog_map, uv, 0.0);
}

// The fog at `p`: (density 0..1, height share in its layer, depth to its
// top (m), the ground's y).
vec4 fog_at(vec3 p, vec4 f) {
	if (f.b < 0.01) return vec4(0.0, 0.0, 0.0, f.r);
	vec2 q = p.xz - P.fog_drift.xy;
	float tm = P.eye.w * FOG_MORPH;
	float a = textureLod(cauliflower, vec3(q.x / FOG_PATCH, tm, q.y / FOG_PATCH), 0.0).g;
	float b = textureLod(cauliflower, vec3(q.x / FOG_PATCH2 + 0.37, tm * 0.6 + 0.5, q.y / FOG_PATCH2), 0.0).g;
	float m = textureLod(cauliflower, vec3(q.x / FOG_PATCH3 + 0.71, tm * 1.7 + 0.21, q.y / FOG_PATCH3), 0.0).g;
	float patch_ = sstep(FOG_GATE.x, FOG_GATE.y, (0.5 * a + 0.35 * b + 0.15 * m - FOG_SUM.x) / FOG_SUM.y);
	float amount = f.b * patch_;
	amount *= sstep(0.04, 0.3, amount);
	if (amount < 0.01) return vec4(0.0, 0.0, 0.0, f.r);
	float depth = P.fog_knobs.y * mix(0.75, 1.3, f.a) * (0.35 + 0.65 * sqrt(amount));
	vec2 bl = textureLod(cauliflower, vec3(q.x, p.y * 1.6 + P.eye.w * 0.4, q.y) / FOG_BILLOW, 0.0).rg;
	float top = f.g + depth + (bl.r - 0.5) * 2.0 * FOG_BILLOW_H;
	if (p.y > top + 2.0) return vec4(0.0, 1.0, 0.0, f.r);
	// A thin layer's top as soft for its depth, so a shallow one never smears.
	float soft = min(FOG_TOP_SOFT, max(top - f.g, 6.0) * 0.6);
	float body = sstep(top + 2.0, top - soft, p.y);
	float ground = mix(P.spare[0].x, 1.0, sstep(FOG_GROUND.x, FOG_GROUND.y, p.y - f.r));
	float wisp = mix(0.3, 1.0, sstep(0.3, 0.68, bl.g));
	float hh = clamp((p.y - f.g) / max(top - f.g, 4.0), 0.0, 1.0);
	// Thicker low, thinning toward its top.
	float thin = 1.0 - P.spare[0].z * hh * hh;
	return vec4(amount * body * ground * wisp * thin, hh, max(top - p.y, 0.0), f.r);
}

// How much sun reaches `p` past the ridges (the fog map's ground along the
// light).
float fog_ridge_shade(vec3 p, vec3 key) {
	float clear = 1e3;
	for (int k = 0; k < 4; k++) {
		vec3 q = p + key * FOG_SHADE_AT[k];
		float g = fog_texel(q.xz).r;
		clear = min(clear, q.y - g);
	}
	return sstep(-8.0, 6.0, clear);
}

// --- The passes --------------------------------------------------------------------------

void weather_pass() {
	ivec2 texel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(out_weather);
	if (any(greaterThanEqual(texel, size))) return;
	vec2 xz = P.weather_at.xy + (vec2(texel) + 0.5) / vec2(size) * P.weather_at.z;
	imageStore(out_weather, texel, weather_texel(xz));
}

void ceiling_pass() {
	ivec2 block = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(out_ceiling);
	if (any(greaterThanEqual(block, size))) return;
	ivec2 texels = textureSize(weather, 0);
	float top = -1e3;
	float bottom = 1e4;
	for (int y = -CEILING_BLOCK; y < 2 * CEILING_BLOCK; y += 2) {
		for (int x = -CEILING_BLOCK; x < 2 * CEILING_BLOCK; x += 2) {
			ivec2 t = clamp(block * CEILING_BLOCK + ivec2(x, y), ivec2(0), texels - 1);
			vec4 w = texelFetch(weather, t, 0);
			// Only a layer with any body counts.
			if (w.x > w.y) {
				top = max(top, w.x);
				bottom = min(bottom, w.y);
			}
			if (w.z > w.w) {
				top = max(top, w.z);
				bottom = min(bottom, w.w);
			}
		}
	}
	imageStore(out_ceiling, block, vec4(top + 4.0, bottom - 12.0, 0.0, 0.0));
}

void shadow_pass() {
	ivec2 texel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(out_shadow);
	if (any(greaterThanEqual(texel, size))) return;
	vec3 key = normalize(P.key.xyz + vec3(0.0, 1e-4, 0.0));
	if (key.y < 0.03 || P.band.w <= 0.0) {
		imageStore(out_shadow, texel, vec4(1.0, 1.0, 0.0, 0.0));
		return;
	}
	vec2 xz = P.shade_sq.xy + (vec2(texel) + 0.5) / vec2(size) * P.shade_sq.z;
	vec3 p = vec3(xz.x, P.band.x, xz.y);
	float t_end = (P.band.y + OVER - p.y) / key.y;
	float thick = 0.0;
	float at_y = 0.0;
	float t = 4.0;
	float step = 8.0;
	for (int i = 0; i < 48; i++) {
		if (t > t_end) break;
		vec3 q = p + key * t;
		float gap = clear_ahead(q, key, max(length(key.xz), 1e-3));
		if (gap > 0.0) {
			t += max(gap, step);
			continue;
		}
		float d = density_cheap(q) * step;
		thick += d;
		at_y += d * q.y;
		t += step;
		step = min(step * 1.15, 50.0);
	}
	float keep = exp(-thick * SUN_SIGMA * 0.6);
	imageStore(out_shadow, texel, vec4(keep, 1.0, thick > 0.01 ? at_y / thick : P.band.x, 0.0));
}

void march_pass() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(out_a);
	if (any(greaterThanEqual(pixel, size))) return;
	ivec2 full_size = textureSize(scene_depth, 0);
	int scale = max(int(P.quality.z), 1);
	ivec2 full = scale > 1 ? min(pixel * 2 + zs_block_offset(int(P.frame.x)), full_size - 1) : min(pixel, full_size - 1);
	vec2 uv = (vec2(full) + 0.5) / vec2(full_size);
	vec3 view_dir = normalize(vec3((uv.x * 2.0 - 1.0) * P.lens.x, (1.0 - uv.y * 2.0) * P.lens.y, -1.0));
	vec3 rd = normalize(mat3(P.camera) * view_dir);
	vec3 ro = P.eye.xyz;

	float d = texelFetch(scene_depth, full, 0).r;
	float near = P.lens.z;
	float far = P.lens.w;
	float t_solid = 1e9;
	if (d > 0.0) {
		float z = near * far / (near + d * (far - near));
		t_solid = z / max(-view_dir.z, 1e-4);
	}
	imageStore(out_depth, pixel, vec4(t_solid));

	// The slab of cloud, out to the reach.
	float level = max(length(rd.xz), 1e-4);
	float t_in = 1e9;
	float t_out = 0.0;
	if (P.band.w > 0.0) {
		float top_y = P.band.y + OVER;
		float bottom = P.band.x - 1.0;
		float a, b;
		if (abs(rd.y) < 1e-4) {
			a = (ro.y < top_y && ro.y > bottom) ? 0.0 : 1e9;
			b = 1e9;
		} else {
			float ta = (top_y - ro.y) / rd.y;
			float tb = (bottom - ro.y) / rd.y;
			a = max(min(ta, tb), 0.0);
			b = max(ta, tb);
		}
		b = min(b, P.band.z / level);
		if (b > a) {
			t_in = a;
			t_out = b;
		}
	}
	t_out = min(t_out, t_solid);

	float frame_index = P.frame.x;
	vec2 jp = vec2(pixel) + vec2(5.588238, 5.588238) * mod(frame_index, 64.0);
	float jitter = fract(52.9829189 * fract(dot(jp, vec2(0.06711056, 0.00583715))));
	if (P.flash.x > 0.5) {
		// Interleaved gradient noise on the render's own pixel (the 2x2
		// block's turn included), stepped by the golden ratio each frame:
		// the frames' offsets spread evenly, so the resolve averages them
		// toward the true mean sooner than white-ish jitter does.
		float ign = fract(52.9829189 * fract(dot(vec2(full), vec2(0.06711056, 0.00583715))));
		jitter = fract(ign + 0.61803398875 * mod(frame_index, 64.0));
	}
	g_jitter = jitter;

	vec3 key = normalize(P.key.xyz + vec3(0.0, 1e-4, 0.0));
	float c = dot(rd, key);
	float ph[OCTAVES];
	for (int o = 0; o < OCTAVES; o++) ph[o] = phase(c, pow(MS_C, float(o)));
	float powder_share = POWDER * sstep(0.2, -0.6, c);

	// The valley fog over its own slab (the sea up to the highest top it
	// can reach), out to its reach and the solid ground.
	vec4 fog_a = vec4(0.0);
	float fog_T = 1.0;
	float fog_met = 0.0;
	float fog_crown = 0.0;
	if (P.fog_at.w > 0.5 && P.fog_knobs.x > 0.0) {
		float top_y = P.fog_knobs.w;
		float bottom = P.band.x;
		float fa = 0.0, fb = 0.0;
		if (abs(rd.y) < 1e-4) {
			fa = (ro.y < top_y && ro.y > bottom) ? 0.0 : 1e9;
			fb = 1e9;
		} else {
			float ta = (top_y - ro.y) / rd.y;
			float tb = (bottom - ro.y) / rd.y;
			fa = max(min(ta, tb), 0.0);
			fb = max(ta, tb);
		}
		fb = min(min(fb, P.fog_drift.z / level), t_solid);
		if (fb > fa) {
			int n = int(P.fog_knobs.z);
			float span = fb - fa;
			float sigma = FOG_SIGMA * P.fog_knobs.x * P.spare[0].y;
			float prev = fa;
			for (int i = 0; i < 96; i++) {
				if (i >= n || fog_T < 0.02) break;
				// Finer near the eye, coarser far (u^1.7 over the span).
				float u0 = float(i) / float(n);
				float u1 = float(i + 1) / float(n);
				float um = (float(i) + jitter) / float(n);
				float t0 = fa + span * pow(u0, 1.7);
				float t1 = fa + span * pow(u1, 1.7);
				float tf = fa + span * pow(um, 1.7);
				float dt = t1 - t0;
				vec3 p = ro + rd * tf;
				vec4 f = fog_texel(p.xz);
				vec4 fs = fog_at(p, f);
				float far = 1.0 - sstep(P.fog_drift.z - P.fog_drift.w, P.fog_drift.z, length(p.xz - ro.xz));
				float dens = fs.x * far * sstep(1.0, 12.0, tf);
				if (dens < 0.002) continue;
				float alpha = 1.0 - exp(-dens * sigma * dt);
				float shade = fog_ridge_shade(p, key);
				float tau = fs.z * FOG_SUN_SIGMA * P.fog_knobs.x * f.b / max(key.y, 0.25);
				float sun_light = 0.0;
				float weight = 1.0;
				float atten = 1.0;
				for (int o = 0; o < OCTAVES; o++) {
					sun_light += weight * exp(-tau * atten) * mix(1.0, ph[o], FOG_PHASE);
					weight *= MS_B;
					atten *= MS_A;
				}
				// In the ridges' shade the fog still glows a little (the sunlit
				// fog round it), so shaded fog reads pale, never as a grey wash.
				sun_light *= mix(0.3, 1.0, shade) * SUN_SCALE / (1.0 + MS_B + MS_B * MS_B);
				float ambient = FOG_SKY * mix(0.7, 1.0, fs.y);
				float bounce = FOG_BOUNCE * (1.0 - fs.y);
				float w = fog_T * alpha;
				// The fourth term is the fog's own share (the composite cools its shade).
				fog_a += w * vec4(ambient, sun_light, bounce, 1.0);
				fog_met += w * tf;
				fog_crown += w * mix(0.25, 0.7, fs.y);
				fog_T *= 1.0 - alpha;
			}
		}
	}

	// How deep in cloud the eye is: the fog round it glows.
	float immersed = 0.0;
	{
		Sample e = cloud_at(ro, 60.0, 0.0, false);
		if (e.density > 0.0) immersed = sstep(-4.0, 20.0, e.inside);
	}

	bool faced = false;
	float turned = 1.0;
	int steps = min(int(P.quality.x), STEPS_MAX);
	int taps_full = min(int(P.quality.y), TAPS_MAX);
	float T = 1.0;
	vec4 acc_a = vec4(0.0);
	float met = 0.0;
	float crown = 0.0;
	float glow = 0.0;
	float t = t_in;
	bool started = false;
	bool hit = false;
	int fine_left = 0;
	float t_first = 1e9;
	for (int i = 0; i < STEPS_MAX; i++) {
		if (t_out <= t_in || i >= steps || t >= t_out || T < 0.03) break;
		vec3 p = ro + rd * t;
		float gap = clear_ahead(p, rd, level);
		if (gap > 0.0) {
			t += clamp(gap, STEP.x, 900.0);
			started = false;
			continue;
		}
		float step = clamp(STEP.x + t * STEP_GROW, STEP.x, STEP.y);
		// Just past where the ray first met cloud, finer steps, so the
		// surface's place never shows the steps as contours.
		if (fine_left > 0) {
			step = max(step * 0.25, STEP.x);
			fine_left--;
		}
		if (!started) {
			started = true;
			t += step * jitter;
			if (t >= t_out) break;
			p = ro + rd * t;
		}
		Sample s = cloud_at(p, t, immersed, true);
		// Close to the eye the cloud thins away, so the eye never meets a
		// wall; in the cloud less so, but the plane ahead stays readable.
		s.density *= mix(sstep(NEAR_FADE.x, NEAR_FADE.y, t), 0.25 + 0.75 * sstep(4.0, 18.0, t), immersed);
		if (s.density > 0.002 && !hit) {
			hit = true;
			t_first = t;
			if (step > STEP.x * 2.0) {
				t -= step * 0.75;
				fine_left = 6;
				continue;
			}
		}
		if (s.density > 0.002) {
			float od = 0.0;
			// Far off, fewer taps over a longer cone, so a far cloud still
			// shades itself.
			int taps = T > 0.15 ? (t < 1500.0 ? taps_full : 4) : 2;
			// Each pixel's cone a little longer or shorter (the resolve
			// averages it), so the taps' steps never show as contours.
			float reach = mix(1.0, 2.6, sstep(700.0, 3000.0, t)) * (0.8 + 0.4 * fract(jitter + float(i) * 0.618));
			for (int k = 0; k < TAPS_MAX; k++) {
				if (k >= taps) break;
				od += density_cheap(p + key * TAP_AT[k] * reach) * TAP_LEN[k] * reach;
			}
			if (!faced) {
				faced = true;
				float e = mix(10.0, 28.0, sstep(60.0, 1500.0, t));
				float here = inside_cheap(p);
				vec3 grad = vec3(
					inside_cheap(p + vec3(e, 0.0, 0.0)) - inside_cheap(p - vec3(e, 0.0, 0.0)),
					inside_cheap(p + vec3(0.0, e, 0.0)) - inside_cheap(p - vec3(0.0, e, 0.0)),
					inside_cheap(p + vec3(0.0, 0.0, e)) - inside_cheap(p - vec3(0.0, 0.0, e)));
				turned = 0.5;
				if (here > -500.0 && dot(grad, grad) > 1e-6 && dot(grad, grad) < 4e5 * e * e) turned = sstep(-0.6, 0.9, dot(-normalize(grad), key));
			}
			od += (1.0 - turned) * FACE_SHADE;
			if (T > 0.1) {
				for (int k = 0; k < LONG_TAPS; k++) od += density_cheap(p + key * LONG_AT[k]) * LONG_LEN;
			}
			float tau = od * SUN_SIGMA;
			float sky_open = 1.0;
			if (T > 0.25) {
				float up = density_cheap(p + vec3(0.0, 14.0, 0.0)) * 14.0 + density_cheap(p + vec3(0.0, 40.0, 0.0)) * 28.0;
				sky_open = mix(CREASE, 1.0, exp(-up * UP_SIGMA * 2.0));
			}
			float sun_light = 0.0;
			float weight = 1.0;
			float atten = 1.0;
			for (int o = 0; o < OCTAVES; o++) {
				sun_light += weight * exp(-tau * atten) * ph[o];
				weight *= MS_B;
				atten *= MS_A;
			}
			sun_light *= SUN_SCALE / (1.0 + MS_B + MS_B * MS_B);
			float powder = 1.0 - exp(-max(s.inside, 0.0) / POWDER_DEPTH);
			sun_light *= mix(1.0, powder, powder_share);
			float deep = sstep(0.0, 50.0, s.inside);
			float beer = exp(-tau);
			float ambient = SKY * sky_open * mix(0.32, 1.0, s.h) * mix(1.0, DEEP, deep) * mix(1.0, 0.45, beer);
			float bounce = BOUNCE * pow(1.0 - s.h, 2.0);
			float alpha = 1.0 - exp(-s.density * s.sigma * step);
			float w = T * alpha;
			acc_a += w * (1.0 - immersed) * vec4(ambient, sun_light, bounce, 0.0);
			// The whiteout mottled by the wisps streaming past.
			glow += w * immersed * (0.75 + 0.3 * beer) * (0.75 + 0.5 * s.pocket);
			met += w * t;
			crown += w * s.h;
			T *= 1.0 - alpha;
			t += step;
		} else {
			// Clear air in the slab: on as far as the map says is clear.
			// The organic field's lumpy domes: also the sample's own distance
			// to the surface (damped), so rays skimming the domes' billow
			// margin don't crawl and spend the steps before far cloud.
			float leap = g_new ? max(s.free, -s.inside * 0.6) : s.free;
			t += clamp(leap, step, 600.0);
			s.free = leap;
			// After a leap the next step jittered afresh, so where the steps
			// fall on the cloud never shows as contours.
			if (s.free > step) started = false;
		}
	}
	// The fog and the cloud, the nearer over the farther (they seldom share
	// a ray's stretch: the fog lies under the low cloud's bases).
	if (fog_T < 1.0) {
		float fog_mean = fog_met / max(1.0 - fog_T, 1e-4);
		if (t_first < fog_mean) {
			acc_a += T * fog_a;
			met += T * fog_met;
			crown += T * fog_crown;
		} else {
			acc_a = fog_a + fog_T * acc_a;
			met = fog_met + fog_T * met;
			crown = fog_crown + fog_T * crown;
			glow *= fog_T;
		}
		T *= fog_T;
	}
	float cover = 1.0 - T;
	imageStore(out_a, pixel, acc_a);
	imageStore(out_b, pixel, vec4(cover, met, crown, glow));
}

void main() {
	g_new = P.flash.y > 0.5;
	if (PASS.mode == MODE_WEATHER) weather_pass();
	else if (PASS.mode == MODE_CEILING) ceiling_pass();
	else if (PASS.mode == MODE_SHADOW) shadow_pass();
	else march_pass();
}
