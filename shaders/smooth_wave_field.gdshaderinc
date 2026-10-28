// Smooth, lattice-free fields for the ground's high-up paint (docs/design/
// endless-flight/far-lawn-handoff.md). Value noise (zs_noise) sits on a square
// lattice, and stretched or warped past a cell it shows that lattice as blocks,
// stripes and arcs; these are sums of plane waves at unrelated angles and
// scales instead, so no cell, no straight seam and no fold.
#ifndef ZS_SMOOTH_WAVE_FIELD
#define ZS_SMOOTH_WAVE_FIELD

const float ZS_WAVE_GOLDEN = 2.39996323;

// About zero-mean, std ~0.16, within +-0.5: 5 plane waves at `q` (in units
// of the feature size: wavelengths about 1.5 to 3 of them), their angles a
// golden step apart from `turn`, their scales spread, their phases from `seed`.
float zs_wave_field(vec2 q, float seed, float turn) {
	float sum = 0.0;
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float a = turn + ZS_WAVE_GOLDEN * fi;
		float f = 2.2 + 0.45 * fi + 0.35 * fract(seed * 0.37 + fi * 0.618);
		sum += sin(dot(q, vec2(cos(a), sin(a))) * f + seed * (3.1 + fi * 1.7));
	}
	return sum * 0.1;
}

// 0..1 about 0.5, with the value noise blend's spread (a base and a second
// octave 2.7x finer at 0.28 of the weight), for the washes' thresholds.
float zs_wave_fbm(vec2 q, float seed, float turn) {
	return 0.5 + 1.25 * (zs_wave_field(q, seed, turn) * 0.72 + zs_wave_field(q * 2.7, seed + 5.0, turn + 0.9) * 0.28);
}
#endif
