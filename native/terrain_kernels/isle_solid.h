// RuinKit Build `solid` (scripts/ruin_kit.gd), op for op, for the classic and
// eroded stone looks: one block's weathering (`_wear`), its corners
// (`_unique`, `_polys`), its dialled wear (`_dial`), its faces' colours and the
// random numbers they draw (`_shade`), its tops, its solid, its hull
// (`thickness`). It returns what `solid` appends to the Build (see
// ZenScapeIsleKernels::ruin_solid) and the random state after; GDScript appends
// them. The clean looks (ashlar, mass, basalt) stay in GDScript.
#pragma once

#include "isle_math.h"
#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace zs {

using namespace godot;

inline bool approx32(float a, float b) {
	if (a == b) return true;
	float tolerance = CMP_EPSILON * std::fabs(a);
	if (tolerance < CMP_EPSILON) tolerance = CMP_EPSILON;
	return std::fabs(a - b) < tolerance;
}
inline bool plane_approx(const Pl &a, const Pl &b) {
	return approx32(a.n.x, b.n.x) && approx32(a.n.y, b.n.y) && approx32(a.n.z, b.n.z) && approx32(a.d, b.d);
}

inline Plane gd(const Pl &p) { return Plane(p.n.gd(), p.d); }

struct SolidConsts {
	bool ruled = false, eroded = false;
	Dictionary erode;
	V2 wobble, chips, chip, chunk;
	double chunk_odds = 0.3, facets = 0.12, edge_mix = 0.2, streak = 0.32, streak_scale = 1.3, damp = 0.7, damp_rise = 1.1, under = 0.72;
	double lichen_odds = 0.05, moss_up = 0.5, moss_scale = 0.8, moss_age = 0.14, moss_cover = 0.45, hull_thin = 0.06;
	Col edge_linear, moss, moss_light, moss_linear;
	std::vector<Col> lichen_linear;

	void read(const Dictionary &c) {
		ruled = c["ruled"];
		eroded = c["eroded"];
		erode = c["erode"];
		auto v2 = [&](const char *key) { Vector2 v = c[key]; return V2(v.x, v.y); };
		wobble = v2("wobble");
		chips = v2("chips");
		chip = v2("chip");
		chunk = v2("chunk");
		chunk_odds = c["chunk_odds"];
		facets = c["facets"];
		edge_mix = c["edge_mix"];
		streak = c["streak"];
		streak_scale = c["streak_scale"];
		damp = c["damp"];
		damp_rise = c["damp_rise"];
		under = c["under"];
		lichen_odds = c["lichen_odds"];
		moss_up = c["moss_up"];
		moss_scale = c["moss_scale"];
		moss_age = c["moss_age"];
		moss_cover = c["moss_cover"];
		hull_thin = c["hull_thin"];
		edge_linear = Col(Color(c["edge_linear"]));
		moss = Col(Color(c["moss"]));
		moss_light = Col(Color(c["moss_light"]));
		moss_linear = Col(Color(c["moss_linear"]));
		Array l = c["lichen_linear"];
		for (int i = 0; i < l.size(); i++) lichen_linear.push_back(Col(Color(l[i])));
	}
	double erode_share(const String &key) const { return erode[key]; }
};

struct SolidBuild {
	const SolidConsts &k;
	Object *noise;
	const Dictionary &bevels;
	Rng rng;
	double weathered = 0, age = 0, ground = -INFINITY;
	bool lean = false;
	// The kept chips and chunk of the last `wear` (eroded looks): kind (0 chip,
	// 1 chunk) and its numbers.
	struct Worn {
		int kind;
		double a, c, d;
		bool b;
	};
	std::vector<Worn> worn_cuts;
	std::vector<V3> raw, pts;
	Polys polys;

	SolidBuild(const SolidConsts &consts, Object *p_noise, const Dictionary &p_bevels) : k(consts), noise(p_noise), bevels(p_bevels) {}

	float noise_2d(double x, double y) const {
		static const StringName name("get_noise_2d");
		return float(double(noise->call(name, float(x), float(y))));
	}
	float noise_3dv(const V3 &v) const {
		static const StringName name("get_noise_3dv");
		return float(double(noise->call(name, v.gd())));
	}

	void hull_points(const std::vector<Pl> &planes, std::vector<V3> &out) {
		convex_points(planes.data(), int(planes.size()), raw);
		unique(raw, out);
	}

	// Build `_wear`.
	std::vector<Pl> wear(const std::vector<Pl> &planes, double rough, int keep) {
		double a = clampf(age * rough, 0.0, 1.0);
		double w = clampf(weathered * rough, 0.0, 1.0);
		std::vector<Pl> out;
		double wobble = double(k.wobble.x) + (double(k.wobble.y) - double(k.wobble.x)) * w;
		worn_cuts.clear();
		for (int i = 0; i < int(planes.size()); i++) {
			const Pl &p = planes[i];
			if (i == keep || (lean && double(p.n.y) > 0.99)) {
				out.push_back(p);
				continue;
			}
			float tx = rng.randf_range(-1, 1);
			float ty = rng.randf_range(-1, 1);
			float tz = rng.randf_range(-1, 1);
			V3 tilt = mul(V3(tx, ty, tz), wobble);
			V3 n = ((p.n + tilt) - p.n * p.n.dot(tilt)).normalized();
			double dd = double(n.dot(p.n * p.d)) - double(rng.randf()) * 0.012 * a;
			out.push_back(Pl(n, float(dd)));
		}
		std::vector<V3> points;
		hull_points(out, points);
		if (points.size() < 4) return out;
		V3 centre;
		for (const V3 &q : points) centre += q;
		centre = divi(centre, int64_t(points.size()));
		AB box(points[0], V3());
		for (const V3 &q : points) expand(box, q);
		double least = minf(box.size.x, minf(box.size.y, box.size.z)) * 0.5;
		int64_t chip_count = int64_t(std::round((double(k.chips.x) * rough + double(k.chips.y) * w) * double(rng.randf_range(0.3, 1.0)) * (lean ? 0.15 : 1.0)));
		for (int64_t c = 0; c < chip_count; c++) {
			V3 corner = points[size_t(rng.randi() % int64_t(points.size()))];
			if (keep >= 0 && absf(planes[keep].distance_to(corner)) < 0.01) continue;
			float jx = rng.randf_range(-0.35, 0.35);
			float jy = rng.randf_range(-0.35, 0.35);
			float jz = rng.randf_range(-0.35, 0.35);
			V3 n = ((corner - centre).normalized() + V3(jx, jy, jz)).normalized();
			double reach = -INFINITY;
			for (const V3 &q : points) reach = maxf(reach, n.dot(q));
			double size = rng.randf_range(k.chip.x, k.chip.y);
			double bite = least * size * (0.35 + 0.65 * a);
			out.push_back(Pl(n, float(reach - bite)));
			if (k.eroded) worn_cuts.push_back(Worn{ 0, (size - double(k.chip.x)) / (double(k.chip.y) - double(k.chip.x)), bite, least * 0.75, corner.y >= centre.y });
		}
		double odds = (k.chunk_odds * w + 0.05 * minf(rough, 1.0)) * (lean ? 0.5 : 1.0);
		double roll = rng.randf();
		if (roll < odds) {
			float nx = rng.randf_range(-1, 1);
			float ny = rng.randf_range(0.0, 1.0);
			float nz = rng.randf_range(-1, 1);
			V3 n = V3(nx, ny, nz).normalized();
			double reach = -INFINITY, low = INFINITY;
			for (const V3 &q : points) {
				reach = maxf(reach, n.dot(q));
				low = minf(low, n.dot(q));
			}
			double share = rng.randf_range(k.chunk.x, k.chunk.y);
			out.push_back(Pl(n, float(reach - (reach - low) * share)));
			if (k.eroded) worn_cuts.push_back(Worn{ 1, roll / odds, share, reach - low, false });
		}
		return out;
	}

	static void expand(AB &box, const V3 &q) {
		V3 begin = box.position, end = box.position + box.size;
		if (q.x < begin.x) begin.x = q.x;
		if (q.y < begin.y) begin.y = q.y;
		if (q.z < begin.z) begin.z = q.z;
		if (q.x > end.x) end.x = q.x;
		if (q.y > end.y) end.y = q.y;
		if (q.z > end.z) end.z = q.z;
		box.position = begin;
		box.size = end - begin;
	}
	static AB grow(const AB &b, float by) {
		AB r = b;
		r.position.x -= by;
		r.position.y -= by;
		r.position.z -= by;
		r.size.x += 2.0f * by;
		r.size.y += 2.0f * by;
		r.size.z += 2.0f * by;
		return r;
	}
	static float longest(const AB &b) {
		float m = b.size.x;
		if (b.size.y > m) m = b.size.y;
		if (b.size.z > m) m = b.size.z;
		return m;
	}

	// Build `_shade` (the classic's face colour, and its random numbers).
	Col shade(const V3 &at, const V3 &normal, const Col &base, bool worn, bool want_colour) {
		Col c = base * float(1.0 + double(rng.randf_range(-0.5, 0.5)) * k.facets * 2.0);
		if (worn) {
			float t = float(k.edge_mix * (0.55 + 0.45 * age) * double(rng.randf_range(0.6, 1.2)));
			c = c.lerp(k.edge_linear, t);
		}
		if (want_colour) {
			if (absf(normal.y) < 0.6) {
				double band = noise_2d(double(at.x) * k.streak_scale * 1.7 + double(at.z) * 0.31, double(at.z) * k.streak_scale * 1.7 - double(at.x) * 0.29);
				c *= float(1.0 - k.streak * smoothstep(-0.05, 0.45, band) * (0.45 + 0.55 * age));
			}
			c *= float(lerpf(k.damp, 1.0, smoothstep(0.0, k.damp_rise, at.y)));
			if (double(normal.y) < -0.3) c *= float(k.under);
		}
		if (double(rng.randf()) < k.lichen_odds * (0.6 + age) && double(normal.y) > -0.2) {
			int64_t pick = rng.randi() % int64_t(k.lichen_linear.size());
			float t = rng.randf_range(0.25, 0.5);
			c = c.lerp(k.lichen_linear[size_t(pick)], t);
		}
		double patch = double(noise_3dv(mul(at, k.moss_scale))) * 0.5 + 0.5;
		if (double(normal.y) > k.moss_up && patch < (k.moss_age + weathered * k.moss_cover) * double(normal.y)) {
			Col m = k.moss.lerp(k.moss_light, float(double(rng.randf()) * 0.6));
			return want_colour ? m.srgb_to_linear() * float(0.9 + 0.15 * double(normal.y)) : Col();
		}
		if (!want_colour) return Col();
		if (absf(normal.y) < 0.5 && patch < weathered * 0.3 && double(at.y) < 2.5) c = c.lerp(k.moss_linear, float(0.3 * weathered));
		return Col(c.r, c.g, c.b, 1.0f);
	}

	// Build `_dial`: [plane, kind] each.
	void dial(const std::vector<Pl> &source, const std::vector<Pl> &cut, bool wore, int count, std::vector<Pl> &out_planes, std::vector<uint8_t> &out_kinds) {
		for (int i = 0; i < int(cut.size()); i++) {
			const Pl &p = cut[i];
			if (i < int(source.size())) {
				const Pl &s = source[i];
				V3 n = p.n;
				double d = p.d;
				if (wore && !plane_approx(p, s)) {
					double share = k.erode_share(double(s.n.y) > 0.85 ? "wobble_top" : "wobble");
					double off = double(p.n.dot(s.n * s.d)) - double(p.d);
					n = s.n.lerp(p.n, float(share)).normalized();
					d = double(n.dot(s.n * s.d)) - off * share;
				}
				Variant info = i < count ? bevels.get(gd(s), Variant()) : Variant();
				if (info.get_type() == Variant::ARRAY) {
					Array arris = info;
					if (double(arris[1]) < 1.0 - k.erode_share(arris[0])) continue;
					d -= minf(double(arris[2]) * k.erode_share("arris"), double(arris[3])) - double(arris[2]);
					out_planes.push_back(Pl(n, float(d)));
					out_kinds.push_back(1);
				} else {
					out_planes.push_back(Pl(n, float(d)));
					out_kinds.push_back(0);
				}
			} else if (wore && i - int(source.size()) < int(worn_cuts.size())) {
				const Worn &w = worn_cuts[i - source.size()];
				if (w.kind == 0) {
					if (w.a < 1.0 - k.erode_share(w.b ? "chip" : "chip_low")) continue;
					double more = minf(w.c * k.erode_share("chip_depth"), w.d) - w.c;
					out_planes.push_back(Pl(p.n, float(double(p.d) - maxf(more, 0.0))));
					out_kinds.push_back(2);
				} else {
					if (w.a >= k.erode_share("chunk")) continue;
					double more = (minf(w.c * k.erode_share("chunk_depth"), 0.5) - w.c) * w.d;
					out_planes.push_back(Pl(p.n, float(double(p.d) - maxf(more, 0.0))));
					out_kinds.push_back(3);
				}
			} else {
				out_planes.push_back(p);
				out_kinds.push_back(0);
			}
		}
	}

	// Build `thickness`.
	static double thickness(const std::vector<V3> &points) {
		if (points.size() < 4) return 0.0;
		V3 mean;
		for (const V3 &p : points) mean += p;
		mean = divi(mean, int64_t(points.size()));
		Bs c = Bs::columns(V3(), V3(), V3());
		for (const V3 &p : points) {
			V3 d = p - mean;
			c.set_column(0, c.column(0) + mul(d, d.x));
			c.set_column(1, c.column(1) + mul(d, d.y));
			c.set_column(2, c.column(2) + mul(d, d.z));
		}
		std::vector<V3> axes;
		const Bs &m = c;
		for (int kk = 0; kk < 2; kk++) {
			V3 v = kk == 0 ? V3(0.577f, 0.577f, 0.577f) : V3(-0.41f, 0.82f, -0.41f);
			if (!axes.empty()) v = (v - axes[0] * axes[0].dot(v));
			for (int i = 0; i < 40; i++) {
				V3 w = m.xform(v);
				if (!axes.empty()) w -= axes[0] * axes[0].dot(w);
				if (double(w.length_squared()) < 1e-20) break;
				v = w.normalized();
			}
			if (double(v.length_squared()) < 1e-12) return 0.0;
			axes.push_back(v.normalized());
		}
		V3 least = axes[0].cross(axes[1]);
		if (double(least.length_squared()) < 1e-12) return 0.0;
		least = least.normalized();
		double low = INFINITY, high = -INFINITY;
		for (const V3 &p : points) {
			low = minf(low, least.dot(p));
			high = maxf(high, least.dot(p));
		}
		return high - low;
	}
};

inline Array planes_array(const std::vector<Pl> &planes, const Tf *xf) {
	TypedArray<Plane> out;
	out.resize(int64_t(planes.size()));
	for (size_t i = 0; i < planes.size(); i++) out[int64_t(i)] = gd(xf ? xf->xform(planes[i]) : planes[i]);
	return out;
}

inline PackedVector3Array points_array(const V3 *pts, int n, const Tf &xf) {
	PackedVector3Array out;
	out.resize(n);
	Vector3 *w = out.ptrw();
	for (int i = 0; i < n; i++) w[i] = xf.xform(pts[i]).gd();
	return out;
}

} // namespace zs
