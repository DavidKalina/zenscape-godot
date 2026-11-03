// ZenScapeTreeSolid: the stood trees' flight solid for GDScript
// (scripts/endless/land_trees.gd `tree_in` / `top_at`). LandTrees publishes
// each plan cell's solid (8 floats a tree: x, z, foot y, height, crown bottom
// over the foot, solid reach, crown radius, knocked) when its block stands,
// when a tree in it is knocked and drops it when the block goes; a query
// reads the 3 x 3 buckets round the point as the GDScript does (each bucket
// in the cell holding its middle, its trees in the cell's order), in double
// as GDScript's floats, so the answers are the GDScript's bit for bit.
// Main thread only: LandTrees publishes on commit and the flight asks on the
// main thread.
#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <cmath>
#include <cstdint>
#include <limits>
#include <unordered_map>
#include <vector>

using namespace godot;

class ZenScapeTreeSolid : public RefCounted {
	GDCLASS(ZenScapeTreeSolid, RefCounted)

	struct Cell {
		std::vector<float> solid;
		std::unordered_map<int64_t, std::vector<int32_t>> buckets;
	};
	double bucket = 16.0;
	double cell = 128.0;
	std::unordered_map<int64_t, Cell> cells;

	static int64_t key(int64_t ix, int64_t iz) { return (ix << 32) ^ (iz & 0xffffffffLL); }

	// The trees of bucket (bx, bz) and their cell's solid, or null.
	const std::vector<int32_t> *list(int64_t bx, int64_t bz, const float *&solid, int64_t &cx, int64_t &cz) const {
		cx = int64_t(std::floor((double(bx) + 0.5) * bucket / cell));
		cz = int64_t(std::floor((double(bz) + 0.5) * bucket / cell));
		const auto c = cells.find(key(cx, cz));
		if (c == cells.end()) return nullptr;
		const auto b = c->second.buckets.find(key(bx, bz));
		if (b == c->second.buckets.end()) return nullptr;
		solid = c->second.solid.data();
		return &b->second;
	}

	static double lerp(double a, double b, double t) { return a + (b - a) * t; }

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("version"), &ZenScapeTreeSolid::version);
		ClassDB::bind_method(D_METHOD("setup", "bucket", "cell"), &ZenScapeTreeSolid::setup);
		ClassDB::bind_method(D_METHOD("set_cell", "cx", "cz", "solid"), &ZenScapeTreeSolid::set_cell);
		ClassDB::bind_method(D_METHOD("drop_cell", "cx", "cz"), &ZenScapeTreeSolid::drop_cell);
		ClassDB::bind_method(D_METHOD("clear"), &ZenScapeTreeSolid::clear);
		ClassDB::bind_method(D_METHOD("count"), &ZenScapeTreeSolid::count);
		ClassDB::bind_method(D_METHOD("top_at", "x", "z"), &ZenScapeTreeSolid::top_at);
		ClassDB::bind_method(D_METHOD("tree_in", "x", "y", "z", "body", "above"), &ZenScapeTreeSolid::tree_in);
	}

public:
	// Bumped when this interface changes, so LandTrees refuses a stale library.
	int64_t version() const { return 1; }

	void setup(double p_bucket, double p_cell) {
		bucket = p_bucket;
		cell = p_cell;
		cells.clear();
	}
	// Plan cell (cx, cz)'s solid, replacing what it had; its buckets from
	// each tree's x, z (GDScript `_lookup`'s, in the same order).
	void set_cell(int64_t cx, int64_t cz, const PackedFloat32Array &p_solid) {
		const int64_t n = p_solid.size() / 8;
		if (n == 0) {
			cells.erase(key(cx, cz));
			return;
		}
		Cell &c = cells[key(cx, cz)];
		c.solid.assign(p_solid.ptr(), p_solid.ptr() + n * 8);
		c.buckets.clear();
		for (int64_t t = 0; t < n; ++t) {
			const int64_t bx = int64_t(std::floor(double(c.solid[t * 8]) / bucket));
			const int64_t bz = int64_t(std::floor(double(c.solid[t * 8 + 1]) / bucket));
			c.buckets[key(bx, bz)].push_back(int32_t(t));
		}
	}
	void drop_cell(int64_t cx, int64_t cz) { cells.erase(key(cx, cz)); }
	void clear() { cells.clear(); }
	int64_t count() const { return int64_t(cells.size()); }

	// LandTrees `top_at`: the tallest tree cone over (x, z), or -INF.
	double top_at(double x, double z) const {
		double best = -std::numeric_limits<double>::infinity();
		const int64_t bx = int64_t(std::floor(x / bucket));
		const int64_t bz = int64_t(std::floor(z / bucket));
		for (int64_t dz = -1; dz <= 1; ++dz)
			for (int64_t dx = -1; dx <= 1; ++dx) {
				const float *s = nullptr;
				int64_t cx, cz;
				const std::vector<int32_t> *l = list(bx + dx, bz + dz, s, cx, cz);
				if (l == nullptr) continue;
				for (const int32_t t : *l) {
					const float *q = s + size_t(t) * 8;
					const double ox = x - double(q[0]);
					const double oz = z - double(q[1]);
					const double reach = q[5];
					const double d2 = ox * ox + oz * oz;
					if (d2 >= reach * reach) continue;
					const double bottom = double(q[2]) + double(q[4]);
					const double top = double(q[2]) + double(q[3]);
					const double v = lerp(top, bottom, std::sqrt(d2) / reach);
					best = best > v ? best : v;
				}
			}
		return best;
	}

	// LandTrees `tree_in`'s pick: [cx, cz, index, top (world y at the point)]
	// of the tree the point is deepest in, or empty.
	PackedFloat64Array tree_in(double x, double y, double z, bool body, double above) const {
		PackedFloat64Array out;
		bool found = false;
		double best_depth = 0.0, best_top = 0.0;
		int64_t bcx = 0, bcz = 0, bi = 0;
		const int64_t bx = int64_t(std::floor(x / bucket));
		const int64_t bz = int64_t(std::floor(z / bucket));
		for (int64_t dz = -1; dz <= 1; ++dz)
			for (int64_t dx = -1; dx <= 1; ++dx) {
				const float *s = nullptr;
				int64_t cx, cz;
				const std::vector<int32_t> *l = list(bx + dx, bz + dz, s, cx, cz);
				if (l == nullptr) continue;
				for (const int32_t t : *l) {
					const float *q = s + size_t(t) * 8;
					const double reach = body ? double(q[5]) : double(q[6]);
					if (reach <= 0.0) continue;
					const double ox = x - double(q[0]);
					const double oz = z - double(q[1]);
					const double d2 = ox * ox + oz * oz;
					if (d2 >= reach * reach) continue;
					const double foot = q[2];
					const double top = lerp(foot + double(q[3]), foot + double(q[4]), std::sqrt(d2) / reach);
					const double depth = top + above - y;
					if (depth <= 0.0 || y < foot - 1.0) continue;
					if (found && depth <= best_depth) continue;
					found = true;
					best_depth = depth;
					best_top = top;
					bcx = cx;
					bcz = cz;
					bi = t;
				}
			}
		if (!found) return out;
		out.resize(4);
		out.set(0, double(bcx));
		out.set(1, double(bcz));
		out.set(2, double(bi));
		out.set(3, best_top);
		return out;
	}
};
