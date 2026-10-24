#[compute]
#version 450
// The sea's FFT cascades (scripts/endless/sea_fft.gd), step 2: one inverse
// FFT pass along the rows (Stockham, radix 2, in shared memory), one
// workgroup a row; the result is written transposed, so running the pass
// twice does the rows, then the columns, and leaves the field in order.

layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer Src { vec2 data[]; } A;
layout(set = 0, binding = 1, std430) restrict writeonly buffer Dst { vec2 data[]; } B;

const uint N = 256u;
const uint LOG_N = 8u;
const float PI = 3.14159265;

shared vec2 buf[2][256];

void main() {
	uint t = gl_LocalInvocationID.x;
	uint row = gl_WorkGroupID.x;
	uint slice = gl_WorkGroupID.y;
	uint base = slice * N * N;
	buf[0][t] = A.data[base + row * N + t];
	buf[0][t + N / 2u] = A.data[base + row * N + t + N / 2u];
	memoryBarrierShared();
	barrier();
	uint ping = 0u;
	for (uint s = 0u; s < LOG_N; s++) {
		uint hs = 1u << s;
		uint k = t & (hs - 1u);
		vec2 a = buf[ping][t];
		vec2 b = buf[ping][t + N / 2u];
		float ang = PI * float(k) / float(hs);
		vec2 w = vec2(cos(ang), sin(ang));
		vec2 bw = vec2(b.x * w.x - b.y * w.y, b.x * w.y + b.y * w.x);
		uint o = ((t >> s) << (s + 1u)) + k;
		buf[1u - ping][o] = a + bw;
		buf[1u - ping][o + hs] = a - bw;
		memoryBarrierShared();
		barrier();
		ping = 1u - ping;
	}
	B.data[base + t * N + row] = buf[ping][t];
	B.data[base + (t + N / 2u) * N + row] = buf[ping][t + N / 2u];
}
