shader_type spatial;
// The guacharo's plumage (scripts/enemies/guacharo_look.gd): a giant oilbird's
// worn rufous feathers, real
// stuff and not a toy: each feather a quad whose vane, rachis, barbs,
// barring, white oilbird spots, dusky tip, sun-faded fringe and ragged,
// split edges are drawn here (alpha scissor), so the outer primaries read as
// fingers against the light. `is_body` > 0.5 paints the body's ellipsoids
// instead, from their rest pose (`rest`), so the pattern rides the body.
// Fine layers fade by pixel footprint (fwidth) so they never shimmer.
render_mode cull_disabled, depth_draw_opaque, shadows_disabled;

uniform vec3 chestnut : source_color = vec3(0.30, 0.165, 0.09);
uniform vec3 dusk : source_color = vec3(0.085, 0.06, 0.05);
uniform vec3 pale : source_color = vec3(0.80, 0.72, 0.60);
uniform vec3 under_tone : source_color = vec3(0.42, 0.30, 0.21);
uniform float is_body = 0.0;
// Feathers: how far the fan is open (1 open, 0 folded); set per instance.
instance uniform float spread = 1.0;

varying vec3 rest;
varying vec4 cust;
varying vec4 tint;
// The feather's own up (its rest normal, in view space): which face we see.
varying vec3 top_n;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

void vertex() {
	cust = CUSTOM0;
	tint = COLOR;
	if (is_body < 0.5) {
		// CUSTOM0 = (pivot x, pivot z, fan angle when folded, seed): the
		// feather turns about its base as the fan closes.
		float a = (1.0 - spread) * CUSTOM0.z;
		float c = cos(a);
		float s = sin(a);
		vec2 d = VERTEX.xz - CUSTOM0.xy;
		VERTEX.xz = CUSTOM0.xy + vec2(c * d.x - s * d.y, s * d.x + c * d.y);
		NORMAL.xz = vec2(c * NORMAL.x - s * NORMAL.z, s * NORMAL.x + c * NORMAL.z);
	}
	rest = VERTEX;
	top_n = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	if (is_body > 0.5) {
		// The body: chestnut, the back darker, the belly a paler cinnamon,
		// overlapping feather scallops and a few white spots on the nape
		// and breast, all from the rest pose.
		vec3 p = rest;
		float back = smoothstep(-0.2, 0.35, p.y);
		vec3 col = mix(under_tone * 0.7, chestnut * 0.62, back);
		float fp = length(fwidth(p)) * 28.0;
		float fine = 1.0 - smoothstep(0.3, 1.2, fp);
		// Scallops: rows of feather ends along the body.
		vec2 q = vec2(atan(p.x, p.y) * 2.2, p.z * 9.0);
		float row = floor(q.y);
		float cell = fract(q.x + row * 0.5);
		float edge = smoothstep(0.55, 0.95, fract(q.y) + 0.35 * abs(cell - 0.5));
		col *= 1.0 - 0.38 * edge * fine;
		// Each feather tipped a shade paler, worn.
		col = mix(col, pale * 0.45, 0.12 * smoothstep(0.75, 0.95, fract(q.y)) * fine);
		// Broad washes, then grain.
		col *= 0.7 + 0.45 * vnoise3(p * 5.0);
		col *= 0.9 + 0.2 * mix(0.5, vnoise3(p * 40.0), fine);
		// White oilbird spots, each in a dark ring.
		vec3 sp = p * vec3(9.0, 9.0, 7.0);
		vec3 ci = floor(sp);
		float r = hash3(ci);
		vec3 fc = fract(sp) - 0.5 - (vec3(hash3(ci + 3.1), hash3(ci + 7.7), hash3(ci + 1.3)) - 0.5) * 0.4;
		float d = length(fc);
		float spot = step(0.78, r) * (1.0 - smoothstep(0.09, 0.15, d));
		float ring = step(0.78, r) * (1.0 - smoothstep(0.15, 0.24, d)) * (1.0 - spot);
		col = mix(col, dusk, ring * 0.5);
		col = mix(col, pale, spot * 0.75);
		ALBEDO = col;
		ROUGHNESS = 0.95;
		SPECULAR = 0.15;
		BACKLIGHT = col * 0.15;
	} else {
		// A feather: UV.x across (0.5 the rachis), UV.y base (0) to tip (1).
		float seed = cust.w;
		float x = UV.x - 0.5;
		float v = UV.y;
		float ax = abs(x);
		float aa = max(fwidth(UV.x) * 1.2, 0.002);
		float fp = length(fwidth(UV)) * 30.0;
		float fine = 1.0 - smoothstep(0.25, 1.0, fp);
		// The vane's outline: full most of the way, a rounded tip.
		float w = 0.5 * sqrt(max(1.0 - pow(v, 5.0), 0.0)) * mix(0.7, 1.0, smoothstep(0.0, 0.1, v));
		// Emarginate primaries (tint.r): the vane narrows past the notch.
		w *= mix(1.0, mix(1.0, 0.72, smoothstep(0.45, 0.62, v)), tint.r);
		// Ragged: the edge chewed, the tip frayed, a chunk worn away.
		float n = vnoise(vec2(v * 22.0 + seed * 31.0, sign(x) * 5.0 + seed * 3.0));
		w *= 0.9 + 0.1 * n;
		w *= 1.0 - 0.4 * smoothstep(0.85, 1.0, v) * vnoise(vec2(x * 30.0 + seed * 9.0, v * 6.0));
		float chunk = step(0.88, hash(vec2(floor(v * 5.0 + seed * 17.0), sign(x) + seed)));
		w *= 1.0 - chunk * 0.25 * smoothstep(0.3, 0.7, v);
		float a = 1.0 - smoothstep(w - aa, w, ax);
		// Split vanes: diagonal gaps between barbs on some rows.
		float g = fract(v * 9.0 + ax * 1.8 + seed * 5.0);
		float rowsplit = step(0.86, hash(vec2(floor(v * 9.0 + ax * 1.8 + seed * 5.0), sign(x) * 2.0 + seed)));
		a *= 1.0 - rowsplit * (1.0 - smoothstep(0.0, 0.03 + aa * 4.0, g)) * smoothstep(0.15, 0.3, ax) * smoothstep(0.3, 0.6, v);
		// The rachis: a faint shaft, faded out by distance (never a stripe).
		float rachis = (1.0 - smoothstep(0.01, 0.01 + aa, ax)) * fine * step(v, 0.92);
		ALPHA = a;
		ALPHA_SCISSOR_THRESHOLD = 0.5;
		// Colour: rufous, the tip dusky (tint.b how dark), barred faintly,
		// barbs streaked, the fringe sun-faded, each feather its own.
		vec3 col = chestnut * (0.85 + 0.3 * hash(vec2(seed, 1.7)));
		col = mix(col, dusk, smoothstep(0.35, 1.0, v) * tint.b);
		col *= 1.0 - 0.18 * smoothstep(0.3, 0.7, sin(v * 34.0 + seed * 6.0) * 0.5 + 0.5) * fine;
		float barb = sin((ax * 1.0 - v * 0.55) * 260.0 + seed * 40.0) * 0.5 + 0.5;
		col *= 1.0 - 0.12 * barb * fine;
		col = mix(col, pale * 0.55, 0.18 * smoothstep(w * 0.7, w, ax));
		col = mix(col, chestnut * 1.2, 0.2 * smoothstep(0.25, 0.0, v));
		col *= 0.85 + 0.3 * vnoise(vec2(x * 4.0, v * 3.0) + seed * 11.0);
		// White spots on the outer vane (tint.g), in dark rings.
		float sv = fract(v * 3.2 + seed);
		vec2 sc = vec2((ax - 0.3) * 1.6, (sv - 0.5) * 0.5);
		float sd = length(sc);
		float on = tint.g * step(0.0, x) * step(v, 0.8);
		col = mix(col, dusk, on * (1.0 - smoothstep(0.08, 0.13, sd)) * 0.6);
		col = mix(col, pale, on * (1.0 - smoothstep(0.045, 0.075, sd)) * 0.85);
		col = mix(col, mix(chestnut, pale, 0.4), rachis * 0.45);
		// The underside a little paler, greyer (seen from below).
		if (dot(top_n, -VERTEX) < 0.0) col = mix(col, under_tone * 0.8, 0.35);
		ALBEDO = col;
		ROUGHNESS = 0.9;
		SPECULAR = 0.22;
		// Thin vanes let the light through at the edges of the silhouette.
		BACKLIGHT = col * 0.35;
	}
}
