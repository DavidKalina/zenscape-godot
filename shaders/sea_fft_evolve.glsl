#[compute]
#version 450
// The sea's FFT cascades (scripts/endless/sea_fft.gd), step 1 each frame:
// h(k, t) from h0 (deep water, omega = sqrt(g k)), turned into the spectra
// of eight real fields, packed two to a complex FFT (a + i b, both real
// since each spectrum is Hermitian):
//   0  Dx + i Dy              (sideways shove x, height)
//   1  Dz + i dDx/dz          (sideways shove z, its cross term)
//   2  dDy/dx + i dDy/dz      (the height's slope)
//   3  dDx/dx + i dDz/dz      (the shove's stretch, for the Jacobian)
// The shove is scaled by the choppiness; positive pulls points toward the
// crests, so they peak.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer Params {
	vec4 sizes;   // tile m per cascade xyz; seed
	vec4 wind;    // heading xy; speed m/s; fetch m
	vec4 shape;   // jonswap gamma; spread exponent s; spread normaliser; short cut m
	vec4 cuts;    // band edges k (0|1, 1|2); longest wave kept (k); height scale
	vec4 clock;   // time s; choppiness; -; -
} P;

layout(set = 0, binding = 1, rgba32f) uniform restrict readonly image2DArray h0_in;
layout(set = 0, binding = 2, std430) restrict writeonly buffer Spectra { vec2 data[]; } S;

const int N = 256;
const float TAU = 6.2831853;
const float GRAVITY = 9.81;

vec2 cmul(vec2 a, vec2 b) {
	return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

// a + i b
vec2 pack(vec2 a, vec2 b) {
	return vec2(a.x - b.y, a.y + b.x);
}

void main() {
	ivec3 id = ivec3(gl_GlobalInvocationID.xyz);
	if (id.x >= N || id.y >= N) return;
	int c = id.z;
	float L = P.sizes[c];
	ivec2 m = ivec2(id.x < N / 2 ? id.x : id.x - N, id.y < N / 2 ? id.y : id.y - N);
	vec2 k = vec2(m) * TAU / L;
	float kl = length(k);
	vec4 h0 = imageLoad(h0_in, id);
	float omega = sqrt(GRAVITY * kl);
	float ph = mod(omega * P.clock.x, TAU);
	vec2 e = vec2(cos(ph), sin(ph));
	vec2 h = cmul(h0.xy, e) + cmul(h0.zw, vec2(e.x, -e.y));
	vec2 ih = vec2(-h.y, h.x);
	vec2 u = kl > 1e-6 ? k / kl : vec2(0.0);
	float lambda = P.clock.y;
	vec2 dx = ih * u.x * lambda;
	vec2 dz = ih * u.y * lambda;
	vec2 dxz = -h * (k.x * u.y) * lambda;
	vec2 dydx = ih * k.x;
	vec2 dydz = ih * k.y;
	vec2 dxx = -h * (k.x * u.x) * lambda;
	vec2 dzz = -h * (k.y * u.y) * lambda;
	int base = c * 4 * N * N + id.y * N + id.x;
	S.data[base] = pack(dx, h);
	S.data[base + N * N] = pack(dz, dxz);
	S.data[base + 2 * N * N] = pack(dydx, dydz);
	S.data[base + 3 * N * N] = pack(dxx, dzz);
}
