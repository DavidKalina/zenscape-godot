// The land field's carve layers (scripts/endless/land_field.gd `sample`): the
// ponds (land_ponds.gd `at`, `carve`), the slot halls (hall_sites.gd `carve`)
// and the split mountains (split_sites.gd `cut`), line for line. GDScript
// finds the sites (that samples the field) and publishes each square's site
// to the native field as it finds it (ZenScapeLandField `carve_put`); this
// only cuts them in. The tunnels, the Peak and the isles stay in GDScript.
//
// The carving shapes the land, so it must match the GDScript bit for bit: the
// same operation order in doubles, Vector2/Vector3 results rounded to floats
// where the GDScript makes one, float constants where the GDScript's are
// Vector2s, and land_math.h's sin/cos/atan2 unless `libm` (as the field).
#pragma once

#include <cmath>
#include <cstdint>
#include <vector>
#include "land_field.h"
#include "land_math.h"

namespace zscarve {

using zsland::clampf;
using zsland::lerpf;
using zsland::smoothstep;

inline double minf(double a, double b) { return a < b ? a : b; }
inline double maxf(double a, double b) { return a > b ? a : b; }
inline double signf(double v) { return v > 0.0 ? 1.0 : (v < 0.0 ? -1.0 : 0.0); }

struct Trig {
	bool libm = false;
	double sin(double v) const { return libm ? std::sin(v) : zsland::det_sin(v); }
	double cos(double v) const { return libm ? std::cos(v) : zsland::det_cos(v); }
	double atan2(double y, double x) const { return libm ? std::atan2(y, x) : zsland::det_atan2(y, x); }
};

// --- Ponds (land_ponds.gd) -------------------------------------------------------------

constexpr double P_REACH = 40.0;
constexpr double P_BOWL = 0.3;
constexpr double P_BANK_RISE = 0.14;
constexpr double P_LIP_X = 5.0, P_LIP_Y = 9.0;

struct PondAt {
	float out = 0, r = 0, edge = 0;
	bool far = true;
};

// `at`: Vector3(distance outside its edge, from its centre, its radius that way).
inline PondAt pond_at(const Trig &m, const float *p, double x, double z) {
	PondAt e;
	const double dx = x - p[0];
	const double dz = z - p[1];
	const double far = p[11] + P_REACH;
	if (std::fabs(dx) > far || std::fabs(dz) > far) return e;
	const double r = std::sqrt(dx * dx + dz * dz);
	if (r > far) return e;
	const double a = m.atan2(dz, dx);
	const double edge = p[2] * (1.0 + p[5] * m.sin(2.0 * a + p[6]) + p[7] * m.sin(3.0 * a + p[8]) + p[9] * m.sin(5.0 * a + p[10]));
	e.out = float(r - edge);
	e.r = float(r);
	e.edge = float(edge);
	e.far = false;
	return e;
}

inline double pond_carve(const float *p, double base, const PondAt &e) {
	const double level = p[3];
	const double ex = e.out;
	if (ex < 0.0) {
		const double s = double(e.r) / maxf(e.edge, 0.01);
		return minf(base, level - p[4] * (1.0 - smoothstep(P_BOWL, 1.0, s)));
	}
	if (ex > P_LIP_Y && base < level + P_BANK_RISE * ex) return base;
	double h = minf(base, level + P_BANK_RISE * ex);
	const double lip = 1.0 - smoothstep(P_LIP_X, P_LIP_Y, ex);
	if (lip > 0.0) h = maxf(h, lerpf(h, level + 0.06 + 0.08 * ex, lip));
	return h;
}

// --- Slot halls (hall_sites.gd) --------------------------------------------------------

constexpr double H_EDGE = 2.0;
constexpr double H_SHEER = 30.0;
constexpr double H_LEAN = 0.35;
constexpr double H_APRON = 16.0;
constexpr double H_GRADE = 0.25;

// `local`, both sites' (a Vector2: floats).
inline void site_local(const float *s, double x, double z, float &qx, float &qy) {
	const double dx = x - s[0];
	const double dz = z - s[1];
	qx = float(dx * s[2] + dz * s[3]);
	qy = float(-dx * s[3] + dz * s[2]);
}

inline double hall_carve(const float *s, double base, double x, double z) {
	float qx, qy;
	site_local(s, x, z, qx, qy);
	const double au = std::fabs(double(qx));
	const double av = std::fabs(double(qy));
	if (au > s[7] || av > s[8]) return base;
	double lid = s[6];
	const double past = au - s[4] - H_APRON;
	if (past > 0.0) lid += past * H_GRADE;
	if (base <= lid) return base;
	if (av <= s[5]) return lid;
	if (av <= s[5] + H_EDGE) return minf(base, lid + H_SHEER * (av - s[5]) / H_EDGE);
	return minf(base, lid + H_SHEER + (av - s[5] - H_EDGE) / H_LEAN);
}

// --- Split mountains (split_sites.gd) --------------------------------------------------

constexpr int K_WAVES = 15, K_TIERS = 16, K_LEVEL = 17, K_BENCH = 22, K_EDGE = 24, K_LEAN = 25;
constexpr int K_WANDER = 26, K_BUTTRESS = 28, K_FLARE = 30, K_STRATA = 32, K_TALUS = 34, K_BLOCK = 36;
constexpr double S_FLUTE_X = 6.0, S_FLUTE_Y = 1.0;
constexpr double S_BENCH_SCALE = 45.0;
constexpr double S_BENCH_RISE = 0.25;
// RIB_EDGE is a Vector2: floats.
const double S_RIB_EDGE_X = double(0.4f), S_RIB_EDGE_Y = double(0.6f);
constexpr double S_BLOCK_EDGE = 0.15;
constexpr double S_FLARE_SHARE = 0.35;
constexpr double S_FLARE_LOW = 0.2;
constexpr double S_FLARE_SOFT = 8.0;
constexpr double S_FLARE_LEAN = 1.1;
constexpr double S_EASE = 12.0;
constexpr double S_GRADE = 0.25;
constexpr double S_PI = 3.1415926535897932384626433833;

struct Split {
	const float *s;
	Trig m;

	// `_r`, GDScript's 64-bit ints (wrapping as two's complement).
	static double r(int64_t i, int64_t salt) {
		uint64_t h = (uint64_t(i) * 374761393ull + uint64_t(salt) * 668265263ull) & 0xffffffffull;
		h = ((h ^ (h >> 13)) * 1274126177ull) & 0xffffffffull;
		h = h ^ (h >> 16);
		return double(h & 0xffffull) / 65535.0;
	}
	static double vn(double t, int64_t salt) {
		const int64_t i = int64_t(std::floor(t));
		double f = t - double(i);
		f = f * f * (3.0 - 2.0 * f);
		return lerpf(r(i, salt), r(i + 1, salt), f);
	}
	// `path`: Vector2(offset, slope), floats.
	void path(double u, float &cx, float &cy) const {
		const double hl = s[4];
		const double k = S_PI * s[K_WAVES] / (2.0 * hl);
		if (std::fabs(u) >= hl) {
			cx = float(s[9] * m.cos(k * (signf(u) * hl + hl)));
			cy = 0.0f;
			return;
		}
		const double a = k * (u + hl);
		cx = float(s[9] * m.cos(a));
		cy = float(-double(s[9]) * k * m.sin(a));
	}
	double floor_at(double u) const {
		const double hl = s[4];
		double y = s[6] + clampf(u, -hl, hl) * s[10];
		const double past = std::fabs(u) - hl;
		if (past > 0.0) y += past * S_GRADE;
		return y;
	}
	double flare(double u) const {
		const double reach = minf(s[K_FLARE], s[4] * S_FLARE_SHARE);
		return smoothstep(s[4] - reach, s[4], std::fabs(u));
	}
	double half(double u) const { return s[5] * (1.0 + s[K_FLARE + 1] * flare(u)); }
	double blocks(double u, int64_t salt) const {
		const double t = u / s[K_BLOCK];
		const int64_t i = int64_t(std::floor(t));
		return s[K_BLOCK + 1] * lerpf(r(i - 1, salt), r(i, salt), smoothstep(0.0, S_BLOCK_EDGE, t - double(i)));
	}
	// `_back`: Vector2(m, the alcove's share), floats.
	void back(double u, int side, float &bx, float &by) const {
		const int64_t salt = int64_t(double(s[12])) + side * 17;
		const double wander = s[K_WANDER] * vn(u / s[K_WANDER + 1], salt + 3);
		const double bay = smoothstep(S_RIB_EDGE_X, S_RIB_EDGE_Y, vn(u / s[K_BUTTRESS + 1], salt + 5));
		const double flute = S_FLUTE_Y * vn(u / S_FLUTE_X, salt + 7);
		bx = float(wander + s[K_BUTTRESS] * bay + flute + blocks(u, salt + 19));
		by = float(bay);
	}
	double bench(double u, int64_t salt, int k, bool lowest) const {
		if (lowest) return s[K_BENCH + 1] + s[K_BLOCK + 1];
		return lerpf(s[K_BENCH], s[K_BENCH + 1], smoothstep(0.2, 0.8, vn(u / S_BENCH_SCALE + k * 3.7, salt + 9 + k * 13))) + blocks(u, salt + 23 + k * 7);
	}
	static double terrace(double t, double tread) {
		const double i = std::floor(t);
		return i + smoothstep(tread, 1.0, t - i);
	}
	double strata(double y0, double h, double f) const {
		const double step = s[K_STRATA];
		if (step <= 0.0 || h <= 0.0) return h;
		const double tread = s[K_STRATA + 1];
		const double a = terrace(y0 / step, tread);
		const double b = terrace((y0 + h) / step, tread);
		return lerpf((b - a) * step, h, f);
	}
	double rise(double u, int side, double e, double lid, bool lowest = false) const {
		if (e <= 0.0) return 0.0;
		const int64_t salt = int64_t(double(s[12])) + side * 31;
		const double f = flare(u);
		const double low = lerpf(1.0, S_FLARE_LOW, f);
		const double edge = s[K_EDGE] * lerpf(1.0, S_FLARE_SOFT, f);
		double y = 0.0;
		const double tw = s[K_TALUS + 1];
		if (tw > 0.0) {
			const double th = s[K_TALUS] * low;
			if (e <= tw) {
				const double a = e / tw;
				return th * a * a;
			}
			e -= tw;
			y = th;
		}
		const double under = s[6] - lid;
		const int n = int(double(s[K_TIERS]));
		for (int k = 0; k < n; ++k) {
			const double t = (s[K_LEVEL + k] + under) * low - y;
			if (t <= 0.5) continue;
			if (e <= edge) {
				const double a = e / edge;
				return y + t * a * a * (3.0 - 2.0 * a);
			}
			e -= edge;
			y += t;
			if (k < n - 1) {
				const double b = bench(u, salt, k, lowest);
				if (e <= b) return y + e * S_BENCH_RISE;
				e -= b;
				y += b * S_BENCH_RISE;
			}
		}
		const double h = e / lerpf(s[K_LEAN], S_FLARE_LEAN, f);
		if (lowest) return y + h;
		return y + strata(lid + y, h, f);
	}
	// `cut(...).x` (a Vector3: a float), `base` a float already.
	double carve(double base, double x, double z) const {
		float qx, qy;
		site_local(s, x, z, qx, qy);
		const double au = std::fabs(double(qx));
		if (au > s[7] || std::fabs(double(qy)) > s[8]) return base;
		float cx, cy;
		path(qx, cx, cy);
		const double off = double(qy) - cx;
		const double d = std::fabs(off) / std::sqrt(1.0 + double(cy) * cy);
		if (d > s[11]) return base;
		const double lid = floor_at(qx);
		if (base <= lid) return base;
		const int side = off > 0.0 ? 1 : 0;
		float bx, by;
		back(qx, side, bx, by);
		const double e = d - half(qx) - bx;
		double y = lid + rise(qx, side, e, lid);
		const double t = maxf(smoothstep(s[11] - S_EASE, s[11], d), smoothstep(s[7] - S_EASE, s[7], au));
		y = lerpf(y, base, t);
		if (y >= base - 0.0005) return base;
		return double(float(y));
	}
};

// --- The squares' published sites ------------------------------------------------------

// One layer's squares: each a site (empty: none there). Read and written by
// the one LandField that owns the field (a worker's LandField has its own).
struct Squares {
	double cell = 1.0;
	bool on = false;
	std::vector<int64_t> keys;
	std::vector<std::vector<float>> sites;
	// A small open-addressed table (power-of-two slots, -1 empty) into `sites`.
	std::vector<int64_t> slot_key;
	std::vector<int32_t> slot_at;
	int64_t last_key = INT64_MIN;
	int32_t last_at = -1;

	static int64_t pack(int64_t ci, int64_t cj) { return (ci << 32) ^ (cj & 0xffffffffll); }
	int64_t key_of(double x, double z) const {
		return pack(int64_t(std::floor(x / cell)), int64_t(std::floor(z / cell)));
	}
	static uint64_t mix(int64_t k) {
		uint64_t h = uint64_t(k) * 0x9E3779B97F4A7C15ull;
		return h ^ (h >> 29);
	}
	// The index into `sites` of square `key`, or -1 when not yet published.
	int32_t find(int64_t key) {
		if (key == last_key) return last_at;
		if (slot_key.empty()) return -1;
		const uint64_t mask = slot_key.size() - 1;
		for (uint64_t i = mix(key) & mask;; i = (i + 1) & mask) {
			if (slot_at[i] < 0) return -1;
			if (slot_key[i] == key) {
				last_key = key;
				last_at = slot_at[i];
				return last_at;
			}
		}
	}
	void put(int64_t key, const float *p, int64_t n) {
		const int32_t at = find(key);
		if (at >= 0) {
			sites[size_t(at)].assign(p, p + n);
			return;
		}
		if ((keys.size() + 1) * 2 > slot_key.size()) grow();
		keys.push_back(key);
		sites.emplace_back(p, p + n);
		insert(key, int32_t(keys.size() - 1));
	}
	void insert(int64_t key, int32_t at) {
		const uint64_t mask = slot_key.size() - 1;
		uint64_t i = mix(key) & mask;
		while (slot_at[i] >= 0) i = (i + 1) & mask;
		slot_key[i] = key;
		slot_at[i] = at;
	}
	void grow() {
		const size_t n = slot_key.empty() ? 64 : slot_key.size() * 2;
		slot_key.assign(n, 0);
		slot_at.assign(n, -1);
		for (size_t k = 0; k < keys.size(); ++k) insert(keys[k], int32_t(k));
		last_key = INT64_MIN;
	}
};

} // namespace zscarve
