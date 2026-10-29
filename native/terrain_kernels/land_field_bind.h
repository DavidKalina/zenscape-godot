// ZenScapeLandField: the endless land's field (land_field.h) for GDScript.
// scripts/endless/land_field.gd (LandField) makes one per field it would have
// made (each chunk worker its own, as before) and reads it through these
// methods and properties; callers never see this class. Per-point calls
// mirror the GDScript field's; `build_chunk` and `grid` do a whole grid in
// one call (land_stream `_build`, endless_grass `grow_cell`).
#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <algorithm>
#include <vector>
#include "land_field.h"

using namespace godot;

#define ZSL_KNOB(name) \
	double get_##name() const { return f.name; } \
	void set_##name(double v) { f.name = v; }
#define ZSL_OUT(name) \
	double get_##name() const { return f.name; }
#define ZSL_BIND_KNOB(name) \
	ClassDB::bind_method(D_METHOD("get_" #name), &ZenScapeLandField::get_##name); \
	ClassDB::bind_method(D_METHOD("set_" #name, "value"), &ZenScapeLandField::set_##name); \
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, #name), "set_" #name, "get_" #name);
#define ZSL_BIND_OUT(name) \
	ClassDB::bind_method(D_METHOD("get_" #name), &ZenScapeLandField::get_##name); \
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, #name), "", "get_" #name);

class ZenScapeLandField : public RefCounted {
	GDCLASS(ZenScapeLandField, RefCounted)

	zsland::LandField f;

	static Vector2 v2(const zsland::V2 &v) { return Vector2(v.x, v.y); }

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("version"), &ZenScapeLandField::version);
		ClassDB::bind_method(D_METHOD("configure", "seed", "floor_half", "knobs"), &ZenScapeLandField::configure);
		ClassDB::bind_method(D_METHOD("sample", "x", "z"), &ZenScapeLandField::sample);
		ClassDB::bind_method(D_METHOD("height", "x", "z"), &ZenScapeLandField::height);
		ClassDB::bind_method(D_METHOD("shape", "x", "z"), &ZenScapeLandField::shape);
		ClassDB::bind_method(D_METHOD("river_y", "x", "z"), &ZenScapeLandField::river_y);
		ClassDB::bind_method(D_METHOD("river_drawn"), &ZenScapeLandField::river_drawn);
		ClassDB::bind_method(D_METHOD("calm_here"), &ZenScapeLandField::calm_here);
		ClassDB::bind_method(D_METHOD("sea_calm", "x", "z"), &ZenScapeLandField::sea_calm);
		ClassDB::bind_method(D_METHOD("snow_line"), &ZenScapeLandField::snow_line);
		ClassDB::bind_method(D_METHOD("colour", "x", "z", "y", "up", "meadow"), &ZenScapeLandField::colour);
		ClassDB::bind_method(D_METHOD("build_chunk", "x0", "z0", "step", "cells", "skirt_drop", "flow_max"), &ZenScapeLandField::build_chunk);
		ClassDB::bind_method(D_METHOD("grid", "x0", "z0", "step", "nx", "nz", "pad"), &ZenScapeLandField::grid);
		ClassDB::bind_method(D_METHOD("blend_grid", "fields", "slot_r", "slot_part", "regions", "corners", "cells", "ci0", "cj0", "cw", "lattice", "x0", "z0", "step", "nx", "nz", "pad"), &ZenScapeLandField::blend_grid);
		ClassDB::bind_method(D_METHOD("blend_chunk", "fields", "slot_r", "slot_part", "regions", "corners", "cells", "ci0", "cj0", "cw", "lattice", "x0", "z0", "step", "cells_n", "skirt_drop", "flow_max"), &ZenScapeLandField::blend_chunk);
		ClassDB::bind_method(D_METHOD("blend_colours", "fields", "slot_r", "slot_part", "regions", "corners", "cells", "ci0", "cj0", "cw", "lattice", "xs", "zs", "ys", "ups", "meadows"), &ZenScapeLandField::blend_colours);
		ClassDB::bind_method(D_METHOD("get_seed"), &ZenScapeLandField::get_seed);
		ADD_PROPERTY(PropertyInfo(Variant::INT, "seed"), "", "get_seed");
		ClassDB::bind_method(D_METHOD("get_old_land"), &ZenScapeLandField::get_old_land);
		ClassDB::bind_method(D_METHOD("set_old_land", "value"), &ZenScapeLandField::set_old_land);
		ADD_PROPERTY(PropertyInfo(Variant::BOOL, "old_land"), "set_old_land", "get_old_land");
		ClassDB::bind_method(D_METHOD("get_libm"), &ZenScapeLandField::get_libm);
		ClassDB::bind_method(D_METHOD("set_libm", "value"), &ZenScapeLandField::set_libm);
		ADD_PROPERTY(PropertyInfo(Variant::BOOL, "libm"), "set_libm", "get_libm");
		ZSL_BIND_KNOB(mountains)
		ZSL_BIND_KNOB(peaks)
		ZSL_BIND_KNOB(valleys)
		ZSL_BIND_KNOB(carve)
		ZSL_BIND_KNOB(carve_blocks)
		ZSL_BIND_KNOB(carve_ledges)
		ZSL_BIND_KNOB(carve_gullies)
		ZSL_BIND_KNOB(detail)
		ZSL_BIND_KNOB(rivers)
		ZSL_BIND_KNOB(river_width)
		ZSL_BIND_KNOB(river_drop)
		ZSL_BIND_KNOB(river_cut)
		ZSL_BIND_KNOB(river_fill)
		ZSL_BIND_KNOB(river_mouth)
		ZSL_BIND_KNOB(river_flare)
		ZSL_BIND_OUT(last_mountain)
		ZSL_BIND_OUT(last_inland)
		ZSL_BIND_OUT(last_valley)
		ZSL_BIND_OUT(last_half)
		ZSL_BIND_OUT(last_side)
		ZSL_BIND_OUT(last_floor)
		ZSL_BIND_OUT(last_cavity)
		ZSL_BIND_OUT(last_ridge)
		ZSL_BIND_OUT(last_river)
		ZSL_BIND_OUT(last_river_r)
		ZSL_BIND_OUT(last_river_w)
		ZSL_BIND_OUT(last_river_y)
		ClassDB::bind_method(D_METHOD("get_last_across"), &ZenScapeLandField::get_last_across);
		ADD_PROPERTY(PropertyInfo(Variant::VECTOR2, "last_across"), "", "get_last_across");
		ClassDB::bind_method(D_METHOD("get_last_river_flow"), &ZenScapeLandField::get_last_river_flow);
		ADD_PROPERTY(PropertyInfo(Variant::VECTOR2, "last_river_flow"), "", "get_last_river_flow");
	}

public:
	// The field itself, for other native kernels handed this object
	// (ZenScapeTrees, tree_cell.h); not bound.
	zsland::LandField &land() { return f; }

	// Bumped when the land's output or this interface changes, so LandField
	// refuses a stale library (and runs its GDScript field instead).
	// 2: `configure` takes the world's land recipe (land_field.gd recipe_defaults());
	// 3: and the built land's forms (ridge_crisp, notch, terrace, mesa keys).
	int64_t version() const { return 3; }

	// The flags LandField parsed (see land_field.gd), then the noises built.
	void configure(int64_t seed, double floor_half, const Dictionary &knobs) {
		f.seed = seed;
		f.floor_half = floor_half;
		f.mountains = double(knobs.get("mountains", 1.0));
		f.peaks = double(knobs.get("peaks", 1.0));
		f.valleys = double(knobs.get("valleys", 1.0));
		f.old_land = bool(knobs.get("old_land", false));
		f.carve = double(knobs.get("carve", 1.0));
		f.carve_blocks = double(knobs.get("carve_blocks", 1.0));
		f.carve_ledges = double(knobs.get("carve_ledges", 1.0));
		f.carve_gullies = double(knobs.get("carve_gullies", 1.0));
		f.rivers = double(knobs.get("rivers", 1.0));
		f.river_width = double(knobs.get("river_width", 1.0));
		f.river_drop = double(knobs.get("river_drop", 1.0));
		f.river_cut = double(knobs.get("river_cut", 1.0));
		f.river_fill = double(knobs.get("river_fill", 1.0));
		f.river_mouth = double(knobs.get("river_mouth", 1.0));
		f.river_flare = double(knobs.get("river_flare", 1.0));
		f.libm = bool(knobs.get("libm", false));
		// The land recipe (the world profile's `land`; keys left out keep
		// wilderness's values, land_field.gd recipe_defaults()).
#define ZS_RECIPE(key, member) f.member = double(knobs.get(key, f.member))
#define ZS_RECIPE2(key, mx, my) { const Vector2 v = knobs.get(key, Vector2(f.mx, f.my)); f.mx = v.x; f.my = v.y; }
		ZS_RECIPE("continent_scale", CONTINENT);
		ZS_RECIPE("continent_swing", CONTINENT_SWING);
		ZS_RECIPE("continent_lift", CONTINENT_LIFT);
		ZS_RECIPE("lowland", LOWLAND);
		ZS_RECIPE("hill_scale", HILLS);
		ZS_RECIPE("hill_tall", HILL_TALL);
		ZS_RECIPE("range_scale", RANGES);
		ZS_RECIPE("range_width", RANGE_WIDTH);
		ZS_RECIPE("range_mask_scale", RANGE_MASK);
		ZS_RECIPE2("range_band", RANGE_BAND_X, RANGE_BAND_Y);
		ZS_RECIPE("warp_scale", WARP);
		ZS_RECIPE("warp_move", WARP_MOVE);
		ZS_RECIPE("ridge_scale", RIDGES);
		ZS_RECIPE2("peak_tall", PEAK_TALL_X, PEAK_TALL_Y);
		ZS_RECIPE("peak_scale", PEAK_SCALE);
		ZS_RECIPE("meadow_scale", MEADOWS);
		ZS_RECIPE2("meadow_band", MEADOW_BAND_X, MEADOW_BAND_Y);
		ZS_RECIPE("meadow_keep", MEADOW_KEEP);
		ZS_RECIPE("meadow_above", MEADOW_ABOVE);
		ZS_RECIPE("valley_scale", VALLEYS);
		ZS_RECIPE("valley_warp_scale", VALLEY_WARP);
		ZS_RECIPE("valley_warp_move", VALLEY_WARP_MOVE);
		ZS_RECIPE2("valley_swing", VALLEY_SWING_X, VALLEY_SWING_Y);
		ZS_RECIPE2("valley_side", VALLEY_SIDE_X, VALLEY_SIDE_Y);
		ZS_RECIPE("valley_keep", VALLEY_KEEP);
		ZS_RECIPE("snow", SNOW);
		// Version 3: the built land's forms.
		ZS_RECIPE("ridge_crisp", RIDGE_CRISP);
		ZS_RECIPE("notch", NOTCH);
		ZS_RECIPE("notch_scale", NOTCH_SCALE);
		ZS_RECIPE2("notch_width", NOTCH_WIDTH_X, NOTCH_WIDTH_Y);
		ZS_RECIPE("terrace", TERRACE);
		ZS_RECIPE("terrace_step", TERRACE_STEP);
		ZS_RECIPE("terrace_flat", TERRACE_FLAT);
		ZS_RECIPE("terrace_scale", TERRACE_SCALE);
		ZS_RECIPE2("terrace_band", TERRACE_BAND_X, TERRACE_BAND_Y);
		ZS_RECIPE("mesa", MESA);
		ZS_RECIPE("mesa_tall", MESA_TALL);
		ZS_RECIPE("mesa_scale", MESA_SCALE);
		ZS_RECIPE("mesa_level", MESA_LEVEL);
		ZS_RECIPE("mesa_edge", MESA_EDGE);
		ZS_RECIPE("mesa_steps", MESA_STEPS);
		ZS_RECIPE("mesa_gap", MESA_GAP);
		ZS_RECIPE("mesa_keep", MESA_KEEP);
		ZS_RECIPE("mesa_mask_scale", MESA_MASK);
		ZS_RECIPE2("mesa_band", MESA_BAND_X, MESA_BAND_Y);
#undef ZS_RECIPE
#undef ZS_RECIPE2
		f.setup();
	}

	Vector2 sample(double x, double z) { return v2(f.sample(x, z)); }
	double height(double x, double z) { return f.height(x, z); }
	Dictionary shape(double x, double z) {
		f.shape_reset();
		const zsland::V2 s = f.sample(x, z);
		Dictionary d;
		d["height"] = double(s.x);
		d["meadow"] = double(s.y);
		d["mountain"] = f.last_mountain;
		d["inland"] = f.last_inland;
		d["valley"] = f.last_valley;
		d["half"] = f.last_half;
		d["side"] = f.last_side;
		d["across"] = v2(f.last_across);
		d["river"] = f.last_river;
		d["river_r"] = f.last_river_r;
		d["river_w"] = f.last_river_w;
		d["river_y"] = f.last_river_y;
		return d;
	}
	double river_y(double x, double z) { return f.river_y(x, z); }
	double river_drawn() const { return f.river_drawn(); }
	double calm_here() const { return f.calm_here(); }
	double sea_calm(double x, double z) { return f.sea_calm(x, z); }
	double snow_line() const { return f.snow_line(); }
	Color colour(double x, double z, double y, double up, double meadow) const {
		const zsland::C4 c = f.colour(x, z, y, up, meadow);
		return Color(c.r, c.g, c.b, c.a);
	}

	// land_stream `_build`'s arrays for the chunk whose corner is (x0, z0):
	// its (cells+1)^2 grid at `step` m, sampled with a one-sample border for
	// the normals, then the skirt's four edges dropped `skirt_drop` m; the
	// river's flow packed at +-flow_max m/s. The same bits as the GDScript loop.
	Dictionary build_chunk(double x0, double z0, double step, int64_t cells, double skirt_drop, double flow_max) {
		f.detail = step;
		const int n = int(cells) + 1;
		const int w = n + 2;
		std::vector<float> hs(size_t(w) * w), ms(size_t(w) * w), rv(size_t(w) * w * 5);
		std::vector<uint8_t> cv(size_t(w) * w * 2);
		for (int j = 0; j < w; ++j) {
			for (int i = 0; i < w; ++i) {
				const zsland::V2 got = f.sample(x0 + double(i - 1) * step, z0 + double(j - 1) * step);
				const int k = j * w + i;
				hs[k] = got.x;
				ms[k] = got.y;
				cv[k * 2] = uint8_t(int64_t(zsland::clampf(f.last_cavity, 0.0, 1.0) * 255.0));
				cv[k * 2 + 1] = uint8_t(int64_t(zsland::clampf(f.last_ridge, 0.0, 1.0) * 255.0));
				const int q = k * 5;
				rv[q] = float(zsland::clampf(f.last_river_r, -1000.0, 1000.0));
				rv[q + 1] = float(f.last_river_w);
				rv[q + 2] = float(f.last_river_y > -zsland::INF ? f.last_river_y : zsland::LandField::SEA_Y - 100.0);
				rv[q + 3] = f.last_river_flow.x;
				rv[q + 4] = f.last_river_flow.y;
			}
		}
		const int total = n * n + 4 * n;
		PackedVector3Array verts, normals;
		PackedColorArray colours;
		PackedByteArray carved;
		PackedFloat32Array river, heights;
		verts.resize(total);
		normals.resize(total);
		colours.resize(total);
		carved.resize(total * 4);
		river.resize(total * 3);
		heights.resize(n * n);
		Vector3 *vp = verts.ptrw();
		Vector3 *np = normals.ptrw();
		Color *cp = colours.ptrw();
		uint8_t *kp = carved.ptrw();
		float *rp = river.ptrw();
		float *hp = heights.ptrw();
		for (int j = 0; j < n; ++j) {
			for (int i = 0; i < n; ++i) {
				const int k = (j + 1) * w + i + 1;
				const double y = hs[k];
				const double nx = double(hs[k - 1]) - double(hs[k + 1]);
				const double nzv = double(hs[k - w]) - double(hs[k + w]);
				const zsland::V3 normal = zsland::V3(nx, 2.0 * step, nzv).normalized();
				const int v = j * n + i;
				vp[v] = Vector3(float(double(i) * step), float(y), float(double(j) * step));
				np[v] = Vector3(normal.x, normal.y, normal.z);
				zsland::C4 c = f.colour(x0 + double(i) * step, z0 + double(j) * step, y, normal.y, ms[k]);
				c.a = ms[k];
				cp[v] = Color(c.r, c.g, c.b, c.a);
				kp[v * 4] = cv[k * 2];
				kp[v * 4 + 1] = cv[k * 2 + 1];
				kp[v * 4 + 2] = uint8_t(int64_t(zsland::clampf(double(rv[k * 5 + 3]) / flow_max * 0.5 + 0.5, 0.0, 1.0) * 255.0));
				kp[v * 4 + 3] = uint8_t(int64_t(zsland::clampf(double(rv[k * 5 + 4]) / flow_max * 0.5 + 0.5, 0.0, 1.0) * 255.0));
				rp[v * 3] = rv[k * 5];
				rp[v * 3 + 1] = rv[k * 5 + 1];
				rp[v * 3 + 2] = rv[k * 5 + 2];
				hp[v] = float(y);
			}
		}
		// The skirt: each edge's vertices again (-z, +x, +z, -x), dropped.
		const float drop = float(skirt_drop);
		for (int e = 0; e < 4; ++e) {
			for (int t = 0; t < n; ++t) {
				const int from = e == 0 ? t : (e == 1 ? t * n + (n - 1) : (e == 2 ? (n - 1) * n + t : t * n));
				const int v = n * n + e * n + t;
				vp[v] = Vector3(vp[from].x - 0.0f, vp[from].y - drop, vp[from].z - 0.0f);
				np[v] = np[from];
				cp[v] = cp[from];
				for (int b = 0; b < 4; ++b) kp[v * 4 + b] = kp[from * 4 + b];
				rp[v * 3] = rp[from * 3];
				rp[v * 3 + 1] = -rp[from * 3 + 1];
				rp[v * 3 + 2] = rp[from * 3 + 2];
			}
		}
		Dictionary out;
		out["verts"] = verts;
		out["normals"] = normals;
		out["colours"] = colours;
		out["carved"] = carved;
		out["river"] = river;
		out["heights"] = heights;
		return out;
	}

	// The field over an nx by nz grid from (x0, z0), `pad` samples before it
	// each way (x = x0+(i-pad)*step): heights, meadows and `last_river` per
	// sample, row by row (endless_grass `grow_cell`'s probe grid).
	Dictionary grid(double x0, double z0, double step, int64_t nx, int64_t nz, int64_t pad) {
		PackedFloat32Array hs, ms, rs;
		hs.resize(nx * nz);
		ms.resize(nx * nz);
		rs.resize(nx * nz);
		float *hp = hs.ptrw();
		float *mp = ms.ptrw();
		float *rp = rs.ptrw();
		for (int64_t j = 0; j < nz; ++j) {
			for (int64_t i = 0; i < nx; ++i) {
				const zsland::V2 got = f.sample(x0 + double(i - pad) * step, z0 + double(j - pad) * step);
				hp[j * nx + i] = got.x;
				mp[j * nx + i] = got.y;
				rp[j * nx + i] = float(f.last_river);
			}
		}
		Dictionary out;
		out["heights"] = hs;
		out["meadows"] = ms;
		out["river"] = rs;
		return out;
	}

	// The regions world's band (land_blend.gd): `fields` the blend's slots
	// (each region's field, then the soft twins), `slot_r` each one's region,
	// `slot_part` its part (0 the whole weight, 1 the sharp share w*w of it, 2
	// the soft rest); the map's weights at the lattice corners round the box
	// (`corners`, cw corners a row from corner (ci0, cj0), `regions` a corner)
	// and each lattice cell's one region or -1 (`cells`, cw-1 a row), the
	// lattice `lattice` m. LandBlend `_at` and `_slot_weights` per point:
	// `slots_at` fills `w` (float32, as the GDScript's arrays) and returns the
	// point's one region, or -1 in the band.
	struct Band {
		std::vector<ZenScapeLandField *> fields;
		std::vector<int> slot_r, slot_part;
		const float *corners = nullptr;
		const int32_t *cells = nullptr;
		int regions = 0, ci0 = 0, cj0 = 0, cw = 0;
		double lattice = 64.0;

		bool read(const Array &fs, const PackedInt32Array &sr, const PackedByteArray &sp, int64_t n, const PackedFloat32Array &cs, const PackedInt32Array &cl, int64_t i0, int64_t j0, int64_t w, double size) {
			for (int64_t s = 0; s < fs.size(); ++s) {
				ZenScapeLandField *k = Object::cast_to<ZenScapeLandField>(fs[s]);
				if (k == nullptr || s >= sr.size() || s >= sp.size()) return false;
				fields.push_back(k);
				slot_r.push_back(sr[s]);
				slot_part.push_back(sp[s]);
			}
			regions = int(n);
			ci0 = int(i0);
			cj0 = int(j0);
			cw = int(w);
			lattice = size;
			corners = cs.ptr();
			cells = cl.ptr();
			return !fields.empty() && cw >= 2;
		}
		int slots_at(double x, double z, float *w) const {
			const double fx = x / lattice, fz = z / lattice;
			const int64_t i = int64_t(std::floor(fx)), j = int64_t(std::floor(fz));
			const int li = int(i) - ci0, lj = int(j) - cj0;
			const int one = cells[lj * (cw - 1) + li];
			if (one >= 0) return one;
			const double tx = fx - double(i), tz = fz - double(j);
			const float *a = corners + (lj * cw + li) * regions, *b = a + regions, *c = a + cw * regions, *d = c + regions;
			for (size_t s = 0; s < fields.size(); ++s) {
				const int r = slot_r[s];
				const double ab = double(a[r]) + (double(b[r]) - double(a[r])) * tx;
				const double cd = double(c[r]) + (double(d[r]) - double(c[r])) * tx;
				double v = double(float(ab + (cd - ab) * tz));
				if (slot_part[s] == 1) v *= v * v;
				else if (slot_part[s] == 2) v *= 1.0 - v * v;
				w[s] = float(v);
			}
			return -1;
		}
		// The slot weights wholly in region `one` (its whole weight, or its
		// sharp share 1 and its twin's rest 0), as `_slot_weights` of a one-hot.
		void slots_of(int one, float *w) const {
			for (size_t s = 0; s < fields.size(); ++s) w[s] = (slot_r[s] == one && slot_part[s] != 2) ? 1.0f : 0.0f;
		}
	};

	// LandBlend `build_chunk` (a chunk in the band) in one call: each slot with
	// weight over the chunk (or its one-sample rim) builds it natively, then
	// the per-vertex blend (heights, the normals of the blended surface, meadow,
	// the carve's bytes, the river's floats, each slot's colour of the blended
	// point by weight) and the skirt, as the GDScript line for line. The
	// lattice is the chunk's (LATTICE*2^k, `lattice_k`).
	Dictionary blend_chunk(const Array &fs, const PackedInt32Array &sr, const PackedByteArray &sp, int64_t regions, const PackedFloat32Array &cs, const PackedInt32Array &cl,
			int64_t ci0, int64_t cj0, int64_t cw, double lattice, double x0, double z0, double step, int64_t cells, double skirt_drop, double flow_max) {
		Dictionary out;
		Band band;
		if (!band.read(fs, sr, sp, regions, cs, cl, ci0, cj0, cw, lattice)) return out;
		const int ns = int(band.fields.size());
		const int n = int(cells) + 1;
		const int w = n + 2;
		std::vector<float> ws(size_t(w) * w * ns);
		std::vector<uint8_t> used(size_t(ns), 0);
		for (int j = 0; j < w; ++j) {
			for (int i = 0; i < w; ++i) {
				float *q = ws.data() + size_t((j * w + i) * ns);
				const int one = band.slots_at(x0 + double(i - 1) * step, z0 + double(j - 1) * step, q);
				if (one >= 0) band.slots_of(one, q);
				for (int r = 0; r < ns; ++r)
					if (q[r] > 0.0f) used[size_t(r)] = 1;
			}
		}
		// Each slot's build, held (the arrays) and read through raw pointers
		// (godot-cpp's packed-array [] is an engine call a read).
		struct Made {
			PackedFloat32Array heights, river;
			PackedVector3Array normals;
			PackedColorArray colours;
			PackedByteArray carved;
			const float *h = nullptr, *rv = nullptr;
			const Vector3 *nm = nullptr;
			const Color *col = nullptr;
			const uint8_t *cb = nullptr;
		};
		std::vector<Made> made(static_cast<size_t>(ns));
		for (int r = 0; r < ns; ++r) {
			if (!used[size_t(r)]) continue;
			const Dictionary m = band.fields[size_t(r)]->build_chunk(x0, z0, step, cells, skirt_drop, flow_max);
			made[size_t(r)].heights = m["heights"];
			made[size_t(r)].river = m["river"];
			made[size_t(r)].normals = m["normals"];
			made[size_t(r)].colours = m["colours"];
			made[size_t(r)].carved = m["carved"];
			Made &k = made[size_t(r)];
			k.h = k.heights.ptr();
			k.rv = k.river.ptr();
			k.nm = k.normals.ptr();
			k.col = k.colours.ptr();
			k.cb = k.carved.ptr();
		}
		const int total = n * n + 4 * n;
		PackedVector3Array verts, normals;
		PackedColorArray colours;
		PackedByteArray carved;
		PackedFloat32Array river, heights;
		verts.resize(total);
		normals.resize(total);
		colours.resize(total);
		carved.resize(total * 4);
		river.resize(total * 3);
		heights.resize(n * n);
		Vector3 *vp = verts.ptrw();
		Vector3 *np = normals.ptrw();
		Color *cp = colours.ptrw();
		uint8_t *bp = carved.ptrw();
		float *rp = river.ptrw();
		float *hp = heights.ptrw();
		const double inv = 1.0 / (2.0 * step);
		const double sea = -40.0;
		for (int j = 0; j < n; ++j) {
			for (int i = 0; i < n; ++i) {
				const int v = j * n + i;
				const float *q = ws.data() + size_t(((j + 1) * w + i + 1) * ns);
				double y = 0.0, gx = 0.0, gz = 0.0, meadow = 0.0, c0 = 0.0, c1 = 0.0, c2 = 0.0, c3 = 0.0, rr = 0.0, rw = 0.0, ry = 0.0, wet = 0.0;
				for (int r = 0; r < ns; ++r) {
					if (!used[size_t(r)]) continue;
					const double wt = q[r];
					const Made &m = made[size_t(r)];
					const double h = m.h[v];
					// The weight's slope (zero where the rim is wholly one region).
					gx += h * (double(q[ns + r]) - double(q[-ns + r])) * inv;
					gz += h * (double(q[w * ns + r]) - double(q[-w * ns + r])) * inv;
					if (wt <= 0.0) continue;
					const Vector3 nm = m.nm[v];
					y += wt * h;
					gx -= wt * double(nm.x) / double(nm.y);
					gz -= wt * double(nm.z) / double(nm.y);
					meadow += wt * double(m.col[v].a);
					c0 += wt * double(m.cb[v * 4]);
					c1 += wt * double(m.cb[v * 4 + 1]);
					c2 += wt * double(m.cb[v * 4 + 2]);
					c3 += wt * double(m.cb[v * 4 + 3]);
					rr += wt * double(m.rv[v * 3]);
					rw += wt * double(m.rv[v * 3 + 1]);
					const double level = m.rv[v * 3 + 2];
					if (level > sea - 99.0) {
						ry += wt * level;
						wet += wt;
					}
				}
				const Vector3 normal = Vector3(float(-gx), 1.0f, float(-gz)).normalized();
				vp[v] = Vector3(float(i * step), float(y), float(j * step));
				np[v] = normal;
				hp[v] = float(y);
				Color c(0, 0, 0, 0);
				for (int r = 0; r < ns; ++r) {
					const float wt = q[r];
					if (wt <= 0.0f) continue;
					const zsland::C4 k = band.fields[size_t(r)]->f.colour(x0 + i * step, z0 + j * step, y, double(normal.y), meadow);
					c += Color(k.r, k.g, k.b, k.a) * wt;
				}
				c.a = float(meadow);
				cp[v] = c;
				bp[v * 4] = uint8_t(int64_t(std::round(c0)));
				bp[v * 4 + 1] = uint8_t(int64_t(std::round(c1)));
				bp[v * 4 + 2] = uint8_t(int64_t(std::round(c2)));
				bp[v * 4 + 3] = uint8_t(int64_t(std::round(c3)));
				rp[v * 3] = float(rr);
				rp[v * 3 + 1] = float(rw);
				rp[v * 3 + 2] = float(wet > 0.0 ? ry / wet : sea - 100.0);
			}
		}
		// The skirt: each edge's vertices again, dropped.
		for (int e = 0; e < 4; ++e) {
			for (int t = 0; t < n; ++t) {
				const int from = e == 0 ? t : (e == 1 ? t * n + int(cells) : (e == 2 ? int(cells) * n + t : t * n));
				const int v = n * n + e * n + t;
				vp[v] = vp[from] - Vector3(0.0f, float(skirt_drop), 0.0f);
				np[v] = np[from];
				cp[v] = cp[from];
				for (int b = 0; b < 4; ++b) bp[v * 4 + b] = bp[from * 4 + b];
				rp[v * 3] = rp[from * 3];
				rp[v * 3 + 1] = -rp[from * 3 + 1];
				rp[v * 3 + 2] = rp[from * 3 + 2];
			}
		}
		out["verts"] = verts;
		out["normals"] = normals;
		out["colours"] = colours;
		out["carved"] = carved;
		out["river"] = river;
		out["heights"] = heights;
		return out;
	}

	// LandBlend `grid` (land_field.gd `_grid` for a box reaching the band) in
	// one call: each point the one region's sample where it lies wholly in
	// one, else every slot with weight there sampled and blended (heights,
	// meadow, the river's distance clamped at 1000 m), as LandBlend `_mix`.
	Dictionary blend_grid(const Array &fs, const PackedInt32Array &sr, const PackedByteArray &sp, int64_t regions, const PackedFloat32Array &cs, const PackedInt32Array &cl,
			int64_t ci0, int64_t cj0, int64_t cw, double lattice, double x0, double z0, double step, int64_t nx, int64_t nz, int64_t pad) {
		Dictionary out;
		Band band;
		if (!band.read(fs, sr, sp, regions, cs, cl, ci0, cj0, cw, lattice)) return out;
		PackedFloat32Array hs, ms, rs;
		hs.resize(nx * nz);
		ms.resize(nx * nz);
		rs.resize(nx * nz);
		float *hp = hs.ptrw();
		float *mp = ms.ptrw();
		float *rp = rs.ptrw();
		std::vector<float> w(band.fields.size());
		for (int64_t j = 0; j < nz; ++j) {
			for (int64_t i = 0; i < nx; ++i) {
				const double x = x0 + double(i - pad) * step, z = z0 + double(j - pad) * step;
				const int64_t v = j * nx + i;
				const int one = band.slots_at(x, z, w.data());
				if (one >= 0) {
					zsland::LandField &k = band.fields[size_t(one)]->f;
					const zsland::V2 got = k.sample(x, z);
					hp[v] = got.x;
					mp[v] = got.y;
					rp[v] = float(k.last_river);
					continue;
				}
				double h = 0.0, m = 0.0, river = 0.0;
				for (size_t s = 0; s < band.fields.size(); ++s) {
					const double wt = w[s];
					if (wt <= 0.0) continue;
					zsland::LandField &k = band.fields[s]->f;
					const zsland::V2 got = k.sample(x, z);
					h += wt * double(got.x);
					m += wt * double(got.y);
					river += wt * std::min(double(k.last_river), 1000.0);
				}
				hp[v] = float(h);
				mp[v] = float(m);
				rp[v] = float(river);
			}
		}
		out["heights"] = hs;
		out["meadows"] = ms;
		out["river"] = rs;
		return out;
	}

	// LandBlend `colour` at many points in one call (xs, zs, ys, ups, meadows
	// alike long): the one region's colour, else each slot's by weight.
	PackedColorArray blend_colours(const Array &fs, const PackedInt32Array &sr, const PackedByteArray &sp, int64_t regions, const PackedFloat32Array &cs, const PackedInt32Array &cl,
			int64_t ci0, int64_t cj0, int64_t cw, double lattice, const PackedFloat64Array &xs, const PackedFloat64Array &zs, const PackedFloat32Array &ys, const PackedFloat32Array &ups, const PackedFloat32Array &meadows) {
		PackedColorArray out;
		Band band;
		if (!band.read(fs, sr, sp, regions, cs, cl, ci0, cj0, cw, lattice)) return out;
		const int64_t n = xs.size();
		out.resize(n);
		Color *op = out.ptrw();
		std::vector<float> w(band.fields.size());
		const double *xp = xs.ptr(), *zp = zs.ptr();
		const float *yp = ys.ptr(), *upp = ups.ptr(), *mp = meadows.ptr();
		for (int64_t p = 0; p < n; ++p) {
			const double x = xp[p], z = zp[p], y = yp[p], up = upp[p], meadow = mp[p];
			const int one = band.slots_at(x, z, w.data());
			if (one >= 0) {
				const zsland::C4 c = band.fields[size_t(one)]->f.colour(x, z, y, up, meadow);
				op[p] = Color(c.r, c.g, c.b, c.a);
				continue;
			}
			Color c(0, 0, 0, 0);
			for (size_t s = 0; s < band.fields.size(); ++s) {
				if (w[s] <= 0.0f) continue;
				const zsland::C4 k = band.fields[s]->f.colour(x, z, y, up, meadow);
				c += Color(k.r, k.g, k.b, k.a) * w[s];
			}
			op[p] = c;
		}
		return out;
	}

	int64_t get_seed() const { return f.seed; }
	bool get_old_land() const { return f.old_land; }
	void set_old_land(bool v) { f.old_land = v; }
	bool get_libm() const { return f.libm; }
	void set_libm(bool v) { f.libm = v; }
	Vector2 get_last_across() const { return v2(f.last_across); }
	Vector2 get_last_river_flow() const { return v2(f.last_river_flow); }
	ZSL_KNOB(mountains)
	ZSL_KNOB(peaks)
	ZSL_KNOB(valleys)
	ZSL_KNOB(carve)
	ZSL_KNOB(carve_blocks)
	ZSL_KNOB(carve_ledges)
	ZSL_KNOB(carve_gullies)
	ZSL_KNOB(detail)
	ZSL_KNOB(rivers)
	ZSL_KNOB(river_width)
	ZSL_KNOB(river_drop)
	ZSL_KNOB(river_cut)
	ZSL_KNOB(river_fill)
	ZSL_KNOB(river_mouth)
	ZSL_KNOB(river_flare)
	ZSL_OUT(last_mountain)
	ZSL_OUT(last_inland)
	ZSL_OUT(last_valley)
	ZSL_OUT(last_half)
	ZSL_OUT(last_side)
	ZSL_OUT(last_floor)
	ZSL_OUT(last_cavity)
	ZSL_OUT(last_ridge)
	ZSL_OUT(last_river)
	ZSL_OUT(last_river_r)
	ZSL_OUT(last_river_w)
	ZSL_OUT(last_river_y)
};
