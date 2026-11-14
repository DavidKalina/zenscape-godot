#[compute]
#version 450
// The weather map the march reads, eased from the last whole map into the
// newest over a slice cycle (scripts/cloud_volume_effect.gd weather_blend).
// A sliced map is whole only every few frames, so whatever the map bakes in
// that changes with time (the storm building and moving, the cells' life)
// stepped at each swap: the clouds grew in visible jerks. Here each texel of
// the newest map (b) is mixed with the last map's (a) at the same field
// point, by how far the cycle has run (knobs.y, 0 on the frame a map swaps
// in, so the shown map runs on unbroken), and the march reads the mix in the
// newest map's square, drift and phase.
//
// off: where the newest map's texel (as uv of the last map, before the
// shift) stands in the last map, low layer (xy) and high layer (zw), in the
// last map's uv; knobs: the newest map's side over the last's, the mix, the
// last map there (1), unused.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(push_constant, std430) uniform Blend {
	vec4 off;
	vec4 knobs;
} B;

layout(set = 0, binding = 0) uniform sampler2D map_a;
layout(set = 0, binding = 1) uniform sampler2D map_b;
layout(rgba16f, set = 0, binding = 2) uniform restrict writeonly image2D out_map;

bool inside(vec2 uv) {
	return all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0)));
}

void main() {
	ivec2 t = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(out_map);
	if (any(greaterThanEqual(t, size))) return;
	vec4 b = texelFetch(map_b, t, 0);
	if (B.knobs.z > 0.5 && B.knobs.y < 1.0) {
		vec2 uv = (vec2(t) + 0.5) / vec2(size) * B.knobs.x;
		vec2 ul = uv + B.off.xy;
		vec2 uh = uv + B.off.zw;
		vec4 a = b;
		if (inside(ul)) a.xy = textureLod(map_a, ul, 0.0).xy;
		if (inside(uh)) a.zw = textureLod(map_a, uh, 0.0).zw;
		b = mix(a, b, B.knobs.y);
	}
	imageStore(out_map, t, b);
}
