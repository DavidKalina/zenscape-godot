// The endless grass's cell placement in C++ (docs/design/endless-flight/native-grass-handoff.md):
// scripts/endless/endless_grass.gd `grow_cell` for one cell, line for line, as
// ZenScapeGrass. It covers the cell's probe (the 1 m height grid, its river,
// slope, beach, alpine and rock masks), KitFlora's Grow (scripts/kit_isle/
// kit_flora.gd) at the endless carpet's settings (the grass candidates, the
// wild grass's feet, the tussocks, thatch and seed heads, the flowers'
// candidates over the meadow type and the drifts), its Draw of the grass
// records into multimesh buffers (one a KitFlora tile, part and ring), and
// grow_cell's own pass over them (the painted ground's patches as each
// tuft's colour, the far ring's drift wash, the near ring's sub tiles).
// The flowers and seed heads it keeps come back as records, which GDScript
// draws (KitFlora.Draw: a few hundred a cell).
//
// Matching GDScript: its numbers are doubles; Vector2, Vector3, Basis, Color
// and PackedFloat32Array hold floats. The engine's vector maths is
// godot-cpp's copy of it (real_t = float), the random numbers are the
// engine's PCG32 and randf, the noise the engine's FastNoiseLite set up as
// its wrapper sets it up, and `hash` the engine's Variant hash. sin, cos and
// pow are the C runtime's, as GDScript's are, so a cell matches GDScript on
// one machine; on another C runtime a last bit may differ (a tuft's tint, or
// rarely a tuft at a mask's edge).
#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/basis.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/vector4.hpp>
#include "land_field_bind.h"
#include <cmath>
#include <cstdint>
#include <limits>
#include <string>
#include <unordered_map>
#include <vector>

namespace zsgrass {

using godot::Basis;
using godot::Color;
using godot::Transform3D;
using godot::Vector2;
using godot::Vector2i;
using godot::Vector3;
using FNL = fastnoiselite::FastNoiseLite;
using zsland::clampf;
using zsland::is_equal_approx;
using zsland::lerpf;
using zsland::maxf;
using zsland::minf;
using zsland::smoothstep;

constexpr double TAU = 6.2831853071795864769252867666;
constexpr double PI = 3.1415926535897932384626433833;
constexpr double DNAN = std::numeric_limits<double>::quiet_NaN();
constexpr double DINF = std::numeric_limits<double>::infinity();

inline int64_t floori(double v) { return int64_t(std::floor(v)); }
inline int64_t roundi(double v) { return int64_t(std::round(v)); }
inline int64_t clampi(int64_t v, int64_t lo, int64_t hi) { return v < lo ? lo : (v > hi ? hi : v); }
inline double clampd(double v, double lo, double hi) { return v < lo ? lo : (v > hi ? hi : v); }
inline double lerpd(double a, double b, double t) { return a + (b - a) * t; }
inline double fposmod(double x, double y) {
	double value = std::fmod(x, y);
	if ((value < 0 && y > 0) || (value > 0 && y < 0)) value += y;
	value += 0.0;
	return value;
}
// Two floats' difference as GDScript takes it (in doubles), narrowed.
inline float dif(float a, float b) { return float(double(a) - double(b)); }
// A float constant as GDScript reads it from a Vector2/3/4 constant.
inline double fq(double v) { return double(float(v)); }

// --- The engine's RandomNumberGenerator (RandomPCG) ----------------------------------
struct Pcg {
	uint64_t state = 0, inc = 0;
	static constexpr uint64_t DEFAULT_INC = 1442695040888963407ULL;
	uint32_t next() {
		const uint64_t old = state;
		state = old * 6364136223846793005ULL + inc;
		const uint32_t xorshifted = uint32_t(((old >> 18u) ^ old) >> 27u);
		const uint32_t rot = uint32_t(old >> 59u);
		return (xorshifted >> rot) | (xorshifted << ((~rot + 1u) & 31u));
	}
	void seed(uint64_t s) {
		state = 0u;
		inc = (DEFAULT_INC << 1u) | 1u;
		next();
		state += s;
		next();
	}
	static int clz32(uint32_t x) {
		int n = 0;
		if (x == 0) return 32;
		while (!(x & 0x80000000u)) {
			x <<= 1;
			++n;
		}
		return n;
	}
	float randf() {
		const uint32_t proto = next();
		if (proto == 0) return 0.0f;
		return std::ldexp(float(next() | 0x80000001u), -32 - clz32(proto));
	}
	float randf_range(float from, float to) { return randf() * (to - from) + from; }
};

// --- The engine's Variant hash of a Vector2i ----------------------------------------
inline uint32_t murmur(uint32_t in, uint32_t seed) {
	in *= 0xcc9e2d51u;
	in = (in << 15) | (in >> 17);
	in *= 0x1b873593u;
	seed ^= in;
	seed = (seed << 13) | (seed >> 19);
	return seed * 5u + 0xe6546b64u;
}
inline uint32_t fmix(uint32_t h) {
	h ^= h >> 16;
	h *= 0x85ebca6bu;
	h ^= h >> 13;
	h *= 0xc2b2ae35u;
	h ^= h >> 16;
	return h;
}
inline int64_t hash_v2i(int64_t x, int64_t y) {
	const uint32_t h = murmur(uint32_t(int32_t(x)), 0x7F07C65u);
	return int64_t(fmix(murmur(uint32_t(int32_t(y)), h)));
}
// float(hash(Vector2i(roundi(x*s), roundi(z*s)))%10007)/10007.0
inline double hash_unit(double x, double z, double s) {
	return double(hash_v2i(roundi(x * s), roundi(z * s)) % 10007) / 10007.0;
}

// --- The engine's FastNoiseLite as its wrapper sets it up ------------------------------
inline void godot_noise(FNL &n, int seed, FNL::NoiseType type, double frequency, FNL::FractalType fractal, int octaves) {
	n.SetSeed(seed);
	n.SetNoiseType(type);
	n.SetFrequency(float(frequency));
	n.SetFractalType(fractal);
	n.SetFractalOctaves(octaves);
	n.SetFractalLacunarity(2.0f);
	n.SetFractalGain(0.5f);
	n.SetFractalWeightedStrength(0.0f);
	n.SetFractalPingPongStrength(2.0f);
	n.SetCellularDistanceFunction(FNL::CellularDistanceFunction_Euclidean);
	n.SetCellularReturnType(FNL::CellularReturnType_Distance);
	n.SetCellularJitter(1.0f);
}
// get_noise_2d(x, y): float coordinates, the float back as a double.
inline double nz(const FNL &n, double x, double y) {
	return double(n.GetNoise(float(x) + 0.0f, float(y) + 0.0f));
}

// The engine's float cos and sin (Math::cos(float)). The official Windows
// build's C runtime gives the double result rounded; MSVC's cosf is a last
// bit off it now and then.
inline float fcos(float a) { return float(std::cos(double(a))); }
inline float fsin(float a) { return float(std::sin(double(a))); }

// Basis(axis, angle) as the engine builds it (no axis check).
inline Basis axis_angle(const Vector3 &a, double angle_d) {
	const float angle = float(angle_d);
	Basis b;
	const Vector3 sq(a.x * a.x, a.y * a.y, a.z * a.z);
	const float cosine = fcos(angle);
	b.rows[0][0] = sq.x + cosine * (1.0f - sq.x);
	b.rows[1][1] = sq.y + cosine * (1.0f - sq.y);
	b.rows[2][2] = sq.z + cosine * (1.0f - sq.z);
	const float sine = fsin(angle);
	const float t = 1 - cosine;
	float xyzt = a.x * a.y * t;
	float zyxs = a.z * sine;
	b.rows[0][1] = xyzt - zyxs;
	b.rows[1][0] = xyzt + zyxs;
	xyzt = a.x * a.z * t;
	zyxs = a.y * sine;
	b.rows[0][2] = xyzt + zyxs;
	b.rows[2][0] = xyzt - zyxs;
	xyzt = a.y * a.z * t;
	zyxs = a.x * sine;
	b.rows[1][2] = xyzt - zyxs;
	b.rows[2][1] = xyzt + zyxs;
	return b;
}
inline Vector2 from_angle(double angle_d) {
	const float a = float(angle_d);
	return Vector2(fcos(a), fsin(a));
}
inline Vector3 rotated(const Vector3 &v, const Vector3 &axis, double angle) {
	return axis_angle(axis, angle).xform(v);
}

// --- scripts/endless/endless_patch.gd ----------------------------------------------
struct Patch {
	Vector2 offset;
	double region_amount = 1.0, bloom_amount = 1.0;
	Vector3 plain;

	static constexpr double PATCH_STRENGTH = 1.0, THIN_UP = 0.93, ROCK_UP = 0.80, VERTEX_HUE = 0.2, DRY_NEAR = 0.18;
	static constexpr double RAGGED_MOST = 0.13, ALPINE_FROM = 42.0 - 15.0;
	static constexpr int KIND_SLOTS[16] = {0, 0, 0, 1, 1, 6, 6, 2, 2, 3, 3, 3, 4, 5, 0, 4};

	static uint32_t hash(int64_t x, int64_t z) {
		uint32_t h = uint32_t(x) * 1597334677u ^ uint32_t(z) * 3812015801u;
		h ^= h >> 16;
		h *= 2246822519u;
		h ^= h >> 13;
		h *= 3266489917u;
		h ^= h >> 16;
		return h;
	}
	static double lattice(int64_t x, int64_t z) { return double(hash(x, z) >> 8) / 16777215.0; }
	static double noise(double px, double pz) {
		const int64_t ix = floori(px), iz = floori(pz);
		double fx = px - double(ix), fz = pz - double(iz);
		fx = fx * fx * (3.0 - 2.0 * fx);
		fz = fz * fz * (3.0 - 2.0 * fz);
		const double a = lerpf(lattice(ix, iz), lattice(ix + 1, iz), fx);
		const double b = lerpf(lattice(ix, iz + 1), lattice(ix + 1, iz + 1), fx);
		return lerpf(a, b, fz);
	}
	static double river_bank(double x, double z) {
		const double n = noise(x / 55.0 + 11.0, z / 55.0 + 11.0) * 0.45 + noise(x / 19.0 + 5.0, z / 19.0 + 5.0) * 0.55;
		return 3.5 * lerpf(0.0, 1.8, smoothstep(0.42, 0.62, n));
	}
	static double fade(double x, double z, double scale) { return noise(x / scale, z / scale) - 0.5; }
	static double patch(double x, double z, double scale) { return smoothstep(0.43, 0.57, noise(x / scale, z / scale)) - 0.5; }
	static double luma(const Vector3 &c) { return double(c.dot(Vector3(0.2126, 0.7152, 0.0722))); }
	static double ss(double a, double b, double x) {
		const double t = clampf((x - a) / (b - a), 0.0, 1.0);
		return t * t * (3.0 - 2.0 * t);
	}
	static Vector3 lerp3(const Vector3 &a, const Vector3 &b, double t) { return a + (b - a) * float(t); }

	Vector3 region(double x, double z, double over) const {
		const double amount = region_amount;
		if (amount <= 0.0) return Vector3(1, 1, 1);
		const Vector2 q = Vector2(float(x), float(z)) + offset;
		const Vector2 r(float(double(q.x) * 0.8 - double(q.y) * 0.6), float(double(q.x) * 0.6 + double(q.y) * 0.8));
		const double a = noise(double(r.x) / 380.0 + 3.7, double(r.y) / 380.0 + 1.3) * 0.8 + noise(double(r.x) / 130.0 - 4.1, double(r.y) / 130.0 + 2.2) * 0.2;
		const double b = noise(double(q.y) / 300.0 - 2.1, double(q.x) / 300.0 + 8.4) * 0.8 + noise(double(q.x) / 110.0 + 6.3, double(q.y) / 110.0 - 1.7) * 0.2;
		const double c = noise(double(r.y) / 220.0 + 5.5, double(r.x) / 220.0 - 3.3);
		const Vector3 ONE(1, 1, 1);
		Vector3 m = lerp3(ONE, Vector3(0.44, 0.78, 0.58), ss(0.42, 0.30, a) * amount);
		m *= lerp3(ONE, Vector3(1.33, 1.20, 0.30), ss(0.58, 0.70, a) * amount);
		m *= lerp3(ONE, Vector3(0.92, 0.90, 1.65), ss(0.42, 0.30, b) * amount);
		m *= lerp3(ONE, Vector3(2.05, 1.22, 0.48), ss(0.60, 0.72, b) * amount);
		m *= lerp3(ONE, Vector3(1.39, 0.74, 1.46), ss(0.55, 0.68, c) * ss(16.0, 34.0, over) * amount);
		return m;
	}

	Vector3 grass(double x, double z, double meadow, double over, double up, const Vector3 &hue) const {
		static const Vector3 GREEN(0.1296, 0.3563, 0.1597), SUNLIT(0.2012, 0.4365, 0.1964), DEEP(0.1004, 0.2565, 0.1318);
		static const Vector3 DRY(0.2350, 0.3800, 0.1250), MEADOW(0.2050, 0.4500, 0.1300), TUNDRA(0.2050, 0.2300, 0.1300), OLIVE(0.2300, 0.2600, 0.1200);
		const double vast = fade(x + 311.0, z + 97.0, 900.0);
		const double broad = fade(x + 71.0, z + 13.0, 260.0);
		const double wide = fade(x + 5.0, z + 211.0, 70.0);
		const double mid = fade(x + 133.0, z + 41.0, 19.0);
		const double clump = patch(x + 57.0, z + 19.0, 34.0) * 0.7 + patch(x + 3.0, z + 77.0, 8.0) * 0.5;
		const double sunny = clampf((broad * 1.3 + wide * 1.5 + mid * 0.9 + clump * 0.9) * PATCH_STRENGTH, -1.0, 1.0);
		Vector3 g = GREEN.lerp(sunny > 0.0 ? SUNLIT : DEEP * float(0.82), float(std::fabs(sunny)));
		g = g.lerp(MEADOW * float(1.0 + mid * 0.5), float(meadow * 0.75));
		const double warm = clampf(broad * 2.4 + vast * 1.8, -1.0, 1.0) * PATCH_STRENGTH;
		g *= Vector3(1, 1, 1).lerp(warm > 0.0 ? Vector3(1.32, 1.05, 0.62) : Vector3(0.80, 0.97, 1.16), float(std::fabs(warm) * 0.5));
		g *= region(x, z, over);
		if (hue != Vector3()) g = g.lerp(hue / float(maxf(luma(hue), 0.01)) * float(luma(g)), float(VERTEX_HUE * 0.6));
		const double dry_far = smoothstep(0.05, 0.32, broad + wide * 0.6 + 0.1);
		const double dry = clampf(DRY_NEAR * 0.6 + dry_far * 0.55, 0.0, 1.0) * (1.0 - meadow * 0.6);
		g = g.lerp(DRY, float(dry * 0.4));
		const double alpine = smoothstep(42.0, 78.0, over + broad * 30.0);
		g = g.lerp(TUNDRA * float(1.0 + mid * 0.6), float(alpine * 0.8));
		const double thin = smoothstep(THIN_UP, ROCK_UP, up);
		g = g.lerp(OLIVE, float(thin * 0.7));
		return g;
	}

	Color tint(double x, double z, double meadow, double over, double up, const Vector3 &hue) const {
		const Vector3 g = grass(x, z, meadow, over, up, hue);
		return Color(g.x / plain.x, g.y / plain.y, g.z / plain.z);
	}

	static double rock_hash(int64_t x, int64_t y, int64_t z) {
		uint32_t vx = uint32_t(x) * 1664525u + 1013904223u;
		uint32_t vy = uint32_t(y) * 1664525u + 1013904223u;
		uint32_t vz = uint32_t(z) * 1664525u + 1013904223u;
		vx = vx + vy * vz;
		vy = vy + vz * vx;
		vz = vz + vx * vy;
		vx ^= vx >> 16;
		vy ^= vy >> 16;
		vz ^= vz >> 16;
		vx = vx + vy * vz;
		return double(vx & 65535u) / 65535.0;
	}
	static double rock_noise(const Vector3 &p) {
		const Vector3 i = p.floor();
		Vector3 f = p - i;
		f = f * f * (Vector3(3.0, 3.0, 3.0) - f * 2.0f);
		const int64_t qx = int64_t(int32_t(i.x)), qy = int64_t(int32_t(i.y)), qz = int64_t(int32_t(i.z));
		float h[8];
		for (int k = 0; k < 8; ++k) h[k] = float(rock_hash(qx + (k & 1), qy + ((k >> 1) & 1), qz + (k >> 2)));
		const double a = lerpf(lerpf(h[0], h[1], f.x), lerpf(h[2], h[3], f.x), f.y);
		const double b = lerpf(lerpf(h[4], h[5], f.x), lerpf(h[6], h[7], f.x), f.y);
		return lerpf(a, b, f.z);
	}
	static double rock_ragged(const Vector3 &p) {
		return (rock_noise(p / 7.0f) - 0.5) * 0.10 + (rock_noise(p / 31.0f + Vector3(4.0, 4.0, 4.0)) - 0.5) * 0.16;
	}
	static double alpine_of(double over, double broad_patch) { return smoothstep(42.0, 78.0, over + broad_patch * 30.0); }
	static double broad(double x, double z) { return fade(x + 71.0, z + 13.0, 260.0); }

	static Vector2 layer(const Vector2 &q, double cell, double chance, const Vector2 &rad, int64_t salt, Vector2 best) {
		const int64_t cx = floori(double(q.x) / cell - 0.5);
		const int64_t cz = floori(double(q.y) / cell - 0.5);
		for (int j = 0; j < 2; ++j) {
			for (int i = 0; i < 2; ++i) {
				const int32_t c_x = int32_t(cx + i), c_y = int32_t(cz + j);
				const uint32_t h = hash(int64_t(c_x) + salt, int64_t(c_y) + salt * 3);
				if (double(h & 255u) / 255.0 >= chance) continue;
				const Vector2 jit = Vector2(float(double((h >> 8) & 255u)), float(double((h >> 16) & 255u))) * float(0.6) / float(255.0);
				const Vector2 centre = (Vector2(float(c_x), float(c_y)) + Vector2(0.2, 0.2) + jit) * float(cell);
				const double radius = cell * lerpf(rad.x, rad.y, double((h >> 24) & 15u) / 15.0);
				const double w = 1.0 - ss(0.35, 1.0, double(q.distance_to(centre)) / radius);
				if (w > double(best.x)) best = Vector2(float(w), float(double(KIND_SLOTS[(h >> 28) & 15u])));
			}
		}
		return best;
	}
	Vector2 bloom(double x, double z) const {
		Vector2 best;
		const double amount = bloom_amount;
		if (amount <= 0.0) return best;
		Vector2 q = Vector2(float(x), float(z)) + offset;
		q += (Vector2(float(noise(double(q.x) / 41.0 + 4.2, double(q.y) / 41.0 - 2.6)), float(noise(double(q.x) / 41.0 - 3.3, double(q.y) / 41.0 + 7.9))) - Vector2(0.5, 0.5)) * float(30.0);
		best = layer(q, 46.0, 0.44 * amount, Vector2(0.28, 0.5), 7151, best);
		best = layer(q, 15.0, 0.16 * amount, Vector2(0.2, 0.38), 9241, best);
		best.x = float(double(best.x) * lerpf(0.45, 1.0, ss(0.3, 0.68, noise(double(q.x) / 6.5 + 2.9, double(q.y) / 6.5 - 8.1))));
		return best;
	}
};

// --- The configuration (endless_grass.gd `_native_config`) ---------------------------
struct Kind {
	int asset = -1;          // index into Config::assets
	double packing = 1.0;
	float size_lo = 0.85f, size_hi = 1.1f;
	bool standing_in = false;
	double head = 0.0, height = 0.0, fb_top = 1.0, fb_head = 1.0;
	std::vector<Color> tints; // empty: the asset's own colour
};
struct GrassPart {
	godot::String key;
	Transform3D pose;
	Color tint;
	bool ringed = false;
};

struct Config {
	// KitFlora.Site at the carpet's settings.
	double tufts = 0, tuft_bump = 1, shag = 0, contact = 0, height_field = 0, tilt = 0, rim = -1;
	bool variety = false, carpet = true;
	bool flowers = false;
	double patches = 1.0, flower_tall = 1.0, sub = 0.0;
	float slope_x = 0.83f, slope_y = 0.88f, alpine_x = 0.3f, alpine_y = 0.7f;
	double flower_tries = 2.2;
	// The rings (Site lod, lod_grow, lod_soft).
	godot::Vector4 lod;
	Vector2 lod_grow;
	double lod_soft = 6.0;
	Patch patch;
	// The catalog: the grass tuft's parts (their poses and tints); the
	// flower assets by index; the kinds (alpine meadow's and the drifts').
	std::vector<GrassPart> grass_parts;
	godot::PackedStringArray assets;
	std::vector<Kind> kinds;
	std::vector<int> meadow_kinds;
	std::vector<double> meadow_weights;
	double meadow_cover = 0.62, meadow_frequency = 0.2, meadow_mix = 0.3;
	std::vector<int> bloom_kinds;
	std::vector<double> bloom_variants;
	int wheat = -1;
	Color thatch_straw;
	double tint_step = 2.0, sink = 0.04, sea_y = -40.0;
	double beach_clear = 2.55, beach_ramp = 0.35, rock_near = 0.95, alpine_top = 84.0;
	float high_x = 36.0f, high_y = 58.0f;
	Color tuft_tone = Color(1, 1, 1);
	double bloom_peak = 16.0, bloom_companion = 0.12, bloom_kind = 0.12, far_wash = 0.35;
	float drift_x = 0.68f, drift_y = 0.82f, drift_z = 6.0f;
	double drift_scale = 55.0;
	float flower_lift_x = 0.8f, flower_lift_y = 1.3f;
	// The alpine tufts (endless_grass ALP): short, sparse tufts on the high
	// turf where the meadow's thin out (its alpine mask's complement), in a pass
	// of their own after the carpet's (their own random numbers, their records
	// after its), so the meadow's tufts and flowers stay where they were.
	// alp_share: their candidates a square metre, a share of `tufts` (0: none).
	double alp_share = 0.0, alp_tall = 0.5, alp_wide = 1.1;
	Color alp_tone = Color(1, 1, 1); // over the tuft's colour (linear)
	double alp_slope_x = 0.87, alp_slope_y = 0.93;
	// The top (over the sea, m): gone from top_y, thinning from top_x; inside
	// the Peak's zone (zone: x, z, radius, on; 600 m soft) its own top.
	double alp_top_x = 79.0, alp_top_y = 95.0, alp_zone_top_x = 140.0, alp_zone_top_y = 170.0;
	godot::Vector4 alp_zone;
	// None on a proud crown (the summits' snow caps, the ground's land_shape.b)
	// outside the Peak's zone.
	bool alp_proud = false;
	// The ground's high stone and scree off the Peak (endless_ground `bare`:
	// alpine_from over its alpine; y 0: none).
	double alp_bare_x = 0.25, alp_bare_y = 0.0;
	// Ground they keep off (the Peak's ice, its rubble, its gorge's scree):
	// capsules [ax, az, bx, bz, ra, rb], and the box round them all.
	std::vector<float> alp_off;
	godot::Vector4 alp_off_box;
};

// KitFlora constants.
constexpr double DRIFT_FREQUENCY = 0.07, HEIGHT_SCALE = 0.12, HEIGHT_THICK = 0.3;
constexpr double PATH_THIN = 0.1, PATH_BARE = 0.5, REACH = 0.25, RIM = 0.5;
constexpr double SHAG_CELL = 1.0, SHAG_VARY = 0.18, SHAG_NOISE = 2.3;
constexpr double TUSSOCK_SHARE = 0.08, THATCH_SHARE = 0.35, SEED_SHARE = 0.025;
constexpr double FLOWER_SHARE = 0.16, STRAY = 0.006;
constexpr int TILE = 24;

struct Record {
	int asset = -1;  // -1: the grass tuft; else Config::assets' index
	double x = 0, z = 0, angle = 0, scale = 0, h = 0;
	bool has_pose = false, has_tint = false;
	bool alpine = false; // an alpine tuft (its colour times Config alp_tone)
	Basis pose;
	Color tint;
};

// One cell's grow (endless_grass `grow_cell` past its height grid).
class Cell {
public:
	const Config &cfg;
	double x0, z0;
	int n, pad;
	const float *hs, *rs, *ms;
	double b00, b10, b01, b11;
	Pcg rng;
	FNL drift;
	FNL m_drift, m_species, m_warp;
	std::vector<Record> records;
	std::vector<float> feet;      // _foot's memo, by 1 m cell round the box (NaN: not yet)
	std::vector<double> ragged_d; // rock_ragged by grid node (NaN: not yet)
	int foot_x0 = 0, foot_z0 = 0, foot_n = 0;
	std::unordered_map<int64_t, float> feet_far;
	// The drifts' grid (Patch bloom, every TINT_STEP m).
	int tg = 0;
	std::vector<Vector2> blooms;
	Vector2 box_pos, box_end;
	double area = 0.0;
	// A band cell's dither (endless_grass `_dither`): the groups' weights on a
	// dither_grid x dither_grid grid over the cell (node-major, dither_count a
	// node); a candidate is grown only where a hash at its root picks
	// dither_group by the weights there. None: every candidate.
	const float *dither_w = nullptr;
	int dither_grid = 0, dither_count = 0, dither_group = 0;

	bool dithered_out(const Vector2 &p) const {
		if (dither_w == nullptr) return false;
		const double step = 64.0 / double(dither_grid - 1);
		const double u = clampd((double(p.x) - x0) / step, 0.0, dither_grid - 1.001);
		const double v = clampd((double(p.y) - z0) / step, 0.0, dither_grid - 1.001);
		const int i = int(u), j = int(v);
		const double fu = u - i, fv = v - j;
		const int c = dither_count;
		const float *a = dither_w + (j * dither_grid + i) * c, *b = a + c, *e = a + dither_grid * c, *f = e + c;
		double total = 0.0;
		for (int q = 0; q < c; ++q) total += lerpd(lerpd(a[q], b[q], fu), lerpd(e[q], f[q], fu), fv);
		const double d = hash_unit(p.x, p.y, 79.0) * total;
		double acc = 0.0;
		int pick = c - 1;
		for (int q = 0; q < c; ++q) {
			acc += lerpd(lerpd(a[q], b[q], fu), lerpd(e[q], f[q], fu), fv);
			if (d < acc) {
				pick = q;
				break;
			}
		}
		return pick != dither_group;
	}

	Cell(const Config &c, double px0, double pz0, int pn, int ppad, const float *h, const float *r, const float *m) :
			cfg(c), x0(px0), z0(pz0), n(pn), pad(ppad), hs(h), rs(r), ms(m) {}

	// The cell's probe (grow_cell `probe`): the drawn turf's height at p, or NaN.
	double probe(const Vector2 &p) {
		const double u = double(p.x) - x0 + pad;
		const double v = double(p.y) - z0 + pad;
		const int64_t i = clampi(floori(u), 1, n - 3);
		const int64_t j = clampi(floori(v), 1, n - 3);
		const double fx = clampf(u - double(i), 0.0, 1.0);
		const double fz = clampf(v - double(j), 0.0, 1.0);
		const int64_t k = j * n + i;
		const double h00 = hs[k], h10 = hs[k + 1], h01 = hs[k + n], h11 = hs[k + n + 1];
		const double h = fx + fz <= 1.0 ? h00 + fx * (h10 - h00) + fz * (h01 - h00) : h11 + (1.0 - fx) * (h01 - h11) + (1.0 - fz) * (h10 - h11);
		const double over = h - cfg.sea_y;
		if (over < cfg.beach_clear) return DNAN;
		const int64_t c = (j + roundi(fz)) * n + i + roundi(fx);
		if (double(rs[c]) < 12.0 && double(rs[c]) < Patch::river_bank(p.x, p.y) * 0.85) return DNAN;
		double up = 2.0 / double(Vector3(dif(hs[c - 1], hs[c + 1]), 2.0f, dif(hs[c - n], hs[c + n])).length());
		double high = 1.0;
		const double alp_x = cfg.alpine_x, alp_y = cfg.alpine_y;
		if (alp_y <= 0.0) high = 1.0 - smoothstep(cfg.high_x, cfg.high_y, over);
		else if (over > Patch::ALPINE_FROM) {
			const double bx = clampf((double(p.x) - x0) / 64.0, 0.0, 1.0);
			const double bz = clampf((double(p.y) - z0) / 64.0, 0.0, 1.0);
			const double broad = lerpf(lerpf(b00, b10, bx), lerpf(b01, b11, bx), bz);
			high = 1.0 - smoothstep(alp_x, alp_y, Patch::alpine_of(over, broad));
			if (high <= 0.0) return DNAN;
		}
		if (alp_y > 0.0 && up < cfg.rock_near) {
			if (up < double(cfg.slope_x) - Patch::RAGGED_MOST) return DNAN;
			if (std::isnan(ragged_d[c])) {
				const Vector3 at(float(x0 + double(c % n) - pad), hs[c], float(z0 + double(c / n) - pad));
				ragged_d[c] = Patch::rock_ragged(at);
			}
			up += ragged_d[c];
		}
		const double keep = smoothstep(cfg.slope_x, cfg.slope_y, up) * high * smoothstep(cfg.beach_clear, cfg.beach_clear + cfg.beach_ramp, over);
		if (keep <= 0.0) return DNAN;
		if (keep < 1.0 && hash_unit(p.x, p.y, 7.0) > keep) return DNAN;
		return h - cfg.sink;
	}
	// The alpine tufts' probe: the drawn turf's height at p where an alpine
	// tuft stands, or NaN. The same ground as `probe` reads, with the alpine
	// mask turned round (they grow where the carpet's thin out), a stricter
	// slope (they stop short of the high ground's broken rock), a top under
	// the snow, and off the ground in `alp_off` and the proud crowns.
	std::vector<float> proud; // ALP_PROUD_N^2 nodes ALP_PROUD_STEP m apart from (x0, z0); empty: none
	static constexpr int ALP_PROUD_N = 9;
	static constexpr double ALP_PROUD_STEP = 8.0;
	double probe_alpine(const Vector2 &p) {
		const double u = double(p.x) - x0 + pad;
		const double v = double(p.y) - z0 + pad;
		const int64_t i = clampi(floori(u), 1, n - 3);
		const int64_t j = clampi(floori(v), 1, n - 3);
		const double fx = clampf(u - double(i), 0.0, 1.0);
		const double fz = clampf(v - double(j), 0.0, 1.0);
		const int64_t k = j * n + i;
		const double h00 = hs[k], h10 = hs[k + 1], h01 = hs[k + n], h11 = hs[k + n + 1];
		const double h = fx + fz <= 1.0 ? h00 + fx * (h10 - h00) + fz * (h01 - h00) : h11 + (1.0 - fx) * (h01 - h11) + (1.0 - fz) * (h10 - h11);
		const double over = h - cfg.sea_y;
		if (over < Patch::ALPINE_FROM) return DNAN;
		// The top: under the snow line, or on the Peak under its granite.
		double zone = 0.0;
		if (cfg.alp_zone.w > 0.5) {
			const double d = double(Vector2(float(cfg.alp_zone.x), float(cfg.alp_zone.y)).distance_to(p));
			zone = 1.0 - smoothstep(double(cfg.alp_zone.z) - 600.0, double(cfg.alp_zone.z), d);
		}
		const double top_x = lerpd(cfg.alp_top_x, cfg.alp_zone_top_x, zone), top_y = lerpd(cfg.alp_top_y, cfg.alp_zone_top_y, zone);
		if (over >= top_y) return DNAN;
		const int64_t c = (j + roundi(fz)) * n + i + roundi(fx);
		if (double(rs[c]) < 12.0 && double(rs[c]) < Patch::river_bank(p.x, p.y) * 0.85) return DNAN;
		double up = 2.0 / double(Vector3(dif(hs[c - 1], hs[c + 1]), 2.0f, dif(hs[c - n], hs[c + n])).length());
		const double bx = clampf((double(p.x) - x0) / 64.0, 0.0, 1.0);
		const double bz = clampf((double(p.y) - z0) / 64.0, 0.0, 1.0);
		const double broad = lerpf(lerpf(b00, b10, bx), lerpf(b01, b11, bx), bz);
		const double alpine = Patch::alpine_of(over, broad);
		double w = cfg.alpine_y <= 0.0f ? smoothstep(cfg.high_x, cfg.high_y, over) : smoothstep(cfg.alpine_x, cfg.alpine_y, alpine);
		// Off the Peak's zone the high ground goes to stone and scree (the
		// ground's `bare`, alpine_from): none there.
		if (cfg.alp_bare_y > 0.0) w *= 1.0 - smoothstep(cfg.alp_bare_x, cfg.alp_bare_y, alpine) * (1.0 - zone);
		if (w <= 0.0) return DNAN;
		if (up < cfg.rock_near) {
			if (up < cfg.alp_slope_x - Patch::RAGGED_MOST) return DNAN;
			if (std::isnan(ragged_d[c])) {
				const Vector3 at(float(x0 + double(c % n) - pad), hs[c], float(z0 + double(c / n) - pad));
				ragged_d[c] = Patch::rock_ragged(at);
			}
			up += ragged_d[c];
		}
		double keep = w * smoothstep(cfg.alp_slope_x, cfg.alp_slope_y, up) * (1.0 - smoothstep(top_x, top_y, over));
		if (keep <= 0.0) return DNAN;
		// Off the Peak's ice, rubble and scree.
		const std::vector<float> &off = cfg.alp_off;
		if (!off.empty() && p.x > cfg.alp_off_box.x && p.y > cfg.alp_off_box.y && p.x < cfg.alp_off_box.z && p.y < cfg.alp_off_box.w) {
			for (size_t s = 0; s + 5 < off.size(); s += 6) {
				const Vector2 a(off[s], off[s + 1]);
				const Vector2 e = Vector2(off[s + 2], off[s + 3]) - a;
				const double t = clampd(double((p - a).dot(e)) / maxf(double(e.length_squared()), 0.001), 0.0, 1.0);
				const double r = lerpd(off[s + 4], off[s + 5], t);
				const double dd = double(p.distance_to(a + e * float(t)));
				if (dd < r) return DNAN;
				keep *= smoothstep(r, r * 1.15 + 4.0, dd);
			}
		}
		// Off the proud crowns' snow caps (outside the Peak's zone).
		if (!proud.empty() && zone < 1.0) {
			const double gu = clampd((double(p.x) - x0) / ALP_PROUD_STEP, 0.0, ALP_PROUD_N - 1.001);
			const double gv = clampd((double(p.y) - z0) / ALP_PROUD_STEP, 0.0, ALP_PROUD_N - 1.001);
			const int gi = int(gu), gj = int(gv);
			const double gx = gu - gi, gz = gv - gj;
			const float *q = proud.data() + gj * ALP_PROUD_N + gi;
			const double b = lerpd(lerpd(q[0], q[1], gx), lerpd(q[ALP_PROUD_N], q[ALP_PROUD_N + 1], gx), gz);
			const double capped = smoothstep(0.50, 0.58, b) * smoothstep(50.0, 85.0, over);
			keep *= 1.0 - smoothstep(0.2, 0.6, capped) * (1.0 - zone);
		}
		if (keep <= 0.0) return DNAN;
		if (keep < 1.0 && hash_unit(p.x, p.y, 11.0) > keep) return DNAN;
		return h - cfg.sink;
	}
	// The alpine tufts: their own candidates after the carpet's, each a short,
	// a little wider tuft.
	void grow_alpine(int64_t grow_seed) {
		if (cfg.alp_share <= 0.0) return;
		if (ragged_d.size() != size_t(n * n)) ragged_d.assign(size_t(n * n), DNAN);
		Pcg arng;
		arng.seed(uint64_t(grow_seed) * 2654435761ULL + 0x5A17EULL);
		const int64_t count = int64_t(64.0 * 64.0 * cfg.tufts * cfg.alp_share);
		for (int64_t c = 0; c < count; ++c) {
			const float px = arng.randf_range(float(x0), float(x0 + 64.0));
			const float pz = arng.randf_range(float(z0), float(z0 + 64.0));
			const double size = arng.randf_range(0.8f, 1.25f);
			const double angle = double(arng.randf()) * TAU;
			const Vector2 p(px, pz);
			if (dithered_out(p)) continue;
			const double h = probe_alpine(p);
			if (std::isnan(h)) continue;
			Record r;
			r.asset = -1;
			r.x = p.x;
			r.z = p.y;
			r.angle = angle;
			r.scale = size;
			r.h = h;
			r.has_pose = true;
			r.alpine = true;
			r.pose = axis_angle(Vector3(0, 1, 0), angle).scaled(Vector3(float(size * cfg.alp_wide), float(size * cfg.alp_tall), float(size * cfg.alp_wide)));
			records.push_back(r);
		}
	}
	double foot(const Vector2 &p) {
		const int64_t kx = floori(double(p.x) / SHAG_CELL), kz = floori(double(p.y) / SHAG_CELL);
		float *slot = nullptr;
		const int64_t ix = kx - foot_x0, iz = kz - foot_z0;
		if (ix >= 0 && iz >= 0 && ix < foot_n && iz < foot_n) slot = &feet[iz * foot_n + ix];
		const int64_t mkey = (kx << 32) ^ (kz & 0xffffffffLL);
		if (slot) {
			if (!std::isnan(*slot)) return *slot;
		} else {
			auto it = feet_far.find(mkey);
			if (it != feet_far.end()) return it->second;
		}
		const Vector2 c = (Vector2(float(int32_t(kx)), float(int32_t(kz))) + Vector2(0.5, 0.5)) * float(SHAG_CELL);
		double f = 0.0;
		const double rings[2] = {1.0, double(2.2f)};
		for (int r = 0; r < 2; ++r) {
			for (int k = 0; k < 8; ++k) {
				if (std::isnan(probe(c + from_angle(double(k) * TAU / 8.0 + 0.2) * float(rings[r])))) {
					f = r == 0 ? 1.0 : 0.5;
					break;
				}
			}
			if (f > 0.0) break;
		}
		if (slot) *slot = float(f);
		else feet_far[mkey] = float(f);
		return f;
	}

	double rolling(const Vector2 &p) const {
		return clampf(nz(drift, double(p.x) / DRIFT_FREQUENCY * HEIGHT_SCALE - 57.0, double(p.y) / DRIFT_FREQUENCY * HEIGHT_SCALE + 89.0) * 1.6, -1.0, 1.0);
	}
	double shag_of(const Vector2 &p, double wild) const {
		const double nn = nz(drift, double(p.x) * SHAG_NOISE + 31.0, double(p.y) * SHAG_NOISE - 17.0);
		return cfg.tuft_bump * lerpf(1.0, 1.0 + cfg.shag, wild) * (1.0 + nn * SHAG_VARY);
	}
	Basis lean(double angle, const Vector3 &form) {
		const Basis b = axis_angle(Vector3(0, 1, 0), angle).scaled(form);
		if (cfg.tilt <= 0.0) return b;
		const Vector3 axis = rotated(Vector3(1, 0, 0), Vector3(0, 1, 0), double(rng.randf()) * TAU);
		return axis_angle(axis, double(rng.randf()) * cfg.tilt) * b;
	}
	bool add(int asset, const Vector2 &p, double size, bool has_tint, const Color &tint, bool has_pose, const Basis &pose) {
		const double h = probe(p);
		if (std::isnan(h)) return false;
		Record r;
		r.asset = asset;
		r.x = p.x;
		r.z = p.y;
		r.angle = double(rng.randf()) * TAU;
		r.scale = size;
		r.h = h;
		r.has_tint = has_tint;
		r.tint = tint;
		r.has_pose = has_pose;
		r.pose = pose;
		records.push_back(r);
		return true;
	}
	// KitFlora's MeadowTypes.form for a kind: [record size, pose or none].
	void form(const Kind &k, double size, double angle, double lift, double &out_size, bool &has_pose, Basis &pose) const {
		if (!k.standing_in) {
			out_size = size;
			if (is_equal_approx(lift, 1.0)) {
				has_pose = false;
				return;
			}
			has_pose = true;
			pose = axis_angle(Vector3(0, 1, 0), angle) * Basis::from_scale(Vector3(float(size), float(size * lift), float(size)));
			return;
		}
		const double across = size * k.head / k.fb_head;
		const double up = size * k.height / k.fb_top * lift;
		pose = axis_angle(Vector3(0, 1, 0), angle) * Basis::from_scale(Vector3(float(across), float(up), float(across)));
		has_pose = true;
		out_size = clampf(across, 0.1, 5.0);
	}
	bool kind_tint(const Kind &k, double variant, Color &out) const {
		if (k.tints.empty()) return false;
		const int64_t s = int64_t(k.tints.size());
		int64_t idx = int64_t(variant * double(s));
		if (idx > s - 1) idx = s - 1;
		out = k.tints[size_t(idx)];
		return true;
	}

	void tuft(const Vector2 &p, double size, double wild) {
		const double ft = foot(p); // e is INF: past SHAG_FOOT.y
		const double shade = 1.0 - cfg.contact * ft;
		const double angle = double(rng.randf()) * TAU;
		double roll = rng.randf();
		if (ft > 0.0 && roll < THATCH_SHARE * ft) {
			const Color straw(cfg.thatch_straw.r * float(shade), cfg.thatch_straw.g * float(shade), cfg.thatch_straw.b * float(shade));
			const Basis b = lean(angle, Vector3(1.45, 0.5, 1.45) * float(size));
			add(-1, p, size, true, straw, true, b);
			return;
		}
		const bool shaded = shade < 1.0;
		const Color tint = Color(float(shade), float(shade), float(shade));
		roll = rng.randf();
		if (roll < TUSSOCK_SHARE * (0.4 + wild)) {
			const Basis b = lean(angle, Vector3(1.3, 1.6, 1.3) * float(size));
			add(-1, p, size, shaded, tint, true, b);
			for (int k = 0; k < 2; ++k) {
				const Vector2 dir = from_angle(angle + PI * (0.3 + double(k) * 1.1));
				const Vector2 q = p + dir * rng.randf_range(float(0.14), float(0.3));
				const double s2 = size * double(rng.randf_range(1.0f, 1.25f));
				add(-1, q, s2, shaded, tint, false, Basis());
			}
		} else {
			if (cfg.tilt > 0.0) {
				const Basis b = lean(angle, Vector3(1, 1, 1) * float(size));
				add(-1, p, size, shaded, tint, true, b);
			} else add(-1, p, size, shaded, tint, false, Basis());
		}
		if (double(rng.randf()) < SEED_SHARE * (0.3 + wild) && cfg.wheat >= 0) {
			const Kind &w = cfg.kinds[size_t(cfg.wheat)];
			const double wsize = rng.randf_range(float(0.7), float(1.0));
			const double wangle = double(rng.randf()) * TAU;
			double rsize;
			bool has_pose;
			Basis pose;
			form(w, wsize, wangle, 1.0, rsize, has_pose, pose);
			Color wt;
			const bool tinted = kind_tint(w, double(rng.randf()), wt);
			const Vector2 at = p + from_angle(double(rng.randf()) * TAU) * float(0.2);
			add(w.asset, at, rsize, tinted, wt, has_pose, pose);
		}
	}

	Vector2 bloom_at(const Vector2 &p) const {
		const double u = clampf((double(p.x) - x0) / cfg.tint_step, 0.0, double(tg) - 1.001);
		const double v = clampf((double(p.y) - z0) / cfg.tint_step, 0.0, double(tg) - 1.001);
		const int i = int(u), j = int(v);
		const double fu = u - i, fv = v - j;
		const double w = lerpf(lerpf(blooms[j * tg + i].x, blooms[j * tg + i + 1].x, fu), lerpf(blooms[(j + 1) * tg + i].x, blooms[(j + 1) * tg + i + 1].x, fu), fv);
		return Vector2(float(w), blooms[(j + roundi(fv)) * tg + i + roundi(fu)].y);
	}

	// MeadowTypes over the alpine type (presence, kind_at, variant).
	Vector2 warped(const Vector2 &p) const {
		return p + Vector2(float(nz(m_warp, p.x, p.y)), float(nz(m_warp, double(p.y) + 31.0, double(p.x) - 17.0))) * float(0.55);
	}
	static int weighted(const std::vector<double> &weights, double roll) {
		double total = 0.0;
		for (double w : weights) total += w;
		roll *= total;
		for (size_t i = 0; i < weights.size(); ++i) {
			roll -= weights[i];
			if (roll < 0.0) return int(i);
		}
		return int(weights.size()) - 1;
	}
	double presence(const Vector2 &p) const {
		const double at = lerpf(0.42, -0.42, cfg.meadow_cover);
		const double rim = std::pow(std::pow(std::fabs(double(p.x)), 4.0) + std::pow(std::fabs(double(p.y)), 4.0), 0.25);
		return smoothstep(at - 0.12, at + 0.22, nz(m_drift, p.x, p.y)) * (1.0 - smoothstep(fq(1.0e6), fq(2.0e6), rim));
	}
	int kind_at(const Vector2 &p, double roll) const {
		const Vector2 q = warped(p);
		const double u = clampf(nz(m_species, q.x, q.y) * 0.5 + 0.5, 0.0, 0.999);
		const int first = weighted(cfg.meadow_weights, u);
		const int count = int(cfg.meadow_kinds.size());
		if (roll < cfg.meadow_mix && count > 1) {
			int second = weighted(cfg.meadow_weights, fposmod(u * 7.31 + 0.13, 0.999));
			if (second == first) second = (first + 1) % count;
			return cfg.meadow_kinds[size_t(second)];
		}
		return cfg.meadow_kinds[size_t(first)];
	}
	double variant(const Vector2 &p) const {
		const Vector2 q = warped(p);
		return fposmod(nz(m_species, q.x, q.y) * 0.5 + 0.5 + 0.37, 1.0);
	}

	void grow(int64_t grow_seed) {
		const int seed_value = int(grow_seed);
		rng.seed(uint64_t(grow_seed));
		godot_noise(drift, seed_value + 5, FNL::NoiseType_OpenSimplex2S, DRIFT_FREQUENCY, FNL::FractalType_FBm, 5);
		const int plant_seed = seed_value + 9;
		godot_noise(m_drift, plant_seed + 1901, FNL::NoiseType_OpenSimplex2S, cfg.meadow_frequency, FNL::FractalType_FBm, 2);
		godot_noise(m_species, plant_seed + 1907, FNL::NoiseType_Cellular, cfg.meadow_frequency * 1.25, FNL::FractalType_None, 5);
		m_species.SetCellularReturnType(FNL::CellularReturnType_CellValue);
		m_species.SetCellularJitter(float(0.9));
		godot_noise(m_warp, plant_seed + 1913, FNL::NoiseType_OpenSimplex2S, 0.9, FNL::FractalType_FBm, 5);

		box_pos = Vector2(float(x0), float(z0));
		const Vector2 box_size(64.0f, 64.0f);
		box_end = box_pos + box_size;
		const double box_area = double(box_size.x * box_size.y);
		const int64_t grass_n = int64_t(box_area * cfg.tufts);
		const bool walk_wild = cfg.shag > 0.0 || cfg.variety;
		foot_x0 = int(floori(x0)) - 2;
		foot_z0 = int(floori(z0)) - 2;
		foot_n = 68;
		feet.assign(size_t(foot_n * foot_n), std::numeric_limits<float>::quiet_NaN());
		ragged_d.assign(size_t(n * n), DNAN);
		// Grass: every candidate at full thickness (the carpet), its height
		// rolling.
		for (int64_t c = 0; c < grass_n; ++c) {
			const float px = rng.randf_range(box_pos.x, box_end.x); // (in order: C++ leaves argument order open)
			const float pz = rng.randf_range(box_pos.y, box_end.y);
			const Vector2 p(px, pz);
			if (dithered_out(p)) continue;
			double thick = 1.0;
			const double roll = cfg.height_field > 0.0 ? rolling(p) : 0.0;
			if (cfg.height_field > 0.0) thick *= 1.0 - HEIGHT_THICK * 0.5 * (1.0 - roll);
			if (double(rng.randf()) > thick * (1.0 - smoothstep(PATH_THIN, PATH_BARE, 0.0))) continue;
			// The cell's outline lies 16 m round it: every point is past the
			// rim (`e` INF), so the rim keeps nothing back and reach is REACH.
			double size = double(rng.randf_range(float(0.85), float(1.45))) * lerpf(1.0, 0.75, 0.0);
			const double wild = walk_wild ? maxf(1.0 - smoothstep(fq(0.3), fq(3.0), DINF), foot(p)) : 0.0;
			if (cfg.shag > 0.0 || cfg.tuft_bump != 1.0) size *= shag_of(p, wild);
			if (cfg.height_field > 0.0) size *= 1.0 + cfg.height_field * roll;
			if (cfg.variety) tuft(p, size, wild);
			else add(-1, p, size, false, Color(), false, Basis());
		}
		// Flowers: the meadow type's drifts, sown sparse; the drifts' kinds.
		if (!cfg.flowers) return;
		const int64_t flower_n = int64_t(box_area * cfg.flower_tries);
		const bool lift_on = !is_equal_approx(cfg.flower_tall, 1.0);
		for (int64_t c = 0; c < flower_n; ++c) {
			const float px = rng.randf_range(box_pos.x, box_end.x); // (in order: C++ leaves argument order open)
			const float pz = rng.randf_range(box_pos.y, box_end.y);
			const Vector2 p(px, pz);
			if (dithered_out(p)) continue;
			const double pres = presence(p);
			int kind = kind_at(p, rng.randf());
			double var = -1.0;
			double drift_by;
			if (!blooms.empty()) {
				const Vector2 b = bloom_at(p);
				if (!(double(b.x) < cfg.bloom_kind) && !(hash_unit(p.x, p.y, 53.0) < cfg.bloom_companion)) {
					const int slot = int(b.y);
					kind = cfg.bloom_kinds[size_t(slot)];
					var = cfg.bloom_variants[size_t(slot)];
				}
				drift_by = 1.0 + (cfg.bloom_peak - 1.0) * double(b.x);
			} else {
				const double nn = Patch::noise(double(p.x) / cfg.drift_scale + 17.3, double(p.y) / cfg.drift_scale - 5.1);
				drift_by = 1.0 + (double(cfg.drift_z) - 1.0) * smoothstep(cfg.drift_x, cfg.drift_y, nn);
			}
			const Kind &k = cfg.kinds[size_t(kind)];
			double keep = std::pow(pres, 1.2) * k.packing * FLOWER_SHARE;
			keep *= drift_by;
			if (double(rng.randf()) > maxf(keep, STRAY)) continue;
			double lift = 1.0;
			if (lift_on) {
				const double h = hash_unit(p.x, p.y, 31.0);
				lift = 1.0 + (cfg.flower_tall - 1.0) * (double(cfg.flower_lift_x) + (double(cfg.flower_lift_y) - double(cfg.flower_lift_x)) * h);
			}
			const double fsize = rng.randf_range(k.size_lo, k.size_hi);
			const double fangle = double(rng.randf()) * TAU;
			double rsize;
			bool has_pose;
			Basis pose;
			form(k, fsize, fangle, lift, rsize, has_pose, pose);
			Color t;
			const bool tinted = !k.tints.empty() && kind_tint(k, var >= 0.0 ? var : variant(p), t);
			add(k.asset, p, rsize, tinted, t, has_pose, pose);
		}
	}
};

} // namespace zsgrass

using namespace godot;

// ZenScapeGrass: endless_grass.gd makes one per layer (`_native_config`),
// shared by its workers (grow_cell keeps no state on it).
class ZenScapeGrass : public RefCounted {
	GDCLASS(ZenScapeGrass, RefCounted)

	zsgrass::Config cfg;
	Dictionary ring_base;
	bool far_share_all = false;
	double far_share = 0.0;

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("version"), &ZenScapeGrass::version);
		ClassDB::bind_method(D_METHOD("configure", "config"), &ZenScapeGrass::configure);
		ClassDB::bind_method(D_METHOD("grow_cell", "cell"), &ZenScapeGrass::grow_cell);
		ClassDB::bind_method(D_METHOD("assets"), &ZenScapeGrass::assets);
		ClassDB::bind_method(D_METHOD("hash_check", "x", "y"), &ZenScapeGrass::hash_check);
		ClassDB::bind_method(D_METHOD("randf_check", "seed", "count"), &ZenScapeGrass::randf_check);
		ClassDB::bind_method(D_METHOD("cull_tiles", "boxes", "reach_of", "state", "show", "lods"), &ZenScapeGrass::cull_tiles);
	}

	// Whether the box at b (x0, z0, x1, z1) meets the disc at d (centre x, z,
	// radius squared; below zero: none).
	static bool tile_meets(const float *b, const float *d) {
		if (d[2] < 0.0f) return false;
		const double dx = MAX(MAX(double(b[0]) - double(d[0]), double(d[0]) - double(b[2])), 0.0);
		const double dz = MAX(MAX(double(b[1]) - double(d[1]), double(d[1]) - double(b[3])), 0.0);
		return dx * dx + dz * dz <= double(d[2]);
	}

	static double num(const Dictionary &d, const char *k, double fallback) {
		return d.has(k) ? double(d[k]) : fallback;
	}

public:
	// 2: grow_cell takes a band cell's dither. 3: the alpine tufts (config `alp`).
	int64_t version() const { return 3; }

	// endless_grass.gd `cull_tiles`, the same answers: one cell's tiles (a
	// box, a ring and a state each: bit 0 shown, the bits over it the far lod)
	// against its rings' discs (`show`) and the far lods' (`lods`: none, one
	// lod's two discs or two lods' four). The tiles whose state changed,
	// [index, new state] each. Keeps no state: the main thread's, every frame.
	PackedInt32Array cull_tiles(const PackedFloat32Array &boxes, const PackedByteArray &reach_of, const PackedByteArray &state, const PackedFloat32Array &show, const PackedFloat32Array &lods) const {
		PackedInt32Array out;
		const int64_t n = state.size();
		if (boxes.size() < n * 4 || reach_of.size() < n) return out;
		const float *b = boxes.ptr();
		const uint8_t *ro = reach_of.ptr();
		const uint8_t *st = state.ptr();
		const float *sh = show.ptr();
		const float *lo = lods.ptr();
		const int64_t rings = show.size() / 3;
		const bool has_lod = lods.size() >= 6;
		const bool has_lod2 = lods.size() >= 12;
		for (int64_t i = 0; i < n; i++) {
			if (ro[i] >= rings) continue;
			const float *box = b + i * 4;
			const int was = st[i];
			const int up = was >> 1;
			int tier = up;
			const bool shown = tile_meets(box, sh + ro[i] * 3);
			if (has_lod && shown) {
				tier = tile_meets(box, lo + (up >= 1 ? 0 : 3)) ? 0 : 1;
				if (tier == 1 && has_lod2 && !tile_meets(box, lo + (up >= 2 ? 6 : 9))) tier = 2;
			}
			const int now = (shown ? 1 : 0) | (tier << 1);
			if (now != was) {
				out.push_back(int32_t(i));
				out.push_back(now);
			}
		}
		return out;
	}

	// The flower assets a cell's records index (the config's `assets`).
	PackedStringArray assets() const { return cfg.assets; }

	int64_t hash_check(int64_t x, int64_t y) const { return zsgrass::hash_v2i(x, y); }
	PackedFloat32Array randf_check(int64_t seed, int64_t count) const {
		zsgrass::Pcg r;
		r.seed(uint64_t(seed));
		PackedFloat32Array out;
		for (int64_t i = 0; i < count; ++i) out.push_back(r.randf());
		return out;
	}

	void configure(const Dictionary &d) {
		using namespace zsgrass;
		cfg.tufts = num(d, "tufts", 4.6);
		cfg.tuft_bump = num(d, "tuft_bump", 1.0);
		cfg.shag = num(d, "shag", 0.0);
		cfg.contact = num(d, "contact", 0.0);
		cfg.height_field = num(d, "height_field", 0.0);
		cfg.tilt = num(d, "tilt", 0.0);
		cfg.rim = num(d, "rim", -1.0);
		cfg.variety = bool(d.get("variety", false));
		cfg.flowers = bool(d.get("flowers", false));
		cfg.patches = num(d, "patches", 1.0);
		cfg.flower_tall = num(d, "flower_tall", 1.0);
		cfg.sub = num(d, "sub", 0.0);
		const Vector2 sl = d.get("slope", Vector2(0.83, 0.88));
		cfg.slope_x = sl.x;
		cfg.slope_y = sl.y;
		const Vector2 al = d.get("alpine", Vector2(0.3, 0.7));
		cfg.alpine_x = al.x;
		cfg.alpine_y = al.y;
		const Vector2 hi = d.get("high", Vector2(36.0, 58.0));
		cfg.high_x = hi.x;
		cfg.high_y = hi.y;
		cfg.flower_tries = num(d, "flower_tries", 2.2);
		cfg.lod = d.get("lod", Vector4());
		cfg.lod_grow = d.get("lod_grow", Vector2(1.5, 1.25));
		cfg.lod_soft = num(d, "lod_soft", 6.0);
		far_share = num(d, "far_share", 0.0);
		cfg.patch.offset = d.get("patch_offset", Vector2());
		cfg.patch.region_amount = num(d, "region_amount", 1.0);
		cfg.patch.bloom_amount = num(d, "bloom_amount", 1.0);
		cfg.patch.plain = d.get("plain", Vector3());
		cfg.tint_step = num(d, "tint_step", 2.0);
		cfg.sink = num(d, "sink", 0.04);
		cfg.sea_y = num(d, "sea_y", -40.0);
		cfg.beach_clear = num(d, "beach_clear", 2.55);
		cfg.beach_ramp = num(d, "beach_ramp", 0.35);
		cfg.rock_near = num(d, "rock_near", 0.95);
		cfg.alpine_top = num(d, "alpine_top", 84.0);
		cfg.tuft_tone = d.get("tuft_tone", Color(1, 1, 1));
		cfg.thatch_straw = d.get("thatch_straw", Color(1, 1, 1));
		cfg.bloom_peak = num(d, "bloom_peak", 16.0);
		cfg.bloom_companion = num(d, "bloom_companion", 0.12);
		cfg.bloom_kind = num(d, "bloom_kind", 0.12);
		cfg.far_wash = num(d, "far_wash", 0.35);
		const Vector3 dr = d.get("drift", Vector3(0.68, 0.82, 6.0));
		cfg.drift_x = dr.x;
		cfg.drift_y = dr.y;
		cfg.drift_z = dr.z;
		cfg.drift_scale = num(d, "drift_scale", 55.0);
		const Vector2 fl = d.get("flower_lift", Vector2(0.8, 1.3));
		cfg.flower_lift_x = fl.x;
		cfg.flower_lift_y = fl.y;
		cfg.grass_parts.clear();
		const Array parts = d.get("grass_parts", Array());
		for (int64_t i = 0; i < parts.size(); ++i) {
			const Dictionary p = parts[i];
			GrassPart g;
			g.key = p.get("key", "");
			g.pose = p.get("pose", Transform3D());
			g.tint = p.get("tint", Color(1, 1, 1));
			g.ringed = bool(p.get("ringed", false));
			cfg.grass_parts.push_back(g);
		}
		cfg.assets = d.get("assets", PackedStringArray());
		cfg.kinds.clear();
		const Array kinds = d.get("kinds", Array());
		for (int64_t i = 0; i < kinds.size(); ++i) {
			const Dictionary k = kinds[i];
			Kind kd;
			kd.asset = int(k.get("asset", -1));
			kd.packing = num(k, "packing", 1.0);
			const Vector2 sz = k.get("sizes", Vector2(0.85, 1.1));
			kd.size_lo = sz.x;
			kd.size_hi = sz.y;
			kd.standing_in = bool(k.get("standing_in", false));
			kd.head = num(k, "head", 0.0);
			kd.height = num(k, "height", 0.0);
			kd.fb_top = num(k, "fb_top", 1.0);
			kd.fb_head = num(k, "fb_head", 1.0);
			const PackedColorArray tints = k.get("tints", PackedColorArray());
			for (int64_t t = 0; t < tints.size(); ++t) kd.tints.push_back(tints[t]);
			cfg.kinds.push_back(kd);
		}
		cfg.meadow_kinds.clear();
		cfg.meadow_weights.clear();
		const PackedInt32Array mk = d.get("meadow_kinds", PackedInt32Array());
		const PackedFloat64Array mw = d.get("meadow_weights", PackedFloat64Array());
		for (int64_t i = 0; i < mk.size(); ++i) cfg.meadow_kinds.push_back(mk[i]);
		for (int64_t i = 0; i < mw.size(); ++i) cfg.meadow_weights.push_back(mw[i]);
		cfg.meadow_cover = num(d, "meadow_cover", 0.62);
		cfg.meadow_frequency = num(d, "meadow_frequency", 0.2);
		cfg.meadow_mix = num(d, "meadow_mix", 0.3);
		cfg.bloom_kinds.clear();
		cfg.bloom_variants.clear();
		const PackedInt32Array bk = d.get("bloom_kinds", PackedInt32Array());
		const PackedFloat64Array bv = d.get("bloom_variants", PackedFloat64Array());
		for (int64_t i = 0; i < bk.size(); ++i) cfg.bloom_kinds.push_back(bk[i]);
		for (int64_t i = 0; i < bv.size(); ++i) cfg.bloom_variants.push_back(bv[i]);
		cfg.wheat = int(d.get("wheat", -1));
		const Dictionary alp = d.get("alp", Dictionary());
		cfg.alp_share = num(alp, "share", 0.0);
		cfg.alp_tall = num(alp, "tall", 0.5);
		cfg.alp_wide = num(alp, "wide", 1.1);
		cfg.alp_tone = alp.get("tone", Color(1, 1, 1));
		const Vector2 als = alp.get("slope", Vector2(0.87, 0.93));
		cfg.alp_slope_x = als.x;
		cfg.alp_slope_y = als.y;
		const Vector2 alt = alp.get("top", Vector2(79.0, 95.0));
		cfg.alp_top_x = alt.x;
		cfg.alp_top_y = alt.y;
		const Vector2 alz = alp.get("zone_top", Vector2(140.0, 170.0));
		cfg.alp_zone_top_x = alz.x;
		cfg.alp_zone_top_y = alz.y;
		cfg.alp_zone = alp.get("zone", Vector4());
		cfg.alp_proud = bool(alp.get("proud", false));
		const Vector2 alb = alp.get("bare", Vector2(0.25, 0.0));
		cfg.alp_bare_x = alb.x;
		cfg.alp_bare_y = alb.y;
		const PackedFloat32Array off = alp.get("off", PackedFloat32Array());
		cfg.alp_off.assign(off.ptr(), off.ptr() + off.size());
		cfg.alp_off_box = alp.get("off_box", Vector4());
		ring_base = Dictionary();
		ring_base["lod"] = cfg.lod;
		ring_base["share"] = far_share;
		ring_base["grow"] = cfg.lod_grow;
		ring_base["soft"] = cfg.lod_soft;
		far_share_all = far_share >= 1.0;
	}

	// One cell: {x0, z0, n, pad, seed (KitFlora's), heights, river, meadows,
	// field (the native land field, for the ground's colour) or colours (its
	// colour on the TINT_STEP grid), dither, dither_grid, dither_count,
	// dither_group (a band cell's, Cell `dither_w`; optional)} -> {parts: grow_cell's grass parts,
	// records: the flowers' and seed heads' (stride 18: asset, x, z, angle,
	// scale, h, tinted, r, g, b, posed, basis columns x9)}.
	Dictionary grow_cell(const Dictionary &d) const {
		using namespace zsgrass;
		const double x0 = d["x0"], z0 = d["z0"];
		const int n = int(d["n"]), pad = int(d["pad"]);
		const int64_t grow_seed = d["seed"];
		const PackedFloat32Array hs_a = d["heights"], rs_a = d["river"], ms_a = d["meadows"];
		const float *hs = hs_a.ptr(), *rs = rs_a.ptr(), *ms = ms_a.ptr();
		Dictionary out;
		Array parts_out;
		out["parts"] = parts_out;
		out["records"] = PackedFloat64Array();
		// No turf in it at all (the sea, the peaks): nothing to grow.
		const double top = cfg.alpine_y > 0.0f ? cfg.alpine_top : double(cfg.high_y);
		bool any = false;
		for (int64_t i = 0; i < hs_a.size(); ++i) {
			const double over = double(hs[i]) - cfg.sea_y;
			if (over >= cfg.beach_clear && over < top) {
				any = true;
				break;
			}
		}
		// The alpine tufts' turf (up to their top, the Peak's the highest).
		bool alp_any = false;
		bool alp_high = false;
		if (cfg.alp_share > 0.0) {
			const double alp_top = maxf(cfg.alp_top_y, cfg.alp_zone_top_y);
			for (int64_t i = 0; i < hs_a.size(); ++i) {
				const double over = double(hs[i]) - cfg.sea_y;
				if (over > Patch::ALPINE_FROM && over < alp_top) alp_any = true;
				if (over > 50.0) alp_high = true;
				if (alp_any && alp_high) break;
			}
		}
		if (!any && !alp_any) return out;
		Cell cell(cfg, x0, z0, n, pad, hs, rs, ms);
		const PackedFloat32Array dither_a = d.get("dither", PackedFloat32Array());
		if (!dither_a.is_empty()) {
			cell.dither_grid = int(d.get("dither_grid", 3));
			cell.dither_count = int(d.get("dither_count", 1));
			cell.dither_group = int(d.get("dither_group", 0));
			if (dither_a.size() >= cell.dither_grid * cell.dither_grid * cell.dither_count) cell.dither_w = dither_a.ptr();
		}
		cell.b00 = Patch::broad(x0, z0);
		cell.b10 = Patch::broad(x0 + 64.0, z0);
		cell.b01 = Patch::broad(x0, z0 + 64.0);
		cell.b11 = Patch::broad(x0 + 64.0, z0 + 64.0);
		const int tg = int(64.0 / cfg.tint_step) + 1;
		cell.tg = tg;
		if (cfg.patch.bloom_amount > 0.0) {
			cell.blooms.resize(size_t(tg * tg));
			for (int tj = 0; tj < tg; ++tj)
				for (int ti = 0; ti < tg; ++ti) cell.blooms[size_t(tj * tg + ti)] = cfg.patch.bloom(x0 + ti * cfg.tint_step, z0 + tj * cfg.tint_step);
		}
		// (A cell with no carpet turf grows none of it: the alpine tufts alone.)
		if (any) cell.grow(grow_seed);
		Object *field_obj = d.get("field", Variant());
		ZenScapeLandField *field = Object::cast_to<ZenScapeLandField>(field_obj);
		if (alp_any) {
			// The proud crowns (rock_shape.gd `grid`'s 40 m radius: the node
			// against the ring round it), off the field, or the cell's `ring`
			// heights (ALP_PROUD_N + 10 a side, ALP_PROUD_STEP m apart, from
			// x0 - 40, z0 - 40) where it has no native field.
			const PackedFloat32Array ring = d.get("ring", PackedFloat32Array());
			const int N = Cell::ALP_PROUD_N, R = 5, D = 4, M = N + 2 * R;
			const double st = Cell::ALP_PROUD_STEP;
			if (cfg.alp_proud && alp_high && (field != nullptr || ring.size() == M * M)) {
				const double zx = double(cfg.alp_zone.x), zz = double(cfg.alp_zone.y), zr = double(cfg.alp_zone.z);
				const bool all_zone = cfg.alp_zone.w > 0.5 && Vector2(float(x0 + 32.0 - zx), float(z0 + 32.0 - zz)).length() < zr - 600.0 - 50.0;
				if (!all_zone) {
					std::vector<float> g(size_t(M * M));
					for (int jj = 0; jj < M; ++jj)
						for (int ii = 0; ii < M; ++ii)
							g[size_t(jj * M + ii)] = field != nullptr ? float(field->height(x0 + (ii - R) * st, z0 + (jj - R) * st)) : ring[jj * M + ii];
					const double a = 0.7 / (R * st) * 0.0625;
					cell.proud.resize(size_t(N * N));
					for (int jj = 0; jj < N; ++jj) {
						for (int ii = 0; ii < N; ++ii) {
							const int q = (jj + R) * M + ii + R;
							const double s = double(g[q]) * 8.0 - g[q - R] - g[q + R] - g[q - R * M] - g[q + R * M] - g[q - D - D * M] - g[q + D - D * M] - g[q - D + D * M] - g[q + D + D * M];
							cell.proud[size_t(jj * N + ii)] = float(clampd(0.5 + s * a, 0.0, 1.0));
						}
					}
				}
			}
			cell.grow_alpine(grow_seed);
		}
		// The painted ground's patches on each tuft, off a TINT_STEP m grid.
		std::vector<Color> tints(size_t(tg * tg));
		const PackedColorArray cols = d.get("colours", PackedColorArray());
		for (int tj = 0; tj < tg; ++tj) {
			for (int ti = 0; ti < tg; ++ti) {
				const int c = (int(tj * cfg.tint_step) + pad) * n + int(ti * cfg.tint_step) + pad;
				const double x = x0 + ti * cfg.tint_step;
				const double z = z0 + tj * cfg.tint_step;
				const double y = hs[c];
				const Vector3 normal = Vector3(dif(hs[c - 1], hs[c + 1]), 2.0f, dif(hs[c - n], hs[c + n])).normalized();
				Color vc;
				if (field != nullptr) vc = field->colour(x, z, y, normal.y, ms[c]);
				else vc = cols[tj * tg + ti];
				const Vector3 hue(float(std::pow(double(vc.r), 2.2)), float(std::pow(double(vc.g), 2.2)), float(std::pow(double(vc.b), 2.2)));
				tints[size_t(tj * tg + ti)] = Color(1, 1, 1).lerp(cfg.patch.tint(x, z, ms[c], y - cfg.sea_y, normal.y, hue), float(cfg.patches)) * cfg.tuft_tone;
			}
		}
		// The draw: records by KitFlora tile, each tile's grass parts, split
		// into the rings (the far share by lot, as Draw `_rings`).
		std::vector<std::pair<int64_t, std::vector<int>>> tiles;
		std::unordered_map<int64_t, size_t> tile_at;
		PackedFloat64Array recs;
		for (size_t r = 0; r < cell.records.size(); ++r) {
			const Record &rec = cell.records[r];
			const int64_t tx = floori(rec.x / double(TILE)), tz = floori(rec.z / double(TILE));
			const int64_t key = (tx << 32) ^ (tz & 0xffffffffLL);
			auto it = tile_at.find(key);
			if (it == tile_at.end()) {
				tile_at[key] = tiles.size();
				tiles.push_back({key, {}});
				it = tile_at.find(key);
			}
			tiles[it->second].second.push_back(int(r));
			if (rec.asset >= 0) {
				const double row[20] = {double(rec.asset), rec.x, rec.z, rec.angle, rec.scale, rec.h, rec.has_tint ? 1.0 : 0.0,
					rec.tint.r, rec.tint.g, rec.tint.b, rec.has_pose ? 1.0 : 0.0,
					rec.pose.rows[0][0], rec.pose.rows[1][0], rec.pose.rows[2][0],
					rec.pose.rows[0][1], rec.pose.rows[1][1], rec.pose.rows[2][1],
					rec.pose.rows[0][2], rec.pose.rows[1][2], rec.pose.rows[2][2]};
				for (double v : row) recs.push_back(v);
			}
		}
		out["records"] = recs;
		const bool colored = cfg.grass_parts.size() == 1;
		std::vector<float> list;
		for (auto &tile : tiles) {
			const Vector2i tkey(int32_t(tile.first >> 32), int32_t(tile.first & 0xffffffffLL));
			for (const GrassPart &part : cfg.grass_parts) {
				list.clear();
				for (int r : tile.second) {
					const Record &rec = cell.records[size_t(r)];
					if (rec.asset >= 0) continue;
					const Basis basis = rec.has_pose ? rec.pose : axis_angle(Vector3(0, 1, 0), rec.angle).scaled(Vector3(1, 1, 1) * float(rec.scale));
					const Transform3D t = (Transform3D(basis, Vector3(float(rec.x), float(rec.h), float(rec.z))) * part.pose) * Transform3D();
					Color col = rec.has_tint && colored ? rec.tint : part.tint;
					if (rec.alpine) col = Color(col.r * cfg.alp_tone.r, col.g * cfg.alp_tone.g, col.b * cfg.alp_tone.b, col.a);
					const float row[16] = {t.basis.rows[0][0], t.basis.rows[0][1], t.basis.rows[0][2], t.origin.x,
						t.basis.rows[1][0], t.basis.rows[1][1], t.basis.rows[1][2], t.origin.y,
						t.basis.rows[2][0], t.basis.rows[2][1], t.basis.rows[2][2], t.origin.z,
						col.r, col.g, col.b, col.a};
					list.insert(list.end(), row, row + 16);
				}
				if (list.empty()) continue;
				const int64_t count = int64_t(list.size() / 16);
				if (!part.ringed) {
					emit(parts_out, part.key, tkey, list, Dictionary(), x0, z0, tg, tints, cell);
					continue;
				}
				// Draw `_rings`: the far share by lot.
				Array id;
				id.push_back(grow_seed);
				id.push_back(part.key);
				id.push_back(tkey);
				Pcg lot;
				lot.seed(uint64_t(UtilityFunctions::hash(id)));
				std::vector<float> split[2];
				for (int64_t i = 0; i < count; ++i) {
					const int k = double(lot.randf()) < far_share ? 1 : 0;
					split[k].insert(split[k].end(), list.begin() + i * 16, list.begin() + i * 16 + 16);
				}
				for (int k = 0; k < 2; ++k) {
					if (split[k].empty()) continue;
					Dictionary r = ring_base.duplicate();
					r["ring"] = k + 1;
					// The far layer is the grass alone in the far ring.
					if (far_share_all && k + 1 != 2) continue;
					emit(parts_out, part.key, tkey, split[k], r, x0, z0, tg, tints, cell);
				}
			}
		}
		return out;
	}

private:
	// grow_cell's pass over one grass batch (the patches' tint, the far
	// ring's drift wash) and its parts (split into SUB m tiles near).
	void emit(Array &parts, const String &key, const Vector2i &tile, std::vector<float> &buf, const Dictionary &ring, double x0, double z0, int tg,
			const std::vector<Color> &tints, const zsgrass::Cell &cell) const {
		using namespace zsgrass;
		const size_t count = buf.size() / 16;
		for (size_t k = 0; k < buf.size(); k += 16) {
			const double u = clampf((double(buf[k + 3]) - x0) / cfg.tint_step, 0.0, double(tg) - 1.001);
			const double v = clampf((double(buf[k + 11]) - z0) / cfg.tint_step, 0.0, double(tg) - 1.001);
			const int i = int(u), j = int(v);
			const Color a = tints[size_t(j * tg + i)].lerp(tints[size_t(j * tg + i + 1)], float(u - i));
			const Color b = tints[size_t((j + 1) * tg + i)].lerp(tints[size_t((j + 1) * tg + i + 1)], float(u - i));
			const Color t = a.lerp(b, float(v - j));
			if (far_share_all && !cell.blooms.empty()) {
				const Vector2 bl = cell.bloom_at(Vector2(buf[k + 3], buf[k + 11]));
				if (double(bl.x) > 0.0 && hash_unit(buf[k + 3], buf[k + 11], 37.0) < double(bl.x) * cfg.far_wash)
					buf[k + 15] = float(double(int(bl.y) + 1) / 16.0);
			}
			buf[k + 12] = float(double(buf[k + 12]) * double(t.r));
			buf[k + 13] = float(double(buf[k + 13]) * double(t.g));
			buf[k + 14] = float(double(buf[k + 14]) * double(t.b));
		}
		if (!far_share_all && cfg.sub > 0.0) {
			const double size = cfg.sub;
			std::vector<std::pair<int64_t, std::vector<size_t>>> by;
			std::unordered_map<int64_t, size_t> at;
			for (size_t k = 0; k < buf.size(); k += 16) {
				const int64_t sx = int32_t(floori(double(buf[k + 3]) / size)), sz = int32_t(floori(double(buf[k + 11]) / size));
				const int64_t skey = (sx << 32) ^ (sz & 0xffffffffLL);
				auto it = at.find(skey);
				if (it == at.end()) {
					at[skey] = by.size();
					by.push_back({skey, {}});
					it = at.find(skey);
				}
				by[it->second].second.push_back(k);
			}
			for (auto &s : by) {
				PackedFloat32Array b;
				b.resize(int64_t(s.second.size() * 16));
				float *w = b.ptrw();
				for (size_t i = 0; i < s.second.size(); ++i)
					for (int q = 0; q < 16; ++q) w[i * 16 + q] = buf[s.second[i] + q];
				Dictionary part;
				part["key"] = key;
				part["tile"] = tile;
				part["count"] = int64_t(s.second.size());
				part["buffer"] = b;
				part["ring"] = ring;
				part["box"] = roots_box(w, s.second.size());
				part["sub"] = Vector2i(int32_t(s.first >> 32), int32_t(s.first & 0xffffffffLL));
				parts.push_back(part);
			}
			return;
		}
		PackedFloat32Array b;
		b.resize(int64_t(buf.size()));
		float *w = b.ptrw();
		for (size_t i = 0; i < buf.size(); ++i) w[i] = buf[i];
		Dictionary part;
		part["key"] = key;
		part["tile"] = tile;
		part["count"] = int64_t(count);
		part["buffer"] = b;
		part["ring"] = ring;
		part["box"] = roots_box(w, count);
		parts.push_back(part);
	}

	static Rect2 roots_box(const float *b, size_t count) {
		if (count < 1) return Rect2();
		double x0 = b[3], x1 = x0, z0 = b[11], z1 = z0;
		for (size_t k = 1; k < count; ++k) {
			x0 = zsgrass::minf(x0, b[k * 16 + 3]);
			x1 = zsgrass::maxf(x1, b[k * 16 + 3]);
			z0 = zsgrass::minf(z0, b[k * 16 + 11]);
			z1 = zsgrass::maxf(z1, b[k * 16 + 11]);
		}
		return Rect2(float(x0), float(z0), float(x1 - x0), float(z1 - z0));
	}
};
