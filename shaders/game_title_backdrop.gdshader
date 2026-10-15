shader_type canvas_item;
// The title's backdrop (scripts/roguelike/game_title.gd): the underground
// look in a still frame. Ranks of Olmec columns going back into fog, a
// torch's warm pool low on the left that breathes, a pale shaft of the
// far-off sky falling from above (the climb's goal), and dust drifting up
// through it. All procedural; nothing here is a texture.
uniform float aspect = 1.7778;
uniform float fade_in : hint_range(0.0, 1.0) = 1.0;
uniform vec3 deep = vec3(0.012, 0.014, 0.020);
uniform vec3 fog = vec3(0.10, 0.085, 0.075);
uniform vec3 torch = vec3(1.0, 0.52, 0.2);
uniform vec3 sky = vec3(0.62, 0.74, 0.86);

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}

// One rank of columns: x = 1 where stone stands, y = across the column
// (0 left face .. 1 right) for its shading. `scale` columns per unit of
// width; tops run past the frame on the near ranks.
vec2 rank(vec2 p, float scale, float seed, float drift, float top) {
	float x = p.x * scale + drift;
	float id = floor(x);
	float fx = fract(x);
	float w = 0.16 + 0.12 * hash(id + seed);
	float h = top + 0.25 * hash(id * 1.7 + seed);
	float u = (fx - 0.5) / w + 0.5;
	float on = step(abs(fx - 0.5), w * 0.5) * step(p.y, h);
	return vec2(on, u);
}

void fragment() {
	vec2 uv = UV;
	vec2 p = vec2((uv.x - 0.5) * aspect, 1.0 - uv.y); // p.y 0 at the bottom
	float t = TIME;

	vec3 col = mix(deep, fog * 0.5, smoothstep(0.0, 0.65, p.y) * (1.0 - smoothstep(0.65, 1.2, p.y)));

	// the shaft of far sky: a cone from the top, a little left of centre
	float sx = p.x - 0.10 - (1.0 - p.y) * 0.08;
	float cone = exp(-pow(sx / (0.10 + (1.0 - p.y) * 0.34), 2.0)) * smoothstep(0.12, 1.0, p.y);
	cone *= 0.8 + 0.2 * noise(vec2(p.x * 3.0, t * 0.15));
	col += sky * cone * 0.30;

	// columns, far to near: paler and thinner far off, black and broad near
	for (int i = 0; i < 4; i++) {
		float k = float(i);
		float depth = k / 3.0;
		float scale = mix(3.2, 0.9, depth);
		vec2 st = rank(p, scale, 11.0 * k + 3.0, k * 0.37 + sin(t * 0.05 + k) * 0.01, mix(0.80, 1.4, depth));
		float stone = st.x;
		vec3 tone = mix(fog * 1.15 + sky * 0.04, vec3(0.006, 0.006, 0.009), depth);
		// rounded: the left face toward the torch is lit, the right in shadow
		float round = smoothstep(0.0, 1.0, 1.0 - st.y);
		tone += torch * 0.10 * round * smoothstep(0.9, -0.5, p.x) * (0.4 + 0.6 * depth) * smoothstep(0.9, 0.0, p.y);
		tone += sky * 0.07 * cone * (1.0 - depth) * (0.5 + 0.5 * st.y);
		// the foot of every column sinks in the dark, the far ones in fog
		tone = mix(deep, tone, smoothstep(0.0, 0.35, p.y));
		col = mix(col, tone, stone);
		col = mix(col, fog * 0.6, 0.12 * (1.0 - depth) * smoothstep(0.7, 0.0, p.y));
	}

	// the torch: a warm pool low on the left, breathing
	vec2 tp = vec2(p.x + 0.55, p.y - 0.17);
	float flick = 0.86 + 0.10 * sin(t * 7.3) * sin(t * 3.1 + 1.0) + 0.06 * noise(vec2(t * 5.0, 2.0));
	float pool = exp(-dot(tp, tp) * 5.5) * flick;
	col += torch * pool * 0.34;
	float core = exp(-dot(tp, tp) * 120.0) * flick;
	col += vec3(1.0, 0.8, 0.5) * core * 0.5;

	// dust drifting up, brightest in the shaft and the torch's light
	float dust = 0.0;
	for (int j = 0; j < 3; j++) {
		float s = 14.0 + float(j) * 9.0;
		vec2 q = vec2(p.x * s + float(j) * 7.1 + sin(t * 0.3 + float(j)) * 0.6, p.y * s - t * (0.35 + 0.2 * float(j)));
		vec2 c = floor(q);
		vec2 f = fract(q) - 0.5;
		float r = hash2(c + float(j) * 31.0);
		vec2 o = vec2(hash2(c * 1.3) - 0.5, hash2(c * 2.1) - 0.5) * 0.5;
		float m = smoothstep(0.07, 0.0, length(f - o)) * step(0.55, r);
		dust += m * (0.5 + 0.5 * sin(t * (1.0 + r * 2.0) + r * 40.0));
	}
	col += (sky * cone * 0.9 + torch * pool * 0.7 + vec3(0.03)) * dust * 0.9;

	float v = smoothstep(1.25, 0.25, length(vec2(p.x * 0.8, p.y - 0.5)));
	col *= mix(0.45, 1.0, v);
	col += (hash2(uv * 997.0 + t) - 0.5) * 0.012;
	COLOR = vec4(col * fade_in, 1.0);
}
