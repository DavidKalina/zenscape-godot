#ifndef ZS_CRAFT_GRIME_INC
#define ZS_CRAFT_GRIME_INC
// The flying craft's weathering (the plane, shaders/plane_surface.gdshader;
// the airship, shaders/airship_surface.gdshader), brought in through
// folk_surface.gdshaderinc with ZS_CRAFT_GRIME so the craft are lit as the
// ruins' stone is. Painted in solid noise over the mesh's own frame (no UVs),
// on top of the paint's colour:
//   - the colour pulled down toward its own grey (`grit_grade`),
//   - broad washes, lighter and darker, a panel's size,
//   - streaks run down the upright faces (rain, oil, soot),
//   - grime settled on the undersides and in dirty patches,
//   - a fine grain, faded by pixel footprint so it never shimmers.
// `grit` 0 leaves the paint clean; `grit_scale` is cells a mesh unit (the
// plane's toy units are small, the airship's are metres). `own` shifts a
// paint's colour a touch so neighbours read as painted apart; `shine` lowers
// the roughness for metal.
uniform float grit : hint_range(0.0, 2.0) = 1.0;
uniform float grit_scale = 1.0;
uniform float grit_grade : hint_range(0.0, 1.0) = 0.3;
uniform float grit_streak = 1.0;
uniform vec3 grit_grime : source_color = vec3(0.22, 0.2, 0.17);
uniform float own = 0.5;
uniform float shine = 0.0;

float cg_hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float cg_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(cg_hash(i), cg_hash(i + vec3(1, 0, 0)), f.x),
			mix(cg_hash(i + vec3(0, 1, 0)), cg_hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(cg_hash(i + vec3(0, 0, 1)), cg_hash(i + vec3(1, 0, 1)), f.x),
			mix(cg_hash(i + vec3(0, 1, 1)), cg_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// Weathers `base` at the mesh point `at` whose world normal is `wn`; returns
// what to add to the roughness.
float craft_grime(inout vec3 base, vec3 at, vec3 wn) {
	base *= mix(vec3(1.03, 1.0, 0.96), vec3(0.97, 1.0, 1.04), own);
	float lum = dot(base, vec3(0.3, 0.55, 0.15));
	base = mix(base, vec3(lum), 0.4 * grit_grade);
	base *= 1.0 - 0.08 * grit_grade;
	if (grit <= 0.0) return -shine * 0.5;
	vec3 p = at * grit_scale;
	// Broad washes.
	float wash = cg_noise(p * 0.55) * 0.6 + cg_noise(p * 1.3 + 5.2) * 0.4;
	base *= 1.0 + (wash - 0.5) * 0.3 * grit;
	// Streaks down the upright faces: noise stretched along the mesh's Y.
	float side = 1.0 - abs(wn.y);
	float s = cg_noise(vec3(p.x * 7.0, p.y * 0.4, p.z * 7.0)) * 0.7 + cg_noise(vec3(p.x * 19.0, p.y * 1.1, p.z * 19.0) + 3.0) * 0.3;
	float streak = smoothstep(0.52, 0.8, s) * smoothstep(0.15, 0.7, side) * grit_streak;
	base = mix(base, base * 0.66 + grit_grime * 0.12, streak * 0.5 * grit);
	// Grime on the undersides and in patches.
	float under = smoothstep(0.15, -0.75, wn.y) * (0.55 + 0.45 * cg_noise(p * 2.1 + 11.0));
	float patch = smoothstep(0.6, 0.82, cg_noise(p * 1.6 + 2.7)) * 0.6;
	float dirt = clamp(max(under, patch) * grit, 0.0, 1.0);
	base = mix(base, base * 0.55 + grit_grime * 0.3, dirt * 0.42);
	// A fine grain, gone before it would shimmer.
	vec3 q = p * 22.0;
	float fade = 1.0 - smoothstep(0.35, 1.2, length(fwidth(q)));
	base *= 1.0 + (cg_noise(q) - 0.5) * 0.16 * grit * fade;
	return (wash - 0.5) * 0.12 * grit + dirt * 0.15 - shine * 0.5;
}

#ifdef ZS_CRAFT_DETAIL
// Close-up detail for a craft's piece seen in the hand (the found plane
// parts, shaders/plane_part_surface.gdshader): hammered dents, a brushed
// grain along the mesh's Z and bright scratches through the coat, raised
// as a bump off the screen's derivatives (no UVs, no tangents) and faded
// by pixel footprint so none of it shimmers. `detail_scale` is cells a
// mesh unit; `detail_bump` the dents' depth (m, in view space).
uniform float detail_scale = 30.0;
uniform float detail_bump = 0.004;
uniform float detail_grain = 0.35;
uniform float detail_scratch = 1.0;

// Details `base` and the view normal `n` at mesh point `at`, view point
// `view_at`; returns what to add to the roughness.
float craft_detail(inout vec3 base, inout vec3 n, vec3 at, vec3 view_at) {
	vec3 p = at * detail_scale;
	float near = 1.0 - smoothstep(0.35, 1.2, length(fwidth(p)));
	vec3 q = p * 6.0;
	float fine = 1.0 - smoothstep(0.35, 1.2, length(fwidth(q)));
	float dents = cg_noise(p) * 0.6 + cg_noise(p * 2.3 + 1.7) * 0.4;
	float grain = (cg_noise(q * vec3(1.0, 1.0, 0.12)) - 0.5) * fine;
	float sc = cg_noise(vec3(p.x * 4.0, p.y * 4.0, p.z * 0.35) + 7.0);
	float scratch = smoothstep(0.74, 0.84, sc) * (1.0 - smoothstep(0.9, 0.96, sc)) * fine * detail_scratch;
	float h = (dents - 0.5) * near + grain * detail_grain - scratch * 0.5;
	base *= 1.0 + (dents - 0.5) * 0.3 * near + grain * 0.12;
	base = mix(base, base * 1.6 + vec3(0.08), scratch * 0.5);
	// The bump: the height's slope across the screen, turned into a tilt of
	// the normal (Mikkelsen's surface gradient off the derivatives).
	vec3 dpdx = dFdx(view_at);
	vec3 dpdy = dFdy(view_at);
	float hx = dFdx(h) * detail_bump;
	float hy = dFdy(h) * detail_bump;
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 g = sign(det) * (hx * r1 + hy * r2);
	n = normalize(abs(det) * n - g);
	return -scratch * 0.3 + (dents - 0.5) * 0.1 * near;
}
#endif
#endif
