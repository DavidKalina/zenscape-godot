shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;
// The storm dragon's hide (scripts/dragon_glimpse.gd; the old one is its
// StandardMaterial3D, one switch away: --hide=old, H): overlapping scales
// laid in the skin's own space (model position, never the UVs), near-black
// purple, wet. Scales are the nearest cell of a 3D cellular noise (the
// project's hash-noise idiom, shaders/dragon_loom.gdshader), each with a
// domed face and a raised lip toward the head that shingles over the next,
// so the normal says "scales" and the lip catches a glint in the flash.
// Larger plates on the belly (laid in bands), small scales on the neck,
// a ridge of spine plates down the back. The mesh's smoothed normals
// (dragon_glimpse.gd `_smooth`) carry the big form; these carry the small.

uniform vec3 hide : source_color = vec3(0.035, 0.024, 0.05);
uniform vec3 sheen : source_color = vec3(0.30, 0.20, 0.55);
// Cell size (model units; the dragon is 1.5x in the world) on the body,
// on the belly, and on the neck.
uniform float body_size = 0.85;
uniform float belly_size = 1.9;
uniform float neck_size = 0.5;
// How lit it is by the flash now (0 to 1), and how close (0 far, 1 close).
uniform float lit = 0.0;
uniform float close = 0.0;
uniform float bump = 1.0;

varying vec3 mpos;
varying vec3 mnorm;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

vec3 hash3(vec3 p) {
	return vec3(hash(p), hash(p + 17.31), hash(p + 41.73));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	mpos = VERTEX;
	mnorm = NORMAL;
}

void fragment() {
	vec3 n0 = normalize(mnorm);
	// Which part of the body: belly (down-facing), neck (toward the head,
	// -z), spine (up-facing, near the middle).
	float belly = smoothstep(-0.25, -0.65, n0.y);
	float neck = smoothstep(-6.0, -20.0, mpos.z) * (1.0 - belly);
	float size = mix(mix(body_size, neck_size, neck), belly_size, belly);
	vec3 q = mpos / size;
	// Nearest and next-nearest cell centres.
	vec3 cell = floor(q);
	float f1 = 9.0;
	float f2 = 9.0;
	vec3 c1 = vec3(0.0);
	vec3 id1 = cell;
	for (int x = -1; x <= 1; x++) for (int y = -1; y <= 1; y++) for (int z = -1; z <= 1; z++) {
		vec3 id = cell + vec3(float(x), float(y), float(z));
		vec3 c = id + 0.15 + 0.7 * hash3(id);
		float d = length(q - c);
		if (d < f1) { f2 = f1; f1 = d; c1 = c; id1 = id; }
		else if (d < f2) { f2 = d; }
	}
	float edge = f2 - f1;
	// The scale's own frame on the surface: out from its centre, and along
	// the body (toward the tail, +z) in the surface.
	vec3 d = q - c1;
	vec3 dt = d - n0 * dot(d, n0);
	vec3 axis = vec3(0.0, 0.0, 1.0);
	vec3 at = axis - n0 * dot(axis, n0);
	at = at / max(length(at), 0.001);
	float along = dot(dt, at);
	// Dome, and a lip: the head-ward side rises and ends in a step.
	float face = smoothstep(0.0, 0.5, edge);
	float lip = smoothstep(0.18, 0.0, edge) * smoothstep(-0.1, -0.5, along);
	vec3 n = n0 - dt * 1.1 * bump * face - at * 0.5 * bump * (1.0 - face) - at * 0.3 * bump * lip;
	// The belly: bands across the body, each a plate.
	float band = fract(mpos.z / (belly_size * 0.9) + 0.35 * noise(mpos * 0.4));
	float plate = smoothstep(0.0, 0.1, band) * smoothstep(1.0, 0.8, band);
	n = mix(n, normalize(n0 - at * (0.6 - band) * 1.1 * bump), belly * 0.65);
	// The spine: ridged plates down the middle of the back.
	float spine_zone = smoothstep(0.55, 0.85, n0.y) * smoothstep(2.2, 0.6, abs(mpos.x));
	float ridge_p = fract(mpos.z / 1.6);
	float ridge = pow(1.0 - abs(ridge_p * 2.0 - 1.0), 1.5);
	n = normalize(mix(n, n0 - at * (ridge_p - 0.5) * 0.9 * bump, spine_zone));
	n = normalize(n);
	// To view space.
	vec3 nv = normalize((VIEW_MATRIX * vec4(mat3(MODEL_MATRIX) * n, 0.0)).xyz);
	NORMAL = nv;
	float vary = 0.7 + 0.6 * hash(id1);
	// The few wet ones: one scale in twenty or so, and one spine plate in
	// five, may catch the flash; the rest stay matt black (a sparse glint,
	// never bands down the neck and tail).
	float spark = smoothstep(0.9, 0.97, hash(id1 + 7.0));
	float plate_wet = step(0.8, hash(vec3(floor(mpos.z / 1.6), 3.1, 5.7)));
	float seam = smoothstep(0.0, 0.14, edge);
	float ndv = clamp(dot(nv, normalize(VIEW)), 0.0, 1.0);
	// Near-black purple, each scale its own shade, seams darker, a faint
	// violet at the scale's lip.
	vec3 col = hide * vary * mix(0.35, 1.0, seam);
	col *= mix(1.0, 0.55, belly * (1.0 - plate));
	col *= 1.0 + 0.25 * spine_zone * ridge;
	ALBEDO = col;
	// Wet: glossy, the lips and seams glossier still.
	float wet = max(spark * max(lip, 1.0 - seam), plate_wet * spine_zone * ridge);
	ROUGHNESS = mix(mix(0.5, 0.7, face), 0.24, wet);
	SPECULAR = mix(0.05, 0.35, wet);
	// Violet sheen at grazing angles, bright with the flash and near.
	float graze = pow(1.0 - ndv, 3.0);
	vec3 em = sheen * graze * (0.02 + 0.05 * lit) * seam;
	// The glint: where a lip or a seam turns edge-on to the eye, wet,
	// lit by the flash behind it; sparks, not a wash.
	float catch_ = pow(1.0 - ndv, 4.0) * (spark * (lip + (1.0 - seam) * 0.3) + plate_wet * spine_zone * ridge * 0.6);
	em += vec3(0.55, 0.5, 0.85) * catch_ * 0.6 * lit * (0.5 + 0.5 * close);
	EMISSION = em;
	RIM = 0.0;
}
