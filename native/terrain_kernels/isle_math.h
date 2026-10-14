// Exact mirrors of the engine math GDScript runs (Godot 4.7, real_t = float),
// for the motif isles' kernels (isle_kernels.h). Every operation is written
// the way the engine's own code does it (core/math/vector3.h, basis.h,
// transform_3d.h, plane.cpp, geometry_3d.cpp, color.h, random_pcg.h,
// core/templates/sort_array.h), in the same order, so a kernel gives the very
// same bits as the GDScript it stands in for. GDScript's own numbers are
// doubles; Vector3, Plane, AABB, Basis, Color and packed float arrays hold
// floats: a double meeting a float type is narrowed first, as the engine's
// Variant operators do. Built with floating-point contraction off, as the
// engine is.
#pragma once

#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/color.hpp>
#include <cmath>
#include <cstdint>
#include <vector>

namespace zs {

// --- Transcendentals ----------------------------------------------------------------
// GDScript's sin/cos/atan2 are the C library's (Math::sin -> std::sin). On
// macOS this library and the engine link the same libSystem, so the local
// functions are the engine's. Elsewhere the engine's own are called (a
// utility function pointer, no script), as the engine and this library may be
// built against different C runtimes. `engine_math` forces that path anywhere
// (to check it gives the same as the local one).
#if defined(__APPLE__)
inline bool engine_math = false;
#else
inline bool engine_math = true;
#endif

inline double sin(double x) { return engine_math ? godot::UtilityFunctions::sin(x) : std::sin(x); }
inline double cos(double x) { return engine_math ? godot::UtilityFunctions::cos(x) : std::cos(x); }
inline double atan2(double y, double x) { return engine_math ? godot::UtilityFunctions::atan2(y, x) : std::atan2(y, x); }

constexpr double TAU = 6.2831853071795864769252867666;
constexpr double PI = 3.1415926535897932384626433833;
constexpr float CMP_EPSILON = 0.00001f;

// --- Scalars (GDScript's utility functions on doubles) ---------------------------------
inline double minf(double a, double b) { return a < b ? a : b; }
inline double maxf(double a, double b) { return a > b ? a : b; }
inline double clampf(double v, double lo, double hi) { return v < lo ? lo : (v > hi ? hi : v); }
inline int64_t mini(int64_t a, int64_t b) { return a < b ? a : b; }
inline int64_t clampi(int64_t v, int64_t lo, int64_t hi) { return v < lo ? lo : (v > hi ? hi : v); }
inline double lerpf(double a, double b, double t) { return a + (b - a) * t; }
inline float lerp32(float a, float b, float t) { return a + (b - a) * t; }
inline double absf(double v) { return std::fabs(v); }
inline int64_t floori(double v) { return int64_t(std::floor(v)); }
inline double fposmod(double x, double y) {
	double value = std::fmod(x, y);
	if (((value < 0) && (y > 0)) || ((value > 0) && (y < 0))) value += y;
	value += 0.0;
	return value;
}
inline bool is_equal_approx(double a, double b) {
	double tolerance = 0.00001 * std::fabs(a);
	if (tolerance < 0.00001) tolerance = 0.00001;
	return std::fabs(a - b) < tolerance;
}
inline double smoothstep(double from, double to, double s) {
	if (is_equal_approx(from, to)) {
		if (from <= to) return s <= from ? 0.0 : 1.0;
		return s <= to ? 1.0 : 0.0;
	}
	double t = clampf((s - from) / (to - from), 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

// --- Vectors --------------------------------------------------------------------------
struct V2 {
	float x = 0, y = 0;
	V2() = default;
	V2(float px, float py) : x(px), y(py) {}
	float dot(const V2 &o) const { return x * o.x + y * o.y; }
};

struct V3 {
	float x = 0, y = 0, z = 0;
	V3() = default;
	V3(float px, float py, float pz) : x(px), y(py), z(pz) {}
	V3(const godot::Vector3 &v) : x(v.x), y(v.y), z(v.z) {}
	godot::Vector3 gd() const { return godot::Vector3(x, y, z); }
	float &operator[](int i) { return i == 0 ? x : (i == 1 ? y : z); }
	float operator[](int i) const { return i == 0 ? x : (i == 1 ? y : z); }
	V3 operator+(const V3 &o) const { return V3(x + o.x, y + o.y, z + o.z); }
	V3 operator-(const V3 &o) const { return V3(x - o.x, y - o.y, z - o.z); }
	V3 operator-() const { return V3(-x, -y, -z); }
	V3 operator*(float s) const { return V3(x * s, y * s, z * s); }
	V3 operator/(float s) const { return V3(x / s, y / s, z / s); }
	V3 &operator+=(const V3 &o) { x += o.x; y += o.y; z += o.z; return *this; }
	V3 &operator-=(const V3 &o) { x -= o.x; y -= o.y; z -= o.z; return *this; }
	bool operator==(const V3 &o) const { return x == o.x && y == o.y && z == o.z; }
	float dot(const V3 &o) const { return x * o.x + y * o.y + z * o.z; }
	V3 cross(const V3 &o) const { return V3((y * o.z) - (z * o.y), (z * o.x) - (x * o.z), (x * o.y) - (y * o.x)); }
	float length_squared() const {
		float x2 = x * x, y2 = y * y, z2 = z * z;
		return x2 + y2 + z2;
	}
	float length() const {
		float x2 = x * x, y2 = y * y, z2 = z * z;
		return std::sqrt(x2 + y2 + z2);
	}
	bool is_finite() const { return std::isfinite(x) && std::isfinite(y) && std::isfinite(z); }
	V3 normalized() const {
		V3 v = *this;
		if (!v.is_finite()) return V3();
		float l = v.length_squared();
		if (l == 0) return V3();
		l = std::sqrt(l);
		v.x /= l;
		v.y /= l;
		v.z /= l;
		return v;
	}
	V3 lerp(const V3 &to, float w) const { return V3(lerp32(x, to.x, w), lerp32(y, to.y, w), lerp32(z, to.z, w)); }
	float distance_to(const V3 &to) const { return (to - *this).length(); }
	float distance_squared_to(const V3 &to) const { return (to - *this).length_squared(); }
};

// GDScript's `Vector3 * float` and `Vector3 / int`: the scalar narrowed.
inline V3 mul(const V3 &v, double s) { return v * float(s); }
inline V3 divi(const V3 &v, int64_t n) { return v / float(n); }

struct Pl {
	V3 n;
	float d = 0;
	Pl() = default;
	Pl(const V3 &pn, float pd) : n(pn), d(pd) {}
	Pl(const godot::Plane &p) : n(p.normal), d(p.d) {}
	float distance_to(const V3 &p) const { return n.dot(p) - d; }
	bool intersect_3(const Pl &p1, const Pl &p2, V3 *r) const {
		const V3 &n0 = n, &n1 = p1.n, &n2 = p2.n;
		float denom = n0.cross(n1).dot(n2);
		if (std::fabs(denom) < CMP_EPSILON) return false;
		*r = ((n1.cross(n2) * d) + (n2.cross(n0) * p1.d) + (n0.cross(n1) * p2.d)) / denom;
		return true;
	}
};

struct Bs {
	V3 rows[3] = { V3(1, 0, 0), V3(0, 1, 0), V3(0, 0, 1) };
	static Bs columns(const V3 &cx, const V3 &cy, const V3 &cz) {
		Bs b;
		b.rows[0] = V3(cx.x, cy.x, cz.x);
		b.rows[1] = V3(cx.y, cy.y, cz.y);
		b.rows[2] = V3(cx.z, cy.z, cz.z);
		return b;
	}
	V3 column(int i) const { return V3(rows[0][i], rows[1][i], rows[2][i]); }
	void set_column(int i, const V3 &v) {
		rows[0][i] = v.x;
		rows[1][i] = v.y;
		rows[2][i] = v.z;
	}
	V3 xform(const V3 &v) const { return V3(rows[0].dot(v), rows[1].dot(v), rows[2].dot(v)); }
	float tdotx(const V3 &v) const { return rows[0][0] * v[0] + rows[1][0] * v[1] + rows[2][0] * v[2]; }
	float tdoty(const V3 &v) const { return rows[0][1] * v[0] + rows[1][1] * v[1] + rows[2][1] * v[2]; }
	float tdotz(const V3 &v) const { return rows[0][2] * v[0] + rows[1][2] * v[1] + rows[2][2] * v[2]; }
	Bs operator*(const Bs &m) const {
		Bs b;
		b.rows[0] = V3(m.tdotx(rows[0]), m.tdoty(rows[0]), m.tdotz(rows[0]));
		b.rows[1] = V3(m.tdotx(rows[1]), m.tdoty(rows[1]), m.tdotz(rows[1]));
		b.rows[2] = V3(m.tdotx(rows[2]), m.tdoty(rows[2]), m.tdotz(rows[2]));
		return b;
	}
	Bs orthonormalized() const {
		V3 x = column(0), y = column(1), z = column(2);
		x = x.normalized();
		y = (y - x * (x.dot(y)));
		y = y.normalized();
		z = (z - x * (x.dot(z)) - y * (y.dot(z)));
		z = z.normalized();
		Bs b = *this;
		b.set_column(0, x);
		b.set_column(1, y);
		b.set_column(2, z);
		return b;
	}
	float cofac(int r1, int c1, int r2, int c2) const { return rows[r1][c1] * rows[r2][c2] - rows[r1][c2] * rows[r2][c1]; }
	Bs inverse() const {
		float co[3] = { cofac(1, 1, 2, 2), cofac(1, 2, 2, 0), cofac(1, 0, 2, 1) };
		float det = rows[0][0] * co[0] + rows[0][1] * co[1] + rows[0][2] * co[2];
		float s = 1.0f / det;
		Bs b;
		b.rows[0] = V3(co[0] * s, cofac(0, 2, 2, 1) * s, cofac(0, 1, 1, 2) * s);
		b.rows[1] = V3(co[1] * s, cofac(0, 0, 2, 2) * s, cofac(0, 2, 1, 0) * s);
		b.rows[2] = V3(co[2] * s, cofac(0, 1, 2, 0) * s, cofac(0, 0, 1, 1) * s);
		return b;
	}
	Bs transposed() const {
		Bs b = *this;
		std::swap(b.rows[0][1], b.rows[1][0]);
		std::swap(b.rows[0][2], b.rows[2][0]);
		std::swap(b.rows[1][2], b.rows[2][1]);
		return b;
	}
};

struct Tf {
	Bs basis;
	V3 origin;
	Tf() = default;
	Tf(const Bs &b, const V3 &o) : basis(b), origin(o) {}
	V3 xform(const V3 &v) const {
		return V3(basis.rows[0].dot(v) + origin.x, basis.rows[1].dot(v) + origin.y, basis.rows[2].dot(v) + origin.z);
	}
	Tf operator*(const Tf &t) const {
		Tf r = *this;
		r.origin = xform(t.origin);
		r.basis = basis * t.basis;
		return r;
	}
	Tf affine_inverse() const {
		Tf r = *this;
		r.basis = basis.inverse();
		r.origin = r.basis.xform(-origin);
		return r;
	}
	Pl xform(const Pl &p) const {
		Bs b = basis.inverse().transposed();
		V3 point = p.n * p.d;
		point = xform(point);
		V3 normal = b.xform(p.n);
		normal = normal.normalized();
		float d = normal.dot(point);
		return Pl(normal, d);
	}
};

struct AB {
	V3 position, size;
	AB() = default;
	AB(const V3 &p, const V3 &s) : position(p), size(s) {}
	AB(const godot::AABB &b) : position(b.position), size(b.size) {}
	bool has_point(const V3 &p) const {
		if (p.x < position.x) return false;
		if (p.y < position.y) return false;
		if (p.z < position.z) return false;
		if (p.x > position.x + size.x) return false;
		if (p.y > position.y + size.y) return false;
		if (p.z > position.z + size.z) return false;
		return true;
	}
	V3 end() const { return position + size; }
};

struct Col {
	float r = 0, g = 0, b = 0, a = 1;
	Col() = default;
	Col(float pr, float pg, float pb, float pa = 1.0f) : r(pr), g(pg), b(pb), a(pa) {}
	Col(const godot::Color &c) : r(c.r), g(c.g), b(c.b), a(c.a) {}
	godot::Color gd() const { return godot::Color(r, g, b, a); }
	Col operator*(float s) const { return Col(r * s, g * s, b * s, a * s); }
	Col &operator*=(float s) { r = r * s; g = g * s; b = b * s; a = a * s; return *this; }
	Col lerp(const Col &to, float w) const { return Col(lerp32(r, to.r, w), lerp32(g, to.g, w), lerp32(b, to.b, w), lerp32(a, to.a, w)); }
	float luminance() const { return 0.2126f * r + 0.7152f * g + 0.0722f * b; }
	static float channel_to_linear(float c) {
		return c < 0.04045f ? c * (1.0f / 12.92f) : std::pow(float((c + 0.055) * (1.0 / (1.0 + 0.055))), 2.4f);
	}
	Col srgb_to_linear() const {
		if (engine_math) {
			godot::Color out = godot::Variant(gd()).call("srgb_to_linear");
			return Col(out);
		}
		return Col(channel_to_linear(r), channel_to_linear(g), channel_to_linear(b), a);
	}
};

// --- Random numbers (RandomNumberGenerator: PCG32, its inc as seeded) -------------
struct Rng {
	uint64_t state = 0;
	uint64_t inc = (1442695040888963407ULL << 1u) | 1u;
	uint32_t rand() {
		uint64_t old = state;
		state = old * 6364136223846793005ULL + (inc | 1);
		uint32_t xorshifted = uint32_t(((old >> 18u) ^ old) >> 27u);
		uint32_t rot = uint32_t(old >> 59u);
		return (xorshifted >> rot) | (xorshifted << ((-rot) & 31));
	}
	static int clz32(uint32_t x) {
#if defined(_MSC_VER) && !defined(__clang__)
		unsigned long index;
		_BitScanReverse(&index, x);
		return 31 - int(index);
#else
		return __builtin_clz(x);
#endif
	}
	// `randf()`: a float (GDScript widens it).
	float randf() {
		uint32_t proto = rand();
		if (proto == 0) return 0;
		return std::ldexp((float)(rand() | 0x80000001u), -32 - clz32(proto));
	}
	// `randf_range(a, b)`: its ends narrowed to floats.
	float randf_range(double from, double to) {
		float f = float(from), t = float(to);
		return randf() * (t - f) + f;
	}
	int64_t randi() { return int64_t(rand()); }
	uint32_t bounded(uint32_t bound) {
		uint32_t threshold = -bound % bound;
		for (;;) {
			uint32_t r = rand();
			if (r >= threshold) return r % bound;
		}
	}
	int64_t randi_range(int from, int to) {
		if (from == to) return from;
		int64_t lo = from < to ? from : to;
		int64_t hi = from > to ? from : to;
		uint32_t diff = uint32_t(hi - lo);
		if (diff == UINT32_MAX) return int64_t(rand()) + lo;
		return int64_t(bounded(diff + 1u)) + lo;
	}
};

// --- Sorting (core/templates/sort_array.h, validating as a debug build) -------------
template <typename T, typename Less>
struct SortArray {
	Less compare;
	static constexpr int64_t THRESHOLD = 16;
	int64_t median_of_3_index(const T *p, int64_t a_i, int64_t b_i, int64_t c_i) const {
		const T &a = p[a_i], &b = p[b_i], &c = p[c_i];
		if (compare(a, b)) {
			if (compare(b, c)) return b_i;
			else if (compare(a, c)) return c_i;
			return a_i;
		} else if (compare(a, c)) return a_i;
		else if (compare(b, c)) return c_i;
		return b_i;
	}
	int64_t bitlog(int64_t n) const {
		int64_t k;
		for (k = 0; n != 1; n >>= 1) ++k;
		return k;
	}
	void push_heap(int64_t first, int64_t hole, int64_t top, T value, T *a) const {
		int64_t parent = (hole - 1) / 2;
		while (hole > top && compare(a[first + parent], value)) {
			a[first + hole] = a[first + parent];
			hole = parent;
			parent = (hole - 1) / 2;
		}
		a[first + hole] = value;
	}
	void adjust_heap(int64_t first, int64_t hole, int64_t len, T value, T *a) const {
		int64_t top = hole;
		int64_t second = 2 * hole + 2;
		while (second < len) {
			if (compare(a[first + second], a[first + (second - 1)])) second--;
			a[first + hole] = a[first + second];
			hole = second;
			second = 2 * (second + 1);
		}
		if (second == len) {
			a[first + hole] = a[first + (second - 1)];
			hole = second - 1;
		}
		push_heap(first, hole, top, value, a);
	}
	void pop_heap(int64_t first, int64_t last, int64_t result, T value, T *a) const {
		a[result] = a[first];
		adjust_heap(first, 0, last - first, value, a);
	}
	void pop_heap(int64_t first, int64_t last, T *a) const { pop_heap(first, last - 1, last - 1, a[last - 1], a); }
	void sort_heap(int64_t first, int64_t last, T *a) const {
		while (last - first > 1) pop_heap(first, last--, a);
	}
	void make_heap(int64_t first, int64_t last, T *a) const {
		if (last - first < 2) return;
		int64_t len = last - first;
		int64_t parent = (len - 2) / 2;
		while (true) {
			adjust_heap(first, parent, len, a[first + parent], a);
			if (parent == 0) return;
			parent--;
		}
	}
	void partial_sort(int64_t first, int64_t last, int64_t middle, T *a) const {
		make_heap(first, middle, a);
		for (int64_t i = middle; i < last; i++)
			if (compare(a[i], a[first])) pop_heap(first, middle, i, a[i], a);
		sort_heap(first, middle, a);
	}
	int64_t partitioner(int64_t first, int64_t last, int64_t pivot, T *a) const {
		const int64_t ufirst = first, ulast = last;
		const T *pivot_at = &a[pivot];
		while (true) {
			while (first != pivot && compare(a[first], *pivot_at)) {
				if (first == ulast - 1) break;
				first++;
			}
			last--;
			while (last != pivot && compare(*pivot_at, a[last])) {
				if (last == ufirst) break;
				last--;
			}
			if (first >= last) return first;
			if (pivot_at == &a[first]) pivot_at = &a[last];
			else if (pivot_at == &a[last]) pivot_at = &a[first];
			std::swap(a[first], a[last]);
			first++;
		}
	}
	void introsort(int64_t first, int64_t last, T *a, int64_t depth) const {
		while (last - first > THRESHOLD) {
			if (depth == 0) {
				partial_sort(first, last, last, a);
				return;
			}
			depth--;
			int64_t cut = partitioner(first, last, median_of_3_index(a, first, first + (last - first) / 2, last - 1), a);
			introsort(cut, last, a, depth);
			last = cut;
		}
	}
	void unguarded_linear_insert(int64_t last, T value, T *a) const {
		int64_t next = last - 1;
		while (compare(value, a[next])) {
			if (next == 0) break;
			a[last] = a[next];
			last = next;
			next--;
		}
		a[last] = value;
	}
	void linear_insert(int64_t first, int64_t last, T *a) const {
		T val = a[last];
		if (compare(val, a[first])) {
			for (int64_t i = last; i > first; i--) a[i] = a[i - 1];
			a[first] = val;
		} else unguarded_linear_insert(last, val, a);
	}
	void insertion_sort(int64_t first, int64_t last, T *a) const {
		if (first == last) return;
		for (int64_t i = first + 1; i != last; i++) linear_insert(first, i, a);
	}
	void unguarded_insertion_sort(int64_t first, int64_t last, T *a) const {
		for (int64_t i = first; i != last; i++) unguarded_linear_insert(i, a[i], a);
	}
	void final_insertion_sort(int64_t first, int64_t last, T *a) const {
		if (last - first > THRESHOLD) {
			insertion_sort(first, first + THRESHOLD, a);
			unguarded_insertion_sort(first + THRESHOLD, last, a);
		} else insertion_sort(first, last, a);
	}
	void sort(T *a, int64_t len) const {
		if (len != 0) {
			introsort(0, len, a, bitlog(len) * 2);
			final_insertion_sort(0, len, a);
		}
	}
};

// --- Geometry --------------------------------------------------------------------------
// Geometry3D.compute_convex_mesh_points.
inline void convex_points(const Pl *planes, int count, std::vector<V3> &out) {
	out.clear();
	for (int i = count - 1; i >= 0; i--) {
		for (int j = i - 1; j >= 0; j--) {
			for (int k = j - 1; k >= 0; k--) {
				V3 point;
				if (planes[i].intersect_3(planes[j], planes[k], &point)) {
					bool excluded = false;
					for (int n = 0; n < count; n++) {
						if (n != i && n != j && n != k) {
							float dp = planes[n].n.dot(point);
							if (dp - planes[n].d > CMP_EPSILON) {
								excluded = true;
								break;
							}
						}
					}
					if (!excluded) out.push_back(point);
				}
			}
		}
	}
}

// RuinKit Build `_unique`.
inline void unique(const std::vector<V3> &points, std::vector<V3> &out) {
	out.clear();
	for (const V3 &p : points) {
		bool seen = false;
		for (const V3 &q : out) {
			if (double(p.distance_squared_to(q)) < 1e-8) {
				seen = true;
				break;
			}
		}
		if (!seen) out.push_back(p);
	}
}

// One face of RuinKit Build `_polys`: [corners, normal, middle, area, plane].
struct Poly {
	int first = 0, count = 0; // into Polys::corners
	V3 normal, mid;
	double area = 0;
	int plane = 0;
};

struct Polys {
	std::vector<V3> corners;
	std::vector<Poly> faces;
	std::vector<V3> open_face;
	double biggest = 0;
	// scratch
	std::vector<V3> on;
	std::vector<double> keys;
	std::vector<int> order;

	struct ByKey {
		const double *keys;
		bool operator()(int a, int b) const { return keys[a] < keys[b]; }
	};

	// `_polys(cut, points, open)`.
	void build(const Pl *cut, int cut_count, const std::vector<V3> &points, int open) {
		corners.clear();
		faces.clear();
		open_face.clear();
		biggest = 0.0;
		if (points.size() < 4) return;
		for (int i = 0; i < cut_count; i++) {
			const Pl &plane = cut[i];
			on.clear();
			for (const V3 &q : points)
				if (absf(plane.distance_to(q)) < 0.0015) on.push_back(q);
			if (on.size() < 3) continue;
			V3 mid;
			for (const V3 &q : on) mid += q;
			mid = divi(mid, int64_t(on.size()));
			V3 u;
			for (const V3 &q : on) {
				if (double((q - mid).length()) > 0.0001) {
					u = (q - mid).normalized();
					break;
				}
			}
			V3 v = plane.n.cross(u);
			// The sort's key, as its comparator works it out each time.
			const int n = int(on.size());
			keys.resize(n);
			order.resize(n);
			for (int k = 0; k < n; k++) {
				keys[k] = zs::atan2(double((on[k] - mid).dot(v)), double((on[k] - mid).dot(u)));
				order[k] = k;
			}
			SortArray<int, ByKey> sorter{ ByKey{ keys.data() } };
			sorter.sort(order.data(), n);
			if (i == open) {
				for (int k = 0; k < n; k++) open_face.push_back(on[order[k]]);
				continue;
			}
			Poly face;
			face.first = int(corners.size());
			face.count = n;
			for (int k = 0; k < n; k++) corners.push_back(on[order[k]]);
			const V3 *c = &corners[face.first];
			double area = 0.0;
			for (int k = 1; k < n - 1; k++) area += double((c[k] - c[0]).cross(c[k + 1] - c[0]).length()) * 0.5;
			biggest = maxf(biggest, area);
			face.normal = plane.n;
			face.mid = mid;
			face.area = area;
			face.plane = i;
			faces.push_back(face);
		}
	}
};

} // namespace zs
