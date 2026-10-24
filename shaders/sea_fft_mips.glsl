#[compute]
#version 450
// The sea's FFT cascades (scripts/endless/sea_fft.gd), step 4: one mip of
// the maps from the one above (a 2x2 mean; the tiles wrap, and the sizes
// are powers of two, so no edge needs care). The sea samples the mips, so
// waves finer than a pixel (or a vertex) average out instead of shimmering.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba16f) uniform restrict readonly image2DArray src;
layout(set = 0, binding = 1, rgba16f) uniform restrict writeonly image2DArray dst;

void main() {
	ivec3 id = ivec3(gl_GlobalInvocationID.xyz);
	ivec2 size = imageSize(dst).xy;
	if (id.x >= size.x || id.y >= size.y) return;
	ivec2 p = id.xy * 2;
	vec4 sum = imageLoad(src, ivec3(p, id.z)) + imageLoad(src, ivec3(p + ivec2(1, 0), id.z)) + imageLoad(src, ivec3(p + ivec2(0, 1), id.z)) + imageLoad(src, ivec3(p + ivec2(1, 1), id.z));
	imageStore(dst, id, sum * 0.25);
}
