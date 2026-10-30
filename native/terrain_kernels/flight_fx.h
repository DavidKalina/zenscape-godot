// The endless flight's per-frame air and bird loops in C++
// (docs/design/endless-flight/native-react-birds-handoff.md), line for line
// with the GDScript they stand in for, which stays the reference:
//
//   ZenScapeMotes    scripts/endless/endless_motes.gd: the pollen specks'
//                    drift and the kicked grass bits' flight, each frame,
//                    into their multimesh buffers. GDScript keeps the
//                    spawning (its RNG, the land probes) and hands each new
//                    speck or bit over as a record.
//   ZenScapeRibbons  scripts/breeze_ribbons.gd `_draw`: the strokes' strips
//                    from the ribbons' paths.
//   ZenScapeBirds    scripts/endless/endless_birds.gd: a flock's flying birds
//                    on their springs (`_fly_birds`, `_pose_air`) once every
//                    bird in it flies, and every bird's part transforms
//                    (`_draw`). GDScript keeps the flocks, the perched life
//                    and every random draw.
//
// Matching GDScript: its numbers are doubles; Vector2/3, Basis, Color and
// the packed float arrays hold floats, a double meeting one narrowed first
// (isle_math.h's mirrors of the engine's math). The constants come from the
// scripts (`configure`), so there is one place to tune them. Any change to
// one side's maths must be made to the other.
#pragma once

#include "isle_math.h"
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <cmath>
#include <unordered_map>
#include <vector>

namespace zsfx {

using zs::V3;
using zs::Bs;
using zs::Tf;
using zs::Col;
using zs::clampf;
using zs::maxf;
using zs::minf;
using zs::lerpf;
using zs::smoothstep;

constexpr double TAU = 6.2831853071795864769252867666;

inline float f32(double d) { return float(d); }
// The engine's float cos and sin: the double result rounded, as the official
// build's runtime gives them (grass_cell.h `fcos`).
inline float fcos(float a) { return float(std::cos(double(a))); }
inline float fsin(float a) { return float(std::sin(double(a))); }

// Basis(axis, angle) as the engine builds it.
inline Bs axis_angle(const V3 &a, double angle_d) {
	const float angle = float(angle_d);
	Bs b;
	const V3 sq(a.x * a.x, a.y * a.y, a.z * a.z);
	const float cosine = fcos(angle);
	b.rows[0][0] = sq.x + cosine * (1.0f - sq.x);
	b.rows[1][1] = sq.y + cosine * (1.0f - sq.y);
	b.rows[2][2] = sq.z + cosine * (1.0f - sq.z);
	const float sine = fsin(angle);
	const float t = 1 - cosine;
	float xyzt = a.x * a.y * t;
	float zyxs = a.z * sine;
	b.rows[0][1] = xyzt - zyxs;
	b.rows[1][0] = xyzt + zyxs;
	xyzt = a.x * a.z * t;
	zyxs = a.y * sine;
	b.rows[0][2] = xyzt + zyxs;
	b.rows[2][0] = xyzt - zyxs;
	xyzt = a.y * a.z * t;
	zyxs = a.x * sine;
	b.rows[1][2] = xyzt - zyxs;
	b.rows[2][1] = xyzt + zyxs;
	return b;
}
inline Bs from_scale(const V3 &s) {
	Bs b;
	b.rows[0] = V3(s.x, 0, 0);
	b.rows[1] = V3(0, s.y, 0);
	b.rows[2] = V3(0, 0, s.z);
	return b;
}
// GDScript's move_toward and signf on doubles.
inline double move_toward(double from, double to, double delta) {
	return std::fabs(to - from) <= delta ? to : from + ((to - from) == 0 ? 0.0f : ((to - from) < 0 ? -1.0f : 1.0f)) * delta;
}
inline double signd(double v) { return v == 0 ? 0.0 : (v < 0 ? -1.0 : 1.0); }
inline float vmin(float a, float b) { return a < b ? a : b; }
inline float vmax(float a, float b) { return a > b ? a : b; }
// Vector2.distance_to.
inline float dist2(float ax, float ay, float bx, float by) {
	return std::sqrt((ax - bx) * (ax - bx) + (ay - by) * (ay - by));
}
inline double num(const godot::Dictionary &d, const char *k, double fallback) {
	return d.has(k) ? double(d[k]) : fallback;
}

// --- scripts/endless/endless_motes.gd -------------------------------------------------
struct Speck {
	V3 pos;
	double age = 0, life = 0, ground = 0, size = 0, phase = 0, drift = 0;
};
// A speck record: pos xyz, age, life, ground, size, phase, drift.
constexpr int SPECK_REC = 9;

struct Bit {
	V3 pos, vel, spin;
	Bs basis;
	Col colour;
	double ground = 0, age = 0, life = 0, length = 0, width = 0, phase = 0, settle = 0, rest = 0;
	bool landed = false;
};
// A bit record: pos xyz, vel xyz, ground, age, life, length, width, basis
// (its rows, 9), spin xyz, phase, settle, rest, colour rgba, landed.
constexpr int BIT_REC = 30;

// --- scripts/breeze_ribbons.gd ---------------------------------------------------------
// A ribbon's record for its strip: vel xyz, age, fade, weight, width, seed.
constexpr int RIBBON_REC = 8;

// --- scripts/endless/endless_birds.gd ---------------------------------------------------
enum { SAT, HOPPING, GROUND, FLYING, LANDING };
enum { P_SIT, P_HEAD, P_TUCK, P_FLY, P_WING_L, P_WING_R };
struct Bird {
	V3 p, v, off, face;
	double pitch = 0, roll = 0, t = 0, beat = 0, bound = 0, squash = 0, seed = 0;
};
// A flying bird's record (adopt, release): p, v, off, face (xyz each),
// pitch, roll, t, beat, bound, squash, seed.
constexpr int BIRD_REC = 19;
// A bird's record to draw: mode, p xyz, face x z, pitch, roll, squash,
// flick, peck, hop_t, look, bound, beat, v.y.
constexpr int DRAW_REC = 16;

} // namespace zsfx

using namespace godot;

class ZenScapeMotes : public RefCounted {
	GDCLASS(ZenScapeMotes, RefCounted)

	// Pollen.
	double reach = 22.0, wander = 0.45, drift = 0.55, opacity = 0.75;
	float high_x = 0.4f, high_y = 5.0f;
	zsfx::Col colour = zsfx::Col(1.0f, 0.9f, 0.62f);
	std::vector<zsfx::Speck> specks;
	std::vector<double> aged;
	PackedFloat32Array pbuf;
	// The kick.
	int64_t most = 240;
	double k_drag = 0.9, k_fall = 4.8, k_flat = 2.8, k_glide = 0.7, k_spin_drag = 1.3, k_level = 16.0, k_stir = 3.5;
	std::vector<zsfx::Bit> bits;
	PackedFloat32Array kbuf;

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("version"), &ZenScapeMotes::version);
		ClassDB::bind_method(D_METHOD("configure", "config"), &ZenScapeMotes::configure);
		ClassDB::bind_method(D_METHOD("pollen_count"), &ZenScapeMotes::pollen_count);
		ClassDB::bind_method(D_METHOD("pollen_clear"), &ZenScapeMotes::pollen_clear);
		ClassDB::bind_method(D_METHOD("pollen_put", "index", "record"), &ZenScapeMotes::pollen_put);
		ClassDB::bind_method(D_METHOD("pollen_age", "delta", "centre"), &ZenScapeMotes::pollen_age);
		ClassDB::bind_method(D_METHOD("pollen_move", "delta", "time", "air", "show"), &ZenScapeMotes::pollen_move);
		ClassDB::bind_method(D_METHOD("pollen_records"), &ZenScapeMotes::pollen_records);
		ClassDB::bind_method(D_METHOD("kick_count"), &ZenScapeMotes::kick_count);
		ClassDB::bind_method(D_METHOD("kick_add", "record"), &ZenScapeMotes::kick_add);
		ClassDB::bind_method(D_METHOD("kick_step", "delta", "time", "air"), &ZenScapeMotes::kick_step);
		ClassDB::bind_method(D_METHOD("kick_records"), &ZenScapeMotes::kick_records);
	}

public:
	int64_t version() const { return 1; }

	void configure(const Dictionary &c) {
		using zsfx::num;
		reach = num(c, "pollen_reach", reach);
		wander = num(c, "pollen_wander", wander);
		drift = num(c, "pollen_drift", drift);
		opacity = num(c, "pollen_opacity", opacity);
		if (c.has("pollen_high")) {
			const Vector2 h = c["pollen_high"];
			high_x = h.x;
			high_y = h.y;
		}
		if (c.has("pollen_colour")) {
			const Color k = c["pollen_colour"];
			colour = zsfx::Col(k.r, k.g, k.b, k.a);
		}
		pbuf.resize(int64_t(num(c, "pollen_count", 0)) * 20);
		most = int64_t(num(c, "kick", double(most)));
		kbuf.resize(most * 20);
		k_drag = num(c, "kick_drag", k_drag);
		k_fall = num(c, "kick_fall", k_fall);
		k_flat = num(c, "kick_flat_drag", k_flat);
		k_glide = num(c, "kick_glide", k_glide);
		k_spin_drag = num(c, "kick_spin_drag", k_spin_drag);
		k_level = num(c, "kick_level", k_level);
		k_stir = num(c, "kick_stir", k_stir);
	}

	// --- Pollen (endless_motes.gd `_pollen`) -------------------------------------------
	int64_t pollen_count() const { return int64_t(specks.size()); }
	void pollen_clear() { specks.clear(); }
	// Speck `index` set from a record (index == count appends one).
	void pollen_put(int64_t index, const PackedFloat64Array &r) {
		if (r.size() < zsfx::SPECK_REC || index < 0 || index > int64_t(specks.size())) return;
		zsfx::Speck s;
		s.pos = zsfx::V3(float(r[0]), float(r[1]), float(r[2]));
		s.age = r[3];
		s.life = r[4];
		s.ground = r[5];
		s.size = r[6];
		s.phase = r[7];
		s.drift = r[8];
		if (index == int64_t(specks.size())) specks.push_back(s);
		else specks[index] = s;
	}
	// Each speck a frame older; the ones spent or out of the disc round
	// `centre` (in order), for GDScript to spawn anew before `pollen_move`.
	PackedInt32Array pollen_age(double delta, const Vector2 &centre) {
		PackedInt32Array out;
		aged.resize(specks.size());
		for (size_t i = 0; i < specks.size(); ++i) {
			zsfx::Speck &s = specks[i];
			const double age = s.age + delta;
			s.age = age;
			aged[i] = age;
			if (age > s.life || double(zsfx::dist2(s.pos.x, s.pos.z, centre.x, centre.y)) > reach) out.push_back(int32_t(i));
		}
		return out;
	}
	// Each speck drifted and drawn (its age as it was before a respawn, as
	// the GDScript loop keeps it): the instance buffer, `pollen_count` of them.
	PackedFloat32Array pollen_move(double delta, double time, const Vector2 &air, double show) {
		using namespace zsfx;
		const int64_t n = int64_t(specks.size());
		if (pbuf.size() < n * 20) pbuf.resize(n * 20);
		float *o = pbuf.ptrw();
		const V3 drift_air = V3(f32(double(air.x) * drift), 0.0f, f32(double(air.y) * drift));
		for (int64_t i = 0; i < n; ++i) {
			Speck &s = specks[i];
			V3 p = s.pos;
			const double age = i < int64_t(aged.size()) ? aged[i] : s.age;
			const double ph = s.phase;
			const V3 w = V3(f32(std::sin(time * 0.7 + ph)), f32(0.35 * std::sin(time * 1.1 + ph * 1.7)), f32(std::cos(time * 0.6 + ph * 2.3))) * f32(wander);
			const V3 v = drift_air * f32(s.drift) + w;
			p += v * f32(delta);
			p.y = f32(clampf(double(p.y), s.ground + double(high_x) * 0.5, s.ground + double(high_y) * 1.2));
			s.pos = p;
			const double u = age / s.life;
			const double a = smoothstep(0.0, 0.15, u) * (1.0 - smoothstep(0.75, 1.0, u)) * opacity * show;
			const float size = f32(s.size);
			float *q = o + i * 20;
			q[0] = size; q[1] = 0.0f; q[2] = 0.0f; q[3] = p.x;
			q[4] = 0.0f; q[5] = size; q[6] = 0.0f; q[7] = p.y;
			q[8] = 0.0f; q[9] = 0.0f; q[10] = size; q[11] = p.z;
			q[12] = colour.r; q[13] = colour.g; q[14] = colour.b; q[15] = f32(a);
			q[16] = v.x; q[17] = v.y; q[18] = v.z; q[19] = 0.0f;
		}
		aged.clear();
		return pbuf;
	}
	// Every speck's record (for checks).
	PackedFloat64Array pollen_records() const {
		PackedFloat64Array out;
		for (const zsfx::Speck &s : specks) {
			const double r[zsfx::SPECK_REC] = { s.pos.x, s.pos.y, s.pos.z, s.age, s.life, s.ground, s.size, s.phase, s.drift };
			for (double x : r) out.push_back(x);
		}
		return out;
	}

	// --- The kick (endless_motes.gd `_kick`, `_throw`) ---------------------------------
	int64_t kick_count() const { return int64_t(bits.size()); }
	// A bit thrown (the oldest dropped when there are `kick` of them).
	void kick_add(const PackedFloat64Array &r) {
		if (r.size() < zsfx::BIT_REC) return;
		if (int64_t(bits.size()) >= most && !bits.empty()) bits.erase(bits.begin());
		zsfx::Bit b;
		const double *d = r.ptr();
		b.pos = zsfx::V3(float(d[0]), float(d[1]), float(d[2]));
		b.vel = zsfx::V3(float(d[3]), float(d[4]), float(d[5]));
		b.ground = d[6];
		b.age = d[7];
		b.life = d[8];
		b.length = d[9];
		b.width = d[10];
		for (int k = 0; k < 3; ++k) b.basis.rows[k] = zsfx::V3(float(d[11 + k * 3]), float(d[12 + k * 3]), float(d[13 + k * 3]));
		b.spin = zsfx::V3(float(d[20]), float(d[21]), float(d[22]));
		b.phase = d[23];
		b.settle = d[24];
		b.rest = d[25];
		b.colour = zsfx::Col(float(d[26]), float(d[27]), float(d[28]), float(d[29]));
		bits.push_back(b);
	}
	// Every bit a frame on (the spent ones dropped): the instance buffer,
	// `kick_count` of them.
	PackedFloat32Array kick_step(double delta, double time, const Vector2 &air2) {
		using namespace zsfx;
		const V3 air(air2.x, 0.0f, air2.y);
		if (kbuf.size() < int64_t(bits.size()) * 20) kbuf.resize(int64_t(bits.size()) * 20);
		float *o = kbuf.ptrw();
		int64_t n = 0;
		size_t keep = 0;
		for (size_t i = 0; i < bits.size(); ++i) {
			Bit b = bits[i];
			const double age = b.age + delta;
			if (age > b.life) continue;
			b.age = age;
			Bs turn = b.basis;
			const V3 face = turn.column(1);
			const double flat = std::fabs(double(face.y));
			V3 v = b.vel;
			V3 w = b.spin;
			bool landed = b.landed;
			if (!landed) {
				v += (air - v) * f32(clampf(k_drag * delta, 0.0, 1.0));
				v.y = f32(double(v.y) - k_fall * delta);
				if (v.y < 0.0f) {
					v.y = f32(double(v.y) * maxf(1.0 - k_flat * flat * delta, 0.0));
					const V3 low = V3(face.x, 0.0f, face.z) * f32(signd(double(face.y)));
					v += low * f32(k_glide) * f32(-double(v.y)) * f32(delta) * 4.0f;
				}
				w = w * f32(maxf(1.0 - k_spin_drag * delta, 0.0));
				const double settle = smoothstep(b.settle, b.settle + 0.6, age);
				const V3 up = V3(0, 1, 0) * f32(face.y >= 0.0f ? 1.0 : -1.0);
				w += face.cross(up) * f32(k_level) * f32(settle) * f32(delta);
				const double ph = b.phase * TAU;
				w += V3(f32(std::sin(time * 2.3 + ph)), f32(0.4 * std::sin(time * 1.7 + ph * 1.9)), f32(std::cos(time * 2.9 + ph * 2.7))) * f32(k_stir) * f32(settle) * f32(delta);
			}
			V3 p = b.pos + v * f32(delta);
			const double floor_y = b.ground + b.rest;
			if (!landed && double(p.y) < floor_y) {
				p.y = f32(floor_y);
				v = V3();
				w = V3();
				landed = true;
				b.landed = true;
				b.life = minf(b.life, age + 0.6);
			}
			b.vel = v;
			b.pos = p;
			const float rate = w.length();
			if (double(rate) > 1.0e-4) turn = (axis_angle(w / rate, double(rate) * delta) * turn).orthonormalized();
			b.basis = turn;
			b.spin = w;
			const double u = age / b.life;
			const double size = (1.0 - smoothstep(0.82, 1.0, u)) * smoothstep(0.0, 0.06, age);
			const double through = double((v - air).length());
			const double flutter = landed ? 0.0 : clampf(through / 6.0, 0.0, 1.0) * 0.85 + clampf(double(rate) / 4.0, 0.0, 1.0) * 0.15;
			float *q = o + n * 20;
			for (int k = 0; k < 3; ++k) {
				q[k * 4] = turn.rows[k].x;
				q[k * 4 + 1] = turn.rows[k].y;
				q[k * 4 + 2] = turn.rows[k].z;
			}
			q[3] = p.x; q[7] = p.y; q[11] = p.z;
			q[12] = b.colour.r; q[13] = b.colour.g; q[14] = b.colour.b; q[15] = 1.0f;
			q[16] = f32(b.width * size);
			q[17] = f32(b.length * size);
			q[18] = f32(b.phase);
			q[19] = f32(flutter);
			++n;
			bits[keep++] = b;
		}
		bits.resize(keep);
		return kbuf;
	}
	PackedFloat64Array kick_records() const {
		PackedFloat64Array out;
		for (const zsfx::Bit &b : bits) {
			out.push_back(b.pos.x); out.push_back(b.pos.y); out.push_back(b.pos.z);
			out.push_back(b.vel.x); out.push_back(b.vel.y); out.push_back(b.vel.z);
			out.push_back(b.age); out.push_back(b.life);
		}
		return out;
	}
};

class ZenScapeRibbons : public RefCounted {
	GDCLASS(ZenScapeRibbons, RefCounted)

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("version"), &ZenScapeRibbons::version);
		ClassDB::bind_method(D_METHOD("strips", "paths", "records", "opacity", "width_scale"), &ZenScapeRibbons::strips);
	}

public:
	int64_t version() const { return 1; }

	// breeze_ribbons.gd `_draw`: the strips of every ribbon with three or more
	// points, as [vertices, normals, uvs, uv2s, colors]; empty for none.
	// `records` RIBBON_REC per path; `opacity` OPACITY * opacity_scale.
	Array strips(const Array &paths, const PackedFloat64Array &records, double opacity, double width_scale) const {
		using namespace zsfx;
		int64_t segments = 0;
		for (int64_t r = 0; r < paths.size(); ++r) {
			const PackedVector3Array path = paths[r];
			if (path.size() >= 3) segments += path.size() - 1;
		}
		Array out;
		if (segments == 0) return out;
		PackedVector3Array verts, normals;
		PackedVector2Array uvs, uv2s;
		PackedColorArray colors;
		verts.resize(segments * 6);
		normals.resize(segments * 6);
		uvs.resize(segments * 6);
		uv2s.resize(segments * 6);
		colors.resize(segments * 6);
		Vector3 *vw = verts.ptrw();
		Vector3 *nw = normals.ptrw();
		Vector2 *uw = uvs.ptrw();
		Vector2 *u2w = uv2s.ptrw();
		Color *cw = colors.ptrw();
		int64_t at = 0;
		std::vector<float> along;
		for (int64_t r = 0; r < paths.size(); ++r) {
			const PackedVector3Array path_v = paths[r];
			const int64_t n = path_v.size();
			if (n < 3) continue;
			const double *rec = records.ptr() + r * RIBBON_REC;
			const V3 vel(f32(rec[0]), f32(rec[1]), f32(rec[2]));
			const double age = rec[3], fade = rec[4], weight = rec[5], width = rec[6], seed = rec[7];
			const Vector3 *pv = path_v.ptr();
			auto P = [&](int64_t i) { return V3(pv[i].x, pv[i].y, pv[i].z); };
			const double born = smoothstep(0.0, 0.7, age);
			const double alpha = opacity * weight * born * clampf(fade, 0.0, 1.0);
			double metres = 0.0;
			along.assign(1, 0.0f);
			for (int64_t i = 1; i < n; ++i) {
				metres += double(P(i).distance_to(P(i - 1)));
				along.push_back(f32(metres));
			}
			const double total = maxf(metres, 0.001);
			V3 prev_l;
			const Vector2 size(f32(width * width_scale), f32(alpha));
			const float tint = f32(seed * 0.01);
			for (int64_t i = 0; i < n; ++i) {
				V3 tangent = P(i + 1 < n - 1 ? i + 1 : n - 1) - P(i - 1 > 0 ? i - 1 : 0);
				if (double(tangent.length_squared()) < 1e-8) tangent = vel;
				tangent = tangent.normalized();
				const double u = double(along[i]) / total;
				if (i > 0) {
					const Color c0(0.0f, 0.0f, tint, f32(double(along[i - 1]) / total));
					const Color c1(0.0f, 0.0f, tint, f32(u));
					const double back = total - double(along[i - 1]);
					const double front = total - double(along[i]);
					const Vector3 a = pv[i - 1], b = pv[i];
					const Vector3 pl(prev_l.x, prev_l.y, prev_l.z), tg(tangent.x, tangent.y, tangent.z);
					const Vector2 ub0(f32(back), 0.0f), uf0(f32(front), 0.0f), uf1(f32(front), 1.0f), ub1(f32(back), 1.0f);
					vw[at] = a; vw[at + 1] = b; vw[at + 2] = b; vw[at + 3] = a; vw[at + 4] = b; vw[at + 5] = a;
					nw[at] = pl; nw[at + 1] = tg; nw[at + 2] = tg; nw[at + 3] = pl; nw[at + 4] = tg; nw[at + 5] = pl;
					uw[at] = ub0; uw[at + 1] = uf0; uw[at + 2] = uf1; uw[at + 3] = ub0; uw[at + 4] = uf1; uw[at + 5] = ub1;
					for (int k = 0; k < 6; ++k) u2w[at + k] = size;
					cw[at] = c0; cw[at + 1] = c1; cw[at + 2] = c1; cw[at + 3] = c0; cw[at + 4] = c1; cw[at + 5] = c0;
					at += 6;
				}
				prev_l = tangent;
			}
		}
		out.push_back(verts);
		out.push_back(normals);
		out.push_back(uvs);
		out.push_back(uv2s);
		out.push_back(colors);
		return out;
	}
};

class ZenScapeBirds : public RefCounted {
	GDCLASS(ZenScapeBirds, RefCounted)

	// The script's numbers (`configure`).
	double span = 0.85, avoid = 3.0, response = 4.0, crouch = 0.12, beat_rate = 15.0;
	float bound_x = 0.34f, bound_y = 0.22f;
	int64_t max_birds = 160, parts = 24;
	zsfx::V3 head_at, wing_at[2];
	std::unordered_map<int64_t, std::vector<zsfx::Bird>> flocks;
	int64_t next_id = 1;
	// Drawing: every part's transforms, MAX_BIRDS a part (as `_data`).
	std::vector<float> data;
	std::vector<int32_t> counts;
	zsfx::V3 lo, hi;
	int64_t drawn = 0;

	void put(int64_t k, const zsfx::Tf &t) {
		float *q = data.data() + (k * max_birds + counts[k]) * 12;
		counts[k] += 1;
		q[0] = t.basis.rows[0].x; q[1] = t.basis.rows[0].y; q[2] = t.basis.rows[0].z; q[3] = t.origin.x;
		q[4] = t.basis.rows[1].x; q[5] = t.basis.rows[1].y; q[6] = t.basis.rows[1].z; q[7] = t.origin.y;
		q[8] = t.basis.rows[2].x; q[9] = t.basis.rows[2].y; q[10] = t.basis.rows[2].z; q[11] = t.origin.z;
	}

	// `_draw`'s body for one bird.
	void draw_one(int64_t k0, double sz, bool settle, int64_t mode, const zsfx::V3 &p, float face_x, float face_z, double pitch, double roll,
			double squash, double flick, double peck, double hop_t, double look, double bound, double beat, float vy) {
		using namespace zsfx;
		if (drawn >= max_birds) return;
		drawn += 1;
		const double yaw = std::atan2(-double(face_x), -double(face_z));
		const bool airborne = mode == FLYING || mode == LANDING;
		if (!airborne) {
			pitch -= 0.18 * flick;
			if (mode == GROUND && hop_t < 0.0) pitch -= 0.45 * maxf(0.0, std::sin(peck * 9.0));
		}
		const double sq = squash;
		const V3 s = V3(f32(1.0 - 0.1 * sq), f32(1.0 + (sq < 0.0 ? 0.15 * sq : -0.08 * sq)), f32(1.0 + maxf(sq, 0.0) * 0.15)) * f32(sz);
		const Bs basis = axis_angle(V3(0, 1, 0), yaw) * axis_angle(V3(1, 0, 0), pitch) * axis_angle(V3(0, 0, 1), roll) * from_scale(s);
		const Tf body(basis, p);
		lo = V3(vmin(lo.x, p.x), vmin(lo.y, p.y), vmin(lo.z, p.z));
		hi = V3(vmax(hi.x, p.x), vmax(hi.y, p.y), vmax(hi.z, p.z));
		if (!airborne) {
			put(k0 + P_SIT, body);
			put(k0 + P_HEAD, body * Tf(axis_angle(V3(0, 1, 0), look), head_at));
			return;
		}
		const bool beating = mode == LANDING || bound < double(bound_x) * (settle ? 1.0 : 1.4) || double(vy) > 1.2;
		if (!beating) {
			put(k0 + P_TUCK, body);
			return;
		}
		put(k0 + P_FLY, body);
		const bool landing = mode == LANDING;
		const double lift = std::sin(beat) * (landing ? 0.55 : 0.95) + (landing ? 0.5 : 0.15);
		put(k0 + P_WING_L, body * Tf(axis_angle(V3(0, 0, 1), -lift), wing_at[0]));
		put(k0 + P_WING_R, body * Tf(axis_angle(V3(0, 0, 1), lift), wing_at[1]));
	}

	// `_turn`: level heading `a` turned `t` of the way to `b`.
	static zsfx::V3 turn(const zsfx::V3 &a, const zsfx::V3 &b, double t) {
		zsfx::V3 turned = a.lerp(b, float(t));
		turned.y = 0.0f;
		return double(turned.length_squared()) > 0.0001 ? turned.normalized() : b;
	}

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("version"), &ZenScapeBirds::version);
		ClassDB::bind_method(D_METHOD("configure", "config"), &ZenScapeBirds::configure);
		ClassDB::bind_method(D_METHOD("adopt", "records"), &ZenScapeBirds::adopt);
		ClassDB::bind_method(D_METHOD("records", "id"), &ZenScapeBirds::records);
		ClassDB::bind_method(D_METHOD("drop", "id"), &ZenScapeBirds::drop);
		ClassDB::bind_method(D_METHOD("fly", "id", "delta", "clock", "anchor", "anchor_v", "heading", "size", "spread", "ground", "plane"), &ZenScapeBirds::fly);
		ClassDB::bind_method(D_METHOD("draw_begin"), &ZenScapeBirds::draw_begin);
		ClassDB::bind_method(D_METHOD("draw_flock", "id", "k0", "size", "settle"), &ZenScapeBirds::draw_flock);
		ClassDB::bind_method(D_METHOD("draw_records", "records", "k0", "size", "settle"), &ZenScapeBirds::draw_records);
		ClassDB::bind_method(D_METHOD("draw_counts"), &ZenScapeBirds::draw_counts);
		ClassDB::bind_method(D_METHOD("draw_box"), &ZenScapeBirds::draw_box);
		ClassDB::bind_method(D_METHOD("drawn"), &ZenScapeBirds::get_drawn);
		ClassDB::bind_method(D_METHOD("part", "k"), &ZenScapeBirds::part);
	}

public:
	int64_t version() const { return 1; }

	void configure(const Dictionary &c) {
		using zsfx::num;
		span = num(c, "span", span);
		avoid = num(c, "avoid", avoid);
		response = num(c, "response", response);
		crouch = num(c, "crouch", crouch);
		beat_rate = num(c, "beat", beat_rate);
		if (c.has("bound")) {
			const Vector2 b = c["bound"];
			bound_x = b.x;
			bound_y = b.y;
		}
		max_birds = int64_t(num(c, "max_birds", double(max_birds)));
		parts = int64_t(num(c, "parts", double(parts)));
		if (c.has("head_at")) head_at = zsfx::V3(Vector3(c["head_at"]));
		if (c.has("wing_l")) wing_at[0] = zsfx::V3(Vector3(c["wing_l"]));
		if (c.has("wing_r")) wing_at[1] = zsfx::V3(Vector3(c["wing_r"]));
		data.assign(size_t(parts * max_birds * 12), 0.0f);
		counts.assign(size_t(parts), 0);
	}

	// A flock whose birds all fly, taken over from their records: its id.
	int64_t adopt(const PackedFloat64Array &r) {
		const int64_t n = r.size() / zsfx::BIRD_REC;
		std::vector<zsfx::Bird> list(static_cast<size_t>(n));
		const double *d = r.ptr();
		for (int64_t i = 0; i < n; ++i, d += zsfx::BIRD_REC) {
			zsfx::Bird &b = list[i];
			b.p = zsfx::V3(float(d[0]), float(d[1]), float(d[2]));
			b.v = zsfx::V3(float(d[3]), float(d[4]), float(d[5]));
			b.off = zsfx::V3(float(d[6]), float(d[7]), float(d[8]));
			b.face = zsfx::V3(float(d[9]), float(d[10]), float(d[11]));
			b.pitch = d[12];
			b.roll = d[13];
			b.t = d[14];
			b.beat = d[15];
			b.bound = d[16];
			b.squash = d[17];
			b.seed = d[18];
		}
		const int64_t id = next_id++;
		flocks[id] = std::move(list);
		return id;
	}
	// A flock's birds as records (to hand back, or for checks).
	PackedFloat64Array records(int64_t id) const {
		PackedFloat64Array out;
		auto it = flocks.find(id);
		if (it == flocks.end()) return out;
		out.resize(int64_t(it->second.size()) * zsfx::BIRD_REC);
		double *d = out.ptrw();
		for (const zsfx::Bird &b : it->second) {
			const double r[zsfx::BIRD_REC] = { b.p.x, b.p.y, b.p.z, b.v.x, b.v.y, b.v.z, b.off.x, b.off.y, b.off.z, b.face.x, b.face.y, b.face.z,
				b.pitch, b.roll, b.t, b.beat, b.bound, b.squash, b.seed };
			for (double x : r) *d++ = x;
		}
		return out;
	}
	void drop(int64_t id) { flocks.erase(id); }

	// `_fly_birds` for a flock all in flight, not settling, nor bursting or
	// scattering (so the place's pull is whole and the wings beat at BEAT).
	void fly(int64_t id, double delta, double clock, const Vector3 &anchor, const Vector3 &anchor_v, const Vector3 &heading,
			double size, double spread, double ground, const Vector3 &plane) {
		using namespace zsfx;
		auto it = flocks.find(id);
		if (it == flocks.end()) return;
		std::vector<Bird> &list = it->second;
		const V3 a(anchor), av(anchor_v), fx(heading), pp(plane);
		const V3 rx = fx.cross(V3(0, 1, 0));
		const double keep = span * size * 1.1 * std::sqrt(double(int64_t(list.size()) + 1)) * spread;
		const double damp = 1.0 - std::exp(-delta * response);
		const double gain = response * 0.25 * 1.0;
		const double turn_k = 1.0 - std::exp(-delta * 8.0);
		const double roll_k = 1.0 - std::exp(-delta * 6.0);
		const double pitch_k = 1.0 - std::exp(-delta * 10.0);
		const double bound_len = double(bound_x) + double(bound_y);
		for (Bird &b : list) {
			b.t += delta;
			// _place_off
			const V3 w = b.off + V3(f32(std::sin(clock * 0.5 + b.seed)), f32(std::sin(clock * 0.37 + b.seed * 1.7) * 0.5), f32(std::cos(clock * 0.43 + b.seed))) * f32(0.12);
			const V3 off = rx * w.x * f32(keep) + V3(0, 1, 0) * w.y * f32(keep) * f32(0.6) - fx * w.z * f32(keep);
			V3 place = a + off;
			const V3 dp = place - pp;
			const double lp = double(dp.length());
			if (lp < avoid) place += dp / f32(maxf(lp, 0.01)) * f32(avoid - lp);
			place.y = f32(maxf(double(place.y), ground + 1.5));
			const V3 want = av + (place - b.p) * f32(gain);
			b.v = b.v.lerp(want, f32(damp * (b.t < crouch + 0.3 ? 0.35 : 1.0)));
			b.p += b.v * f32(delta);
			if (double(b.p.y) < ground + 0.5) {
				b.p.y = f32(ground + 0.5);
				b.v.y = f32(maxf(double(b.v.y), 0.0));
			}
			// _pose_air, airborne, not startled.
			const V3 flat(b.v.x, 0.0f, b.v.z);
			const V3 was = b.face;
			if (double(flat.length_squared()) > 0.04) b.face = turn(b.face, flat.normalized(), turn_k);
			const double yaw_rate = double(was.cross(b.face).y) / maxf(delta, 0.0001);
			const double bank = clampf(std::atan(yaw_rate * double(flat.length()) / 9.8) * 0.8, -0.8, 0.8);
			b.roll = lerpf(b.roll, bank, roll_k);
			const double pitch = clampf(std::atan2(double(b.v.y), maxf(double(flat.length()), 0.3)) * 0.6, -0.6, 0.6);
			b.pitch = lerpf(b.pitch, pitch, pitch_k);
			b.bound = std::fmod(b.bound + delta, bound_len);
			b.beat += delta * beat_rate;
			b.squash = move_toward(b.squash, 0.0, delta * 4.0);
		}
	}

	// --- Drawing (`_draw`): begin, each flock in order, then the counts, box and parts.
	void draw_begin() {
		std::fill(counts.begin(), counts.end(), 0);
		lo = zsfx::V3(INFINITY, INFINITY, INFINITY);
		hi = zsfx::V3(-INFINITY, -INFINITY, -INFINITY);
		drawn = 0;
	}
	void draw_flock(int64_t id, int64_t k0, double sz, bool settle) {
		auto it = flocks.find(id);
		if (it == flocks.end()) return;
		for (const zsfx::Bird &b : it->second)
			draw_one(k0, sz, settle, zsfx::FLYING, b.p, b.face.x, b.face.z, b.pitch, b.roll, b.squash, 0.0, 0.0, -1.0, 0.0, b.bound, b.beat, b.v.y);
	}
	void draw_records(const PackedFloat64Array &r, int64_t k0, double sz, bool settle) {
		const int64_t n = r.size() / zsfx::DRAW_REC;
		const double *d = r.ptr();
		for (int64_t i = 0; i < n; ++i, d += zsfx::DRAW_REC)
			draw_one(k0, sz, settle, int64_t(d[0]), zsfx::V3(float(d[1]), float(d[2]), float(d[3])), float(d[4]), float(d[5]), d[6], d[7], d[8], d[9], d[10], d[11],
					d[12], d[13], d[14], float(d[15]));
	}
	PackedInt32Array draw_counts() const {
		PackedInt32Array out;
		out.resize(int64_t(counts.size()));
		for (size_t k = 0; k < counts.size(); ++k) out.set(int64_t(k), counts[k]);
		return out;
	}
	// [lo, hi] of the birds drawn.
	Array draw_box() const {
		Array out;
		out.push_back(Vector3(lo.x, lo.y, lo.z));
		out.push_back(Vector3(hi.x, hi.y, hi.z));
		return out;
	}
	int64_t get_drawn() const { return drawn; }
	// Part `k`'s buffer: MAX_BIRDS transforms (as `_data.slice`).
	PackedFloat32Array part(int64_t k) const {
		PackedFloat32Array out;
		if (k < 0 || k >= parts) return out;
		out.resize(max_birds * 12);
		std::copy(data.begin() + k * max_birds * 12, data.begin() + (k + 1) * max_birds * 12, out.ptrw());
		return out;
	}
};
