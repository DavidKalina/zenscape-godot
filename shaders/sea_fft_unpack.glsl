#[compute]
#version 450
// The sea's FFT cascades (scripts/endless/sea_fft.gd), step 3: the fields
// out of the FFT into the maps the sea shader samples, mip 0 of a 2D array:
//   layer c      Dx, Dy, Dz, dDx/dz   (the shove and height, m)
//   layer 3 + c  dDy/dx, dDy/dz, dDx/dx, dDz/dz
// The sea sums the cascades' derivatives before it forms the Jacobian, so
// a fold reads across them all.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer Spectra { vec2 data[]; } S;
layout(set = 0, binding = 1, rgba16f) uniform restrict writeonly image2DArray maps;

const int N = 256;

void main() {
	ivec3 id = ivec3(gl_GlobalInvocationID.xyz);
	if (id.x >= N || id.y >= N) return;
	int c = id.z;
	int base = c * 4 * N * N + id.y * N + id.x;
	vec2 f0 = S.data[base];
	vec2 f1 = S.data[base + N * N];
	vec2 f2 = S.data[base + 2 * N * N];
	vec2 f3 = S.data[base + 3 * N * N];
	imageStore(maps, ivec3(id.xy, c), vec4(f0.x, f0.y, f1.x, f1.y));
	imageStore(maps, ivec3(id.xy, 3 + c), vec4(f2.x, f2.y, f3.x, f3.y));
}
