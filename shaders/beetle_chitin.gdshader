shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// The Millstone Beetle's shell (scripts/enemies/millstone_look.gd): old,
// heavy chitin, real stuff rather than a toy's colour. A dark umber and
// olive-bronze plate, worn paler on its high points and edges, scored with
// fine scratches and pitted, stone dust (ochre, the turf's own) caked up
// from the feet and settled in the seams, a dull sheen left only on the
// clean tops. All in solid noise over each part's REST pose (the mesh's own
// space, plus `part_lift`, the part's height over the ground at rest), so
// the grain rides on the moving body. Fine layers fade by pixel footprint
// so they never shimmer; at gameplay range the broad washes and the value
// step from dark shell to pale dust carry it.

uniform vec3 shell_dark : source_color = vec3(0.15, 0.12, 0.085);
uniform vec3 shell_warm : source_color = vec3(0.29, 0.23, 0.15);
uniform vec3 shell_worn : source_color = vec3(0.36, 0.31, 0.22);
uniform vec3 dust : source_color = vec3(0.60, 0.50, 0.35);
// The dust's rise from the ground (m): caked under this, gone over it.
uniform float dust_rise = 0.2;
// The grain's scale (cycles a metre) of the broad washes.
uniform float grain = 3.2;
uniform float sheen = 0.42;
// A leg or a joint: rougher, darker, dustier.
instance uniform float part_lift = 0.0;
instance uniform float part_dust = 0.0;
instance uniform float part_seed = 0.0;

varying vec3 rest;
varying vec3 rest_n;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.17, 0.13));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
			mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
			mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return s;
}

void vertex() {
	rest = VERTEX + vec3(part_seed * 7.31, part_lift, part_seed * 3.17);
	rest_n = NORMAL;
}

void fragment() {
	// The pixel's footprint on the rest pose: fine layers fade as it grows.
	float foot = length(fwidth(rest));
	float fine = 1.0 - smoothstep(0.012, 0.05, foot);
	float mid = 1.0 - smoothstep(0.05, 0.2, foot);

	// Broad washes: dark plate warming to bronze in soft patches.
	float wash = fbm(rest * grain);
	vec3 col = mix(shell_dark, shell_warm, smoothstep(0.32, 0.72, wash));
	// Worn pale on the high points (facing up and out) and in a few rubbed patches.
	float up = clamp(rest_n.y, 0.0, 1.0);
	float rub = smoothstep(0.55, 0.85, fbm(rest * grain * 2.1 + 4.0)) * (0.35 + 0.65 * up);
	col = mix(col, shell_worn, rub * 0.4);
	// Scratches: thin ridged streaks, raked along the body.
	float scr = 1.0 - abs(vnoise(rest * vec3(3.0, 26.0, 9.0)) * 2.0 - 1.0);
	scr = smoothstep(0.93, 0.99, scr) * smoothstep(0.4, 0.7, vnoise(rest * 4.0 + 11.0));
	col = mix(col, shell_worn, scr * 0.28 * fine);
	// Pits: small dark dots.
	float pit = smoothstep(0.8, 0.9, vnoise(rest * 38.0));
	col *= 1.0 - pit * 0.45 * fine;
	// Dust: caked up from the feet, broken at its top edge; in the seams
	// (facing down and sideways) a little higher.
	float h = rest.y;
	float edge = (fbm(rest * 9.0) - 0.5) * 0.18 * (0.4 + 0.6 * mid);
	float side = 1.0 - abs(rest_n.y);
	float rise = dust_rise * (1.0 + 0.6 * side) + part_dust;
	float caked = 1.0 - smoothstep(rise * 0.55, rise, h + edge);
	// Dust settled in the dome's low folds too, lightly.
	caked = max(caked, smoothstep(0.62, 0.8, fbm(rest * 5.0 + 2.0)) * 0.35 * up);
	vec3 dusty = dust * (0.82 + 0.3 * vnoise(rest * 21.0) * mid);
	col = mix(col, dusty, clamp(caked, 0.0, 1.0));
	ALBEDO = col;
	// A dull sheen only where it is clean and on top.
	float clean = (1.0 - caked) * (1.0 - rub * 0.6);
	ROUGHNESS = mix(0.92, 1.0 - sheen, clean * (0.4 + 0.6 * up));
	SPECULAR = 0.35 * clean;
}
