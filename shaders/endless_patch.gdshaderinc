// The endless ground's patch noise (shaders/endless_ground.gdshader), which
// the grass carpet's tufts read too (scripts/endless/endless_patch.gd, its
// twin in GDScript, tints each tuft by it on the worker that grows it), so
// the tufts carry the painted ground's patches and the carpet sits in the
// field it fades into. Value noise over an integer hash, so the CPU and the
// GPU get the same lattice.

uint ep_hash(ivec2 q) {
	uint h = uint(q.x) * 1597334677u ^ uint(q.y) * 3812015801u;
	h ^= h >> 16u;
	h *= 2246822519u;
	h ^= h >> 13u;
	h *= 3266489917u;
	h ^= h >> 16u;
	return h;
}

float ep_lattice(ivec2 q) {
	return float(ep_hash(q) >> 8u) / 16777215.0;
}

float ep_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	f = f * f * (3.0 - 2.0 * f);
	ivec2 q = ivec2(i);
	return mix(mix(ep_lattice(q), ep_lattice(q + ivec2(1, 0)), f.x),
		mix(ep_lattice(q + ivec2(0, 1)), ep_lattice(q + ivec2(1, 1)), f.x), f.y);
}

// Noise at `scale` m round its mean (-0.5..0.5), faded to the mean where a
// pixel's footprint `fp` (m) grows past a share of the scale.
float ep_fade(vec2 p, float scale, float fp) {
	float keep = 1.0 - smoothstep(scale * 0.18, scale * 0.6, fp);
	if (keep <= 0.0) return 0.0;
	return (ep_noise(p / scale) - 0.5) * keep;
}

// The same as a patch with a defined edge (-0.5 or 0.5 either side), the
// edge widening to a blur as the pixel grows, faded to its mean far off.
float ep_patch(vec2 p, float scale, float fp) {
	float keep = 1.0 - smoothstep(scale * 0.18, scale * 0.6, fp);
	if (keep <= 0.0) return 0.0;
	float w = 0.07 + fp / scale * 1.2;
	return (smoothstep(0.5 - w, 0.5 + w, ep_noise(p / scale)) - 0.5) * keep;
}
