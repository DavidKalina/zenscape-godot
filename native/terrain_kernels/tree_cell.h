// The endless forests' placement in C++ (docs/design/endless-flight/native-trees-handoff.md):
// scripts/endless/tree_plan.gd (`area`, `far_cell`, `floor_grid`) and the
// building half of scripts/endless/land_trees.gd (`_build_block`'s instance
// buffers, `_build_far`'s, `_floor_arrays`), line for line, as ZenScapeTrees.
// The land is read from the worker's own native field (ZenScapeLandField)
// with the ponds LandField would cut in (land_ponds.gd `at`, `carve`) passed
// in, and the arches near the square (TreePlan `_arches_near`) likewise;
// GDScript keeps the arches, the ponds' making and each cell's lookup.
//
// Matching GDScript: numbers are doubles, Vector2/3, Basis, Color and the
// packed float arrays hold floats (see grass_cell.h, whose engine helpers
// this reuses: PCG32, the Variant hash's murmur, FastNoiseLite as the engine
// sets it up, the engine's float cos and sin). The candidates are sorted with
// the engine's own SortArray, so equal ranks fall as Array.sort_custom has them.
#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/templates/hashfuncs.hpp>
#include <godot_cpp/templates/sort_array.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/basis.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include "land_field_bind.h"
#include "grass_cell.h"
#include <cmath>
#include <cstdint>
#include <unordered_map>
#include <vector>

namespace zstrees {

using godot::Basis;
using godot::Color;
using godot::Vector2;
using godot::Vector2i;
using godot::Vector3;
using FNL = fastnoiselite::FastNoiseLite;
using zsgrass::fq;
using zsgrass::TAU;
using zsland::clampf;
using zsland::lerpf;
using zsland::maxf;
using zsland::minf;
using zsland::smoothstep;

inline int64_t floori(double v) { return int64_t(std::floor(v)); }
inline int64_t roundi(double v) { return int64_t(std::round(v)); }
inline int64_t clampi(int64_t v, int64_t lo, int64_t hi) { return v < lo ? lo : (v > hi ? hi : v); }
constexpr double DINF = std::numeric_limits<double>::infinity();

// --- tree_plan.gd's constants (Vector2/3 ones read as floats: fq) -------------------
enum { DENSE = 0, GROVE = 1, LONE = 2 };
constexpr int STRIDE = 8;
constexpr double CELL = 128.0, SLOT = 6.0, FAR_CELL = 1024.0, FAR_SLOT = 24.0;
constexpr double SPACE_AT = 0.5, BORDER = 2.0, GAP_LONE = 9.0;
constexpr double TAKE_DENSE = 0.95, TAKE_GROVE = 0.85, LONE_P = 0.0022;
constexpr double DENSE_AT = 0.47, GROVE_AT = 0.36, EDGE = 0.035, SHARE_SHIFT = 0.4;
constexpr double CLUMP_ON = 0.1, CLUMP_SOFT = 0.08;
constexpr double LANE = 320.0, CLEARING_ON = 0.42;
constexpr double VALLEY_BIAS = 0.08, RIVER_BIAS = 0.14;
constexpr double BEACH_CLEAR = 5.0, RIVER_KEEP = 4.0;
constexpr double MEADOW_WILD = -0.05;
constexpr double FLAT_SLOPE = 0.06, FLAT_REACH = 32.0, FLAT_STEP = 16.0;
constexpr double FLOOR_GROVE = 0.7, ARCH_CLEAR = 18.0, ARCH_APPROACH = 110.0, SINK = 0.35;
constexpr double SEA_Y = -40.0;
constexpr double FOREST = 1500.0, CLUMP = 75.0, CLEARING = 140.0, MEADOW_KEEP = 1100.0;

// Vector2(x, y) constants as float pairs.
struct F2 {
	float x, y;
};
const F2 GAP_DENSE{1.0f, 1.5f}, GAP_GROVE{1.5f, 3.2f};
const F2 STEEP{0.8f, 0.88f}, TREE_LINE{60.0f, 82.0f}, MEADOW_OFF{0.1f, 0.28f}, MEADOW_DEEP{0.75f, 0.92f};
const F2 RIVER_BAND{6.0f, 70.0f};
const F2 SIZE_DENSE{3.0f, 4.4f}, SIZE_GROVE{2.4f, 4.0f}, SIZE_LONE{3.6f, 4.6f};
const F2 WIDE_DENSE{1.35f, 1.7f}, WIDE_LONE{1.15f, 1.35f};
const F2 FAR_GROW{1.9f, 1.25f};
const float SLOPE_BIAS[3] = {0.995f, 0.95f, 0.1f};
const float HIGH_BIAS[3] = {12.0f, 38.0f, 0.08f};
const float COAST[3] = {5.0f, 18.0f, 0.25f};
const float FAR_KEEP[3] = {0.24f, 0.3f, 1.0f};
const float DENSITY[3] = {40.0f, 35.0f, 0.025f};

// --- land_trees.gd's constants -------------------------------------------------------
constexpr double BLOCK = 256.0, DETAIL_TILE = 64.0;
constexpr float MID_SIZE = 0.94f;
const F2 TINT_SPREAD{0.86f, 1.04f};

// --- land_ponds.gd -------------------------------------------------------------------
constexpr double PONDS_CELL = 400.0, POND_REACH = 40.0, BOWL = 0.3, BANK_RISE = 0.14;
constexpr double LIP_X = 5.0, LIP_Y = 9.0;

struct Pond {
	double p[12];
	int64_t ci = 0, cj = 0;
};

// Ponds.at: Vector3(distance outside its edge, from its centre, its radius that way).
inline Vector3 pond_at(const Pond &pd, double x, double z) {
	const double *p = pd.p;
	const double dx = x - p[0];
	const double dz = z - p[1];
	const double far = p[11] + POND_REACH;
	if (std::fabs(dx) > far || std::fabs(dz) > far) return Vector3(float(DINF), 0.0f, 0.0f);
	const double r = std::sqrt(dx * dx + dz * dz);
	if (r > far) return Vector3(float(DINF), 0.0f, 0.0f);
	const double a = std::atan2(dz, dx);
	const double edge = p[2] * (1.0 + p[5] * std::sin(2.0 * a + p[6]) + p[7] * std::sin(3.0 * a + p[8]) + p[9] * std::sin(5.0 * a + p[10]));
	return Vector3(float(r - edge), float(r), float(edge));
}

// Ponds.carve
inline double pond_carve(const Pond &pd, double base, const Vector3 &e) {
	const double *p = pd.p;
	const double level = p[3];
	const double ex = e.x;
	if (ex < 0.0) {
		const double s = double(e.y) / maxf(double(e.z), 0.01);
		return minf(base, level - p[4] * (1.0 - smoothstep(BOWL, 1.0, s)));
	}
	if (ex > LIP_Y && base < level + BANK_RISE * ex) return base;
	double h = minf(base, level + BANK_RISE * ex);
	const double lip = 1.0 - smoothstep(LIP_X, LIP_Y, ex);
	if (lip > 0.0) h = maxf(h, lerpf(h, level + 0.06 + 0.08 * ex, lip));
	return h;
}

// The land's shape at a point, as tree_plan reads LandField.shape's dictionary.
struct Shape {
	double height = 0.0, meadow = 0.0, valley = DINF, half = 0.0, side = 0.0, river = DINF;
};

// The engine's Variant hash of [a, b, c, d] (four ints).
inline uint32_t hash4(int64_t a, int64_t b, int64_t c, int64_t d) {
	uint32_t h = godot::hash_murmur3_one_32(28u); // Variant::ARRAY
	h = godot::hash_murmur3_one_32(godot::hash_one_uint64(uint64_t(a)), h);
	h = godot::hash_murmur3_one_32(godot::hash_one_uint64(uint64_t(b)), h);
	h = godot::hash_murmur3_one_32(godot::hash_one_uint64(uint64_t(c)), h);
	h = godot::hash_murmur3_one_32(godot::hash_one_uint64(uint64_t(d)), h);
	return godot::hash_fmix32(h);
}

struct Config {
	int64_t seed = 1;
	double share = 1.0, meadows = 1.0;
	double gap = 0.0, lane_open = 0.0;
	std::vector<Vector3> dims;
	std::vector<float> weights;
	FNL forest, clump, lane, lane_warp, clearing, meadow_keep;
	// The block building's.
	Color tint;
	std::vector<Vector3> crown_fit;
	bool detail = false, rings = false;

	void noise(FNL &n, int salt, double scale, int octaves, FNL::FractalType kind) {
		zsgrass::godot_noise(n, int(seed * 6271 + salt * 92821 + 17), FNL::NoiseType_OpenSimplex2S, 1.0 / scale, kind, octaves);
	}
	void setup() {
		noise(forest, 1, FOREST, 3, FNL::FractalType_FBm);
		noise(clump, 2, CLUMP, 2, FNL::FractalType_FBm);
		noise(lane, 3, LANE, 1, FNL::FractalType_None);
		noise(lane_warp, 4, LANE * 0.6, 1, FNL::FractalType_None);
		noise(clearing, 5, CLEARING, 2, FNL::FractalType_FBm);
		noise(meadow_keep, 6, MEADOW_KEEP, 2, FNL::FractalType_FBm);
	}
};

struct Cand {
	double px, pz, rank, creach, g;
	int64_t kind, si, sj, v;
	double sc, wd;
};
struct CandOrder {
	bool operator()(const Cand &a, const Cand &b) const { return a.rank > b.rank; }
};

// The land a plan reads (LandField `sample` and `shape`): one native field,
// or the regions' band (ZenScapeLandBand) as LandBlend reads it: the one
// region's field in a pure lattice cell, else each slot sampled and blended
// by weight, the valley's from the heaviest. `h`, `m`: the last sample's
// height and meadow unrounded (the blend's are doubles).
struct Land {
	zsland::LandField *one = nullptr;
	const ZenScapeLandField::Band *band = nullptr;
	std::vector<float> w;
	double h = 0.0, m = 0.0;
	double last_valley = DINF, last_half = 0.0, last_side = 0.0, last_river = DINF;

	// `shape`: as LandField.shape (a field's own reset first; the blend's
	// slots are sampled as they stand).
	zsland::V2 sample(double x, double z, bool shape) {
		zsland::LandField *k = one;
		if (band != nullptr) {
			if (!band->covers(x, z)) {
				const double lo = band->lattice * 0.5;
				const double hix = (double(band->ci0 + band->cw - 1) - 0.5) * band->lattice, hiz = (double(band->cj0 + band->ch - 1) - 0.5) * band->lattice;
				const double cx = std::min(std::max(x, double(band->ci0) * band->lattice + lo), hix);
				const double cz = std::min(std::max(z, double(band->cj0) * band->lattice + lo), hiz);
				const int r = band->slots_at(cx, cz, w.data());
				if (r >= 0) k = &band->fields[size_t(r)]->land();
			} else {
				const int r = band->slots_at(x, z, w.data());
				if (r >= 0) k = &band->fields[size_t(r)]->land();
			}
		}
		if (k != nullptr) {
			if (shape) k->shape_reset();
			const zsland::V2 s = k->sample(x, z);
			h = double(s.x);
			m = double(s.y);
			last_valley = k->last_valley;
			last_half = k->last_half;
			last_side = k->last_side;
			last_river = k->last_river;
			return s;
		}
		double hh = 0.0, mm = 0.0, river = 0.0, best = -1.0;
		zsland::LandField *kid = nullptr;
		for (size_t s = 0; s < band->fields.size(); ++s) {
			const double wt = double(w[s]);
			if (wt <= 0.0) continue;
			zsland::LandField &f = band->fields[s]->land();
			const zsland::V2 got = f.sample(x, z);
			if (wt > best) {
				best = wt;
				kid = &f;
			}
			hh += wt * double(got.x);
			mm += wt * double(got.y);
			river += wt * std::min(f.last_river, 1000.0);
		}
		h = hh;
		m = mm;
		last_river = river;
		if (kid != nullptr) {
			last_valley = kid->last_valley;
			last_half = kid->last_half;
			last_side = kid->last_side;
		}
		return zsland::V2(hh, mm);
	}
};

// One plan's work (a TreePlan made for one task): the field, the ponds, the
// flats' caches and `last_wild`.
struct Planner {
	const Config &cfg;
	Land &f;
	std::vector<Pond> ponds;
	std::unordered_map<int64_t, bool> flats;
	std::unordered_map<int64_t, double> heights;
	double last_wild = 0.0;

	Planner(const Config &c, Land &field) :
			cfg(c), f(field) {}

	static int64_t key2(int64_t i, int64_t j) { return (i << 32) ^ (j & 0xffffffffLL); }

	const Pond *pond_for(double x, double z) const {
		if (ponds.empty()) return nullptr;
		const int64_t ci = floori(x / PONDS_CELL), cj = floori(z / PONDS_CELL);
		for (const Pond &p : ponds)
			if (p.ci == ci && p.cj == cj) return &p;
		return nullptr;
	}

	// LandField.height: the native field's, or its sample with the pond cut in.
	double height(double x, double z) {
		const zsland::V2 s = f.sample(x, z, false);
		float h = s.x;
		const Pond *p = pond_for(x, z);
		if (p != nullptr) {
			const Vector3 e = pond_at(*p, x, z);
			if (double(e.x) < POND_REACH && double(e.x) < LIP_Y) h = float(pond_carve(*p, double(h), e));
		}
		return double(h);
	}

	// LandField.shape
	Shape shape(double x, double z) {
		f.sample(x, z, true);
		Shape out;
		out.height = f.h;
		out.meadow = f.m;
		out.valley = f.last_valley;
		out.half = f.last_half;
		out.side = f.last_side;
		out.river = f.last_river;
		const Pond *p = pond_for(x, z);
		if (p != nullptr) {
			const Vector3 e = pond_at(*p, x, z);
			if (double(e.x) < POND_REACH) {
				const bool on = double(e.x) < out.river;
				const double h = double(e.x) < LIP_Y ? pond_carve(*p, out.height, e) : out.height;
				out.height = h;
				if (on) out.river = double(e.x);
			}
		}
		return out;
	}

	double hash01(int64_t i, int64_t j, int64_t salt) const {
		return double(hash4(cfg.seed, i, j, salt) & 0xffffffu) / 16777216.0;
	}

	int64_t variant(double r) const {
		double total = 0.0;
		for (float w : cfg.weights) total += double(w);
		double roll = r * total;
		for (size_t i = 0; i < cfg.weights.size(); ++i) {
			roll -= double(cfg.weights[i]);
			if (roll <= 0.0) return int64_t(i);
		}
		return 0;
	}

	double node_height(int64_t i, int64_t j) {
		const int64_t k = key2(i, j);
		auto it = heights.find(k);
		if (it != heights.end()) return it->second;
		const double h = height(double(i) * FLAT_STEP, double(j) * FLAT_STEP);
		heights[k] = h;
		return h;
	}

	bool flat(double x, double z) {
		const int64_t i = roundi(x / FLAT_STEP);
		const int64_t j = roundi(z / FLAT_STEP);
		const int64_t k = key2(i, j);
		auto it = flats.find(k);
		if (it != flats.end()) return it->second;
		const int64_t r = roundi(FLAT_REACH / FLAT_STEP);
		const double most = FLAT_SLOPE * double(r) * FLAT_STEP * 2.0;
		bool fl = std::fabs(node_height(i + r, j) - node_height(i - r, j)) <= most;
		if (fl) fl = std::fabs(node_height(i, j + r) - node_height(i, j - r)) <= most;
		flats[k] = fl;
		return fl;
	}

	double suits(double x, double z, const Shape &s, double up) {
		const double over = s.height - SEA_Y;
		if (over < BEACH_CLEAR) return 0.0;
		if (s.river < RIVER_KEEP) return 0.0;
		if (up < double(STEEP.x)) return 0.0;
		double k = smoothstep(STEEP.x, STEEP.y, up);
		k *= 1.0 - smoothstep(TREE_LINE.x, TREE_LINE.y, over);
		F2 off = MEADOW_OFF;
		last_wild = 0.0;
		const double v = s.valley;
		if (v < DINF && v < s.half) return 0.0;
		if (cfg.meadows > 0.0) {
			const double wild = smoothstep(MEADOW_WILD - 0.06, MEADOW_WILD + 0.06, -zsgrass::nz(cfg.meadow_keep, x, z) + (cfg.meadows - 1.0) * 0.3);
			const float w = float(wild);
			off.x = MEADOW_OFF.x + (MEADOW_DEEP.x - MEADOW_OFF.x) * w;
			off.y = MEADOW_OFF.y + (MEADOW_DEEP.y - MEADOW_OFF.y) * w;
			last_wild = wild * smoothstep(MEADOW_OFF.x, MEADOW_OFF.y, s.meadow);
			if (wild < 0.5 && flat(x, z)) return 0.0;
		} else if (flat(x, z))
			return 0.0;
		k *= 1.0 - smoothstep(off.x, off.y, s.meadow);
		return k;
	}

	double reach(double x, double z, const Shape &s, double up) const {
		double fv = zsgrass::nz(cfg.forest, x, z) * 0.62 + 0.5;
		const double over = s.height - SEA_Y;
		fv += double(SLOPE_BIAS[2]) * smoothstep(SLOPE_BIAS[0], SLOPE_BIAS[1], up);
		const double v = s.valley;
		const double half = s.half;
		if (v < DINF && v > half) fv += VALLEY_BIAS * (1.0 - smoothstep(half + s.side * 0.6, half + s.side * 1.4 + 20.0, v));
		const double r = s.river;
		if (r < DINF) fv += RIVER_BIAS * smoothstep(RIVER_BAND.x, double(RIVER_BAND.x) + 6.0, r) * (1.0 - smoothstep(double(RIVER_BAND.y) * 0.5, RIVER_BAND.y, r));
		fv += double(HIGH_BIAS[2]) * smoothstep(HIGH_BIAS[0], HIGH_BIAS[1], over);
		fv -= double(COAST[2]) * (1.0 - smoothstep(COAST[0], COAST[1], over));
		return fv + (cfg.share - 1.0) * SHARE_SHIFT;
	}

	Vector3 mask(double x, double z, const Shape &s, double up) {
		if (cfg.share <= 0.0) return Vector3();
		const double k = suits(x, z, s, up);
		if (k <= 0.0) return Vector3();
		const double fv = reach(x, z, s, up);
		double dense = smoothstep(DENSE_AT - EDGE, DENSE_AT + EDGE, fv);
		double grove = smoothstep(GROVE_AT - EDGE, GROVE_AT + EDGE, fv) * (1.0 - dense);
		if (dense > 0.0) {
			double open = 0.0;
			if (zsgrass::nz(cfg.clearing, x, z) > CLEARING_ON) open = 1.0;
			const double w = zsgrass::nz(cfg.lane_warp, x, z) * LANE * 0.35;
			const double l = std::fabs(zsgrass::nz(cfg.lane, x + w, z - w));
			if (l * LANE / 1.6 < cfg.lane_open * 0.5) open = 1.0;
			dense *= 1.0 - open;
		}
		grove += dense * last_wild;
		dense *= 1.0 - last_wild;
		return Vector3(float(dense), float(grove), float(1.0 - dense - grove)) * float(k);
	}

	double clump(double x, double z) const {
		return smoothstep(CLUMP_ON - CLUMP_SOFT, CLUMP_ON + CLUMP_SOFT, zsgrass::nz(cfg.clump, x, z));
	}

	static double floor_weight(const Vector3 &m, double c) {
		return clampf(double(m.x) + double(m.y) * c * FLOOR_GROVE, 0.0, 1.0);
	}

	// TreePlan._by_arch over [x, z, cos, sin, half span, half depth] sixes.
	static bool by_arch(const double *a, int64_t count, double x, double z) {
		for (int64_t q = 0; q < count; ++q) {
			const double *e = a + q * 6;
			const double ox = x - e[0];
			const double oz = z - e[1];
			if (std::fabs(ox) > 400.0 || std::fabs(oz) > 400.0) continue;
			const double lx = std::fabs(ox * e[2] - oz * e[3]);
			const double lz = std::fabs(ox * e[3] + oz * e[2]);
			if (lx < e[4] + ARCH_CLEAR && lz < e[5] + ARCH_CLEAR) return true;
			if (lx < e[4] && lz < e[5] + ARCH_APPROACH) return true;
		}
		return false;
	}

	double r_most() const {
		double r = 0.0;
		for (const Vector3 &d : cfg.dims) r = maxf(r, double(d.x));
		return r;
	}

	// TreePlan.area
	godot::PackedFloat32Array area(double x0, double z0, double size, const double *arches, int64_t arch_n) {
		godot::PackedFloat32Array out;
		if (cfg.share <= 0.0) return out;
		const double gap = cfg.gap;
		const double rm = r_most();
		const double reach_most = rm * maxf(SIZE_LONE.y, SIZE_DENSE.y) * maxf(WIDE_LONE.y, WIDE_DENSE.y) * SPACE_AT * 2.0 + gap * maxf(GAP_GROVE.y, GAP_DENSE.y);
		const int64_t border = int64_t(std::ceil(reach_most * BORDER / SLOT)) + 1;
		const int64_t i0 = floori(x0 / SLOT) - border;
		const int64_t j0 = floori(z0 / SLOT) - border;
		const int64_t n = int64_t(size / SLOT) + border * 2 + 2;
		std::vector<Shape> shapes(size_t(n * n));
		std::vector<float> hs(size_t(n * n));
		for (int64_t j = 0; j < n; ++j) {
			for (int64_t i = 0; i < n; ++i) {
				const Shape s = shape((double(i0 + i) + 0.5) * SLOT, (double(j0 + j) + 0.5) * SLOT);
				shapes[size_t(j * n + i)] = s;
				hs[size_t(j * n + i)] = float(s.height);
			}
		}
		std::vector<Cand> cand;
		cand.reserve(size_t(n * n / 2));
		for (int64_t j = 1; j < n - 1; ++j) {
			for (int64_t i = 1; i < n - 1; ++i) {
				const int64_t si = i0 + i;
				const int64_t sj = j0 + j;
				const double roll = hash01(si, sj, 1);
				const double gx = (double(hs[size_t(j * n + i + 1)]) - double(hs[size_t(j * n + i - 1)])) / (SLOT * 2.0);
				const double gz = (double(hs[size_t((j + 1) * n + i)]) - double(hs[size_t((j - 1) * n + i)])) / (SLOT * 2.0);
				const double up = 1.0 / std::sqrt(1.0 + gx * gx + gz * gz);
				const Shape &s = shapes[size_t(j * n + i)];
				const double px = (double(si) + hash01(si, sj, 2)) * SLOT;
				const double pz = (double(sj) + hash01(si, sj, 3)) * SLOT;
				const Vector3 m = mask(px, pz, s, up);
				int64_t kind = -1;
				if (roll < double(m.x) * TAKE_DENSE)
					kind = DENSE;
				else if (roll < double(m.x) * TAKE_DENSE + double(m.y) * TAKE_GROVE * clump(px, pz))
					kind = GROVE;
				else if (roll > 1.0 - double(m.z) * LONE_P)
					kind = LONE;
				if (kind < 0) continue;
				if (by_arch(arches, arch_n, px, pz)) continue;
				const int64_t v = variant(hash01(si, sj, 4));
				const F2 sizes = kind == DENSE ? SIZE_DENSE : (kind == GROVE ? SIZE_GROVE : SIZE_LONE);
				const F2 wide = kind == LONE ? WIDE_LONE : WIDE_DENSE;
				const double sc = lerpf(sizes.x, sizes.y, hash01(si, sj, 5));
				const double wd = lerpf(wide.x, wide.y, hash01(si, sj, 6));
				const F2 spread = kind == DENSE ? GAP_DENSE : GAP_GROVE;
				const double g = gap * (kind == LONE ? GAP_LONE : lerpf(spread.x, spread.y, hash01(si, sj, 7)));
				Cand c;
				c.px = px;
				c.pz = pz;
				c.rank = hash01(si, sj, 8);
				c.creach = double(cfg.dims[size_t(v)].x) * sc * wd * SPACE_AT;
				c.g = g;
				c.kind = kind;
				c.si = si;
				c.sj = sj;
				c.v = v;
				c.sc = sc;
				c.wd = wd;
				cand.push_back(c);
			}
		}
		if (!cand.empty()) {
			godot::SortArray<Cand, CandOrder, false> sorter;
			sorter.sort(cand.data(), int64_t(cand.size()));
		}
		std::vector<int32_t> grid(size_t(n * n), -1);
		std::vector<uint8_t> kept(cand.size(), 0);
		const double gap_most = gap * maxf(GAP_GROVE.y, GAP_DENSE.y);
		const double r_reach = rm * maxf(SIZE_LONE.y, SIZE_DENSE.y) * maxf(WIDE_LONE.y, WIDE_DENSE.y) * SPACE_AT;
		for (size_t k = 0; k < cand.size(); ++k) {
			const Cand &c = cand[k];
			const int64_t gi = c.si - i0;
			const int64_t gj = c.sj - j0;
			const int64_t slots = int64_t(std::ceil((c.creach + r_reach + maxf(c.g, gap_most)) / SLOT)) + 1;
			bool ok = true;
			const int64_t dj1 = std::min<int64_t>(gj + slots + 1, n), di1 = std::min<int64_t>(gi + slots + 1, n);
			for (int64_t dj = std::max<int64_t>(gj - slots, 0); dj < dj1 && ok; ++dj) {
				for (int64_t di = std::max<int64_t>(gi - slots, 0); di < di1; ++di) {
					const int32_t other = grid[size_t(dj * n + di)];
					if (other < 0) continue;
					const Cand &o = cand[size_t(other)];
					const double need = c.creach + o.creach + maxf(c.g, o.g);
					const double dx = c.px - o.px;
					const double dz = c.pz - o.pz;
					if (dx * dx + dz * dz < need * need) {
						ok = false;
						break;
					}
				}
			}
			if (ok) {
				grid[size_t(gj * n + gi)] = int32_t(k);
				kept[k] = 1;
			}
		}
		for (size_t k = 0; k < cand.size(); ++k) {
			if (kept[k] == 0) continue;
			const Cand &c = cand[k];
			if (c.px < x0 || c.px >= x0 + size || c.pz < z0 || c.pz >= z0 + size) continue;
			const double y = height(c.px, c.pz);
			const double hx = height(c.px + 1.0, c.pz);
			const double hz = height(c.px, c.pz + 1.0);
			const double tilt = Vector2(float(hx - y), float(hz - y)).length();
			const float row[STRIDE] = {float(c.px), float(y - SINK - tilt * c.creach * 0.3), float(c.pz), float(c.sc), float(c.wd),
				float(hash01(c.si, c.sj, 9) * TAU), float(double(c.v)), float(double(c.kind))};
			for (int q = 0; q < STRIDE; ++q) out.push_back(row[q]);
		}
		return out;
	}

	// TreePlan.far_cell
	godot::Dictionary far_cell(int64_t cx, int64_t cz, const double *arches, int64_t arch_n) {
		godot::PackedFloat32Array out;
		const int64_t own = int64_t(FAR_CELL / FAR_SLOT);
		const int64_t n = own + 4;
		const int64_t i0 = floori(double(cx) * FAR_CELL / FAR_SLOT) - 2;
		const int64_t j0 = floori(double(cz) * FAR_CELL / FAR_SLOT) - 2;
		godot::Dictionary got;
		got["trees"] = out;
		got["h"] = godot::PackedFloat32Array();
		got["w"] = godot::PackedFloat32Array();
		got["n"] = n;
		got["x"] = (double(i0) + 0.5) * FAR_SLOT;
		got["z"] = (double(j0) + 0.5) * FAR_SLOT;
		got["step"] = FAR_SLOT;
		if (cfg.share <= 0.0) return got;
		const double x0 = double(cx) * FAR_CELL;
		const double z0 = double(cz) * FAR_CELL;
		godot::PackedFloat32Array hs;
		hs.resize(n * n);
		float *hp = hs.ptrw();
		std::vector<Shape> shapes(size_t(n * n));
		for (int64_t j = 0; j < n; ++j) {
			for (int64_t i = 0; i < n; ++i) {
				const Shape s = shape((double(i0 + i) + 0.5) * FAR_SLOT, (double(j0 + j) + 0.5) * FAR_SLOT);
				shapes[size_t(j * n + i)] = s;
				hp[j * n + i] = float(s.height);
			}
		}
		godot::PackedFloat32Array ws;
		ws.resize((n - 2) * (n - 2));
		float *wp = ws.ptrw();
		const Vector3 per = Vector3(DENSITY[0], DENSITY[1], DENSITY[2]) * float(FAR_SLOT) * float(FAR_SLOT) / float(10000.0);
		for (int64_t j = 1; j < n - 1; ++j) {
			for (int64_t i = 1; i < n - 1; ++i) {
				const int64_t si = i0 + i;
				const int64_t sj = j0 + j;
				const double cxm = (double(si) + 0.5) * FAR_SLOT;
				const double czm = (double(sj) + 0.5) * FAR_SLOT;
				const double gx = (double(hp[j * n + i + 1]) - double(hp[j * n + i - 1])) / (FAR_SLOT * 2.0);
				const double gz = (double(hp[(j + 1) * n + i]) - double(hp[(j - 1) * n + i])) / (FAR_SLOT * 2.0);
				const double up = 1.0 / std::sqrt(1.0 + gx * gx + gz * gz);
				const Vector3 m = mask(cxm, czm, shapes[size_t(j * n + i)], up);
				const double c = clump(cxm, czm);
				wp[(j - 1) * (n - 2) + i - 1] = float(floor_weight(m, c));
				const double px = (double(si) + 0.5 + (hash01(si, sj, 12) - 0.5) * 0.8) * FAR_SLOT;
				const double pz = (double(sj) + 0.5 + (hash01(si, sj, 13) - 0.5) * 0.8) * FAR_SLOT;
				if (px < x0 || px >= x0 + FAR_CELL || pz < z0 || pz >= z0 + FAR_CELL) continue;
				const double dpart = double(m.x) * double(per.x) * double(FAR_KEEP[0]);
				const double gpart = double(m.y) * c * double(per.y) * double(FAR_KEEP[1]);
				const double want = dpart + gpart + double(m.z) * double(per.z) * double(FAR_KEEP[2]);
				const double roll = hash01(si, sj, 11);
				if (roll >= want) continue;
				const int64_t kind = roll < dpart ? DENSE : (roll < dpart + gpart ? GROVE : LONE);
				if (by_arch(arches, arch_n, px, pz)) continue;
				const F2 sz = kind == DENSE ? SIZE_DENSE : (kind == GROVE ? SIZE_GROVE : SIZE_LONE);
				const double sc = lerpf(sz.x, sz.y, hash01(si, sj, 15));
				const F2 grow = kind != LONE ? FAR_GROW : F2{1.0f, 1.0f};
				const double y = height(px, pz);
				const float row[STRIDE] = {float(px), float(y - SINK), float(pz), float(sc * double(grow.y)),
					float(double(grow.x) / double(grow.y) * (kind == LONE ? double(WIDE_LONE.x) : 1.1)), float(hash01(si, sj, 16) * TAU),
					float(double(variant(hash01(si, sj, 14)))), float(double(kind))};
				for (int q = 0; q < STRIDE; ++q) out.push_back(row[q]);
			}
		}
		got["trees"] = out;
		got["h"] = hs;
		got["w"] = ws;
		return got;
	}

	// TreePlan.floor_grid
	godot::Dictionary floor_grid(double x0, double z0, double size, double step) {
		const int64_t own = int64_t(size / step);
		const int64_t n = own + 4;
		const double ox = x0 - 1.5 * step;
		const double oz = z0 - 1.5 * step;
		godot::PackedFloat32Array hs;
		hs.resize(n * n);
		float *hp = hs.ptrw();
		std::vector<Shape> shapes(size_t(n * n));
		for (int64_t j = 0; j < n; ++j) {
			for (int64_t i = 0; i < n; ++i) {
				const Shape s = shape(ox + double(i) * step, oz + double(j) * step);
				shapes[size_t(j * n + i)] = s;
				hp[j * n + i] = float(s.height);
			}
		}
		godot::PackedFloat32Array ws;
		ws.resize((n - 2) * (n - 2));
		float *wp = ws.ptrw();
		for (int64_t q = 0; q < (n - 2) * (n - 2); ++q) wp[q] = 0.0f;
		if (cfg.share > 0.0) {
			for (int64_t j = 1; j < n - 1; ++j) {
				for (int64_t i = 1; i < n - 1; ++i) {
					const double x = ox + double(i) * step;
					const double z = oz + double(j) * step;
					const double gx = (double(hp[j * n + i + 1]) - double(hp[j * n + i - 1])) / (step * 2.0);
					const double gz = (double(hp[(j + 1) * n + i]) - double(hp[(j - 1) * n + i])) / (step * 2.0);
					const Vector3 m = mask(x, z, shapes[size_t(j * n + i)], 1.0 / std::sqrt(1.0 + gx * gx + gz * gz));
					wp[(j - 1) * (n - 2) + i - 1] = float(floor_weight(m, clump(x, z)));
				}
			}
		}
		godot::Dictionary got;
		got["h"] = hs;
		got["w"] = ws;
		got["n"] = n;
		got["x"] = ox;
		got["z"] = oz;
		got["step"] = step;
		return got;
	}
};

// land_trees.gd `_put`: a MultiMesh instance (TRANSFORM_3D with colours).
inline void put(godot::PackedFloat32Array &buf, const Basis &b, const Vector3 &o, const Color &c) {
	const float row[16] = {b.rows[0][0], b.rows[0][1], b.rows[0][2], o.x, b.rows[1][0], b.rows[1][1], b.rows[1][2], o.y,
		b.rows[2][0], b.rows[2][1], b.rows[2][2], o.z, c.r, c.g, c.b, c.a};
	const int64_t at = buf.size();
	buf.resize(at + 16);
	float *p = buf.ptrw() + at;
	for (int q = 0; q < 16; ++q) p[q] = row[q];
}

// land_trees.gd `_floor_arrays`.
inline godot::Dictionary floor_arrays(const godot::Dictionary &g) {
	godot::Dictionary none;
	const int64_t n = int64_t(g["n"]);
	const godot::PackedFloat32Array hs = g["h"];
	const godot::PackedFloat32Array raw = g["w"];
	if (raw.is_empty()) return none;
	const double step = double(g["step"]);
	const double ox = double(g["x"]);
	const double oz = double(g["z"]);
	const int64_t wn = n - 2;
	const float *hp = hs.ptr();
	const float *rp = raw.ptr();
	std::vector<float> ws(size_t(n * n), 0.0f);
	bool any = false;
	for (int64_t j = 2; j < n - 1; ++j) {
		for (int64_t i = 2; i < n - 1; ++i) {
			double sum = 0.0;
			for (int64_t dj = -1; dj < 2; ++dj) {
				for (int64_t di = -1; di < 2; ++di) {
					const int64_t ri = clampi(i - 1 + di, 0, wn - 1);
					const int64_t rj = clampi(j - 1 + dj, 0, wn - 1);
					sum += double(rp[rj * wn + ri]);
				}
			}
			ws[size_t(j * n + i)] = float(sum / 9.0);
			if (sum > 0.18) any = true;
		}
	}
	if (!any) return none;
	godot::PackedVector3Array verts, normals;
	godot::PackedColorArray colours;
	godot::PackedInt32Array index;
	std::vector<int32_t> at(size_t(n * n), -1);
	for (int64_t j = 2; j < n - 2; ++j) {
		for (int64_t i = 2; i < n - 2; ++i) {
			if (maxf(maxf(ws[size_t(j * n + i)], ws[size_t(j * n + i + 1)]), maxf(ws[size_t((j + 1) * n + i)], ws[size_t((j + 1) * n + i + 1)])) <= 0.02) continue;
			int32_t q[4];
			const int64_t cs[4][2] = {{i, j}, {i + 1, j}, {i + 1, j + 1}, {i, j + 1}};
			for (int c = 0; c < 4; ++c) {
				const int64_t k = cs[c][1] * n + cs[c][0];
				if (at[size_t(k)] < 0) {
					at[size_t(k)] = int32_t(verts.size());
					verts.push_back(Vector3(float(ox + double(cs[c][0]) * step), hp[k], float(oz + double(cs[c][1]) * step)));
					normals.push_back(Vector3(float(double(hp[k - 1]) - double(hp[k + 1])), float(step * 2.0), float(double(hp[k - n]) - double(hp[k + n]))).normalized());
					colours.push_back(Color(1, 1, 1, ws[size_t(k)]));
				}
				q[c] = at[size_t(k)];
			}
			const int32_t tri[6] = {q[0], q[1], q[2], q[0], q[2], q[3]};
			for (int t = 0; t < 6; ++t) index.push_back(tri[t]);
		}
	}
	godot::Array arrays;
	arrays.resize(13); // Mesh.ARRAY_MAX
	arrays[0] = verts; // ARRAY_VERTEX
	arrays[1] = normals; // ARRAY_NORMAL
	arrays[3] = colours; // ARRAY_COLOR
	arrays[12] = index; // ARRAY_INDEX
	godot::Dictionary out;
	out["arrays"] = arrays;
	return out;
}

} // namespace zstrees

// ZenScapeTrees: land_trees.gd makes one (`native`), shared by its workers;
// each call makes its own Planner over the worker's own field.
class ZenScapeTrees : public RefCounted {
	GDCLASS(ZenScapeTrees, RefCounted)

	zstrees::Config cfg;

	static std::vector<zstrees::Pond> ponds_of(const Array &list) {
		std::vector<zstrees::Pond> out;
		for (int64_t k = 0; k < list.size(); ++k) {
			const PackedFloat32Array p = list[k];
			if (p.size() < 12) continue;
			zstrees::Pond pd;
			for (int q = 0; q < 12; ++q) pd.p[q] = double(p[q]);
			pd.ci = zstrees::floori(pd.p[0] / zstrees::PONDS_CELL);
			pd.cj = zstrees::floori(pd.p[1] / zstrees::PONDS_CELL);
			out.push_back(pd);
		}
		return out;
	}

	// The land `o` is: a native field (ZenScapeLandField) or a band of them
	// (ZenScapeLandBand); false for neither.
	static bool land_of(Object *o, zstrees::Land &out) {
		ZenScapeLandField *f = Object::cast_to<ZenScapeLandField>(o);
		if (f != nullptr) {
			out.one = &f->land();
			return true;
		}
		ZenScapeLandBand *b = Object::cast_to<ZenScapeLandBand>(o);
		if (b == nullptr || b->band() == nullptr) return false;
		out.band = b->band();
		out.w.assign(out.band->fields.size(), 0.0f);
		return true;
	}

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("version"), &ZenScapeTrees::version);
		ClassDB::bind_method(D_METHOD("configure", "config"), &ZenScapeTrees::configure);
		ClassDB::bind_method(D_METHOD("area", "field", "x0", "z0", "size", "arches", "ponds"), &ZenScapeTrees::area);
		ClassDB::bind_method(D_METHOD("far_cell", "field", "cx", "cz", "arches", "ponds"), &ZenScapeTrees::far_cell);
		ClassDB::bind_method(D_METHOD("floor_grid", "field", "x0", "z0", "size", "step", "ponds"), &ZenScapeTrees::floor_grid);
		ClassDB::bind_method(D_METHOD("block", "field", "key", "arches", "ponds", "rng_seed", "floor"), &ZenScapeTrees::block);
		ClassDB::bind_method(D_METHOD("far", "field", "key", "arches", "ponds", "floor"), &ZenScapeTrees::far);
		ClassDB::bind_method(D_METHOD("hash_check", "a", "b", "c", "d"), &ZenScapeTrees::hash_check);
	}

public:
	int64_t version() const { return 1; }

	int64_t hash_check(int64_t a, int64_t b, int64_t c, int64_t d) const { return int64_t(zstrees::hash4(a, b, c, d)); }

	void configure(const Dictionary &d) {
		cfg.seed = int64_t(d.get("seed", 1));
		cfg.share = double(d.get("share", 1.0));
		cfg.meadows = double(d.get("meadows", 1.0));
		cfg.gap = double(d.get("gap", 0.0));
		cfg.lane_open = double(d.get("lane_open", 0.0));
		const PackedVector3Array dims = d.get("dims", PackedVector3Array());
		cfg.dims.assign(dims.ptr(), dims.ptr() + dims.size());
		const PackedFloat32Array w = d.get("weights", PackedFloat32Array());
		cfg.weights.assign(w.ptr(), w.ptr() + w.size());
		cfg.tint = d.get("tint", Color(1, 1, 1));
		const PackedVector3Array fit = d.get("crown_fit", PackedVector3Array());
		cfg.crown_fit.assign(fit.ptr(), fit.ptr() + fit.size());
		cfg.detail = bool(d.get("detail", false));
		cfg.rings = bool(d.get("rings", false));
		cfg.setup();
	}

	PackedFloat32Array area(Object *field, double x0, double z0, double size, const PackedFloat64Array &arches, const Array &ponds) {
		zstrees::Land f;
		ERR_FAIL_COND_V(!land_of(field, f), PackedFloat32Array());
		zstrees::Planner p(cfg, f);
		p.ponds = ponds_of(ponds);
		return p.area(x0, z0, size, arches.ptr(), arches.size() / 6);
	}

	Dictionary far_cell(Object *field, int64_t cx, int64_t cz, const PackedFloat64Array &arches, const Array &ponds) {
		zstrees::Land f;
		ERR_FAIL_COND_V(!land_of(field, f), Dictionary());
		zstrees::Planner p(cfg, f);
		p.ponds = ponds_of(ponds);
		return p.far_cell(cx, cz, arches.ptr(), arches.size() / 6);
	}

	Dictionary floor_grid(Object *field, double x0, double z0, double size, double step, const Array &ponds) {
		zstrees::Land f;
		ERR_FAIL_COND_V(!land_of(field, f), Dictionary());
		zstrees::Planner p(cfg, f);
		p.ponds = ponds_of(ponds);
		return p.floor_grid(x0, z0, size, step);
	}

	// land_trees.gd `_build_block` past the cells' lookup: {all (the plan's
	// trees), near (variant -> [trunks, crowns, count]), mid, tiles, floor}.
	Dictionary block(Object *field, const Vector2i &key, const PackedFloat64Array &arches, const Array &ponds, int64_t rng_seed, bool with_floor) {
		using namespace zstrees;
		zstrees::Land f;
		ERR_FAIL_COND_V(!land_of(field, f), Dictionary());
		Planner p(cfg, f);
		p.ponds = ponds_of(ponds);
		const PackedFloat32Array all = p.area(double(key.x) * BLOCK, double(key.y) * BLOCK, BLOCK, arches.ptr(), arches.size() / 6);
		const int64_t n = all.size() / STRIDE;
		const int64_t variants = int64_t(cfg.dims.size());
		std::vector<PackedFloat32Array> trunks((size_t)variants), crowns((size_t)variants);
		std::vector<int64_t> counts((size_t)variants, 0);
		PackedFloat32Array mid;
		const int64_t per_tile = int64_t(BLOCK / DETAIL_TILE);
		// tile index -> variant -> buffer, count
		std::vector<std::vector<PackedFloat32Array>> tile_bufs(size_t(per_tile * per_tile));
		std::vector<std::vector<int64_t>> tile_counts(size_t(per_tile * per_tile));
		std::vector<int64_t> tile_order;
		zsgrass::Pcg rng;
		rng.seed(uint64_t(rng_seed));
		const float *a = all.ptr();
		const Vector3 up(0, 1, 0);
		for (int64_t t = 0; t < n; ++t) {
			const int64_t q = t * STRIDE;
			const Vector3 at(a[q], a[q + 1], a[q + 2]);
			const double sc = a[q + 3];
			const double wide = a[q + 4];
			const double yaw = a[q + 5];
			const int64_t v = int64_t(a[q + 6]);
			const Basis basis = zsgrass::axis_angle(up, yaw).scaled(Vector3(float(sc * wide), float(sc), float(sc * wide)));
			const Color tone = cfg.tint * rng.randf_range(TINT_SPREAD.x, TINT_SPREAD.y);
			put(trunks[size_t(v)], basis, at, Color(1, 1, 1, 1));
			put(crowns[size_t(v)], basis, at, tone);
			counts[size_t(v)] += 1;
			if (cfg.detail) {
				const int64_t ti = clampi(int64_t((double(at.x) - double(key.x) * BLOCK) / DETAIL_TILE), 0, per_tile - 1) + per_tile * clampi(int64_t((double(at.z) - double(key.y) * BLOCK) / DETAIL_TILE), 0, per_tile - 1);
				if (tile_bufs[size_t(ti)].empty()) {
					tile_bufs[size_t(ti)].resize(size_t(variants));
					tile_counts[size_t(ti)].assign(size_t(variants), 0);
					tile_order.push_back(ti);
				}
				put(tile_bufs[size_t(ti)][size_t(v)], basis, at, tone);
				tile_counts[size_t(ti)][size_t(v)] += 1;
			}
			const Vector3 fit = cfg.crown_fit[size_t(v)];
			const Vector3 sv = Vector3(float(sc * wide * double(fit.x)), float(sc * double(fit.y)), float(sc * wide * double(fit.x))) * (cfg.rings ? 1.0f : MID_SIZE);
			const Basis cb = zsgrass::axis_angle(up, yaw).scaled(sv);
			const Color mc = cfg.rings ? tone : Color(float(double(tone.r) / double(cfg.tint.r)), float(double(tone.g) / double(cfg.tint.g)), float(double(tone.b) / double(cfg.tint.b)));
			put(mid, cb, at + Vector3(0.0f, float(double(fit.z) * sc), 0.0f), mc);
		}
		Array near;
		for (int64_t v = 0; v < variants; ++v) {
			Array slot;
			slot.push_back(trunks[size_t(v)]);
			slot.push_back(crowns[size_t(v)]);
			slot.push_back(counts[size_t(v)]);
			near.push_back(slot);
		}
		Dictionary tiles;
		for (int64_t ti : tile_order) {
			Array per_v;
			for (int64_t v = 0; v < variants; ++v) {
				Array e;
				e.push_back(tile_bufs[size_t(ti)][size_t(v)]);
				e.push_back(tile_counts[size_t(ti)][size_t(v)]);
				per_v.push_back(e);
			}
			tiles[ti] = per_v;
		}
		Dictionary out;
		out["all"] = all;
		out["near"] = near;
		out["mid"] = mid;
		out["tiles"] = tiles;
		out["floor"] = with_floor ? floor_arrays(p.floor_grid(double(key.x) * BLOCK, double(key.y) * BLOCK, BLOCK, 16.0)) : Dictionary();
		return out;
	}

	// land_trees.gd `_build_far`: {buf, n, floor}.
	Dictionary far(Object *field, const Vector2i &key, const PackedFloat64Array &arches, const Array &ponds, bool with_floor) {
		using namespace zstrees;
		zstrees::Land f;
		ERR_FAIL_COND_V(!land_of(field, f), Dictionary());
		Planner p(cfg, f);
		p.ponds = ponds_of(ponds);
		const Dictionary got = p.far_cell(key.x, key.y, arches.ptr(), arches.size() / 6);
		const PackedFloat32Array trees = got["trees"];
		const int64_t n = trees.size() / STRIDE;
		const float *a = trees.ptr();
		PackedFloat32Array buf;
		buf.resize(n * 16);
		buf.resize(0);
		const Vector3 up(0, 1, 0);
		for (int64_t t = 0; t < n; ++t) {
			const int64_t q = t * STRIDE;
			const int64_t v = int64_t(a[q + 6]);
			const Vector3 fit = cfg.crown_fit[size_t(v)];
			const double sc = a[q + 3];
			const double wide = a[q + 4];
			const Basis cb = zsgrass::axis_angle(up, double(a[q + 5])).scaled(Vector3(float(sc * wide * double(fit.x)), float(sc * double(fit.y)), float(sc * wide * double(fit.x))));
			const double shade = lerpf(TINT_SPREAD.x, TINT_SPREAD.y, zsgrass::fposmod(double(a[q]) * 0.37 + double(a[q + 2]) * 0.61, 1.0));
			const Color c = cfg.rings ? cfg.tint * float(shade) : Color(float(shade), float(shade), float(shade));
			put(buf, cb, Vector3(a[q], float(double(a[q + 1]) + double(fit.z) * sc), a[q + 2]), c);
		}
		Dictionary out;
		out["buf"] = buf;
		out["n"] = n;
		out["floor"] = with_floor ? floor_arrays(got) : Dictionary();
		return out;
	}
};
