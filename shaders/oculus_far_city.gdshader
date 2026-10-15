shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;
// The far cities of the oculus abyss (scripts/underground/far_cities.gd):
// weathered stone silhouettes going to the abyss's haze with distance, lit
// a little from the opening side, their windows warm speckles laid after the
// haze so they read across kilometres. COLOR.a flags the wall faces that
// have windows; INSTANCE_CUSTOM.x is a city's seed, .y how many of its
// windows burn.
uniform vec3 haze : source_color = vec3(0.13, 0.21, 0.23);
uniform vec3 stone : source_color = vec3(0.10, 0.125, 0.14);
uniform vec3 warm : source_color = vec3(1.0, 0.68, 0.38);
uniform vec3 light_dir = vec3(0.5, 0.7, 0.3);
uniform float glow = 1.0;
uniform float reach = 1500.0;

varying float dist;
varying vec3 wpos;
varying vec3 wnorm;
varying float wall;
varying vec2 seed;
varying vec3 local;

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	dist = length(wpos - (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
	wall = COLOR.a;
	seed = INSTANCE_CUSTOM.xy;
	local = VERTEX;
}

void fragment() {
	vec3 n = normalize(wnorm);
	float lit = clamp(dot(n, normalize(light_dir)) * 0.5 + 0.5, 0.0, 1.0);
	vec3 base = stone * COLOR.rgb * (0.5 + 0.6 * lit);
	// Distance takes them into the haze: gently, so a city a kilometre off keeps
	// its stepped shape and one at three is a pale ghost.
	float far = 1.0 - exp(-pow(dist / (reach * 1.5), 1.2));
	vec3 col = mix(base, haze * 1.15, far);
	// Windows: small lit panes in rows on the wall faces, a share of them burning.
	float win = 0.0;
	if (wall > 0.5) {
		vec2 g = vec2(local.x + local.z, local.y) * vec2(34.0, 22.0) + seed.x * 40.0;
		vec2 id = floor(g);
		vec2 f = fract(g);
		float pane = step(0.28, f.x) * step(f.x, 0.72) * step(0.3, f.y) * step(f.y, 0.7);
		float burns = step(h21(id + seed.x * 17.0), seed.y);
		win = pane * burns;
		// A pane smaller than a pixel would shimmer: it goes to its average light.
		float fw = max(fwidth(g.x), fwidth(g.y));
		win = mix(win, 0.08 * seed.y, smoothstep(0.3, 0.8, fw));
	}
	// Seen small and far a window is a speck of light, not a pane: widen it by distance.
	float speck = mix(1.0, 0.7, smoothstep(0.0, 1.0, dist / 3000.0));
	col += warm * win * glow * speck * (0.8 + 0.5 * h21(wpos.xz * 0.37 + floor(local.y * 22.0)));
	ALBEDO = col;
}
