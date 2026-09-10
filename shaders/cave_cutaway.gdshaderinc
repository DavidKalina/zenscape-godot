// Shared by the cave's rock and earth faces so both cut the same opening.
// `p` is room-local; `normal` is the wall's outward normal.
float cutaway_grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float cutaway_patch(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(mix(cutaway_grain(cell), cutaway_grain(cell + vec2(1, 0)), f.x),
		mix(cutaway_grain(cell + vec2(0, 1)), cutaway_grain(cell + vec2(1, 1)), f.x), f.y);
}
// Dithered discard keeps depth writes (display fog paints alpha as ground)
// and leaves a ragged rock frame around the opening.
bool cave_cutaway(vec3 p, vec3 normal, float half_width, float ceiling, float reveal, vec2 frag) {
	float along = dot(p.xz, vec2(normal.z, -normal.x));
	// A thin frame: about a metre at the sides, just clear of floor and ceiling.
	float ragged = (cutaway_patch(vec2(along, p.y) * 0.9) - 0.5) * 0.7;
	float inside = min(half_width - 1.0 - abs(along), min(p.y - 0.45, ceiling - 0.45 - p.y)) + ragged;
	float dither = fract(52.9829189 * fract(dot(frag, vec2(0.06711056, 0.00583715))));
	return reveal * smoothstep(0.0, 0.6, inside) > dither;
}
