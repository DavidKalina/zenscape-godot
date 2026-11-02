#pragma once
// The Peak's serac mesher's heavy loops (scripts/endless/rocks/peak_serac.gd:
// `build`'s `_emit` and `_solid`, and `_carve`, a shard's box cut by its
// planes), the GDScript kept as the mirror. The shards
// are cut and placed in GDScript (the plan, once per cell); this turns their
// faces into the mesh's arrays, its three levels, the colliders' faces and
// each pillar's ring-and-sector solid. The face shades' jitter comes in
// pre-rolled (one per face, in order), so both paths read the same numbers.
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/basis.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <algorithm>
#include <cmath>
#include <limits>
#include <vector>

using namespace godot;

class ZenScapeSerac : public RefCounted {
	GDCLASS(ZenScapeSerac, RefCounted)

	static double clamp01(double x) { return std::min(std::max(x, 0.0), 1.0); }

	// `_cut`: a convex block's faces cut by a plane, the cut closed by a new face.
	static std::vector<std::vector<Vector3>> cut(const std::vector<std::vector<Vector3>> &polys, const Vector3 &n, double d) {
		std::vector<std::vector<Vector3>> out;
		std::vector<Vector3> cap;
		for (const std::vector<Vector3> &f : polys) {
			std::vector<Vector3> kept;
			const size_t m = f.size();
			for (size_t i = 0; i < m; ++i) {
				const Vector3 &a = f[i];
				const Vector3 &b = f[(i + 1) % m];
				const double da = (double)a.dot(n) - d;
				const double db = (double)b.dot(n) - d;
				if (da <= 0.0) kept.push_back(a);
				if ((da < 0.0 && db > 0.0) || (da > 0.0 && db < 0.0)) {
					const Vector3 x = a.lerp(b, (real_t)(da / (da - db)));
					kept.push_back(x);
					cap.push_back(x);
				}
			}
			if (kept.size() >= 3) out.push_back(std::move(kept));
		}
		if (cap.size() < 3) return out;
		Vector3 mid;
		for (const Vector3 &p : cap) mid += p;
		mid /= (real_t)cap.size();
		const Vector3 u = n.cross(std::fabs((double)n.y) < 0.9 ? Vector3(0, 1, 0) : Vector3(1, 0, 0)).normalized();
		const Vector3 w = n.cross(u);
		std::vector<std::pair<double, Vector3>> order;
		order.reserve(cap.size());
		for (const Vector3 &p : cap) order.emplace_back(std::atan2((double)(p - mid).dot(w), (double)(p - mid).dot(u)), p);
		std::sort(order.begin(), order.end(), [](const std::pair<double, Vector3> &a, const std::pair<double, Vector3> &b) { return a.first < b.first; });
		std::vector<Vector3> face;
		for (const auto &e : order)
			if (face.empty() || (double)e.second.distance_squared_to(face.back()) > 1e-5) face.push_back(e.second);
		if (face.size() >= 3) out.push_back(std::move(face));
		return out;
	}

	// `_emit`: one block's faces into the arrays.
	static void emit(std::vector<Vector3> &v, std::vector<Vector3> &n, std::vector<Color> &c, std::vector<int32_t> lv[3],
			const Array &polys, double tone, int level, double foot, double tall, const Vector3 &at,
			const float *jit, int64_t &ji, double soft) {
		const int64_t pc = polys.size();
		std::vector<PackedVector3Array> fs((size_t)pc);
		Vector3 mid;
		int64_t count = 0;
		for (int64_t k = 0; k < pc; ++k) {
			fs[k] = polys[k];
			const Vector3 *q = fs[k].ptr();
			for (int64_t i = 0; i < fs[k].size(); ++i) {
				mid += q[i];
				++count;
			}
		}
		mid /= (real_t)std::max<int64_t>(count, 1);
		const double span = std::max(tall * 0.42, 1.0);
		const real_t sf = (real_t)soft;
		for (int64_t k = 0; k < pc; ++k) {
			const PackedVector3Array &f = fs[k];
			const Vector3 *q = f.ptr();
			const int64_t m = f.size();
			const double jitter = jit[ji++];
			Vector3 nrm;
			Vector3 centre;
			for (int64_t i = 0; i < m; ++i) {
				const Vector3 &a = q[i];
				const Vector3 &r = q[(i + 1) % m];
				nrm += Vector3((real_t)(((double)a.y - r.y) * ((double)a.z + r.z)), (real_t)(((double)a.z - r.z) * ((double)a.x + r.x)),
						(real_t)(((double)a.x - r.x) * ((double)a.y + r.y)));
				centre += a;
			}
			centre /= (real_t)m;
			if ((double)nrm.length_squared() < 1e-8) continue;
			nrm = nrm.normalized();
			const bool flip = nrm.dot(centre - mid) < 0.0f;
			if (flip) nrm = -nrm;
			const double hollow = nrm.y < -0.12 ? 0.3 : 1.0;
			const double shade = clamp01(tone + jitter);
			const int32_t first = (int32_t)v.size();
			v.push_back(at + centre);
			n.push_back(nrm);
			c.push_back(Color((float)shade, (float)(clamp01(((double)centre.y - foot) / span) * hollow), 0.0f, 0.0f));
			for (int64_t i = 0; i < m; ++i) {
				v.push_back(at + q[i]);
				n.push_back((nrm + (q[i] - centre).normalized() * sf).normalized());
				const double open = clamp01(((double)q[i].y - foot) / span) * hollow;
				c.push_back(Color((float)shade, (float)open, 1.0f, 0.0f));
			}
			for (int l = 0; l <= level && l < 3; ++l) {
				for (int64_t i = 0; i < m; ++i) {
					const int32_t i0 = first + 1 + (int32_t)i;
					const int32_t i1 = first + 1 + (int32_t)((i + 1) % m);
					lv[l].push_back(first);
					lv[l].push_back(flip ? i0 : i1);
					lv[l].push_back(flip ? i1 : i0);
				}
			}
		}
	}

	// `_solid`: the outline of every block at each ring's height, its sectors' most.
	static Dictionary solid(const Dictionary &p, int sectors, double ring_m, double sample) {
		const Vector3 at = p["at"];
		const Array blocks = p["blocks"];
		std::vector<PackedVector3Array> fs;
		for (int64_t b = 0; b < blocks.size(); ++b) {
			const Dictionary bd = blocks[b];
			const Array polys = bd["polys"];
			for (int64_t k = 0; k < polys.size(); ++k) fs.push_back(polys[k]);
		}
		double lo = std::numeric_limits<double>::infinity(), hi = -lo;
		for (const PackedVector3Array &f : fs) {
			const Vector3 *q = f.ptr();
			for (int64_t i = 0; i < f.size(); ++i) {
				lo = std::min(lo, (double)q[i].y);
				hi = std::max(hi, (double)q[i].y);
			}
		}
		const int rings = std::max(4, (int)std::ceil((hi - lo) / ring_m));
		const double dy = (hi - lo) / rings;
		std::vector<std::vector<Vector2>> segs((size_t)rings + 1);
		for (const PackedVector3Array &f : fs) {
			const Vector3 *q = f.ptr();
			const int64_t m = f.size();
			double y0 = std::numeric_limits<double>::infinity(), y1 = -y0;
			for (int64_t i = 0; i < m; ++i) {
				y0 = std::min(y0, (double)q[i].y);
				y1 = std::max(y1, (double)q[i].y);
			}
			const int k0 = std::clamp((int)std::ceil((y0 - lo) / dy), 0, rings);
			const int k1 = std::clamp((int)std::floor((y1 - lo) / dy), 0, rings);
			for (int k = k0; k <= k1; ++k) {
				const double y = lo + k * dy;
				std::vector<Vector2> &ring = segs[k];
				int got = 0;
				Vector2 first;
				for (int64_t i = 0; i < m; ++i) {
					const Vector3 &a = q[i];
					const Vector3 &b2 = q[(i + 1) % m];
					if (((double)a.y <= y) == ((double)b2.y <= y)) continue;
					const Vector3 x = a.lerp(b2, (real_t)((y - a.y) / ((double)b2.y - a.y)));
					const Vector2 pt(x.x, x.z);
					if (got == 0) first = pt;
					else {
						ring.push_back(first);
						ring.push_back(pt);
					}
					++got;
				}
			}
		}
		PackedVector2Array centres;
		centres.resize(rings + 1);
		PackedFloat32Array rad;
		rad.resize((int64_t)(rings + 1) * sectors);
		float *rp = rad.ptrw();
		for (int64_t i = 0; i < rad.size(); ++i) rp[i] = 0.0f;
		Vector2 last;
		const Vector2 base(at.x, at.z);
		for (int k = 0; k <= rings; ++k) {
			const std::vector<Vector2> &ring = segs[k];
			Vector2 mean;
			for (const Vector2 &e : ring) mean += e;
			mean = ring.empty() ? last : mean / (real_t)ring.size();
			last = mean;
			centres.set(k, base + mean);
			for (size_t i = 0; i + 1 < ring.size(); i += 2) {
				const Vector2 a = ring[i] - mean;
				const Vector2 b2 = ring[i + 1] - mean;
				const int steps = std::clamp((int)std::ceil((double)a.distance_to(b2) / sample), 1, 40);
				for (int j = 0; j <= steps; ++j) {
					const Vector2 e = a.lerp(b2, (real_t)((double)j / steps));
					const int s = std::clamp((int)std::floor(((double)e.angle() + 3.141592653589793) / 6.283185307179586 * sectors), 0, sectors - 1);
					float &r = rp[k * sectors + s];
					r = (float)std::max((double)r, (double)e.length());
				}
			}
		}
		Vector2 mid;
		for (int i = 0; i <= rings; ++i) mid += centres[i];
		mid /= (real_t)(rings + 1);
		double reach = 0.0;
		for (int i = 0; i <= rings; ++i)
			for (int k = 0; k < sectors; ++k) reach = std::max(reach, (double)rp[i * sectors + k] + (double)centres[i].distance_to(mid));
		Dictionary out;
		out["c"] = centres;
		out["r"] = rad;
		out["y0"] = (double)at.y + lo;
		out["dy"] = dy;
		out["rings"] = rings + 1;
		out["top"] = (double)at.y + hi;
		out["mid"] = mid;
		out["reach"] = reach;
		out["size"] = (double)p["r"];
		out["base"] = (double)at.y;
		return out;
	}

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("build", "pillars", "jitter", "sectors", "ring", "sample", "soft"), &ZenScapeSerac::build);
		ClassDB::bind_method(D_METHOD("carve", "half", "planes", "turn", "at"), &ZenScapeSerac::carve);
	}

public:
	// `_carve`: the box of half-widths `half` cut by each plane ([nx, ny, nz, d]
	// in turn, kept where p.n <= d), turned and put at `at`: [face...].
	Array carve(const Vector3 &half, const PackedFloat64Array &planes, const Basis &turn, const Vector3 &at) {
		const Vector3 &h = half;
		const Vector3 c[8] = {Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z),
			Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)};
		static const int quads[6][4] = {{0, 1, 2, 3}, {7, 6, 5, 4}, {0, 4, 5, 1}, {1, 5, 6, 2}, {2, 6, 7, 3}, {3, 7, 4, 0}};
		std::vector<std::vector<Vector3>> polys;
		for (const auto &q : quads) polys.push_back({c[q[0]], c[q[1]], c[q[2]], c[q[3]]});
		const double *pl = planes.ptr();
		for (int64_t i = 0; i + 3 < planes.size(); i += 4)
			polys = cut(polys, Vector3((real_t)pl[i], (real_t)pl[i + 1], (real_t)pl[i + 2]), pl[i + 3]);
		Array out;
		for (const std::vector<Vector3> &f : polys) {
			PackedVector3Array pf;
			pf.resize((int64_t)f.size());
			Vector3 *w = pf.ptrw();
			for (size_t j = 0; j < f.size(); ++j) w[j] = turn.xform(f[j]) + at;
			out.append(pf);
		}
		return out;
	}

	// {v, n, c, l0, l1, l2, faces (a level-1 trimesh a pillar), solid (one a pillar)}.
	Dictionary build(const Array &pillars, const PackedFloat32Array &jitter, int64_t sectors, double ring, double sample, double soft) {
		std::vector<Vector3> v, n;
		std::vector<Color> c;
		std::vector<int32_t> lv[3];
		std::vector<size_t> cuts{0};
		Array solids;
		const float *jit = jitter.ptr();
		int64_t ji = 0;
		for (int64_t pi = 0; pi < pillars.size(); ++pi) {
			const Dictionary p = pillars[pi];
			const Vector3 at = p["at"];
			const double foot = p["foot"], tall = p["tall"];
			const Array blocks = p["blocks"];
			for (int64_t b = 0; b < blocks.size(); ++b) {
				const Dictionary bd = blocks[b];
				const Array polys = bd["polys"];
				if (ji + polys.size() > jitter.size()) return Dictionary();
				emit(v, n, c, lv, polys, (double)bd["tone"], (int)bd["level"], foot, tall, at, jit, ji, soft);
			}
			cuts.push_back(lv[1].size());
			solids.append(solid(p, (int)sectors, ring, sample));
		}
		PackedVector3Array pv, pn;
		pv.resize((int64_t)v.size());
		pn.resize((int64_t)n.size());
		std::copy(v.begin(), v.end(), pv.ptrw());
		std::copy(n.begin(), n.end(), pn.ptrw());
		PackedColorArray pc;
		pc.resize((int64_t)c.size());
		std::copy(c.begin(), c.end(), pc.ptrw());
		Dictionary out;
		out["v"] = pv;
		out["n"] = pn;
		out["c"] = pc;
		for (int l = 0; l < 3; ++l) {
			PackedInt32Array idx;
			idx.resize((int64_t)lv[l].size());
			std::copy(lv[l].begin(), lv[l].end(), idx.ptrw());
			out[String("l") + String::num_int64(l)] = idx;
		}
		Array faces;
		for (size_t k = 0; k + 1 < cuts.size(); ++k) {
			PackedVector3Array f;
			f.resize((int64_t)(cuts[k + 1] - cuts[k]));
			Vector3 *fp = f.ptrw();
			for (size_t i = 0; i < cuts[k + 1] - cuts[k]; ++i) fp[i] = v[(size_t)lv[1][cuts[k] + i]];
			faces.append(f);
		}
		out["faces"] = faces;
		out["solid"] = solids;
		return out;
	}
};
