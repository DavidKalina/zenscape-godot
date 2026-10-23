// The endless land's own exp, log, pow, sin and cos (land_field.h), so a seed
// grows the same land on every machine: the C runtimes' versions (macOS
// libSystem, Windows UCRT, MinGW) may differ in the last bit, and a land that
// is to match across machines (co-op sends only the seed) can't lean on
// them. These are fdlibm's algorithms (Sun Microsystems, 1993: "Permission
// to use, copy, modify, and distribute this software is freely granted,
// provided that this notice is preserved."), written with plain double
// arithmetic, std::ldexp/frexp (exact) and no table, so with contraction off
// (SConstruct) they give the same bits on any IEEE-754 machine. Each is
// within about one unit in the last place of the true value; the land asks
// them only over small, well-behaved ranges.
#pragma once

#include <cmath>
#include <limits>

namespace zsland {

inline double det_exp(double x) {
	const double ln2_hi = 6.93147180369123816490e-01;
	const double ln2_lo = 1.90821492927058770002e-10;
	const double inv_ln2 = 1.44269504088896338700e+00;
	const double P1 = 1.66666666666666019037e-01;
	const double P2 = -2.77777777770155933842e-03;
	const double P3 = 6.61375632143793436117e-05;
	const double P4 = -1.65339022054652515390e-06;
	const double P5 = 4.13813679705723846039e-08;
	if (x != x) return x;
	if (x > 7.09782712893383973096e+02) return std::numeric_limits<double>::infinity();
	if (x < -7.45133219101941108420e+02) return 0.0;
	const double ax = x < 0.0 ? -x : x;
	double hi = 0.0, lo = 0.0;
	int k = 0;
	if (ax > 0.5*ln2_hi) {
		k = int(inv_ln2*x + (x < 0.0 ? -0.5 : 0.5));
		const double t = double(k);
		hi = x - t*ln2_hi;
		lo = t*ln2_lo;
		x = hi - lo;
	} else if (ax < 3.7252902984e-09) {
		return 1.0 + x;
	}
	const double t = x*x;
	const double c = x - t*(P1 + t*(P2 + t*(P3 + t*(P4 + t*P5))));
	if (k == 0) return 1.0 - ((x*c)/(c - 2.0) - x);
	const double y = 1.0 - ((lo - (x*c)/(2.0 - c)) - hi);
	return std::ldexp(y, k);
}

inline double det_log(double x) {
	const double ln2_hi = 6.93147180369123816490e-01;
	const double ln2_lo = 1.90821492927058770002e-10;
	const double Lg1 = 6.666666666666735130e-01;
	const double Lg2 = 3.999999999940941908e-01;
	const double Lg3 = 2.857142874366239149e-01;
	const double Lg4 = 2.222219843214978396e-01;
	const double Lg5 = 1.818357216161805012e-01;
	const double Lg6 = 1.531383769920937332e-01;
	const double Lg7 = 1.479819860511658591e-01;
	if (x != x) return x;
	if (x < 0.0) return std::numeric_limits<double>::quiet_NaN();
	if (x == 0.0) return -std::numeric_limits<double>::infinity();
	if (x == std::numeric_limits<double>::infinity()) return x;
	int e = 0;
	double m = std::frexp(x, &e); // x = m*2^e, m in [0.5, 1)
	if (m < 0.70710678118654752440) {
		m *= 2.0;
		e -= 1;
	}
	const double f = m - 1.0;
	const double k = double(e);
	const double s = f/(2.0 + f);
	const double z = s*s;
	const double w = z*z;
	const double t1 = w*(Lg2 + w*(Lg4 + w*Lg6));
	const double t2 = z*(Lg1 + w*(Lg3 + w*(Lg5 + w*Lg7)));
	const double R = t2 + t1;
	const double hfsq = 0.5*f*f;
	return k*ln2_hi - ((hfsq - (s*(hfsq + R) + k*ln2_lo)) - f);
}

// x^y for x >= 0 (all the land asks): exp(y log x), exact at the ends.
inline double det_pow(double x, double y) {
	if (y == 0.0) return 1.0;
	if (x != x || y != y) return std::numeric_limits<double>::quiet_NaN();
	if (x == 1.0) return 1.0;
	if (x == 0.0) return y > 0.0 ? 0.0 : std::numeric_limits<double>::infinity();
	if (x < 0.0) return std::numeric_limits<double>::quiet_NaN();
	if (y == 1.0) return x;
	return det_exp(y*det_log(x));
}

inline double det_ksin(double x, double y) {
	const double S1 = -1.66666666666666324348e-01;
	const double S2 = 8.33333333332248946124e-03;
	const double S3 = -1.98412698298579493134e-04;
	const double S4 = 2.75573137070700676789e-06;
	const double S5 = -2.50507602534068634195e-08;
	const double S6 = 1.58969099521155010221e-10;
	const double z = x*x;
	const double v = z*x;
	const double r = S2 + z*(S3 + z*(S4 + z*(S5 + z*S6)));
	return x - ((z*(0.5*y - v*r) - y) - v*S1);
}

inline double det_kcos(double x, double y) {
	const double C1 = 4.16666666666666019037e-02;
	const double C2 = -1.38888888888741095749e-03;
	const double C3 = 2.48015872894767294178e-05;
	const double C4 = -2.75573143513906633035e-07;
	const double C5 = 2.08757232129817482790e-09;
	const double C6 = -1.13596475577881948265e-11;
	const double z = x*x;
	const double w = z*z;
	const double r = z*(C1 + z*(C2 + z*C3)) + w*w*(C4 + z*(C5 + z*C6));
	const double hz = 0.5*z;
	const double q = 1.0 - hz;
	return q + (((1.0 - q) - hz) + (z*r - x*y));
}

// x into [-pi/4, pi/4] plus a tail (y0 + y1), and the quadrant. Good to about
// one ulp while |x| < 2^19 * pi/2 (the land's angles are a few dozen at most).
inline int det_reduce(double x, double &y0, double &y1) {
	const double inv_pio2 = 6.36619772367581382433e-01;
	const double pio2_1 = 1.57079632673412561417e+00;
	const double pio2_1t = 6.07710050650619224932e-11;
	const double ax = x < 0.0 ? -x : x;
	if (ax <= 7.85398163397448278999e-01) {
		y0 = x;
		y1 = 0.0;
		return 0;
	}
	const double fn = std::floor(x*inv_pio2 + 0.5);
	const double r = x - fn*pio2_1;
	const double w = fn*pio2_1t;
	y0 = r - w;
	y1 = (r - y0) - w;
	const long long n = (long long)fn;
	return int(n & 3);
}

inline double det_sin(double x) {
	if (!std::isfinite(x)) return std::numeric_limits<double>::quiet_NaN();
	double y0, y1;
	switch (det_reduce(x, y0, y1)) {
		case 0: return det_ksin(y0, y1);
		case 1: return det_kcos(y0, y1);
		case 2: return -det_ksin(y0, y1);
		default: return -det_kcos(y0, y1);
	}
}

inline double det_cos(double x) {
	if (!std::isfinite(x)) return std::numeric_limits<double>::quiet_NaN();
	double y0, y1;
	switch (det_reduce(x, y0, y1)) {
		case 0: return det_kcos(y0, y1);
		case 1: return -det_ksin(y0, y1);
		case 2: return -det_kcos(y0, y1);
		default: return det_ksin(y0, y1);
	}
}

} // namespace zsland
