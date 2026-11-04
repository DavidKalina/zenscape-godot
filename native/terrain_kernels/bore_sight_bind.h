// The chase camera's sight in the tunnels and the burrower's steering, in C++:
//
// ZenScapeHallSolid: LandHalls `inside` (scripts/endless/land_halls.gd) over
// its records' BoxSolid grids (scripts/endless/box_solid.gd), published by
// record as they commit, take their near solid and go.
//
// ZenScapeBoreSight: LandTunnels `near`, `tube`, `inside`, `land_y` and
// `sight` (scripts/endless/land_tunnels.gd) over the stood sites' tables
// (tunnel_sites.gd `local`, `profile`, `roof_over`, `floor_at`, `bore_at`,
// `shaft_at`, `portal_at`, `section`, `_cover`'s cap), its stretches'
// HallSolid, and the bore's spurs and plugs (bore_spurs.gd, bore_plug.gd
// `inside`, packed by GDScript as their near lists change). The land's
// height stays GDScript (LandField `height`: the native field plus the
// tunnels', ponds' and splits' carving), asked through a Callable only
// where an answer needs it, once a point.
//
// ZenScapeBurrowerSteer: burrower.gd's trunk gather (game_land.gd
// `trees_near`, then `_ask_trunks`' filter, sort and cut) and `_move`'s
// steering round its obstacles.
//
// Each mirrors its GDScript, which stays the reference, operation for
// operation: GDScript's scalars are doubles and its vectors floats (a
// vector method or operator rounds to float, a component read widens to
// double), so the same bits come out. Main thread only.
#pragma once

#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>
#include <unordered_map>
#include <vector>
#include "FastNoiseLite.h"

using namespace godot;

namespace bore_sight {

static constexpr double NaN = std::numeric_limits<double>::quiet_NaN();

// GDScript's lerpf, clampf, maxf, minf on doubles.
static inline double lerpd(double a, double b, double w) { return a + (b - a) * w; }
static inline double clampd(double v, double lo, double hi) { return v < lo ? lo : (v > hi ? hi : v); }
static inline double maxd(double a, double b) { return a > b ? a : b; }
static inline double mind(double a, double b) { return a < b ? a : b; }

// Rect2 `has_point` (float).
struct Box {
	float x = 0, y = 0, w = 0, h = 0;
	bool has(float px, float pz) const {
		if (px < x) return false;
		if (pz < y) return false;
		if (px >= x + w) return false;
		if (pz >= y + h) return false;
		return true;
	}
};

// Vector2 / Vector3 maths as the engine does it (float).
static inline float len2(float x, float y) { return std::sqrt(x * x + y * y); }
static inline float lsq3(float x, float y, float z) {
	const float x2 = x * x;
	const float y2 = y * y;
	const float z2 = z * z;
	return x2 + y2 + z2;
}
static inline float dot3(const float *a, const float *b) { return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]; }

// box_solid.gd's grid.
struct Grid {
	double x0 = 0, z0 = 0;
	int64_t nx = 0, nz = 0;
	std::vector<int32_t> start, idx;
	std::vector<float> b;

	// BoxSolid `inside` at local `q`, boxes grown by `pad`.
	bool inside(float qx, float qy, float qz, double pad) const {
		const int64_t i = int64_t(std::floor((double(qx) - x0) / 2.0));
		const int64_t j = int64_t(std::floor((double(qz) - z0) / 2.0));
		if (i < 0 || j < 0 || i >= nx || j >= nz) return false;
		const int64_t at = j * nx + i;
		const double pp = pad * pad;
		const double x = qx, y = qy, z = qz;
		for (int32_t n = start[at]; n < start[at + 1]; ++n) {
			const int64_t k = int64_t(idx[n]) * 6;
			if (y < double(b[k + 1]) || y > double(b[k + 4])) continue;
			const double dx = maxd(0.0, maxd(double(b[k]) - x, x - double(b[k + 3])));
			const double dz = maxd(0.0, maxd(double(b[k + 2]) - z, z - double(b[k + 5])));
			if (dx * dx + dz * dz <= pp) return true;
		}
		return false;
	}

	static Grid from(const Dictionary &g) {
		Grid out;
		out.x0 = double(g.get("x0", 0.0));
		out.z0 = double(g.get("z0", 0.0));
		out.nx = int64_t(g.get("nx", 0));
		out.nz = int64_t(g.get("nz", 0));
		const PackedInt32Array s = g.get("start", PackedInt32Array());
		const PackedInt32Array ix = g.get("idx", PackedInt32Array());
		const PackedFloat32Array bb = g.get("b", PackedFloat32Array());
		out.start.assign(s.ptr(), s.ptr() + s.size());
		out.idx.assign(ix.ptr(), ix.ptr() + ix.size());
		out.b.assign(bb.ptr(), bb.ptr() + bb.size());
		// A grid that doesn't add up answers nothing rather than read past its ends.
		if (int64_t(out.start.size()) != out.nx * out.nz + 1) out.nx = out.nz = 0;
		return out;
	}
};

} // namespace bore_sight

class ZenScapeHallSolid : public RefCounted {
	GDCLASS(ZenScapeHallSolid, RefCounted)

	struct Rec {
		double sx = 0, sz = 0, sr = 0;
		Transform3D inv;
		float fy = 0;
		std::vector<bore_sight::Grid> secs;
	};
	std::unordered_map<int64_t, Rec> recs;

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("version"), &ZenScapeHallSolid::version);
		ClassDB::bind_method(D_METHOD("put", "id", "site", "inv", "floor_y", "solids"), &ZenScapeHallSolid::put);
		ClassDB::bind_method(D_METHOD("drop", "id"), &ZenScapeHallSolid::drop);
		ClassDB::bind_method(D_METHOD("clear"), &ZenScapeHallSolid::clear);
		ClassDB::bind_method(D_METHOD("count"), &ZenScapeHallSolid::count);
		ClassDB::bind_method(D_METHOD("inside", "p", "pad"), &ZenScapeHallSolid::inside);
	}

public:
	int64_t version() const { return 1; }

	// Record `id`: its site array (site[0], site[1] its middle, site[7] its
	// reach), its frame's inverse and floor (the frame's origin y), and each
	// section's solid (BoxSolid's dictionary), replacing what `id` had.
	void put(int64_t id, const PackedFloat32Array &site, const Transform3D &inv, double floor_y, const Array &solids) {
		Rec r;
		if (site.size() < 8) {
			recs.erase(id);
			return;
		}
		r.sx = double(site[0]);
		r.sz = double(site[1]);
		r.sr = double(site[7]);
		r.inv = inv;
		r.fy = float(floor_y);
		for (int64_t i = 0; i < solids.size(); ++i) r.secs.push_back(bore_sight::Grid::from(solids[i]));
		recs[id] = std::move(r);
	}
	void drop(int64_t id) { recs.erase(id); }
	void clear() { recs.clear(); }
	int64_t count() const { return int64_t(recs.size()); }

	// LandHalls `inside`.
	bool inside(const Vector3 &p, double pad) const {
		for (const auto &e : recs) {
			const Rec &r = e.second;
			if (std::fabs(double(p.x) - r.sx) > r.sr + 40.0 || std::fabs(double(p.z) - r.sz) > r.sr + 40.0) continue;
			const Vector3 local = r.inv.xform(p);
			const float ly = float(double(p.y) - double(r.fy));
			for (const bore_sight::Grid &g : r.secs)
				if (g.inside(local.x, ly, local.z, pad)) return true;
		}
		return false;
	}
};

class ZenScapeBoreSight : public RefCounted {
	GDCLASS(ZenScapeBoreSight, RefCounted)
	using FNL = fastnoiselite::FastNoiseLite;

	struct Shaft {
		float ax = 0, az = 0;
		double top = 0;
	};
	struct Site {
		bore_sight::Box box;
		float ox = 0, oz = 0, wx = 1, wz = 0, mbx = 0, mbz = 0, obx = 1, obz = 0;
		double u_end = 0, length = 0, floor_y = 0;
		bool sunk = false;
		std::vector<float> tv, tc, tsn, ts, ss, wn, wp, vt, rn, rise;
		std::vector<Shaft> shafts;
		FNL rock;
	};
	std::vector<Site> sites;

	// The constants (tunnel_sites.gd's and land_tunnels.gd's; some are
	// static vars there, so GDScript hands them over).
	double STEP = 4.0, PORTAL_OUT = 20.0, PORTAL_IN = 24.0, PORTAL_HALF = 0.0;
	double HALL_HALF = 0.0, HALL_VAULT = 18.0, HALL_ROUND = 24.0;
	double MOUTH_HALF = 17.0, MOUTH_VAULT = 23.0, MOUTH_ROUND = 2.5;
	double SHAFT_R = 7.0, PORTAL_OVER = 0.6, CAP_OVER = 16.0, CAP_FLAT = 24.0, CAP_FALL = 2.4;
	double CAP_ROUGH = 3.5, CAP_GRAIN = 4.0, WALL_NEAR = 12.0, SIGHT_STEP = 0.75, SIGHT_UP = 60.0;
	double hall_pad = 0.0;

	Ref<ZenScapeHallSolid> halls;
	Callable height_of;

	// Spurs: per spur its bound (x, y, z, r) and CHAIN spheres (x, y, z, r).
	int64_t chain = 0;
	std::vector<double> spurs;
	// Plugs: per plug mid, along, side, hole (3 each), r, half, outer
	// (AROUND), thick (RINGS*AROUND).
	int64_t around = 0, rings = 0;
	double lip = 0.0;
	std::vector<double> plugs;
	bool whole = false;

	// --- tunnel_sites.gd -----------------------------------------------------------

	// `local`: (distance along the path from mouth A, offset across it).
	Vector2 local(const Site &t, double x, double z) const {
		const double dx = x - double(t.ox);
		const double dz = z - double(t.oz);
		const double u = dx * double(t.wx) + dz * double(t.wz);
		const double v = -dx * double(t.wz) + dz * double(t.wx);
		if (u <= 0.0) return Vector2(float(u), float(v));
		if (u >= t.u_end) {
			const float qx = float(x) - t.mbx;
			const float qz = float(z) - t.mbz;
			const float along = qx * t.obx + qz * t.obz;
			return Vector2(float(t.length + double(along)), float(double(t.obx) * double(qz) - double(t.obz) * double(qx)));
		}
		const double f = u / STEP;
		const int64_t k = std::min(int64_t(f), int64_t(t.tv.size()) - 2);
		const double a = f - double(k);
		const double dv = v - bore_sight::lerpd(t.tv[k], t.tv[k + 1], a);
		return Vector2(float(bore_sight::lerpd(t.ts[k], t.ts[k + 1], a) + dv * bore_sight::lerpd(t.tsn[k], t.tsn[k + 1], a)), float(dv * bore_sight::lerpd(t.tc[k], t.tc[k + 1], a)));
	}

	// The sample index at `s` (profile, floor_at's walk).
	static int64_t seg(const Site &t, double s, double step, int64_t top) {
		int64_t i = int64_t(s / step);
		if (i < 0) i = 0;
		if (i > top) i = top;
		const int64_t n = int64_t(t.ss.size());
		while (i < n - 2 && double(t.ss[i + 1]) < s) ++i;
		while (i > 0 && double(t.ss[i]) > s) --i;
		return i;
	}

	// `profile`: (half width -d, +d, crown, roundness).
	void profile(const Site &t, double s, float out[4]) const {
		if (t.sunk && (s <= 0.0 || s >= t.length)) {
			out[0] = float(MOUTH_HALF); out[1] = float(MOUTH_HALF); out[2] = float(MOUTH_VAULT); out[3] = float(MOUTH_ROUND);
			return;
		}
		if (s <= 0.0 || s >= t.length || t.wn.empty()) {
			out[0] = float(HALL_HALF); out[1] = float(HALL_HALF); out[2] = float(HALL_VAULT); out[3] = float(HALL_ROUND);
			return;
		}
		const int64_t i = seg(t, s, STEP, int64_t(t.ss.size()) - 2);
		const double a = bore_sight::clampd((s - double(t.ss[i])) / bore_sight::maxd(double(t.ss[i + 1]) - double(t.ss[i]), 0.0001), 0.0, 1.0);
		out[0] = float(bore_sight::lerpd(t.wn[i], t.wn[i + 1], a));
		out[1] = float(bore_sight::lerpd(t.wp[i], t.wp[i + 1], a));
		out[2] = float(bore_sight::lerpd(t.vt[i], t.vt[i + 1], a));
		out[3] = float(bore_sight::lerpd(t.rn[i], t.rn[i + 1], a));
	}

	// `roof_over`: the superellipse's top at `d` across, NAN past the walls.
	static double roof_over(const float pr[4], double d) {
		const double hw = (double(pr[0]) + double(pr[1])) * 0.5;
		const double x = std::fabs((d - (double(pr[1]) - double(pr[0])) * 0.5) / hw);
		if (x >= 1.0) return bore_sight::NaN;
		return double(pr[2]) * std::pow(1.0 - std::pow(x, double(pr[3])), 1.0 / double(pr[3]));
	}

	// `floor_at`.
	double floor_at(const Site &t, double s) const {
		if (t.rise.empty() || s <= 0.0 || s >= t.length) return t.floor_y;
		const int64_t i = seg(t, s, STEP, int64_t(t.rise.size()) - 2);
		return t.floor_y + bore_sight::lerpd(t.rise[i], t.rise[i + 1], bore_sight::clampd((s - double(t.ss[i])) / bore_sight::maxd(double(t.ss[i + 1]) - double(t.ss[i]), 0.0001), 0.0, 1.0));
	}

	// `bore_at`: (floor, roof) or NAN.
	bool bore_at(const Site &t, double x, double z, double grow, float &lo, float &hi) const {
		if (!t.box.has(float(x), float(z))) return false;
		const Vector2 q = local(t, x, z);
		if (double(q.x) < -PORTAL_OUT || double(q.x) > t.length + PORTAL_OUT) return false;
		float pr[4];
		profile(t, q.x, pr);
		const double mid = (double(pr[1]) - double(pr[0])) * 0.5;
		const double h = roof_over(pr, double(q.y) + (double(q.y) >= mid ? grow : -grow));
		if (std::isnan(h)) return false;
		const double f = floor_at(t, q.x);
		lo = float(f);
		hi = float(f + h);
		return true;
	}

	// `portal_local`.
	static Vector2 portal_local(const Site &t, int m, double x, double z) {
		const float ax = m == 0 ? t.ox : t.mbx;
		const float az = m == 0 ? t.oz : t.mbz;
		const float ix = m == 0 ? t.wx : -t.obx;
		const float iz = m == 0 ? t.wz : -t.obz;
		const float qx = float(x) - ax;
		const float qz = float(z) - az;
		return Vector2(qx * ix + qz * iz, ix * qz - iz * qx);
	}

	// `portal_at`.
	int portal_at(const Site &t, double x, double z) const {
		if (t.sunk) return -1;
		for (int m = 0; m < 2; ++m) {
			const Vector2 q = portal_local(t, m, x, z);
			if (double(q.x) >= -PORTAL_OUT && double(q.x) <= PORTAL_IN && std::fabs(double(q.y)) <= PORTAL_HALF) return m;
		}
		return -1;
	}

	// `shaft_at` (grow 0).
	int shaft_at(const Site &t, double x, double z) const {
		const float px = float(x), pz = float(z);
		for (size_t i = 0; i < t.shafts.size(); ++i)
			if (double(bore_sight::len2(px - t.shafts[i].ax, pz - t.shafts[i].az)) < SHAFT_R) return int(i);
		return -1;
	}

	// `section(t, s).x`: the wider side's half width.
	double section_x(const Site &t, double s) const {
		float pr[4];
		profile(t, s, pr);
		return double(float(bore_sight::maxd(pr[0], pr[1])));
	}

	// land_tunnels.gd `_cover`.
	double cover(const Site &t, double x, double z, double h) const {
		const int m = portal_at(t, x, z);
		if (m < 0) return h;
		const Vector2 q = portal_local(t, m, x, z);
		const double a = q.x, d = q.y;
		const float nx = float(d * CAP_GRAIN) + 0.0f;
		const float ny = float(a * CAP_GRAIN + 5000.0 * double(m + 1)) + 0.0f;
		const double rough = CAP_ROUGH * (double(t.rock.GetNoise(nx, ny)) * 0.5 + 0.5);
		const double cap = t.floor_y + HALL_VAULT + CAP_OVER + rough - CAP_FALL * bore_sight::maxd(std::fabs(d) - CAP_FLAT, 0.0);
		return bore_sight::maxd(h + PORTAL_OVER, cap);
	}

	// --- the near spurs and plugs ---------------------------------------------------

	bool spurs_inside(const Vector3 &p) const {
		const size_t stride = 4 + size_t(chain) * 4;
		for (size_t o = 0; o + stride <= spurs.size(); o += stride) {
			const double *s = spurs.data() + o;
			const float b = bore_sight::lsq3(p.x - float(s[0]), p.y - float(s[1]), p.z - float(s[2]));
			if (double(b) > s[3] * s[3]) continue;
			for (int64_t i = 0; i < chain; ++i) {
				const double *c = s + 4 + i * 4;
				if (double(bore_sight::lsq3(p.x - float(c[0]), p.y - float(c[1]), p.z - float(c[2]))) < c[3] * c[3]) return true;
			}
		}
		return false;
	}

	bool plugs_inside(const Vector3 &p) const {
		const size_t stride = 14 + size_t(around) + size_t(rings * around);
		const float pv[3] = { p.x, p.y, p.z };
		for (size_t o = 0; o + stride <= plugs.size(); o += stride) {
			const double *q = plugs.data() + o;
			const float mid[3] = { float(q[0]), float(q[1]), float(q[2]) };
			const float along[3] = { float(q[3]), float(q[4]), float(q[5]) };
			const float side[3] = { float(q[6]), float(q[7]), float(q[8]) };
			const float hole[3] = { float(q[9]), float(q[10]), float(q[11]) };
			const double r = q[12], half = q[13];
			const double *outer = q + 14;
			const double *thick = q + 14 + around;
			// _local
			const float d[3] = { pv[0] - mid[0], pv[1] - mid[1], pv[2] - mid[2] };
			const float a = bore_sight::dot3(d, along);
			const float hm[3] = { hole[0] - mid[0], hole[1] - mid[1], hole[2] - mid[2] };
			const double lx = double(bore_sight::dot3(d, side)) - double(bore_sight::dot3(hm, side));
			const double ly = double(d[1]) - double(hm[1]);
			const float rho = bore_sight::len2(float(lx), float(ly));
			if (double(rho) <= r || std::fabs(double(a)) > half) continue;
			// _thick_at: _k_of, then _half_at.
			const float dh[3] = { pv[0] - hole[0], pv[1] - hole[1], pv[2] - hole[2] };
			const double ang = std::atan2(double(dh[1]), double(bore_sight::dot3(dh, side)));
			int64_t k = int64_t(std::round(ang / 6.283185307179586 * double(around))) % around;
			if (k < 0) k += around;
			double th;
			if (double(rho) > outer[k]) th = -1.0;
			else {
				double hf = 0.0;
				if (double(rho) > r) {
					const double f = bore_sight::clampd((double(rho) - r) / bore_sight::maxd(outer[k] - r, 0.01), 0.0, 1.0);
					const int64_t j = std::min(int64_t(f * double(rings - 1)), rings - 2);
					hf = bore_sight::mind(thick[j * around + k], thick[(j + 1) * around + k]);
				}
				th = bore_sight::maxd(hf, lip * 0.5);
			}
			if (std::fabs(double(a)) < th) return true;
		}
		return false;
	}

	bool halls_inside(const Vector3 &p) const {
		return halls.is_valid() && halls->inside(p, hall_pad);
	}

	// The land's height at (x, z), asked of GDScript once a point.
	struct Height {
		const Callable *of;
		double x, z;
		bool have = false;
		double h = 0.0;
		double get() {
			if (!have) {
				h = of->is_valid() ? double(of->call(x, z)) : 0.0;
				have = true;
			}
			return h;
		}
	};

	bool inside_at(const Vector3 &p, Height &hq) const {
		if (halls_inside(p)) return true;
		if (spurs_inside(p)) return true;
		if (plugs_inside(p)) return true;
		const double px = p.x, py = p.y, pz = p.z;
		for (const Site &t : sites) {
			if (!t.box.has(p.x, p.z)) continue;
			const int sh = shaft_at(t, px, pz);
			if (sh >= 0 && py < t.shafts[sh].top) return py < t.floor_y;
			const double h = hq.get();
			const double cv = cover(t, px, pz, h);
			float lo, hi;
			if (bore_at(t, px, pz, 0.0, lo, hi) && cv > double(hi)) return py < double(lo) || (py > double(hi) && py < cv);
			if (py >= cv) continue;
			if (cv != h) return true;
			const Vector2 q = local(t, px, pz);
			if (double(q.x) >= -PORTAL_OUT && double(q.x) <= t.length + PORTAL_OUT && std::fabs(double(q.y)) < section_x(t, q.x) + WALL_NEAR) return true;
		}
		return false;
	}

	double land_y_at(const Vector3 &p, double h) const {
		const double px = p.x, py = p.y, pz = p.z;
		for (const Site &t : sites) {
			if (!t.box.has(p.x, p.z)) continue;
			const int sh = shaft_at(t, px, pz);
			if (sh >= 0 && py < t.shafts[sh].top) return t.floor_y;
			const double cv = cover(t, px, pz, h);
			float lo, hi;
			if (bore_at(t, px, pz, 0.0, lo, hi) && cv > double(hi) && py < double(hi)) return double(lo);
			if (cv != h) return cv;
		}
		return h;
	}

	int tube_at(const Vector3 &p) const {
		const double px = p.x, py = p.y, pz = p.z;
		for (const Site &t : sites) {
			if (!t.box.has(p.x, p.z) || py > t.floor_y + SIGHT_UP) continue;
			const int sh = shaft_at(t, px, pz);
			if (sh >= 0 && py < t.shafts[sh].top) return py < t.floor_y ? 1 : 0;
			float lo, hi;
			if (!bore_at(t, px, pz, 0.0, lo, hi) || portal_at(t, px, pz) >= 0) return -1;
			return (py < double(lo) || py > double(hi) || halls_inside(p)) ? 1 : 0;
		}
		return -1;
	}

	bool near_at(const Vector3 &p) const {
		for (const Site &t : sites)
			if (t.box.has(p.x, p.z) && double(p.y) < t.floor_y + SIGHT_UP) return true;
		return false;
	}

	static std::vector<float> floats(const Dictionary &d, const char *k) {
		const PackedFloat32Array a = d.get(k, PackedFloat32Array());
		return std::vector<float>(a.ptr(), a.ptr() + a.size());
	}

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("version"), &ZenScapeBoreSight::version);
		ClassDB::bind_method(D_METHOD("configure", "consts", "height", "halls"), &ZenScapeBoreSight::configure);
		ClassDB::bind_method(D_METHOD("set_sites", "sites"), &ZenScapeBoreSight::set_sites);
		ClassDB::bind_method(D_METHOD("set_spurs", "chain", "pack"), &ZenScapeBoreSight::set_spurs);
		ClassDB::bind_method(D_METHOD("set_plugs", "around", "rings", "lip", "pack"), &ZenScapeBoreSight::set_plugs);
		ClassDB::bind_method(D_METHOD("near", "p"), &ZenScapeBoreSight::near);
		ClassDB::bind_method(D_METHOD("tube", "p"), &ZenScapeBoreSight::tube);
		ClassDB::bind_method(D_METHOD("inside", "p", "h"), &ZenScapeBoreSight::inside);
		ClassDB::bind_method(D_METHOD("land_y", "p", "h"), &ZenScapeBoreSight::land_y);
		ClassDB::bind_method(D_METHOD("sight", "from", "to"), &ZenScapeBoreSight::sight);
		ClassDB::bind_method(D_METHOD("sight_whole"), &ZenScapeBoreSight::sight_whole);
	}

public:
	int64_t version() const { return 1; }

	// The constants by their GDScript names, the land's height (a Callable
	// of x, z) and the stretches' HallSolid.
	void configure(const Dictionary &c, const Callable &height, const Ref<ZenScapeHallSolid> &p_halls) {
#define BS_K(name) name = double(c.get(#name, name))
		BS_K(STEP); BS_K(PORTAL_OUT); BS_K(PORTAL_IN); BS_K(PORTAL_HALF);
		BS_K(HALL_HALF); BS_K(HALL_VAULT); BS_K(HALL_ROUND);
		BS_K(MOUTH_HALF); BS_K(MOUTH_VAULT); BS_K(MOUTH_ROUND);
		BS_K(SHAFT_R); BS_K(PORTAL_OVER); BS_K(CAP_OVER); BS_K(CAP_FLAT); BS_K(CAP_FALL);
		BS_K(CAP_ROUGH); BS_K(CAP_GRAIN); BS_K(WALL_NEAR); BS_K(SIGHT_STEP); BS_K(SIGHT_UP);
#undef BS_K
		hall_pad = double(c.get("hall_pad", 0.0));
		height_of = height;
		halls = p_halls;
	}

	// The stood sites, in LandTunnels `_sites`' order: each a dictionary of
	// its box, path frame, tables, shafts ([x, z, top, ...]) and its rock
	// noise's seed, frequency and octaves.
	void set_sites(const Array &list) {
		sites.clear();
		sites.resize(size_t(list.size()));
		for (int64_t i = 0; i < list.size(); ++i) {
			const Dictionary d = list[i];
			Site &t = sites[size_t(i)];
			const Rect2 b = d.get("box", Rect2());
			t.box = { b.position.x, b.position.y, b.size.x, b.size.y };
			const Vector2 o = d.get("origin", Vector2()), w = d.get("way", Vector2(1, 0));
			const Vector2 mb = d.get("mouth_b", Vector2()), ob = d.get("out_b", Vector2(1, 0));
			t.ox = o.x; t.oz = o.y; t.wx = w.x; t.wz = w.y;
			t.mbx = mb.x; t.mbz = mb.y; t.obx = ob.x; t.obz = ob.y;
			t.u_end = double(d.get("u_end", 0.0));
			t.length = double(d.get("length", 0.0));
			t.floor_y = double(d.get("floor_y", 0.0));
			t.sunk = bool(d.get("sunk", false));
			t.tv = floats(d, "tv"); t.tc = floats(d, "tc"); t.tsn = floats(d, "tsn"); t.ts = floats(d, "ts");
			t.ss = floats(d, "ss"); t.wn = floats(d, "wn"); t.wp = floats(d, "wp"); t.vt = floats(d, "vt");
			t.rn = floats(d, "rn"); t.rise = floats(d, "rise");
			const PackedFloat64Array sh = d.get("shafts", PackedFloat64Array());
			for (int64_t k = 0; k + 2 < sh.size(); k += 3) t.shafts.push_back({ float(sh[k]), float(sh[k + 1]), sh[k + 2] });
			// The engine's FastNoiseLite as the resource sets it up (FBM, its defaults).
			t.rock.SetSeed(int(int64_t(d.get("rock_seed", 0))));
			t.rock.SetNoiseType(FNL::NoiseType_OpenSimplex2S);
			t.rock.SetFrequency(float(double(d.get("rock_frequency", 0.01))));
			t.rock.SetFractalType(FNL::FractalType_FBm);
			t.rock.SetFractalOctaves(int(int64_t(d.get("rock_octaves", 5))));
			t.rock.SetFractalLacunarity(2.0f);
			t.rock.SetFractalGain(0.5f);
			t.rock.SetFractalWeightedStrength(0.0f);
			t.rock.SetFractalPingPongStrength(2.0f);
			// The path tables must hold a step past each end (local, profile).
			if (t.tv.size() < 2 || t.ts.size() < t.tv.size() || t.tsn.size() < t.tv.size() || t.tc.size() < t.tv.size() || t.ss.size() < 2) t.box = { 0, 0, 0, 0 };
			if (!t.wn.empty() && (t.wp.size() < t.ss.size() || t.wn.size() < t.ss.size() || t.vt.size() < t.ss.size() || t.rn.size() < t.ss.size())) t.wn.clear();
			if (!t.rise.empty() && t.rise.size() < t.ss.size()) t.rise.clear();
		}
	}

	void set_spurs(int64_t p_chain, const PackedFloat64Array &pack) {
		chain = p_chain;
		spurs.assign(pack.ptr(), pack.ptr() + pack.size());
	}

	void set_plugs(int64_t p_around, int64_t p_rings, double p_lip, const PackedFloat64Array &pack) {
		around = p_around;
		rings = p_rings;
		lip = p_lip;
		plugs.assign(pack.ptr(), pack.ptr() + pack.size());
		if (around <= 0 || rings < 2) plugs.clear();
	}

	bool near(const Vector3 &p) const { return near_at(p); }
	int64_t tube(const Vector3 &p) const { return tube_at(p); }

	// `inside`; `h` the land's height at p's x, z if known (NAN: asked).
	bool inside(const Vector3 &p, double h) const {
		Height hq{ &height_of, double(p.x), double(p.z) };
		if (!std::isnan(h)) {
			hq.have = true;
			hq.h = h;
		}
		return inside_at(p, hq);
	}

	double land_y(const Vector3 &p, double h) const { return land_y_at(p, h); }

	// `sight`: the clear share of the way; `sight_whole` after.
	double sight(const Vector3 &from, const Vector3 &to) {
		whole = false;
		if (!near_at(from) && !near_at(to)) return 1.0;
		const float dl = std::sqrt(bore_sight::lsq3(to.x - from.x, to.y - from.y, to.z - from.z));
		const int64_t n = std::max<int64_t>(1, int64_t(std::ceil(double(dl) / SIGHT_STEP)));
		bool all = true;
		for (int64_t i = 1; i <= n; ++i) {
			const float w = float(double(i) / double(n));
			const Vector3 p(from.x + (to.x - from.x) * w, from.y + (to.y - from.y) * w, from.z + (to.z - from.z) * w);
			int got = tube_at(p);
			if (got == 0 && spurs_inside(p)) got = 1;
			if (got == 0 && plugs_inside(p)) got = 1;
			if (got < 0) {
				all = false;
				Height hq{ &height_of, double(p.x), double(p.z) };
				if (inside_at(p, hq) || double(p.y) < land_y_at(p, hq.get())) got = 1;
			}
			if (got == 1) {
				whole = all;
				return double(i - 1) / double(n);
			}
		}
		whole = all;
		return 1.0;
	}

	bool sight_whole() const { return whole; }
};

class ZenScapeBurrowerSteer : public RefCounted {
	GDCLASS(ZenScapeBurrowerSteer, RefCounted)

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("version"), &ZenScapeBurrowerSteer::version);
		ClassDB::bind_method(D_METHOD("trunks", "cells", "at", "r", "pos", "fw", "side", "most"), &ZenScapeBurrowerSteer::trunks);
		ClassDB::bind_method(D_METHOD("steer", "obstacles", "pos", "fw", "look", "lean", "dir", "nearest"), &ZenScapeBurrowerSteer::steer);
	}

public:
	int64_t version() const { return 1; }

	// game_land.gd `trees_near(at, r)` over the stood cells' arrays `cells`
	// (8 floats a tree), then burrower.gd `_ask_trunks`' filter (from `pos`
	// along `fw`, within `side` across, not 2 m behind), sorted by how far
	// along and cut to `most`: the trunks' (x, z), nearest first.
	PackedVector2Array trunks(const Array &cells, const Vector2 &at, double r, const Vector2 &pos, const Vector2 &fw, double side, int64_t most) const {
		struct Hit {
			double along;
			float x, z;
		};
		std::vector<Hit> found;
		const double r2 = r * r;
		const float ox = fw.y, oz = -fw.x; // fw.orthogonal()
		for (int64_t c = 0; c < cells.size(); ++c) {
			const PackedFloat32Array t = cells[c];
			const float *v = t.ptr();
			const int64_t n = t.size();
			for (int64_t q = 0; q + 7 < n; q += 8) {
				if (double(v[q + 3]) <= 0.0) continue;
				const double dx = double(v[q]) - double(at.x);
				const double dz = double(v[q + 1]) - double(at.y);
				if (dx * dx + dz * dz > r2) continue;
				const float rx = v[q] - pos.x, rz = v[q + 1] - pos.y;
				const double along = double(rx * fw.x + rz * fw.y);
				if (along < -2.0 || std::fabs(double(rx * ox + rz * oz)) > side) continue;
				found.push_back({ along, v[q], v[q + 1] });
			}
		}
		std::stable_sort(found.begin(), found.end(), [](const Hit &a, const Hit &b) { return a.along < b.along; });
		PackedVector2Array out;
		const int64_t keep = std::min<int64_t>(int64_t(found.size()), std::max<int64_t>(most, 0));
		out.resize(keep);
		for (int64_t i = 0; i < keep; ++i) out.set(i, Vector2(found[i].x, found[i].z));
		return out;
	}

	// burrower.gd `_move`'s pass round its obstacles: `obstacles` 5 doubles
	// each (x, z, reach, margin, ramp), the head at `pos` facing `fw`
	// looking `look` m on, rounding the side of `lean`, onto `dir`:
	// [dir.x, dir.y, nearest].
	PackedFloat64Array steer(const PackedFloat64Array &obstacles, const Vector2 &pos, const Vector2 &fw, double look, const Vector2 &lean, const Vector2 &p_dir, double nearest) const {
		const float lk = float(look);
		const Vector2 ahead(pos.x + fw.x * lk, pos.y + fw.y * lk);
		const Vector2 fl(fw.x * lk, fw.y * lk);
		const Vector2 mid(pos.x + fl.x * 0.5f, pos.y + fl.y * 0.5f);
		const Vector2 probes[3] = { pos, mid, ahead };
		float dx = p_dir.x, dy = p_dir.y;
		const double *o = obstacles.ptr();
		for (int64_t k = 0; k + 4 < obstacles.size(); k += 5) {
			const float ax = float(o[k]), az = float(o[k + 1]);
			const double reach = o[k + 2];
			const double r = reach + o[k + 3];
			const double ramp = o[k + 4];
			for (const Vector2 &pr : probes) {
				const double d = bore_sight::len2(pr.x - ax, pr.y - az);
				nearest = bore_sight::mind(nearest, double(bore_sight::len2(pos.x - ax, pos.y - az)) - reach);
				if (d < r + ramp) {
					float awx = pr.x - ax, awz = pr.y - az;
					float l = awx * awx + awz * awz;
					if (l != 0) {
						l = std::sqrt(l);
						awx /= l;
						awz /= l;
					}
					float tx = -awz, tz = awx;
					if (double(tx * lean.x + tz * lean.y) < 0.0) {
						tx = -tx;
						tz = -tz;
					}
					const double w = bore_sight::clampd(1.0 - (d - r) / ramp, 0.0, 1.6);
					const float fw_ = float(w);
					float sx = awx * 0.9f + tx * 0.6f;
					float sz = awz * 0.9f + tz * 0.6f;
					sx = sx * fw_;
					sz = sz * fw_;
					sx = sx * 1.8f;
					sz = sz * 1.8f;
					dx = dx + sx;
					dy = dy + sz;
				}
			}
		}
		PackedFloat64Array out;
		out.resize(3);
		out.set(0, dx);
		out.set(1, dy);
		out.set(2, nearest);
		return out;
	}
};
