shader_type spatial;
// The cloud sea the aqueduct isle's halls rise from (studies/
// aqueduct_isle_chain.gd, docs/design/isle-hall-chain.md): the hall rise
// study's greybox sea (shaders/hall_rise_sea.gdshader, the same heaps and
// swells), but a patch of it, not the whole world. It is opaque over the
// patch (so a chunk under it is hidden till it breaks through) and breaks
// up into ragged clumps (cut out by a slow noise) at its rim (`patch`:
// centre x, z, radius, fade, world metres) and round the isle (`hole`: the
// same), sagging there so its edge sinks away rather than standing as a
// wall.
render_mode cull_back, diffuse_lambert, specular_disabled;
uniform vec3 top : source_color = vec3(0.93, 0.94, 0.97);
uniform vec3 under : source_color = vec3(0.62, 0.68, 0.8);
uniform float heap = 7.0;
uniform float scale = 0.011;
uniform vec2 drift = vec2(0.6, 0.25);
uniform vec4 swells[6];
uniform int swell_count = 0;
uniform vec4 patch = vec4(0.0, 0.0, 420.0, 120.0);
uniform vec4 hole = vec4(85.0, -20.0, 220.0, 100.0);
uniform float sag = 22.0;

varying float h;
varying float cover;
varying vec2 world;

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

float swell(vec2 w) {
	float lift = 0.0;
	for (int i = 0; i < 6; i++) {
		if (i >= swell_count) break;
		vec4 s = swells[i];
		float d = length(w - s.xy) / max(s.z, 1.0);
		float dome = 1.0 - smoothstep(0.35, 1.15, d);
		float boil = 0.6 + 0.4 * noise(w * 0.09 + vec2(TIME * 1.3, -TIME * 0.9));
		lift += s.w * dome * boil;
	}
	return lift;
}

// How much sea there is at w (0 to 1): the patch, less the isle's hole
// (studies/aqueduct_isle_chain.gd `cover` is the same).
float covered(vec2 w) {
	float inside = 1.0 - smoothstep(patch.z, patch.z + patch.w, length(w - patch.xy));
	float clear = smoothstep(hole.z, hole.z + hole.w, length(w - hole.xy));
	return inside * clear;
}

float height(vec2 w) {
	return heaps(w) * heap + swell(w);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float e = 3.0;
	float c = height(w.xz);
	float dx = height(w.xz + vec2(e, 0.0)) - c;
	float dz = height(w.xz + vec2(0.0, e)) - c;
	h = c / heap;
	cover = covered(w.xz);
	world = w.xz;
	VERTEX.y += c - (1.0 - cover) * sag;
	NORMAL = normalize(vec3(-dx / e, 1.0, -dz / e));
}

void fragment() {
	// Ragged: thinning sea breaks into clumps by a slow noise.
	float n = noise(world * 0.035) * 0.65 + noise(world * 0.11 + 4.7) * 0.35;
	if (cover < 0.05 + 0.9 * n) discard;
	ALBEDO = mix(under, top, clamp(h * 0.8 + 0.35, 0.0, 1.0));
	ROUGHNESS = 1.0;
}
