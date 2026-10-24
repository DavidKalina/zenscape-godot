#[compute]
#version 450
// The sea's FFT cascades (scripts/endless/sea_fft.gd), step 0: each
// cascade's starting spectrum h0(k), built once (and again when a knob
// changes). A JONSWAP spectrum for the wind's speed and fetch, spread round
// the wind by cos(theta/2)^2s, deep-water dispersion. Each cascade keeps only
// its own band of wavenumbers, so the three add up without counting a wave
// twice. Per texel: h0(k) in xy, conj(h0(-k)) in zw.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer Params {
	vec4 sizes;   // tile m per cascade xyz; seed
	vec4 wind;    // heading xy; speed m/s; fetch m
	vec4 shape;   // jonswap gamma; spread exponent s; spread normaliser; short cut m
	vec4 cuts;    // band edges k (0|1, 1|2); longest wave kept (k); height scale
	vec4 clock;   // time s; choppiness; -; -
} P;

layout(set = 0, binding = 1, rgba32f) uniform restrict writeonly image2DArray h0_out;

const int N = 256;
const float PI = 3.14159265;
const float TAU = 6.2831853;
const float GRAVITY = 9.81;

uint pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

// Two independent unit gaussians for mode `m` of cascade `c`.
vec2 gauss(ivec2 m, int c, uint seed) {
	uint s = pcg(uint(m.x + 4096) ^ pcg(uint(m.y + 4096) ^ pcg(uint(c) * 7919u + seed)));
	uint s2 = pcg(s);
	float u1 = max(float(s) / 4294967296.0, 1e-7);
	float u2 = float(s2) / 4294967296.0;
	float r = sqrt(-2.0 * log(u1));
	return r * vec2(cos(TAU * u2), sin(TAU * u2));
}

// The wavenumber spectrum at k (m^-2 per (rad/m)^2) for cascade c, 0 off
// its band.
float spectrum(vec2 k, int c) {
	float kl = length(k);
	if (kl < 1e-6) return 0.0;
	float lo = c == 0 ? 0.0 : (c == 1 ? P.cuts.x : P.cuts.y);
	float hi = c == 0 ? P.cuts.x : (c == 1 ? P.cuts.y : 1e9);
	if (kl < lo || kl >= hi || kl < P.cuts.z) return 0.0;
	float omega = sqrt(GRAVITY * kl);
	float dodk = GRAVITY / (2.0 * omega);
	float U = max(P.wind.z, 0.5);
	float F = max(P.wind.w, 100.0);
	float alpha = 0.076 * pow(U * U / (F * GRAVITY), 0.22);
	float wp = 22.0 * pow(GRAVITY * GRAVITY / (U * F), 1.0 / 3.0);
	float sigma = omega <= wp ? 0.07 : 0.09;
	float r = exp(-(omega - wp) * (omega - wp) / (2.0 * sigma * sigma * wp * wp));
	float s_omega = alpha * GRAVITY * GRAVITY / pow(omega, 5.0) * exp(-1.25 * pow(wp / omega, 4.0)) * pow(P.shape.x, r);
	// Spread round the wind.
	vec2 w = normalize(P.wind.xy);
	float cos_t = dot(k / kl, w);
	float half_cos = sqrt(max(0.5 * (1.0 + cos_t), 0.0));
	float spread = P.shape.z * pow(half_cos, 2.0 * P.shape.y);
	// The shortest waves damped (they alias at the finest cascade's grid).
	float shortest = exp(-kl * kl * P.shape.w * P.shape.w);
	return s_omega * spread * dodk / kl * shortest;
}

void main() {
	ivec3 id = ivec3(gl_GlobalInvocationID.xyz);
	if (id.x >= N || id.y >= N) return;
	int c = id.z;
	float L = P.sizes[c];
	ivec2 m = ivec2(id.x < N / 2 ? id.x : id.x - N, id.y < N / 2 ? id.y : id.y - N);
	vec2 k = vec2(m) * TAU / L;
	float dk = TAU / L;
	uint seed = uint(P.sizes.w);
	vec4 o = vec4(0.0);
	// The Nyquist row and column have no partner of their own: left empty.
	if (m.x != -N / 2 && m.y != -N / 2) {
		float scale = P.cuts.w;
		vec2 a = 0.5 * gauss(m, c, seed) * sqrt(spectrum(k, c)) * dk * scale;
		vec2 b = 0.5 * gauss(-m, c, seed) * sqrt(spectrum(-k, c)) * dk * scale;
		o = vec4(a, b.x, -b.y);
	}
	imageStore(h0_out, id, o);
}
