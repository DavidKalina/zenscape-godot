// ZenScapeCarve: LandField `sample`'s carve layers (land_carve.h) for
// GDScript. Each LandField owns one (a worker's LandField its own, so it is
// only ever read and written on one thread): `sample` publishes each square's
// sites as it finds them (`put`), then hands the field's height to `carve`.
#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/vector4.hpp>
#include <vector>
#include "land_carve.h"

using namespace godot;

class ZenScapeCarve : public RefCounted {
	GDCLASS(ZenScapeCarve, RefCounted)

	// The layers' squares: ponds, tunnels (their boxes, grown a metre),
	// slot halls, splits.
	zscarve::Squares sq[4];
	zscarve::Trig m;
	zscarve::PondAt c_pond;
	float c_pond_y = 0.0f;

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("version"), &ZenScapeCarve::version);
		ClassDB::bind_method(D_METHOD("setup", "ponds", "tunnels", "halls", "splits", "cells", "libm"), &ZenScapeCarve::setup);
		ClassDB::bind_method(D_METHOD("put", "layer", "x", "z", "site"), &ZenScapeCarve::put);
		ClassDB::bind_method(D_METHOD("carve", "x", "z", "base", "river"), &ZenScapeCarve::carve);
		ClassDB::bind_method(D_METHOD("pond"), &ZenScapeCarve::pond);
	}

public:
	// Bumped when the carve's output or this interface changes, so LandField
	// refuses a stale library (and carves in GDScript instead).
	int64_t version() const { return 1; }

	// Which layers are on, their squares' sizes (m), and the field's libm.
	void setup(bool ponds, bool tunnels, bool halls, bool splits, const PackedFloat64Array &cells, bool libm) {
		const bool on[4] = {ponds, tunnels, halls, splits};
		for (int k = 0; k < 4; ++k) {
			sq[k] = zscarve::Squares();
			sq[k].on = on[k];
			sq[k].cell = cells.size() > k ? cells[k] : 1.0;
		}
		m.libm = libm;
	}
	// Layer `layer`'s site for the square holding (x, z) (empty: none).
	void put(int64_t layer, double x, double z, const PackedFloat32Array &site) {
		if (layer < 0 || layer > 3) return;
		zscarve::Squares &q = sq[layer];
		q.put(q.key_of(x, z), site.ptr(), site.size());
	}
	// The field's height `base` at (x, z) (its `last_river` `river`) with the
	// ponds, halls and splits cut in: Vector3(height, 0; 1 where a pond's
	// reads hold (`pond`), 0), or y 2 where a square is not yet published and
	// 3 where a tunnel's box holds the point (LandField then works it in
	// GDScript).
	Vector3 carve(double x, double z, double base, double river) {
		const std::vector<float> *site[4] = {nullptr, nullptr, nullptr, nullptr};
		for (int k = 0; k < 4; ++k) {
			zscarve::Squares &q = sq[k];
			if (!q.on) continue;
			const int32_t at = q.find(q.key_of(x, z));
			if (at < 0) return Vector3(0, 2, 0);
			const std::vector<float> &s = q.sites[size_t(at)];
			if (s.empty()) continue;
			if (k == 1) {
				for (size_t i = 0; i + 3 < s.size(); i += 4)
					if (x >= s[i] && z >= s[i + 1] && x <= s[i + 2] && z <= s[i + 3]) return Vector3(0, 3, 0);
				continue;
			}
			site[k] = &s;
		}
		float h = float(base);
		float on = 0.0f;
		if (site[0]) {
			const float *p = site[0]->data();
			const zscarve::PondAt e = zscarve::pond_at(m, p, x, z);
			if (!e.far && e.out < zscarve::P_REACH) {
				if (e.out < river) {
					on = 1.0f;
					c_pond = e;
					c_pond_y = p[3];
				}
				if (e.out < zscarve::P_LIP_Y) h = float(zscarve::pond_carve(p, h, e));
			}
		}
		if (site[2]) h = float(zscarve::hall_carve(site[2]->data(), h, x, z));
		if (site[3]) {
			const zscarve::Split sp{site[3]->data(), m};
			h = float(sp.carve(h, x, z));
		}
		return Vector3(h, on, 0);
	}
	// The last `carve`'s pond reads where its y was 1: Vector4(outside its
	// edge, from its centre, its radius that way, its level).
	Vector4 pond() const { return Vector4(c_pond.out, c_pond.r, c_pond.edge, c_pond_y); }
};
