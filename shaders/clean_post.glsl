#[compute]
#version 450
// The look's grade (scripts/endless/clean_post.gd): after everything is drawn,
// in linear light before the tone map, highlights a little warm and shadows a
// little cool. Each pixel reads and writes only itself in the colour image.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(push_constant, std430) uniform Params {
	vec4 warm;   // highlight tint rgb, unused
	vec4 cool;   // shadow tint rgb, unused
} P;

layout(rgba16f, set = 0, binding = 0) uniform restrict image2D color_image;

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(color_image);
	if (any(greaterThanEqual(pixel, size))) return;
	vec3 col = imageLoad(color_image, pixel).rgb;
	float l = dot(col, vec3(0.2126, 0.7152, 0.0722));
	float sw = 1.0 - smoothstep(0.02, 0.4, l);
	float lw = smoothstep(0.2, 1.0, l);
	col *= mix(vec3(1.0), P.cool.rgb, sw);
	col *= mix(vec3(1.0), P.warm.rgb, lw);
	// The tints cost the greens some colour; give it back.
	float l2 = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col = max(mix(vec3(l2), col, 1.03), vec3(0.0));
	imageStore(color_image, pixel, vec4(col, 1.0));
}
