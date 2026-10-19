shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
// The storm dragon's wing membrane (scripts/dragon_glimpse.gd): thin, with
// veins. Two scales of cellular edges laid in the skin's own space make the
// network (stout veins, then fine ones); the vein is thick and near-black,
// the web between it thin, and a flash behind the wing shows through the
// thin web as a dull red-violet, dark where the veins are.

uniform vec3 skin : source_color = vec3(0.045, 0.03, 0.055);
uniform vec3 glow : source_color = vec3(0.4, 0.07, 0.22);
uniform float vein_size = 5.0;
uniform float fine_size = 1.6;
uniform float lit = 0.0;
uniform float close = 0.0;
// The glow's strength far off, and close.
uniform float glow_far = 0.05;
uniform float glow_close = 0.25;

varying vec3 mpos;

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

// Distance gap to the cell edge (0 on it), and the nearest cell's id.
float edge_of(vec3 q) {
	vec3 cell = floor(q);
	float f1 = 9.0;
	float f2 = 9.0;
	for (int x = -1; x <= 1; x++) for (int y = -1; y <= 1; y++) for (int z = -1; z <= 1; z++) {
		vec3 id = cell + vec3(float(x), float(y), float(z));
		float d = length(q - (id + 0.1 + 0.8 * hash3(id)));
		if (d < f1) { f2 = f1; f1 = d; }
		else if (d < f2) { f2 = d; }
	}
	return f2 - f1;
}

void vertex() {
	mpos = VERTEX;
}

void fragment() {
	// Veins wander a little (a warp), stout ones and fine ones.
	vec3 w = mpos + (vec3(noise(mpos * 0.7), noise(mpos * 0.7 + 9.0), noise(mpos * 0.7 + 21.0)) - 0.5) * 2.0;
	float e1 = edge_of(w / vein_size);
	float e2 = edge_of(w / fine_size + 3.0);
	float vein = max(smoothstep(0.07, 0.0, e1), smoothstep(0.05, 0.0, e2) * 0.7);
	float web = 1.0 - vein;
	// Thin patches in the web (it varies in thickness).
	float thin = 0.65 + 0.35 * noise(mpos * 0.5 + 40.0);
	ALBEDO = skin * mix(1.2, 0.5, vein);
	ROUGHNESS = mix(0.5, 0.3, vein);
	SPECULAR = 0.2;
	float strength = mix(glow_far, glow_close, close);
	// The flash behind it shows through the web.
	vec3 through = glow * strength * lit * web * thin;
	float ndv = abs(dot(normalize(NORMAL), normalize(VIEW)));
	EMISSION = through * (0.5 + 0.5 * (1.0 - ndv)) + vec3(0.3, 0.2, 0.45) * pow(1.0 - ndv, 3.0) * vein * lit * 0.25;
	BACKLIGHT = through * 0.4;
}
