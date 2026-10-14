// The motif isles' kernels (docs/design/roguelike/native-isles-round1.md):
// the number crunching of a motif isle's build moved out of GDScript, which
// in this engine runs one thread at a time across the process, so isles can
// be built side by side on the worker pool. Each method takes packed arrays
// and plain values (or GDScript's own arrays, only read) and gives packed
// arrays back: no nodes, resources, scene, physics or script calls, safe on
// any worker. Each mirrors its GDScript op for op (isle_math.h), and the
// GDScript stays as the fallback and the reference.
#pragma once

#include "isle_finish.h"
#include "isle_solid.h"
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <algorithm>
#include <map>
#include <tuple>

using namespace godot;

// Mesh::ArrayType (the build profile leaves Mesh out).
namespace zs_mesh {
enum { ARRAY_VERTEX = 0, ARRAY_NORMAL = 1, ARRAY_COLOR = 3, ARRAY_TEX_UV = 4, ARRAY_TEX_UV2 = 5, ARRAY_CUSTOM0 = 6, ARRAY_MAX = 13 };
}

class ZenScapeIsleKernels : public RefCounted {
	GDCLASS(ZenScapeIsleKernels, RefCounted)

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("ruin_finish", "build"), &ZenScapeIsleKernels::ruin_finish);
		ClassDB::bind_method(D_METHOD("ruin_solid", "consts", "noise", "bevels", "state", "numbers", "flags", "planes", "extra", "pose", "frame", "colour", "stone", "open", "rough", "grow"), &ZenScapeIsleKernels::ruin_solid);
		ClassDB::bind_method(D_METHOD("growth_levels", "vertices", "levels", "thin_width", "thin_aspect"), &ZenScapeIsleKernels::growth_levels);
		ClassDB::bind_method(D_METHOD("growth_chunks", "arrays", "cell"), &ZenScapeIsleKernels::growth_chunks);
		ClassDB::bind_method(D_METHOD("edge_distance", "point", "poly"), &ZenScapeIsleKernels::edge_distance);
		ClassDB::bind_method(D_METHOD("thickness", "points"), &ZenScapeIsleKernels::thickness);
		ClassDB::bind_method(D_METHOD("cut_faces", "faces", "piece_tris"), &ZenScapeIsleKernels::cut_faces);
		ClassDB::bind_method(D_METHOD("set_engine_math", "on"), &ZenScapeIsleKernels::set_engine_math);
		ClassDB::bind_method(D_METHOD("version"), &ZenScapeIsleKernels::version);
	}

public:
	// Bumped when a kernel's output changes, so GDScript can refuse a stale library.
	int64_t version() const { return 2; }

	// Transcendentals through the engine's own functions (the default off macOS).
	void set_engine_math(bool on) { zs::engine_math = on; }

	// RuinKit Build `finish` from `_ivy` to the end of `_draw` (scripts/ruin_kit.gd
	// `_finish_native` says what goes in): {state, v, n, c, gv, gn, gc, guv,
	// guv2, gcu}, or {} when the Build holds what it does not draw.
	Dictionary ruin_finish(const Dictionary &build) const {
		zs::Finish f;
		if (!f.read(build)) return Dictionary();
		return f.run();
	}

	// RuinKit Build `solid` in the classic or an eroded look (scripts/ruin_kit.gd
	// `_solid_native`). `numbers`: weathered, age, ground, and the Build's
	// pending, tops, hulls and solids counts; `flags`: 1 collide, 2 wear, 4
	// growable, 8 lean, 16 rigid, 32 a bend, 64 check_floating, 128
	// drop_floating. Answers [random state, the open face, pending entries,
	// tops, solid (or null), hull (or null), its anchor, block (or null)].
	Array ruin_solid(const Dictionary &consts, Object *noise, const Dictionary &bevels, int64_t state, const PackedFloat64Array &numbers, int64_t flags,
			const Array &planes_in, const Array &extra_in, const Transform3D &pose_in, const Transform3D &frame_in, const Color &colour_in, const Color &stone_in,
			int64_t open_in, double rough, const PackedFloat32Array &grow) const {
		using namespace zs;
		SolidConsts k;
		k.read(consts);
		SolidBuild b(k, noise, bevels);
		b.rng.state = uint64_t(state);
		const double *num = numbers.ptr();
		b.weathered = num[0];
		b.age = num[1];
		b.ground = num[2];
		const int64_t pending_count = int64_t(num[3]), tops_count = int64_t(num[4]), hulls_count = int64_t(num[5]), solids_count = int64_t(num[6]);
		const bool collide = flags & 1, wear = flags & 2, growable = flags & 4, rigid = flags & 16, has_path = flags & 32, floating = (flags & 64) || (flags & 128);
		b.lean = flags & 8;
		int open = int(open_in);
		const Col colour(colour_in), stone(stone_in);
		const bool ruled = growable && k.ruled;
		const bool eroding = ruled && k.eroded;
		auto to_tf = [](const Transform3D &t) {
			Tf r;
			for (int i = 0; i < 3; i++) r.basis.rows[i] = V3(t.basis.rows[i]);
			r.origin = V3(t.origin);
			return r;
		};
		const Tf pose = to_tf(pose_in), frame = to_tf(frame_in);

		std::vector<Pl> cut;
		cut.reserve(planes_in.size() + extra_in.size() + 16);
		for (int64_t i = 0; i < planes_in.size(); i++) cut.push_back(Pl(Plane(planes_in[i])));
		for (int64_t i = 0; i < extra_in.size(); i++) cut.push_back(Pl(Plane(extra_in[i])));
		// `source` is `cut` as it was; when the wear is not kept, `cut` stays
		// the very same array (the ground's plane then lands in both).
		std::vector<Pl> source = cut;
		bool same = true;
		bool wore = false;
		if (wear) {
			std::vector<Pl> worn = b.wear(cut, rough, open);
			wore = true;
			std::vector<V3> base;
			convex_points(cut.data(), int(cut.size()), base);
			bool keep_worn = true;
			if (base.size() >= 4) {
				AB box(base[0], V3());
				for (const V3 &q : base) SolidBuild::expand(box, q);
				box = SolidBuild::grow(box, float(maxf(0.15, double(SolidBuild::longest(box)) * 0.08)));
				std::vector<V3> worn_points;
				convex_points(worn.data(), int(worn.size()), worn_points);
				for (const V3 &q : worn_points) {
					if (!box.has_point(q)) {
						keep_worn = false;
						wore = false;
						break;
					}
				}
			}
			if (keep_worn) {
				cut = worn;
				same = false;
			}
		}
		const Tf xf = frame * pose;
		if (b.ground > -INFINITY) {
			cut.push_back(xf.affine_inverse().xform(Pl(V3(0, -1, 0), float(-b.ground))));
			if (same) source = cut;
		}
		std::vector<V3> points;
		b.hull_points(cut, points);
		const Col linear = colour.srgb_to_linear();
		Polys &made = b.polys;
		made.build(cut.data(), int(cut.size()), points, open);
		Array out;
		out.resize(8);
		PackedVector3Array open_face;
		for (const V3 &q : made.open_face) open_face.push_back(q.gd());
		out[1] = open_face;
		if (points.size() < 4) {
			out[0] = int64_t(b.rng.state);
			out[1] = PackedVector3Array();
			out[2] = Array();
			out[3] = Array();
			out[6] = NAN;
			return out;
		}
		Array block;
		if (floating && growable) {
			block.push_back(points_array(points.data(), int(points.size()), xf));
			block.push_back(planes_array(cut, &xf));
			block.push_back(Variant());
		}
		const double biggest = made.biggest;
		const int64_t occluder = growable ? solids_count : -1;
		double anchor = NAN;
		if (rigid && has_path) {
			V3 middle;
			for (const V3 &q : points) middle += xf.xform(q);
			anchor = double(middle.x) / double(points.size());
		}
		std::vector<Pl> dialled;
		std::vector<uint8_t> kinds;
		if (eroding) b.dial(source, cut, wore, int(planes_in.size()), dialled, kinds);
		std::vector<V3> shape_points;
		const std::vector<V3> *shape = &points;
		if (eroding) {
			b.hull_points(dialled, shape_points);
			if (shape_points.size() >= 4) shape = &shape_points;
		}
		V3 centre;
		double part = 1.0;
		if (ruled) {
			for (const V3 &q : *shape) centre += xf.xform(q);
			centre = divi(centre, int64_t(shape->size()));
			part = double(colour.luminance()) / maxf(stone.luminance(), 0.001);
		}
		Array pending;
		if (eroding) {
			Array entry;
			entry.push_back(String("erode"));
			entry.push_back(planes_array(dialled, &xf));
			entry.push_back(centre.gd());
			entry.push_back(part);
			entry.push_back(occluder);
			entry.push_back(anchor);
			PackedByteArray ks;
			ks.resize(int64_t(kinds.size()));
			for (size_t i = 0; i < kinds.size(); i++) ks.set(int64_t(i), kinds[i]);
			entry.push_back(ks);
			pending.push_back(entry);
		}
		Variant grow_value = grow.is_empty() ? Variant() : Variant(grow);
		// The polys as they are now (the colour draws below don't touch them).
		const std::vector<Poly> faces = made.faces;
		const std::vector<V3> corners = made.corners;
		for (const Poly &p : faces) {
			V3 normal = xf.basis.xform(p.normal).normalized();
			V3 mid = xf.xform(p.mid);
			bool small = wear && p.area < biggest * 0.16;
			Col shade;
			if (ruled) {
				b.shade(mid, normal, linear, small, false);
				if (eroding) continue;
				return Array(); // a clean look: not here
			} else if (growable) shade = b.shade(mid, normal, linear, small, true);
			else shade = linear * float(1.0 + double(b.rng.randf_range(-0.06, 0.06)));
			if (!growable) shade.a = 1.0f;
			Array entry;
			entry.push_back(points_array(&corners[p.first], p.count, xf));
			entry.push_back(normal.gd());
			entry.push_back(shade.gd());
			entry.push_back(occluder);
			entry.push_back(anchor);
			entry.push_back(grow_value);
			pending.push_back(entry);
		}
		Array tops;
		if (growable) {
			for (const Poly &p : faces) {
				V3 normal = xf.basis.xform(p.normal).normalized();
				if (double(normal.y) > 0.8 && p.area > 0.03) {
					Array top;
					top.push_back(points_array(&corners[p.first], p.count, xf));
					top.push_back(p.area);
					tops.push_back(top);
				}
			}
		}
		Variant solid_entry;
		if (growable) {
			AB box(xf.xform(points[0]), V3());
			for (const V3 &q : points) SolidBuild::expand(box, xf.xform(q));
			box = SolidBuild::grow(box, 0.01f);
			Array entry;
			entry.push_back(AABB(box.position.gd(), box.size.gd()));
			entry.push_back(planes_array(cut, &xf));
			solid_entry = entry;
		}
		Variant hull_value;
		if (collide) {
			std::vector<V3> hull;
			hull.reserve(points.size());
			for (const V3 &q : points) hull.push_back(xf.xform(q));
			if (SolidBuild::thickness(hull) >= k.hull_thin) {
				PackedVector3Array h;
				h.resize(int64_t(hull.size()));
				for (size_t i = 0; i < hull.size(); i++) h.set(int64_t(i), hull[i].gd());
				hull_value = h;
			}
		}
		if (!block.is_empty()) {
			const int64_t solids_after = solids_count + (growable ? 1 : 0);
			const int64_t hulls_after = hulls_count + (hull_value.get_type() == Variant::NIL ? 0 : 1);
			PackedInt32Array marks;
			for (int64_t m : { pending_count, tops_count, hulls_count, solids_count, pending_count + pending.size(), tops_count + tops.size(), hulls_after, solids_after }) marks.push_back(int32_t(m));
			block[2] = marks;
		}
		out[0] = int64_t(b.rng.state);
		out[2] = pending;
		out[3] = tops;
		out[4] = solid_entry;
		out[5] = hull_value;
		out[6] = anchor;
		out[7] = block.is_empty() ? Variant() : Variant(block);
		return out;
	}

	// RuinLod `_groups`: [group starts (triangle indices, then the end), thin flags].
	static void groups(const PackedVector3Array &v, double thin_width, double thin_aspect, std::vector<int32_t> &starts, std::vector<uint8_t> &thin) {
		const zs::V3 *p = reinterpret_cast<const zs::V3 *>(v.ptr());
		const int64_t tris = v.size() / 3;
		int64_t k = 0;
		while (k < tris) {
			const zs::V3 first = p[k * 3];
			int64_t end = k + 1;
			while (end < tris && p[end * 3] == first) end += 1;
			double area = 0.0, longest = 0.0;
			for (int64_t t = k; t < end; t++) {
				const zs::V3 &a = p[t * 3], &b = p[t * 3 + 1], &c = p[t * 3 + 2];
				area += double((b - a).cross(c - a).length()) * 0.5;
				longest = zs::maxf(longest, zs::maxf((b - a).length(), zs::maxf((c - b).length(), (a - c).length())));
			}
			double width = area / zs::maxf(longest, 1e-6);
			starts.push_back(int32_t(k));
			thin.push_back(width < thin_width && longest > width * thin_aspect ? 1 : 0);
			k = end;
		}
		starts.push_back(int32_t(tris));
	}

	static double share_hash(int64_t g) {
		uint64_t h = (uint64_t(g) * 2654435761ULL) & 0xffffffffULL;
		h = ((h ^ (h >> 15)) * 2246822519ULL) & 0xffffffffULL;
		h = h ^ (h >> 13);
		return double(h % 10007) / 10007.0;
	}

	// RuinLod's growth levels: {index (0..n-1), lods ({error: indices}, as
	// `growth_lods`)}. `levels`: [[error, share], ...].
	Dictionary growth_levels(const PackedVector3Array &v, const Array &levels, double thin_width, double thin_aspect) const {
		static_assert(sizeof(zs::V3) == sizeof(Vector3), "Vector3 is three floats");
		Dictionary out;
		const int64_t n = v.size();
		PackedInt32Array index;
		index.resize(n);
		int32_t *ip = index.ptrw();
		for (int64_t k = 0; k < n; k++) ip[k] = int32_t(k);
		out["index"] = index;
		std::vector<int32_t> starts;
		std::vector<uint8_t> thin;
		groups(v, thin_width, thin_aspect, starts, thin);
		const int64_t tris = n / 3;
		Dictionary lods;
		int64_t last_size = -1;
		for (int64_t l = 0; l < levels.size(); l++) {
			Array level = levels[l];
			double share = level[1];
			std::vector<int32_t> picked;
			for (size_t g = 0; g + 1 < starts.size(); g++) {
				if (thin[g] == 1) continue;
				if (share < 1.0 && share_hash(int64_t(g)) >= share) continue;
				for (int32_t t = starts[g]; t < starts[g + 1]; t++) {
					picked.push_back(t * 3);
					picked.push_back(t * 3 + 1);
					picked.push_back(t * 3 + 2);
				}
			}
			const int64_t size = int64_t(picked.size());
			if (size >= tris * 3 || (last_size >= 0 && size >= last_size)) continue;
			if (size == 0) break;
			PackedInt32Array idx;
			idx.resize(size);
			std::copy(picked.begin(), picked.end(), idx.ptrw());
			lods[double(level[0])] = idx;
			last_size = size;
		}
		out["lods"] = lods;
		return out;
	}

	template <typename P>
	static P rows(const P &source, const std::vector<int64_t> &picked, const std::vector<int32_t> &starts, int width) {
		P out;
		int64_t total = 0;
		for (int64_t g : picked) total += int64_t(starts[g + 1] - starts[g]) * 3 * width;
		out.resize(total);
		auto *w = out.ptrw();
		const auto *r = source.ptr();
		int64_t at = 0;
		for (int64_t g : picked) {
			const int64_t a = int64_t(starts[g]) * 3 * width, b = int64_t(starts[g + 1]) * 3 * width;
			for (int64_t i = a; i < b; i++) w[at++] = r[i];
		}
		return out;
	}

	// RuinLod `shade_chunks`' arrays: the growth surface `arrays` split by its
	// face groups' first corners into cells `cell` wide (one when it all lies
	// within a cell and a half), each the surface arrays of its chunk, the
	// cells in order.
	Array growth_chunks(const Array &arrays, double cell) const {
		PackedVector3Array v = arrays[zs_mesh::ARRAY_VERTEX];
		std::vector<int32_t> starts;
		std::vector<uint8_t> thin;
		groups(v, 0.0, 0.0, starts, thin);
		const zs::V3 *p = reinterpret_cast<const zs::V3 *>(v.ptr());
		zs::AB box(p[0], zs::V3());
		for (int64_t i = 0; i < v.size(); i++) {
			zs::V3 begin = box.position, end = box.position + box.size;
			const zs::V3 &q = p[i];
			if (q.x < begin.x) begin.x = q.x;
			if (q.y < begin.y) begin.y = q.y;
			if (q.z < begin.z) begin.z = q.z;
			if (q.x > end.x) end.x = q.x;
			if (q.y > end.y) end.y = q.y;
			if (q.z > end.z) end.z = q.z;
			box.position = begin;
			box.size = end - begin;
		}
		const bool one = double(box.size.x) < cell * 1.5 && double(box.size.z) < cell * 1.5 && double(box.size.y) < cell * 1.5;
		std::map<std::tuple<int64_t, int64_t, int64_t>, std::vector<int64_t>> bins;
		for (size_t g = 0; g + 1 < starts.size(); g++) {
			std::tuple<int64_t, int64_t, int64_t> key(0, 0, 0);
			if (!one) {
				const zs::V3 &at = p[int64_t(starts[g]) * 3];
				key = std::make_tuple(zs::floori(double(at.x) / cell), zs::floori(double(at.y) / cell), zs::floori(double(at.z) / cell));
			}
			bins[key].push_back(int64_t(g));
		}
		Array out;
		const int slots[6] = { zs_mesh::ARRAY_VERTEX, zs_mesh::ARRAY_NORMAL, zs_mesh::ARRAY_COLOR, zs_mesh::ARRAY_TEX_UV, zs_mesh::ARRAY_TEX_UV2, zs_mesh::ARRAY_CUSTOM0 };
		for (auto &bin : bins) {
			Array part;
			part.resize(zs_mesh::ARRAY_MAX);
			for (int slot : slots) {
				Variant source = arrays[slot];
				if (source.get_type() == Variant::NIL) continue;
				const int width = slot == zs_mesh::ARRAY_CUSTOM0 ? 4 : 1;
				switch (source.get_type()) {
					case Variant::PACKED_VECTOR3_ARRAY: part[slot] = one ? PackedVector3Array(source).duplicate() : rows(PackedVector3Array(source), bin.second, starts, width); break;
					case Variant::PACKED_VECTOR2_ARRAY: part[slot] = one ? PackedVector2Array(source).duplicate() : rows(PackedVector2Array(source), bin.second, starts, width); break;
					case Variant::PACKED_COLOR_ARRAY: part[slot] = one ? PackedColorArray(source).duplicate() : rows(PackedColorArray(source), bin.second, starts, width); break;
					case Variant::PACKED_FLOAT32_ARRAY: part[slot] = one ? PackedFloat32Array(source).duplicate() : rows(PackedFloat32Array(source), bin.second, starts, width); break;
					default: return Array();
				}
			}
			out.push_back(part);
		}
		return out;
	}

	// RuinKit Build `thickness` (`hull_thickness`).
	double thickness(const PackedVector3Array &points) const {
		std::vector<zs::V3> p(size_t(points.size()));
		for (int64_t i = 0; i < points.size(); i++) p[size_t(i)] = zs::V3(points[i]);
		return zs::SolidBuild::thickness(p);
	}

	struct CutKey {
		double key;
		int64_t t;
	};
	struct CutLess {
		bool operator()(const CutKey &a, const CutKey &b) const { return a.key < b.key; }
	};

	// LateShapes `_cut`: `faces` (triangle corners) in pieces of about
	// `piece_tris` triangles, sorted by their middles along the longest side.
	Array cut_faces(const PackedVector3Array &faces, int64_t piece_tris) const {
		const int64_t tris = faces.size() / 3;
		const zs::V3 *f = reinterpret_cast<const zs::V3 *>(faces.ptr());
		zs::AB box(f[0], zs::V3());
		for (int64_t i = 0; i < faces.size(); i++) zs::SolidBuild::expand(box, f[i]);
		int axis = 0;
		float most = box.size.x;
		if (box.size.y > most) {
			axis = 1;
			most = box.size.y;
		}
		if (box.size.z > most) axis = 2;
		std::vector<CutKey> keys((size_t)tris);
		for (int64_t t = 0; t < tris; t++) keys[size_t(t)] = CutKey{ double(f[t * 3][axis]) + double(f[t * 3 + 1][axis]) + double(f[t * 3 + 2][axis]), t };
		zs::SortArray<CutKey, CutLess> sorter{ CutLess() };
		sorter.sort(keys.data(), tris);
		int64_t count = int64_t(std::ceil(double(tris) / double(piece_tris)));
		if (count < 1) count = 1;
		Array out;
		for (int64_t k = 0; k < count; k++) {
			PackedVector3Array piece;
			const int64_t from = k * tris / count, to = (k + 1) * tris / count;
			piece.resize((to - from) * 3);
			Vector3 *w = piece.ptrw();
			int64_t at = 0;
			for (int64_t i = from; i < to; i++) {
				const int64_t t = keys[size_t(i)].t;
				w[at++] = faces[t * 3];
				w[at++] = faces[t * 3 + 1];
				w[at++] = faces[t * 3 + 2];
			}
			out.push_back(piece);
		}
		return out;
	}

	// KitLand `edge_distance`: `point`'s distance to the ring `poly`'s edges.
	double edge_distance(const Vector2 &point, const PackedVector2Array &poly) const {
		double best = INFINITY;
		const int64_t n = poly.size();
		const Vector2 *r = poly.ptr();
		const float px = point.x, py = point.y;
		for (int64_t i = 0; i < n; i++) {
			const Vector2 a = r[i], b = r[(i + 1) % n];
			float qx, qy;
			const float dx = px - a.x, dy = py - a.y;
			const float nx = b.x - a.x, ny = b.y - a.y;
			const float l2 = nx * nx + ny * ny;
			if (l2 < 1e-20f) {
				qx = a.x;
				qy = a.y;
			} else {
				const float d = (nx * dx + ny * dy) / l2;
				if (d <= 0.0f) {
					qx = a.x;
					qy = a.y;
				} else if (d >= 1.0f) {
					qx = b.x;
					qy = b.y;
				} else {
					qx = a.x + nx * d;
					qy = a.y + ny * d;
				}
			}
			const float dist = std::sqrt((px - qx) * (px - qx) + (py - qy) * (py - qy));
			best = zs::minf(best, double(dist));
		}
		return best;
	}
};
