shader_type spatial;
// Curtains of leafy vines in the tunnels (scripts/endless/land_tunnels.gd
// `_build_growth`): a card hung from its top edge, scaled to its width and
// length in metres, cut to a few wavering stems of alternate leaves, each
// stem its own length, the leaves thinning and shrinking down it. It sways
// a little, more at its foot. Torch lit only: no sky fill, no haze.
render_mode cull_disabled, ambient_light_disabled, fog_disabled, diffuse_burley;

uniform vec3 tint : source_color = vec3(0.12, 0.26, 0.06);
uniform vec3 tint_old : source_color = vec3(0.2, 0.22, 0.07);
uniform float stem_gap = 0.28;
uniform float leaf_gap = 0.16;
uniform float leaf_size = 0.085;

varying vec2 size;
varying float phase;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	size = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	phase = INSTANCE_CUSTOM.x * 6.2831;
	float down = UV.y;
	VERTEX.z += sin(TIME * 0.8 + phase + down * 2.5) * 0.12 * down * down * size.y / max(length(MODEL_MATRIX[2].xyz), 0.001);
	VERTEX.x += sin(TIME * 0.6 + phase * 1.3 + down * 1.7) * 0.05 * down / max(size.x, 0.001);
}

void fragment() {
	vec2 p = vec2(UV.x * size.x, UV.y * size.y);
	float n = max(floor(size.x / stem_gap), 1.0);
	float gap = size.x / n;
	float i0 = floor(p.x / gap);
	float hit = 0.0;
	float shade = 0.0;
	vec2 lean = vec2(0.0);
	for (float di = -1.0; di <= 1.0; di += 1.0) {
		float i = i0 + di;
		if (i < 0.0 || i >= n) continue;
		float h = hash(vec2(i, phase));
		float stem_len = size.y * mix(0.35, 1.0, h);
		if (p.y > stem_len) continue;
		float x = (i + 0.5) * gap + sin(p.y * 1.4 + h * 9.0) * 0.1 + sin(p.y * 4.1 + h * 3.0) * 0.03;
		float t = p.y / stem_len;
		// The stem.
		if (abs(p.x - x) < 0.012 * (1.0 - t * 0.5)) {
			hit = 1.0;
			shade = 0.55;
		}
		// The leaves, alternate either side, every leaf_gap down.
		float k = floor(p.y / leaf_gap);
		for (float dk = -1.0; dk <= 1.0; dk += 1.0) {
			float kk = k + dk;
			float hk = hash(vec2(i * 13.0 + kk, h));
			if (hk < t * 0.55) continue;
			float side = mod(kk, 2.0) < 1.0 ? -1.0 : 1.0;
			vec2 c = vec2(x + side * 0.06, (kk + 0.5) * leaf_gap);
			float r = leaf_size * mix(0.7, 1.25, hk) * (1.0 - t * 0.4);
			vec2 d = p - c;
			// A leaf: an ellipse tipped out and down.
			float a = side * 0.7;
			vec2 q = vec2(cos(a) * d.x - sin(a) * d.y, sin(a) * d.x + cos(a) * d.y);
			if (dot(q / vec2(r * 0.6, r), q / vec2(r * 0.6, r)) < 1.0) {
				hit = 1.0;
				shade = mix(0.75, 1.3, hk);
				lean = vec2(side * 0.5, hk - 0.5);
			}
		}
	}
	if (hit < 0.5) discard;
	vec3 base = mix(tint, tint_old, step(0.8, shade) * 0.5);
	ALBEDO = base * shade;
	ROUGHNESS = 0.7;
	BACKLIGHT = base * 0.6;
	// A faint fill, so a curtain over the torches' reach still shows.
	EMISSION = ALBEDO * 0.25;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(lean.x, 0.0, lean.y, 0.0)).xyz * 0.5);
}
