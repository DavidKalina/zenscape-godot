shader_type spatial;
// The rune token's stone (scripts/rune_token.gd): a deep red plummet,
// oxblood drifting toward plum-black, its facet edges lit, a carved rune on
// each long lower facet glowing in `tint` (they light in turn round the
// stone), an ember at its heart beating slow and doubled like a pulse, a
// shimmer sinking down to the point now and then, and a sheen that turns
// rose at grazing angles. `glow` and `inner` are the glyph token's, set by
// scripts/glyph_pickup.gd by day, by night and in the pickup.
render_mode cull_back;

uniform vec3 tint : source_color = vec3(0.78, 0.08, 0.16);
uniform vec3 glow_tint : source_color = vec3(1.0, 0.55, 0.45);
uniform vec3 deep : source_color = vec3(0.5, 0.01, 0.07);
uniform vec3 deep_alt : source_color = vec3(0.28, 0.0, 0.12);
uniform vec3 sheen : source_color = vec3(1.0, 0.4, 0.5);
uniform vec3 ember : source_color = vec3(1.0, 0.06, 0.1);
uniform float glow = 0.35;
uniform float inner = 0.0;
// The token's size (m), so the runes sit on the facets.
uniform float size = 1.0;
// The stone's shape, as shares of the size (scripts/rune_token.gd).
uniform float sides = 6.0;
uniform float girdle = 0.24;
uniform float cap = 0.09;
uniform float top = 0.2;
uniform float bottom = 0.62;
// The pulse's period (s).
uniform float beat_period = 1.6;

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
	} else if (which == 3) { // tiwaz
		d = min(d, seg(p, vec2(0.0, -1.0), vec2(0.0, 1.0)));
		d = min(d, seg(p, vec2(0.0, 1.0), vec2(-0.6, 0.35)));
		d = min(d, seg(p, vec2(0.0, 1.0), vec2(0.6, 0.35)));
	} else if (which == 4) { // kenaz
		d = min(d, seg(p, vec2(0.45, 0.9), vec2(-0.45, 0.0)));
		d = min(d, seg(p, vec2(-0.45, 0.0), vec2(0.45, -0.9)));
	} else { // othala
		d = min(d, seg(p, vec2(0.0, 1.0), vec2(0.55, 0.4)));
		d = min(d, seg(p, vec2(0.55, 0.4), vec2(-0.55, -1.0)));
		d = min(d, seg(p, vec2(0.0, 1.0), vec2(-0.55, 0.4)));
		d = min(d, seg(p, vec2(-0.55, 0.4), vec2(0.55, -1.0)));
	}
	return d;
}

// A heartbeat: two soft knocks, the second lighter, then a rest.
float pulse(float time) {
	float t = fract(time / beat_period);
	return exp(-pow(t * 12.0, 2.0)) + exp(-pow((1.0 - t) * 12.0, 2.0))
		+ 0.6 * exp(-pow((t - 0.2) * 12.0, 2.0));
}

void stone(vec3 view, vec3 normal, float time, out vec3 albedo, out vec3 emission) {
	vec3 n = normalize(obj_n);
	float v = obj_pos.y;
	float facing = clamp(dot(normal, view), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.5);
	float beat = pulse(time);
	// The ember: light from within, strongest a little under the girdle,
	// seen most through the facets that face you.
	float heart = exp(-pow((v + 0.1) / 0.28, 2.0)) * (0.35 + 0.65 * facing);

	if (n.y > 0.9) {
		// The flat cap: a dark window onto the ember.
		albedo = deep;
		emission = deep * (0.3 + glow) + ember * heart * (0.25 + 0.5 * beat) * (0.4 + glow)
			+ tint * inner;
		return;
	}

	vec3 up = normalize(vec3(0.0, 1.0, 0.0) - n * n.y);
	vec3 side = normalize(cross(n, up));
	float u = dot(obj_pos, side);
	bool upper = v > 0.0;
	// Which facet round the stone.
	float a = atan(n.z, n.x);
	int facet = int(mod(floor((a + PI) / (TAU / sides)), sides));
	float fid = float(facet);

	// The facet's half-width at this height, and how far in from its edges.
	float hs = sin(PI / sides);
	float hw = upper ? mix(girdle, cap, v / top) * hs : girdle * hs * (1.0 + v / bottom);
	float edge = upper ? min(hw - abs(u), min(v, top - v) * 0.8) : min(hw - abs(u), -v * 0.8);
	float edge_line = 1.0 - smoothstep(0.0, 0.014, edge);

	// The body: deep, drifting oxblood to plum by height and time.
	float drift = 0.5 + 0.5 * sin(time * 0.3 + v * 4.0 + fid * 0.9);
	vec3 body = mix(deep, deep_alt, drift);
	float core = smoothstep(0.0, 0.1, edge) * facing;

	// The rune: on a long lower facet, lit in turn round the stone.
	float r = 0.0;
	if (!upper) {
		vec2 q = vec2(u, v + bottom * 0.33) / vec2(0.05, 0.085);
		float d = rune(q, int(mod(fid, 6.0))) * 0.05;
		float stroke = 1.0 - smoothstep(0.004, 0.01, d);
		float halo = exp(-d * 70.0) * 0.35;
		float turn = 0.4 + 0.6 * pow(0.5 + 0.5 * sin(time * 0.9 - fid * TAU / sides), 3.0);
		r = (stroke + halo) * turn;
	}
	// A shimmer sinking down the stone to its point every few seconds.
	float span = top + bottom;
	float h = top - mod(time * 0.28, 2.0) * span;
	float shimmer = exp(-pow((v - h) / 0.045, 2.0));

	albedo = body * 0.45;
	vec3 e = body * (0.35 + 0.7 * core) * (0.5 + glow);
	e += ember * heart * (0.08 + 0.42 * beat) * (0.3 + 0.7 * glow);
	e += mix(tint, sheen, rim * rim) * rim * (0.1 + 0.2 * glow);
	e += glow_tint * edge_line * (0.15 + 0.3 * glow);
	e += tint * shimmer * (0.25 + 0.35 * glow);
	e += mix(tint, vec3(1.0, 0.75, 0.75), 0.4) * r * (0.9 + 1.5 * glow) * (0.8 + 0.4 * beat);
	e += tint * inner * (0.3 + 1.2 * core);
	emission = e;
}

void fragment() {
	vec3 albedo;
	vec3 emission;
	stone(VIEW, NORMAL, TIME, albedo, emission);
	ALBEDO = albedo;
	EMISSION = emission;
	ROUGHNESS = 0.3;
	METALLIC = 0.0;
	SPECULAR = 0.22;
}
