#[compute]
#version 450
// The unified cloud volume's temporal resolve (scripts/cloud_volume_effect
// .gd), at the render's full size. The march (shaders/cloud_volume_march
// .glsl) takes one pixel of each 2x2 block a frame, a different one each
// frame, so over four frames every pixel of the render is marched. Here
// each pixel takes last frame's resolved cloud, reprojected to where the
// cloud seen at it stood on screen then, and blends in this frame's: the
// pixel marched this frame strongly, the rest gently from the march
// upsampled round it (each of the four nearest samples weighted by how
// near its solid stands to this pixel's, so an island's edge stays crisp
// against the cloud behind it). The history is clamped to the march's
// neighbourhood so a moving eye or a rising tower never ghosts for long.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer Params {
	mat4 camera;        // world from view, this frame
	mat4 prev_view;     // view from world, last frame
	vec4 lens;          // tan half fov x, y this frame; blend; history valid
	vec4 prev_lens;     // tan half fov x, y last frame
	vec4 eye;           // xyz this frame, w the march's frame index
	vec4 planes;        // near, far, the marched pixel's blend, 0
} P;

layout(set = 0, binding = 1) uniform sampler2D march_a;
layout(set = 0, binding = 2) uniform sampler2D march_b;
layout(set = 0, binding = 3) uniform sampler2D march_depth;
layout(set = 0, binding = 4) uniform sampler2D scene_depth;
layout(set = 0, binding = 5) uniform sampler2D history_a;
layout(set = 0, binding = 6) uniform sampler2D history_b;
layout(rgba16f, set = 0, binding = 7) uniform restrict writeonly image2D out_a;
layout(rgba16f, set = 0, binding = 8) uniform restrict writeonly image2D out_b;

ivec2 zs_block_offset(int frame) {
	int k = frame & 3;
	return k == 0 ? ivec2(0, 0) : (k == 1 ? ivec2(1, 1) : (k == 2 ? ivec2(1, 0) : ivec2(0, 1)));
}

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(out_a);
	if (any(greaterThanEqual(pixel, size))) return;
	ivec2 low = textureSize(march_a, 0);
	ivec2 offset = zs_block_offset(int(P.eye.w));
	vec2 uv = (vec2(pixel) + 0.5) / vec2(size);
	vec3 view_dir = normalize(vec3((uv.x * 2.0 - 1.0) * P.lens.x, (1.0 - uv.y * 2.0) * P.lens.y, -1.0));
	float d = texelFetch(scene_depth, min(pixel, textureSize(scene_depth, 0) - 1), 0).r;
	float t_solid = 1e9;
	if (d > 0.0) {
		float z = P.planes.x * P.planes.y / (P.planes.x + d * (P.planes.y - P.planes.x));
		t_solid = z / max(-view_dir.z, 1e-4);
	}

	// This frame's march round this pixel: the four nearest samples (march
	// pixel p stands at render pixel 2p + offset), weighted by distance and
	// by how near their solid stands to this pixel's.
	vec2 lp = (vec2(pixel - offset)) * 0.5;
	ivec2 base = ivec2(floor(lp));
	vec2 f = lp - vec2(base);
	vec4 a = vec4(0.0), b = vec4(0.0);
	vec4 lo_a = vec4(1e9), hi_a = vec4(-1e9), lo_b = vec4(1e9), hi_b = vec4(-1e9);
	float wsum = 0.0;
	for (int k = 0; k < 4; k++) {
		ivec2 o = ivec2(k & 1, k >> 1);
		ivec2 q = clamp(base + o, ivec2(0), low - 1);
		float bil = (o.x == 1 ? f.x : 1.0 - f.x) * (o.y == 1 ? f.y : 1.0 - f.y);
		float ld = texelFetch(march_depth, q, 0).r;
		float rel = abs(ld - t_solid) / max(min(ld, t_solid), 1.0);
		float near = exp(-rel * 8.0);
		float w = (bil + 0.02) * near + 1e-6;
		vec4 na = texelFetch(march_a, q, 0);
		vec4 nb = texelFetch(march_b, q, 0);
		a += na * w;
		b += nb * w;
		wsum += w;
		if (near > 0.3) {
			lo_a = min(lo_a, na); hi_a = max(hi_a, na);
			lo_b = min(lo_b, nb); hi_b = max(hi_b, nb);
		}
	}
	a /= wsum;
	b /= wsum;
	if (lo_b.x > hi_b.x) {
		lo_a = a; hi_a = a; lo_b = b; hi_b = b;
	}
	// Marched this frame: its own sample, exactly.
	bool marched = all(equal((pixel - offset) & 1, ivec2(0))) && all(greaterThanEqual(pixel - offset, ivec2(0)));
	if (marched) {
		ivec2 q = min((pixel - offset) / 2, low - 1);
		a = texelFetch(march_a, q, 0);
		b = texelFetch(march_b, q, 0);
	}
	if (P.lens.w < 0.5) {
		imageStore(out_a, pixel, a);
		imageStore(out_b, pixel, b);
		return;
	}
	// Where the cloud seen here stood last frame: its mean distance along
	// the ray, else far off.
	vec3 rd = normalize(mat3(P.camera) * view_dir);
	float dist = b.x > 0.01 ? b.y / b.x : min(t_solid, 4000.0);
	vec4 v = P.prev_view * vec4(P.eye.xyz + rd * dist, 1.0);
	float blend = marched ? P.planes.z : P.lens.z;
	vec2 prev_uv = uv;
	if (v.z < -0.01) prev_uv = vec2(v.x / (-v.z) / P.prev_lens.x * 0.5 + 0.5, 0.5 - v.y / (-v.z) / P.prev_lens.y * 0.5);
	else blend = 1.0;
	if (any(lessThan(prev_uv, vec2(0.0))) || any(greaterThan(prev_uv, vec2(1.0)))) blend = 1.0;
	// The history may stray a little past the neighbourhood (the march is
	// coarse), never far.
	vec4 pad_a = (hi_a - lo_a) * 0.15 + 0.002;
	vec4 pad_b = (hi_b - lo_b) * 0.15 + 0.002;
	vec4 ha = clamp(textureLod(history_a, prev_uv, 0.0), lo_a - pad_a, hi_a + pad_a);
	vec4 hb = clamp(textureLod(history_b, prev_uv, 0.0), lo_b - pad_b, hi_b + pad_b);
	imageStore(out_a, pixel, max(mix(ha, a, blend), vec4(0.0)));
	imageStore(out_b, pixel, max(mix(hb, b, blend), vec4(0.0)));
}
