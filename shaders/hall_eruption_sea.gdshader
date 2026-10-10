shader_type spatial;
// The hall eruption study's cloud sea (studies/hall_eruption.gd): a greybox
// floor of soft heaps, opaque so a piece under it is hidden till it breaks
// through. Heaped in world metres (the mesh follows the eye), drifting.
render_mode cull_back, diffuse_lambert, specular_disabled;
uniform vec3 top : source_color = vec3(0.9, 0.92, 0.96);
uniform vec3 under : source_color = vec3(0.55, 0.61, 0.74);
uniform float heap = 7.0;
uniform float scale = 0.011;
uniform vec2 drift = vec2(0.6, 0.25);

varying float h;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float heaps(vec2 w) {
	vec2 p = (w + drift * TIME) * scale;
	float n = noise(p) * 0.55 + noise(p * 2.3 + 7.1) * 0.3 + noise(p * 5.1 + 3.3) * 0.15;
	return smoothstep(0.2, 0.85, n);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float e = 3.0;
	float c = heaps(w.xz);
	float dx = heaps(w.xz + vec2(e, 0.0)) - c;
	float dz = heaps(w.xz + vec2(0.0, e)) - c;
	h = c;
	VERTEX.y += c * heap;
	NORMAL = normalize(vec3(-dx * heap / e, 1.0, -dz * heap / e));
}

void fragment() {
	ALBEDO = mix(under, top, clamp(h * 0.8 + 0.35, 0.0, 1.0));
	ROUGHNESS = 1.0;
}
