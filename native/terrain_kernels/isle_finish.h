// RuinKit Build `finish`'s number crunching (scripts/ruin_kit.gd,
// scripts/ruin_growth.gd, scripts/ruin_stone_style.gd), op for op: the ivy,
// the wall-head fringes, the vine curtains, the moss cushions, then every
// pending face drawn (an eroded look's blocks worn where they are open), into
// the stone's and the growth's surface arrays. Its input is the Build's state
// as GDScript holds it (read here, never written), its output packed arrays
// and the random state after. See isle_math.h for the rules every line keeps.
#pragma once

#include "isle_math.h"
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <unordered_map>

namespace zs {

using namespace godot;

// RuinGrowth attrs: anchor y, span, out x, out z, free, flutter, phase, up, along.
struct Attrs {
	float a[9] = { 0 };
	bool none = true;
};

inline Attrs attrs(double anchor_y, double span, const V3 &out, double free, double flutter, double phase, bool upright = false, double along = -1.0) {
	Attrs r;
	r.none = false;
	r.a[0] = float(anchor_y);
	r.a[1] = float(span);
	r.a[2] = out.x;
	r.a[3] = out.z;
	r.a[4] = float(free);
	r.a[5] = float(flutter);
	r.a[6] = float(phase);
	r.a[7] = upright ? 1.0f : 0.0f;
	r.a[8] = float(along);
	return r;
}

// One pending face (`pending`): corners, normal, colour, occluder, growth attrs
// (none: stone); or an eroded look's block.
struct Pending {
	bool erode = false;
	int first = 0, count = 0; // corners, or planes for an eroded block
	V3 normal;
	Col colour;
	int occluder = -1;
	Attrs grow;
	// an eroded block
	V3 centre;
	double part = 1.0;
	int kinds = 0; // into Finish::kinds
};

struct Solid {
	AB box;
	int first = 0, count = 0; // planes
};

struct Top {
	int first = 0, count = 0;
	double area = 0;
};

struct Hang {
	V3 at;
	double length = 0;
	bool free = true;
	double from = -1.0;
};

struct GridKey {
	int64_t x, y, z;
	bool operator==(const GridKey &o) const { return x == o.x && y == o.y && z == o.z; }
};
struct GridHash {
	size_t operator()(const GridKey &k) const {
		uint64_t h = uint64_t(k.x) * 73856093ULL ^ uint64_t(k.y) * 19349663ULL ^ uint64_t(k.z) * 83492791ULL;
		return size_t(h ^ (h >> 29));
	}
};

struct Finish {
	// --- The Build's state ---
	Rng rng;
	double weathered = 0, age = 0, detail = 1.0, ground = -INFINITY;
	bool lean = false, vines = true, cull = false;
	Col clean_stone;
	std::vector<Pl> planes; // the solids' (world) planes, then the eroded blocks'
	std::vector<Solid> solids;
	std::vector<V3> top_points;
	std::vector<Top> tops;
	std::vector<Hang> hangs;
	std::vector<AB> clear;
	std::vector<V3> corners; // pending faces' corners
	std::vector<uint8_t> kinds;
	std::vector<Pending> pending;
	Attrs grow;

	// --- The kit's constants (read from the scripts) ---
	std::vector<Col> ivy_linear, vine_linear;
	V2 ivy_leaf, ivy_strands, ivy_length, cushion, leaf_size;
	int64_t ivy_most = 46, ivy_lean = 8;
	Col moss, moss_light, stem_colour;
	double cull_off = 0.03, cell_cull = 2.0;
	double leaf_width = 0.62, stem = 0.013, node_step = 0.085, stem_step = 0.3, lean_scale = 1.6, tendril = 0.2;
	V2 spacing, fringe_length;
	int64_t strands_most = 11, strands_lean = 5, fringes_most = 6, fringes_lean = 2;
	double length_gain = 1.8, longest = 6.0, fringe_rate = 0.35;
	// The stone look (RuinStoneStyle LOOKS[current]).
	double look_band = 0, look_band_tone = 0, look_foot = 0, look_rise = 1, look_facets = 0, look_top = 0, look_tip = 0.3;
	double look_under = 1, look_recess = 1, look_worn = 0;
	double stem_cos[4], stem_sin[4];

	// --- What it draws ---
	PackedVector3Array sv, sn;
	PackedColorArray sc;
	PackedVector3Array gv, gn;
	PackedColorArray gc;
	PackedVector2Array guv, guv2;
	PackedFloat32Array gcu;

	// scratch
	std::vector<Pl> cut;
	std::vector<V3> raw, points;
	Polys polys;
	std::unordered_map<GridKey, std::vector<int>, GridHash> grid;
	bool gridded = false;

	// The Build's `terrain` (the ground under the piece, in its frame), or
	// none (flat, y 0): Build `floor_at`.
	Callable terrain;
	double floor_at(double x, double z) const { return terrain.is_valid() ? double(terrain.call(x, z)) : 0.0; }

	// --- Reading GDScript's state ---------------------------------------------------
	static bool is_string(const Variant &v) { return v.get_type() == Variant::STRING || v.get_type() == Variant::STRING_NAME; }

	void read_attrs(const Variant &v, Attrs &out) {
		out = Attrs();
		if (v.get_type() != Variant::PACKED_FLOAT32_ARRAY) return;
		PackedFloat32Array a = v;
		if (a.is_empty()) return;
		out.none = false;
		for (int i = 0; i < 9 && i < a.size(); i++) out.a[i] = a[i];
	}

	// False if it holds what this kernel does not draw (the caller's GDScript does).
	bool read(const Dictionary &in) {
		int64_t state = in["state"];
		rng.state = uint64_t(state);
		weathered = in["weathered"];
		age = in["age"];
		detail = in["detail"];
		ground = in["ground"];
		terrain = in.get("terrain", Callable());
		lean = in["lean"];
		vines = in["vines"];
		cull = in["cull"];
		clean_stone = Col(Color(in["clean_stone"]));
		Array ivy = in["ivy_linear"];
		for (int i = 0; i < ivy.size(); i++) ivy_linear.push_back(Col(Color(ivy[i])));
		Array vine = in["vine_linear"];
		for (int i = 0; i < vine.size(); i++) vine_linear.push_back(Col(Color(vine[i])));
		auto v2 = [&](const char *key) { Vector2 v = in[key]; return V2(v.x, v.y); };
		ivy_leaf = v2("ivy_leaf");
		ivy_strands = v2("ivy_strands");
		ivy_length = v2("ivy_length");
		cushion = v2("cushion");
		leaf_size = v2("leaf");
		spacing = v2("spacing");
		fringe_length = v2("fringe_length");
		ivy_most = in["ivy_most"];
		ivy_lean = in["ivy_lean"];
		moss = Col(Color(in["moss"]));
		moss_light = Col(Color(in["moss_light"]));
		stem_colour = Col(Color(in["stem_colour"]));
		cull_off = in["cull_off"];
		cell_cull = in["cell_cull"];
		leaf_width = in["leaf_width"];
		stem = in["stem"];
		node_step = in["node_step"];
		stem_step = in["stem_step"];
		lean_scale = in["lean_scale"];
		tendril = in["tendril"];
		strands_most = in["strands"];
		strands_lean = in["strands_lean"];
		fringes_most = in["fringes"];
		fringes_lean = in["fringes_lean"];
		length_gain = in["length_gain"];
		longest = in["longest"];
		fringe_rate = in["fringe_rate"];
		Dictionary look = in["look"];
		look_band = look.get("band", 0.0);
		look_band_tone = look.get("band_tone", 0.0);
		look_foot = look.get("foot", 0.0);
		look_rise = look.get("rise", 1.0);
		look_facets = look.get("facets", 0.0);
		look_top = look.get("top", 0.0);
		look_tip = look.get("tip", 0.3);
		look_under = look.get("under", 1.0);
		look_recess = look.get("recess", 1.0);
		look_worn = look.get("worn", 0.0);
		bool look_ok = double(look.get("block", 0.0)) <= 0.0 && !bool(look.get("facet_hash", false));
		for (int k = 0; k < 4; k++) {
			stem_cos[k] = zs::cos(TAU * k / 3.0);
			stem_sin[k] = zs::sin(TAU * k / 3.0);
		}

		Array s = in["solids"];
		solids.reserve(s.size());
		for (int i = 0; i < s.size(); i++) {
			Array e = s[i];
			Solid solid;
			solid.box = AB(AABB(e[0]));
			Array ps = e[1];
			solid.first = int(planes.size());
			solid.count = int(ps.size());
			for (int k = 0; k < ps.size(); k++) planes.push_back(Pl(Plane(ps[k])));
			solids.push_back(solid);
		}
		Array t = in["tops"];
		for (int i = 0; i < t.size(); i++) {
			Array e = t[i];
			PackedVector3Array poly = e[0];
			Top top;
			top.first = int(top_points.size());
			top.count = int(poly.size());
			for (int k = 0; k < poly.size(); k++) top_points.push_back(V3(poly[k]));
			top.area = e[1];
			tops.push_back(top);
		}
		Array h = in["hangs"];
		for (int i = 0; i < h.size(); i++) {
			Array e = h[i];
			Hang hang;
			hang.at = V3(Vector3(e[0]));
			hang.length = e[1];
			hang.free = e[2];
			hang.from = e[3];
			hangs.push_back(hang);
		}
		Array c = in["clear"];
		for (int i = 0; i < c.size(); i++) clear.push_back(AB(AABB(c[i])));
		Array p = in["pending"];
		pending.reserve(p.size() * 4);
		for (int i = 0; i < p.size(); i++) {
			Array e = p[i];
			Variant head = e[0];
			Pending f;
			if (is_string(head)) {
				if (String(head) != "erode" || !look_ok) return false;
				f.erode = true;
				Array ps = e[1];
				f.first = int(planes.size());
				f.count = int(ps.size());
				for (int k = 0; k < ps.size(); k++) planes.push_back(Pl(Plane(ps[k])));
				f.centre = V3(Vector3(e[2]));
				f.part = e[3];
				f.occluder = int(int64_t(e[4]));
				PackedByteArray ks = e[6];
				f.kinds = int(kinds.size());
				for (int k = 0; k < ks.size(); k++) kinds.push_back(ks[k]);
			} else {
				PackedVector3Array cs = head;
				f.first = int(corners.size());
				f.count = int(cs.size());
				for (int k = 0; k < cs.size(); k++) corners.push_back(V3(cs[k]));
				f.normal = V3(Vector3(e[1]));
				f.colour = Col(Color(e[2]));
				f.occluder = int(int64_t(e[3]));
				read_attrs(e[5], f.grow);
			}
			pending.push_back(f);
		}
		return true;
	}

	// --- The stone it reads ------------------------------------------------------------
	// Build `_inside`.
	bool inside(const V3 &p) const {
		for (const Solid &s : solids) {
			if (!s.box.has_point(p)) continue;
			bool in = true;
			for (int k = 0; k < s.count; k++) {
				if (planes[s.first + k].distance_to(p) > 0.0f) {
					in = false;
					break;
				}
			}
			if (in) return true;
		}
		return false;
	}

	// Build `_gap`.
	double gap(const V3 &p, const V3 &dir, double most) const {
		double t = 0.0;
		while (t < most) {
			if (inside(p + mul(dir, t))) return t;
			t += 0.04;
		}
		return most;
	}

	bool kept_clear(const V3 &p) const {
		for (const AB &b : clear)
			if (b.has_point(p)) return true;
		return false;
	}

	// --- Faces --------------------------------------------------------------------
	void add_face(const V3 *cs, int n, const V3 &normal, const Col &colour, int occluder, const Attrs &g) {
		Pending f;
		f.first = int(corners.size());
		f.count = n;
		for (int k = 0; k < n; k++) corners.push_back(cs[k]);
		f.normal = normal;
		f.colour = colour;
		f.occluder = occluder;
		f.grow = g;
		pending.push_back(f);
	}

	// Build `growth_face`.
	void growth_face(std::initializer_list<V3> cs, const V3 &normal, const Col &colour) {
		std::vector<V3> c(cs);
		add_face(c.data(), int(c.size()), normal, colour, -1, grow);
	}

	// Build `solid` for what grows on the stone (never solid, never worn, not
	// growable): `planes` cut at `pose`, its faces in `colour` each a step apart.
	void solid_growth(const std::vector<Pl> &block, const Tf &pose, const Col &colour, bool linear_given = false, const Col *linear_in = nullptr) {
		cut.assign(block.begin(), block.end());
		const Tf xf = Tf() * pose; // `frame` is identity in `finish`
		if (ground > -INFINITY) cut.push_back(xf.affine_inverse().xform(Pl(V3(0, -1, 0), float(-ground))));
		convex_points(cut.data(), int(cut.size()), raw);
		unique(raw, points);
		Col linear = linear_given ? *linear_in : colour.srgb_to_linear();
		polys.build(cut.data(), int(cut.size()), points, -1);
		if (points.size() < 4) return;
		for (const Poly &p : polys.faces) {
			V3 normal = xf.basis.xform(p.normal).normalized();
			Col shade = linear * float(1.0 + double(rng.randf_range(-0.06, 0.06)));
			shade.a = 1.0f;
			V3 cs[64];
			std::vector<V3> big;
			V3 *out = cs;
			if (p.count > 64) {
				big.resize(p.count);
				out = big.data();
			}
			for (int k = 0; k < p.count; k++) out[k] = xf.xform(polys.corners[p.first + k]);
			add_face(out, p.count, normal, shade, -1, grow);
		}
	}

	// Build `_leaf`.
	void leaf(const V3 &at, const V3 &out, double size, double droop) {
		V3 face = out + mul(mul(V3(0, -1, 0), droop), rng.randf_range(0.3, 1.0));
		float jx = rng.randf_range(-0.4, 0.4);
		float jy = rng.randf_range(-0.3, 0.3);
		float jz = rng.randf_range(-0.4, 0.4);
		face = (face + V3(jx, jy, jz)).normalized();
		V3 side = face.cross(absf(face.y) < 0.9 ? V3(0, 1, 0) : V3(1, 0, 0)).normalized();
		Bs basis = Bs::columns(side, face, side.cross(face)).orthonormalized();
		std::vector<Pl> block;
		block.push_back(Pl(V3(0, -1, 0), 0.0f));
		double turn = double(rng.randf()) * TAU;
		const int sides = lean ? 3 : 5;
		for (int k = 0; k < sides; k++) {
			double a = turn + TAU * k / (lean ? 3.0 : 5.0) + double(rng.randf_range(-0.2, 0.2));
			float ca = float(zs::cos(a)), sa = float(zs::sin(a));
			block.push_back(Pl(V3(ca, 0.0f, sa), float(size * double(rng.randf_range(0.42, 0.55)))));
			V3 n = V3(float(zs::cos(a + 0.6) * 0.9), 1.0f, float(zs::sin(a + 0.6) * 0.9)).normalized();
			block.push_back(Pl(n, n.dot(V3(0.0f, float(size * 0.32), 0.0f))));
		}
		double light = clampf(double(face.y) * 0.5 + 0.5 + double(rng.randf_range(-0.3, 0.3)), 0.0, 0.999);
		const Col &linear = ivy_linear[size_t(int64_t(light * double(ivy_linear.size())))];
		solid_growth(block, Tf(basis, at), linear, true, &linear);
	}

	// Build `_strand` (the ivy's).
	void ivy_strand(const V3 &start, const V3 &out, double length, bool free) {
		V3 along(-out.z, 0.0f, out.x);
		V3 p = start;
		double travelled = 0.0;
		double size = double(rng.randf_range(ivy_leaf.x, ivy_leaf.y)) * (lean ? 1.45 : 1.15);
		double in_air = 0.0;
		double phase = fposmod(double(start.x) * 3.17 + double(start.z) * 5.31, 1.0);
		while (travelled < length) {
			double taper = 1.0 - 0.55 * smoothstep(length * 0.55, length, travelled);
			grow = attrs(start.y, length, out, free ? 1.0 : clampf(in_air / 0.4, 0.0, 1.0), 1.0, fposmod(phase + travelled * 0.37, 1.0));
			int64_t leaves = (lean ? 1 : 2) + int64_t(rng.randf() < 0.5f);
			for (int64_t j = 0; j < leaves; j++) {
				V3 off = mul(along, rng.randf_range(-0.16, 0.16));
				off = off + V3(0.0f, rng.randf_range(-0.05, 0.05), 0.0f);
				off = off + mul(out, rng.randf_range(0.0, 0.05));
				double s = size * taper * double(rng.randf_range(0.75, 1.1));
				leaf(p + off, out, s, 0.5);
			}
			double step = double(rng.randf_range(0.11, 0.17)) * (lean ? 1.8 : 1.0);
			V3 next = p + mul(V3(0, -1, 0), step);
			next = next + mul(mul(along, rng.randf_range(-0.05, 0.05)), free ? 0.4 : 1.0);
			if (!free) {
				double pushed = 0.0;
				while (inside(next) && pushed < 0.7) {
					next += mul(out, 0.05);
					pushed += 0.05;
				}
				if (pushed >= 0.7) break;
				double g = gap(next, -out, 0.45);
				if (g < 0.45) {
					next -= mul(out, maxf(0.0, g - 0.05));
					in_air = 0.0;
				} else {
					in_air += step;
					if (in_air > 1.0) break;
				}
			} else if (inside(next)) break;
			if (double(next.y) < 0.05) {
				grow = attrs(0.0, 0.0, V3(), 0.0, 0.35, phase, false, 0.6);
				int64_t count = rng.randi_range(2, 5);
				for (int64_t j = 0; j < count; j++) {
					V3 on = V3(next.x, 0.03f, next.z) + mul(out, rng.randf_range(0.0, 0.5));
					on = on + mul(along, rng.randf_range(-0.4, 0.4));
					leaf(on, V3(0, 1, 0), rng.randf_range(ivy_leaf.x, ivy_leaf.y), 0.0);
				}
				break;
			}
			p = next;
			travelled += step;
		}
	}

	// The high tops' pick by area (`_ivy`, `fringes`).
	const Top &pick_top(const std::vector<int> &high, double roll) const {
		const Top *pick = &tops[high[0]];
		for (int t : high) {
			roll -= tops[t].area;
			if (roll <= 0.0) {
				pick = &tops[t];
				break;
			}
		}
		return *pick;
	}

	V3 top_centre(const Top &t) const {
		V3 centre;
		for (int k = 0; k < t.count; k++) centre += top_points[t.first + k];
		return divi(centre, t.count);
	}

	// Build `_ivy`.
	void ivy() {
		std::vector<int> high;
		double area = 0.0;
		for (int i = 0; i < int(tops.size()); i++) {
			if (double(top_points[tops[i].first].y) < 0.75) continue;
			high.push_back(i);
			area += tops[i].area;
		}
		int64_t asked = int64_t(area * lerpf(ivy_strands.x, ivy_strands.y, weathered) + double(rng.randf()));
		int64_t count = int64_t(double(mini(lean ? ivy_lean : ivy_most, asked)) * detail);
		double longest_strand = lerpf(ivy_length.x, ivy_length.y, weathered);
		for (int64_t i = 0; i < count; i++) {
			if (high.empty()) break;
			for (int attempt = 0; attempt < 8; attempt++) {
				double roll = double(rng.randf()) * area;
				const Top &pick = pick_top(high, roll);
				const V3 *poly = &top_points[pick.first];
				V3 centre = top_centre(pick);
				int64_t k = rng.randi() % pick.count;
				V3 p0 = poly[k];
				V3 p1 = poly[(k + 1) % pick.count];
				V3 edge = p1 - p0;
				V3 out = V3(edge.z, 0.0f, -edge.x).normalized();
				if (double(out.length()) < 0.5) continue;
				V3 mid = p0.lerp(p1, rng.randf_range(0.15, 0.85));
				if (out.dot(mid - centre) < 0.0f) out = -out;
				if (inside(mid + mul(out, 0.12) + mul(V3(0, -1, 0), 0.3)) || inside(mid + mul(out, 0.1) + mul(V3(0, 1, 0), 0.08))) continue;
				V3 start = mid + mul(out, 0.05) + mul(V3(0, 1, 0), 0.03);
				grow = attrs(0.0, 0.0, V3(), 0.0, 0.35, fposmod(double(mid.x) * 3.17 + double(mid.z) * 5.31, 1.0), false, 0.6);
				int64_t mats = rng.randi_range(2, 4);
				for (int64_t j = 0; j < mats; j++) {
					V3 on = mid - mul(out, rng.randf_range(0.0, 0.3));
					on = on + mul(edge.normalized(), rng.randf_range(-0.25, 0.25));
					on = on + mul(V3(0, 1, 0), 0.02);
					leaf(on, V3(0, 1, 0), rng.randf_range(ivy_leaf.x, ivy_leaf.y), 0.0);
				}
				double length = minf(mid.y, double(rng.randf_range(0.4, 1.0)) * longest_strand);
				ivy_strand(start, out, length, false);
				break;
			}
		}
		curtains();
		grow = Attrs();
	}

	// --- RuinGrowth ---------------------------------------------------------------------
	void curtains() {
		if (!vines) return;
		for (int hi = 0; hi < int(hangs.size()); hi++) {
			const Hang h = hangs[hi];
			if (detail < 1.0 && std::fmod(hi * 0.618, 1.0) >= detail) continue;
			curtain(h.at, h.length, h.from);
		}
	}

	double underside(const V3 &at, double low, double high) const {
		double y = low;
		while (y < high) {
			if (inside(V3(at.x, float(y), at.z))) return y - 0.03;
			y += 0.06;
		}
		return -1.0;
	}

	V3 run_way(const V3 &at, double from) {
		V3 best(1, 0, 0);
		double most = -1.0;
		double turn = double(rng.randf()) * 0.3;
		for (int k = 0; k < 4; k++) {
			double a = turn + PI * k / 4.0;
			V3 way(float(zs::cos(a)), 0.0f, float(zs::sin(a)));
			double run = 0.0;
			for (double s : { -1.0, 1.0 }) {
				double d = 0.15;
				while (d < 1.6) {
					V3 q = at + mul(mul(way, s), d);
					if (inside(V3(q.x, float(from + 0.12), q.z)) || inside(V3(q.x, float(from + 0.45), q.z)) || inside(V3(q.x, float(from + 0.9), q.z))) run += 0.15;
					else break;
					d += 0.15;
				}
			}
			if (run > most) {
				most = run;
				best = way;
			}
		}
		return best;
	}

	void curtain(const V3 &at, double length, double from) {
		const int64_t most_given = -1;
		if (from < 0.0) {
			from = underside(at, 0.5, 14.0);
			if (from < 0.0) return;
		}
		if (length < 0.2) return;
		V3 way = run_way(at, from);
		double gap_between = double(rng.randf_range(spacing.x, spacing.y)) * (lean ? lean_scale : 1.0);
		int64_t most = most_given < 0 ? (lean ? strands_lean : strands_most) : most_given;
		int64_t count = clampi(int64_t(std::round(double(most) * double(rng.randf_range(0.55, 1.0)))), 2, most);
		double long_most = minf(length * length_gain + 0.6, longest);
		V3 facing(-way.z, 0.0f, way.x);
		double shift = double(rng.randf_range(-0.3, 0.3)) * double(count) * gap_between;
		for (int64_t i = 0; i < count; i++) {
			double t = (double(i) + 0.5) / double(count);
			double along = (t - 0.5) * double(count) * gap_between + shift + double(rng.randf_range(-0.03, 0.03));
			V3 p = at + mul(way, along);
			double top = underside(p, from - 0.9, from + 1.2);
			if (top < 0.0) continue;
			double envelope = 0.5 + 0.5 * zs::sin(PI * t);
			double room = top - floor_at(p.x, p.z) - 0.35;
			double l = minf(long_most * envelope * double(rng.randf_range(0.6, 1.1)), room);
			if (l < 0.3) continue;
			strand(V3(p.x, float(top), p.z), l, facing, true, 1.0, false);
		}
	}

	void fringes() {
		if (!vines) return;
		std::vector<int> high;
		double area = 0.0;
		for (int i = 0; i < int(tops.size()); i++) {
			if (double(top_points[tops[i].first].y) < 1.8) continue;
			high.push_back(i);
			area += tops[i].area;
		}
		if (high.empty()) return;
		int64_t cap = lean ? fringes_lean : fringes_most;
		int64_t asked = int64_t(area * fringe_rate * (0.4 + weathered) + double(rng.randf()));
		int64_t count = int64_t(double(mini(cap, asked)) * detail);
		for (int64_t i = 0; i < count; i++) {
			for (int attempt = 0; attempt < 8; attempt++) {
				double roll = double(rng.randf()) * area;
				const Top &pick = pick_top(high, roll);
				const V3 *poly = &top_points[pick.first];
				V3 centre = top_centre(pick);
				int64_t k = rng.randi() % pick.count;
				V3 p0 = poly[k];
				V3 p1 = poly[(k + 1) % pick.count];
				V3 edge = p1 - p0;
				if (double(edge.length()) < 0.5) continue;
				V3 out = V3(edge.z, 0.0f, -edge.x).normalized();
				V3 mid = p0.lerp(p1, rng.randf_range(0.2, 0.8));
				if (out.dot(mid - centre) < 0.0f) out = -out;
				if (inside(mid + mul(out, 0.12) + mul(V3(0, -1, 0), 0.3)) || inside(mid + mul(out, 0.1) + mul(V3(0, 1, 0), 0.08))) continue;
				V3 along = edge.normalized();
				double gap_between = double(rng.randf_range(0.14, 0.2)) * (lean ? lean_scale : 1.0);
				int64_t fit = int64_t(double(edge.length()) * 0.8 / gap_between);
				int64_t strands = mini(fit, lean ? 3 : rng.randi_range(4, 9));
				double long_most = lerpf(fringe_length.x, fringe_length.y, weathered) * double(rng.randf_range(0.6, 1.0));
				for (int64_t j = 0; j < strands; j++) {
					double t = (double(j) + 0.5) / double(strands);
					V3 at = mid + mul(mul(mul(along, t - 0.5), double(float(strands))), gap_between);
					if (double((at - p0).dot(along)) < 0.05 || double((at - p1).dot(along)) > -0.05) continue;
					double l = minf(long_most * (0.45 + 0.55 * zs::sin(PI * t)) * double(rng.randf_range(0.7, 1.1)), double(at.y) - 0.1);
					strand(at + mul(out, 0.05) + mul(V3(0, 1, 0), 0.02), l, out, false);
				}
				break;
			}
		}
	}

	// RuinGrowth `strand`.
	void strand(const V3 &start, double length, const V3 &out, bool free, double coarse = 1.0, bool full = false) {
		double scale = (lean ? lean_scale : 1.0) * coarse;
		V3 side(-out.z, 0.0f, out.x);
		double step = node_step * scale;
		V3 p = start;
		double travelled = 0.0;
		double in_air = 0.0;
		V3 stem_from = start;
		double stem_len = 0.0;
		double phase = rng.randf();
		V3 drift = mul(side, rng.randf_range(-0.05, 0.05));
		Attrs keep = grow;
		double bare = length * (1.0 - tendril);
		int64_t node = 0;
		while (travelled < length) {
			if (kept_clear(p)) break;
			double t = travelled / length;
			double hug = free ? 0.0 : (in_air <= 0.0 ? 1.0 : 0.0);
			double air_share = free ? 1.0 : clampf(in_air / 0.4, 0.0, 1.0);
			bool on_tendril = travelled > bare;
			if (!on_tendril || node % 3 == 0) {
				double size = lerpf(leaf_size.x, leaf_size.y, smoothstep(0.3, 1.0, t)) * scale * double(rng.randf_range(0.8, 1.15));
				if (on_tendril) size *= 0.7;
				int js = ((lean && !full) || on_tendril) ? 1 : 2;
				for (int j = 0; j < js; j++) {
					double s = (node + j) % 2 == 0 ? 1.0 : -1.0;
					grow = attrs(start.y, length, out, air_share, 1.0, std::fmod(phase + double(node) * 0.137 + double(j) * 0.31, 1.0));
					vine_leaf(p, out, mul(side, s), size, t, hug);
				}
			}
			node += 1;
			V3 next = p + mul(V3(0, -1, 0), step);
			next = next + mul(drift, step);
			next = next + mul(side, rng.randf_range(-0.02, 0.02));
			if (!free) {
				double pushed = 0.0;
				while (inside(next) && pushed < 0.7) {
					next += mul(out, 0.05);
					pushed += 0.05;
				}
				if (pushed >= 0.7) break;
				double g = gap(next, -out, 0.45);
				if (g < 0.45) {
					next -= mul(out, maxf(0.0, g - 0.04));
					in_air = 0.0;
				} else in_air += step;
			} else if (inside(next)) break;
			if (double(next.y) < floor_at(next.x, next.z) + 0.06) break;
			stem_len += step;
			if (stem_len >= stem_step * scale || travelled + step >= length) {
				grow = attrs(start.y, length, out, air_share, 0.0, phase);
				if (coarse > 1.0) ribbon(stem_from, next, stem * scale * lerpf(1.0, 0.6, t), out);
				else stem_piece(stem_from, next, stem * scale * lerpf(1.0, 0.6, t));
				stem_from = next;
				stem_len = 0.0;
			}
			p = next;
			travelled += step;
		}
		if (travelled >= length * 0.9) {
			grow = attrs(start.y, length, out, 1.0, 0.6, phase);
			V3 hook = p + mul(mul(V3(0, -1, 0), 0.06), scale);
			hook = hook + mul(mul(side, 0.05), scale);
			stem_piece(p, hook, stem * scale * 0.55);
			V3 tip = hook + mul(mul(V3(0, 1, 0), 0.05), scale);
			tip = tip + mul(mul(side, 0.02), scale);
			tip = tip + mul(out, 0.02);
			stem_piece(hook, tip, stem * scale * 0.45);
		}
		grow = keep;
	}

	static double sign_to(const V3 &n, const V3 &face) { return n.dot(face) >= 0.0f ? 1.0 : -1.0; }

	// RuinGrowth `_vine_leaf`.
	void vine_leaf(const V3 &at, const V3 &out, const V3 &side, double size, double t, double hug) {
		V3 down = mul(V3(0, -1, 0), lerpf(0.55, 0.85, hug));
		V3 axis = down + mul(out, lerpf(0.6, 0.15, hug));
		axis = axis + mul(side, rng.randf_range(0.2, 0.7));
		float jx = rng.randf_range(-0.2, 0.2);
		float jy = rng.randf_range(-0.1, 0.25);
		float jz = rng.randf_range(-0.2, 0.2);
		axis = (axis + V3(jx, jy, jz)).normalized();
		V3 face = (out - axis * axis.dot(out)).normalized();
		if (double(face.length()) < 0.5) face = side.cross(axis).normalized();
		V3 across = axis.cross(face).normalized();
		double w = size * leaf_width * 0.5;
		V3 base = at + mul(side, 0.01);
		V3 tip = base + mul(axis, size);
		V3 mid = base + mul(mul(axis, size), 0.42);
		V3 fold = mul(mul(face, size), rng.randf_range(0.08, 0.16));
		V3 left = mid + mul(across, w) + fold;
		V3 right = mid - mul(across, w) + fold;
		double shade = clampf(0.35 + 0.5 * t + double(rng.randf_range(-0.3, 0.3)), 0.0, 0.999);
		Col colour = vine_linear[size_t(int64_t(shade * double(vine_linear.size())))] * rng.randf_range(0.9, 1.08);
		colour.a = 1.0f;
		V3 n1 = (left - base).cross(tip - base);
		growth_face({ base, left, tip }, mul(n1.normalized(), sign_to(n1, face)), colour);
		V3 n2 = (tip - base).cross(right - base);
		growth_face({ base, tip, right }, mul(n2.normalized(), sign_to(n2, face)), colour);
	}

	// RuinGrowth `_stem`.
	void stem_piece(const V3 &a, const V3 &b2, double r) {
		V3 axis = b2 - a;
		if (double(axis.length()) < 0.005) return;
		axis = axis.normalized();
		V3 u = axis.cross(absf(axis.z) < 0.9 ? V3(0, 0, -1) : V3(1, 0, 0)).normalized();
		V3 v = axis.cross(u);
		for (int k = 0; k < 3; k++) {
			V3 d0 = mul(u, stem_cos[k]) + mul(v, stem_sin[k]);
			V3 d1 = mul(u, stem_cos[k + 1]) + mul(v, stem_sin[k + 1]);
			V3 n = (d0 + d1).normalized();
			growth_face({ a + mul(d0, r), a + mul(d1, r), b2 + mul(d1, r), b2 + mul(d0, r) }, n, stem_colour);
		}
	}

	// RuinGrowth `_ribbon`.
	void ribbon(const V3 &a, const V3 &b2, double r, const V3 &out) {
		V3 axis = b2 - a;
		if (double(axis.length()) < 0.005) return;
		V3 across = axis.cross(out).normalized();
		if (double(across.length()) < 0.5) return;
		growth_face({ a - mul(across, r), a + mul(across, r), b2 + mul(across, r), b2 - mul(across, r) }, out, stem_colour);
	}

	// Build `_cushions`.
	void cushions() {
		if (detail <= 0.0) return;
		grow = attrs(0.0, 0.0, V3(), 0.0, 0.0, 0.0, false, 0.55);
		const std::vector<Top> found = tops;
		for (const Top &t : found) {
			double area = t.area;
			double odds = (0.08 + 0.55 * weathered) * minf(1.0, area * 2.0) * detail * (lean ? 0.5 : 1.0);
			if (double(rng.randf()) > odds) continue;
			int64_t pads = 1 + int64_t(area * 2.0 * weathered);
			for (int64_t j = 0; j < pads; j++) {
				int64_t k = rng.randi() % t.count;
				V3 centre = top_centre(t);
				const V3 *poly = &top_points[t.first];
				V3 edge_at = poly[k].lerp(poly[(k + 1) % t.count], rng.randf());
				V3 at = centre.lerp(edge_at, float(double(rng.randf()) * 0.75));
				double r = double(rng.randf_range(cushion.x, cushion.y)) * minf(1.0, std::sqrt(area));
				std::vector<Pl> block;
				block.push_back(Pl(V3(0, -1, 0), 0.0f));
				block.push_back(Pl(V3(0, 1, 0), float(r * double(rng.randf_range(0.3, 0.5)))));
				double turn = double(rng.randf()) * TAU;
				int sides = lean ? 4 : 6;
				for (int e = 0; e < sides; e++) {
					double a = turn + TAU * e / double(sides);
					block.push_back(Pl(V3(float(zs::cos(a)), 0.0f, float(zs::sin(a))), float(r)));
					V3 n = V3(float(zs::cos(a + 0.5) * 0.8), 1.0f, float(zs::sin(a + 0.5) * 0.8)).normalized();
					block.push_back(Pl(n, n.dot(V3(0.0f, float(r * 0.4), 0.0f))));
				}
				Col colour = moss_light.lerp(moss, float(double(rng.randf()) * 0.6));
				solid_growth(block, Tf(Bs(), at - V3(0.0f, 0.02f, 0.0f)), colour);
			}
		}
		grow = Attrs();
	}

	// --- Drawing ------------------------------------------------------------------------
	void make_grid() {
		gridded = true;
		for (int i = 0; i < int(solids.size()); i++) {
			const AB &box = solids[i].box;
			V3 end = box.end();
			for (int64_t cx = floori(double(box.position.x) / cell_cull); cx < floori(double(end.x) / cell_cull) + 1; cx++)
				for (int64_t cy = floori(double(box.position.y) / cell_cull); cy < floori(double(end.y) / cell_cull) + 1; cy++)
					for (int64_t cz = floori(double(box.position.z) / cell_cull); cz < floori(double(end.z) / cell_cull) + 1; cz++)
						grid[GridKey{ cx, cy, cz }].push_back(i);
		}
	}

	bool in_solid(const Solid &s, const V3 &p) const {
		if (!s.box.has_point(p)) return false;
		for (int k = 0; k < s.count; k++)
			if (planes[s.first + k].distance_to(p) > 0.0f) return false;
		return true;
	}

	// Build `_solid_at`.
	bool solid_at(const V3 &p, int own) const {
		if (double(p.y) < floor_at(p.x, p.z) - 0.01 || double(p.y) < ground - 0.01) return true;
		auto it = grid.find(GridKey{ floori(double(p.x) / cell_cull), floori(double(p.y) / cell_cull), floori(double(p.z) / cell_cull) });
		if (it == grid.end()) return false;
		for (int i : it->second) {
			if (i == own) continue;
			if (in_solid(solids[i], p)) return true;
		}
		return false;
	}

	// Build `_covered`.
	bool covered(const V3 *cs, int n, const V3 &normal, int own) const {
		V3 middle;
		for (int k = 0; k < n; k++) middle += cs[k];
		middle = divi(middle, n);
		V3 off = mul(mul(normal, cull_off), 2.0);
		if (!solid_at(middle + off, own)) return false;
		int64_t count = 0;
		for (int k = 0; k < n; k++)
			if (solid_at(cs[k].lerp(middle, 0.5f) + off, own)) count += 1;
		return count * 2 >= n;
	}

	// Build `_hidden`.
	bool hidden(const V3 *cs, int n, const V3 &normal, int own) const {
		V3 middle;
		for (int k = 0; k < n; k++) middle += cs[k];
		middle = divi(middle, n);
		V3 probes[65];
		std::vector<V3> big;
		V3 *pr = probes;
		if (n + 1 > 65) {
			big.resize(n + 1);
			pr = big.data();
		}
		pr[0] = middle;
		for (int k = 0; k < n; k++) pr[k + 1] = cs[k].lerp(middle, 0.1f);
		for (int k = 0; k <= n; k++) {
			V3 p = pr[k] + mul(normal, cull_off);
			if (double(p.y) < floor_at(p.x, p.z) - 0.01 || double(p.y) < ground - 0.01) continue;
			auto it = grid.find(GridKey{ floori(double(p.x) / cell_cull), floori(double(p.y) / cell_cull), floori(double(p.z) / cell_cull) });
			if (it == grid.end()) return false;
			bool found = false;
			for (int i : it->second) {
				if (i == own) continue;
				if (in_solid(solids[i], p)) {
					found = true;
					break;
				}
			}
			if (!found) return false;
		}
		return true;
	}

	static double facing(const V3 &n) {
		double a = zs::atan2(n.z, n.x);
		return clampf(0.32 * zs::sin(a * 3.0 + 0.7) + 0.18 * zs::sin(a * 5.0 + 2.3) + 0.25 * double(n.y), -0.5, 0.5);
	}

	// RuinStoneStyle `shade` (a look with no block tone and no facet hash).
	Col style_shade(const Col &stone_colour, const V3 &at, const V3 &normal, double part, bool worn) const {
		Col c = stone_colour;
		if (look_band > 0.0) {
			int64_t k = floori(double(at.y) / look_band);
			c *= float(1.0 + look_band_tone * (k % 2 == 0 ? 1.0 : -1.0));
		}
		c *= float(1.0 - look_foot * (1.0 - smoothstep(0.0, look_rise, at.y)));
		if (double(normal.y) > 0.85) {
			double tip = clampf(double(V2(normal.x, normal.z).dot(V2(float(-0.55), float(0.83)))) / 0.06, -1.0, 1.0);
			c *= float(1.0 + look_facets * (look_top + look_tip * tip));
		} else c *= float(1.0 + facing(normal) * look_facets);
		if (double(normal.y) < -0.3) c *= float(look_under);
		if (part < 0.8) c *= float(look_recess);
		if (worn) c *= float(1.0 + look_worn);
		Col linear = Col(c.r, c.g, c.b, 1.0f).srgb_to_linear();
		return Col(linear.r, linear.g, linear.b, 1.0f);
	}

	// Build `_erode`: an eroded block's faces, appended to `out`.
	void erode(const Pending &e, std::vector<Pending> &out, std::vector<V3> &out_corners) {
		const Pl *ps = &planes[e.first];
		const uint8_t *ks = &kinds[e.kinds];
		std::vector<Pl> base;
		for (int i = 0; i < e.count; i++)
			if (ks[i] == 0 || ks[i] == 3) base.push_back(ps[i]);
		convex_points(base.data(), int(base.size()), raw);
		unique(raw, points);
		polys.build(base.data(), int(base.size()), points, -1);
		std::vector<V3> open, shut;
		for (const Poly &f : polys.faces) {
			if (covered(&polys.corners[f.first], f.count, f.normal, e.occluder)) shut.push_back(f.normal);
			else open.push_back(f.normal);
		}
		std::vector<Pl> keep;
		std::vector<uint8_t> kept;
		for (int i = 0; i < e.count; i++) {
			uint8_t kind = ks[i];
			if (kind == 1 || kind == 2) {
				V3 n = ps[i].n;
				double reach = kind == 1 ? 0.6 : 0.3;
				int64_t seen = 0, hid = 0;
				for (const V3 &m : open)
					if (double(m.dot(n)) > reach) seen += 1;
				for (const V3 &m : shut)
					if (double(m.dot(n)) > reach) hid += 1;
				if (kind == 1 && hid > 0) continue;
				if (kind == 2 && seen < 2) continue;
			}
			keep.push_back(ps[i]);
			kept.push_back(kind);
		}
		convex_points(keep.data(), int(keep.size()), raw);
		unique(raw, points);
		if (points.size() < 4) return;
		polys.build(keep.data(), int(keep.size()), points, -1);
		for (const Poly &f : polys.faces) {
			bool worn = kept[f.plane] != 0;
			Pending face;
			face.first = int(out_corners.size());
			face.count = f.count;
			for (int k = 0; k < f.count; k++) out_corners.push_back(polys.corners[f.first + k]);
			face.normal = f.normal;
			face.colour = style_shade(clean_stone, f.mid, f.normal, e.part, worn);
			face.occluder = e.occluder;
			out.push_back(face);
		}
	}

	void tri(PackedVector3Array &v, PackedVector3Array &n, PackedColorArray &c, const V3 &a, const V3 &b, const V3 &d, const V3 &normal, const Col &colour) {
		const Vector3 gn = normal.gd();
		const Color gc = colour.gd();
		v.push_back(a.gd());
		n.push_back(gn);
		c.push_back(gc);
		v.push_back(b.gd());
		n.push_back(gn);
		c.push_back(gc);
		v.push_back(d.gd());
		n.push_back(gn);
		c.push_back(gc);
	}

	// RuinGrowth `emit` (no bend).
	void emit(const V3 *cs, int count, const V3 &normal, const Col &colour, const Attrs &g) {
		const float *a = g.a;
		V3 o = Bs().xform(V3(a[2], 0.0f, a[3]));
		double span = a[1];
		bool up = a[7] > 0.5f;
		const Vector3 face_normal = normal.gd();
		const Color face_colour = colour.gd();
		for (int k = 1; k < count - 1; k++) {
			V3 tri[3] = { cs[0], cs[k], cs[k + 1] };
			if ((tri[1] - tri[0]).cross(tri[2] - tri[0]).dot(normal) > 0.0f) {
				V3 t = tri[1];
				tri[1] = tri[2];
				tri[2] = t;
			}
			for (const V3 &p : tri) {
				double reach = 0.0;
				if (span > 0.0) reach = up ? clampf(double(p.y) - double(a[0]), 0.0, span * 1.2) : clampf(double(a[0]) - double(p.y), 0.0, span * 1.2);
				gv.push_back(p.gd());
				gn.push_back(face_normal);
				gc.push_back(face_colour);
				guv.push_back(Vector2(float(up ? -reach : reach), float(span)));
				guv2.push_back(Vector2(a[6], a[5]));
				double along = double(a[8]) >= 0.0 ? double(a[8]) : (span > 0.0 ? clampf(reach / span, 0.0, 1.0) : 0.5);
				gcu.push_back(o.x);
				gcu.push_back(o.z);
				gcu.push_back(a[4]);
				gcu.push_back(float(along));
			}
		}
	}

	// Build `_draw` (no shelter, no bend).
	void draw() {
		bool carving = false;
		for (const Pending &f : pending)
			if (f.erode) {
				carving = true;
				break;
			}
		if (cull || carving) make_grid();
		std::vector<Pending> drawn;
		std::vector<V3> drawn_corners;
		const std::vector<Pending> *list = &pending;
		const std::vector<V3> *list_corners = &corners;
		if (carving) {
			drawn.reserve(pending.size() * 2);
			drawn_corners.reserve(corners.size() * 2);
			for (const Pending &f : pending) {
				if (f.erode) erode(f, drawn, drawn_corners);
				else {
					Pending c = f;
					c.first = int(drawn_corners.size());
					for (int k = 0; k < f.count; k++) drawn_corners.push_back(corners[f.first + k]);
					drawn.push_back(c);
				}
			}
			list = &drawn;
			list_corners = &drawn_corners;
		}
		for (const Pending &f : *list) {
			const V3 *cs = &(*list_corners)[f.first];
			if (cull && hidden(cs, f.count, f.normal, f.occluder)) continue;
			if (!f.grow.none) {
				emit(cs, f.count, f.normal, f.colour, f.grow);
				continue;
			}
			for (int k = 1; k < f.count - 1; k++) {
				const V3 &a = cs[0], &b = cs[k], &c = cs[k + 1];
				if ((b - a).cross(c - a).dot(f.normal) > 0.0f) tri(sv, sn, sc, a, c, b, f.normal, f.colour);
				else tri(sv, sn, sc, a, b, c, f.normal, f.colour);
			}
		}
		pending.clear();
	}

	// `finish` from the ivy to the drawn arrays.
	Dictionary run() {
		ivy();
		fringes();
		cushions();
		draw();
		Dictionary out;
		out["state"] = int64_t(rng.state);
		out["v"] = sv;
		out["n"] = sn;
		out["c"] = sc;
		out["gv"] = gv;
		out["gn"] = gn;
		out["gc"] = gc;
		out["guv"] = guv;
		out["guv2"] = guv2;
		out["gcu"] = gcu;
		return out;
	}
};

} // namespace zs
