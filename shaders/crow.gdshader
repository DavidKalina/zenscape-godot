shader_type spatial;
// A crow (scripts/crow_body.gd): matte charcoal-black plumage with a faint
// oily blue-green-violet sheen where the light glances off it, worn brown
// tips on the old flight feathers, dust in the grain. Feathers (is_body 0)
// are quads whose vane, rachis, barbs and ragged split edges are drawn here
// (alpha scissor), the outer primaries notched into fingers. The body
// (is_body 1) paints its merged ellipsoids by COLOR: plumage (black) with
// rows of feather scallops, the eyes (red), the beak (green), the scaly
// legs (blue). Fine layers fade by pixel footprint so they never shimmer.
render_mode cull_disabled, depth_draw_opaque;
// Lit by light() below: matte, the sheen a tinted lobe that never glares
// white at a glance (no metallic Fresnel).

uniform vec3 ink : source_color = vec3(0.075, 0.072, 0.078);
uniform vec3 char_tone : source_color = vec3(0.12, 0.115, 0.115);
uniform vec3 worn : source_color = vec3(0.2, 0.165, 0.13);
uniform vec3 dust : source_color = vec3(0.52, 0.48, 0.42);
uniform vec3 sheen_a : source_color = vec3(0.27, 0.30, 0.55);
uniform vec3 sheen_b : source_color = vec3(0.20, 0.42, 0.40);
uniform vec3 horn : source_color = vec3(0.06, 0.058, 0.06);
uniform float sheen = 0.4;
uniform float is_body = 0.0;
// Feathers: how far the fan is open (1 open, 0 folded); set per instance.
instance uniform float spread = 1.0;

varying vec3 rest;
varying vec3 rest_n;
varying vec4 cust;
varying vec4 tint;
varying vec3 top_n;
// The sheen's colour and strength, for light().
varying vec3 v_sheen;

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

// The oily sheen: a thin-film hue that slides from violet-blue to green as
// the surface turns from the eye.
vec3 film(float glance, float shift) {
	float t = clamp(glance * 1.4 + shift, 0.0, 1.0);
	return mix(sheen_a, sheen_b, smoothstep(0.15, 0.85, t));
}

void vertex() {
	cust = CUSTOM0;
	tint = COLOR;
	if (is_body < 0.5) {
		// CUSTOM0 = (pivot x, pivot z, fan angle when folded, seed).
		float a = (1.0 - spread) * CUSTOM0.z;
		float c = cos(a);
		float s = sin(a);
		vec2 d = VERTEX.xz - CUSTOM0.xy;
		VERTEX.xz = CUSTOM0.xy + vec2(c * d.x - s * d.y, s * d.x + c * d.y);
		NORMAL.xz = vec2(c * NORMAL.x - s * NORMAL.z, s * NORMAL.x + c * NORMAL.z);
	}
	rest = VERTEX;
	rest_n = NORMAL;
	top_n = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	float glance = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	if (is_body > 0.5) {
		vec3 p = rest;
		float fp = length(fwidth(p)) * 140.0;
		float fine = 1.0 - smoothstep(0.3, 1.2, fp);
		if (tint.r > 0.5) {
			// The eye: dark brown, wet.
			ALBEDO = vec3(0.025, 0.018, 0.014);
			ROUGHNESS = 0.12;
			SPECULAR = 0.7;
			v_sheen = vec3(0.3);
		} else if (tint.g > 0.5) {
			// The beak: dark horn, grained along its length, the edges and
			// tip worn paler and scratched.
			vec3 col = horn * (0.85 + 0.3 * vnoise(vec2(p.x * 300.0, p.z * 60.0)));
			col *= 1.0 - 0.15 * fine * smoothstep(0.6, 0.9, vnoise(vec2(p.x * 900.0 + p.y * 400.0, p.z * 140.0)));
			col = mix(col, char_tone * 1.25, 0.35 * smoothstep(-0.075, -0.1, p.z));
			ALBEDO = col;
			ROUGHNESS = 0.5;
			SPECULAR = 0.3;
			v_sheen = vec3(0.12) * (1.0 - smoothstep(-0.075, -0.1, p.z));
		} else if (tint.b > 0.5) {
			// The legs: scaled, dull black-grey, a little dusty.
			float ring = smoothstep(0.55, 0.95, fract(p.y * 9.0 + 0.3 * sin(atan(p.x, p.z) * 2.0)));
			vec3 col = horn * (1.0 - 0.3 * ring * fine);
			col = mix(col, dust * 0.4, 0.15 * vnoise(p.xz * 600.0 + p.y * 7.0));
			ALBEDO = col;
			ROUGHNESS = 0.75;
			SPECULAR = 0.15;
			v_sheen = vec3(0.0);
		} else {
			// Plumage: rows of overlapping feather ends, each edge a shade
			// greyer (worn), broad washes and grain, dust settled low, the
			// sheen strongest on the back, nape and crown.
			vec2 q = vec2(atan(p.x, p.y + 0.02) * 6.0 + vnoise3(p * 200.0) * 0.6, p.z * 110.0 + p.y * 40.0 + vnoise3(p * 90.0) * 1.5);
			float row = floor(q.y);
			float cell = fract(q.x + row * 0.5 + hash(vec2(row, 3.0)) * 0.3);
			float edge = smoothstep(0.6, 0.95, fract(q.y) + 0.3 * abs(cell - 0.5));
			vec3 col = mix(ink, char_tone, 0.35 * vnoise3(p * 60.0));
			col = mix(col, char_tone * 1.25, 0.3 * edge * fine * (0.4 + vnoise3(p * 150.0)));
			col *= 0.9 + 0.2 * mix(0.5, vnoise3(p * 420.0), fine);
			float low = smoothstep(0.0, -1.0, rest_n.y);
			col = mix(col, dust * 0.55, 0.12 * low * vnoise3(p * 120.0));
			// Feather grain: the normal jittered row by row, so the light
			// breaks into small glints instead of one smooth highlight.
			vec3 jit = vec3(vnoise3(p * 260.0), vnoise3(p * 260.0 + 7.1), vnoise3(p * 260.0 + 13.7)) - 0.5;
			NORMAL = normalize(NORMAL + (jit * 0.22 + (edge - 0.5) * 0.15 * NORMAL) * fine);
			float m = sheen * (0.25 + 0.75 * smoothstep(-0.2, 0.7, rest_n.y)) * (1.0 - 0.6 * edge * fine);
			m *= 0.4 + 0.8 * vnoise3(p * 140.0);
			vec3 film_c = film(glance, 0.3 * vnoise3(p * 40.0) - 0.15);
			ALBEDO = mix(col, film_c, m * 0.08);
			v_sheen = film_c * m;
			ROUGHNESS = 0.85;
			SPECULAR = 0.12;
		}
	} else {
		// A feather: UV.x across (0.5 the rachis), UV.y base (0) to tip (1).
		// A thin vane: lit on whichever face is seen.
		if (dot(NORMAL, VIEW) < 0.0) NORMAL = -NORMAL;
		float seed = cust.w;
		float x = UV.x - 0.5;
		float v = UV.y;
		float ax = abs(x);
		float aa = max(fwidth(UV.x) * 1.2, 0.002);
		float fp = length(fwidth(UV)) * 30.0;
		float fine = 1.0 - smoothstep(0.25, 1.0, fp);
		// The vane: full most of the way, a rounded, slightly squared tip.
		float w = 0.5 * sqrt(max(1.0 - pow(v, 6.0), 0.0)) * mix(0.7, 1.0, smoothstep(0.0, 0.12, v));
		// Fingers (tint.r): the vane narrows past the notch.
		w *= mix(1.0, mix(1.0, 0.62, smoothstep(0.4, 0.6, v)), tint.r);
		// Ragged: the edge chewed, the tip frayed and split, a chunk gone.
		float n = vnoise(vec2(v * 26.0 + seed * 31.0, sign(x) * 5.0 + seed * 3.0));
		w *= 0.86 + 0.14 * n;
		w *= 1.0 - 0.5 * smoothstep(0.8, 1.0, v) * vnoise(vec2(x * 34.0 + seed * 9.0, v * 7.0));
		float chunk = step(0.8, hash(vec2(floor(v * 5.0 + seed * 17.0), sign(x) + seed)));
		w *= 1.0 - chunk * 0.35 * smoothstep(0.35, 0.75, v) * tint.g;
		float a = 1.0 - smoothstep(w - aa, w, ax);
		// Split vanes: diagonal gaps between barbs.
		float g = fract(v * 8.0 + ax * 2.2 + seed * 5.0);
		float rowsplit = step(0.78, hash(vec2(floor(v * 8.0 + ax * 2.2 + seed * 5.0), sign(x) * 2.0 + seed)));
		a *= 1.0 - rowsplit * (1.0 - smoothstep(0.0, 0.04 + aa * 4.0, g)) * smoothstep(0.12, 0.3, ax) * smoothstep(0.25, 0.6, v);
		float rachis = (1.0 - smoothstep(0.012, 0.012 + aa, ax)) * fine * step(v, 0.93);
		ALPHA = a;
		ALPHA_SCISSOR_THRESHOLD = 0.5;
		// Colour: charcoal-black, each feather its own shade; the old ones
		// (tint.g) faded brown towards the tip; barbs streaked, the fringe
		// greyer; dust specks in the grain.
		vec3 col = mix(ink, char_tone, 0.25 + 0.45 * hash(vec2(seed, 1.7)));
		col = mix(col, worn, smoothstep(0.45, 1.0, v) * tint.g * (0.4 + 0.5 * hash(vec2(seed, 4.1))));
		float barb = sin((ax - v * 0.5) * 240.0 + seed * 40.0) * 0.5 + 0.5;
		col *= 1.0 - 0.14 * barb * fine;
		col = mix(col, char_tone * 1.25, 0.25 * smoothstep(w * 0.65, w, ax));
		col *= 0.85 + 0.3 * vnoise(vec2(x * 5.0, v * 4.0) + seed * 11.0);
		col = mix(col, dust * 0.7, 0.35 * fine * step(0.9, vnoise(vec2(x * 60.0, v * 90.0) + seed * 7.0)));
		col = mix(col, char_tone * 1.4, rachis * 0.35);
		bool top = dot(top_n, VIEW) > 0.0;
		float m = 0.0;
		if (top) {
			// The sheen on the upper face, most at the vane's base, broken
			// by the barbs, none on the worn tips.
			m = sheen * tint.b * (1.0 - smoothstep(0.5, 1.0, v) * tint.g) * (0.8 + 0.2 * barb);
		} else {
			// The underside: a duller, greyer black.
			col = mix(col, char_tone, 0.25);
		}
		vec3 film_c = film(glance, 0.4 * hash(vec2(seed, 9.3)) - 0.2 + v * 0.2);
		ALBEDO = mix(col, film_c, m * 0.08);
		v_sheen = film_c * m;
		ROUGHNESS = 0.85;
		SPECULAR = 0.12;
	}
}

void light() {
	float nl = dot(NORMAL, LIGHT);
	// Matte: Lambert, and thin vanes glowing a little with the light behind.
	float through = (1.0 - is_body) * 0.3 * clamp(-nl, 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * (clamp(nl, 0.0, 1.0) + through) / PI;
	// The sheen: a soft tinted lobe; a faint broad one under it (dull feathers).
	vec3 h = normalize(LIGHT + VIEW);
	float nh = max(dot(NORMAL, h), 0.0);
	float lit = clamp(nl, 0.0, 1.0) * ATTENUATION;
	SPECULAR_LIGHT += LIGHT_COLOR * lit * (v_sheen * pow(nh, 28.0) * 0.45 + vec3(0.012) * pow(nh, 6.0));
}
