shader_type canvas_item;
// Frost on the canopy (scripts/endless/canopy_frost.gd): feathered fronds
// grown in from the screen's edges, thickest in the corners. `cover` is how
// far in it reaches (0 none, 1 about a third of the way to the middle);
// `melt` turns the white to a clear wet film that bends the scene as the
// front draws back to the edges.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float cover = 0.0;
uniform float melt = 0.0;
uniform float aspect = 1.6;
uniform float grain = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return s;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 p = vec2(uv.x * aspect, uv.y) + grain;
	// How far in from the edges, in screen heights: the corners count closer.
	float dx = max(min(uv.x, 1.0 - uv.x) * aspect, 1e-4);
	float dy = max(min(uv.y, 1.0 - uv.y), 1e-4);
	float e = 1.0 / (1.0 / dx + 1.0 / dy);
	// Fronds: noise drawn out across the nearest edge (fine along it, long
	// inward), so the frost reaches in as feathered fingers, soft at their
	// tips; the reach itself swells and thins along the edge.
	float side = smoothstep(-0.04, 0.04, dy - dx);
	float fronds = mix(fbm(vec2(p.x * 22.0, p.y * 2.4)), fbm(vec2(p.x * 2.4, p.y * 22.0)), side);
	float rag = fbm(p * 2.6);
	float reach = cover * 0.16 * (0.45 + 0.9 * rag);
	float tip = reach * (0.3 + 1.2 * fronds);
	float front = tip - e;
	if (front <= 0.0) {
		discard;
	}
	float depth = front / max(tip, 1e-4);
	// Thick and white at the rim, thinning out to nothing at the fronds' tips.
	float body = smoothstep(0.0, 0.65, depth) * (0.72 + 0.28 * fbm(p * 30.0));
	float spark = step(0.982, hash21(floor(p * 240.0))) * smoothstep(0.3, 0.8, depth);
	float k = body;
	float white = k * (1.0 - melt);
	float film = body * melt;
	// The scene behind, bent and softened by the ice (or the water it melts to).
	vec2 bend = (vec2(fronds, rag) - 0.5) * (0.012 * white + 0.03 * film);
	vec2 o = uv + bend;
	vec2 px = vec2(0.003, 0.0048) * (white + 0.4 * film);
	vec3 scene = (textureLod(screen, o, 0.0).rgb * 2.0
		+ textureLod(screen, o + px, 0.0).rgb + textureLod(screen, o - px, 0.0).rgb
		+ textureLod(screen, o + vec2(px.x, -px.y), 0.0).rgb + textureLod(screen, o + vec2(-px.x, px.y), 0.0).rgb) / 6.0;
	vec3 ice = vec3(0.90, 0.95, 1.0);
	vec3 col = mix(scene, ice, clamp(0.75 * white, 0.0, 1.0));
	col += vec3(1.0) * 0.35 * spark * white;
	col = mix(col, col * 0.94 + vec3(0.04, 0.05, 0.06), film * 0.5);
	COLOR = vec4(col, clamp(max(white * 1.1, film * 0.7), 0.0, 0.95));
}
