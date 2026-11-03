// Gritty soil, shared by the burrower's earth (clods, torn crest).
// grit_albedo(p, base, wet, seed): damp dark earth with dry lighter crumbs,
// pale and dark grains, and bits of root or grass; grit_height(p, seed): a
// crumbly height for bump.

float g_hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float g_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(g_hash(i), g_hash(i + vec3(1, 0, 0)), f.x),
				   mix(g_hash(i + vec3(0, 1, 0)), g_hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(g_hash(i + vec3(0, 0, 1)), g_hash(i + vec3(1, 0, 1)), f.x),
				   mix(g_hash(i + vec3(0, 1, 1)), g_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float grit_height(vec3 p, float seed) {
	p += vec3(seed * 13.7, seed * 5.3, seed * 9.1);
	float h = g_noise(p * 5.0) * 0.5 + g_noise(p * 13.0) * 0.3 + g_noise(p * 34.0) * 0.2;
	// Crumbs: cells of pebbles standing out.
	h += step(0.72, g_noise(p * 21.0 + 7.0)) * 0.35;
	return h;
}

vec3 grit_albedo(vec3 p, vec3 base, float dry, float seed) {
	p += vec3(seed * 13.7, seed * 5.3, seed * 9.1);
	vec3 damp = base * 0.62;
	vec3 pale = mix(base, vec3(0.55, 0.40, 0.24), 0.5) * 1.05;
	float patch = g_noise(p * 4.0);
	float crumb = g_noise(p * 16.0);
	// Dry lighter crumbs on the damp dark earth; drier means more of them.
	float dry_mask = smoothstep(0.62 - dry * 0.22, 0.78 - dry * 0.22, crumb * 0.65 + patch * 0.5);
	vec3 c = mix(damp, pale, dry_mask * (0.55 + 0.45 * dry));
	// Mottle.
	c *= 0.82 + 0.36 * g_noise(p * 9.0);
	// Grains: fine pale and dark specks.
	float gr = g_noise(p * 70.0);
	c = mix(c, vec3(0.68, 0.58, 0.44), step(0.95, gr) * 0.55);
	c = mix(c, vec3(0.05, 0.04, 0.03), step(gr, 0.12) * 0.7);
	// Roots and grass: thin stretched streaks in a few directions.
	float f1 = g_noise(vec3(p.x * 55.0, p.y * 4.0, p.z * 4.0));
	float f2 = g_noise(vec3(p.x * 4.0, p.y * 4.0, p.z * 60.0) + 5.0);
	float fibre = max(step(0.86, f1), step(0.87, f2));
	vec3 root = mix(vec3(0.30, 0.20, 0.11), vec3(0.50, 0.40, 0.24), g_noise(p * 25.0));
	vec3 grass = vec3(0.16, 0.27, 0.07);
	vec3 fc = (base.g > base.r * 1.05) ? grass : root;
	c = mix(c, fc, fibre * 0.85);
	return c;
}
