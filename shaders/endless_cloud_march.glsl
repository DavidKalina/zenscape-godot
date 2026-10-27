#[versions]

play = "";
cost = "#define COST_VIEW";

#[compute]
#version 450

VERSION_DEFINES

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
	vec4 spare[24];     // 68..163; spare[0] the valley fog's look: floor share, density scale, top thinning, -; spare[3..5] the storm front (shaders/storm_cloud.glslinc); spare[20].x the shade pass stepped as before (--cloud-shade=old); spare[21] the high layer's samples off the low layer's within a texel (the map read xz, a slice's xz); spare[22] the drift since the weather map was drawn (low xz, high xz), spare[23] a weather slice's square
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
// The shade pass's heights apart (m; shadow_pass).
const float SHADE_PLANE = 10.0;
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
// The field's offset this weather pass (clouds of the low layer and the high
// layer drift at their own speeds, the cloud life's shear) and which layer it
// is drawing.
vec2 g_drift = vec2(0.0);
// The storm's push at the sample cloud_at is reading (0 with no storm), for
// layer_inside's underside.
float g_storm = 0.0;

bool g_high = false;
// How far the high layer's samples stand from the low layer's in the map
// this weather pass draws (spare[21] xy the map read, zw a slice's;
// scripts/cloud_volume_effect.gd LAYER_PHASE).
vec2 g_phase = vec2(0.0);

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

// The storm front's push on the field (P.spare[3], P.spare[4]; off unless
// --storm).
#include "storm_cloud.glslinc"

float cluster_gate(vec2 f) {
	uint salt = uint(P.drift.z);
	float n = 0.65 * value_noise(f / CLUSTER, salt + 17u) + 0.35 * value_noise(f / (CLUSTER * 0.43), salt + 19u);
	return sstep(CLUSTER_GATE.x, CLUSTER_GATE.y, n);
}

// --- Cloud life (P.spare[1].x = 1; --cloud-life=0 is the rigid field) ---------------
// Each cell keeps its own clock: a cycle of PERIOD seconds (by the cell's own
// pace) in which its cloud grows from a thin wisp, stands, and thins away to
// nothing, and the next cycle's cloud (a fresh hash of the cell, so another
// shape and place) forms from nothing, so nothing pops. Mirrored in
// endless_clouds.gd (`_cell_life`).
const float LIFE_COVER = 1.6;
float cell_life(ivec2 c, bool big, out uint cyc) {
	cyc = 0u;
	if (P.spare[1].x < 0.5) return 1.0;
	uint base = uint(P.drift.z) + (big ? 101u : 211u);
	vec3 lh = hash3(c, base + 31u);
	float period = P.spare[1].y * mix(0.6, 1.5, lh.x) * (big ? 1.0 : 0.6);
	float ph = P.spare[2].x / period + lh.y;
	float f = floor(ph);
	cyc = uint(max(f, 0.0));
	float u = ph - f;
	return sstep(0.0, 0.4, u) * (1.0 - sstep(0.55, 1.0, u));
}

struct Cloud {
	uint salt;
	float life;
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
	float storm;
};

// The cloud of cell `c` before it is lifted over the ground (false: none):
// its kind, footprint and form.
bool recipe_shape(ivec2 c, bool big, float cover, out Cloud k) {
	float cell = big ? BIG : SMALL;
	uint cyc;
	k.life = cell_life(c, big, cyc);
	uint salt = uint(P.drift.z) + (big ? 101u : 211u) + cyc * 977u;
	k.salt = salt;
	bool lifed = P.spare[1].x > 0.5;
	vec3 h = hash3(c, salt);
	k.middle = (vec2(c) + 0.5 + JIT * (h.xy * 2.0 - 1.0)) * cell;
	// The storm's push here (storm_cloud.glslinc), at the cloud's place now
	// (the low layer's drift for both layers, so a cloud's push never hangs
	// on its kind). Pushed, a broad cloud lives on whole and always stands.
	// Its kind reads the place alone (storm_place): it never changes as the
	// storm builds.
	k.storm = big ? storm_push(k.middle + P.drift.xy) : 0.0;
	float kp = big ? storm_place(k.middle + P.drift.xy) : 0.0;
	k.life = mix(k.life, 1.0, k.storm);
	if (lifed && k.life < 0.01) return false;
	// A small puff where the storm pushes thins away (SP_SMALL_GO of the
	// push): it is never pushed, so under the storm it lay low on the land
	// and water, its fine lobes off, lit as the storm's low cloud: a smooth
	// near-black lens (and the khaki lid's sunlit puffs behind the core).
	if (!big && storm_on()) {
		k.life *= 1.0 - sstep(SP_SMALL_GO.x, SP_SMALL_GO.y, storm_push(k.middle + P.drift.xy));
		if (k.life < 0.01) return false;
	}
	float gate = cluster_gate(k.middle);
	if (!big) gate = mix(0.02, 1.0, gate * gate);
	float field_here = region_cover(k.middle) * cover * (big ? BIG_COVER2 : SMALL_COVER2) * gate * (lifed ? LIFE_COVER : 1.0);
	float here = mix(field_here, 1.0, k.storm);
	if (h.z >= here) return false;
	// A cell only the storm stands up comes in from a wisp as it builds.
	if (h.z >= field_here) k.life *= sstep(0.0, SP_ADMIT, here - h.z);
	if (k.life < 0.01) return false;
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
	// Pushed, most broad cells heap into towers, the rest into mid cloud.
	bool towers = kp > 0.0 && fract(s.y * 13.7 + s.x) < kp * SP_TOWERS;
	bool mids = kp > 0.25 && !towers;
	if (!big) {
		k.kind = KIND_PUFF;
		k.low = true;
		k.base = mix(SMALL_BASE.x, SMALL_BASE.y, s.y);
		nr = vec2(2.0, 5.0); k.L = 0.45; k.W = 0.35; k.main_r = 0.65; k.br = vec2(0.4, 0.62); k.hs = vec2(0.7, 1.1);
		tall = vec2(0.6, 1.25); belly = vec2(0.35, 0.55); qb = vec2(0.5, 0.85);
	} else if (s.y < FAIR_SHARE && !towers && !mids) {
		k.kind = KIND_FAIR;
		k.low = true;
		k.base = mix(LOW_BASE.x, LOW_BASE.y, s.z);
		nr = vec2(3.0, 6.0); k.L = 0.55; k.W = 0.38; k.main_r = 0.62; k.br = vec2(0.35, 0.6); k.hs = vec2(0.7, 1.1);
		tall = vec2(0.55, 1.0); belly = vec2(0.3, 0.5); qb = vec2(0.45, 0.8);
	} else if (towers || (s.y < FAIR_SHARE + TOWER_SHARE2 && !mids)) {
		k.kind = KIND_TOWER;
		k.base = mix(TOWER_BASE.x, TOWER_BASE.y, s.z);
		nr = vec2(5.0, 9.0); k.L = 0.5; k.W = 0.45; k.main_r = 0.6; k.br = vec2(0.4, 0.6); k.hs = vec2(0.6, 1.0);
		tall = vec2(1.0, 1.5); belly = vec2(0.25, 0.4); qb = vec2(0.45, 0.7);
		k.profile = 0.4;
		k.r *= 1.2;
	} else if (s.y < FAIR_SHARE + TOWER_SHARE2 + ROW_SHARE && !mids) {
		k.kind = KIND_ROW;
		k.low = t3 < 0.4;
		k.base = k.low ? mix(LOW_BASE.x, LOW_BASE.y + 30.0, s.z) : mix(MID_BASE.x, MID_BASE.y, s.z);
		nr = vec2(6.0, 9.0); k.L = 1.15; k.W = 0.18; k.main_r = 0.5; k.br = vec2(0.36, 0.55); k.hs = vec2(0.8, 1.15);
		tall = vec2(0.55, 0.95); belly = vec2(0.32, 0.5); qb = vec2(0.5, 0.8);
	} else if (s.y < FAIR_SHARE + TOWER_SHARE2 + ROW_SHARE + WISP_SHARE && !mids) {
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
	// Pushed: wider, taller, more domes, a deeper belly, a lower base.
	float st = k.storm;
	k.r *= mix(1.0, SP_GROW.x, st);
	k.n = min(k.n + int(st * SP_DOMES + 0.5), 9);
	k.base = mix(k.base, min(k.base, mix(SP_BASE.x, SP_BASE.y, s.z)), st);
	// Past the core, where the deck lets go, it rides up to the deck's back
	// (SP_TRAIL_BASE): whole by a third of the push, so only a cell the
	// push has all but let go of comes back down to its own base.
	if (st > 0.0) {
		float d_s = dot(k.middle + P.drift.xy - P.spare[3].xy, P.spare[3].zw);
		float back = sstep(-P.spare[4].y + SE_OUT.x, -P.spare[4].y + SE_OUT.y, d_s);
		k.base = mix(k.base, max(k.base, mix(SP_TRAIL_BASE.x, SP_TRAIL_BASE.y, s.z)), sstep(0.0, 0.3, st) * back);
	}
	k.r = min(k.r, mix(EXT_MAX, SP_EXT, st) * cell / k.ext);
	k.tall = mix(tall.x, tall.y, t2) * DOME * mix(1.0, SP_GROW.y, st);
	k.belly = mix(belly.x, belly.y, fract(m.y * 5.13 + s.x)) * mix(1.0, SP_BELLY, st);
	k.qb = mix(qb.x, qb.y, fract(m.z * 3.71 + h.x));
	return true;
}

// Cloud `k` (of cell `c`) lifted whole over the ground, so the belly keeps
// its round (the map's clamp under it would cut it level); a lifted cloud a
// little higher again, its own, so lifted neighbours never share a base.
// Over the meadows a low one thins.
void recipe_lift(inout Cloud k, ivec2 c, bool big) {
	uint salt = k.salt;
	vec3 h = hash3(c, salt);
	vec3 s = hash3(c, salt + 1u);
	vec2 fl = cloud_floor(k.middle + g_drift, k.r * k.ext, k.low);
	if (fl.x > k.base) k.base = fl.x + 30.0 * fract(s.y * 13.7 + h.x);
	if (k.low) k.tall *= mix(1.0, 0.6, fl.y);
	k.H = min(k.r * k.main_r * k.tall, TOP_MAX + SP_TOP * k.storm - k.base);
}

// The cloud as its own life has it now: grown from a wisp (thin and a little
// narrower) to its full size, and back. The base stays where the lift put it.
void apply_life(inout Cloud k) {
	float lr = mix(0.7, 1.0, k.life);
	k.r *= lr;
	k.tall *= k.life;
	k.H *= lr * k.life;
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

float yields(Cloud k, ivec2 c, bool big, float cover) {
	float press = 0.0;
	float reach = k.r * k.ext;
	for (int pass = 0; pass < 2; pass++) {
		bool other_big = pass == 0;
		// A broad cloud never yields to a puff.
		if (big && !other_big) continue;
		float cell = other_big ? BIG : SMALL;
		ivec2 g = ivec2(floor(k.middle / cell));
		float most = reach + (other_big && storm_on() ? SP_EXT : EXT_MAX) * cell;
		for (int y = -2; y <= 2; y++) {
			for (int x = -2; x <= 2; x++) {
				ivec2 n = g + ivec2(x, y);
				if (other_big == big && n == c) continue;
				// Cheap first: a cell's middle alone can rule it out.
				uint ncyc;
				cell_life(n, other_big, ncyc);
				uint salt = uint(P.drift.z) + (other_big ? 101u : 211u) + ncyc * 977u;
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
				// A neighbour still forming or thinning away presses less: the
				// cloud under it gives way as it grows, never in one step.
				if (me) press = max(press, sstep(0.05, 0.4, o.life));
				if (press >= 0.999) return press;
			}
		}
	}
	return press;
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
	ivec2 g = ivec2(floor(f / cell));
	// A storm's pushed clouds reach up to SP_EXT cells: look two round.
	int look = big && storm_on() ? 2 : 1;
	for (int y = -look; y <= look; y++) {
		for (int x = -look; x <= look; x++) {
			ivec2 c = g + ivec2(x, y);
			Cloud k;
			if (!recipe_shape(c, big, cover, k)) continue;
			bool lifed = P.spare[1].x > 0.5;
			if (lifed && k.low == g_high) continue;
			recipe_lift(k, c, big);
			float d = length(f - k.middle);
			float top_c = -1e4;
			float base_c = 1e4;
			float out_c = d - k.ext * k.r;
			// Whether a puff or a wisp yields is asked over its reach and a
			// margin round it, where its rim's height could still be the
			// nearest rim a texel keeps and so bend a neighbour's smoothed edge
			// (farther off it only gives the leap a shorter, safe distance).
			if (out_c < YIELD_NEAR && P.flash.z > 0.5 && (!big || k.kind == KIND_WISP)) {
				float press = yields(k, c, big, cover);
				if (press >= 0.999) continue;
				k.life *= 1.0 - press;
			}
			// (A cell the storm stands up grows in by its life even with
			// the field's life off.)
			if (lifed || k.storm > 0.0 || (!big && storm_on())) {
				if (k.life < 0.01) continue;
				apply_life(k);
				out_c = d - k.ext * k.r;
			}
			// Past the rims the map keeps the nearest rim's height as the
			// base (the cloud's lowest point there would drag the smoothed
			// base down at the rim into hanging strands).
			float rim_c = k.base + k.H * 0.4;
			if (out_c <= 0.0) {
				out_c = 1e9;
				for (int i = 0; i < 9; i++) {
					if (i >= k.n) break;
					vec3 b = bubble_span(k, c, k.salt, i, f);
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
	g_drift = P.drift.xy;
	g_high = false;
	vec2 f = xz - g_drift;
	vec2 low = vec2(sea - 300.0, sea);
	vec2 high = vec2(sea - 300.0, sea);
	float low_gap = 1e9;
	float high_gap = 1e9;
	float cover = P.drift.w;
	if (g_new) {
		lattice_new(f, true, sea, cover, low, low_gap, high, high_gap);
		lattice_new(f, false, sea, cover, low, low_gap, high, high_gap);
		if (P.spare[1].x > 0.5) {
			// The high layer on its own, faster wind.
			g_high = true;
			g_drift = P.spare[1].zw;
			f = xz + g_phase - g_drift;
			lattice_new(f, true, sea, cover, low, low_gap, high, high_gap);
			lattice_new(f, false, sea, cover, low, low_gap, high, high_gap);
		}
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

vec4 weather_layers(vec2 xz) {
	vec2 uv = (xz - P.weather_at.xy) / P.weather_at.z;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return vec4(-1e3, 0.0, -1e3, 0.0);
	return textureLod(weather, uv, 0.0);
}

// The map drawn a slice a frame (scripts/cloud_volume_effect.gd
// weather_slices) is one moment, up to two cycles old: each layer is read
// where its cloud stood then, spare[22] (low xz, high xz) the drift since,
// the high layer's samples spare[21].xy off the low layer's.
vec4 weather_map(vec2 xz) {
	vec4 since = P.spare[22];
	vec4 w = weather_layers(xz - since.xy);
	vec2 high = since.zw + P.spare[21].xy;
	if (high != since.xy) w.zw = weather_layers(xz - high).zw;
	return w;
}

// The map smoothed over two texels (four bilinear taps half a texel
// about): its texels' creases, sharp down a steep flank, never show as
// flutes in the cloud's form or its light.
vec4 weather_smooth(vec2 xz) {
	float h = 0.5 * P.weather_at.z / P.weather_at.w;
	return 0.25 * (weather_map(xz + vec2(h, h)) + weather_map(xz + vec2(-h, h)) + weather_map(xz + vec2(h, -h)) + weather_map(xz + vec2(-h, -h)));
}

// The same, and the map's slope over one texel from its four taps (free):
// how steep each layer's top is right here (low in .x, high in .z), so a
// pushed cloud's tall wall, which drops across a texel or two, reads its
// real steepness and its heaps carve it as deep as they carve its crown.
vec4 weather_smooth_s(vec2 xz, out vec2 local) {
	float h = 0.5 * P.weather_at.z / P.weather_at.w;
	vec4 a = weather_map(xz + vec2(h, h));
	vec4 b = weather_map(xz + vec2(-h, h));
	vec4 c = weather_map(xz + vec2(h, -h));
	vec4 d = weather_map(xz + vec2(-h, -h));
	vec4 gx = ((a + c) - (b + d)) / (4.0 * h);
	vec4 gz = ((a + b) - (c + d)) / (4.0 * h);
	local = vec2(length(vec2(gx.x, gz.x)), length(vec2(gx.z, gz.z)));
	return 0.25 * (a + b + c + d);
}

// The highest top and lowest base round `xz`.
vec2 ceiling_at(vec2 xz) {
	vec2 uv = (xz - P.weather_at.xy) / P.weather_at.z;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return vec2(-1e3, 1e4);
	return textureLod(ceiling, uv, 0.0).rg;
}

// The underside's lump where it binds in the last layer_inside (0..1, 1 in
// a recess; 0 where the top or sides bind): storm_cave reads it.
float g_lump = 0.0;

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
		// A storm's pushed cloud hangs in deeper lumps (mammatus).
		float under = clamp(thick * 0.28, 2.0, 40.0 + SP_UNDER * g_storm) * lump;
		float below = (p.y - base - under) / sqrt(1.0 + slope_b * slope_b) * 1.2 + 1.0;
		g_lump = below < inside ? lump : 0.0;
		return min(inside, below);
	}
	g_lump = 0.0;
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
	float cave;
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

// The cost view's counters (P.spare[5].w, --cloud-cost-view=N; march_pass):
// the towers' reads (bake and their noise) and the field's evaluations.
int g_c_st = 0;
int g_c_f = 0;
// Off in play (they cost registers and stores in the hot paths, ~.25 ms
// with the storm's towers): only the "cost" version counts.
#ifdef COST_VIEW
#define COST(x) x
#else
#define COST(x)
#endif

Sample field_at(vec3 p, float t, float immersed, bool fine) {
	Sample s = Sample(0.0, SIGMA, -1e3, 0.0, 0.5, 0.0, 0.0);
	if (P.band.w <= 0.0 || p.y < P.band.x - 1.0 || p.y > P.band.y + OVER) return s;
	COST(g_c_f += 4);
	vec2 local;
	vec4 w = weather_smooth_s(p.xz, local);
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
	float push = storm_push(p.xz);
	vec2 at = p.xz;
	vec4 wx = weather_map(at + vec2(span, 0.0)) - weather_map(at - vec2(span, 0.0));
	vec4 wz = weather_map(at + vec2(0.0, span)) - weather_map(at - vec2(0.0, span));
	vec2 slope = vec2(length(vec2(wx.x, wz.x)), length(vec2(wx.z, wz.z))) / (2.0 * span);
	// A pushed cloud's tall flanks read at their own steepness right here
	// (the map's slope over one texel, up to SP_SLOPE_MAX): held to the wide
	// span's, its wall's inside rose 10-30 m a metre across, so the heaps
	// (and the light taps, which see the same) moved it only a few metres
	// and the face stood as one smooth sheet.
	float slope_max = mix(SLOPE_MAX, SP_SLOPE_MAX, push);
	slope = min(mix(slope, max(slope, local), push), vec2(slope_max));
	vec2 slope_b = min(vec2(length(vec2(wx.y, wz.y)), length(vec2(wx.w, wz.w))) / (2.0 * span), vec2(slope_max));
	vec3 boil = BOIL * P.eye.w;
	float fine_w = (fine && P.quality.w > 0.5) ? 1.0 - sstep(FINE_NEAR * 0.6, FINE_NEAR, t) : 0.0;
	// The storm's near knots (storm_cloud.glslinc).
	float near_w = fine ? 1.0 - sstep(SC_NEAR_AT.x, SC_NEAR_AT.y, t) : 0.0;
	float hh_l = 0.0, hh_h = 0.0;
	float in_l = -1e3, in_h = -1e3;
	float wisp = 0.5;
	float sw = 0.0;
	float cave_l = 0.0, cave_h = 0.0;
	if (low_on) {
		vec2 n = textureLod(cauliflower, (p + boil) / TILE_LOW, 0.0).rg;
		float nm = textureLod(cauliflower, (p + boil * 1.3 + 37.0) / MID, 0.0).r;
		float nf = fine_w > 0.0 ? fine_w * FINE_SWELL * (textureLod(cauliflower, (p + boil * 1.6 + 71.0) / FINE, 0.0).r - 0.5) : 0.0;
		// A small puff is only a few of the map's texels across, under the
		// lobes' and swells' scales, so it drew as a smooth bell with a flat
		// base: thin low cloud takes its lobes and swells from finer noise
		// (P.flash.w; --cloud-puffs=old: off).
		// The storm's push here (shaders/storm_cloud.glslinc).
		sw = storm_push(p.xz);
		g_storm = sw;
		float small_l = (1.0 - sstep(PUFF_THIN.x, PUFF_THIN.y, w.x - w.y)) * P.flash.w * (1.0 - sw);
		if (small_l > 0.0) {
			n.r = mix(n.r, textureLod(cauliflower, (p + boil + 11.0) / PUFF_TILE, 0.0).r, small_l);
			nm = mix(nm, textureLod(cauliflower, (p + boil * 1.3 + 53.0) / (PUFF_TILE * 0.45), 0.0).r, small_l);
		}
		in_l = layer_inside(p, w.x, w.y, slope.x, slope_b.x, n.r, n.g, nm, nf, hh_l);
		// The storm's big heaps carved into its towers (storm_cloud.glslinc).
		if (sw > 0.0) {
			float lump = g_lump;
			float c = storm_carve(p, boil, w.x - w.y, hh_l, near_w);
			in_l += sw * c;
			cave_l = sw * storm_cave(c, g_carve_near, lump);
		}
		wisp = n.g;
	}
	if (high_on) {
		vec2 n = textureLod(cauliflower, (p + boil * 1.4 + 113.0) / TILE_HIGH, 0.0).rg;
		float nm = textureLod(cauliflower, (p + boil * 1.3 + 59.0) / (MID * 1.6), 0.0).r;
		float nf = fine_w > 0.0 ? fine_w * FINE_SWELL * (textureLod(cauliflower, (p + boil * 1.6 + 23.0) / FINE, 0.0).r - 0.5) : 0.0;
		in_h = layer_inside(p, w.z, w.w, slope.y, slope_b.y, n.r, n.g, nm * 1.6 - 0.3, nf, hh_h);
		// The storm's towers stand in the high layer: their heaps too.
		float sh = storm_push(p.xz);
		if (sh > 0.0) {
			float lump = g_lump;
			float c = storm_carve(p, boil, w.z - w.w, hh_h, near_w);
			in_h += sh * c;
			cave_h = sh * storm_cave(c, g_carve_near, lump);
		}
		if (in_h > in_l) wisp = n.g;
	}
	float inside = max(in_l, in_h);
	float hh = in_h > in_l ? hh_h : hh_l;
	// The deck's height share by the world's height, not its column's.
	if (sw > 0.0 && in_l >= in_h) hh = mix(hh, storm_height(p.y), sw * 0.5);
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
		s.cave = in_h > in_l ? cave_h : cave_l;
		s.density = d;
		s.h = hh;
		s.pocket = wisp;
		s.sigma = mix(SIGMA, SIGMA_IN, immersed);
	}
	return s;
}

// The light taps' form: the density, one noise octave; on a pushed cloud
// its broad heaps too (storm_carve_cheap), so the shade and the sky's
// light fall into the heaps' pockets.
float field_density_cheap(vec3 p) {
	if (p.y < P.band.x - 1.0 || p.y > P.band.y + OVER) return 0.0;
	COST(g_c_f += 1);
	vec2 local;
	vec4 w = weather_smooth_s(p.xz, local);
	bool low_on = p.y > w.y - 6.0 && p.y < w.x + OVER;
	bool high_on = p.y > w.w - 6.0 && p.y < w.z + OVER;
	if (!low_on && !high_on) return 0.0;
	vec2 n = textureLod(cauliflower, (p + BOIL * P.eye.w) / TILE_HIGH, 0.0).rg;
	float sw = storm_push(p.xz);
	g_storm = sw;
	// A pushed cloud's wall at its own steepness, as cloud_at reads it.
	vec2 sl = mix(vec2(0.6), clamp(local, vec2(0.6), vec2(SP_SLOPE_MAX)), sw);
	float hh;
	float inside = -1e3;
	if (low_on) {
		inside = layer_inside(p, w.x, w.y, sl.x, 0.6, n.r, n.g, 0.45, 0.0, hh);
		if (sw > 0.0) inside += sw * storm_carve_cheap(p, w.x - w.y, hh);
	}
	if (high_on) {
		float ih = layer_inside(p, w.z, w.w, sl.y, 0.6, n.r, n.g, 0.45, 0.0, hh);
		if (sw > 0.0) ih += sw * storm_carve_cheap(p, w.z - w.w, hh);
		inside = max(inside, ih);
	}
	return sstep(-4.0, 12.0, inside);
}

// The coarse form's distance into the cloud, for the face a ray first meets
// (a pushed cloud's with its heaps, the fine octave too).
float field_inside_cheap(vec3 p) {
	COST(g_c_f += 2);
	vec2 local;
	vec4 w = weather_smooth_s(p.xz, local);
	vec2 n = textureLod(cauliflower, (p + BOIL * P.eye.w) / TILE_LOW, 0.0).rg;
	float sw = storm_push(p.xz);
	g_storm = sw;
	vec2 sl = mix(vec2(0.6), clamp(local, vec2(0.6), vec2(SP_SLOPE_MAX)), sw);
	float hh_l, hh_h;
	float il = layer_inside(p, w.x, w.y, sl.x, 0.6, n.r, n.g, 0.45, 0.0, hh_l);
	float ih = layer_inside(p, w.z, w.w, sl.y, 0.6, n.r, n.g, 0.45, 0.0, hh_h);
	if (sw > 0.0) {
		il += sw * storm_carve_face(p, w.x - w.y, hh_l);
		ih += sw * storm_carve_face(p, w.z - w.w, hh_h);
	}
	return max(il, ih);
}


// --- The storm's cumulonimbus (scripts/endless/storm_towers.gd) -------------------
// A few baked towers (scripts/sky_tower.gd's lobes, baked to a float 3D
// distance texture, two stages red and green, morphed) scaled up into the
// world, in the front's core: their smooth body is read here, the storm's
// own heaps carved in (storm_carve) and lit as the pushed cells are, so
// they are the same weather. spare[5].y how many; each tower i at
// spare[6+4i]: frame origin xyz (world), scale up; [7+4i] box middle
// (frame), morph; [8+4i] box half (frame), shown (0..1, its fade in);
// [9+4i] its foot and top (world y), scale across (at least the scale up,
// so the frame's distance times the scale up stays a lower bound).
const int ST_MAX = 3;
// Under the foot (the bake's box cut) the body thins out over this (m).
const float ST_FOOT = 60.0;
// The base's lumps (m deep, tile; only up into it, as the pushed cells'
// mammatus) and where the last st_inside's base bound, how deep in a lump
// (0..1, for storm_cave).
const float ST_UNDER = 150.0;
const vec3 ST_UNDER_TILE = vec3(520.0, 300.0, 520.0);
float g_st_lump = 0.0;

// Past the march's reach (or out of the slab) the field is off and only the
// towers draw (march_pass sets it per ray).
float g_field_out = 1e9;
// Whether the last cloud_at's sample was a tower's.
bool g_st = false;
// The towers' fine octave's share at this sample's range (march_pass): it
// fades past ST_FINE_AT, where its 150 m lumps would alias into fur.
float g_st_fine = 1.0;
// The heaps' carve at the march's tower sample, but the broad lobe's (m):
// the light taps take the tower's lobed body shifted in by it
// (st_inside_cheap).
float g_st_c = 0.0;
const vec2 ST_FINE_AT = vec2(2500.0, 5000.0);
// The last cloud_at's clear way to every tower's body (m, a lower bound)
// and the field's own inside there (m); and what the march knows before
// it: a clear way already read this step (st_gap; below 0 none).
float g_st_free = 1e9;
float g_f_inside = -1e3;
float g_st_known = -1.0;
float g_st_known_ray = -1.0;
// The ray's direction (march_pass), and the last st_inside's or st_gap's
// clear way to every tower's body along it (m): under a tower's flat base
// the ray leaps straight to it, where the body's distance is 0 (the
// lobes reach down into the cut).
vec3 g_rd = vec3(0.0, 1.0, 0.0);
float g_st_ray = 1e9;
// Whether the light taps (density_cheap) and the face (inside_cheap) look
// at the towers and at the field: the march turns them off where the
// sample stands farther from one than they reach.
bool g_taps_st = true;
bool g_face_st = true;
bool g_face_f = true;
// One broader octave than the storm's own (m deep, tile), the towers' only:
// it breaks the coarse bake into km-wide cauliflower.
const float ST_LOBE = 220.0;
const vec3 ST_LOBE_TILE = vec3(1900.0, 1500.0, 1900.0);
// The carve's share past which a sample counts as in a crease (storm_cave
// sees the storm's own octaves; the broad lobe adds this much of its own).
const float ST_LOBE_CAVE = 0.35;
// The share of the light taps' depth a tower's sample keeps (the march's
// light loop; spare[5].z overrides it, --storm-tower-taps=X).
const float ST_TAPS = 0.35;

// A tower's heaps at `p` (m, never more than 0): the broad lobe, the storm's
// own octaves (storm_carve_broad, _fine) and, `near` > 0, its near knots;
// `cave` how deep in a crease (storm_cave).
float st_lobe(vec3 p, float hh) {
	COST(g_c_st += 1);
	vec3 q = p + BOIL * P.eye.w * 0.5;
	float lobe = textureLod(cauliflower, (q + SC_CHURN_BIG * P.spare[5].x * 0.6) / ST_LOBE_TILE + 0.13, 0.0).r;
	return ST_LOBE * mix(0.5, 1.0, hh) * (sstep(0.3, 0.75, lobe) - 1.0);
}

float st_carve(vec3 p, float thick, float hh, float near, out float cave, out float lobe_c) {
	vec3 q = p + BOIL * P.eye.w * 0.5;
	float ch = P.spare[5].x;
	float cl = st_lobe(p, hh);
	lobe_c = cl;
	float c = storm_carve_broad(q, ch, thick, hh) + g_st_fine * storm_carve_fine(q, ch, thick);
	COST(g_c_st += 3);
	g_carve_near = 0.0;
	if (near > 0.0) {
		COST(g_c_st += 1);
		float n = textureLod(cauliflower, (q + SC_CHURN_NEAR * ch) / vec3(SC_NEAR_TILE, SC_NEAR_TILE * 0.8, SC_NEAR_TILE) + 0.47, 0.0).r;
		g_carve_near = near * SC_NEAR * (sstep(0.28, 0.72, n) - 1.0);
		c += g_carve_near;
	}
	cave = storm_cave(c + cl * ST_LOBE_CAVE, g_carve_near, g_st_lump);
	return c + cl;
}

int st_count() {
	return P.band.w > 0.0 ? int(P.spare[5].y + 0.5) : 0;
}

float st_read(int i, vec3 uvw) {
	COST(g_c_st += 1);
	vec2 rg = i == 0 ? textureLod(body0, uvw, 0.0).rg : (i == 1 ? textureLod(body1, uvw, 0.0).rg : textureLod(body2, uvw, 0.0).rg);
	return mix(rg.r, rg.g, P.spare[7 + i * 4].w);
}

// How far `p` stands clear of every tower's body (m, a lower bound): to its
// box, or in the box the bake's distance (one read), so the field's leaps
// by the ceiling map still run through the towers' wide boxes.
// (g_st_ray the same along the ray; under a base, no read.)
float st_gap(vec3 p) {
	float g = 1e9;
	g_st_ray = 1e9;
	int n = st_count();
	for (int i = 0; i < ST_MAX; i++) {
		if (i >= n) break;
		vec4 a = P.spare[6 + i * 4];
		vec4 c = P.spare[8 + i * 4];
		if (c.w <= 0.0) continue;
		vec3 sc = vec3(P.spare[9 + i * 4].z, a.w, P.spare[9 + i * 4].z);
		vec3 q = (p - a.xyz) / sc - P.spare[7 + i * 4].xyz;
		float out_by = length(max(abs(q) - c.xyz, 0.0) * sc);
		float ray = out_by;
		if (out_by <= 0.0) {
			float base = p.y - P.spare[9 + i * 4].x - ST_FOOT * 0.3;
			if (base < 0.0) {
				out_by = -base;
				ray = g_rd.y > 1e-3 ? -base / g_rd.y : 1e9;
			} else {
				out_by = max(st_read(i, (q + c.xyz) / (2.0 * c.xyz)) * a.w * 0.85, 0.0);
				ray = out_by;
			}
		}
		g = min(g, out_by);
		g_st_ray = min(g_st_ray, ray);
	}
	return g;
}

// How far into the nearest tower's smooth body `p` is (m; below 0 out of
// it), before its heaps; `hh` its height in that tower (0 foot, 1 top),
// `thick` the tower's height, `free` a lower bound on the clear way to any.
float st_inside(vec3 p, out float hh, out float thick, out float free) {
	float best = -1e4;
	hh = 0.0;
	thick = 0.0;
	free = 1e9;
	g_st_ray = 1e9;
	g_st_lump = 0.0;
	// The lumps are the same noise under every tower: read once.
	float lumps = -1.0;
	int n = st_count();
	for (int i = 0; i < ST_MAX; i++) {
		if (i >= n) break;
		vec4 a = P.spare[6 + i * 4];
		vec4 b = P.spare[7 + i * 4];
		vec4 c = P.spare[8 + i * 4];
		vec4 f = P.spare[9 + i * 4];
		if (c.w <= 0.0) continue;
		vec3 sc = vec3(f.z, a.w, f.z);
		vec3 q = (p - a.xyz) / sc - b.xyz;
		float out_by = length(max(abs(q) - c.xyz, 0.0) * sc);
		float ins;
		// The foot: the box's floor cut, thinned up into a flat base hung
		// with lumps (they only lift it: under it, nothing to read).
		float under = p.y - f.x - ST_FOOT * 0.3;
		if (out_by > 0.0) {
			ins = -out_by - 20.0;
			free = min(free, out_by);
			g_st_ray = min(g_st_ray, out_by);
		} else if (under < 0.0) {
			ins = under * 0.8;
			free = min(free, -under);
			g_st_ray = min(g_st_ray, g_rd.y > 1e-3 ? -under / g_rd.y : 1e9);
		} else {
			float dist = st_read(i, (q + c.xyz) / (2.0 * c.xyz)) * a.w + (1.0 - c.w) * 300.0;
			float lump = 0.0;
			// (Lumps only lower the base: read them only where it binds.)
			if (under < ST_UNDER + 60.0 && under * 0.8 < -dist) {
				if (lumps < 0.0) {
					COST(g_c_st += 1);
					vec3 q2 = p + BOIL * P.eye.w * 0.5 + SC_CHURN_MID * P.spare[5].x * 0.4;
					vec2 n = textureLod(cauliflower, q2 / ST_UNDER_TILE + 0.37, 0.0).rg;
					lumps = clamp(0.5 + (0.45 - n.r) * 1.6 + (0.5 - n.g) * 0.8, 0.0, 1.0);
				}
				lump = lumps;
				under -= ST_UNDER * lump;
			}
			ins = min(-dist, under * 0.8);
			if (ins > best) g_st_lump = under * 0.8 < -dist ? lump : 0.0;
			free = min(free, max(dist * 0.85, 0.0));
			g_st_ray = min(g_st_ray, max(dist * 0.85, 0.0));
		}
		if (ins > best) {
			best = ins;
			thick = f.y - f.x;
			hh = clamp((p.y - f.x) / max(thick, 1.0), 0.0, 1.0);
		}
	}
	return best;
}

// The cloud at `p`: the field's (field_at) and the storm's towers'.
bool g_no_field = false;
Sample cloud_at_core(vec3 p, float t, float immersed, bool fine) {
	bool field = !g_no_field && t <= g_field_out && p.y >= P.band.x - 1.0 && p.y <= P.band.y + OVER;
	Sample s = field ? field_at(p, t, immersed, fine) : Sample(0.0, SIGMA, -1e3, 0.0, 0.5, 1e9, 0.0);
	g_st = false;
	g_st_c = 0.0;
	g_f_inside = s.inside;
	g_st_free = 1e9;
	if (st_count() == 0) return s;
	// The march's st_gap this step already says every tower is out of
	// reach: none can bind here.
	if (g_st_known_ray > 30.0) {
		g_st_free = g_st_known;
		s.free = min(s.free, g_st_known_ray);
		return s;
	}
	float hh, thick, free;
	float ins = st_inside(p, hh, thick, free);
	g_st_free = free;
	s.free = min(s.free, g_st_ray);
	float cave = 0.0;
	float own = 0.0;
	if (ins > 0.0) {
		float near_w = fine ? 1.0 - sstep(SC_NEAR_AT.x, SC_NEAR_AT.y, t) : 0.0;
		float cl;
		float c = st_carve(p, thick, hh, near_w, cave, cl);
		ins += c;
		own = c - cl;
	}
	s.inside = max(s.inside, ins);
	if (ins <= 0.0) return s;
	float soft = mix(SOFT.y, SOFT.x, hh) * mix(0.5, 1.0, sstep(40.0, 300.0, t));
	float d = sstep(0.0, soft, ins);
	if (d > s.density) {
		g_st = true;
		g_st_c = own;
		s.density = d;
		s.h = hh;
		s.cave = cave;
		s.pocket = 0.5;
		s.sigma = mix(SIGMA, SIGMA_IN, immersed);
	}
	return s;
}

// The envelope's (storm_env_cloud) where the storm has closed in: g_env
// when it binds (lit flat, no taps), g_env_band when the sample lies in its
// band at all (the march steps it at its own pace), g_env_e the envelope.
bool g_env = false;
bool g_env_band = false;
float g_env_e = 0.0;

// The cloud at `p`: the field's and the towers' (cloud_at_core), and the
// storm's envelope round the plane.
Sample cloud_at(vec3 p, float t, float immersed, bool fine) {
	g_env = false;
	g_env_band = false;
	g_env_e = 0.0;
	float e = storm_env_on() && t <= g_field_out ? storm_envelope(p.xz) : 0.0;
	float fl = 0.0;
	if (e > 0.0) {
		fl = storm_env_floor(p.xz);
		g_env_band = p.y <= storm_deck_base(e, fl) + SE_THICK && p.y >= fl;
	}
	// In its band under every base the field's map holds, the field can't
	// bind: only the towers are asked.
	g_no_field = false;
	vec2 cl = vec2(-1e3, 1e4);
	if (g_env_band) {
		cl = ceiling_at(p.xz);
		g_no_field = p.y < cl.y - 8.0;
	}
	Sample s = cloud_at_core(p, t, immersed, fine);
	if (g_no_field) {
		s.inside = min(s.inside, -(cl.y - p.y));
		g_f_inside = min(g_f_inside, -(cl.y - p.y));
	}
	g_no_field = false;
	g_env_e = e;
	if (!g_env_band) return s;
	float dens, hh, cave;
	float ins = storm_env_cloud(p, e, fl, t, dens, hh, cave);
	// In its deck the deck wins over a tower or cell it holds (a tower's
	// lumps in its band are lit by their depth under its top, paler than
	// the deck round them); its scud only where denser.
	if (dens > s.density || (dens > 0.002 && g_env_scud < 0.5)) {
		g_env = true;
		g_st = false;
		s.density = dens;
		s.inside = max(s.inside, ins);
		s.h = hh;
		s.cave = cave;
		s.pocket = 0.5;
		s.sigma = SE_SIGMA / max(SIGMA, 1e-4) * mix(SIGMA, SIGMA_IN, immersed);
	}
	return s;
}

// The towers' body for the face (`face`: the heaps as the march carves
// them, st_carve, but the near knots) and for the light taps (the lobed
// body, st_lobe, shifted in by the march's sample's own carve of the
// finer octaves, g_st_c: as if those heaps lay flat round it, so a lit
// heap's taps start on its surface; their creases shade by storm_cave).
float st_inside_cheap(vec3 p, bool face) {
	float hh, thick, free, cave, cl;
	float ins = st_inside(p, hh, thick, free);
	if (ins > -4.0) ins += face ? st_carve(p, thick, hh, 0.0, cave, cl) : st_lobe(p, hh) + g_st_c;
	return ins;
}

float density_cheap(vec3 p) {
	float d = field_density_cheap(p);
	if (st_count() == 0 || !g_taps_st) return d;
	return max(d, sstep(-4.0, 12.0, st_inside_cheap(p, false)));
}

float inside_cheap(vec3 p) {
	float i = !g_face_f || p.y > P.band.y + OVER + 200.0 ? -1e3 : field_inside_cheap(p);
	if (st_count() == 0 || !g_face_st) return i;
	return max(i, st_inside_cheap(p, true));
}

// How far a ray may leap from `p` before it can meet cloud (0: step here).
float clear_ahead(vec3 p, vec3 rd, float level) {
	vec2 c = ceiling_at(p.xz);
	float block = P.weather_at.z / P.weather_at.w * CEILING_BLOCK_F;
	float across = block * 0.9 / level;
	float over = p.y - (c.x + OVER);
	float gap = 0.0;
	if (over > 0.0) gap = min(rd.y < 0.0 ? over / -rd.y : 1e9, across);
	else {
		float under = (c.y - 8.0) - p.y;
		if (under > 0.0) gap = min(rd.y > 0.0 ? under / rd.y : 1e9, across);
	}
	// The storm's envelope (storm_env_cloud) is in no map: wherever it may
	// lie within the leap, no leap into its band.
	if (gap > 0.0 && storm_env_on()) {
		float env_top = storm_env_top() + 20.0;
		if (p.y < env_top) {
			// Up to where it may begin across the land.
			float r = storm_env_reach(p.xz);
			if (r < 20.0) return 0.0;
			gap = min(gap, (r - 10.0) / level);
		} else if (rd.y < 0.0) gap = min(gap, (p.y - env_top) / -rd.y);
	}
	return gap;
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
	// A slice (PASS.pad0 1): rows from PASS.pad1, round the square in
	// spare[23] (scripts/cloud_volume_effect.gd weather_slices).
	vec4 square = P.weather_at;
	g_phase = P.spare[21].xy;
	if (PASS.pad0 == 1) {
		texel.y += PASS.pad1;
		square = P.spare[23];
		g_phase = P.spare[21].zw;
	}
	if (any(greaterThanEqual(texel, size))) return;
	vec2 xz = square.xy + (vec2(texel) + 0.5) / vec2(size) * square.z;
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
	float thick = 0.0;
	float at_y = 0.0;
	// Up the light's line through the slab, one sample at each of a fixed
	// stack of heights SHADE_PLANE m apart, the ones the ceiling says no
	// cloud reaches skipped. Each sample slides smoothly as the light turns
	// and the eye moves, and a skipped one moves no other: stepped along the
	// line with leaps, a leap's length (from the ceiling, and whether a step
	// fell just over a block's top) moved every sample after it, so a small
	// puff's one or two samples jumped and its shade on the land flickered.
	// spare[20].x 1 (--cloud-shade=old): the stepped march, as before.
	if (P.spare[20].x > 0.5) {
		float t_end = (P.band.y + OVER - p.y) / key.y;
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
	} else {
		float run = SHADE_PLANE / key.y;
		vec2 across = key.xz / key.y;
		int planes = int(ceil((P.band.y + OVER - P.band.x) / SHADE_PLANE));
		for (int i = 0; i < planes; i++) {
			float y = P.band.x + (float(i) + 0.5) * SHADE_PLANE;
			vec3 q = vec3(p.xz + across * (y - p.y), y).xzy;
			vec2 c = ceiling_at(q.xz);
			if (y > c.x + OVER || y < c.y - 8.0) continue;
			float d = density_cheap(q) * run;
			thick += d;
			at_y += d * y;
		}
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

	g_rd = rd;
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
	// The field's reach; the storm's towers drawn past it (st_*).
	g_field_out = t_out;
	int stn = st_count();
	for (int i = 0; i < ST_MAX; i++) {
		if (i >= stn) break;
		vec4 sa = P.spare[6 + i * 4];
		vec4 sc = P.spare[8 + i * 4];
		if (sc.w <= 0.0) continue;
		vec3 sxyz = vec3(P.spare[9 + i * 4].z, sa.w, P.spare[9 + i * 4].z);
		vec3 mid = sa.xyz + sxyz * P.spare[7 + i * 4].xyz;
		vec3 half_box = sxyz * sc.xyz;
		vec3 inv = 1.0 / (rd + vec3(1e-6));
		vec3 t0 = (mid - half_box - ro) * inv;
		vec3 t1 = (mid + half_box - ro) * inv;
		vec3 lo = min(t0, t1);
		vec3 hi = max(t0, t1);
		float ba = max(max(lo.x, lo.y), max(lo.z, 0.0));
		float bb = min(min(hi.x, hi.y), hi.z);
		if (bb > ba) {
			t_in = min(t_in, ba);
			t_out = max(t_out, bb);
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
		// (Not in a scud fragment: it is faded round the eye, and the eye
		// in one turned the whole view to the fog's glow, the cells and the
		// towers' bases pale flat puffs under the dark deck.)
		if (e.density > 0.0 && !(g_env && g_env_scud > 0.5)) immersed = sstep(-4.0, 20.0, e.inside);
	}
	// Under the storm's envelope the cloud round the eye is its gloom, lit
	// as the deck lights the cloud under it (dark grey), never the fair
	// day's white glow: that share of the immersion keeps the cloud's own
	// light and gives none to the glow.
	float glow_share = immersed;
	if (immersed > 0.0 && storm_env_on()) glow_share *= 1.0 - sstep(0.0, 0.5, storm_envelope(ro.xz));

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
	float fine_k = 0.25;
	float t_first = 1e9;
	int c_iters = 0;
	int c_lit = 0;
	int c_face = 0;
	int c_tap0 = 0;
	int c_samp = 0;
	int c_pre = 0;
	float c_hit_st = 0.0;
	for (int i = 0; i < STEPS_MAX; i++) {
		if (t_out <= t_in || i >= steps || t >= t_out || T < 0.03) break;
		COST(c_iters++);
		vec3 p = ro + rd * t;
		float gap = t <= g_field_out ? clear_ahead(p, rd, level) : 1e9;
		g_st_known = -1.0;
		g_st_known_ray = -1.0;
		if (stn > 0 && gap > 0.0) {
			// Near a tower a short leap would only creep: step as usual.
			g_st_known = st_gap(p);
			float sg = g_st_ray;
			g_st_known_ray = sg;
			gap = min(gap, sg < clamp(STEP.x + t * STEP_GROW, STEP.x, STEP.y) * 2.0 ? 0.0 : sg);
		}
		if (gap > 0.0) {
			t += clamp(gap, STEP.x, 900.0);
			started = false;
			continue;
		}
		float step = clamp(STEP.x + t * STEP_GROW, STEP.x, STEP.y);
		// Just past where the ray first met cloud, finer steps, so the
		// surface's place never shows the steps as contours.
		if (fine_left > 0) {
			step = max(step * fine_k, STEP.x);
			fine_left--;
		}
		if (!started) {
			started = true;
			t += step * jitter;
			if (t >= t_out) break;
			p = ro + rd * t;
			g_st_known -= step * jitter;
			g_st_known_ray -= step * jitter;
		}
		g_st_fine = 1.0 - sstep(ST_FINE_AT.x, ST_FINE_AT.y, t);
		COST(int cs0 = g_c_st);
		Sample s = cloud_at(p, t, immersed, true);
		COST(c_samp += g_c_st - cs0);
		// In the envelope's band, clear of the field's cloud and the
		// towers, its own pace: its scud and murk are soft and kilometres
		// wide, so the steps stretch with the distance.
		float step_s = step;
		if (g_env_band && g_f_inside < -40.0 && g_st_free > 80.0) step_s = max(step, clamp(6.0 + 0.025 * t, 6.0, 70.0));
		// Close to the eye the cloud thins away, so the eye never meets a
		// wall; in the cloud less so, but the plane ahead stays readable.
		s.density *= mix(sstep(NEAR_FADE.x, NEAR_FADE.y, t), 0.25 + 0.75 * sstep(4.0, 18.0, t), immersed);
		if (s.density > 0.002 && !hit) {
			hit = true;
			t_first = t;
			COST(c_pre = c_iters);
			COST(c_hit_st = g_st ? 1.0 : 0.3);
			if (step > STEP.x * 2.0 && !g_env) {
				t -= step * 0.75;
				// (A tower's soft km-wide face: half as many, twice as long:
				// the same stretch, ~.15 ms less ahead.)
				fine_left = g_st ? 3 : 6;
				fine_k = g_st ? 0.5 : 0.25;
				continue;
			}
		}
		if (s.density > 0.002 && g_env) {
			// The envelope's deck and scud: flat and dark under the storm,
			// no taps (the deck's lumps shade by their creases).
			COST(c_lit++);
			bool scud = g_env_scud > 0.5;
			float sky_e = SE_SKY.y;
			if (!scud) {
				// Its form: the side light on its flanks (only where the
				// sample shows: a ray's first deck samples).
				vec2 lean = T > 0.3 ? storm_deck_lean() : vec2(0.35, 0.15);
				sky_e = storm_deck_light(g_env_depth, (1.0 - SE_CREASE * s.cave) * (SE_RIM.x + SE_RIM.y * lean.x + SE_RIM.z * lean.y));
			}
			// The sun's share in the deck by the same fall-off: a flat share
			// laid over the sky's form swamped it (a flat grey looking up).
			float sun_e = scud ? SE_SUN.y : SE_SUN.x * SE_SUN_FORM * sky_e / SE_DECK_MAX;
			float alpha = 1.0 - exp(-s.density * s.sigma * step_s);
			float w = T * alpha;
			acc_a += w * (1.0 - glow_share) * vec4(SKY * sky_e, sun_e * SUN_SCALE, 0.0, 0.0);
			glow += w * glow_share * 0.3;
			met += w * t;
			crown += w * s.h * 0.3;
			T *= 1.0 - alpha;
			t += step_s;
			continue;
		}
		if (s.density > 0.002) {
			COST(c_lit++);
			float od = 0.0;
			// Far off, fewer taps over a longer cone, so a far cloud still
			// shades itself.
			int taps = T > 0.15 ? (t < 1500.0 ? taps_full : 4) : 2;
			// Each pixel's cone a little longer or shorter (the resolve
			// averages it), so the taps' steps never show as contours.
			float reach = mix(1.0, 2.6, sstep(700.0, 3000.0, t)) * (0.8 + 0.4 * fract(jitter + float(i) * 0.618));
			// The towers stand farther off than any tap reaches: the taps
			// (and the sky's) leave them out.
			bool long_taps = T > 0.1 && !g_st;
			bool st_near = g_st_free < max(TAP_AT[taps - 1] * reach, long_taps ? LONG_AT[LONG_TAPS - 1] : 40.0) + 8.0;
			// A cell's taps see the towers' shade in two (one up its cone,
			// one up the long taps' reach), not in each: a tower's own
			// taps see its heaps in each.
			g_taps_st = st_near && g_st;
			if (st_near && !g_st) {
				od += sstep(-4.0, 12.0, st_inside_cheap(p + key * TAP_AT[4] * reach, false)) * (TAP_LEN[3] + TAP_LEN[4] + TAP_LEN[5]) * reach;
				if (long_taps) od += sstep(-4.0, 12.0, st_inside_cheap(p + key * LONG_AT[1], false)) * LONG_LEN * float(LONG_TAPS);
			}
			COST(int c0 = g_c_st);
			for (int k = 0; k < TAPS_MAX; k++) {
				if (k >= taps) break;
				od += density_cheap(p + key * TAP_AT[k] * reach) * TAP_LEN[k] * reach;
			}
			COST(c_tap0 += g_c_st - c0);
			if (!faced) {
				COST(c0 = g_c_st);
				faced = true;
				float e = mix(10.0, 28.0, sstep(60.0, 1500.0, t));
				// The face looks only at what can bind within its reach: a
				// tower's face past the field (or well clear of its cloud)
				// leaves the field out, a cell's well clear of every tower
				// the towers.
				g_face_st = g_st_free < e * 2.0 + 30.0;
				g_face_f = !g_st || (t <= g_field_out && g_f_inside > -(e * 3.0 + 40.0));
				float here;
				vec3 grad;
				if (g_st) {
					// A tower's face: four taps on a tetrahedron (the
					// gradient twice central differences', so halved).
					const vec3 K0 = vec3(1.0, -1.0, -1.0);
					const vec3 K1 = vec3(-1.0, -1.0, 1.0);
					const vec3 K2 = vec3(-1.0, 1.0, -1.0);
					const vec3 K3 = vec3(1.0, 1.0, 1.0);
					float f0 = inside_cheap(p + K0 * e);
					float f1 = inside_cheap(p + K1 * e);
					float f2 = inside_cheap(p + K2 * e);
					float f3 = inside_cheap(p + K3 * e);
					here = (f0 + f1 + f2 + f3) * 0.25;
					grad = (K0 * f0 + K1 * f1 + K2 * f2 + K3 * f3) * 0.5;
				} else {
					here = inside_cheap(p);
					grad = vec3(
						inside_cheap(p + vec3(e, 0.0, 0.0)) - inside_cheap(p - vec3(e, 0.0, 0.0)),
						inside_cheap(p + vec3(0.0, e, 0.0)) - inside_cheap(p - vec3(0.0, e, 0.0)),
						inside_cheap(p + vec3(0.0, 0.0, e)) - inside_cheap(p - vec3(0.0, 0.0, e)));
				}
				g_face_st = true;
				g_face_f = true;
				COST(c_face += g_c_st - c0);
				turned = 0.5;
				if (here > -500.0 && dot(grad, grad) > 1e-6 && dot(grad, grad) < 4e5 * e * e) turned = sstep(-0.6, 0.9, dot(-normalize(grad), key));
			}
			od += (1.0 - turned) * FACE_SHADE;
			// (Not on a tower: under the core its base's long taps cost
			// ~4 ms, and ST_TAPS stands for its own scattering.)
			if (long_taps) {
				for (int k = 0; k < LONG_TAPS; k++) od += density_cheap(p + key * LONG_AT[k]) * LONG_LEN;
			}
			// A tower's light: its taps see a wall kilometres deep behind
			// every lit heap, where a cell's see daylight through its
			// far side; the light it scatters through itself keeps its
			// lit faces white (ST_TAPS of the taps' depth).
			if (g_st) od *= P.spare[5].z > 0.0 ? P.spare[5].z : ST_TAPS;
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
			// A pushed cloud dark low down (shaders/storm_cloud.glslinc).
			float sw = storm_push(p.xz);
			sun_light *= mix(1.0, storm_sun(p.y), sw);
			// ...and in its heaps' creases (storm_cave).
			sun_light *= 1.0 - SC_CAVE_SUN * s.cave;
			// In or under the envelope's deck, in its shade: lit as the deck
			// is (a tower's base, a cell under it).
			float env_shade = 0.0;
			// (Past the field's reach the march asks no envelope, but a
			// tower's base there stands under the deck all the same.)
			float e_l = t <= g_field_out ? g_env_e : storm_envelope(p.xz);
			float db = P.band.x + mix(SE_DECK.y, SE_DECK.x, e_l);
			if (e_l > 0.0) {
				env_shade = sstep(0.0, 0.5, e_l) * sstep(db + SE_THICK, db + SE_THICK * 0.3, p.y);
			}
			// Past the deck's back, where the push lets go, a pushed cell
			// stands in the storm's trail: shaded as the deck is, fading
			// with the push, so the deck's back runs on into its cells' dark
			// heaps, never a sunlit khaki lid over a strip of sky.
			if (sw > 0.0 && storm_env_on()) {
				float d_s = dot(p.xz - P.spare[3].xy, P.spare[3].zw);
				float trail = SE_TRAIL * sstep(0.0, SE_TRAIL_PUSH, sw) * sstep(-P.spare[4].y * 0.5, -P.spare[4].y + SE_OUT.x, d_s) * (1.0 - e_l);
				env_shade = max(env_shade, trail * sstep(P.band.x + SE_TRAIL_TOP.y, P.band.x + SE_TRAIL_TOP.x, p.y));
			}
			if (env_shade > 0.0) sun_light = mix(sun_light, SE_SUN.x * SUN_SCALE, env_shade);
			float powder = 1.0 - exp(-max(s.inside, 0.0) / POWDER_DEPTH);
			sun_light *= mix(1.0, powder, powder_share);
			float deep = sstep(0.0, 50.0, s.inside);
			float beer = exp(-tau);
			float ambient = SKY * sky_open * mix(0.32, 1.0, s.h) * mix(1.0, DEEP, deep) * mix(1.0, 0.45, beer);
			ambient *= mix(1.0, storm_sky(p.y), sw) * (1.0 - SC_CAVE_SKY * s.cave);
			ambient = mix(ambient, SKY * storm_deck_light(max(db + SE_THICK - p.y, 0.0), 1.0 - 0.5 * s.cave), env_shade);
			float bounce = BOUNCE * pow(1.0 - s.h, 2.0) * mix(1.0, 0.3, sw) * (1.0 - env_shade);
			float alpha = 1.0 - exp(-s.density * s.sigma * step);
			float w = T * alpha;
			acc_a += w * (1.0 - glow_share) * vec4(ambient, sun_light, bounce, 0.0);
			// The whiteout mottled by the wisps streaming past.
			glow += w * glow_share * (0.75 + 0.3 * beer) * (0.75 + 0.5 * s.pocket);
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
			if (g_env_band) leap = min(leap, step_s);
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
	// The storm's murk (storm_cloud.glslinc SE_MURK): the rain-grey air
	// under the envelope, in chunks along the ray, laid before and behind
	// the cloud by its mean distance.
	if (storm_env_on() && P.spare[18].y > 0.0) {
		float cover_c = 1.0 - T;
		float t_c = cover_c > 0.003 ? met / cover_c : 1e9;
		float top_y = P.band.x + SE_MURK_TOP.y;
		float ma = 0.0;
		float mb = min(t_solid, SE_MURK_REACH);
		if (rd.y > 1e-4) mb = min(mb, max((top_y - ro.y) / rd.y, 0.0));
		if (ro.y > top_y) ma = rd.y < -1e-4 ? (top_y - ro.y) / rd.y : mb;
		if (mb > ma) {
			vec4 mf = vec4(0.0);
			vec4 mk = vec4(0.0);
			float tf = 1.0;
			float tk = 1.0;
			float metf = 0.0;
			float metk = 0.0;
			float span = mb - ma;
			float prev = ma;
			for (int i = 1; i <= SE_MURK_CHUNKS; i++) {
				float u = float(i) / float(SE_MURK_CHUNKS);
				float b = ma + span * u * u;
				for (int h = 0; h < 2; h++) {
					float a0 = h == 0 ? prev : max(prev, t_c);
					float b0 = h == 0 ? min(b, t_c) : b;
					if (b0 <= a0) continue;
					float tm = 0.5 * (a0 + b0);
					vec3 pm = ro + rd * tm;
					float e_m = storm_envelope(pm.xz);
					if (e_m <= 0.0) continue;
					vec2 mm = storm_murk_at(pm, e_m);
					vec4 L = vec4(SKY * mix(SE_MURK_SKY.x, SE_MURK_SKY.y, mm.y), SE_MURK_SUN * SUN_SCALE, 0.0, 0.0);
					float alpha = 1.0 - exp(-mm.x * SE_MURK * P.spare[18].y * (b0 - a0));
					if (h == 0) {
						mf += tf * alpha * L;
						metf += tf * alpha * tm;
						tf *= 1.0 - alpha;
					} else {
						mk += tk * alpha * L;
						metk += tk * alpha * tm;
						tk *= 1.0 - alpha;
					}
				}
				prev = b;
			}
			acc_a = mf + tf * (acc_a + T * mk);
			met = metf + tf * (met + T * metk);
			crown *= tf;
			glow *= tf;
			T = tf * T * tk;
		}
	}
	float cover = 1.0 - T;
	// The cost view: grey by what this pixel cost (1 the loop's turns of
	// 160, 2 the towers' reads of 400, 3 the field's of 600, 4 lit samples
	// of 40).
	float cv = P.spare[5].w;
#ifdef COST_VIEW
	if (cv > 0.0) {
		int m = int(cv);
		float v = float(c_iters) / 160.0;
		if (m == 2) v = float(g_c_st) / 400.0;
		else if (m == 3) v = float(g_c_f) / 600.0;
		else if (m == 4) v = float(c_lit) / 40.0;
		else if (m == 5) v = uv.x;
		else if (m == 6) v = float(c_tap0) / 400.0;
		else if (m == 7) v = float(c_face) / 400.0;
		else if (m == 8) v = float(c_samp) / 400.0;
		else if (m == 9) v = float(hit ? c_pre : c_iters) / 160.0;
		else if (m == 10) v = min(t_first, 8000.0) / 8000.0;
		else if (m == 11) v = c_hit_st;
		imageStore(out_a, pixel, vec4(0.0, v * fract(cv) * 10.0, 0.0, 0.0));
		imageStore(out_b, pixel, vec4(1.0, 50.0, 0.5, 0.0));
		return;
	}
#endif
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
