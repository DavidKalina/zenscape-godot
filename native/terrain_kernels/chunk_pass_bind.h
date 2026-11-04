// A land chunk's build past the field, in C++ (land_stream.gd `_build`,
// land_field.gd `build_chunk`), so a chunk build stays off GDScript:
//
// ZenScapeTunnelCarve: one mountain tunnel's carve (tunnel_sites.gd
// `carve_m`, `sunk_cut`, `trench_under` and what they read: `local`, `top`,
// `_massif_q`, `_shelve`, `_smax`, `_trench`, `_pit`, `_bowl_cut`, `_bowl_e`),
// packed once from its Site when the site is made (read only after, so any
// worker may ask it).
//
// ZenScapeChunkPass: the passes over a chunk's arrays: Tunnels.apply_chunk,
// land_stream `_river_frame` (and its ring of samples where only the native
// field and the tunnels shape the land there), RockShape.grid's layers, and
// `_portal_holes`' triangles.
//
// Each mirrors its GDScript, which stays the reference, operation for
// operation: GDScript's scalars are doubles and its vectors floats (a
// vector method or operator rounds to float, a component read widens to
// double). pow and atan2 are land_math.h's (fdlibm's), as the land field's.
#pragma once

#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <cmath>
#include <cstdint>
#include <limits>
#include <vector>
#include "FastNoiseLite.h"
#include "land_math.h"
#include "land_field_bind.h"

using namespace godot;

namespace chunk_pass {

static constexpr double INF_D = std::numeric_limits<double>::infinity();

inline double minf(double a, double b) { return a < b ? a : b; }
inline double maxf(double a, double b) { return a > b ? a : b; }
inline double clampf(double v, double lo, double hi) { return v < lo ? lo : (v > hi ? hi : v); }
inline double lerpf(double a, double b, double t) { return a + (b - a) * t; }
inline int64_t clampi(int64_t v, int64_t lo, int64_t hi) { return v < lo ? lo : (v > hi ? hi : v); }
// GDScript's floori / ceili of a double.
inline int64_t floori(double v) { return int64_t(std::floor(v)); }
inline int64_t ceili(double v) { return int64_t(std::ceil(v)); }
inline double smoothstep(double a, double b, double s) { return zsland::smoothstep(a, b, s); }

// A FastNoiseLite resource as the engine sets it up, asked as get_noise_2d.
struct Noise {
	fastnoiselite::FastNoiseLite n;
	bool on = false;
	void from(const Dictionary &d) {
		using FNL = fastnoiselite::FastNoiseLite;
		on = !d.is_empty();
		if (!on) return;
		n.SetSeed(int(int64_t(d.get("seed", 0))));
		static const FNL::NoiseType types[] = { FNL::NoiseType_OpenSimplex2, FNL::NoiseType_OpenSimplex2S, FNL::NoiseType_Cellular, FNL::NoiseType_Perlin, FNL::NoiseType_ValueCubic, FNL::NoiseType_Value };
		n.SetNoiseType(types[clampi(int64_t(d.get("noise_type", 1)), 0, 5)]);
		n.SetFrequency(float(double(d.get("frequency", 0.01))));
		static const FNL::FractalType fr[] = { FNL::FractalType_None, FNL::FractalType_FBm, FNL::FractalType_Ridged, FNL::FractalType_PingPong };
		n.SetFractalType(fr[clampi(int64_t(d.get("fractal_type", 1)), 0, 3)]);
		n.SetFractalOctaves(int(int64_t(d.get("fractal_octaves", 5))));
		n.SetFractalLacunarity(float(double(d.get("fractal_lacunarity", 2.0))));
		n.SetFractalGain(float(double(d.get("fractal_gain", 0.5))));
		n.SetFractalWeightedStrength(float(double(d.get("fractal_weighted_strength", 0.0))));
		n.SetFractalPingPongStrength(float(double(d.get("fractal_ping_pong_strength", 2.0))));
	}
	double at(double x, double z) const {
		const float fx = float(x) + 0.0f;
		const float fz = float(z) + 0.0f;
		return double(n.GetNoise(fx, fz));
	}
};

// Vector2 maths in floats.
inline float dist2(float ax, float az, float bx, float bz) {
	const float dx = ax - bx;
	const float dz = az - bz;
	return std::sqrt(dx * dx + dz * dz);
}

} // namespace chunk_pass

class ZenScapeTunnelCarve : public RefCounted {
	GDCLASS(ZenScapeTunnelCarve, RefCounted)

	struct Shaft {
		float ax = 0, az = 0;
		double top = 0;
	};
	struct Shelf {
		double a = 0, b = 0, y = 0;
	};

	// Rect2 (float): position and size; has_point as the engine.
	float bx = 0, bz = 0, bw = 0, bh = 0;
	float ox = 0, oz = 0, wx = 1, wz = 0, mbx = 0, mbz = 0, obx = 1, obz = 0;
	float ramp_x = 0, ramp_y = 0;
	double u_end = 0, length = 0, floor_y = 0, crest = 0, grade = 0;
	bool sunk = false;
	std::vector<float> tv, tc, tsn, ts;
	std::vector<Shaft> shafts;
	std::vector<Shelf> shelves;
	chunk_pass::Noise crest_noise, gully, rock;

	// tunnel_sites.gd's constants (and static vars), handed over by GDScript.
	double STEP = 4, COVER_MOUTH = 0, RISE = 1, CREST_VARY = 0, FLANK = 0, FLANK_VARY = 0, CREST_R = 1, END = 0;
	double BLEND = 1, GULLY = 0, SHELF_FADE = 1, SHELF_SPAN = 0, SHELF_WALL = 0, SHELF_BLEND = 1, SHELF_RAGGED = 0;
	double EDGE_FADE = 1, APRON = 0, TRENCH_WIDE = 0, SINK = 0, HALL_HALF = 0, EDGE = 1, SHEER = 0, LEAN = 1;
	double PIT_FLOOR = 0, PIT_WALL = 0, PIT_BLEND = 1, PIT_RAGGED = 0, FACE_REACH = 0;
	double BOWL_RISE = 0, WALL_RIM = 0, GULLY_BACK = 0, BOWL_FALL = 1, BOWL_ROUGH = 0, WALL_BENCH = 1, BENCH_WANDER = 0;
	double BOWL_MOUTH = 0, BOWL_WIDE = 1;
	// Vector constants' float components, widened.
	double GULLY_FROM_X = 0, GULLY_FROM_Y = 0, WALL_E_X = 0, WALL_E_Y = 0, GULLY_SCALE_X = 0, GULLY_SCALE_Y = 0;
	double GULLY_FADE_X = 0, GULLY_FADE_Y = 0, WALL_FADE_X = 0, WALL_FADE_Y = 0, BENCH_RISER_X = 0, BENCH_RISER_Y = 0;
	double BENCH_PATCH_X = 0, BENCH_PATCH_Y = 0, BENCH_PATCH_Z = 0;

	bool has_point(float px, float pz) const {
		if (px < bx) return false;
		if (pz < bz) return false;
		if (px >= bx + bw) return false;
		if (pz >= bz + bh) return false;
		return true;
	}

	static std::vector<float> floats(const Dictionary &d, const char *k) {
		const PackedFloat32Array a = d.get(k, PackedFloat32Array());
		return std::vector<float>(a.ptr(), a.ptr() + a.size());
	}

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("version"), &ZenScapeTunnelCarve::version);
		ClassDB::bind_method(D_METHOD("setup", "site", "consts"), &ZenScapeTunnelCarve::setup);
		ClassDB::bind_method(D_METHOD("carve_m", "base", "x", "z"), &ZenScapeTunnelCarve::carve_m);
		ClassDB::bind_method(D_METHOD("sunk_cut", "base", "x", "z", "step"), &ZenScapeTunnelCarve::sunk_cut);
		ClassDB::bind_method(D_METHOD("trench_under", "x", "z", "step"), &ZenScapeTunnelCarve::trench_under);
	}

public:
	int64_t version() const { return 1; }

	bool is_sunk() const { return sunk; }

	// The Site's tables (tunnel_sites.gd `native_pack`) and the constants.
	void setup(const Dictionary &d, const Dictionary &c) {
#define TC_K(name) name = double(c.get(#name, name))
		TC_K(STEP); TC_K(COVER_MOUTH); TC_K(RISE); TC_K(CREST_VARY); TC_K(FLANK); TC_K(FLANK_VARY); TC_K(CREST_R); TC_K(END);
		TC_K(BLEND); TC_K(GULLY); TC_K(SHELF_FADE); TC_K(SHELF_SPAN); TC_K(SHELF_WALL); TC_K(SHELF_BLEND); TC_K(SHELF_RAGGED);
		TC_K(EDGE_FADE); TC_K(APRON); TC_K(TRENCH_WIDE); TC_K(SINK); TC_K(HALL_HALF); TC_K(EDGE); TC_K(SHEER); TC_K(LEAN);
		TC_K(PIT_FLOOR); TC_K(PIT_WALL); TC_K(PIT_BLEND); TC_K(PIT_RAGGED); TC_K(FACE_REACH);
		TC_K(BOWL_RISE); TC_K(WALL_RIM); TC_K(GULLY_BACK); TC_K(BOWL_FALL); TC_K(BOWL_ROUGH); TC_K(WALL_BENCH); TC_K(BENCH_WANDER);
		TC_K(BOWL_MOUTH); TC_K(BOWL_WIDE);
#undef TC_K
#define TC_V2(name) { const Vector2 v = c.get(#name, Vector2()); name##_X = double(v.x); name##_Y = double(v.y); }
		TC_V2(GULLY_FROM); TC_V2(WALL_E); TC_V2(GULLY_SCALE); TC_V2(GULLY_FADE); TC_V2(WALL_FADE); TC_V2(BENCH_RISER);
#undef TC_V2
		{
			const Vector3 v = c.get("BENCH_PATCH", Vector3());
			BENCH_PATCH_X = double(v.x); BENCH_PATCH_Y = double(v.y); BENCH_PATCH_Z = double(v.z);
		}
		const Rect2 b = d.get("box", Rect2());
		bx = b.position.x; bz = b.position.y; bw = b.size.x; bh = b.size.y;
		const Vector2 o = d.get("origin", Vector2()), w = d.get("way", Vector2(1, 0));
		const Vector2 mb = d.get("mouth_b", Vector2()), ob = d.get("out_b", Vector2(1, 0));
		const Vector2 rp = d.get("ramp", Vector2());
		ox = o.x; oz = o.y; wx = w.x; wz = w.y; mbx = mb.x; mbz = mb.y; obx = ob.x; obz = ob.y;
		ramp_x = rp.x; ramp_y = rp.y;
		u_end = double(d.get("u_end", 0.0));
		length = double(d.get("length", 0.0));
		floor_y = double(d.get("floor_y", 0.0));
		crest = double(d.get("crest", 0.0));
		grade = double(d.get("grade", 0.0));
		sunk = bool(d.get("sunk", false));
		tv = floats(d, "tv"); tc = floats(d, "tc"); tsn = floats(d, "tsn"); ts = floats(d, "ts");
		const PackedFloat64Array sh = d.get("shafts", PackedFloat64Array());
		shafts.clear();
		for (int64_t k = 0; k + 2 < sh.size(); k += 3) shafts.push_back({ float(sh[k]), float(sh[k + 1]), sh[k + 2] });
		const PackedFloat64Array sv = d.get("shelves", PackedFloat64Array());
		shelves.clear();
		for (int64_t k = 0; k + 2 < sv.size(); k += 3) shelves.push_back({ sv[k], sv[k + 1], sv[k + 2] });
		crest_noise.from(d.get("crest_noise", Dictionary()));
		gully.from(d.get("gully", Dictionary()));
		rock.from(d.get("rock", Dictionary()));
		// The path table must hold a step past each end.
		if (!sunk && (tv.size() < 2 || ts.size() < tv.size() || tsn.size() < tv.size() || tc.size() < tv.size())) { bw = 0; bh = 0; }
	}

	// --- tunnel_sites.gd ---------------------------------------------------------

	void local(double x, double z, float &qx, float &qy) const {
		const double dx = x - double(ox);
		const double dz = z - double(oz);
		const double u = dx * double(wx) + dz * double(wz);
		const double v = -dx * double(wz) + dz * double(wx);
		if (u <= 0.0) { qx = float(u); qy = float(v); return; }
		if (u >= u_end) {
			const float px = float(x) - mbx;
			const float pz = float(z) - mbz;
			const float along = px * obx + pz * obz;
			qx = float(length + double(along));
			qy = float(double(obx) * double(pz) - double(obz) * double(px));
			return;
		}
		const double f = u / STEP;
		const int64_t k = std::min(int64_t(f), int64_t(tv.size()) - 2);
		const double a = f - double(k);
		const double dv = v - chunk_pass::lerpf(tv[k], tv[k + 1], a);
		qx = float(chunk_pass::lerpf(ts[k], ts[k + 1], a) + dv * chunk_pass::lerpf(tsn[k], tsn[k + 1], a));
		qy = float(dv * chunk_pass::lerpf(tc[k], tc[k + 1], a));
	}

	double top(double s) const {
		const double c = floor_y + COVER_MOUTH;
		if (s <= 0.0) return c + s * END;
		if (s >= length) return c - (s - length) * END;
		const double q = chunk_pass::clampf(chunk_pass::minf(s, length - s) / RISE, 0.0, 1.0);
		const double r = 1.0 - (1.0 - q) * (1.0 - q);
		const double vary = 1.0 - CREST_VARY * (0.5 + 0.5 * crest_noise.at(s, 0.0));
		return c + (crest - COVER_MOUTH) * r * vary;
	}

	double massif_q(float qx, float qy, double x, double z) const {
		const double a = std::fabs(double(qy));
		const double fall = FLANK * (1.0 + FLANK_VARY * crest_noise.at(double(qx) * 0.7, qy > 0.0f ? 7000.0 : -7000.0));
		double y = top(double(qx)) - fall * (a < CREST_R ? a * a / (2.0 * CREST_R) : a - CREST_R * 0.5);
		double w = chunk_pass::smoothstep(GULLY_FROM_X, GULLY_FROM_Y, a);
		if (w > 0.0 && !shelves.empty()) {
			for (const Shelf &sv : shelves) {
				const double along = chunk_pass::maxf(chunk_pass::maxf(sv.a - double(qx), double(qx) - sv.b), 0.0);
				w *= chunk_pass::smoothstep(0.0, SHELF_FADE, chunk_pass::maxf(along, a - SHELF_SPAN));
			}
		}
		if (w > 0.0) y += GULLY * w * gully.at(x, z);
		return y;
	}

	static double smax(double a, double b, double k) {
		const double h = chunk_pass::clampf(0.5 + 0.5 * (a - b) / k, 0.0, 1.0);
		return chunk_pass::lerpf(b, a, h) + k * h * (1.0 - h);
	}

	// `_shelve`: (the surface, the shelf's meadow), as floats.
	void shelve(double y, float qx, double x, double z, float &oy, float &om) const {
		double m = 0.0;
		for (const Shelf &sv : shelves) {
			const double along = chunk_pass::maxf(chunk_pass::maxf(sv.a - double(qx), double(qx) - sv.b), 0.0);
			const double fy = sv.y;
			double wall = fy + along * SHELF_WALL;
			if (wall - SHELF_BLEND >= y) continue;
			if (along > 0.0) wall += SHELF_RAGGED * (rock.at(x * 1.5, z * 1.5) * 0.5 + 0.5) * chunk_pass::smoothstep(0.0, 20.0, along);
			y = -smax(-y, -wall, SHELF_BLEND);
			m = chunk_pass::maxf(m, (1.0 - chunk_pass::smoothstep(1.0, 6.0, std::fabs(y - fy))) * (1.0 - chunk_pass::smoothstep(0.0, 30.0, along)));
		}
		oy = float(y);
		om = float(m);
	}

	double trench(double y, float mx, float mz, float o_x, float o_z, double x, double z, double ramp) const {
		const double qx = x - double(mx);
		const double qz = z - double(mz);
		const double a = qx * double(o_x) + qz * double(o_z);
		if (a < 0.0 || a > APRON + ramp) return y;
		const double b = std::fabs(double(o_x) * qz - double(o_z) * qx);
		if (b > TRENCH_WIDE) return y;
		double lid = floor_y - SINK;
		if (a > APRON) lid += (a - APRON) * grade;
		if (y <= lid) return y;
		if (b <= HALL_HALF) return lid;
		if (b <= HALL_HALF + EDGE) return chunk_pass::minf(y, lid + SHEER * (b - HALL_HALF) / EDGE);
		return chunk_pass::minf(y, lid + SHEER + (b - HALL_HALF - EDGE) / LEAN);
	}

	double pit(double y, double x, double z) const {
		const float px = float(x), pz = float(z);
		for (const Shaft &sh : shafts) {
			const double d = double(chunk_pass::dist2(px, pz, sh.ax, sh.az));
			double wall = sh.top + chunk_pass::maxf(d - PIT_FLOOR, 0.0) * PIT_WALL;
			if (wall - PIT_BLEND >= y) continue;
			if (d > PIT_FLOOR) wall += PIT_RAGGED * (rock.at(x * 2.0, z * 2.0) * 0.5 + 0.5) * chunk_pass::smoothstep(PIT_FLOOR, PIT_FLOOR + 12.0, d);
			y = -smax(-y, -wall, PIT_BLEND);
		}
		return y;
	}

	// `carve_m`: (height, shelf meadow) as floats.
	void carve_at(double base, double x, double z, float &oy, float &om) const {
		if (!has_point(float(x), float(z))) { oy = float(base); om = 0.0f; return; }
		if (sunk) {
			float c[3];
			sunk_at(base, x, z, 0.0, c);
			oy = c[0];
			om = 0.0f;
			return;
		}
		float qx, qy;
		local(x, z, qx, qy);
		float smx = float(massif_q(qx, qy, x, z));
		float smy = 0.0f;
		if (!shelves.empty()) shelve(double(smx), qx, x, z, smx, smy);
		double y = smax(double(smx), base, BLEND);
		const double meadow = double(smy) * chunk_pass::smoothstep(0.0, BLEND, double(smx) - base);
		if (y != base) {
			const double e = chunk_pass::minf(chunk_pass::minf(x - double(bx), double(bx + bw) - x), chunk_pass::minf(z - double(bz), double(bz + bh) - z));
			if (e < EDGE_FADE) y = base + (y - base) * chunk_pass::smoothstep(0.0, EDGE_FADE, e);
		}
		y = trench(y, ox, oz, -wx, -wz, x, z, double(ramp_x));
		y = trench(y, mbx, mbz, obx, obz, x, z, double(ramp_y));
		oy = float(pit(y, x, z));
		om = float(meadow);
	}

	double bowl_e(float mx, float mz, float o_x, float o_z, double x, double z, double reach) const {
		const double qx = x - double(mx);
		const double qz = z - double(mz);
		const double a = qx * double(o_x) + qz * double(o_z);
		if (a < 0.0 || a > reach) return chunk_pass::INF_D;
		const double b = std::fabs(double(o_x) * qz - double(o_z) * qx);
		const double c = reach * 0.42;
		const double wide = chunk_pass::lerpf(BOWL_MOUTH, BOWL_WIDE, chunk_pass::smoothstep(0.0, c, a));
		const double along = chunk_pass::maxf(a - c, 0.0) / (reach - c);
		const double rag = rock.at(x * 0.35, z * 0.35) * 0.34 + rock.at(x * 1.3, z * 1.3) * 0.1;
		return std::sqrt(along * along + b * b / (wide * wide)) * (1.0 + rag);
	}

	// `_bowl_cut`: Vector3 (floats).
	void bowl_cut(double y, float mx, float mz, float o_x, float o_z, double x, double z, double reach, double step, float out[3]) const {
		const double e = bowl_e(mx, mz, o_x, o_z, x, z, reach);
		if (e >= 1.0) { out[0] = float(y); out[1] = 0.0f; out[2] = 0.0f; return; }
		const double a = (x - double(mx)) * double(o_x) + (z - double(mz)) * double(o_z);
		const double lid = floor_y - SINK + a * BOWL_RISE;
		if (y <= lid) { out[0] = float(y); out[1] = 0.0f; out[2] = 0.0f; return; }
		const double wall = chunk_pass::smoothstep(WALL_E_X, WALL_E_Y, e) * (1.0 - chunk_pass::smoothstep(WALL_RIM, 1.0, e));
		double flute = 0.0;
		if (wall > 0.0) {
			// c := m+o*reach*0.42 (Vector2 * float, in floats)
			const float rf = float(reach);
			const float k42 = float(0.42);
			const float cx = mx + (o_x * rf) * k42;
			const float cz = mz + (o_z * rf) * k42;
			const float qx = float(x) - cx;
			const float qz = float(z) - cz;
			const double ring = zsland::det_atan2(double(qz), double(qx)) * BOWL_WIDE;
			const double fall = double(std::sqrt(qx * qx + qz * qz));
			flute = 1.0 - std::fabs(rock.at(ring * GULLY_SCALE_X, fall * GULLY_SCALE_Y)) * 2.6;
			flute = chunk_pass::clampf(flute, 0.0, 1.0) * wall * (1.0 - chunk_pass::smoothstep(GULLY_FADE_X, GULLY_FADE_Y, step));
		}
		double k = zsland::det_pow(chunk_pass::minf(e + flute * GULLY_BACK, 1.0), BOWL_FALL);
		k = chunk_pass::lerpf(k, 1.0, chunk_pass::smoothstep(WALL_RIM, 1.0, e));
		const double rough = BOWL_ROUGH * chunk_pass::smoothstep(APRON, APRON * 3.0, a) * (1.0 - k) * std::fabs(rock.at(x * 0.9, z * 0.9)) * 2.0;
		double cut = chunk_pass::lerpf(lid + rough, y, k);
		double groove = flute;
		double crest_m = 0.0;
		double bench = wall * (1.0 - chunk_pass::smoothstep(WALL_FADE_X, WALL_FADE_Y, step));
		if (bench > 0.0) bench *= chunk_pass::smoothstep(BENCH_PATCH_Y, BENCH_PATCH_Z, rock.at(x * BENCH_PATCH_X + 91.0, z * BENCH_PATCH_X));
		if (bench > 0.0) {
			const double tier = cut / WALL_BENCH + rock.at(x * 0.18, z * 0.18) * BENCH_WANDER;
			const double fr = tier - std::floor(tier);
			cut += (chunk_pass::smoothstep(BENCH_RISER_X, BENCH_RISER_Y, fr) - fr) * WALL_BENCH * bench;
			groove = chunk_pass::maxf(groove, chunk_pass::smoothstep(0.05, BENCH_RISER_X, fr) * (1.0 - chunk_pass::smoothstep(BENCH_RISER_X, 0.5, fr)) * bench);
			crest_m = chunk_pass::smoothstep(0.5, BENCH_RISER_Y, fr) * (1.0 - chunk_pass::smoothstep(BENCH_RISER_Y, 0.95, fr)) * bench;
		}
		out[0] = float(chunk_pass::minf(y, cut));
		out[1] = float(groove);
		out[2] = float(crest_m);
	}

	void sunk_at(double base, double x, double z, double step, float out[3]) const {
		float a[3], b[3];
		bowl_cut(base, ox, oz, -wx, -wz, x, z, double(ramp_x), step, a);
		bowl_cut(double(a[0]), mbx, mbz, obx, obz, x, z, double(ramp_y), step, b);
		out[0] = b[0];
		out[1] = float(chunk_pass::maxf(double(a[1]), double(b[1])));
		out[2] = float(chunk_pass::maxf(double(a[2]), double(b[2])));
	}

	double trench_under_at(double x, double z, double step) const {
		if (sunk || !has_point(float(x), float(z))) return chunk_pass::INF_D;
		double out = chunk_pass::INF_D;
		for (int mm = 0; mm < 2; ++mm) {
			const float atx = mm == 0 ? ox : mbx, atz = mm == 0 ? oz : mbz;
			const float o_x = mm == 0 ? -wx : obx, o_z = mm == 0 ? -wz : obz;
			const float qx = float(x) - atx, qz = float(z) - atz;
			const double a = double(qx * o_x + qz * o_z);
			const double reach = APRON + double(mm == 0 ? ramp_x : ramp_y);
			if (a < -chunk_pass::minf(step, FACE_REACH) || a > reach + step) continue;
			const double b = chunk_pass::maxf(std::fabs(double(o_x * qz - o_z * qx)) - step, 0.0);
			if (b > TRENCH_WIDE) continue;
			double lid = floor_y - SINK + chunk_pass::maxf(chunk_pass::clampf(a - step, 0.0, reach) - APRON, 0.0) * grade;
			if (b > HALL_HALF + EDGE) lid += SHEER + (b - HALL_HALF - EDGE) / LEAN;
			else if (b > HALL_HALF) lid += SHEER * (b - HALL_HALF) / EDGE;
			out = chunk_pass::minf(out, lid);
		}
		return out;
	}

	// Bound.
	Vector2 carve_m(double base, double x, double z) const {
		float y, m;
		carve_at(base, x, z, y, m);
		return Vector2(y, m);
	}
	Vector3 sunk_cut(double base, double x, double z, double step) const {
		float c[3];
		sunk_at(base, x, z, step, c);
		return Vector3(c[0], c[1], c[2]);
	}
	double trench_under(double x, double z, double step) const { return trench_under_at(x, z, step); }
	// The box's float bounds, for the chunk pass.
	float box_x() const { return bx; }
	float box_z() const { return bz; }
	float box_ex() const { return bx + bw; }
	float box_ez() const { return bz + bh; }
};

class ZenScapeChunkPass : public RefCounted {
	GDCLASS(ZenScapeChunkPass, RefCounted)

	// tunnel_sites.gd's (apply_chunk's).
	double BOWL_TURF = 7, SHELF_MEADOW = 0.9, SEA_Y = -40, DRY_LOW_RIVER = -440;
	double MEADOW_LIFT_X = 4, MEADOW_LIFT_Y = 30, BOWL_FLOOR_X = 0, BOWL_FLOOR_Y = 0, BOWL_FLOOR_Z = 0;
	// land_ponds.gd's.
	double P_CELL = 400, P_REACH = 40, P_BOWL = 0.3, P_BANK_RISE = 0.14, P_LIP_X = 5, P_LIP_Y = 9;

	// Ponds.at: (outside its edge, from its centre, its radius that way), floats.
	void pond_at(const float *p, double x, double z, float e[3]) const {
		const double dx = x - double(p[0]);
		const double dz = z - double(p[1]);
		const double far = double(p[11]) + P_REACH;
		const float inf = std::numeric_limits<float>::infinity();
		if (std::fabs(dx) > far || std::fabs(dz) > far) { e[0] = inf; e[1] = 0; e[2] = 0; return; }
		const double r = std::sqrt(dx * dx + dz * dz);
		if (r > far) { e[0] = inf; e[1] = 0; e[2] = 0; return; }
		const double a = zsland::det_atan2(dz, dx);
		const double edge = double(p[2]) * (1.0 + double(p[5]) * zsland::det_sin(2.0 * a + double(p[6])) + double(p[7]) * zsland::det_sin(3.0 * a + double(p[8])) + double(p[9]) * zsland::det_sin(5.0 * a + double(p[10])));
		e[0] = float(r - edge);
		e[1] = float(r);
		e[2] = float(edge);
	}

	// Ponds.carve.
	double pond_carve(const float *p, double base, const float e[3]) const {
		const double level = double(p[3]);
		const double ex = double(e[0]);
		if (ex < 0.0) {
			const double s = double(e[1]) / chunk_pass::maxf(double(e[2]), 0.01);
			return chunk_pass::minf(base, level - double(p[4]) * (1.0 - chunk_pass::smoothstep(P_BOWL, 1.0, s)));
		}
		if (ex > P_LIP_Y && base < level + P_BANK_RISE * ex) return base;
		double h = chunk_pass::minf(base, level + P_BANK_RISE * ex);
		const double lip = 1.0 - chunk_pass::smoothstep(P_LIP_X, P_LIP_Y, ex);
		if (lip > 0.0) h = chunk_pass::maxf(h, chunk_pass::lerpf(h, level + 0.06 + 0.08 * ex, lip));
		return h;
	}

	static std::vector<Ref<ZenScapeTunnelCarve>> carves(const Array &a) {
		std::vector<Ref<ZenScapeTunnelCarve>> out;
		for (int64_t i = 0; i < a.size(); ++i) {
			Ref<ZenScapeTunnelCarve> c = a[i];
			if (c.is_valid()) out.push_back(c);
		}
		return out;
	}

	double meadow_keep(double lift) const {
		if (lift < 0.0) return 0.0;
		return 1.0 - chunk_pass::smoothstep(MEADOW_LIFT_X, MEADOW_LIFT_Y, lift);
	}

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("version"), &ZenScapeChunkPass::version);
		ClassDB::bind_method(D_METHOD("setup", "consts"), &ZenScapeChunkPass::setup);
		ClassDB::bind_method(D_METHOD("setup_ponds", "consts"), &ZenScapeChunkPass::setup_ponds);
		ClassDB::bind_method(D_METHOD("tunnel_chunk", "made", "carves", "x0", "z0", "step", "cells", "skirt_drop", "height", "impl"), &ZenScapeChunkPass::tunnel_chunk);
		ClassDB::bind_method(D_METHOD("river_near", "river", "count"), &ZenScapeChunkPass::river_near);
		ClassDB::bind_method(D_METHOD("river_ring", "field", "carves", "pond_cells", "ponds", "x0", "z0", "step", "cells"), &ZenScapeChunkPass::river_ring);
		ClassDB::bind_method(D_METHOD("river_frame", "made", "ring_r", "ring_w", "step", "cells"), &ZenScapeChunkPass::river_frame);
		ClassDB::bind_method(D_METHOD("grid_heights", "field", "carves", "ponds", "x0", "z0", "step", "nx", "nz", "pad"), &ZenScapeChunkPass::grid_heights);
		ClassDB::bind_method(D_METHOD("any_steep", "normals", "count", "up"), &ZenScapeChunkPass::any_steep);
		ClassDB::bind_method(D_METHOD("rock_layer", "shape", "hs", "c", "per", "k", "d", "gn", "a", "cells"), &ZenScapeChunkPass::rock_layer);
		ClassDB::bind_method(D_METHOD("rock_finish", "shape", "cells"), &ZenScapeChunkPass::rock_finish);
		ClassDB::bind_method(D_METHOD("portal_tris", "made", "mask", "cells", "faces"), &ZenScapeChunkPass::portal_tris);
	}

public:
	int64_t version() const { return 1; }

	void setup(const Dictionary &c) {
#define CP_K(name) name = double(c.get(#name, name))
		CP_K(BOWL_TURF); CP_K(SHELF_MEADOW); CP_K(SEA_Y); CP_K(DRY_LOW_RIVER);
#undef CP_K
		const Vector2 ml = c.get("MEADOW_LIFT", Vector2(4, 30));
		MEADOW_LIFT_X = double(ml.x); MEADOW_LIFT_Y = double(ml.y);
		const Vector3 bf = c.get("BOWL_FLOOR", Vector3());
		BOWL_FLOOR_X = double(bf.x); BOWL_FLOOR_Y = double(bf.y); BOWL_FLOOR_Z = double(bf.z);
	}

	void setup_ponds(const Dictionary &c) {
		P_CELL = double(c.get("CELL", P_CELL));
		P_REACH = double(c.get("REACH", P_REACH));
		P_BOWL = double(c.get("BOWL", P_BOWL));
		P_BANK_RISE = double(c.get("BANK_RISE", P_BANK_RISE));
		const Vector2 l = c.get("LIP", Vector2(5, 9));
		P_LIP_X = double(l.x); P_LIP_Y = double(l.y);
	}

	// Tunnels.apply_chunk: the tunnels' pass over a chunk's arrays. `height`
	// the LandField's height (the normals past the chunk's edge), `impl` the
	// field doing the work (its `colour`).
	void tunnel_chunk(Dictionary made, const Array &p_carves, double x0, double z0, double step, int64_t cells, double skirt_drop, const Callable &height, Object *impl) {
		const std::vector<Ref<ZenScapeTunnelCarve>> ts = carves(p_carves);
		if (ts.empty()) return;
		const int64_t n = cells + 1;
		PackedFloat32Array heights = made["heights"];
		PackedVector3Array verts = made["verts"];
		PackedVector3Array normals = made["normals"];
		PackedColorArray colours = made["colours"];
		PackedByteArray carved = made["carved"];
		PackedFloat32Array river = made["river"];
		bool sunk = false;
		for (const auto &t : ts) sunk = sunk || t->is_sunk();
		std::vector<float> lift(size_t(n * n), 0.0f);
		std::vector<uint8_t> moved(size_t(n * n), 0);
		std::vector<float> shelf;
		std::vector<uint8_t> marks(size_t(sunk ? n * n * 2 : 0), 0);
		bool any_moved = false;
		float *hp = heights.ptrw();
		Vector3 *vp = verts.ptrw();
		for (const auto &t : ts) {
			const int64_t i0 = chunk_pass::clampi(chunk_pass::floori((double(t->box_x()) - x0) / step), 0, cells);
			const int64_t i1 = chunk_pass::clampi(chunk_pass::ceili((double(t->box_ex()) - x0) / step), 0, cells);
			const int64_t j0 = chunk_pass::clampi(chunk_pass::floori((double(t->box_z()) - z0) / step), 0, cells);
			const int64_t j1 = chunk_pass::clampi(chunk_pass::ceili((double(t->box_ez()) - z0) / step), 0, cells);
			for (int64_t j = j0; j <= j1; ++j) {
				for (int64_t i = i0; i <= i1; ++i) {
					const int64_t v = j * n + i;
					const double x = x0 + double(i) * step;
					const double z = z0 + double(j) * step;
					float ymx = 0.0f, ymy = 0.0f;
					if (t->is_sunk()) {
						float c[3];
						t->sunk_at(double(hp[v]), x, z, step, c);
						ymx = c[0];
						if (c[1] > 0.0f || c[2] > 0.0f) {
							marks[size_t(v * 2)] = uint8_t(int64_t(double(c[1]) * 255.0));
							marks[size_t(v * 2 + 1)] = uint8_t(int64_t(double(c[2]) * 255.0));
						}
					} else {
						t->carve_at(double(hp[v]), x, z, ymx, ymy);
					}
					double y = double(ymx);
					if (step > 1.0) y = chunk_pass::minf(y, t->trench_under_at(x, z, step));
					if (ymy > 0.0f) {
						if (shelf.empty()) shelf.assign(size_t(n * n), 0.0f);
						shelf[size_t(v)] = float(chunk_pass::maxf(double(shelf[size_t(v)]), double(ymy)));
					}
					if (std::fabs(y - double(hp[v])) > 0.0005) {
						lift[size_t(v)] = float(double(lift[size_t(v)]) + (y - double(hp[v])));
						hp[v] = float(y);
						vp[v] = Vector3(vp[v].x, float(y), vp[v].z);
						moved[size_t(v)] = 1;
						any_moved = true;
					}
				}
			}
		}
		if (!any_moved) return;
		std::vector<uint8_t> redo(size_t(n * n), 0);
		static const int dd[5][2] = { { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } };
		for (int64_t j = 0; j < n; ++j) {
			for (int64_t i = 0; i < n; ++i) {
				if (moved[size_t(j * n + i)] == 0) continue;
				for (const auto &d : dd) {
					const int64_t ii = i + d[0], jj = j + d[1];
					if (ii >= 0 && ii < n && jj >= 0 && jj < n) redo[size_t(jj * n + ii)] = 1;
				}
			}
		}
		Vector3 *np = normals.ptrw();
		Color *cp = colours.ptrw();
		ZenScapeLandField *lf = Object::cast_to<ZenScapeLandField>(impl);
		uint8_t *kp = carved.ptrw();
		float *rp = river.ptrw();
		for (int64_t j = 0; j < n; ++j) {
			for (int64_t i = 0; i < n; ++i) {
				const int64_t v = j * n + i;
				if (redo[size_t(v)] == 0) continue;
				const double x = x0 + double(i) * step;
				const double z = z0 + double(j) * step;
				const double hl = i > 0 ? double(hp[v - 1]) : double(height.call(x - step, z));
				const double hr = i < cells ? double(hp[v + 1]) : double(height.call(x + step, z));
				const double hd = j > 0 ? double(hp[v - n]) : double(height.call(x, z - step));
				const double hu = j < cells ? double(hp[v + n]) : double(height.call(x, z + step));
				const zsland::V3 nv = zsland::V3(hl - hr, 2.0 * step, hd - hu).normalized();
				const Vector3 normal(nv.x, nv.y, nv.z);
				np[v] = normal;
				double meadow = double(cp[v].a);
				const double lv = double(lift[size_t(v)]);
				if (moved[size_t(v)] != 0) meadow *= (sunk && lv < 0.0) ? 1.0 - chunk_pass::smoothstep(0.0, BOWL_TURF, -lv) : meadow_keep(lv);
				if (sunk && lv < -BOWL_TURF) meadow = chunk_pass::maxf(meadow, BOWL_FLOOR_Z * chunk_pass::smoothstep(BOWL_FLOOR_X, BOWL_FLOOR_Y, double(normal.y)));
				if (!shelf.empty()) meadow = chunk_pass::maxf(meadow, SHELF_MEADOW * double(shelf[size_t(v)]));
				const double cy = !sunk ? double(hp[v]) : chunk_pass::maxf(double(hp[v]), SEA_Y + 26.0);
				Color c = lf != nullptr ? lf->colour(x, z, cy, double(normal.y), meadow) : Color(impl->call("colour", x, z, cy, double(normal.y), meadow));
				c.a = float(meadow);
				cp[v] = c;
				if (moved[size_t(v)] != 0) {
					kp[v * 4] = sunk ? marks[size_t(v * 2)] : 0;
					kp[v * 4 + 1] = sunk ? marks[size_t(v * 2 + 1)] : 0;
					if (lv > 1.0 || (sunk && lv < -1.0)) {
						kp[v * 4 + 2] = 128;
						kp[v * 4 + 3] = 128;
						rp[v * 3] = 1000.0f;
						rp[v * 3 + 1] = 0.0f;
						rp[v * 3 + 2] = float(lv < 0.0 ? DRY_LOW_RIVER : SEA_Y - 100.0);
					}
				}
			}
		}
		for (int e = 0; e < 4; ++e) {
			for (int64_t t = 0; t < n; ++t) {
				const int64_t from = e == 0 ? t : (e == 1 ? t * n + cells : (e == 2 ? cells * n + t : t * n));
				if (redo[size_t(from)] == 0) continue;
				const int64_t v = n * n + e * n + t;
				vp[v] = vp[from] - Vector3(0.0f, float(skirt_drop), 0.0f);
				np[v] = np[from];
				cp[v] = cp[from];
				for (int q = 0; q < 4; ++q) kp[v * 4 + q] = kp[from * 4 + q];
				rp[v * 3] = rp[from * 3];
				rp[v * 3 + 1] = -rp[from * 3 + 1];
				rp[v * 3 + 2] = rp[from * 3 + 2];
			}
		}
		made["heights"] = heights;
		made["verts"] = verts;
		made["normals"] = normals;
		made["colours"] = colours;
		made["carved"] = carved;
		made["river"] = river;
	}

	// `_river_frame`'s first test: a river near any of the grid's vertices.
	bool river_near(const PackedFloat32Array &river, int64_t count) const {
		const float *r = river.ptr();
		for (int64_t v = 0; v < count && v * 3 + 1 < river.size(); ++v) {
			if (double(r[v * 3 + 1]) > 0.05 && std::fabs(double(r[v * 3])) < double(r[v * 3 + 1]) + 40.0) return true;
		}
		return false;
	}

	// `_river_frame`'s ring of samples (two past the grid each way, in its scan
	// order, the grid skipped) off the native field `field`, with the tunnels
	// `carves` cut in (LandField `sample`'s `_tunnel`, where they are the only
	// layer there): [river_r clamped, river_w] per sample.
	Array river_ring(Object *field, const Array &p_carves, const PackedInt32Array &pond_cells, const Array &ponds, double x0, double z0, double step, int64_t cells) {
		Array out;
		ZenScapeLandField *lf = Object::cast_to<ZenScapeLandField>(field);
		if (lf == nullptr) return out;
		zsland::LandField &f = lf->land();
		const std::vector<Ref<ZenScapeTunnelCarve>> ts = carves(p_carves);
		// The ponds by their square (LandField `_pond_for`): (ci, cj) pairs.
		std::vector<PackedFloat32Array> pk;
		for (int64_t i = 0; i < ponds.size(); ++i) pk.push_back(ponds[i]);
		const int64_t np = std::min<int64_t>(int64_t(pk.size()), pond_cells.size() / 2);
		const int64_t n = cells + 1;
		const int64_t m = n + 4;
		PackedFloat32Array rr, ww;
		rr.resize(m * m - n * n);
		ww.resize(m * m - n * n);
		float *ro = rr.ptrw();
		float *wo = ww.ptrw();
		int64_t w = 0;
		for (int64_t j = 0; j < m; ++j) {
			for (int64_t i = 0; i < m; ++i) {
				if (i >= 2 && i < n + 2 && j >= 2 && j < n + 2) continue;
				const double x = x0 + double(i - 2) * step;
				const double z = z0 + double(j - 2) * step;
				zsland::V2 got = f.sample(x, z);
				bool t_on = false, p_on = false;
				float p_r = 0.0f, p_w = 0.0f;
				if (np > 0) {
					const int64_t ci = chunk_pass::floori(x / P_CELL), cj = chunk_pass::floori(z / P_CELL);
					for (int64_t q = 0; q < np; ++q) {
						if (pond_cells[q * 2] != ci || pond_cells[q * 2 + 1] != cj || pk[size_t(q)].size() < 12) continue;
						const float *pp = pk[size_t(q)].ptr();
						float e[3];
						pond_at(pp, x, z, e);
						if (double(e[0]) >= P_REACH) break;
						if (double(e[0]) < f.last_river) {
							p_on = true;
							p_r = e[1];
							p_w = e[2];
						}
						if (double(e[0]) < P_LIP_Y) got.x = float(pond_carve(pp, double(got.x), e));
						break;
					}
				}
				for (const auto &t : ts) {
					float ymx, ymy;
					t->carve_at(double(got.x), x, z, ymx, ymy);
					const double y = double(ymx);
					const double d = y - double(got.x);
					if (d == 0.0) continue;
					got.y = float(chunk_pass::maxf(double(got.y) * meadow_keep(d), SHELF_MEADOW * double(ymy)));
					if (d > 1.0) t_on = true;
					got.x = float(y);
				}
				ro[w] = float(chunk_pass::clampf(t_on ? 1000.0 : (p_on ? double(p_r) : double(f.last_river_r)), -1000.0, 1000.0));
				wo[w] = float(p_on ? double(p_w) : double(f.last_river_w));
				++w;
			}
		}
		out.append(rr);
		out.append(ww);
		return out;
	}

	// `_river_frame` past its ring of samples (river_ring's order).
	PackedFloat32Array river_frame(const Dictionary &made, const PackedFloat32Array &ring_r, const PackedFloat32Array &ring_w, double step, int64_t cells) const {
		const int64_t n = cells + 1;
		const int64_t m = n + 4;
		PackedFloat32Array frame;
		frame.resize((n * n + 4 * n) * 4);
		float *fo = frame.ptrw();
		for (int64_t i = 0; i < frame.size(); ++i) fo[i] = 0.0f;
		const PackedFloat32Array river = made["river"];
		const PackedByteArray carved = made["carved"];
		if (ring_r.size() != m * m - n * n || ring_w.size() != ring_r.size()) return frame;
		const float *r = river.ptr();
		const uint8_t *cv = carved.ptr();
		std::vector<float> rs(size_t(m * m)), ws(size_t(m * m));
		int64_t w = 0;
		for (int64_t j = 0; j < m; ++j) {
			for (int64_t i = 0; i < m; ++i) {
				const int64_t k = j * m + i;
				if (i >= 2 && i < n + 2 && j >= 2 && j < n + 2) {
					const int64_t v = (j - 2) * n + i - 2;
					rs[size_t(k)] = r[v * 3];
					ws[size_t(k)] = r[v * 3 + 1];
				} else {
					rs[size_t(k)] = ring_r[w];
					ws[size_t(k)] = ring_w[w];
					++w;
				}
			}
		}
		std::vector<float> nx(size_t(m * m), 0.0f), nz(size_t(m * m), 0.0f);
		for (int64_t j = 1; j < m - 1; ++j) {
			for (int64_t i = 1; i < m - 1; ++i) {
				const int64_t k = j * m + i;
				// Vector2(rs[k+1]-rs[k-1], rs[k+m]-rs[k-m]): doubles rounded to floats.
				float gx = float(double(rs[size_t(k + 1)]) - double(rs[size_t(k - 1)]));
				float gy = float(double(rs[size_t(k + m)]) - double(rs[size_t(k - m)]));
				const float l2 = gx * gx + gy * gy;
				if (double(l2) > 1e-12) {
					const float l = std::sqrt(l2);
					if (l != 0.0f) {
						gx /= l;
						gy /= l;
					}
					nx[size_t(k)] = gx;
					nz[size_t(k)] = gy;
				}
			}
		}
		const double h2 = 1.0 / (2.0 * step);
		for (int64_t j = 0; j < n; ++j) {
			for (int64_t i = 0; i < n; ++i) {
				const int64_t v = j * n + i;
				if (double(r[v * 3 + 1]) <= 0.05 || std::fabs(double(r[v * 3])) > double(r[v * 3 + 1]) + 40.0) continue;
				const int64_t k = (j + 2) * m + i + 2;
				float tx = -nz[size_t(k)], ty = nx[size_t(k)];
				const float fx = float(double(cv[v * 4 + 2]) / 255.0 * 2.0 - 1.0);
				const float fy = float(double(cv[v * 4 + 3]) / 255.0 * 2.0 - 1.0);
				if (tx * fx + ty * fy < 0.0f) {
					tx = -tx;
					ty = -ty;
				}
				const double bend = ((double(nx[size_t(k + 1)]) - double(nx[size_t(k - 1)])) + (double(nz[size_t(k + m)]) - double(nz[size_t(k - m)]))) * h2;
				// Vector2(ws diffs) * h2: floats, then the float product.
				const float wgx = float(double(ws[size_t(k + 1)]) - double(ws[size_t(k - 1)]));
				const float wgy = float(double(ws[size_t(k + m)]) - double(ws[size_t(k - m)]));
				const float h2f = float(h2);
				const float wx = wgx * h2f, wy = wgy * h2f;
				fo[v * 4] = tx;
				fo[v * 4 + 1] = ty;
				fo[v * 4 + 2] = float(chunk_pass::clampf(bend, -0.2, 0.2));
				fo[v * 4 + 3] = float(chunk_pass::clampf(double(wx * tx + wy * ty), -1.0, 1.0));
			}
		}
		for (int e = 0; e < 4; ++e) {
			for (int64_t t = 0; t < n; ++t) {
				const int64_t from = e == 0 ? t : (e == 1 ? t * n + cells : (e == 2 ? cells * n + t : t * n));
				const int64_t v = n * n + e * n + t;
				for (int c = 0; c < 4; ++c) fo[v * 4 + c] = fo[from * 4 + c];
			}
		}
		return frame;
	}

	// LandField `grid`'s heights where only the native field, the ponds and
	// the tunnels shape the land (Ponds.apply_grid, then Tunnels.apply_grid).
	PackedFloat32Array grid_heights(Object *field, const Array &p_carves, const Array &ponds, double x0, double z0, double step, int64_t nx, int64_t nz, int64_t pad) {
		ZenScapeLandField *lf = Object::cast_to<ZenScapeLandField>(field);
		if (lf == nullptr) return PackedFloat32Array();
		const Dictionary got = lf->grid(x0, z0, step, nx, nz, pad);
		PackedFloat32Array hs = got["heights"];
		float *h = hs.ptrw();
		for (int64_t q = 0; q < ponds.size(); ++q) {
			const PackedFloat32Array pa = ponds[q];
			if (pa.size() < 12) continue;
			const float *p = pa.ptr();
			const double far = double(p[11]) + P_REACH;
			const int64_t i0 = chunk_pass::clampi(chunk_pass::floori((double(p[0]) - far - x0) / step) + pad, 0, nx - 1);
			const int64_t i1 = chunk_pass::clampi(chunk_pass::ceili((double(p[0]) + far - x0) / step) + pad, 0, nx - 1);
			const int64_t j0 = chunk_pass::clampi(chunk_pass::floori((double(p[1]) - far - z0) / step) + pad, 0, nz - 1);
			const int64_t j1 = chunk_pass::clampi(chunk_pass::ceili((double(p[1]) + far - z0) / step) + pad, 0, nz - 1);
			for (int64_t j = j0; j <= j1; ++j) {
				for (int64_t i = i0; i <= i1; ++i) {
					float e[3];
					pond_at(p, x0 + double(i - pad) * step, z0 + double(j - pad) * step, e);
					if (double(e[0]) >= P_REACH) continue;
					const int64_t k = j * nx + i;
					if (double(e[0]) < P_LIP_Y) h[k] = float(pond_carve(p, double(h[k]), e));
				}
			}
		}
		for (const auto &t : carves(p_carves)) {
			const int64_t i0 = chunk_pass::clampi(chunk_pass::floori((double(t->box_x()) - x0) / step) + pad, 0, nx - 1);
			const int64_t i1 = chunk_pass::clampi(chunk_pass::ceili((double(t->box_ex()) - x0) / step) + pad, 0, nx - 1);
			const int64_t j0 = chunk_pass::clampi(chunk_pass::floori((double(t->box_z()) - z0) / step) + pad, 0, nz - 1);
			const int64_t j1 = chunk_pass::clampi(chunk_pass::ceili((double(t->box_ez()) - z0) / step) + pad, 0, nz - 1);
			for (int64_t j = j0; j <= j1; ++j) {
				for (int64_t i = i0; i <= i1; ++i) {
					const double x = x0 + double(i - pad) * step;
					const double z = z0 + double(j - pad) * step;
					const int64_t k = j * nx + i;
					float ymx, ymy;
					t->carve_at(double(h[k]), x, z, ymx, ymy);
					const double d = double(ymx) - double(h[k]);
					if (std::fabs(d) <= 0.0005) continue;
					h[k] = ymx;
				}
			}
		}
		return hs;
	}

	bool any_steep(const PackedVector3Array &normals, int64_t count, double up) const {
		const Vector3 *p = normals.ptr();
		for (int64_t v = 0; v < count && v < normals.size(); ++v) {
			if (double(p[v].y) < up) return true;
		}
		return false;
	}

	// RockShape.grid's work for radius `c` over its padded grid `hs`.
	PackedByteArray rock_layer(PackedByteArray shape, const PackedFloat32Array &hs, int64_t c, int64_t per, int64_t k, int64_t d, int64_t gn, double a, int64_t cells) const {
		const int64_t n = cells + 1;
		const int64_t m = gn + 2 * k;
		if (hs.size() < m * m || shape.size() < n * n * 4) return shape;
		const float *h = hs.ptr();
		std::vector<float> lay(size_t(gn * gn));
		for (int64_t j = 0; j < gn; ++j) {
			const int64_t row = (j + k) * m + k;
			for (int64_t i = 0; i < gn; ++i) {
				const int64_t q = row + i;
				const double s = double(h[q]) * 8.0 - double(h[q - k]) - double(h[q + k]) - double(h[q - k * m]) - double(h[q + k * m]) - double(h[q - d - d * m]) - double(h[q + d - d * m]) - double(h[q - d + d * m]) - double(h[q + d + d * m]);
				lay[size_t(j * gn + i)] = float(chunk_pass::clampf(0.5 + s * a, 0.0, 1.0));
			}
		}
		uint8_t *sp = shape.ptrw();
		if (per == 1) {
			for (int64_t v = 0; v < n * n; ++v) sp[v * 4 + c] = uint8_t(int64_t(double(lay[size_t(v)]) * 255.0));
			return shape;
		}
		const double inv = 1.0 / double(per);
		for (int64_t j = 0; j < n; ++j) {
			const int64_t iz = std::min<int64_t>(j / per, gn - 2);
			const double fz = double(j - iz * per) * inv;
			for (int64_t i = 0; i < n; ++i) {
				const int64_t ix = std::min<int64_t>(i / per, gn - 2);
				const double fx = double(i - ix * per) * inv;
				const int64_t q = iz * gn + ix;
				const double val = chunk_pass::lerpf(chunk_pass::lerpf(double(lay[size_t(q)]), double(lay[size_t(q + 1)]), fx), chunk_pass::lerpf(double(lay[size_t(q + gn)]), double(lay[size_t(q + gn + 1)]), fx), fz);
				sp[(j * n + i) * 4 + c] = uint8_t(int64_t(val * 255.0));
			}
		}
		return shape;
	}

	// RockShape.grid's alpha and skirt.
	PackedByteArray rock_finish(PackedByteArray shape, int64_t cells) const {
		const int64_t n = cells + 1;
		if (shape.size() < (n * n + 4 * n) * 4) return shape;
		uint8_t *sp = shape.ptrw();
		for (int64_t v = 0; v < n * n; ++v) sp[v * 4 + 3] = 255;
		for (int e = 0; e < 4; ++e) {
			for (int64_t t = 0; t < n; ++t) {
				const int64_t from = e == 0 ? t : (e == 1 ? t * n + cells : (e == 2 ? cells * n + t : t * n));
				const int64_t v = n * n + e * n + t;
				for (int c = 0; c < 4; ++c) sp[v * 4 + c] = sp[from * 4 + c];
			}
		}
		return shape;
	}

	// `_portal_holes` past its mask: the grid's triangles not wholly on it, then
	// the skirts' (land_stream `_grid_indices`' order); `faces` (a level-0
	// chunk) also the grid's kept triangles' corners. Sets made.indices
	// (and made.faces).
	void portal_tris(Dictionary made, const PackedByteArray &mask, int64_t cells, bool want_faces) const {
		const int64_t n = cells + 1;
		if (mask.size() < n * n) return;
		const uint8_t *mk = mask.ptr();
		const PackedVector3Array verts = made["verts"];
		const Vector3 *vp = verts.ptr();
		PackedInt32Array out;
		PackedVector3Array faces;
		std::vector<int32_t> o;
		std::vector<Vector3> fc;
		o.reserve(size_t(cells * cells * 6 + 24 * cells));
		for (int64_t j = 0; j < cells; ++j) {
			for (int64_t i = 0; i < cells; ++i) {
				const int32_t a = int32_t(j * n + i);
				const int32_t tri[2][3] = { { a, a + 1, a + int32_t(n) }, { a + 1, a + int32_t(n) + 1, a + int32_t(n) } };
				for (const auto &t : tri) {
					if (mk[t[0]] != 0 && mk[t[1]] != 0 && mk[t[2]] != 0) continue;
					o.push_back(t[0]);
					o.push_back(t[1]);
					o.push_back(t[2]);
					if (want_faces) {
						fc.push_back(vp[t[0]]);
						fc.push_back(vp[t[1]]);
						fc.push_back(vp[t[2]]);
					}
				}
			}
		}
		auto edge = [&](int e, int64_t t) -> int64_t { return e == 0 ? t : (e == 1 ? t * n + cells : (e == 2 ? cells * n + t : t * n)); };
		auto on = [&](int64_t v) -> bool {
			if (v < n * n) return mk[v] != 0;
			const int64_t e = (v - n * n) / n;
			const int64_t t = (v - n * n) % n;
			return mk[edge(int(e), t)] != 0;
		};
		for (int e = 0; e < 4; ++e) {
			for (int64_t t = 0; t < cells; ++t) {
				const int32_t a = int32_t(edge(e, t));
				const int32_t b = int32_t(edge(e, t + 1));
				const int32_t sa = int32_t(n * n + e * n + t);
				const int32_t two[2][3] = { { a, b, sa }, { b, sa + 1, sa } };
				for (const auto &q : two) {
					if (on(q[0]) && on(q[1]) && on(q[2])) continue;
					o.push_back(q[0]);
					o.push_back(q[1]);
					o.push_back(q[2]);
				}
			}
		}
		out.resize(int64_t(o.size()));
		int32_t *op = out.ptrw();
		for (size_t i = 0; i < o.size(); ++i) op[i] = o[i];
		made["indices"] = out;
		if (want_faces) {
			faces.resize(int64_t(fc.size()));
			Vector3 *fp = faces.ptrw();
			for (size_t i = 0; i < fc.size(); ++i) fp[i] = fc[i];
			made["faces"] = faces;
		}
	}
};
