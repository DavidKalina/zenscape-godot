// The endless land's field in C++ (docs/design/endless-flight/native-land-handoff.md):
// scripts/endless/land_field.gd's GDScript field (its inner class `GDField`)
// line for line, so a seed grows the same land natively or in GDScript.
// LandField (GDScript) stays the public face and calls this through
// ZenScapeLandField (kernels.cpp) when the library is built.
//
// Matching GDScript's numbers: GDScript's own numbers are doubles; Vector2,
// Vector3, Color and PackedFloat32Array hold floats (real_t = float), and a
// double meeting a vector is narrowed first, as the engine's Variant
// operators do. The helpers below (V2, V3, C4) do just that, in the same
// order. FastNoiseLite is the engine's own copy, asked with float
// coordinates as get_noise_2d is.
//
// Repeatable on every machine: no clock, no thread state, no uninitialised
// memory, and (unless `libm` is set, to check against GDScript bit for bit
// on one machine) exp/pow/sin/cos are land_math.h's, not the C runtime's.
// Built with contraction off (SConstruct), so no fused multiply-add.
//
// A new feature: add its knob (a member, set by `configure`), its noise (a
// salt not used yet), and its maths where the GDScript field had it, then
// mirror it in GDField (or make it native-only: see the handoff).
#pragma once

#include "FastNoiseLite.h"
#include "land_math.h"
#include <cmath>
#include <cstdint>
#include <limits>
#include <vector>

namespace zsland {

using FNL = fastnoiselite::FastNoiseLite;
constexpr double INF = std::numeric_limits<double>::infinity();
constexpr double TAU = 6.2831853071795864769252867666;

// --- GDScript's scalar utility functions (doubles) ---------------------------------
inline double minf(double a, double b) { return a < b ? a : b; }
inline double maxf(double a, double b) { return a > b ? a : b; }
inline double clampf(double v, double lo, double hi) { return v < lo ? lo : (v > hi ? hi : v); }
inline double lerpf(double a, double b, double t) { return a + (b - a) * t; }
inline double absf(double v) { return std::fabs(v); }
inline double signf(double v) { return v > 0 ? 1.0 : (v < 0 ? -1.0 : 0.0); }
inline int64_t floori(double v) { return int64_t(std::floor(v)); }
inline bool is_equal_approx(double a, double b) {
	if (a == b) return true;
	double tolerance = 0.00001 * std::fabs(a);
	if (tolerance < 0.00001) tolerance = 0.00001;
	return std::fabs(a - b) < tolerance;
}
inline double smoothstep(double from, double to, double s) {
	if (is_equal_approx(from, to)) {
		if (from <= to) return s <= from ? 0.0 : 1.0;
		return s <= to ? 1.0 : 0.0;
	}
	double t = clampf((s - from) / (to - from), 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

// --- Engine vectors (floats) --------------------------------------------------------
struct V2 {
	float x = 0, y = 0;
	V2() = default;
	V2(double px, double py) : x(float(px)), y(float(py)) {}
	static V2 of(float px, float py) { V2 v; v.x = px; v.y = py; return v; }
	V2 operator+(const V2 &o) const { return of(x + o.x, y + o.y); }
	V2 operator*(double s) const { const float f = float(s); return of(x * f, y * f); }
	V2 operator/(double s) const { const float f = float(s); return of(x / f, y / f); }
	float length() const { return std::sqrt(x * x + y * y); }
	V2 normalized() const {
		if (!std::isfinite(x) || !std::isfinite(y)) return of(0, 0);
		float l = x * x + y * y;
		if (l == 0) return of(0, 0);
		l = std::sqrt(l);
		return of(x / l, y / l);
	}
	V2 lerp(const V2 &to, double w) const {
		const float t = float(w);
		return of(x + (to.x - x) * t, y + (to.y - y) * t);
	}
};
struct V3 {
	float x = 0, y = 0, z = 0;
	V3() = default;
	V3(double px, double py, double pz) : x(float(px)), y(float(py)), z(float(pz)) {}
	V3 lerp(const V3 &to, double w) const {
		const float t = float(w);
		V3 r;
		r.x = x + (to.x - x) * t;
		r.y = y + (to.y - y) * t;
		r.z = z + (to.z - z) * t;
		return r;
	}
	V3 normalized() const {
		V3 r;
		if (!std::isfinite(x) || !std::isfinite(y) || !std::isfinite(z)) return r;
		const float x2 = x * x, y2 = y * y, z2 = z * z;
		float l = x2 + y2 + z2;
		if (l == 0) return r;
		l = std::sqrt(l);
		r.x = x / l;
		r.y = y / l;
		r.z = z / l;
		return r;
	}
};
struct C4 {
	float r = 0, g = 0, b = 0, a = 1;
	C4() = default;
	C4(double pr, double pg, double pb) : r(float(pr)), g(float(pg)), b(float(pb)), a(1.0f) {}
	C4 lerp(const C4 &to, double w) const {
		const float t = float(w);
		C4 c;
		c.r = r + (to.r - r) * t;
		c.g = g + (to.g - g) * t;
		c.b = b + (to.b - b) * t;
		c.a = a + (to.a - a) * t;
		return c;
	}
};

class LandField {
public:
	// --- Constants (land_field.gd; Vector2 constants as floats) ----------------------
	static constexpr double SEA_Y = -40.0;
	// The land recipe (land_field.gd recipe_defaults(); the world profile's `land`,
	// read in `configure`): members, not constants, at wilderness's values.
	double CONTINENT = 3600.0, CONTINENT_SWING = 70.0, CONTINENT_LIFT = 14.0, LOWLAND = 26.0;
	double HILLS = 320.0, HILL_TALL = 16.0;
	static constexpr double MOUNTAINS = 2600.0, MOUNTAIN_TALL = 105.0;
	static constexpr float MOUNTAIN_BAND_X = 0.18f, MOUNTAIN_BAND_Y = 0.5f;
	double RANGES = 2300.0, RANGE_WIDTH = 0.36, RANGE_MASK = 3400.0;
	float RANGE_BAND_X = -0.50f, RANGE_BAND_Y = -0.12f;
	double WARP = 1500.0, WARP_MOVE = 520.0, RIDGES = 700.0;
	float PEAK_TALL_X = 95.0f, PEAK_TALL_Y = 215.0f;
	double PEAK_SCALE = 1700.0;
	double MEADOWS = 650.0;
	float MEADOW_BAND_X = -0.05f, MEADOW_BAND_Y = 0.22f;
	double MEADOW_KEEP = 0.07, MEADOW_ABOVE = 3.0;
	double VALLEYS = 2100.0, VALLEY_WARP = 1100.0, VALLEY_WARP_MOVE = 380.0;
	float VALLEY_SWING_X = 0.75f, VALLEY_SWING_Y = 1.7f;
	float VALLEY_SIDE_X = 300.0f, VALLEY_SIDE_Y = 150.0f;
	double VALLEY_KEEP = 0.08;
	double SNOW = 125.0;
	// The built land's forms (land_field.gd RIDGE_CRISP..MESA_BAND), off unless set.
	double RIDGE_CRISP = 0.0, NOTCH = 0.0, NOTCH_SCALE = 1300.0;
	float NOTCH_WIDTH_X = 0.025f, NOTCH_WIDTH_Y = 0.07f;
	double TERRACE = 0.0, TERRACE_STEP = 5.0, TERRACE_FLAT = 0.65, TERRACE_SCALE = 1500.0;
	float TERRACE_BAND_X = -0.15f, TERRACE_BAND_Y = 0.2f;
	double MESA = 0.0, MESA_TALL = 50.0, MESA_SCALE = 800.0, MESA_LEVEL = 0.3, MESA_EDGE = 0.035;
	double MESA_STEPS = 2.0, MESA_GAP = 0.12, MESA_KEEP = 0.12, MESA_MASK = 3800.0;
	float MESA_BAND_X = -0.1f, MESA_BAND_Y = 0.25f;
	// (The recipe's end; constants again from here.)
	static constexpr double BEACH = 2.2;
	static constexpr double CARVE_GRID = 8.0;
	static constexpr float CARVE_SLOPE_X = 0.38f, CARVE_SLOPE_Y = 0.9f;
	static constexpr float CARVE_MOUNTAIN_X = 0.004f, CARVE_MOUNTAIN_Y = 0.08f;
	static constexpr double FACET_CELL = 32.0, FACET_TILT = 0.35, FACET_STEP = 3.5, FACET_EDGE = 0.010, FACET_KEEP = 0.8;
	static constexpr double BENCH = 14.0, BENCH_WARP = 1.4, BENCH_WANDER = 70.0, BENCH_FLAT = 0.42, BENCH_BANDS = 220.0;
	static constexpr float GULLY_SIZE[3] = {36.0f, 15.0f, 6.0f};
	static constexpr float GULLY_DEPTH[3] = {10.0f, 4.5f, 1.0f};
	static constexpr double GULLY_JITTER = 0.45, GULLY_SHARP = 1.7;
	static constexpr double GULLY_SHADE[3] = {1.0, 0.75, 0.4};
	static constexpr float CARVE_FADE_X = 3.0f, CARVE_FADE_Y = 5.0f;
	static constexpr double CARVE_DETAIL_OFF = 16.0;
	static constexpr float RIVER_WIDTH_X = 10.0f, RIVER_WIDTH_Y = 24.0f;
	static constexpr double RIVER_WIDE = 820.0, RIVER_PINCH = 0.28, RIVER_PINCH_SIZE = 150.0;
	static constexpr float RIVER_DROP_X = 2.0f, RIVER_DROP_Y = 3.0f;
	static constexpr double RIVER_BANK = 8.0, RIVER_BED = 0.6, RIVER_HUG = 0.9, RIVER_SIDE = 1900.0;
	static constexpr double RIVER_MEANDER = 470.0, RIVER_SWAY = 0.12, RIVER_RAMP = 40.0, RIVER_REACH = 80.0;
	static constexpr float RIVER_PLAIN_X = 26.0f, RIVER_PLAIN_Y = 40.0f;
	static constexpr double RIVER_PLAIN_SPREAD = 6.0;
	static constexpr float RIVER_FLOW_X = 0.35f, RIVER_FLOW_Y = 9.0f;
	static constexpr double RIVER_STILL = 0.0012;
	static constexpr double RIVER_INLAND = 0.3, RIVER_CUT_SIDE = 0.5, RIVER_FILL_SIDE = 110.0;
	static constexpr double RIVER_MOUTH_RISE = 5.0, RIVER_FLARE = 1.4, RIVER_MOUTH_DEEP = 3.6, RIVER_MOUTH_EASE = 1.2, RIVER_MOUTH_SINK = 1.5;
	static constexpr int LAT_SLOTS = 128;

	// --- Knobs (LandField's flags; `configure` then `setup`) ------------------------
	int64_t seed = 0;
	double mountains = 1.0, peaks = 1.0, valleys = 1.0;
	bool old_land = false;
	double carve = 1.0, carve_blocks = 1.0, carve_ledges = 1.0, carve_gullies = 1.0, detail = 0.0;
	double rivers = 1.0, river_width = 1.0, river_drop = 1.0, river_cut = 1.0, river_fill = 1.0;
	double river_mouth = 1.0, river_flare = 1.0;
	double floor_half = 50.0;
	// The C runtime's exp/pow/sin/cos (as GDScript), not land_math.h's.
	bool libm = false;

	// --- What the last `sample` found (land_field.gd) -------------------------------
	double last_mountain = 0.0, last_inland = 0.0, last_valley = INF, last_half = 0.0, last_side = 0.0;
	V2 last_across = V2::of(1.0f, 0.0f);
	double last_floor = INF, last_cavity = 0.0, last_ridge = 0.0;
	double last_river = INF, last_river_r = INF, last_river_w = 0.0, last_river_y = -INF;
	V2 last_river_flow;

	void setup() {
		noise(n_continent, 1, CONTINENT, 3, FNL::FractalType_FBm);
		noise(n_hills, 2, HILLS, 4, FNL::FractalType_FBm);
		noise(n_mask, 3, old_land ? MOUNTAINS : RANGE_MASK, 2, FNL::FractalType_FBm);
		noise(n_ridges, 4, old_land ? 900.0 : RIDGES, 5, FNL::FractalType_Ridged);
		noise(n_meadows, 5, MEADOWS, 2, FNL::FractalType_FBm);
		noise(n_tint, 6, 180.0, 2, FNL::FractalType_FBm);
		noise(n_warp, 7, WARP, 2, FNL::FractalType_FBm);
		noise(n_range, 8, RANGES, 2, FNL::FractalType_FBm);
		noise(n_peak, 9, PEAK_SCALE, 2, FNL::FractalType_FBm);
		noise(n_valley, 10, VALLEYS, 2, FNL::FractalType_FBm);
		noise(n_valley_warp, 11, VALLEY_WARP, 1, FNL::FractalType_None);
		noise(n_valley_wide, 12, 900.0, 1, FNL::FractalType_None);
		noise(n_bench_warp, 13, BENCH_WANDER, 2, FNL::FractalType_FBm);
		noise(n_bench_band, 14, BENCH_BANDS, 1, FNL::FractalType_None);
		noise(n_gully_amp, 15, 1.0, 1, FNL::FractalType_None);
		noise(n_river_side, 16, RIVER_SIDE, 1, FNL::FractalType_None);
		noise(n_river_meander, 17, RIVER_MEANDER, 1, FNL::FractalType_None);
		noise(n_river_wide, 18, RIVER_WIDE, 1, FNL::FractalType_None);
		noise(n_notch, 19, NOTCH_SCALE, 1, FNL::FractalType_None);
		noise(n_terrace, 20, TERRACE_SCALE, 2, FNL::FractalType_FBm);
		noise(n_mesa, 21, MESA_SCALE, 2, FNL::FractalType_FBm);
		noise(n_mesa_mask, 22, MESA_MASK, 1, FNL::FractalType_None);
	}

	// Vector2(world height, meadow) at a world XZ point (`sample`).
	V2 sample(double x, double z) {
		if (old_land) {
			last_river = INF;
			last_river_w = 0.0;
			return old_sample(x, z);
		}
		V2 s = broad(x, z);
		last_cavity = 0.0;
		last_ridge = 0.0;
		const double rr = last_river_r, rw = last_river_w, ry = last_river_y;
		const V2 rf = last_river_flow;
		const double rtop = river_top, rk = river_k, rm = river_mouth_s, rb = river_bed;
		// A mesa's walls are carved as a range's are (`rock_`; 0 without mesas).
		const double rock = maxf(last_mountain, rock_);
		if (carve > 0.0 && rock > double(CARVE_MOUNTAIN_X) && detail < CARVE_DETAIL_OFF) {
			const double k_mountain = last_mountain, k_inland = last_inland, k_valley = last_valley;
			const double k_half = last_half, k_side = last_side;
			const V2 k_across = last_across;
			s.x = float(carve_at(x, z, s.x, s.y, rock, floor_y_));
			last_mountain = k_mountain;
			last_inland = k_inland;
			last_valley = k_valley;
			last_half = k_half;
			last_side = k_side;
			last_across = k_across;
		}
		last_river_r = rr;
		last_river_w = rw;
		last_river_y = ry;
		last_river_flow = rf;
		river_top = rtop;
		river_k = rk;
		river_mouth_s = rm;
		river_bed = rb;
		last_river = INF;
		if (rk > 0.0) {
			const double reach = rw + RIVER_BANK + RIVER_RAMP + (last_inland < 0.95 ? double(RIVER_PLAIN_Y) * RIVER_PLAIN_SPREAD : 0.0);
			if (absf(rr) < reach) s.x = float(river_at(s.x));
			else last_river = absf(rr) - rw;
		}
		return s;
	}

	double height(double x, double z) { return sample(x, z).x; }

	// `shape`'s resets before its sample (round one's land sets none of these).
	void shape_reset() {
		last_mountain = 0.0;
		last_valley = INF;
		last_inland = 0.0;
	}

	double river_drawn() const {
		if (river_mouth <= 0.0 || last_river_y == -INF) return last_river_y;
		const double over = last_river_y - SEA_Y;
		return last_river_y - (RIVER_BED + RIVER_MOUTH_DEEP) * minf(river_mouth, 1.0) * (1.0 - smoothstep(0.0, RIVER_MOUTH_SINK, over));
	}

	double river_y(double x, double z) {
		sample(x, z);
		if (last_river < 0.0 && river_drawn() > SEA_Y + 0.05) return river_drawn();
		return std::numeric_limits<double>::quiet_NaN();
	}

	double calm_here() const {
		if (river_mouth <= 0.0 || rivers <= 0.0 || last_river_w <= 0.0) return 0.0;
		return smoothstep(0.5, 3.0, last_river_w) * (1.0 - smoothstep(2.0, 12.0, last_river));
	}

	double sea_calm(double x, double z) {
		sample(x, z);
		return calm_here();
	}

	double snow_line() const { return old_land ? 95.0 : SNOW; }

	C4 colour(double x, double z, double y, double up, double meadow) const {
		static const C4 SAND(0.80, 0.74, 0.56), SEABED(0.42, 0.46, 0.40), GRASS(0.30, 0.48, 0.20), GRASS_DRY(0.46, 0.54, 0.24);
		static const C4 MEADOW(0.52, 0.64, 0.28), ROCK(0.47, 0.44, 0.40), SNOW_COLOUR(0.93, 0.94, 0.97);
		const double over = y - SEA_Y;
		if (over < -0.5) return SEABED.lerp(SAND, clampf(1.0 + over / 6.0, 0.0, 1.0));
		C4 grass = GRASS.lerp(GRASS_DRY, clampf(nz(n_tint, x, z) * 0.9 + 0.45, 0.0, 1.0));
		grass = grass.lerp(MEADOW, meadow);
		C4 c = SAND.lerp(grass, smoothstep(BEACH * 0.6, BEACH * 1.4, over));
		c = c.lerp(ROCK, smoothstep(0.86, 0.72, up));
		const double snow = snow_line();
		if (over > snow - 12.0) c = c.lerp(SNOW_COLOUR, smoothstep(snow - 12.0, snow + 6.0, over) * smoothstep(0.62, 0.8, up));
		return c;
	}

private:
	FNL n_continent, n_hills, n_mask, n_ridges, n_meadows, n_tint, n_warp, n_range, n_peak;
	FNL n_valley, n_valley_warp, n_valley_wide, n_bench_warp, n_bench_band, n_gully_amp;
	FNL n_river_side, n_river_meander, n_river_wide;
	FNL n_notch, n_terrace, n_mesa, n_mesa_mask;
	double floor_y_ = -INF;
	double rock_ = 0.0;
	double river_top = -INF, river_k = 0.0, river_mouth_s = 0.0, river_bed = RIVER_BED;
	// The carve's memos and lattice caches (land_field.gd), kept as GDScript
	// keeps them: they hold only what a recompute would give, but `last_floor`
	// after a carved sample is whatever the carve's last broad read left.
	int32_t bs_key_x = 1 << 30, bs_key_y = 0;
	V3 bs_00, bs_10, bs_01, bs_11;
	int32_t fc_key_x = 1 << 30, fc_key_y = 0;
	float fc[54] = {};
	int32_t gc_key_x[3] = {1 << 30, 1 << 30, 1 << 30}, gc_key_y[3] = {0, 0, 0};
	float gc[3][8] = {};
	std::vector<int64_t> node_key, h_key;
	std::vector<uint8_t> node_set, h_set;
	std::vector<double> node_v, h_v;

	double EXP(double v) const { return libm ? std::exp(v) : det_exp(v); }
	double POW(double a, double b) const { return libm ? std::pow(a, b) : det_pow(a, b); }
	double COS(double v) const { return libm ? std::cos(v) : det_cos(v); }
	double SIN(double v) const { return libm ? std::sin(v) : det_sin(v); }

	void noise(FNL &n, int64_t salt, double scale, int octaves, FNL::FractalType kind) {
		// `seed*7919+salt*104729` (int64), narrowed to the property's int.
		const uint64_t s = uint64_t(seed) * 7919u + uint64_t(salt) * 104729u;
		n.SetSeed(int(int32_t(uint32_t(s))));
		n.SetNoiseType(FNL::NoiseType_OpenSimplex2S);
		n.SetFrequency(float(1.0 / scale));
		n.SetFractalType(kind);
		n.SetFractalOctaves(octaves);
	}

	// get_noise_2d: float coordinates, the noise's float back as a double.
	static double nz(const FNL &n, double x, double z) {
		const float fx = float(x) + 0.0f;
		const float fz = float(z) + 0.0f;
		return double(n.GetNoise(fx, fz));
	}

	V2 broad(double x, double z) {
		double base = nz(n_continent, x, z) * CONTINENT_SWING * 2.0 + CONTINENT_LIFT;
		if (base > 0.0) base = LOWLAND * (1.0 - EXP(-base / LOWLAND));
		const double inland = smoothstep(-6.0, 18.0, base);
		const double hills = nz(n_hills, x, z) * HILL_TALL * 2.0 * (0.35 + 0.65 * inland);
		double h = base + hills;
		double mountain = 0.0;
		last_valley = INF;
		last_floor = INF;
		last_inland = inland;
		floor_y_ = -INF;
		if (inland > 0.0 && mountains > 0.0) {
			// RANGE_BAND+Vector2.ONE*(1.0-mountains)*0.35, in floats.
			const V2 shift = (V2::of(1.0f, 1.0f) * (1.0 - mountains)) * 0.35;
			const V2 band = V2::of(RANGE_BAND_X, RANGE_BAND_Y) + shift;
			const double where = smoothstep(band.x, band.y, nz(n_mask, x, z)) * inland;
			if (where > 0.0) {
				const double wx = x + nz(n_warp, x, z) * WARP_MOVE;
				const double wz = z + nz(n_warp, x + 7919.0, z - 3301.0) * WARP_MOVE;
				const double rn = nz(n_range, wx, wz);
				const double off = absf(rn) / RANGE_WIDTH;
				if (off < 1.0) {
					double crest = 1.0 - off;
					crest = crest * crest * (3.0 - 2.0 * crest);
					mountain = crest * where;
					const double tall = lerpf(PEAK_TALL_X, PEAK_TALL_Y, clampf(nz(n_peak, x, z) * 0.9 + 0.5, 0.0, 1.0)) * peaks;
					const double ridge = nz(n_ridges, x, z) * 0.5 + 0.5;
					double add = tall * (0.4 * POW(mountain, 1.4) + 0.75 * ridge * ridge * mountain * mountain);
					if (RIDGE_CRISP > 0.0) {
						const double a = 1.0 - off;
						const double gable = tall * where * a * smoothstep(0.0, 0.35, a) * (0.8 + 0.35 * ridge);
						add = lerpf(add, gable, minf(RIDGE_CRISP, 1.0));
					}
					if (NOTCH > 0.0) {
						const double ns = nz(n_notch, x, z);
						const double nn = absf(ns);
						if (nn < double(NOTCH_WIDTH_Y)) {
							const double e = 8.0;
							const double ngx = nz(n_notch, x + e, z) - ns;
							const double ngz = nz(n_notch, x, z + e) - ns;
							const double rgx = nz(n_range, wx + e, wz) - rn;
							const double rgz = nz(n_range, wx, wz + e) - rn;
							const double dn = std::sqrt((ngx * ngx + ngz * ngz) * (rgx * rgx + rgz * rgz));
							const double along = dn > 0.0 ? absf(ngx * rgx + ngz * rgz) / dn : 1.0;
							add *= 1.0 - minf(NOTCH, 1.0) * (1.0 - smoothstep(NOTCH_WIDTH_X, NOTCH_WIDTH_Y, nn)) * (1.0 - smoothstep(0.45, 0.8, along));
						}
					}
					h += add;
				}
			}
		}
		if (TERRACE > 0.0 && inland > 0.0) {
			const double tm = smoothstep(TERRACE_BAND_X, TERRACE_BAND_Y, nz(n_terrace, x, z)) * inland * (1.0 - smoothstep(0.3, 0.8, mountain)) * minf(TERRACE, 1.0);
			if (tm > 0.0) {
				const double ty = h / TERRACE_STEP;
				const double tf = ty - std::floor(ty);
				const double stepped = (std::floor(ty) + smoothstep(TERRACE_FLAT, 1.0, tf)) * TERRACE_STEP;
				h = lerpf(h, stepped, tm);
			}
		}
		double meadow = smoothstep(MEADOW_BAND_X, MEADOW_BAND_Y, nz(n_meadows, x, z)) * inland * (1.0 - smoothstep(0.0, 0.35, mountain));
		if (meadow > 0.0) {
			const double flat = maxf(base + hills * MEADOW_KEEP, MEADOW_ABOVE);
			h = lerpf(h, flat, meadow);
		}
		double mesa = 0.0;
		if (MESA > 0.0 && inland > 0.0) {
			const double region = smoothstep(MESA_BAND_X, MESA_BAND_Y, nz(n_mesa_mask, x, z)) * smoothstep(0.0, 0.25, inland) * (1.0 - smoothstep(0.05, 0.3, mountain)) * minf(MESA, 1.0);
			if (region > 0.0) {
				const double lv = MESA_LEVEL + (1.0 - region) * 1.2;
				const double mn = nz(n_mesa, x, z);
				if (mn > lv) {
					const double tiers = maxf(std::floor(MESA_STEPS), 1.0);
					double wall = 0.0;
					const int64_t nt = int64_t(tiers);
					for (int64_t t = 0; t < nt; ++t) {
						const double at = lv + double(t) * MESA_GAP;
						const double st = smoothstep(at, at + MESA_EDGE, mn);
						mesa += st / tiers;
						wall = maxf(wall, 1.0 - absf(2.0 * st - 1.0));
					}
					const double top = base + hills * MESA_KEEP + MESA_TALL * mesa;
					h = lerpf(h, maxf(top, MEADOW_ABOVE), minf(mesa * tiers, 1.0));
					meadow = maxf(meadow * (1.0 - smoothstep(0.0, 0.3, wall)), smoothstep(0.9, 1.0, mesa) * inland);
				}
			}
		}
		rock_ = mesa;
		last_river_r = INF;
		last_river_w = 0.0;
		last_river_y = -INF;
		last_river_flow = V2();
		river_top = -INF;
		river_k = 0.0;
		river_mouth_s = 0.0;
		river_bed = RIVER_BED;
		if (inland > 0.0 && valleys > 0.0) {
			const double vx = x + nz(n_valley_warp, x, z) * VALLEY_WARP_MOVE;
			const double vz = z + nz(n_valley_warp, x - 4111.0, z + 2027.0) * VALLEY_WARP_MOVE;
			const double v = nz(n_valley, vx, vz);
			const double e = 6.0;
			const double gx = (nz(n_valley, vx + e, vz) - v) / e;
			const double gz = (nz(n_valley, vx, vz + e) - v) / e;
			const double d = absf(v) / maxf(std::sqrt(gx * gx + gz * gz), 0.25 / VALLEYS);
			const double half = floor_half * lerpf(VALLEY_SWING_X, VALLEY_SWING_Y, clampf(nz(n_valley_wide, x, z) * 0.8 + 0.5, 0.0, 1.0));
			const double side = lerpf(VALLEY_SIDE_X, VALLEY_SIDE_Y, smoothstep(0.0, 0.6, maxf(mountain, mesa))) * maxf(valleys, 1.0);
			last_valley = d;
			last_half = half;
			last_side = side;
			if (gx * gx + gz * gz > 0.0) last_across = V2(gx, gz).normalized();
			double floor_y = maxf(base + hills * VALLEY_KEEP, MEADOW_ABOVE);
			last_floor = SEA_Y + floor_y;
			if (d < half + side) {
				double fill = 0.0;
				if (rivers > 0.0) {
					const double k = smoothstep(0.0, 0.12, inland) * minf(valleys, 1.0) * minf(rivers, 1.0);
					const double ds = v / maxf(std::sqrt(gx * gx + gz * gz), 0.25 / VALLEYS);
					fill = smoothstep(0.5, 3.0, base - double(RIVER_DROP_Y) * river_drop) * k;
					const double reach_r = RIVER_REACH + (inland < 0.95 ? double(RIVER_PLAIN_Y) * RIVER_PLAIN_SPREAD : 0.0);
					double off = signf(ds) * half * RIVER_HUG;
					bool far = k <= 0.0 || d > half * (RIVER_HUG + 2.0 * RIVER_SWAY) + reach_r;
					if (!far) {
						double pick = nz(n_river_side, x, z) * 4.0;
						pick = pick / std::sqrt(1.0 + pick * pick);
						off = half * (pick * RIVER_HUG + nz(n_river_meander, x, z) * 2.0 * RIVER_SWAY * absf(pick));
						far = absf(ds - off) > reach_r;
					}
					if (far) {
						last_river_r = ds - off;
						const double mean_mouth = mouth(base - double(RIVER_DROP_Y) * river_drop);
						last_river_w = (double(RIVER_WIDTH_X) + double(RIVER_WIDTH_Y)) * 0.25 * river_width * k * (1.0 + RIVER_FLARE * river_flare * mean_mouth * mean_mouth * minf(river_mouth, 1.0));
						last_river_y = SEA_Y + mouth_level(base - double(RIVER_DROP_Y) * river_drop);
					} else {
						const double wide = clampf(nz(n_river_wide, x, z) * 0.9 + 0.5, 0.0, 1.0);
						const double pinch = 1.0 + RIVER_PINCH * nz(n_river_wide, x * RIVER_WIDE / RIVER_PINCH_SIZE + 911.0, z * RIVER_WIDE / RIVER_PINCH_SIZE - 377.0);
						double w = lerpf(RIVER_WIDTH_X, RIVER_WIDTH_Y, wide) * river_width * 0.5 * k * pinch;
						const double drop = lerpf(RIVER_DROP_X, RIVER_DROP_Y, wide) * river_drop;
						const double mo = mouth(base - drop);
						const double flare = 1.0 + RIVER_FLARE * river_flare * mo * mo * minf(river_mouth, 1.0);
						w *= flare;
						const double gw = maxf(std::sqrt(gx * gx + gz * gz), 0.25 / VALLEYS);
						double scale = 1.0;
						V2 along = V2(-gz, gx) / gw;
						const V2 wg = V2(valley_at(x + 4.0, z) - v, valley_at(x, z + 4.0) - v) * 0.25;
						const double wl = wg.length();
						if (wl > 1e-7) {
							scale = clampf(gw / wl, 0.25, 4.0);
							along = V2::of(-wg.y, wg.x) / wl;
						}
						const double r = (ds - off) * scale;
						const double s = absf(r);
						const double top = maxf(base, MEADOW_ABOVE);
						const double water = mouth_level(base - drop);
						const double near = (1.0 - smoothstep(w + RIVER_BANK, w + RIVER_BANK + RIVER_RAMP, s)) * k;
						floor_y = lerpf(floor_y, top, near);
						last_river_r = r;
						last_river_w = w;
						last_river_y = SEA_Y + water;
						river_top = SEA_Y + top;
						river_k = k;
						river_mouth_s = mo;
						river_bed = RIVER_BED + RIVER_MOUTH_DEEP * mo * minf(river_mouth, 1.0);
						if (s < w + RIVER_BANK + 16.0 && water > 0.0) {
							const double ax = along.x, az = along.y;
							const double fall = (lowland(x - ax * 30.0, z - az * 30.0) - lowland(x + ax * 30.0, z + az * 30.0)) / 60.0;
							const double speed = (double(RIVER_FLOW_X) + std::sqrt(absf(fall)) * double(RIVER_FLOW_Y)) / flare;
							last_river_flow = (along * clampf(fall / RIVER_STILL, -1.0, 1.0)) * speed;
						}
					}
				}
				floor_y_ = SEA_Y + floor_y;
				last_floor = floor_y_;
				const double t = clampf((d - half) / side, 0.0, 1.0);
				double keep = t * t * (3.0 - 2.0 * t);
				double cut_in = inland;
				if (rivers > 0.0 && river_cut > 0.0) {
					const double tc = clampf((d - half) / (side * RIVER_CUT_SIDE), 0.0, 1.0);
					cut_in = lerpf(inland, lerpf(smoothstep(0.0, RIVER_INLAND, inland), inland, tc * tc * (3.0 - 2.0 * tc)), minf(river_cut, 1.0));
				}
				keep = lerpf(1.0, keep, minf(valleys, 1.0) * cut_in);
				if (h > floor_y) h = floor_y + (h - floor_y) * keep;
				else if (fill > 0.0 && river_fill > 0.0) {
					const double tf = clampf((d - half) / RIVER_FILL_SIDE, 0.0, 1.0);
					const double keep_f = lerpf(1.0, tf * tf * (3.0 - 2.0 * tf), minf(valleys, 1.0) * cut_in);
					h = lerpf(h, floor_y + (h - floor_y) * keep_f, fill * minf(river_fill, 1.0));
				}
				const double floor_meadow = (1.0 - smoothstep(half * 0.7, half + side * 0.2, d)) * inland * minf(valleys, 1.0);
				meadow = maxf(meadow, floor_meadow);
			}
		}
		if (absf(h) < BEACH * 2.0) h = h * lerpf(0.45, 1.0, smoothstep(0.0, BEACH * 2.0, absf(h)));
		last_mountain = mountain;
		return V2(SEA_Y + h, meadow);
	}

	double mouth(double lv) const {
		if (river_mouth <= 0.0) return 0.0;
		return 1.0 - smoothstep(0.0, RIVER_MOUTH_RISE, lv);
	}

	double mouth_level(double lv) const {
		if (river_mouth <= 0.0) return maxf(lv, 0.0);
		const double e = RIVER_MOUTH_EASE;
		if (lv >= e) return lv;
		if (lv <= -e) return 0.0;
		return (lv + e) * (lv + e) / (4.0 * e);
	}

	double lowland(double x, double z) const {
		double b = nz(n_continent, x, z) * CONTINENT_SWING * 2.0 + CONTINENT_LIFT;
		if (b > 0.0) b = LOWLAND * (1.0 - EXP(-b / LOWLAND));
		return b;
	}

	double valley_at(double x, double z) const {
		const double vx = x + nz(n_valley_warp, x, z) * VALLEY_WARP_MOVE;
		const double vz = z + nz(n_valley_warp, x - 4111.0, z + 2027.0) * VALLEY_WARP_MOVE;
		return nz(n_valley, vx, vz);
	}

	double river_at(double h) {
		double w = last_river_w;
		const double s = absf(last_river_r);
		const double water = last_river_y;
		const double top = river_top;
		const double drop = top - water;
		double core = w + RIVER_BANK;
		if (s > core + RIVER_RAMP + double(RIVER_PLAIN_Y) * RIVER_PLAIN_SPREAD) {
			last_river = s - w;
			return h;
		}
		const double raise = (1.0 - smoothstep(core, core + RIVER_RAMP, s)) * smoothstep(0.5, 3.0, water - SEA_Y) * river_k;
		if (h < top && raise > 0.0) h = lerpf(h, top, raise);
		const double over = h - top;
		if (over > 0.0) {
			const double plain = (1.0 - smoothstep(core, core + RIVER_RAMP + over * RIVER_PLAIN_SPREAD, s)) * river_k * (1.0 - smoothstep(RIVER_PLAIN_X, RIVER_PLAIN_Y, over)) * (1.0 - smoothstep(0.0, 0.15, last_mountain)) * (1.0 - smoothstep(0.55, 0.95, last_inland));
			h -= over * plain;
		}
		const double banked = smoothstep(water - 2.5, water - 0.4, h) * (1.0 - smoothstep(double(RIVER_PLAIN_X) * 0.6, RIVER_PLAIN_X, h - top));
		w *= banked;
		last_river_w = w;
		last_river = s - w;
		if (w <= 0.0) return h;
		core = w + RIVER_BANK;
		double cut;
		if (s < w) {
			const double u = s / w;
			cut = water - river_bed * (1.0 - POW(u, 2.0 + 2.0 * river_mouth_s));
		} else if (s < core) {
			const double u = (s - w) / RIVER_BANK;
			cut = water + drop * u * u * (3.0 - 2.0 * u);
		} else {
			const double o = s - core;
			cut = water + drop + o * (1.0 + o * 0.04);
		}
		double keep = 1.0;
		if (detail > 1.0) keep = smoothstep(2.5, 4.5, (core * 2.0) / detail);
		if (cut < h) h -= (h - cut) * keep * banked;
		return h;
	}

	// --- The carve --------------------------------------------------------------------
	static int64_t lat_key(int64_t i, int64_t j) {
		return int64_t(uint64_t(i) << 32) ^ (j & 0xFFFFFFFFLL);
	}

	V3 node(int64_t i, int64_t j) {
		const int64_t slot = (i & (LAT_SLOTS - 1)) + (j & (LAT_SLOTS - 1)) * LAT_SLOTS;
		const int64_t key = lat_key(i, j);
		if (node_key[slot] == key && node_set[slot] == 1)
			return V3(node_v[slot * 3], node_v[slot * 3 + 1], node_v[slot * 3 + 2]);
		const double g = CARVE_GRID;
		const double hx0 = lat_h(i - 1, j);
		const double hx1 = lat_h(i + 1, j);
		const double hz0 = lat_h(i, j - 1);
		const double hz1 = lat_h(i, j + 1);
		const double hc = lat_h(i, j);
		const V3 v(hc, (hx1 - hx0) / (2.0 * g), (hz1 - hz0) / (2.0 * g));
		node_key[slot] = key;
		node_set[slot] = 1;
		node_v[slot * 3] = v.x;
		node_v[slot * 3 + 1] = v.y;
		node_v[slot * 3 + 2] = v.z;
		return v;
	}

	double lat_h(int64_t i, int64_t j) {
		const int64_t slot = (i & (LAT_SLOTS - 1)) + (j & (LAT_SLOTS - 1)) * LAT_SLOTS;
		const int64_t key = lat_key(i, j);
		if (h_key[slot] == key && h_set[slot] == 1) return h_v[slot];
		const double h = broad(double(i) * CARVE_GRID, double(j) * CARVE_GRID).x;
		h_key[slot] = key;
		h_set[slot] = 1;
		h_v[slot] = h;
		return h;
	}

	V3 broad_slope(double x, double z) {
		if (h_set.empty()) {
			const size_t slots = size_t(LAT_SLOTS) * LAT_SLOTS;
			node_key.assign(slots, 0);
			node_set.assign(slots, 0);
			node_v.assign(slots * 3, 0.0);
			h_key.assign(slots, 0);
			h_set.assign(slots, 0);
			h_v.assign(slots, 0.0);
		}
		const double fx = x / CARVE_GRID;
		const double fz = z / CARVE_GRID;
		const int64_t i = floori(fx);
		const int64_t j = floori(fz);
		const double u = fx - double(i);
		const double v = fz - double(j);
		if (i != int64_t(bs_key_x) || j != int64_t(bs_key_y)) {
			bs_key_x = int32_t(i);
			bs_key_y = int32_t(j);
			bs_00 = node(i, j);
			bs_10 = node(i + 1, j);
			bs_01 = node(i, j + 1);
			bs_11 = node(i + 1, j + 1);
		}
		return bs_00.lerp(bs_10, u).lerp(bs_01.lerp(bs_11, u), v);
	}

	static int64_t hash3(int64_t i, int64_t j, int64_t salt) {
		uint64_t h = (uint64_t(i) * 73856093u) ^ (uint64_t(j) * 19349663u) ^ (uint64_t(salt) * 83492791u);
		h = (h ^ uint64_t(int64_t(h) >> 13)) * 1274126177u;
		h = (h ^ uint64_t(int64_t(h) >> 16)) * 1103515245u;
		return int64_t(h ^ uint64_t(int64_t(h) >> 15)) & 0xFFFFFF;
	}

	static double rand01(int64_t h, int64_t k) {
		const uint64_t m = uint64_t(h) * (uint64_t(k) * 2654435761u + 1u);
		return double((int64_t(m) >> 7) & 0xFFFF) / 65535.0;
	}

	const float *facet_cells(int64_t ci, int64_t cj, int64_t salt) {
		if (ci == int64_t(fc_key_x) && cj == int64_t(fc_key_y)) return fc;
		fc_key_x = int32_t(ci);
		fc_key_y = int32_t(cj);
		int n = 0;
		for (int64_t dj = -1; dj < 2; ++dj) {
			for (int64_t di = -1; di < 2; ++di) {
				const int64_t hh = hash3(ci + di, cj + dj, salt);
				const double cx = (double(ci + di) + 0.1 + 0.8 * rand01(hh, 1)) * FACET_CELL;
				const double cz = (double(cj + dj) + 0.1 + 0.8 * rand01(hh, 2)) * FACET_CELL;
				const V3 c = broad_slope(cx, cz);
				V2 cg = V2::of(c.y, c.z);
				const double cl = cg.length();
				cg = cg + ((V2(rand01(hh, 3) - 0.5, rand01(hh, 4) - 0.5) * 2.0) * FACET_TILT) * cl;
				fc[n] = float(cx);
				fc[n + 1] = float(cz);
				fc[n + 2] = c.x;
				fc[n + 3] = cg.x;
				fc[n + 4] = cg.y;
				fc[n + 5] = float((rand01(hh, 5) - 0.5) * 2.0 * FACET_STEP * smoothstep(0.2, 0.8, cl));
				n += 6;
			}
		}
		return fc;
	}

	const float *gully_cells(int o, int64_t i, int64_t j, int64_t salt) {
		float *got = gc[o];
		if (int64_t(gc_key_x[o]) == i && int64_t(gc_key_y[o]) == j) return got;
		gc_key_x[o] = int32_t(i);
		gc_key_y[o] = int32_t(j);
		const double size = GULLY_SIZE[o];
		for (int c = 0; c < 4; ++c) {
			const int64_t hh = hash3(i + (c & 1), j + (c >> 1), salt + int64_t(o) * 1013);
			got[c * 2] = float(TAU / (size * (1.0 + (rand01(hh, 1) - 0.5) * 2.0 * GULLY_JITTER)));
			got[c * 2 + 1] = float(rand01(hh, 2) * TAU);
		}
		return got;
	}

	double keep_of(double size) const {
		if (detail <= 1.0) return 1.0;
		return smoothstep(CARVE_FADE_X, CARVE_FADE_Y, size / detail);
	}

	double carve_at(double x, double z, double h, double meadow, double mountain, double floor_y) {
		const V3 bs = broad_slope(x, z);
		const V2 slope = V2::of(bs.y, bs.z);
		const double steep = slope.length();
		const double mask = smoothstep(CARVE_SLOPE_X, CARVE_SLOPE_Y, steep) * smoothstep(CARVE_MOUNTAIN_X, CARVE_MOUNTAIN_Y, mountain) * (1.0 - smoothstep(0.2, 0.5, meadow)) * minf(carve, 2.0);
		if (mask <= 0.0) return h;
		const int64_t salt = int64_t(uint64_t(seed) * 31u + 7u);
		const double fk = keep_of(FACET_CELL) * FACET_KEEP * minf(mask, 1.0) * minf(carve_blocks, 1.0 / FACET_KEEP);
		V2 g = slope;
		if (fk > 0.0) {
			const float *cells = facet_cells(floori(x / FACET_CELL), floori(z / FACET_CELL), salt);
			double sum = 0.0, plane = 0.0, gsx = 0.0, gsz = 0.0;
			for (int n = 0; n < 54; n += 6) {
				const double dx = x - double(cells[n]);
				const double dz = z - double(cells[n + 1]);
				const double w = EXP(-FACET_EDGE * (dx * dx + dz * dz));
				if (w < 1e-3) continue;
				plane += w * (double(cells[n + 2]) + double(cells[n + 3]) * dx + double(cells[n + 4]) * dz + double(cells[n + 5]));
				gsx += w * double(cells[n + 3]);
				gsz += w * double(cells[n + 4]);
				sum += w;
			}
			const V2 gsum(gsx, gsz);
			if (sum > 0.0) {
				h = lerpf(h, plane / sum, fk);
				g = g.lerp(gsum / sum, fk);
			}
		}
		const double bk = minf(keep_of(BENCH) * mask * smoothstep(0.2, 0.55, nz(n_bench_band, x, z)) * carve_ledges, 1.0);
		if (bk > 0.0) {
			const double warp = nz(n_bench_warp, x, z) * BENCH * BENCH_WARP;
			const double y = (h - SEA_Y + warp) / BENCH;
			const double f = y - std::floor(y);
			const double stepped = (std::floor(y) + smoothstep(BENCH_FLAT, 1.0, f)) * BENCH - warp + SEA_Y;
			h = lerpf(h, stepped, bk);
			last_cavity = maxf(last_cavity, bk * (1.0 - smoothstep(0.0, 0.18, absf(f - BENCH_FLAT - 0.04))));
			last_ridge = maxf(last_ridge, bk * (1.0 - smoothstep(0.0, 0.1, minf(f, 1.0 - f))) * 0.8);
		}
		for (int o = 0; o < 3; ++o) {
			const double gsize = GULLY_SIZE[o];
			const double gdepth = GULLY_DEPTH[o];
			const double gk = keep_of(gsize) * mask * carve_gullies;
			if (gk <= 0.0) continue;
			const double glen = g.length();
			if (glen < 1e-4) break;
			const V2 down = g / glen;
			const V2 across = V2::of(-down.y, down.x);
			const double ax = across.x, ay = across.y;
			const double lx = x / gsize;
			const double lz = z / gsize;
			const int64_t i = floori(lx);
			const int64_t j = floori(lz);
			double u = lx - double(i);
			double v = lz - double(j);
			u = u * u * u * (u * (u * 6.0 - 15.0) + 10.0);
			v = v * v * v * (v * (v * 6.0 - 15.0) + 10.0);
			const float *corner = gully_cells(o, i, j, salt);
			const double sz = gsize;
			const double base = x * ax + z * ay - sz * (double(i) * ax + double(j) * ay);
			const double a0 = base * double(corner[0]) + double(corner[1]);
			const double a1 = (base - sz * ax) * double(corner[2]) + double(corner[3]);
			const double a2 = (base - sz * ay) * double(corner[4]) + double(corner[5]);
			const double a3 = (base - sz * (ax + ay)) * double(corner[6]) + double(corner[7]);
			const double w0 = (1.0 - u) * (1.0 - v);
			const double w1 = u * (1.0 - v);
			const double w2 = (1.0 - u) * v;
			const double w3 = u * v;
			const double wave = w0 * COS(a0) + w1 * COS(a1) + w2 * COS(a2) + w3 * COS(a3);
			const double dwave = -(w0 * SIN(a0) * double(corner[0]) + w1 * SIN(a1) * double(corner[2]) + w2 * SIN(a2) * double(corner[4]) + w3 * SIN(a3) * double(corner[6]));
			const double amp = smoothstep(-0.25, 0.35, nz(n_gully_amp, x / sz * 0.35 + double(o) * 97.0, z / sz * 0.35 - double(o) * 61.0));
			if (amp <= 0.0) continue;
			const double groove = clampf((1.0 - wave) * 0.5, 0.0, 1.0);
			const double gp1 = POW(groove, GULLY_SHARP - 1.0);
			const double gp = gp1 * groove;
			const double depth = gdepth * gk * amp * clampf(steep, 0.6, 1.6);
			const double weight = GULLY_SHADE[o] * gk * amp;
			const double rim = 1.0 - groove;
			last_cavity = maxf(last_cavity, weight * gp);
			last_ridge = maxf(last_ridge, weight * rim * rim * rim);
			h -= depth * gp;
			g = g + across * (depth * GULLY_SHARP * gp1 * 0.5 * dwave);
		}
		if (floor_y > -INF) h = maxf(h, floor_y);
		return h;
	}

	V2 old_sample(double x, double z) {
		double base = nz(n_continent, x, z) * CONTINENT_SWING * 2.0 + CONTINENT_LIFT;
		if (base > 0.0) base = LOWLAND * (1.0 - EXP(-base / LOWLAND));
		const double inland = smoothstep(-6.0, 18.0, base);
		double h = base + nz(n_hills, x, z) * HILL_TALL * 2.0 * (0.35 + 0.65 * inland);
		const double mountain = smoothstep(MOUNTAIN_BAND_X, MOUNTAIN_BAND_Y, nz(n_mask, x, z)) * inland;
		if (mountain > 0.0) {
			const double ridge = nz(n_ridges, x, z) * 0.5 + 0.5;
			h += ridge * ridge * MOUNTAIN_TALL * mountain;
		}
		const double meadow = smoothstep(MEADOW_BAND_X, MEADOW_BAND_Y, nz(n_meadows, x, z)) * inland * (1.0 - mountain);
		if (meadow > 0.0) {
			const double flat = maxf(base + (h - base) * MEADOW_KEEP, MEADOW_ABOVE);
			h = lerpf(h, flat, meadow);
		}
		if (absf(h) < BEACH * 2.0) h = h * lerpf(0.45, 1.0, smoothstep(0.0, BEACH * 2.0, absf(h)));
		return V2(SEA_Y + h, meadow);
	}
};

} // namespace zsland
