#[compute]
#version 450
// The clean look's pass (scripts/endless/clean_post.gd): after everything is
// drawn, in linear light before the tone map,
//   - a faint line on ridges and silhouettes far enough off to be shapes (a
//     depth jump to the sky or to land much farther), laid in the haze's own
//     colour on the nearer side, never dark;
//   - a light grade: highlights a little warm, shadows a little cool.
// Each pixel reads and writes only itself in the colour image.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(push_constant, std430) uniform Params {
	vec4 lens;   // near, far, edge strength, grade strength
	vec4 edge;   // edge colour rgb, reach (px)
	vec4 warm;   // highlight tint rgb, edge begin (m)
	vec4 cool;   // shadow tint rgb, edge full (m)
} P;

layout(set = 0, binding = 0) uniform sampler2D scene_depth;
layout(rgba16f, set = 0, binding = 1) uniform restrict image2D color_image;

float lin_z(ivec2 q) {
	ivec2 ts = textureSize(scene_depth, 0);
	float d = texelFetch(scene_depth, clamp(q, ivec2(0), ts - 1), 0).r;
	if (d <= 0.0) return P.lens.y * 20.0;
	return P.lens.x * P.lens.y / (P.lens.x + d * (P.lens.y - P.lens.x));
}

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(color_image);
	if (any(greaterThanEqual(pixel, size))) return;
	vec3 col = imageLoad(color_image, pixel).rgb;
	if (P.lens.z > 0.0) {
		float zc = lin_z(pixel);
		if (zc < P.lens.y * 2.0) {
			int r = int(P.edge.w);
			float far_most = 0.0;
			far_most = max(far_most, lin_z(pixel + ivec2(r, 0)));
			far_most = max(far_most, lin_z(pixel - ivec2(r, 0)));
			far_most = max(far_most, lin_z(pixel + ivec2(0, r)));
			far_most = max(far_most, lin_z(pixel - ivec2(0, r)));
			float jump = (far_most - zc) / zc;
			float e = smoothstep(0.18, 0.6, jump) * smoothstep(P.warm.w, P.cool.w, zc);
			col = mix(col, P.edge.rgb, e * P.lens.z);
		}
	}
	if (P.lens.w > 0.0) {
		float l = dot(col, vec3(0.2126, 0.7152, 0.0722));
		float sw = 1.0 - smoothstep(0.02, 0.4, l);
		float lw = smoothstep(0.2, 1.0, l);
		col *= mix(vec3(1.0), P.cool.rgb, sw * P.lens.w);
		col *= mix(vec3(1.0), P.warm.rgb, lw * P.lens.w);
	}
	imageStore(color_image, pixel, vec4(col, 1.0));
}
