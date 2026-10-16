// A rope bridge alive (scripts/rope_bridge.gd): the static faceted mesh
// (scripts/footbridge.gd `build_mesh`) moved, vertex by vertex, by how far
// its ropes stand off their sag pose (scripts/rope_bridge_sim.gd `pack`).
// Each vertex finds its place along the span (t) and across it from where
// it stands in the mesh, against the ends `end_a`, `end_b` and the sag
// `bow`: at deck height it moves with the foot ropes (left and right blended
// across the deck, so a plank rolls when one side sinks), high up with the
// hand ropes, the cords between stretching. The ends never move. While the
// deck moves fast its planks rattle a little each on its own beat.
//
// The surface (docs/scenic/rope-bridge-grit.md): drawn per pixel from the
// mesh's own tags (scripts/footbridge.gd `_box`: UV the face's metres along
// its long and short side, CUSTOM0 the part, a per-box random, its half
// sizes), no textures. Planks grey and split, dark wet grain, nail heads,
// dirt packed in the joins, moss and lichen on the tops; ropes sun-bleached
// hemp, twisted strands, frayed, grimed and mossy; posts and sills dark
// weathered timber. Lit as the ruins' stone is (shaders/folk_surface.gdshaderinc:
// the sky's hemisphere as emission, the look pass's bounce and fill).
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;

global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
global uniform vec3 zs_cloud_sun;
global uniform vec3 zs_key_direction;
#include "res://shaders/look_fill.gdshaderinc"

const int SAMPLES = 33;

uniform vec3 end_a = vec3(0.0);
uniform vec3 end_b = vec3(1.0, 0.0, 0.0);
uniform float bow = 0.0;
uniform float width = 0.74;
uniform int nodes = 10;
uniform float planks = 30.0;
uniform float rattle = 0.0;
uniform float hand_rope = 0.8;
uniform vec4 deck[SAMPLES];
uniform vec4 hand[SAMPLES];

// How much the weathering shows (0 the bare vertex colours), the moss, and
// the sky fill the bridge takes in shade.
uniform float grit : hint_range(0.0, 2.0) = 1.0;
uniform float moss : hint_range(0.0, 2.0) = 0.8;
uniform float fill = 1.25;

varying vec4 part;
varying vec3 at;

void vertex() {
	vec2 flat_way = end_b.xz - end_a.xz;
	float span = max(length(flat_way), 0.01);
	vec2 way = flat_way / span;
	vec2 across = vec2(-way.y, way.x);
	vec2 rel = VERTEX.xz - end_a.xz;
	float t = clamp(dot(rel, way) / span, 0.0, 1.0);
	float side = dot(rel, across);
	float s = sin(3.14159265 * t);
	float rest = mix(end_a.y, end_b.y, t) + bow * s * s;
	float h = VERTEX.y - rest;
	float at_node = t * float(nodes);
	int i = min(int(floor(at_node)), nodes - 1);
	float f = at_node - float(i);
	vec4 d = mix(deck[i], deck[i + 1], f);
	vec4 r = mix(hand[i], hand[i + 1], f);
	float right = clamp(0.5 + side / width, 0.0, 1.0);
	vec2 low = vec2(mix(d.x, d.y, right), d.z);
	vec2 high = side < 0.0 ? vec2(r.x, r.z) : vec2(r.y, r.w);
	vec2 move = mix(low, high, smoothstep(hand_rope * 0.375, hand_rope * 0.81, h));
	// The planks' rattle, each its own beat, only at deck height.
	float plank = floor(t * planks);
	float beat = fract(sin(plank * 12.9898 + 1.7) * 43758.5453);
	float on_deck = 1.0 - smoothstep(0.03, 0.08, abs(h + 0.02));
	move.x += rattle * on_deck * sin(TIME * (26.0 + beat * 9.0) + beat * 6.2832);
	part = CUSTOM0;
	at = VERTEX;
	VERTEX += vec3(across.x * move.y, move.x, across.y * move.y);
}

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	return n2(p) * 0.55 + n2(p * 2.03 + 7.1) * 0.3 + n2(p * 4.1 + 3.3) * 0.15;
}

// 1 while a detail whose cells are `q` a unit is wider than a pixel, fading
// out once it would shimmer.
float seen(vec2 q) {
	return 1.0 - smoothstep(0.3, 0.9, length(fwidth(q)));
}

void fragment() {
	float kind = floor(part.x + 0.5);
	float tag = part.y;
	float sh = max(part.z, 0.001);
	float lh = max(part.w, sh);
	// The face's own metres, from the box's middle.
	vec2 q = UV - vec2(tag * 41.0, tag * 67.0);
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float top = smoothstep(0.35, 0.85, wn.y);
	vec3 vc = COLOR.rgb;
	vec3 base = vc;
	float rough = 0.92;
	float g = grit;
	float mo = 0.0;
	if (kind > 0.5 && kind < 1.5) {
		// --- Planks: grey, split, dark in the grain.
		vec2 pc = vec2(q.x / lh, q.y / sh);
		float own = fract(tag * 7.3);
		vec3 silver = mix(vec3(0.24, 0.225, 0.2), vec3(0.38, 0.355, 0.315), own);
		base = mix(vc * 0.5, silver, 0.9);
		// Grain: long streaks along the plank, a few dark and wet.
		vec2 gp = vec2(q.x * 2.2 + tag * 13.0, q.y * 46.0 + tag * 31.0);
		float grain = fbm(gp);
		float fine = n2(vec2(q.x * 5.0, q.y * 150.0) + tag * 9.0) * seen(vec2(q.y * 150.0, 0.0));
		float ring = 0.5 + 0.5 * sin(q.y * 70.0 + fbm(gp * 0.3) * 9.0 + tag * 20.0);
		base *= 0.62 + grain * 0.7 - fine * 0.1;
		base = mix(base, vec3(0.2, 0.17, 0.13), smoothstep(0.5, 0.85, ring * grain + (1.0 - grain) * 0.35) * 0.5 * g);
		// Splits: thin dark lines along the plank, broken.
		float sp = abs(fract(q.y * 4.3 + tag * 5.0 + n2(vec2(q.x * 3.0, tag * 9.0)) * 0.35) - 0.5);
		float run = smoothstep(0.55, 0.75, n2(vec2(q.x * 4.5 + tag * 17.0, floor(q.y * 4.3 + tag * 5.0) * 3.7)));
		float split = (1.0 - smoothstep(0.0, 0.028, sp)) * run;
		base = mix(base, vec3(0.05, 0.04, 0.03), split * 0.9 * g);
		// Dirt packed in the joins: the plank's long edges and ends.
		float edge = max(smoothstep(0.55, 1.0, abs(pc.y)), smoothstep(0.88, 1.0, abs(pc.x)));
		float dirt = edge * (0.55 + 0.45 * n2(q * 38.0 + tag * 5.0));
		base = mix(base, vec3(0.17, 0.13, 0.095), clamp(dirt, 0.0, 1.0) * 0.8 * g * (0.5 + 0.5 * top));
		// Nail heads near the ends of the top.
		float nail = (1.0 - smoothstep(0.012, 0.022, length(vec2(abs(q.x) - (lh - 0.075), abs(q.y) - sh * 0.35)))) * top;
		float rust = n2(q * 60.0 + tag * 3.0);
		base = mix(base, mix(vec3(0.1, 0.08, 0.07), vec3(0.34, 0.2, 0.12), rust), nail * 0.9);
		// Wear toward the middle where feet fall: paler.
		float wear = (1.0 - smoothstep(0.0, 0.55, abs(pc.x))) * top;
		base = mix(base, base * 1.2 + 0.015, wear * 0.35 * g);
		// Moss and lichen gather in the joins and at the plank ends.
		mo = smoothstep(0.42, 0.78, fbm(q * 12.0 + tag * 21.0) + edge * 0.35 - 0.05) * (0.5 + 0.5 * top);
		rough = 0.88;
	} else if (kind > 1.5 && kind < 3.5) {
		// --- Hemp rope and cords: twisted strands, frayed.
		bool cord = kind > 2.5;
		float around = q.y / sh;
		float twist = q.x * (cord ? 55.0 : 46.0) + around * 2.4 + tag * 30.0;
		float strand = 0.5 + 0.5 * sin(twist);
		vec3 hemp = mix(vec3(0.33, 0.28, 0.2), vec3(0.58, 0.52, 0.4), fract(tag * 5.7) * 0.5 + 0.15);
		base = mix(vc * 0.7, hemp, 0.85);
		// Between strands it is dark and grimy; the strands are sun-bleached.
		base = mix(base * (cord ? 0.55 : 0.4), base * 1.1, smoothstep(0.1, 0.9, strand));
		// Fibres: a fuzz of pale fibres and a few frayed ends.
		float fib = n2(vec2(q.x * 120.0 + tag * 7.0, around * 6.0 + strand * 5.0)) * seen(vec2(q.x * 120.0, 0.0));
		base = mix(base, vec3(0.8, 0.74, 0.6), smoothstep(0.7, 0.95, fib) * 0.3 * g);
		// Grime and wet darkening in long stains; the cords are darker still.
		float stain = fbm(vec2(q.x * 2.4 + tag * 11.0, around * 0.8));
		base = mix(base, base * vec3(0.5, 0.46, 0.4), smoothstep(0.35, 0.7, stain) * 0.75 * g);
		base *= cord ? 0.95 : 1.0;
		// A binding now and then: darker.
		float knot = smoothstep(0.82, 0.9, n2(vec2(q.x * 1.3 + tag * 17.0, 4.0)));
		base = mix(base, base * 0.55, knot * 0.6 * step(0.5, fract(tag * 3.1)));
		mo = smoothstep(0.66, 0.9, fbm(vec2(q.x * 3.0 + tag * 5.0, around * 1.5 + 4.0))) * (cord ? 0.2 : 0.55);
		rough = 1.0;
	} else {
		// --- Posts and sills: dark timber, split, lichened.
		float own = fract(tag * 3.7);
		vec3 dark = mix(vec3(0.17, 0.145, 0.115), vec3(0.3, 0.265, 0.22), own);
		base = mix(vc * 0.6, dark, 0.8);
		vec2 gp = vec2(q.y * 18.0 + tag * 11.0, q.x * 3.0 + tag * 5.0);
		float grain = fbm(gp);
		base *= 0.7 + grain * 0.6;
		float ring = 0.5 + 0.5 * sin(q.y * 140.0 + fbm(gp * 0.4) * 8.0);
		base = mix(base, vec3(0.07, 0.06, 0.045), smoothstep(0.65, 0.95, ring * grain) * 0.35 * g);
		float sp = abs(fract(q.y * 9.0 + tag * 3.0 + n2(vec2(q.x * 2.2, tag * 7.0)) * 0.3) - 0.5);
		float run = smoothstep(0.58, 0.78, n2(vec2(q.x * 3.2 + tag * 17.0, floor(q.y * 9.0 + tag * 3.0) * 3.1)));
		base = mix(base, vec3(0.05, 0.04, 0.03), (1.0 - smoothstep(0.0, 0.03, sp)) * run * 0.8 * g);
		// Lichen: pale grey-green rosettes; moss in patches.
		float lich = smoothstep(0.6, 0.78, n2(q * 16.0 + tag * 30.0)) * smoothstep(0.35, 0.7, fbm(q * 5.0 + 9.0));
		base = mix(base, vec3(0.5, 0.52, 0.4), lich * 0.5 * g);
		mo = smoothstep(0.55, 0.85, fbm(q * 9.0 + tag * 12.0)) * 0.7;
		rough = 0.95;
	}
	// Moss: soft olive.
	vec3 moss_col = mix(vec3(0.12, 0.17, 0.07), vec3(0.22, 0.27, 0.1), n2(q * 60.0 + tag * 8.0));
	float m = clamp(mo * moss, 0.0, 1.0);
	base = mix(base, moss_col, m * 0.7);
	rough = mix(rough, 1.0, m);
	// Broad washes so no two stretches match, and dust settled on the tops.
	float wash = fbm(at.xz * 0.9 + at.y * 0.6);
	base *= 1.0 + (wash - 0.5) * 0.3 * g;
	base = mix(base, vec3(0.62, 0.57, 0.48), top * smoothstep(0.55, 0.9, fbm(at.xz * 2.6 + 3.0)) * 0.14 * g);
	base = mix(vc, base, clamp(g, 0.0, 1.0));
	ALBEDO = base;
	ROUGHNESS = rough;
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, wn.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge_light = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 rim_sky = zs_hemi_sky * zs_hemi_energy;
	EMISSION = base * hemi * fill + mix(base, vec3(0.5), 0.4) * rim_sky * edge_light * 0.35;
	float sunward = clamp(dot(wn, zs_key_direction), 0.0, 1.0);
	EMISSION += base * (zs_look_bounce_light(wn) + zs_look_fill_light(1.0 - 0.75 * sunward));
}
