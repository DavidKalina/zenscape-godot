// ZenScapePeak: the Peak's massif (peak_massif.h) for GDScript. PeakMassif
// (scripts/endless/peak_massif.gd) makes one per land, passes it everything
// the land worked out once (`setup`) and shares it with every worker's massif:
// it is only read after that, so any number of workers call it at once.
#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/vector4.hpp>
#include <vector>
#include "land_field_bind.h"
#include "peak_massif.h"

using namespace godot;

class ZenScapePeak : public RefCounted {
	GDCLASS(ZenScapePeak, RefCounted)

	zspeak::Massif m;

	static zsland::V2 v2(const Vector2 &v) { return zsland::V2::of(v.x, v.y); }
	static std::vector<float> floats(const PackedFloat32Array &a) {
		const int64_t n = a.size();
		std::vector<float> out(static_cast<size_t>(n));
		const float *p = a.ptr();
		for (int64_t i = 0; i < n; ++i) out[size_t(i)] = p[i];
		return out;
	}
	static std::vector<zsland::V2> vectors(const PackedVector2Array &a) {
		const int64_t n = a.size();
		std::vector<zsland::V2> out(static_cast<size_t>(n));
		const Vector2 *p = a.ptr();
		for (int64_t i = 0; i < n; ++i) out[size_t(i)] = v2(p[i]);
		return out;
	}

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("version"), &ZenScapePeak::version);
		ClassDB::bind_method(D_METHOD("setup", "data"), &ZenScapePeak::setup);
		ClassDB::bind_method(D_METHOD("h_rock", "a", "v", "step"), &ZenScapePeak::h_rock);
		ClassDB::bind_method(D_METHOD("apply_chunk", "field", "impl", "made", "x0", "z0", "step", "cells", "skirt_drop"), &ZenScapePeak::apply_chunk);
		ClassDB::bind_method(D_METHOD("apply_grid", "got", "x0", "z0", "step", "nx", "nz", "pad"), &ZenScapePeak::apply_grid);
	}

public:
	// Bumped when the massif's output or this interface changes, so PeakMassif
	// refuses a stale library (and runs its GDScript instead).
	int64_t version() const { return 2; }

	// All of it, once, before any worker reads it.
	void setup(const Dictionary &d) {
		m.libm = bool(d.get("libm", false));
		m.rock_on = bool(d.get("rock", true));
		m.ice_carve = bool(d.get("ice_carve", true));
		m.centre = v2(d["centre"]);
		m.facing = v2(d["facing"]);
		m.side = v2(d["side"]);
		m.o = v2(d["o"]);
		m.noises(int(int64_t(d["noise_seed"])), int(int64_t(d["rock_seed"])));
		const Array ribs = d["ribs"];
		for (int k = 0; k < 8; ++k) m.ribs[k] = floats(ribs[k]);
		m.towers = vectors(d["towers"]);
		m.crown = vectors(d["crown"]);
		m.root_way = vectors(d["root_way"]);
		m.tower_tops = floats(d["tower_tops"]);
		m.crown_ph = floats(d["crown_ph"]);
		m.tarn_c = v2(d["tarn_c"]);
		m.tarn_wet = double(d["tarn_wet"]);
		m.pond = floats(d["pond"]);
		const Vector3 ph = d["cq_ph"];
		m.cq_ph_x = ph.x;
		m.cq_ph_y = ph.y;
		m.cq_ph_z = ph.z;
		const PackedByteArray live = d["live"];
		m.live.assign(live.ptr(), live.ptr() + live.size());
		m.live_n = int(int64_t(d["live_n"]));
		m.live_at = v2(d["live_at"]);
		m.fall_map = floats(d["fall_map"]);
		const Array se = d["s_e"], sf = d["s_f"];
		for (int g = 0; g < 2; ++g) {
			m.s_e[g] = floats(se[g]);
			m.s_f[g] = floats(sf[g]);
		}
		m.s_hull = floats(d["s_hull"]);
		m.s_gap = floats(d["s_gap"]);
		m.s_tops = floats(d["s_tops"]);
		m.s_spine = floats(d["s_spine"]);
		m.s_na = int(int64_t(d["s_na"]));
		m.s_nv = int(int64_t(d["s_nv"]));
	}

	// PeakMassif `_h_rock`.
	Vector4 h_rock(double a, double v, double step) const {
		const zspeak::V4 h = m.h_rock(a, v, step);
		return Vector4(h.x, h.y, h.z, h.w);
	}

	// PeakMassif `apply_chunk`, line for line. `field` the LandField, `impl`
	// its field: a native one's colours are read directly, any other's (the
	// regions' blend, GDField) through LandField `colours`.
	void apply_chunk(Object *field, Object *impl, const Dictionary &p_made, double x0, double z0, double step, int64_t p_cells, double skirt_drop) {
		Dictionary made = p_made;
		const int cells = int(p_cells);
		const int n = cells + 1;
		const int w = n + 2;
		PackedFloat32Array heights = made["heights"];
		PackedVector3Array verts = made["verts"];
		PackedVector3Array normals = made["normals"];
		PackedColorArray colours = made["colours"];
		PackedByteArray carved = made["carved"];
		PackedFloat32Array river = made["river"];
		std::vector<float> hs(size_t(w) * w, 0.0f), relief(size_t(n) * n, 0.0f);
		std::vector<uint8_t> mv(size_t(w) * w, 0), lifted(size_t(n) * n, 0);
		// Read through `ptr` first: a chunk the massif leaves alone copies nothing.
		const float *h_in = heights.ptr();
		const Vector3 *n_in = normals.ptr();
		const Color *c_in = colours.ptr();
		std::vector<float> alpha(size_t(n) * n);
		for (int v = 0; v < n * n; ++v) alpha[size_t(v)] = c_in[v].a;
		bool any = false;
		const double r2 = zspeak::BOUND * zspeak::BOUND;
		const double fx = m.facing.x, fz = m.facing.y, sx = m.side.x, sz = m.side.y;
		const double ox = m.o.x, oz = m.o.y, cx = m.centre.x, cz = m.centre.y;
		const double lax = m.live_at.x, laz = m.live_at.y;
		for (int jj = 0; jj < w; ++jj) {
			const int j = jj - 1;
			const bool j_out = j < 0 || j > cells;
			for (int ii = 0; ii < w; ++ii) {
				const int i = ii - 1;
				const bool i_out = i < 0 || i > cells;
				if (i_out && j_out) continue;
				double base;
				int v = j * n + i;
				if (!i_out && !j_out) base = h_in[v];
				else if (i < 0) {
					v = j * n;
					base = double(h_in[v + 1]) + 2.0 * step * double(n_in[v].x) / double(n_in[v].y);
				} else if (i_out) {
					v = j * n + cells;
					base = double(h_in[v - 1]) - 2.0 * step * double(n_in[v].x) / double(n_in[v].y);
				} else if (j < 0) {
					v = i;
					base = double(h_in[v + n]) + 2.0 * step * double(n_in[v].z) / double(n_in[v].y);
				} else {
					v = cells * n + i;
					base = double(h_in[v - n]) - 2.0 * step * double(n_in[v].z) / double(n_in[v].y);
				}
				const int k = jj * w + ii;
				hs[size_t(k)] = float(base);
				const double x = x0 + double(i) * step;
				const double z = z0 + double(j) * step;
				const double dx = x - ox, dz = z - oz;
				if (dx * dx + dz * dz >= r2) continue;
				if (m.live_n > 0) {
					const int64_t ci = zsland::floori((x - lax) / zspeak::MASK_CELL);
					const int64_t cj = zsland::floori((z - laz) / zspeak::MASK_CELL);
					if (ci < 0 || cj < 0 || ci >= m.live_n || cj >= m.live_n || m.live[size_t(cj * m.live_n + ci)] == 0) continue;
				}
				const double qx = x - cx, qz = z - cz;
				const zspeak::V4 hm = m.h_rock(qx * fx + qz * fz, qx * sx + qz * sz, step);
				const double by = base - zspeak::SEA_Y;
				const double y = zsland::lerpf(zsland::maxf(by, double(hm.x)), double(hm.x), double(hm.y));
				const double lift = y - by;
				if (!i_out && !j_out) {
					relief[size_t(v)] = hm.w;
					const double a = alpha[size_t(v)];
					const double mw = zsland::maxf(a * (1.0 - zsland::smoothstep(0.5, 6.0, zsland::absf(lift))), double(hm.z));
					if (zsland::absf(lift) <= 0.0005 && zsland::absf(mw - a) <= 0.002) continue;
					alpha[size_t(v)] = float(mw);
					if (zsland::absf(lift) > 1.0) lifted[size_t(v)] = 1;
				} else if (zsland::absf(lift) <= 0.0005) continue;
				hs[size_t(k)] = float(y + zspeak::SEA_Y);
				mv[size_t(k)] = 1;
				any = true;
			}
		}
		if (!any) return;
		// Normals and colours wherever a height round them moved.
		std::vector<int32_t> redo;
		redo.reserve(size_t(n) * n);
		for (int j = 0; j < n; ++j) {
			for (int i = 0; i < n; ++i) {
				const int k = (j + 1) * w + i + 1;
				if (mv[k] + mv[k - 1] + mv[k + 1] + mv[k - w] + mv[k + w] > 0) redo.push_back(j * n + i);
			}
		}
		float *hp = heights.ptrw();
		Vector3 *vp = verts.ptrw();
		Vector3 *np = normals.ptrw();
		Color *cp = colours.ptrw();
		uint8_t *bp = carved.ptrw();
		float *rp = river.ptrw();
		for (int v = 0; v < n * n; ++v) cp[v].a = alpha[size_t(v)];
		const int count = int(redo.size());
		std::vector<float> ys(static_cast<size_t>(count)), ups(static_cast<size_t>(count)), ms(static_cast<size_t>(count));
		for (int t = 0; t < count; ++t) {
			const int v = redo[size_t(t)];
			const int i = v % n;
			const int j = v / n;
			const int k = (j + 1) * w + i + 1;
			const zsland::V3 normal = zsland::V3(double(hs[k - 1]) - double(hs[k + 1]), 2.0 * step, double(hs[k - w]) - double(hs[k + w])).normalized();
			np[v] = Vector3(normal.x, normal.y, normal.z);
			hp[v] = hs[k];
			vp[v] = Vector3(vp[v].x, hs[k], vp[v].z);
			ys[size_t(t)] = hs[k];
			ups[size_t(t)] = normal.y;
			ms[size_t(t)] = cp[v].a;
			if (mv[k] != 0) {
				bp[v * 4] = uint8_t(int64_t(zsland::clampf(-double(relief[v]), 0.0, 1.0) * 255.0));
				bp[v * 4 + 1] = uint8_t(int64_t(zsland::clampf(double(relief[v]), 0.0, 1.0) * 255.0));
			}
			if (lifted[v] != 0) {
				bp[v * 4 + 2] = 128;
				bp[v * 4 + 3] = 128;
				rp[v * 3] = 1000.0f;
				rp[v * 3 + 1] = 0.0f;
				rp[v * 3 + 2] = float(zspeak::SEA_Y - 100.0);
			}
		}
		ZenScapeLandField *native = Object::cast_to<ZenScapeLandField>(impl);
		if (native != nullptr) {
			const zsland::LandField &land = native->land();
			for (int t = 0; t < count; ++t) {
				const int v = redo[size_t(t)];
				const zsland::C4 c = land.colour(x0 + double(v % n) * step, z0 + double(v / n) * step, double(ys[size_t(t)]), double(ups[size_t(t)]), double(ms[size_t(t)]));
				cp[v] = Color(c.r, c.g, c.b, ms[size_t(t)]);
			}
		} else {
			PackedFloat64Array xa, za;
			PackedFloat32Array ya, ua, ma;
			xa.resize(count);
			za.resize(count);
			ya.resize(count);
			ua.resize(count);
			ma.resize(count);
			double *xp = xa.ptrw(), *zp = za.ptrw();
			float *yp = ya.ptrw(), *up = ua.ptrw(), *mp = ma.ptrw();
			for (int t = 0; t < count; ++t) {
				const int v = redo[size_t(t)];
				xp[t] = x0 + double(v % n) * step;
				zp[t] = z0 + double(v / n) * step;
				yp[t] = ys[size_t(t)];
				up[t] = ups[size_t(t)];
				mp[t] = ms[size_t(t)];
			}
			const PackedColorArray got = field->call("colours", xa, za, ya, ua, ma);
			const Color *gp = got.ptr();
			for (int t = 0; t < count; ++t) {
				Color c = gp[t];
				c.a = ms[size_t(t)];
				cp[redo[size_t(t)]] = c;
			}
		}
		// The skirt's copies of the edges.
		for (int e = 0; e < 4; ++e) {
			for (int t = 0; t < n; ++t) {
				const int from = e == 0 ? t : (e == 1 ? t * n + cells : (e == 2 ? cells * n + t : t * n));
				const int k = ((from / n) + 1) * w + (from % n) + 1;
				if (mv[k] + mv[k - 1] + mv[k + 1] + mv[k - w] + mv[k + w] == 0) continue;
				const int sv = n * n + e * n + t;
				vp[sv] = Vector3(vp[from].x - 0.0f, vp[from].y - float(skirt_drop), vp[from].z - 0.0f);
				np[sv] = np[from];
				cp[sv] = cp[from];
				for (int q = 0; q < 4; ++q) bp[sv * 4 + q] = bp[from * 4 + q];
				rp[sv * 3] = rp[from * 3];
				rp[sv * 3 + 1] = -rp[from * 3 + 1];
				rp[sv * 3 + 2] = rp[from * 3 + 2];
			}
		}
		made["heights"] = heights;
		made["verts"] = verts;
		made["normals"] = normals;
		made["colours"] = colours;
		made["carved"] = carved;
		made["river"] = river;
	}

	// PeakMassif `apply_grid`, line for line.
	void apply_grid(const Dictionary &p_got, double x0, double z0, double step, int64_t nx, int64_t nz, int64_t pad) {
		Dictionary got = p_got;
		PackedFloat32Array hs = got["heights"];
		PackedFloat32Array ms = got["meadows"];
		PackedFloat32Array rs = got["river"];
		float *hp = hs.ptrw();
		const bool has_m = !ms.is_empty(), has_r = !rs.is_empty();
		float *mp = has_m ? ms.ptrw() : nullptr;
		float *rp = has_r ? rs.ptrw() : nullptr;
		const double ox = m.o.x, oz = m.o.y, b = zspeak::BOUND;
		const auto clampi = [](int64_t v, int64_t lo, int64_t hi) { return v < lo ? lo : (v > hi ? hi : v); };
		const int64_t i0 = clampi(zsland::floori((ox - b - x0) / step) + pad, 0, nx - 1);
		const int64_t i1 = clampi(int64_t(std::ceil((ox + b - x0) / step)) + pad, 0, nx - 1);
		const int64_t j0 = clampi(zsland::floori((oz - b - z0) / step) + pad, 0, nz - 1);
		const int64_t j1 = clampi(int64_t(std::ceil((oz + b - z0) / step)) + pad, 0, nz - 1);
		for (int64_t j = j0; j <= j1; ++j) {
			for (int64_t i = i0; i <= i1; ++i) {
				const double x = x0 + double(i - pad) * step;
				const double z = z0 + double(j - pad) * step;
				if (!m.reaches(x, z)) continue;
				const int64_t k = j * nx + i;
				const float mw = has_m ? mp[k] : 0.0f;
				double lift = 0.0;
				const zsland::V2 y = m.apply(hp[k], mw, x, z, step, lift);
				hp[k] = y.x;
				if (has_m) mp[k] = y.y;
				if (zsland::absf(lift) > 1.0 && has_r) rp[k] = 1000.0f;
			}
		}
		got["heights"] = hs;
		if (has_m) got["meadows"] = ms;
		if (has_r) got["river"] = rs;
	}
};
