#[compute]
#version 450
// The unified cloud volume's passes (scripts/cloud_volume.gd,
// scripts/cloud_volume_effect.gd), one shader run four times a frame, each
// pass picked by the push constant's mode:
//
//   0 WEATHER: the weather map round the eye. Each texel says how the cloud
//     stands over that bit of the sea: its crown's height and its base's
//     over the sea's feet, its density, and how steeply its crown slopes
//     there. The heaps are a field of round cumulus, each its own cloud of
//     its own size (two lattices: broad heaps and small ones between),
//     standing where the sea's baked heap-field has mass (scripts/sky_sea.gd
//     `_bake`, red), risen and closed up under the islands and round the
//     ranges' feet (`_bake_swells`), parted under a falling glide, and
//     swollen round each tower's foot, so a tower stands out of a billowing
//     mound of its own sea. Weather to come (coverage, anvils, a raised base
//     for a deck of stratocumulus) writes here: `weather_texel`.
//   1 CEILING: the highest crown in each 160 m block of the map and its
//     neighbours, so the march leaps the clear air over the heaps.
//   2 SHADOW: how much of the light each spot of the map keeps, looking up
//     from the sea's feet toward the sun through the heaps and the towers:
//     the islands and ranges read it (shaders/cloud_volume_shadow
//     .gdshaderinc) for the cloud's shade on the land.
//   3 MARCH: one ray per quarter-res pixel (one pixel of each 2x2 block a
//     frame, in turn; every pixel on Ultra), stopped by the scene's depth.
//
// The light is not coloured here. Each march pixel stores how much of each
// light term reached it (premultiplied by the cloud's coverage), and the
// composite (shaders/cloud_volume_composite.gdshader) colours them with the
// sky's own palettes, so the art stays in Godot's shader language:
// A = (sky light, sunlight, light off the sea below, tower share),
// B = (coverage, distance, height in the cloud, glow: in-cloud and lightning).
// C holds the solid's distance at the pixel, for the depth-aware upsample.
//
// Sunlight per sample: a cone of taps toward the light (the sun, the moon at
// night) through the same cloud gives the optical depth, so heaps shade
// their neighbours and towers shade the sea; then three octaves of
// scattering (Wrenninge), each attenuated less, weighted less and with a
// flatter phase than the last, stand in for light scattered many times: a
// narrow forward lobe makes the silver lining where the sun comes through
// thin cloud, the deep core of a backlit tower stays dim. Powder darkens
// thin edges seen with the sun behind the eye, so lobes read round.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(push_constant, std430) uniform Pass {
	int mode;
	int pad0;
	int pad1;
	int pad2;
} PASS;

layout(set = 0, binding = 0, std430) restrict readonly buffer Params {
	mat4 camera;        // world from view (basis, origin)
	vec4 lens;          // tan half fov x, tan half fov y, near, far
	vec4 eye;           // xyz, motion time
	vec4 sun;           // xyz the sun, w dull weather (zs_cloud.x)
	vec4 key;           // xyz the light on the cloud (sun, moon at night), w the glide's parting (zs_sea_flight.w)
	vec4 sea;           // floor y, tall, reach, sea strength
	vec4 sea2;          // eye xz, hand over share, has noise
	vec4 envelope_at;   // corner xy (drifting field), side, baked
	vec4 swells_at;     // corner xy (world), side, baked
	vec4 frame;         // frame index, towers, wakes, deep night (night under a clear sky)
	vec4 islands[8];    // x, z, reach, underside y
	vec4 tower_a[4];    // frame origin xyz (world), strength
	vec4 tower_b[4];    // box middle xyz (tower frame), morph
	vec4 tower_c[4];    // box half xyz, wane
	vec4 tower_d[4];    // noise shift xyz, lift
	vec4 tower_e[4];    // sea y, top y (tower frame), 0, 0
	vec4 weather_at;    // corner xz (world), side (m), texels a side
	vec4 quality;       // march steps, light taps, march scale (1 or 2), fine octaves on
	vec4 flash;         // lightning: xyz, strength (zs_flash)
	vec4 shadow_at;     // the split height (m) between the shade from on high and the heaps', shadow texels a side, weather redrawn, shade redrawn
	vec4 wake_at[32];   // xyz, time laid
	vec4 wake_way[32];  // back to the previous point xyz, radius
} P;

layout(set = 0, binding = 1) uniform sampler2D envelope;
layout(set = 0, binding = 2) uniform sampler2D swells;
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

// --- The sea's heaps -------------------------------------------------------------
const vec2 DRIFT = vec2(0.6, 0.35) * 1.2;
// The broad heaps' lattice (m), their radii (share of a cell) and how tall
// for how wide; the small heaps' the same.
const float BROAD = 170.0;
const vec2 BROAD_R = vec2(0.40, 0.62);
const float BROAD_TALL = 0.78;
const float SMALL = 68.0;
const vec2 SMALL_R = vec2(0.36, 0.56);
const float SMALL_TALL = 0.85;
// A low floor of cloud between the heaps where the field has mass (m).
const float FLOOR_LAYER = 9.0;
// No crown higher than this over the sea's feet (m): under the glide's
// cushion (scripts/sky_glide.gd FLOOR) with room to spare.
const float CROWN_MAX = 92.0;
// How far the heaps rise under an island and round a range's foot (m).
const float LIFT_RISE = 26.0;
// A tower's foot: how far round it its mound reaches (m), and how tall.
const float SKIRT_REACH = 170.0;
const float SKIRT_TALL = 64.0;
// The ceiling's blocks: this many weather texels a side.
const int CEILING_BLOCK = 32;
const float TILE = 280.0;
const float LOBE = 30.0;
const float MID = 95.0;
const float MID_SWELL = 9.0;
const float WISP = 3.0;
const float FINE = 34.0;
const float FINE_SWELL = 4.0;
const float FINE_NEAR = 300.0;
const vec2 SOFT = vec2(1.5, 3.5);
const vec3 BOIL = vec3(0.72, -0.4, 0.42);
const float SEA_SIGMA = 0.16;
// The most a heap's surface may stand above its crown height once billowed.
const float OVER = LOBE * 0.6 + WISP * 0.5 + MID_SWELL * 0.6 + FINE_SWELL * 0.6 + 2.0;
const vec2 NEAR_FADE = vec2(6.0, 45.0);

// --- The towers (as shaders/sky_tower.gdshader) ------------------------------------
const float T_TILE = 170.0;
const float T_SWELL = 44.0;
const float T_FINE = 46.0;
const float T_FINE_SWELL = 10.0;
const float T_FINEST = 15.0;
const float T_FINEST_SWELL = 1.8;
const float T_FINE_NEAR = 240.0;
const vec2 T_SOFT = vec2(2.5, 8.0);
const vec3 T_DRIFT = vec3(0.9, -0.7, 0.5);
const float ERODE = 30.0;
const float T_SIGMA = 0.1;
const float T_SIGMA_IN = 0.045;
const float T_REACH = T_SWELL * 0.6 + T_FINE_SWELL * 0.5 + 9.0;

// --- The march --------------------------------------------------------------------
const int STEPS_MAX = 160;
const vec2 STEP = vec2(2.0, 18.0);
const float STEP_GROW = 0.014;
// The light's cone: tap distances (m) toward it and their lengths.
const int TAPS_MAX = 6;
const float TAP_AT[6] = float[](3.0, 9.0, 21.0, 45.0, 90.0, 170.0);
const float TAP_LEN[6] = float[](6.0, 8.0, 16.0, 32.0, 60.0, 100.0);
// How strongly cloud toward the light shades (per metre of full density).
const float SUN_SIGMA = 0.034;
// The scattering octaves (Wrenninge): each next one attenuated by A, weighted
// by B, its phase's eccentricity scaled by C.
const int OCTAVES = 3;
const float MS_A = 0.45;
const float MS_B = 0.55;
const float MS_C = 0.5;
// The phase: a narrow forward lobe (the lining), a broad back one, their
// mix, and the most the forward lobe may lift a sample (so the sun's own
// disc behind a thin edge never blows out).
const float PHASE_FORWARD = 0.82;
const float PHASE_BACK = -0.25;
const float PHASE_BACK_SHARE = 0.5;
const float PHASE_MAX = 14.0;
// The octaves' sum, unshaded, scaled so a sunlit side seen side-on or with
// the sun behind the eye takes about the sun's full light.
const float SUN_SCALE = 1.55;
// How much cloud (m) a lobe's face turned from the light counts as lying
// toward it (shaders/sky_sea.gdshader FACE_SHADE).
const float FACE_SHADE = 55.0;
// Powder: how far it darkens thin edges seen with the sun behind the eye,
// and over how many metres into the cloud it fades.
const float POWDER = 0.35;
const float POWDER_DEPTH = 9.0;
// The sky's light: open overhead (two taps up) and how fast cloud over a
// point takes it; under a bump, the crease's share.
const float UP_SIGMA = 0.03;
const float CREASE = 0.3;
const float DEEP = 0.4;
// The sky's light overall: under the sun's, so the sunlit side reads.
const float SKY = 0.72;
// Light off the bright sea below on a tower's lower flanks.
const float BOUNCE = 0.28;
// A tower's sky light against the sea's: a tall body stands in less of
// the sky's light than a low heap under open sky.
const float TOWER_SKY = 0.58;
// Lightning (as shaders/reference_cloud_march.gdshaderinc), in the glow's
// units (the composite's GLOW 1.4).
const float FLASH = 90.0 / 1.4;

const float WAKE_OPEN = 0.35;
const float WAKE_HOLD = 7.0;
const float WAKE_LIFE = 29.0;
const float WAKE_WIDEN = 1.5;
const float WAKE_WIDEN_TIME = 3.0;

// Which pixel of its 2x2 block a march pixel takes this frame.
ivec2 zs_block_offset(int frame) {
	int k = frame & 3;
	return k == 0 ? ivec2(0, 0) : (k == 1 ? ivec2(1, 1) : (k == 2 ? ivec2(1, 0) : ivec2(0, 1)));
}

float sstep(float a, float b, float x) {
	float t = clamp((x - a) / (b - a), 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

// Henyey-Greenstein, scaled so an even scatter is 1.
float hg(float c, float g) {
	float g2 = g * g;
	return (1.0 - g2) / pow(max(1.0 + g2 - 2.0 * g * c, 1e-4), 1.5);
}

float phase(float c, float scale) {
	return min(mix(hg(c, PHASE_FORWARD * scale), hg(c, PHASE_BACK * scale), PHASE_BACK_SHARE), PHASE_MAX);
}

float wake_strength(float age) {
	if (age < 0.0 || age >= WAKE_LIFE) return 0.0;
	return sstep(0.0, WAKE_OPEN, age) * (1.0 - sstep(WAKE_HOLD, WAKE_LIFE, age));
}

float wake_radius(float laid, float age) {
	return laid * (1.0 + WAKE_WIDEN * sstep(0.0, WAKE_WIDEN_TIME, age)) * sqrt(wake_strength(age));
}

float wake_keep(vec3 p, float rag) {
	float keep = 1.0;
	int n = int(P.frame.z);
	for (int i = 0; i < n; i++) {
		float age = P.eye.w - P.wake_at[i].w;
		float s = wake_strength(age);
		if (s <= 0.0) continue;
		float rad = wake_radius(P.wake_way[i].w, age);
		vec3 b = P.wake_at[i].xyz;
		vec3 back = P.wake_way[i].xyz;
		vec3 a = b - back;
		float len2 = dot(back, back);
		float h = len2 > 1e-4 ? clamp(dot(p - a, back) / len2, 0.0, 1.0) : 1.0;
		float d = distance(p, a + back * h);
		if (d > rad * 1.6) continue;
		keep = min(keep, 1.0 - s * (1.0 - sstep(rad * 0.5, rad * 1.1, d + (rag - 0.5) * rad * 0.9)));
	}
	return keep;
}

// --- The towers' bodies ----------------------------------------------------------------

float body_at(int i, vec3 local) {
	vec3 uvw = (local - P.tower_b[i].xyz) / (2.0 * P.tower_c[i].xyz) + 0.5;
	vec2 d;
	if (i == 0) d = textureLod(body0, uvw, 0.0).rg;
	else if (i == 1) d = textureLod(body1, uvw, 0.0).rg;
	else if (i == 2) d = textureLod(body2, uvw, 0.0).rg;
	else d = textureLod(body3, uvw, 0.0).rg;
	return mix(d.r, d.g, P.tower_b[i].w) + P.tower_c[i].w * ERODE;
}

// Distance (m) from a point in a tower's frame to its box, 0 inside.
float box_gap(int i, vec3 local) {
	vec3 q = abs(local - P.tower_b[i].xyz) - P.tower_c[i].xyz;
	return length(max(q, vec3(0.0)));
}

// --- WEATHER --------------------------------------------------------------------------

// The tallest of one lattice's round heaps at field point `f` (m over the
// sea's feet), and its crown's slope there; each heap only where the
// heap-field has mass at its middle.
vec2 heaps(vec2 f, float cell, vec2 radius, float tall, float salt) {
	vec2 g = floor(f / cell);
	vec2 best = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = g + vec2(float(x), float(y));
			vec2 h = hash2(c + salt);
			vec2 middle = (c + 0.18 + 0.64 * h) * cell;
			float r = cell * mix(radius.x, radius.y, hash1(c + salt + 17.3));
			float d = length(f - middle);
			if (d >= r) continue;
			// The heap-field's mass at its middle: none, no heap; little, a
			// low one.
			vec2 uv = (middle - P.envelope_at.xy) / P.envelope_at.z;
			float mass = textureLod(envelope, uv, 0.0).r * 2.0 - 1.0;
			float keep = sstep(-0.25, 0.35, mass + (hash1(c + salt + 5.1) - 0.5) * 0.3);
			if (keep <= 0.01) continue;
			float H = r * tall * mix(0.7, 1.15, hash1(c + salt + 9.7)) * mix(0.45, 1.0, keep);
			float u = d / r;
			// A round crown on steep flanks, a little flattened at the top.
			float e = max(1.0 - u * u, 1e-4);
			float top = H * pow(e, 0.6);
			if (top > best.x) best = vec2(top, H * 1.2 * u / (r * pow(e, 0.4)));
		}
	}
	return best;
}

// One texel of the weather map at world point `xz`: crown height (m over
// the sea's feet), density, base height (m), the crown's slope.
vec4 weather_texel(vec2 xz) {
	if (P.envelope_at.w < 0.5 || P.sea.w <= 0.0) return vec4(0.0);
	vec2 f = xz + DRIFT * P.eye.w;
	vec2 uv = (f - P.envelope_at.xy) / P.envelope_at.z;
	float mass = textureLod(envelope, uv, 0.0).r * 2.0 - 1.0;
	vec2 broad = heaps(f, BROAD, BROAD_R, BROAD_TALL, 0.0);
	vec2 small = heaps(f, SMALL, SMALL_R, SMALL_TALL, 41.0);
	vec2 crown = broad.x >= small.x ? broad : small;
	float field = sstep(-0.15, 0.3, mass);
	float density = max(field, sstep(0.0, 6.0, crown.x));
	crown.x = max(crown.x, FLOOR_LAYER * field);
	// Under the islands and round the ranges' feet the heaps close up and
	// rise.
	float lift = 0.0;
	float foot = 0.0;
	if (P.swells_at.w > 0.5) {
		vec2 s = textureLod(swells, (xz - P.swells_at.xy) / P.swells_at.z, 0.0).rg;
		lift = s.r;
		foot = s.g;
	}
	float closed = max(lift * 0.85, foot * 0.9);
	if (closed > 0.0) {
		float rise = max(lift, foot);
		float filled = max(crown.x, mix(FLOOR_LAYER, 40.0, rise));
		crown.x = mix(crown.x, filled, closed) * (1.0 + 0.35 * rise) + LIFT_RISE * rise * closed;
		crown.y *= 1.0 - 0.6 * closed;
		density = max(density, closed);
	}
	// Each tower's foot stands in a mound of the sea.
	int towers = int(P.frame.y);
	for (int i = 0; i < towers; i++) {
		vec3 local = vec3(xz.x - P.tower_a[i].x, P.tower_e[i].x + 12.0, xz.y - P.tower_a[i].z);
		vec3 q = abs(local - P.tower_b[i].xyz) - P.tower_c[i].xyz;
		float out_xz = length(max(q.xz, vec2(0.0)));
		if (out_xz > SKIRT_REACH) continue;
		vec3 inside = clamp(local, P.tower_b[i].xyz - P.tower_c[i].xyz + 1.0, P.tower_b[i].xyz + P.tower_c[i].xyz - 1.0);
		float bd = body_at(i, inside) + out_xz;
		float skirt = (1.0 - sstep(-10.0, SKIRT_REACH, bd)) * P.tower_a[i].w * (1.0 - P.tower_c[i].w);
		if (skirt <= 0.0) continue;
		float mound = SKIRT_TALL * pow(skirt, 0.7);
		if (mound > crown.x) crown = vec2(mound, SKIRT_TALL * 0.7 / SKIRT_REACH / max(pow(skirt, 0.3), 0.2));
		density = max(density, sstep(0.0, 0.4, skirt));
	}
	// Parted under a falling glide.
	float part = P.key.w;
	if (part > 0.0) {
		float fray = texture(cauliflower, vec3(f * 0.004, 0.37)).g * 18.0;
		float d = length(xz - P.sea2.xy) + fray;
		crown.x *= mix(1.0, sstep(part * 130.0, part * 130.0 + 45.0, d), sstep(0.0, 0.25, part));
	}
	// Handed over to the dome's sea far out.
	density *= 1.0 - sstep(P.sea.z * P.sea2.z, P.sea.z, length(xz - P.eye.xz));
	crown.x = min(crown.x, CROWN_MAX);
	if (density <= 0.0) crown.x = 0.0;
	return vec4(crown.x, density, 0.0, min(crown.y, 8.0));
}

// --- The cloud at a point ----------------------------------------------------------------

vec4 weather_at(vec2 xz) {
	vec2 uv = (xz - P.weather_at.xy) / P.weather_at.z;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return vec4(0.0);
	return textureLod(weather, uv, 0.0);
}

// The highest crown (m over the sea's feet) within a block of `xz`.
float ceiling_at(vec2 xz) {
	vec2 uv = (xz - P.weather_at.xy) / P.weather_at.z;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return 0.0;
	return textureLod(ceiling, uv, 0.0).r;
}

// How far into a heap a point is (m, about its true distance from the
// surface), given its weather texel; `hh` its height in the heap (0 foot,
// 1 crown), `wisp` the noise's green. `detail` 0 the light taps' form, 1
// with the middle octave, 2 with the fine one near the eye.
float sea_inside(vec3 p, vec4 w, float t, int detail, out float hh, out float wisp) {
	float top = P.sea.x + w.x;
	float base = P.sea.x + w.z;
	hh = clamp((p.y - base) / max(top - base, 4.0), 0.0, 1.0);
	vec3 boil = BOIL * P.eye.w;
	bool noisy = P.sea2.w > 0.5;
	vec2 n = noisy ? textureLod(cauliflower, (p + boil) / TILE, 0.0).rg : vec2(0.45, 0.5);
	wisp = n.g;
	// The billows grow toward the crown; the base stays flat-ish.
	float billow = mix(0.3, 1.0, hh) * sstep(0.0, 14.0, w.x);
	float inside = (top - p.y) / sqrt(1.0 + w.w * w.w) + billow * LOBE * (n.r - 0.45) + (n.g - 0.5) * WISP;
	if (detail >= 1 && noisy) inside += billow * MID_SWELL * (textureLod(cauliflower, (p + boil * 1.3 + 37.0) / MID, 0.0).r - 0.45);
	if (detail >= 2 && noisy && P.quality.w > 0.5) {
		float f = 1.0 - sstep(FINE_NEAR * 0.6, FINE_NEAR, t);
		// The finest octave mostly carves, so it never leaves specks of
		// cloud hanging off the body.
		if (f > 0.0) {
			float add = f * billow * FINE_SWELL * (textureLod(cauliflower, (p + boil * 1.6 + 71.0) / FINE, 0.0).r - 0.5);
			inside += add > 0.0 ? add * sstep(-4.0, 1.0, inside) : add;
		}
	}
	return min(inside, (p.y - base) * 2.0 + 1.0);
}

// A sample of the cloud: its density (0..1 per sigma), sigma, how far into
// it (m), its height in its own cloud (0 foot, 1 crown), the wisps, and
// whether it is a tower's.
struct Sample {
	float density;
	float sigma;
	float inside;
	float h;
	float pocket;
	float tower;
};

// How far a ray may leap from `p` before it can meet cloud (0: step here).
float clear_ahead(vec3 p, vec3 rd, float level) {
	float gap = 1e9;
	float far = length(p.xz - P.eye.xz);
	if (P.sea.w > 0.0 && far < P.sea.z) {
		float top_y = P.sea.x + CROWN_MAX + OVER;
		if (p.y < P.sea.x - 2.0) gap = rd.y < 0.0 ? 1e9 : (P.sea.x - 2.0 - p.y) / max(rd.y, 1e-4);
		else if (p.y > top_y) gap = rd.y > 0.0 ? 1e9 : (p.y - top_y) / max(-rd.y, 1e-4) + 0.5;
		else {
			// Over the block's highest crown: on to where the ray comes down
			// to it, at most out of the blocks round this one.
			float over = p.y - (P.sea.x + ceiling_at(p.xz) + OVER);
			float block = P.weather_at.z / P.weather_at.w * float(CEILING_BLOCK);
			if (over > 0.0) gap = min(rd.y < 0.0 ? over / -rd.y : 1e9, block * 0.9 / level);
			else gap = 0.0;
		}
	}
	int towers = int(P.frame.y);
	for (int i = 0; i < towers; i++) {
		vec3 local = p - P.tower_a[i].xyz;
		float b = box_gap(i, local);
		if (b > 0.0) gap = min(gap, b + 0.5);
		else gap = min(gap, max(body_at(i, local) - T_REACH, 0.0));
	}
	return gap;
}

Sample cloud_at(vec3 p, float t, float immersed, bool fine) {
	Sample s = Sample(0.0, SEA_SIGMA, -1e3, 0.0, 0.5, 0.0);
	// The sea's heaps.
	if (P.sea.w > 0.0 && p.y > P.sea.x - 2.0 && p.y < P.sea.x + CROWN_MAX + OVER) {
		vec4 w = weather_at(p.xz);
		if (w.y > 0.0 && p.y < P.sea.x + w.x + OVER) {
			float hh, wisp;
			float inside = sea_inside(p, w, t, fine ? 2 : 1, hh, wisp);
			float soft = mix(SOFT.y, SOFT.x, hh) * mix(0.5, 1.0, sstep(40.0, 300.0, t));
			float d = sstep(0.0, soft, inside) * mix(0.55, 1.0, sstep(0.3, 0.68, wisp)) * w.y;
			d *= sstep(P.sea.x - 1.0, P.sea.x + 10.0, p.y);
			d *= mix(1.0, sstep(0.47, 0.64, wisp), immersed);
			// Thin low toward the horizon, where the dome's veil is
			// (shaders/sky_sea.gdshader).
			vec3 to = normalize(p - P.eye.xyz);
			float veiled = sstep(-0.02, -0.16, to.y) * mix(1.0, sstep(-0.34, -0.66, to.y), P.frame.w);
			d *= mix(1.0, veiled, sstep(150.0, 700.0, t));
			d *= P.sea.w;
			if (d > 0.0) {
				s.density = d;
				s.inside = inside;
				s.h = hh;
				s.pocket = wisp;
				s.sigma = mix(SEA_SIGMA, T_SIGMA_IN, immersed);
			}
		}
	}
	// The towers.
	int towers = int(P.frame.y);
	for (int i = 0; i < towers; i++) {
		vec3 local = p - P.tower_a[i].xyz;
		if (box_gap(i, local) > 0.0) continue;
		float bd = body_at(i, local);
		if (bd > T_REACH) continue;
		float sea_y = P.tower_e[i].x;
		float span = max(P.tower_e[i].y - sea_y, 40.0);
		float h = clamp((local.y - sea_y) / span, 0.0, 1.0);
		vec3 boil = T_DRIFT * P.eye.w + P.tower_d[i].xyz - vec3(0.0, P.tower_d[i].w, 0.0);
		vec2 n = textureLod(cauliflower, (local + boil) / T_TILE, 0.0).rg;
		float inside = mix(0.45, 1.0, h) * T_SWELL * (n.r - 0.45) - bd + (n.g - 0.5) * mix(8.0, 3.0, h);
		float pocket = n.g;
		float f = fine ? 1.0 - sstep(T_FINE_NEAR * 0.6, T_FINE_NEAR, t) : 0.0;
		if (f > 0.0 && P.quality.w > 0.5) {
			vec2 fn = textureLod(cauliflower, (local + boil * 1.6 + 71.0) / T_FINE, 0.0).rg;
			// Fine octaves carve more than they add: no specks off the body.
			float add = f * (T_FINE_SWELL * (fn.r - 0.5) + T_FINEST_SWELL * (textureLod(cauliflower, (local + boil * 2.2 + 13.0) / T_FINEST, 0.0).r - 0.5));
			// Only on the body: none of it raises cloud out of clear air.
			inside += add > 0.0 ? add * sstep(-5.0, 1.0, inside) : add;
			pocket = mix(pocket, fn.g, 0.6 * f);
		}
		float soft = mix(T_SOFT.y, T_SOFT.x, h) * mix(0.5, 1.0, sstep(40.0, 300.0, t));
		float d = sstep(0.0, soft, inside) * mix(0.55, 1.0, sstep(0.3, 0.68, n.g));
		d *= mix(1.0, sstep(0.47, 0.64, pocket), immersed);
		d *= sstep(sea_y - 8.0, sea_y + 40.0, local.y);
		float wane = P.tower_c[i].w;
		float gone = clamp(wane * 1.4 + (1.0 - h) * 0.4 - 0.4, 0.0, 1.0);
		d *= sstep(gone * 0.75, gone * 0.75 + 0.2, n.g) * (1.0 - gone * gone);
		d *= P.tower_a[i].w;
		if (d > s.density) {
			s.density = d;
			s.sigma = mix(T_SIGMA, T_SIGMA_IN, immersed);
			s.inside = inside;
			s.h = h;
			s.pocket = pocket;
			s.tower = 1.0;
		} else {
			s.inside = max(s.inside, inside);
		}
	}
	if (s.density > 0.002 && int(P.frame.z) > 0) s.density *= wake_keep(p, s.pocket);
	return s;
}

// The cheap form for light taps: the density (0..1), no fine octaves, no
// wakes; the middle octave only near the eye (`mid`).
float density_cheap(vec3 p, bool mid) {
	float d = 0.0;
	if (P.sea.w > 0.0 && p.y > P.sea.x - 2.0 && p.y < P.sea.x + CROWN_MAX + OVER) {
		vec4 w = weather_at(p.xz);
		if (w.y > 0.0 && p.y < P.sea.x + w.x + OVER) {
			float hh, wisp;
			float inside = sea_inside(p, w, 1e3, mid ? 1 : 0, hh, wisp);
			d = sstep(0.0, 5.0, inside) * w.y * sstep(P.sea.x - 1.0, P.sea.x + 10.0, p.y);
		}
	}
	int towers = int(P.frame.y);
	for (int i = 0; i < towers; i++) {
		vec3 local = p - P.tower_a[i].xyz;
		if (box_gap(i, local) > 0.0) continue;
		float bd = body_at(i, local);
		if (bd > T_REACH) continue;
		float span = max(P.tower_e[i].y - P.tower_e[i].x, 40.0);
		float h = clamp((local.y - P.tower_e[i].x) / span, 0.0, 1.0);
		vec3 boil = T_DRIFT * P.eye.w + P.tower_d[i].xyz - vec3(0.0, P.tower_d[i].w, 0.0);
		float nr = textureLod(cauliflower, (local + boil) / T_TILE, 0.0).r;
		float inside = mix(0.45, 1.0, h) * T_SWELL * (nr - 0.45) - bd;
		d = max(d, sstep(0.0, 8.0, inside) * P.tower_a[i].w * sstep(P.tower_e[i].x - 8.0, P.tower_e[i].x + 40.0, local.y));
	}
	return d;
}

// How far into the cloud a point is (m), the light taps' form: for the
// face of the lobe a ray first meets.
float inside_cheap(vec3 p) {
	float inside = -1e3;
	if (P.sea.w > 0.0 && p.y > P.sea.x - 2.0 && p.y < P.sea.x + CROWN_MAX + OVER) {
		vec4 w = weather_at(p.xz);
		if (w.y > 0.0) {
			float hh, wisp;
			inside = sea_inside(p, w, 1e3, 1, hh, wisp);
		}
	}
	int towers = int(P.frame.y);
	for (int i = 0; i < towers; i++) {
		vec3 local = p - P.tower_a[i].xyz;
		if (box_gap(i, local) > 0.0) continue;
		float bd = body_at(i, local);
		if (bd > T_REACH) continue;
		float span = max(P.tower_e[i].y - P.tower_e[i].x, 40.0);
		float h = clamp((local.y - P.tower_e[i].x) / span, 0.0, 1.0);
		vec3 boil = T_DRIFT * P.eye.w + P.tower_d[i].xyz - vec3(0.0, P.tower_d[i].w, 0.0);
		float nr = textureLod(cauliflower, (local + boil) / T_TILE, 0.0).r;
		inside = max(inside, mix(0.45, 1.0, h) * T_SWELL * (nr - 0.45) - bd);
	}
	return inside;
}

// How much tower body lies far along the light from `p` (m of cloud): a
// few long taps through the towers' smooth bodies only, so a tower casts
// its shadow down onto the sea and onto its neighbours.
const int LONG_TAPS = 4;
const float LONG_AT[4] = float[](260.0, 340.0, 430.0, 540.0);
const float LONG_LEN = 90.0;
float tower_shade(vec3 p, vec3 key) {
	int towers = int(P.frame.y);
	if (towers == 0) return 0.0;
	float thick = 0.0;
	for (int k = 0; k < LONG_TAPS; k++) {
		vec3 q = p + key * LONG_AT[k];
		for (int i = 0; i < towers; i++) {
			vec3 local = q - P.tower_a[i].xyz;
			if (box_gap(i, local) > 0.0) continue;
			thick += sstep(10.0, -20.0, body_at(i, local)) * LONG_LEN * P.tower_a[i].w;
		}
	}
	return thick;
}

// How much of the sun an island keeps off a point (shaders/sky_sea.gdshader).
float island_shadow(vec3 p, vec3 sun) {
	float shade = 0.0;
	float up = max(sun.y, 0.25);
	for (int i = 0; i < 8; i++) {
		if (P.islands[i].z <= 0.0) break;
		vec2 at = p.xz + sun.xz / up * (P.islands[i].w - p.y);
		float d = length(at - P.islands[i].xy);
		shade = max(shade, 1.0 - sstep(P.islands[i].z * 0.55, P.islands[i].z * 1.25, d));
	}
	return shade;
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
	// This block and its eight neighbours, every other texel (the crowns are
	// broader than two texels).
	ivec2 texels = textureSize(weather, 0);
	float top = 0.0;
	for (int y = -CEILING_BLOCK; y < 2 * CEILING_BLOCK; y += 2) {
		for (int x = -CEILING_BLOCK; x < 2 * CEILING_BLOCK; x += 2) {
			ivec2 t = clamp(block * CEILING_BLOCK + ivec2(x, y), ivec2(0), texels - 1);
			top = max(top, texelFetch(weather, t, 0).r);
		}
	}
	imageStore(out_ceiling, block, vec4(top + 3.0, 0.0, 0.0, 0.0));
}

void shadow_pass() {
	ivec2 texel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(out_shadow);
	if (any(greaterThanEqual(texel, size))) return;
	vec3 key = normalize(P.key.xyz + vec3(0.0, 1e-4, 0.0));
	if (key.y < 0.03) {
		imageStore(out_shadow, texel, vec4(1.0, 1.0, 0.0, 0.0));
		return;
	}
	vec2 xz = P.weather_at.xy + (vec2(texel) + 0.5) / vec2(size) * P.weather_at.z;
	vec3 p = vec3(xz.x, P.sea.x, xz.y);
	float split = P.shadow_at.x;
	// Up toward the light, in growing steps, to over the highest tower.
	float top_y = P.sea.x + CROWN_MAX + OVER;
	int towers = int(P.frame.y);
	for (int i = 0; i < towers; i++) top_y = max(top_y, P.tower_a[i].y + P.tower_e[i].y + 20.0);
	float t_end = (top_y - p.y) / key.y;
	float high = 0.0;
	float low = 0.0;
	float high_y = 0.0;
	float t = 3.0;
	float step = 6.0;
	for (int i = 0; i < 40; i++) {
		if (t > t_end) break;
		vec3 q = p + key * t;
		float d = density_cheap(q, false) * step;
		if (q.y > split) {
			high += d;
			high_y += d * q.y;
		} else {
			low += d;
		}
		t += step;
		step = min(step * 1.18, 60.0);
	}
	float keep_high = exp(-high * SUN_SIGMA * 0.5);
	float keep_low = exp(-low * SUN_SIGMA * 0.5);
	imageStore(out_shadow, texel, vec4(keep_high, keep_low, high > 0.01 ? high_y / high : split, 0.0));
}

void march_pass() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(out_a);
	if (any(greaterThanEqual(pixel, size))) return;
	// Each march pixel stands for a 2x2 block of the render; it marches
	// through one of the four, a different one each frame (the resolve
	// fills the render's every pixel in over four frames). On Ultra each
	// march pixel is one of the render's.
	ivec2 full_size = textureSize(scene_depth, 0);
	int scale = max(int(P.quality.z), 1);
	ivec2 full = scale > 1 ? min(pixel * 2 + zs_block_offset(int(P.frame.x)), full_size - 1) : min(pixel, full_size - 1);
	vec2 uv = (vec2(full) + 0.5) / vec2(full_size);
	vec3 view_dir = normalize(vec3((uv.x * 2.0 - 1.0) * P.lens.x, (1.0 - uv.y * 2.0) * P.lens.y, -1.0));
	vec3 rd = normalize(mat3(P.camera) * view_dir);
	vec3 ro = P.eye.xyz;

	// The solid's distance along the ray (reversed-Z depth, linearised).
	float d = texelFetch(scene_depth, full, 0).r;
	float near = P.lens.z;
	float far = P.lens.w;
	float t_solid = 1e9;
	if (d > 0.0) {
		float z = near * far / (near + d * (far - near));
		t_solid = z / max(-view_dir.z, 1e-4);
	}
	imageStore(out_depth, pixel, vec4(t_solid));

	// Where along the ray there is any cloud to march: the sea's slab out to
	// its reach, and each tower's box.
	float level = max(length(rd.xz), 1e-4);
	float t_in = 1e9;
	float t_out = 0.0;
	if (P.sea.w > 0.0) {
		float top_y = P.sea.x + CROWN_MAX + OVER;
		float bottom = P.sea.x - 2.0;
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
		b = min(b, P.sea.z / level);
		if (b > a) {
			t_in = min(t_in, a);
			t_out = max(t_out, b);
		}
	}
	int towers = int(P.frame.y);
	for (int i = 0; i < towers; i++) {
		vec3 o = ro - P.tower_a[i].xyz;
		vec3 inv = 1.0 / (rd + vec3(equal(rd, vec3(0.0))) * 1e-6);
		vec3 lo = (P.tower_b[i].xyz - P.tower_c[i].xyz - o) * inv;
		vec3 hi = (P.tower_b[i].xyz + P.tower_c[i].xyz - o) * inv;
		vec3 n3 = min(lo, hi);
		vec3 f3 = max(lo, hi);
		float a = max(max(n3.x, n3.y), max(n3.z, 0.0));
		float b = min(min(f3.x, f3.y), f3.z);
		if (b > a) {
			t_in = min(t_in, a);
			t_out = max(t_out, b);
		}
	}
	t_out = min(t_out, t_solid);
	if (t_out <= t_in) {
		imageStore(out_a, pixel, vec4(0.0));
		imageStore(out_b, pixel, vec4(0.0));
		return;
	}

	// Blue-ish noise jitter on the start, new each frame (the temporal
	// resolve averages it away).
	float frame_index = P.frame.x;
	vec2 jp = vec2(pixel) + vec2(5.588238, 5.588238) * mod(frame_index, 64.0);
	float jitter = fract(52.9829189 * fract(dot(jp, vec2(0.06711056, 0.00583715))));

	vec3 key = normalize(P.key.xyz + vec3(0.0, 1e-4, 0.0));
	vec3 sun = normalize(P.sun.xyz + vec3(0.0, 1e-4, 0.0));
	float day_shadow = sstep(0.02, 0.2, sun.y) * (1.0 - sstep(0.35, 0.9, P.sun.w));
	// The phase of each scattering octave: the same all along the ray.
	float c = dot(rd, key);
	float ph[OCTAVES];
	for (int o = 0; o < OCTAVES; o++) ph[o] = phase(c, pow(MS_C, float(o)));
	// Powder only seen with the light behind the eye.
	float powder_share = POWDER * sstep(0.2, -0.6, c);

	// How deep in cloud the eye itself is: the fog round it glows.
	float immersed = 0.0;
	{
		Sample e = cloud_at(ro, 60.0, 0.0, false);
		if (e.density > 0.0) immersed = sstep(-4.0, 24.0, e.inside);
	}

	// The face of the lobe the ray first meets (found once, as the near sea
	// did): a face turned from the light counts FACE_SHADE metres of cloud
	// toward it, so every billow has a lit side and a shaded one even where
	// little stands between it and the sun.
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
	for (int i = 0; i < STEPS_MAX; i++) {
		if (i >= steps || t >= t_out || T < 0.03) break;
		vec3 p = ro + rd * t;
		float gap = clear_ahead(p, rd, level);
		if (gap > 0.0) {
			t += clamp(gap, STEP.x, 400.0);
			continue;
		}
		float step = clamp(STEP.x + t * STEP_GROW, STEP.x, STEP.y);
		if (!started) {
			started = true;
			t += step * jitter;
			if (t >= t_out) break;
			p = ro + rd * t;
		}
		Sample s = cloud_at(p, t, immersed, true);
		// Close to the eye the sea thins away (the glide's vapour takes
		// over), unless the eye is in it.
		if (s.tower < 0.5) s.density *= mix(sstep(NEAR_FADE.x, NEAR_FADE.y, t), 1.0, immersed);
		if (s.density > 0.002) {
			// Toward the light: optical depth through a cone of taps.
			float od = 0.0;
			int taps = T > 0.15 ? (t < 900.0 ? taps_full : 3) : 2;
			bool mid = t < 600.0;
			for (int k = 0; k < TAPS_MAX; k++) {
				if (k >= taps) break;
				od += density_cheap(p + key * TAP_AT[k], mid && k < 3) * TAP_LEN[k];
			}
			if (!faced) {
				faced = true;
				float e = mix(5.0, 14.0, sstep(60.0, 900.0, t));
				// The coarse form's slope (central differences); where it
				// has none round here (a wisp off the body, the sentinel),
				// half turned.
				float here = inside_cheap(p);
				vec3 grad = vec3(
					inside_cheap(p + vec3(e, 0.0, 0.0)) - inside_cheap(p - vec3(e, 0.0, 0.0)),
					inside_cheap(p + vec3(0.0, e, 0.0)) - inside_cheap(p - vec3(0.0, e, 0.0)),
					inside_cheap(p + vec3(0.0, 0.0, e)) - inside_cheap(p - vec3(0.0, 0.0, e)));
				turned = 0.5;
				if (here > -500.0 && dot(grad, grad) > 1e-6 && dot(grad, grad) < 4e5 * e * e) turned = sstep(-0.2, 0.75, dot(-normalize(grad), key));
			}
			od += (1.0 - turned) * FACE_SHADE;
			if (T > 0.1) od += tower_shade(p, key);
			od += island_shadow(p, sun) * day_shadow * 140.0;
			float tau = od * SUN_SIGMA;
			// Open overhead or under a bump.
			float sky_open = 1.0;
			if (T > 0.25) {
				// The coarse form only: the fine bumps' tops must not each
				// catch the open sky as a speck.
				float up = density_cheap(p + vec3(0.0, 12.0, 0.0), false) * 12.0 + density_cheap(p + vec3(0.0, 34.0, 0.0), false) * 24.0;
				sky_open = mix(CREASE, 1.0, exp(-up * UP_SIGMA * 2.0));
			}
			// The scattering octaves.
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
			float deep = sstep(0.0, 40.0, s.inside);
			float beer = exp(-tau);
			float ambient = SKY * mix(1.0, TOWER_SKY, s.tower) * sky_open * mix(0.5, 1.0, s.h) * mix(1.0, DEEP, deep) * mix(1.0, 0.45, beer);
			// The bright sea under a tower lights its lower flanks.
			float bounce = s.tower * BOUNCE * pow(1.0 - s.h, 2.0) * P.sea.w;
			float alpha = 1.0 - exp(-s.density * s.sigma * step);
			float w = T * alpha;
			float in_cloud = immersed;
			acc_a += w * (1.0 - in_cloud) * vec4(ambient, sun_light, bounce, s.tower);
			glow += w * in_cloud * (0.85 + 0.3 * beer);
			if (P.flash.w > 0.0) {
				float fd = length(p - P.flash.xyz);
				glow += w * P.flash.w * FLASH / (fd * fd + 40.0);
			}
			met += w * t;
			crown += w * s.h;
			T *= 1.0 - alpha;
		}
		t += step;
	}
	float cover = 1.0 - T;
	imageStore(out_a, pixel, acc_a);
	imageStore(out_b, pixel, vec4(cover, met, crown, glow));
}

void main() {
	if (PASS.mode == MODE_WEATHER) weather_pass();
	else if (PASS.mode == MODE_CEILING) ceiling_pass();
	else if (PASS.mode == MODE_SHADOW) shadow_pass();
	else march_pass();
}
