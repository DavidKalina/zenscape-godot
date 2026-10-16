shader_type spatial;
// The rune token (scripts/rune_token.gd): a deep gem, teal drifting toward
// indigo, its facet edges lit, a carved rune on each upper facet glowing in
// `tint` (they light in turn round the stone), a soft shimmer rising through
// it now and then, and a sheen that turns violet at grazing angles. The ring
// (band 1) carries runic ticks flowing round it and a bright comet chasing
// them. `glow` and `inner` are the glyph token's, set by
// scripts/glyph_pickup.gd by day, by night and in the pickup.
render_mode cull_back;

uniform vec3 tint : source_color = vec3(0.56, 0.83, 0.9);
uniform vec3 glow_tint : source_color = vec3(0.8, 0.95, 1.0);
uniform vec3 deep : source_color = vec3(0.02, 0.22, 0.25);
uniform vec3 deep_alt : source_color = vec3(0.05, 0.1, 0.32);
uniform vec3 sheen : source_color = vec3(0.55, 0.45, 0.95);
uniform float glow = 0.35;
uniform float inner = 0.0;
// 0 the diamond, 1 the ring.
uniform float band = 0.0;
// The token's size (m), so the runes sit on the facets.
uniform float size = 1.0;
// The diamond's shape, as shares of the size (scripts/rune_token.gd).
uniform float girdle = 0.3;
uniform float top = 0.62;
uniform float bottom = 0.42;

varying vec3 obj_pos;
varying vec3 obj_n;

void vertex() {
	obj_pos = VERTEX / size;
	obj_n = NORMAL;
}

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// A rune in a box from -1 to 1: its distance to the nearest stroke.
float rune(vec2 p, int which) {
	float d = 1e3;
	if (which == 0) { // algiz
		d = min(d, seg(p, vec2(0.0, -1.0), vec2(0.0, 1.0)));
		d = min(d, seg(p, vec2(0.0, 0.15), vec2(-0.7, 0.95)));
		d = min(d, seg(p, vec2(0.0, 0.15), vec2(0.7, 0.95)));
	} else if (which == 1) { // fehu
		d = min(d, seg(p, vec2(-0.35, -1.0), vec2(-0.35, 1.0)));
		d = min(d, seg(p, vec2(-0.35, 0.35), vec2(0.55, 0.95)));
		d = min(d, seg(p, vec2(-0.35, -0.2), vec2(0.55, 0.4)));
	} else if (which == 2) { // dagaz
		d = min(d, seg(p, vec2(-0.6, -0.8), vec2(-0.6, 0.8)));
		d = min(d, seg(p, vec2(0.6, -0.8), vec2(0.6, 0.8)));
		d = min(d, seg(p, vec2(-0.6, 0.8), vec2(0.6, -0.8)));
		d = min(d, seg(p, vec2(-0.6, -0.8), vec2(0.6, 0.8)));
	} else { // tiwaz
		d = min(d, seg(p, vec2(0.0, -1.0), vec2(0.0, 1.0)));
		d = min(d, seg(p, vec2(0.0, 1.0), vec2(-0.6, 0.35)));
		d = min(d, seg(p, vec2(0.0, 1.0), vec2(0.6, 0.35)));
	}
	return d;
}

void diamond(vec3 view, vec3 normal, float time, out vec3 albedo, out vec3 emission) {
	vec3 n = normalize(obj_n);
	vec3 up = normalize(vec3(0.0, 1.0, 0.0) - n * n.y);
	vec3 side = normalize(cross(n, up));
	float u = dot(obj_pos, side);
	float v = obj_pos.y;
	bool upper = v > 0.0;
	// Which facet (0..3) round the stone.
	float a = atan(n.z, n.x);
	int facet = int(mod(floor((a + PI) / (PI * 0.5)), 4.0));
	float fid = float(facet);

	// The facet's half-width at this height, and how far in from its edges.
	float half_edge = girdle * 0.7071;
	float hw = upper ? half_edge * (1.0 - v / top) : half_edge * (1.0 + v / bottom);
	float edge = min(hw - abs(u), abs(v) * 0.8);
	float edge_line = 1.0 - smoothstep(0.0, 0.018, edge);

	// The body: deep, drifting teal to indigo by height and time.
	float drift = 0.5 + 0.5 * sin(time * 0.35 + v * 5.0 + fid * 0.8);
	vec3 body = mix(deep, deep_alt, drift);
	float facing = clamp(dot(normal, view), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.5);
	// Light from within, strongest through the facet's middle.
	float core = smoothstep(0.0, 0.12, edge) * facing;

	// The rune: on an upper facet, lit in turn round the stone.
	float r = 0.0;
	if (upper) {
		vec2 q = vec2(u, v - top * 0.36) / vec2(0.075, 0.115);
		float d = rune(q, facet) * 0.075;
		float stroke = 1.0 - smoothstep(0.006, 0.014, d);
		float halo = exp(-d * 55.0) * 0.35;
		float pulse = 0.45 + 0.55 * pow(0.5 + 0.5 * sin(time * 1.4 - fid * PI * 0.5), 2.0);
		r = (stroke + halo) * pulse;
	}
	// A shimmer rising through the stone every few seconds.
	float span = top + bottom;
	float h = mod(time * 0.32, 1.9) * span - bottom;
	float shimmer = exp(-pow((v - h) / 0.05, 2.0));

	albedo = body;
	vec3 e = body * (0.8 + 1.6 * core) * (0.5 + glow);
	e += mix(tint, sheen, rim) * rim * (0.12 + 0.25 * glow);
	e += glow_tint * edge_line * (0.3 + 0.45 * glow);
	e += tint * shimmer * (0.35 + 0.5 * glow);
	e += mix(tint, vec3(1.0), 0.35) * r * (1.0 + 1.6 * glow);
	e += tint * inner * (0.3 + 1.2 * core);
	emission = e;
}

void ring(vec2 uv, float time, out vec3 albedo, out vec3 emission) {
	// Runic ticks flowing round the ring, and a comet chasing them.
	float along = uv.x;
	float ticks = fract(along * 14.0 + time * 0.5);
	float tick = smoothstep(0.0, 0.03, ticks) * (1.0 - smoothstep(0.1, 0.14, ticks));
	float c = fract(along - time * 0.3);
	float comet = exp(-c * 9.0) + exp(-(1.0 - c) * 60.0);
	albedo = deep * 0.6;
	vec3 e = tint * (0.08 + 0.18 * glow);
	e += mix(tint, vec3(1.0), 0.3) * tick * (0.3 + 0.5 * glow);
	e += mix(glow_tint, vec3(1.0), 0.5) * comet * (0.8 + 1.4 * glow);
	e += tint * inner * 0.8;
	emission = e;
}

void fragment() {
	vec3 albedo;
	vec3 emission;
	if (band > 0.5) {
		ring(UV, TIME, albedo, emission);
		ROUGHNESS = 0.2;
		METALLIC = 0.3;
		SPECULAR = 0.7;
	} else {
		diamond(VIEW, NORMAL, TIME, albedo, emission);
		ROUGHNESS = 0.18;
		METALLIC = 0.1;
		SPECULAR = 0.45;
	}
	ALBEDO = albedo;
	EMISSION = emission;
}
