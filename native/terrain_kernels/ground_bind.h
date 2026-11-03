// ZenScapeGround: the flight's ground composite's broad phase for GDScript
// (scripts/endless/ground_native.gd). Each site owner publishes the world XZ
// rectangles where its `ground` / `inside` can answer anything but "nothing
// here" (one layer each, on change, not per query); `near` hands back the
// bit of every layer whose rectangles may hold a point, from one hash
// lookup (an owner's change re-marks only its own squares). GDScript then asks only those owners, so the answers are the
// owners' own (the rectangles only ever skip owners that would have said
// nothing). Main thread only: the study's ground queries publish and read
// it on the one thread.
#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <cmath>
#include <cstdint>
#include <unordered_map>
#include <vector>

using namespace godot;

class ZenScapeGround : public RefCounted {
	GDCLASS(ZenScapeGround, RefCounted)

	static constexpr int LAYERS = 16;
	// The hash's square (m): a rectangle marks every square it touches.
	double cell = 8.0;
	// Each layer's rectangles by the owner's id for them (a cell of arches,
	// a rock square, ...), so a change re-marks only its own squares.
	std::unordered_map<int64_t, std::vector<float>> owned[LAYERS];
	// Each marked square: how many of each layer's rectangles touch it, and
	// the bits of the layers with any.
	struct Square {
		uint32_t bits = 0;
		uint32_t n[LAYERS] = {};
	};
	std::unordered_map<int64_t, Square> grid;
	// The movers' rectangles (a few, republished as they move), each with
	// its layer's bit, tested one by one past the hash.
	std::vector<float> movers;
	std::vector<uint32_t> mover_bits;

	static int64_t key(int64_t ix, int64_t iz) { return (ix << 32) ^ (iz & 0xffffffffLL); }

	// Marks (`add`) or unmarks the squares of layer `l`'s rectangles `r`.
	void mark(int l, const std::vector<float> &r, bool add) {
		const uint32_t bit = uint32_t(1) << l;
		for (size_t i = 0; i + 3 < r.size(); i += 4) {
			const int64_t x0 = int64_t(std::floor(double(r[i]) / cell));
			const int64_t z0 = int64_t(std::floor(double(r[i + 1]) / cell));
			const int64_t x1 = int64_t(std::floor(double(r[i + 2]) / cell));
			const int64_t z1 = int64_t(std::floor(double(r[i + 3]) / cell));
			// A runaway rectangle (a bad publish) would flood the hash.
			if (x1 < x0 || z1 < z0 || (x1 - x0 + 1) * (z1 - z0 + 1) > 400000) continue;
			for (int64_t z = z0; z <= z1; ++z)
				for (int64_t x = x0; x <= x1; ++x) {
					if (add) {
						Square &q = grid[key(x, z)];
						q.n[l] += 1;
						q.bits |= bit;
						continue;
					}
					const auto it = grid.find(key(x, z));
					if (it == grid.end() || it->second.n[l] == 0) continue;
					if (--it->second.n[l] == 0) {
						it->second.bits &= ~bit;
						if (it->second.bits == 0) grid.erase(it);
					}
				}
		}
	}

	void drop_id(int l, int64_t id) {
		const auto it = owned[l].find(id);
		if (it == owned[l].end()) return;
		mark(l, it->second, false);
		owned[l].erase(it);
	}

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("version"), &ZenScapeGround::version);
		ClassDB::bind_method(D_METHOD("setup", "cell"), &ZenScapeGround::setup);
		ClassDB::bind_method(D_METHOD("publish", "layer", "rects"), &ZenScapeGround::publish);
		ClassDB::bind_method(D_METHOD("put", "layer", "id", "rects"), &ZenScapeGround::put);
		ClassDB::bind_method(D_METHOD("drop", "layer", "id"), &ZenScapeGround::drop);
		ClassDB::bind_method(D_METHOD("movers", "layer", "rects"), &ZenScapeGround::set_movers);
		ClassDB::bind_method(D_METHOD("near", "x", "z"), &ZenScapeGround::near);
		ClassDB::bind_method(D_METHOD("squares"), &ZenScapeGround::squares);
	}

public:
	// Bumped when this interface changes, so GroundNative refuses a stale
	// library (and asks every owner, as GDScript always did).
	int64_t version() const { return 2; }

	void setup(double p_cell) {
		cell = p_cell > 0.5 ? p_cell : 0.5;
		grid.clear();
		for (int l = 0; l < LAYERS; ++l)
			for (const auto &e : owned[l]) mark(l, e.second, true);
	}
	// Layer `layer`'s rectangles, world XZ: [min x, min z, max x, max z, ...],
	// replacing all it had.
	void publish(int64_t layer, const PackedFloat32Array &p_rects) {
		if (layer < 0 || layer >= LAYERS) return;
		const int l = int(layer);
		while (!owned[l].empty()) drop_id(l, owned[l].begin()->first);
		put(layer, 0, p_rects);
	}
	// The rectangles layer `layer` holds under `id` (replacing that id's
	// last ones; an empty array drops it). Only their squares are re-marked.
	void put(int64_t layer, int64_t id, const PackedFloat32Array &p_rects) {
		if (layer < 0 || layer >= LAYERS) return;
		const int l = int(layer);
		drop_id(l, id);
		if (p_rects.size() < 4) return;
		std::vector<float> &r = owned[l][id];
		r.assign(p_rects.ptr(), p_rects.ptr() + p_rects.size());
		mark(l, r, true);
	}
	void drop(int64_t layer, int64_t id) {
		if (layer < 0 || layer >= LAYERS) return;
		drop_id(int(layer), id);
	}
	// The movers of layer `layer` (replacing its last ones): rectangles as
	// `publish`'s, kept out of the hash so a move costs no rebuild.
	void set_movers(int64_t layer, const PackedFloat32Array &p_rects) {
		if (layer < 0 || layer >= LAYERS) return;
		const uint32_t bit = uint32_t(1) << layer;
		std::vector<float> kept;
		std::vector<uint32_t> kept_bits;
		for (size_t i = 0; i < mover_bits.size(); ++i) {
			if (mover_bits[i] == bit) continue;
			kept.insert(kept.end(), movers.begin() + i * 4, movers.begin() + i * 4 + 4);
			kept_bits.push_back(mover_bits[i]);
		}
		const float *r = p_rects.ptr();
		for (int64_t i = 0; i + 3 < p_rects.size(); i += 4) {
			kept.insert(kept.end(), r + i, r + i + 4);
			kept_bits.push_back(bit);
		}
		movers.swap(kept);
		mover_bits.swap(kept_bits);
	}
	// The bits of the layers that may hold world XZ (x, z).
	int64_t near(double x, double z) const {
		const auto it = grid.find(key(int64_t(std::floor(x / cell)), int64_t(std::floor(z / cell))));
		uint32_t m = it == grid.end() ? 0 : it->second.bits;
		const float *r = movers.data();
		for (size_t i = 0; i < mover_bits.size(); ++i, r += 4)
			if (x >= r[0] && z >= r[1] && x <= r[2] && z <= r[3]) m |= mover_bits[i];
		return int64_t(m);
	}
	// The hash's marked squares (for a look at what is published).
	int64_t squares() const {
		return int64_t(grid.size());
	}
};
