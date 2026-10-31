// The Peak's massif in C++ (docs/design/endless-flight/crown-native-handoff.md):
// scripts/endless/peak_massif.gd's profile (`_h_rock`, `_h0` and what they
// call), its chunk and grid passes (`apply_chunk`, `apply_grid`), peak_rock.gd
// and peak_split.gd's readers (`near`, `carve`), line for line, so the mountain
// is the same natively or in GDScript. The GDScript stays the fallback and the
// reference. A change to either side's maths or constants must be made to the
// other, and ZenScapePeak's `version` bumped.
//
// Numbers follow land_field.h: GDScript's are doubles; Vector2, Vector3, Vector4
// and the packed float arrays hold floats, and a double meeting a vector is
// narrowed first. So a vector constant here is its double(float) (`F`), a vector
// the GDScript does arithmetic on is a zsland::V2, and what comes back through a
// Vector is narrowed where the GDScript's is.
//
// `Massif` is immutable once `setup` has run: one per land, cached by
// peak_massif.gd and read from every worker at once. Everything here is const,
// and FastNoiseLite's GetNoise is const too.
//
// Repeatable on every machine, as the land is: land_math.h's exp/pow/sin/cos/atan2
// unless `libm` is set (--land-libm), which matches GDScript bit for bit on one
// machine. `--cirque=0` and `--spire-form=0` are not here: those run in GDScript.
#pragma once

#include "land_field.h"

namespace zspeak {

using zsland::C4;
using zsland::FNL;
using zsland::INF;
using zsland::V2;
using zsland::V3;
using zsland::absf;
using zsland::clampf;
using zsland::floori;
using zsland::lerpf;
using zsland::maxf;
using zsland::minf;
using zsland::smoothstep;

// A Vector component read back: a float, as a double.
constexpr double F(double v) { return double(float(v)); }

constexpr double SEA_Y = -40.0;
constexpr double PI = 3.1415926535897932384626433833;

struct V4 {
	float x = 0, y = 0, z = 0, w = 0;
};

inline float dot(const V2 &a, const V2 &b) { return a.x * b.x + a.y * b.y; }
inline float length_squared(const V2 &a) { return a.x * a.x + a.y * a.y; }

// --- peak_massif.gd's constants -----------------------------------------------------

constexpr double O_ALONG = 1600.0, RING_R = 1350.0;
constexpr double CREST_POS[] = {0.0, 880.0, 3.0, 862.0, 6.0, 900.0, 9.0, 835.0, 12.0, 866.0, 15.0, 770.0, 19.0, 790.0,
	23.0, 690.0, 27.0, 705.0, 32.0, 600.0, 38.0, 570.0, 46.0, 510.0, 60.0, 440.0, 80.0, 380.0, 100.0, 340.0,
	120.0, 285.0, 140.0, 215.0, 155.0, 135.0, 168.0, 40.0};
constexpr double CREST_NEG[] = {0.0, 880.0, 4.0, 902.0, 7.0, 925.0, 10.0, 868.0, 12.0, 840.0, 14.0, 862.0, 16.0, 890.0,
	19.0, 835.0, 23.0, 862.0, 27.0, 780.0, 31.0, 800.0, 36.0, 720.0, 42.0, 680.0, 60.0, 590.0, 80.0, 500.0,
	100.0, 430.0, 120.0, 350.0, 140.0, 270.0, 155.0, 170.0, 168.0, 40.0};
constexpr int CREST_POS_N = int(sizeof(CREST_POS) / sizeof(double));
constexpr int CREST_NEG_N = int(sizeof(CREST_NEG) / sizeof(double));
constexpr double RIB_SPUR = -0.7, RIB_WANDER = 3.0, RIB_IN = 55.0, RIB_ARM = 60.0, RIB_OUT = 115.0, RIB_GROW = 380.0;
constexpr double RIB_WIDE_SHARE = 0.45;
const double RIB_FOOT_X = F(300.0), RIB_FOOT_Y = F(560.0);
constexpr int RIB_STRIDE = 7;
constexpr double ARM_END = 168.0;
constexpr double WALL_FOOT = 520.0, WALL_RUN = 600.0, TALUS_FALL = 0.4, TALUS_SHARE = 0.22, TALUS_TOP = 0.6;
constexpr double CLIFF_X = F(0.45), CLIFF_Y = F(0.97);
constexpr double ARM_IN_X = F(0.8), ARM_IN_Y = F(0.42);
constexpr double SHOULDER_X = F(90.0), SHOULDER_Y = F(520.0), SHOULDER_Z = F(600.0);
constexpr double PLATEAU_Y = 880.0, LIP_Y = 895.0, BACK_RUN = 2000.0, BACK_BOW = 1.8, KNIFE_BOW = 2.6;
constexpr double ARM_OUT_RUN = 1100.0, ARM_OUT_BOW = 1.5, FALL_END = -60.0, PAST_END = 1.0;
constexpr double ICEFALL_X = F(850.0), ICEFALL_Y_ = F(1250.0), ICEFALL_YX = F(520.0), ICEFALL_YY = F(400.0);
constexpr double ICEFALL_STEPS = 3, ICEFALL_RISER = 0.35;
constexpr double BOULDERS_X = F(1250.0), BOULDERS_Y_ = F(2050.0), BOULDERS_YX = F(400.0), BOULDERS_YY = F(300.0);
constexpr double GLACIER_X = F(2050.0), GLACIER_Y_ = F(3100.0), GLACIER_YX = F(300.0), GLACIER_YY = F(100.0);
constexpr double TOE_X = F(3100.0), TOE_Y = F(3500.0);
constexpr double FLOOR_HALF_X = F(200.0), FLOOR_HALF_Y = F(240.0), FLOOR_HALF_Z = F(260.0), FLOOR_HALF_W = F(330.0);
constexpr double GL_BEND = 170.0, GL_TURNS = 1.6, ICE_BULGE = 6.0;
constexpr double SIDE_UP = 80.0, SIDE_RUN = 170.0, SIDE_GAP = 70.0, SIDE_FALL = 0.4, SIDE_DIP = 15.0, SIDE_DIP_TO = 2200.0, SHELF_FALL = 1.0;
constexpr double MOR_UP = 30.0, MOR_AT = 30.0, MOR_W = 48.0;
constexpr double CREV_BAND = 430.0, CREV_SHARE = 0.35, CREV_SP = 26.0, CREV_W = 9.0, CREV_DEEP = 5.0, CREV_ARC = 60.0;
constexpr double LUMPS = 2.5, LUMP_SCALE = 3.7;
constexpr double TARN_BOWL = 130.0, TARN_DEEP = 5.0, SHORE_DROP = 18.0, SHORE_RUN = 1.55;
constexpr double SHORE_FALL_X = F(30.0), SHORE_FALL_Y = F(90.0), SHORE_ACROSS_X = F(130.0), SHORE_ACROSS_Y = F(200.0);
constexpr double CIRQUE_R = 250.0;
constexpr double CIRQUE_LOBE_X = F(0.07), CIRQUE_LOBE_Y = F(0.09), CIRQUE_LOBE_Z = F(0.04);
constexpr double CIRQUE_OUT_X = F(1.08), CIRQUE_OUT_Y = F(1.3), CIRQUE_FRONT_X = F(165.0), CIRQUE_FRONT_Y = F(215.0);
constexpr double FLOOR_RISE = 14.0;
constexpr double KNOBS_X = F(9.0), KNOBS_Y = F(60.0), KNOBS_Z = F(0.05), SWELL_X = F(9.0), SWELL_Y = F(150.0);
constexpr double RIM_X = F(14.0), RIM_Y = F(34.0), RIM_Z = F(0.16), QUIET_X = F(1.5), QUIET_Y = F(2.3);
constexpr double STRIP_X = F(120.0), STRIP_Y = F(118.0), STRIP_Z = F(22.0), STRIP_W = F(16.0);
constexpr double APRON_X = F(88.0), APRON_Y = F(16.0);
constexpr double CROWN_GIRTH[3] = {82.0, 70.0, 60.0};
constexpr double PLINTH_TOPS[3] = {985.0, 955.0, 930.0};
struct Arete {
	int p, q;
	double sag;
};
constexpr Arete ARETES[2] = {{0, 1, 90.0}, {1, 2, 70.0}};
constexpr double ARETE_FALL = 1.6, ARETE_BREAK = 34.0, CROWN_REACH = 1140.0;
constexpr double ROOT_TOPS[3][2] = {{1060.0, 230.0}, {1010.0, 215.0}, {975.0, 195.0}};
constexpr double ROOT_FALL = 0.75, ROOT_TOP = 120.0, ROOT_RIDGE = 0.35;
constexpr double ROOT_GROW_X = F(60.0), ROOT_GROW_Y = F(300.0);
constexpr double ROOT_END = 420.0, ROOT_SINK = 0.0012, ROOT_BLEND = 60.0, ROOT_ROUGH = 19.0, ROOT_NEAR = 300.0, ROOT_SLACK = 110.0;
constexpr double ROOT_SHIFT_Y = F(220.0);
struct Shoulder {
	int tower;
	double a, v, end, top;
};
constexpr Shoulder SHOULDERS[2] = {{0, 520.0, -790.0, 770.0, 1040.0}, {2, 470.0, 770.0, 740.0, 985.0}};
constexpr double SHOULDER_FALL = 1.15, SHOULDER_BOW = 1.7;
constexpr double LANE_X = F(60.0), LANE_Y = F(120.0), LANE_FROM_X = F(150.0), LANE_FROM_Y = F(230.0), LANE_TOP = 872.0;
constexpr double CIRQUE_REACH2 = 202500.0;
constexpr double TOWER_R = 18.0, TOWER_FALL = 2.5;
constexpr double ROUGH = 12.0, ROUGH_SCALE = 90.0;
constexpr double ROCK_STEEP_X = F(0.14), ROCK_STEEP_Y = F(0.45), ROCK_FOOT_X = F(6.0), ROCK_FOOT_Y = F(44.0);
constexpr double ROCK_CIRQUE_X = F(190.0), ROCK_CIRQUE_Y = F(260.0), ROCK_TOWER_X = F(0.9), ROCK_TOWER_Y = F(1.5);
constexpr double ROCK_PAINT = 5.0, ROCK_LIFT = 0.8;
constexpr double BOUND = 4050.0;
constexpr double MASK_CELL = 64.0;

// --- peak_rock.gd's --------------------------------------------------------------

namespace rock {
constexpr double BUTTRESS_X = F(190.0), BUTTRESS_Y = F(17.0), RIB_X = F(68.0), RIB_Y = F(11.0);
constexpr double GULLY_X = F(24.0), GULLY_Y = F(5.0), CHIP_X = F(8.5), CHIP_Y = F(1.6);
constexpr double KEEP_QUADS = 3.5, BLOCKS = 3.0, BLOCK_EDGE = 0.28, PLANES = 330.0, MOVE_MOST = 30.0, PAINT_RIB = 0.3;
constexpr double LEDGE_X = F(30.0), LEDGE_Y = F(0.42), LEDGE_BITE = 0.75, LEDGE_QUAD = 4.0;
constexpr double FOLD_AX = F(0.0041), FOLD_AY = F(0.0029), FOLD_AZ = F(46.0);
constexpr double FOLD_BX = F(-0.011), FOLD_BY = F(0.007), FOLD_BZ = F(20.0);
constexpr double FOLD_CX = F(0.11), FOLD_CY = F(0.14);
constexpr double LEDGE_PATCH = 150.0;
} // namespace rock

// --- peak_split.gd's --------------------------------------------------------------

namespace split {
constexpr double A_SPAN_X = F(120.0), V_SPAN_X = F(-1060.0), CELL = 20.0, FAR = 400.0, REACH = 240.0;
constexpr double NOSE_Y = 308.0, APRON_BACK = 240.0, A_SPAN_Y = F(2240.0);
constexpr double SPILL_AX = F(2050.0), SPILL_AY = F(2185.0), SPILL_V = 160.0, SPILL_Y = 306.0, SPILL_GRADE = 0.27;
constexpr double SPILL_HALF_X = F(122.0), SPILL_HALF_Y = F(64.0), SPILL_SIDE = 0.5;
constexpr double SLOPE = 2.6, FOOT = 10.0, ELBOW = 70.0, EASE = 1.15, BOW_EASE = 2.4;
constexpr double BOW_AX = F(1500.0), BOW_AY = F(1780.0);
constexpr double BUTTRESS = 22.0, SPUR_SCALE = 0.55, BAND_X = F(8.0), BAND_Y = F(0.098), FLOOR_ROUGH = 0.3;
constexpr double RIDGE_UP = 170.0, RIDGE = 62.0, OUT_FALL = 2.0;
constexpr double RIDGE_IN_X = F(330.0), RIDGE_IN_Y = F(480.0), RIDGE_LOW_X = F(640.0), RIDGE_LOW_Y = F(830.0), RIDGE_LOWS = 0.25;
constexpr double RIDGE_OUT_X = F(835.0), RIDGE_OUT_Y = F(872.0);
constexpr double TOP_BREAK = 40.0, ROOF_RISE = 0.42, FLANK_X = F(0.9), FLANK_Y = F(1.5), SPINE_WANDER = 34.0;
constexpr double SIGHT_A = 3500.0, SIGHT_EYE = 25.0, SIGHT_Y = 1000.0, SIGHT_TO = -260.0;
constexpr double SIGHT_OVER_X = F(300.0), SIGHT_OVER_Y = F(190.0), SIGHT_OVER_AX = F(1820.0), SIGHT_OVER_AY = F(1450.0);
constexpr double OUTER_UNDER = 40.0, OUTER_FREE_X = F(1650.0), OUTER_FREE_Y = F(1250.0);
constexpr double NOTCH = 75.0, NOTCH_SCALE = 0.3;
} // namespace split

class Massif {
public:
	// --- Set once by ZenScapePeak::setup, then only read ------------------------------
	bool libm = false, rock_on = true;
	V2 centre, facing, side, o;
	FNL noise, rock_n;
	std::vector<float> ribs[8];
	std::vector<V2> towers, crown, root_way;
	std::vector<float> tower_tops, crown_ph;
	V2 tarn_c;
	double tarn_wet = 0.0;
	std::vector<float> pond;
	float cq_ph_x = 0, cq_ph_y = 0, cq_ph_z = 0;
	// The mask (`_mask`): live cells, and the fall map (three floats a corner).
	std::vector<uint8_t> live;
	int live_n = 0;
	V2 live_at;
	std::vector<float> fall_map;
	// The split's grid (peak_split.gd).
	std::vector<float> s_e[2], s_f[2], s_hull, s_gap, s_tops, s_spine;
	int s_na = 0, s_nv = 0;

	void noises(int rough_seed, int rock_seed) {
		noise.SetSeed(rough_seed);
		noise.SetNoiseType(FNL::NoiseType_OpenSimplex2S);
		noise.SetFrequency(float(1.0 / ROUGH_SCALE));
		noise.SetFractalType(FNL::FractalType_FBm);
		noise.SetFractalOctaves(4);
		rock_n.SetSeed(rock_seed);
		rock_n.SetNoiseType(FNL::NoiseType_OpenSimplex2S);
		rock_n.SetFrequency(1.0f);
		rock_n.SetFractalType(FNL::FractalType_None);
	}

	double EXP(double v) const { return libm ? std::exp(v) : zsland::det_exp(v); }
	double POW(double a, double b) const { return libm ? std::pow(a, b) : zsland::det_pow(a, b); }
	double SIN(double v) const { return libm ? std::sin(v) : zsland::det_sin(v); }
	double COS(double v) const { return libm ? std::cos(v) : zsland::det_cos(v); }
	double ATAN2(double y, double x) const { return libm ? std::atan2(y, x) : zsland::det_atan2(y, x); }

	static double nz(const FNL &n, double x, double y) {
		const float fx = float(x) + 0.0f;
		const float fy = float(y) + 0.0f;
		return double(n.GetNoise(fx, fy));
	}

	// `reaches`.
	bool reaches(double x, double z) const {
		const double dx = x - double(o.x), dz = z - double(o.y);
		return dx * dx + dz * dz < BOUND * BOUND && live_cell(x, z);
	}
	bool live_cell(double x, double z) const {
		if (live_n == 0) return true;
		const int64_t i = floori((x - double(live_at.x)) / MASK_CELL);
		const int64_t j = floori((z - double(live_at.y)) / MASK_CELL);
		if (i < 0 || j < 0 || i >= live_n || j >= live_n) return false;
		return live[size_t(j * live_n + i)] == 1;
	}

	// `_h_rock`: (height, cut, meadow, paint).
	V4 h_rock(double a, double v, double step) const {
		float f_x = 0.0f, f_y = 0.0f, f_z = 0.0f;
		if (rock_on) falls(a, v, f_x, f_y, f_z);
		const double keep = double(f_x) > ROCK_STEEP_X ? rock_keep(a, v, double(f_x)) : 0.0;
		V3 hm;
		if (keep <= 0.0) {
			hm = h0(a, v);
			V4 r;
			r.x = hm.x;
			r.y = hm.y;
			r.z = hm.z;
			return r;
		}
		const V2 m = move(a, v, step);
		const double e = near(a, v);
		const double air = smoothstep(ROCK_FOOT_X, ROCK_FOOT_Y, e);
		const double w = lerpf(minf(double(m.x), 0.0) * smoothstep(0.0, ROCK_FOOT_X, e), double(m.x), air) * keep;
		hm = h0(a + double(f_y) * w, v + double(f_z) * w);
		const double fx = double(facing.x), fz = double(facing.y), sx = double(side.x), sz = double(side.y);
		hm.x = float(ledge(double(hm.x), double(centre.x) + fx * a + sx * v, double(centre.y) + fz * a + sz * v, a, v, keep * air, step) + double(m.y) * ROCK_LIFT * keep * air);
		V4 r;
		r.x = hm.x;
		r.y = hm.y;
		r.z = hm.z;
		r.w = float(clampf(double(m.y) / ROCK_PAINT, -1.0, 1.0) * keep * smoothstep(0.0, ROCK_FOOT_X, e));
		return r;
	}

	// `apply` with `step`: (height, meadow) for `base` at (x, z); `lift` is
	// `last_lift`.
	V2 apply(float base_h, float base_m, double x, double z, double step, double &lift) const {
		const V2 q = V2(x, z) - centre;
		const V4 hm = h_rock(double(dot(q, facing)), double(dot(q, side)), step);
		const double by = double(base_h) - SEA_Y;
		const double y = lerpf(maxf(by, double(hm.x)), double(hm.x), double(hm.y));
		lift = y - by;
		const double m = maxf(double(base_m) * (1.0 - smoothstep(0.5, 6.0, absf(lift))), double(hm.z));
		return V2(y + SEA_Y, m);
	}

private:
	// `_falls`.
	void falls(double a, double v, float &s, float &ua, float &uv) const {
		if (fall_map.empty()) return;
		double fi = (double(centre.x) + double(facing.x) * a + double(side.x) * v - double(live_at.x)) / MASK_CELL;
		double fj = (double(centre.y) + double(facing.y) * a + double(side.y) * v - double(live_at.y)) / MASK_CELL;
		const int64_t i = int64_t(fi);
		const int64_t j = int64_t(fj);
		if (fi < 0.0 || fj < 0.0 || i >= live_n || j >= live_n) return;
		fi -= double(i);
		fj -= double(j);
		const int64_t m = live_n + 1;
		const int64_t k0 = (j * m + i) * 3, k1 = k0 + 3, k2 = k0 + m * 3, k3 = k2 + 3;
		const double w0 = (1.0 - fi) * (1.0 - fj), w1 = fi * (1.0 - fj), w2 = (1.0 - fi) * fj, w3 = fi * fj;
		const float *t = fall_map.data();
		s = float(double(t[k0]) * w0 + double(t[k1]) * w1 + double(t[k2]) * w2 + double(t[k3]) * w3);
		ua = float(double(t[k0 + 1]) * w0 + double(t[k1 + 1]) * w1 + double(t[k2 + 1]) * w2 + double(t[k3 + 1]) * w3);
		uv = float(double(t[k0 + 2]) * w0 + double(t[k1 + 2]) * w1 + double(t[k2 + 2]) * w2 + double(t[k3 + 2]) * w3);
	}

	// `_rock_keep`.
	double rock_keep(double a, double v, double s) const {
		double k = smoothstep(ROCK_STEEP_X, ROCK_STEEP_Y, s);
		if (k <= 0.0) return 0.0;
		const double rho2 = a * a + v * v;
		if (rho2 < CIRQUE_REACH2) k *= smoothstep(ROCK_CIRQUE_X, ROCK_CIRQUE_Y, std::sqrt(rho2));
		if (rho2 < CROWN_REACH * CROWN_REACH) {
			const V2 at(a, v);
			for (size_t t = 0; t < crown.size(); ++t) {
				const double g = CROWN_GIRTH[t];
				k *= smoothstep(g * ROCK_TOWER_X, g * ROCK_TOWER_Y, double((at - crown[t]).length()));
			}
		}
		return k;
	}

	// PeakRock `_ridged`.
	double ridged(double x, double y) const { return 1.0 - 2.8 * absf(nz(rock_n, x, y)); }

	// PeakRock `move`.
	V2 move(double a, double v, double step) const {
		using namespace rock;
		const double c = step * KEEP_QUADS;
		const double quiet = smoothstep(-0.25, 0.3, nz(rock_n, a / PLANES + 91.0, v / PLANES - 37.0));
		double w = 0.0, paint = 0.0;
		if (BUTTRESS_X >= c) {
			const double r = clampf(ridged(a / BUTTRESS_X, v / BUTTRESS_X) * 0.5 + 0.5, 0.0, 1.0) * BLOCKS;
			const double k = std::floor(r);
			w = (k + smoothstep(0.5 - BLOCK_EDGE, 0.5 + BLOCK_EDGE, r - k)) / BLOCKS * 2.0 - 1.0;
			w *= BUTTRESS_Y;
		}
		if (RIB_X >= c) {
			const double r = ridged(a / RIB_X + 13.0, v / RIB_X + 5.0) * RIB_Y * (0.45 + 0.55 * quiet);
			w += r;
			paint += r * PAINT_RIB;
		}
		if (GULLY_X >= c) {
			const double g = ridged(a / GULLY_X - 31.0, v / GULLY_X + 17.0) * GULLY_Y * (0.4 + 0.6 * quiet);
			w += g;
			paint += g;
		}
		if (CHIP_X >= c) {
			const double p = ridged(a / CHIP_X + 7.0, v / CHIP_X - 23.0) * CHIP_Y * (0.4 + 0.6 * quiet);
			w += p;
			paint += p;
		}
		return V2(clampf(w, -MOVE_MOST, MOVE_MOST), paint);
	}

	// PeakRock `ledge`.
	double ledge(double h, double x, double z, double a, double v, double keep, double step) const {
		using namespace rock;
		if (step > LEDGE_QUAD) return h;
		const double on = smoothstep(-0.2, 0.2, nz(rock_n, a / LEDGE_PATCH - 53.0, v / LEDGE_PATCH + 71.0)) * keep;
		if (on <= 0.001) return h;
		const double fold = FOLD_AZ * SIN(x * FOLD_AX + z * FOLD_AY) + FOLD_BZ * SIN(x * FOLD_BX + z * FOLD_BY + 1.3) + x * FOLD_CX + z * FOLD_CY;
		const double s = (h + fold) / LEDGE_X;
		const double f = s - std::floor(s);
		return h + (smoothstep(0.0, LEDGE_Y, f) - f) * LEDGE_X * on * LEDGE_BITE;
	}

	// PeakSplit `near`.
	double near(double a, double v) const {
		using namespace split;
		const double x = (a - A_SPAN_X) / CELL;
		const double y = (v - V_SPAN_X) / CELL;
		if (x < 0.0 || y < 0.0) return FAR;
		const int64_t i = int64_t(x);
		const int64_t j = int64_t(y);
		if (i >= s_na - 1 || j >= s_nv - 1) return FAR;
		const int64_t k = j * s_na + i;
		const double fx = x - double(i), fy = y - double(j);
		const float *e0 = s_e[0].data(), *e1 = s_e[1].data();
		const double w00 = (1.0 - fx) * (1.0 - fy), w10 = fx * (1.0 - fy), w01 = (1.0 - fx) * fy, w11 = fx * fy;
		return minf(double(e0[k]) * w00 + double(e0[k + 1]) * w10 + double(e0[k + s_na]) * w01 + double(e0[k + s_na + 1]) * w11,
				double(e1[k]) * w00 + double(e1[k + 1]) * w10 + double(e1[k + s_na]) * w01 + double(e1[k + s_na + 1]) * w11);
	}

	static double split_far(double a) { return split::NOSE_Y + (split::A_SPAN_Y - 250.0 - a) * 0.31; }
	static double split_sight(double a) {
		using namespace split;
		return SIGHT_EYE + (SIGHT_Y - SIGHT_EYE) * (SIGHT_A - a) / (SIGHT_A - SIGHT_TO);
	}
	double split_rise(double ee, double tier, double ease) const {
		using namespace split;
		if (ee <= 0.0) return 0.0;
		double r;
		if (ee < FOOT) r = SLOPE * ee * ee / (2.0 * FOOT);
		else if (ee < ELBOW) r = SLOPE * (ee - FOOT * 0.5);
		else r = SLOPE * (ELBOW - FOOT * 0.5) + ease * (ee - ELBOW);
		return r + BAND_X * SIN(r * BAND_Y + tier) * minf(ee / FOOT, 1.0);
	}
	static double split_edge(double f) {
		using namespace split;
		return RIDGE_UP * (1.0 - RIDGE_LOWS * smoothstep(RIDGE_LOW_X, RIDGE_LOW_Y, f)) * (1.0 - smoothstep(RIDGE_OUT_X, RIDGE_OUT_Y, f));
	}
	static double split_ridge(double f) { return smoothstep(split::RIDGE_IN_X, split::RIDGE_IN_Y, f) * split_edge(f); }
	static double split_spill(double a, double v, double spur) {
		using namespace split;
		const double d = maxf(a - SPILL_AX, 0.0);
		const double t = clampf(d / (SPILL_AY - SPILL_AX), 0.0, 1.0);
		const double half = lerpf(SPILL_HALF_X, SPILL_HALF_Y, t * t) + spur * 30.0;
		return SPILL_Y - SPILL_GRADE * d - SPILL_SIDE * maxf(absf(v - SPILL_V) - half, 0.0);
	}

	// PeakSplit `carve` (`rough` is ROUGH).
	double carve(double a, double v, double h, double n) const {
		using namespace split;
		const double rough = ROUGH;
		const double x = (a - A_SPAN_X) / CELL;
		const double y = (v - V_SPAN_X) / CELL;
		if (x < 0.0 || y < 0.0) return h;
		const int64_t i = int64_t(x);
		const int64_t j = int64_t(y);
		if (i >= s_na - 1 || j >= s_nv - 1) return h;
		const int64_t k = j * s_na + i;
		const double fx = x - double(i), fy = y - double(j);
		const float *e0 = s_e[0].data(), *e1 = s_e[1].data();
		const double w00 = (1.0 - fx) * (1.0 - fy), w10 = fx * (1.0 - fy), w01 = (1.0 - fx) * fy, w11 = fx * fy;
		const int64_t k1 = k + 1, k2 = k + s_na, k3 = k2 + 1;
		const double ei = double(e0[k]) * w00 + double(e0[k1]) * w10 + double(e0[k2]) * w01 + double(e0[k3]) * w11;
		const double er = double(e1[k]) * w00 + double(e1[k1]) * w10 + double(e1[k2]) * w01 + double(e1[k3]) * w11;
		const float *ph = s_hull.data();
		const double hull = double(ph[k]) * w00 + double(ph[k1]) * w10 + double(ph[k2]) * w01 + double(ph[k3]) * w11;
		if (ei >= FAR - 1.0 && er >= FAR - 1.0 && hull <= 0.0) return h;
		const float *f0 = s_f[0].data(), *f1 = s_f[1].data(), *pg = s_gap.data();
		const double fi = double(f0[k]) * w00 + double(f0[k1]) * w10 + double(f0[k2]) * w01 + double(f0[k3]) * w11;
		const double fr = double(f1[k]) * w00 + double(f1[k1]) * w10 + double(f1[k2]) * w01 + double(f1[k3]) * w11;
		const double gap = double(pg[k]) * w00 + double(pg[k1]) * w10 + double(pg[k2]) * w01 + double(pg[k3]) * w11;
		const double spur = nz(noise, a * SPUR_SCALE + 1900.0, v * SPUR_SCALE - 1300.0);
		const double wander = BUTTRESS * spur * 1.6;
		const double tier = spur * 5.0;
		const double notch = NOTCH * smoothstep(0.02, 0.3, nz(noise, a * NOTCH_SCALE + 3100.0, v * NOTCH_SCALE - 700.0));
		double mass = h;
		const double nearest = minf(ei, er);
		const double bow = smoothstep(BOW_AX, BOW_AY, a);
		const double line = split_sight(a);
		const double out = rough * n;
		const double inner = clampf(hull * 2.0 - 0.5, 0.0, 1.0);
		if (hull > 0.0) {
			const double t = (a - A_SPAN_X) / 50.0;
			const int64_t size = int64_t(s_tops.size());
			const int64_t ti_raw = int64_t(t);
			const int64_t ti = ti_raw < 0 ? 0 : (ti_raw > size - 2 ? size - 2 : ti_raw);
			const float *tops = s_tops.data(), *spine = s_spine.data();
			double top = lerpf(double(tops[ti]), double(tops[ti + 1]), t - double(ti)) - TOP_BREAK * maxf(nz(noise, a * 0.45 - 2100.0, v * 0.45 + 800.0) * 2.0 + 0.3, 0.0);
			const double off = absf(v - lerpf(double(spine[ti]), double(spine[ti + 1]), t - double(ti)) + SPINE_WANDER * spur * 2.0);
			const double over = lerpf(SIGHT_OVER_Y, SIGHT_OVER_X, smoothstep(SIGHT_OVER_AY, SIGHT_OVER_AX, a));
			top = minf(top, line + over * gap) - notch * smoothstep(1850.0, 1650.0, a);
			const double fb = lerpf(lerpf(fr, fi, smoothstep(-80.0, 80.0, er - ei)), split_far(a), smoothstep(120.0, 225.0, nearest));
			const double bench = fb + split_edge(fb);
			const double wall = bench + lerpf(ROOF_RISE, BOW_EASE, bow) * clampf(nearest - RIDGE, 0.0, 165.0);
			const double roof = minf(top, minf(wall, maxf(top - lerpf(FLANK_X, FLANK_Y, bow) * off, bench))) + out;
			mass = maxf(mass, roof);
		}
		if (inner < 1.0) {
			const double free_ = smoothstep(OUTER_FREE_X, OUTER_FREE_Y, a) * gap;
			const double cap = line - OUTER_UNDER + free_ * 600.0 - notch;
			if (ei < REACH) mass = maxf(mass, minf(fi + split_ridge(fi) - notch - maxf(ei - RIDGE, 0.0) * OUT_FALL, cap) + out);
			if (er < REACH) mass = maxf(mass, minf(fr + split_ridge(fr) - notch - maxf(er - RIDGE, 0.0) * OUT_FALL, cap) + out);
		}
		const double low = n * rough * FLOOR_ROUGH * smoothstep(APRON_BACK, APRON_BACK + 50.0, a);
		const double ease = lerpf(EASE, BOW_EASE, bow);
		const double y0 = ei < FAR - 1.0 ? fi + split_rise(ei + wander, tier, ease) + low : INF;
		const double y1 = er < FAR - 1.0 ? fr + split_rise(er + wander, tier, ease) + low : INF;
		double cut = minf(mass, minf(y0, y1));
		if (a > SPILL_AX - 30.0) cut = maxf(cut, split_spill(a, v, spur));
		const double fill = smoothstep(350.0, 310.0, a) * (1.0 - smoothstep(0.0, 30.0, nearest));
		if (fill <= 0.0) return cut;
		return lerpf(cut, maxf(cut, minf(y0, y1)), fill);
	}

	// `_crest`.
	static double crest(double th, double s) {
		const double *cr = s > 0.0 ? CREST_POS : CREST_NEG;
		const int size = s > 0.0 ? CREST_POS_N : CREST_NEG_N;
		int k = 0;
		while (k + 4 < size && th > cr[k + 2]) k += 2;
		const double t0 = cr[k], t1 = cr[k + 2];
		return lerpf(cr[k + 1], cr[k + 3], clampf((th - t0) / (t1 - t0), 0.0, 1.0));
	}

	// `_rib`.
	double rib(double th, double s, bool outer, double e) const {
		const int k = (s > 0.0 ? 2 : 0) + (outer ? 1 : 0);
		const double tw = th + RIB_WANDER * nz(noise, th * 2.5 + 600.0 * double(k), e * 0.35 + 3000.0) * smoothstep(0.0, 300.0, e);
		const double r = rib_in(ribs[k * 2], tw, e) * (1.0 - RIB_WIDE_SHARE) + rib_in(ribs[k * 2 + 1], tw, e) * RIB_WIDE_SHARE;
		return lerpf(0.0, r, smoothstep(0.0, 3.0, th));
	}

	// `_rib_in`.
	double rib_in(const std::vector<float> &tv, double th, double e) const {
		const float *t = tv.data();
		int lo = 0;
		int hi = int(tv.size()) / RIB_STRIDE - 1;
		while (lo < hi) {
			const int mid = (lo + hi + 1) >> 1;
			if (double(t[mid * RIB_STRIDE]) <= th) lo = mid;
			else hi = mid - 1;
		}
		const int i = lo * RIB_STRIDE;
		const double f = clampf((th - double(t[i])) / double(t[i + 1]), 0.0, 1.0);
		const double c = t[i + 3];
		const double g = f < c ? (c - f) / c : (f - c) / (1.0 - c);
		const double amp = double(t[i + 2]) * smoothstep(double(t[i + 5]), double(t[i + 5]) + 90.0, e) * (1.0 - smoothstep(double(t[i + 6]) - 150.0, double(t[i + 6]), e));
		return RIB_SPUR + (1.0 - RIB_SPUR) * amp * (1.0 - POW(g, double(t[i + 4])));
	}

	// `_valley_mid`.
	double valley_mid(double a) const {
		const double t = clampf((a - BOULDERS_X) / (TOE_Y - BOULDERS_X), 0.0, 1.0);
		return GL_BEND * SIN(PI * GL_TURNS * t) * smoothstep(0.0, 0.25, t);
	}

	// `_crown_rock`, the roots on: the aretes.
	double crown_rock(double a, double v, double n) const {
		double h = -INF;
		const V2 at(a, v);
		for (const Arete &e : ARETES) {
			const V2 p = crown[size_t(e.p)];
			const V2 pq = crown[size_t(e.q)] - p;
			const double t = clampf(double(dot(at - p, pq)) / double(length_squared(pq)), 0.0, 1.0);
			const double off = double((at - (p + pq * t)).length());
			if (off > 300.0) continue;
			const double sag = 4.0 * t * (1.0 - t);
			double y = lerpf(PLINTH_TOPS[e.p], PLINTH_TOPS[e.q], t) - e.sag * sag;
			y += ARETE_BREAK * nz(noise, t * double(pq.length()) * 2.5 + double(e.p) * 900.0, 5000.0) * sag;
			const double top = y - off * ARETE_FALL + n * ROUGH * 1.2;
			if (top > h) h = top;
		}
		return h;
	}

	// `_roots`.
	double roots(double a, double v, double n, double h) const {
		double top = -INF;
		for (size_t k = 0; k < crown.size(); ++k) {
			double dx = a - double(crown[k].x);
			double dv = v - double(crown[k].y);
			double r = std::sqrt(dx * dx + dv * dv);
			const double row0 = ROOT_TOPS[k][0], row1 = ROOT_TOPS[k][1];
			if (r > ROOT_NEAR && row0 - ROOT_FALL * (r - ROOT_SLACK) + ROOT_ROUGH < minf(top, h - ROOT_BLEND)) continue;
			const double moved = EXP(-r / ROOT_SHIFT_Y);
			dx -= double(root_way[k].x) * moved;
			dv -= double(root_way[k].y) * moved;
			r = std::sqrt(dx * dx + dv * dv);
			const double phi = ATAN2(dv, dx) + double(crown_ph[k]);
			const double gully = 0.65 * absf(SIN(1.5 * phi)) + 0.35 * absf(SIN(2.5 * phi + 1.3));
			const double e = r * (1.0 + ROOT_RIDGE * gully * smoothstep(ROOT_GROW_X, ROOT_GROW_Y, r));
			const double past = maxf(e - ROOT_END, 0.0);
			const double y = row0 - ROOT_FALL * e + row1 * EXP(-e / ROOT_TOP) - past * past * ROOT_SINK + n * ROOT_ROUGH;
			if (y > top) top = y;
		}
		for (const Shoulder &s : SHOULDERS) {
			const V2 p = crown[size_t(s.tower)];
			const V2 pq = V2(s.a, s.v) - p;
			const V2 at(a, v);
			const double t = clampf(double(dot(at - p, pq)) / double(length_squared(pq)), 0.0, 1.0);
			const double off = double((at - (p + pq * t)).length());
			if (off > 320.0) continue;
			double y = s.end + (s.top - s.end) * POW(1.0 - t, SHOULDER_BOW) - off * SHOULDER_FALL + n * ROOT_ROUGH - 500.0 * smoothstep(0.82, 1.0, t);
			if (y + ARETE_BREAK * 1.4 < minf(top, h - ROOT_BLEND)) continue;
			y += ARETE_BREAK * 1.4 * nz(noise, t * double(pq.length()) * 2.5 + double(s.tower) * 700.0, 7000.0);
			if (y > top) top = y;
		}
		const double lane = (1.0 - smoothstep(LANE_X, LANE_Y, absf(a - STRIP_X))) * smoothstep(LANE_FROM_X, LANE_FROM_Y, absf(v));
		if (lane > 0.0 && top > LANE_TOP) top = lerpf(top, LANE_TOP, lane);
		const double gap = maxf(ROOT_BLEND - absf(h - top), 0.0) / ROOT_BLEND;
		return maxf(h, top) + gap * gap * ROOT_BLEND * 0.25;
	}

	// `_wall`.
	double wall(double e, double hc) const {
		if (e >= WALL_RUN) return WALL_FOOT - (e - WALL_RUN) * TALUS_FALL;
		const double t = 1.0 - maxf(e, 0.0) / WALL_RUN;
		return WALL_FOOT + (hc - WALL_FOOT) * (TALUS_SHARE * smoothstep(0.0, TALUS_TOP, t) + (1.0 - TALUS_SHARE) * smoothstep(CLIFF_X, CLIFF_Y, t));
	}

	// `_fall`.
	double fall(double top, double d, double run, double bow) const {
		if (d >= run) return FALL_END - (d - run) * PAST_END;
		return top - (top - FALL_END) * (1.0 - POW(1.0 - d / run, bow));
	}

	// `_h0`, the cirque and the roots on (`--cirque=0`, `--spire-form=0`: GDScript).
	V3 h0(double a, double v) const {
		const double n = nz(noise, a, v);
		const double av = absf(v);
		const double sg = v >= 0.0 ? 1.0 : -1.0;
		const double oa = a - O_ALONG;
		const double r = std::sqrt(oa * oa + v * v);
		const double th = ATAN2(av, -oa) * (180.0 / PI);
		double h = -INF, c = 0.0;
		const double meadow = 0.0;
		if (th < ARM_END + 10.0) {
			const double hc = crest(th, sg);
			const double d = r - RING_R;
			double rough = 1.0, hr;
			if (d < 0.0) {
				const double e = -d;
				const double rb = rib(th, sg, false, e);
				const double foot = 1.0 - smoothstep(RIB_FOOT_X, RIB_FOOT_Y, e);
				const double hw = wall(e + RIB_IN * rb * smoothstep(0.0, 120.0, e) * foot, hc);
				const double ea = e + RIB_ARM * rb * smoothstep(0.0, 150.0, e) * foot;
				const double ha = hc - ea * lerpf(ARM_IN_X, ARM_IN_Y, smoothstep(0.0, 500.0, ea));
				hr = lerpf(ha, hw, 1.0 - smoothstep(30.0, 60.0, th));
			} else {
				const double rb = RIB_OUT * rib(th, sg, true, d);
				const double dr = d + rb * smoothstep(20.0, RIB_GROW, d);
				const double ws = 1.0 - smoothstep(5.0, 16.0, th);
				double hs;
				if (d < SHOULDER_X) hs = lerpf(hc, PLATEAU_Y, smoothstep(0.0, SHOULDER_X, d));
				else if (d < SHOULDER_Y) hs = PLATEAU_Y;
				else if (d < SHOULDER_Z) hs = lerpf(PLATEAU_Y, LIP_Y, smoothstep(SHOULDER_Y, SHOULDER_Z, d));
				else {
					const double db = d - SHOULDER_Z;
					hs = fall(LIP_Y, db + rb * smoothstep(20.0, RIB_GROW, db), BACK_RUN, BACK_BOW);
				}
				const double hb = lerpf(fall(hc, dr, BACK_RUN, KNIFE_BOW), hs, ws);
				hr = lerpf(fall(hc, dr, ARM_OUT_RUN, ARM_OUT_BOW), hb, 1.0 - smoothstep(35.0, 70.0, th));
				rough = lerpf(1.0, 0.15, ws * smoothstep(40.0, SHOULDER_X, d) * (1.0 - smoothstep(SHOULDER_Y + 20.0, SHOULDER_Z + 60.0, d)));
			}
			hr -= 400.0 * smoothstep(160.0, ARM_END + 8.0, th);
			h = hr + n * ROUGH * rough;
			c = (1.0 - smoothstep(RING_R, RING_R + 150.0, r)) * (1.0 - smoothstep(130.0, 160.0, th));
		}
		const V2 vl = valley(a, v, n);
		if (double(vl.x) > h) h = double(vl.x);
		c = maxf(c, double(vl.y));
		if (th < 42.0 && absf(r - RING_R) < 70.0) {
			const V2 at(a, v);
			for (size_t k = 0; k < towers.size(); ++k) {
				const double dt = double((at - towers[k]).length());
				if (dt > TOWER_R + 60.0) continue;
				const double ht = double(tower_tops[k]) - maxf(dt - TOWER_R, 0.0) * TOWER_FALL + n * ROUGH * 0.2;
				if (ht > h) h = ht;
			}
		}
		h = carve(a, v, h, n);
		const double rho2 = a * a + v * v;
		if (rho2 < CIRQUE_REACH2) {
			const V2 cq = cirq(a, v, h);
			h = double(cq.x);
			c = maxf(c, double(cq.y));
		}
		if (rho2 < CROWN_REACH * CROWN_REACH) {
			const double cr = crown_rock(a, v, n);
			if (cr > h) h = cr;
			h = roots(a, v, n, h);
		}
		return V3(h, c, meadow);
	}

	// `_cq_r`.
	double cq_r(double phi) const {
		return CIRQUE_R * (1.0 + CIRQUE_LOBE_X * SIN(2.0 * phi + double(cq_ph_x)) + CIRQUE_LOBE_Y * SIN(3.0 * phi + double(cq_ph_y)) + CIRQUE_LOBE_Z * SIN(5.0 * phi + double(cq_ph_z)));
	}

	// `_tarn_n` (`Ponds.edge_at`).
	double tarn_n(double a, double v) const {
		const double ta = a - double(tarn_c.x);
		const double tv = v - double(tarn_c.y);
		const V2 tw = facing * ta + side * tv;
		const double b = ATAN2(double(tw.y), double(tw.x));
		const float *p = pond.data();
		const double edge = double(p[2]) * (1.0 + double(p[5]) * SIN(2.0 * b + double(p[6])) + double(p[7]) * SIN(3.0 * b + double(p[8])) + double(p[9]) * SIN(5.0 * b + double(p[10])));
		return std::sqrt(ta * ta + tv * tv) / (TARN_BOWL * edge / double(p[2]));
	}

	// `_cirq`.
	V2 cirq(double a, double v, double h) const {
		const double rho = std::sqrt(a * a + v * v);
		const double phi = ATAN2(v, a);
		const double s = rho / cq_r(phi);
		const double hd = smoothstep(0.25, 0.75, a / maxf(rho, 1.0));
		const double wf = (1.0 - smoothstep(CIRQUE_OUT_X, CIRQUE_OUT_Y, s)) * (1.0 - smoothstep(CIRQUE_FRONT_X, CIRQUE_FRONT_Y, a));
		if (wf <= 0.0) return V2(h, 0.0);
		const double tn = tarn_n(a, v);
		const double sd = double(V2(a - STRIP_X, maxf(absf(v) - STRIP_Y, 0.0)).length());
		double flat = 1.0 - smoothstep(STRIP_Z, STRIP_Z + (a > STRIP_X ? STRIP_W : STRIP_W * 0.5), sd);
		flat = maxf(flat, 1.0 - smoothstep(0.0, APRON_Y, double(V2(maxf(STRIP_X - a, 0.0), maxf(absf(v) - APRON_X, 0.0)).length())));
		const double lane = 1.0 - smoothstep(STRIP_Z + 10.0, STRIP_Z + 40.0, absf(a - STRIP_X));
		const double quiet = smoothstep(QUIET_X, QUIET_Y, tn);
		const double kn = nz(noise, a * ROUGH_SCALE / KNOBS_Y + 7000.0, v * ROUGH_SCALE / KNOBS_Y);
		const double broken = smoothstep(KNOBS_Z, KNOBS_Z + 0.4, kn) * lerpf(0.45, 1.0, smoothstep(0.3, 0.9, s));
		const double swell = nz(noise, a * ROUGH_SCALE / SWELL_Y - 4000.0, v * ROUGH_SCALE / SWELL_Y);
		const double fall_ = std::sqrt(1.0 - smoothstep(SHORE_FALL_X, SHORE_FALL_Y, a)) * (1.0 - smoothstep(SHORE_ACROSS_X, SHORE_ACROSS_Y, absf(v))) * smoothstep(double(tarn_c.x) - 40.0, double(tarn_c.x) + 40.0, a);
		const double calm = (1.0 - smoothstep(SHORE_FALL_Y, STRIP_X, a)) * (1.0 - smoothstep(SHORE_ACROSS_X, SHORE_ACROSS_Y, absf(v)));
		double hp = PLATEAU_Y + (FLOOR_RISE * smoothstep(0.5, 1.0, s) + KNOBS_X * broken + SWELL_X * swell) * quiet * (1.0 - calm);
		hp -= SHORE_DROP * maxf(1.0 - smoothstep(1.0, SHORE_RUN, tn), fall_);
		const double rn = nz(noise, COS(phi) * CIRQUE_R * 0.7 + 3000.0, SIN(phi) * CIRQUE_R * 0.7) * 0.5 + 0.5;
		const double rim = lerpf(RIM_X, RIM_Y, smoothstep(0.15, 0.85, rn)) * (1.0 + 0.2 * kn);
		const double bump = maxf(1.0 - absf(s - 1.0) / RIM_Z, 0.0);
		hp += rim * bump * bump * (3.0 - 2.0 * bump) * (1.0 - hd) * (1.0 - lane);
		if (tn < 1.0) hp -= TARN_DEEP * POW(1.0 - tn * tn, 1.5);
		hp = lerpf(hp, PLATEAU_Y, flat);
		return V2(lerpf(h, hp, wf), wf);
	}

	// `_valley`.
	V2 valley(double a, double v, double n) const {
		const double vr = v - valley_mid(a);
		const double av = absf(vr);
		double fl, half, rough = 0.0;
		if (a < ICEFALL_X) {
			fl = ICEFALL_YX - (ICEFALL_X - a);
			half = FLOOR_HALF_X;
			rough = 0.6;
		} else if (a < ICEFALL_Y_) {
			const double s = (a - ICEFALL_X) / (ICEFALL_Y_ - ICEFALL_X) * ICEFALL_STEPS;
			const double k = std::floor(s);
			const double g = (k + smoothstep(0.0, ICEFALL_RISER, s - k)) / ICEFALL_STEPS;
			fl = lerpf(ICEFALL_YX, ICEFALL_YY, g);
			half = FLOOR_HALF_X;
			rough = 0.5;
		} else if (a < BOULDERS_Y_) {
			const double t = (a - BOULDERS_X) / (BOULDERS_Y_ - BOULDERS_X);
			fl = lerpf(BOULDERS_YX, BOULDERS_YY, t) + nz(noise, a * LUMP_SCALE, av * LUMP_SCALE) * LUMPS;
			half = lerpf(FLOOR_HALF_X, FLOOR_HALF_Y, smoothstep(0.0, 0.3, t));
			rough = 0.35;
		} else if (a < GLACIER_Y_) {
			const double t = (a - GLACIER_X) / (GLACIER_Y_ - GLACIER_X);
			fl = lerpf(GLACIER_YX, GLACIER_YY, POW(t, 0.9));
			half = lerpf(FLOOR_HALF_Z, FLOOR_HALF_W, t);
			fl += nz(noise, a * LUMP_SCALE, av * LUMP_SCALE) * LUMPS * (1.0 - smoothstep(0.0, 0.06, t));
			rough = 0.35 * (1.0 - smoothstep(0.0, 0.06, t));
		} else {
			fl = fall(GLACIER_YY, a - TOE_X, TOE_Y - TOE_X, 1.0);
			half = FLOOR_HALF_W;
			rough = 0.2;
		}
		const double e = av - half;
		const double q = av / half;
		const double ice = smoothstep(GLACIER_X, GLACIER_X + 200.0, a) * (1.0 - smoothstep(GLACIER_Y_ - 250.0, GLACIER_Y_, a));
		if (ice > 0.0 && e < 0.0) {
			fl += ICE_BULGE * (1.0 - q * q) * ice;
			const double ac = a - GLACIER_X + CREV_ARC * (1.0 - q * q);
			const double band = ac / CREV_BAND - std::floor(ac / CREV_BAND);
			const double on = smoothstep(0.0, 0.06, band) * (1.0 - smoothstep(CREV_SHARE - 0.06, CREV_SHARE, band));
			if (on > 0.0) {
				const double dc = absf(ac / CREV_SP - std::floor(ac / CREV_SP) - 0.5) * CREV_SP;
				fl -= CREV_DEEP * (1.0 - smoothstep(0.0, CREV_W * 0.5, dc)) * on * ice * (1.0 - smoothstep(0.7, 0.95, q));
			}
		}
		const double mor = smoothstep(BOULDERS_X + 100.0, BOULDERS_X + 400.0, a) * (1.0 - smoothstep(TOE_X, TOE_X + 300.0, a));
		double h;
		if (e <= 0.0) {
			h = fl + MOR_UP * mor * POW(maxf(1.0 - absf(e - MOR_AT) / MOR_W, 0.0), 1.6);
		} else {
			const double es = e - SIDE_GAP * mor;
			const double hm = MOR_UP * mor * POW(maxf(1.0 - absf(e - MOR_AT) / MOR_W, 0.0), 1.6);
			if (es <= SIDE_RUN) {
				h = fl + maxf(SIDE_UP * smoothstep(0.0, SIDE_RUN, es), hm);
				rough = lerpf(rough, 0.6, smoothstep(0.0, 60.0, e));
			} else {
				const double past = maxf(std::sqrt((a - O_ALONG) * (a - O_ALONG) + v * v) - RING_R, 0.0);
				h = maxf(fl + SIDE_UP - (es - SIDE_RUN) * SIDE_FALL, fl - SIDE_DIP - maxf(0.0, a - SIDE_DIP_TO) * 0.5 - past * SHELF_FALL);
				rough = 0.6;
			}
		}
		const double cut_e = e - SIDE_GAP * mor;
		const double c = (1.0 - smoothstep(SIDE_RUN, SIDE_RUN + 90.0, cut_e)) * (1.0 - smoothstep(TOE_X, TOE_X + 400.0, a));
		return V2(h + n * ROUGH * rough, c);
	}
};

} // namespace zspeak
