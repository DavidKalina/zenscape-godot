shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// The temple kit's stone (scripts/temple_kit.gd, art/blender/temple_kit/):
// the shapes carry the masonry, the vertex colour the stone's tone, joints,
// stains and moss (temple_lib.py `paint`). This adds what a vertex can't:
// the limestone's grain and pitting up close, fading out with distance so
// far columns stay calm. Lit as the ruins' stone is (shaders/ruin_stone.
// gdshader through folk_surface.gdshaderinc): the world has no ambient, so
// the sky's hemisphere comes in as emission (`fill`), with the sunlit land's
// warm bounce on what looks across or down (`ground_bounce`), so a face out
// of the sun stays pale stone, not black. Neither leans on the look pass's
// fill (zs_look_fill): endless flight runs without it (0), the galleries
// with it; there it only adds a little more.
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
global uniform vec3 zs_cloud_sun;
global uniform vec3 zs_key_direction;
#include "res://shaders/look_fill.gdshaderinc"

uniform float fill = 3.3;
// The sunlit ground's bounce: the sun's colour (zs_cloud_sun) by its height,
// off a ground of about this albedo, on the part of the sky a face sees below
// the horizon.
uniform float ground_bounce = 0.45;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.92;
// The grain: albedo mottle (`grain`), dark pits (`pits`), and a bump on the
// normal (`bump`), all at `grain_scale` per metre; gone past `grain_far` m.
uniform float grain = 0.14;
uniform float pits = 0.22;
uniform float bump = 0.35;
uniform float grain_scale = 3.0;
uniform float grain_far = 90.0;
// A lift for every tone (the kit's colours are authored for this at 1).
uniform float brightness = 1.0;
// The weather, at every distance (the vertex colour is too coarse for it):
// rain streaks down the sides (`streaks`), lichen in patches (`lichen`:
// grey-green crusts and a few ochre spots), dirt in a broad mottle (`dirt`)
// and moss on what looks up (`moss_top`).
uniform float streaks = 0.55;
uniform vec3 streak_colour : source_color = vec3(0.40, 0.36, 0.30);
uniform float lichen = 0.5;
uniform vec3 lichen_colour : source_color = vec3(0.70, 0.71, 0.60);
uniform vec3 ochre_colour : source_color = vec3(0.72, 0.56, 0.30);
uniform float dirt = 0.22;
uniform vec3 dirt_colour : source_color = vec3(0.47, 0.42, 0.34);
uniform float moss_top = 0.2;
uniform vec3 moss_colour : source_color = vec3(0.36, 0.42, 0.20);

varying vec3 world;
// `world` less the piece's origin snapped to 64 m: the grain's noise runs on
// small numbers (a float's hash at a site 3 km out came out in blocky
// cells), the same on every piece in that 64 m square, so joints still line up.
varying vec3 grain_at;

float h3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float n3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	return n3(p) * 0.55 + n3(p * 2.3 + 3.1) * 0.3 + n3(p * 5.1 + 7.7) * 0.15;
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	grain_at = world - floor(MODEL_MATRIX[3].xyz / 64.0) * 64.0;
}

void fragment() {
	vec3 base = COLOR.rgb * brightness;
	float dist = length(world - CAMERA_POSITION_WORLD);
	float near = 1.0 - smoothstep(grain_far * 0.4, grain_far, dist);
	vec3 p = grain_at * grain_scale;
	float g = fbm(p);
	vec3 face = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float side = 1.0 - abs(face.y);
	// A broader cloudiness, kept at every distance (it is a few metres).
	float cloud = n3(grain_at * 0.35 + 2.0);
	base *= 1.0 + (cloud - 0.5) * 0.12;
	// Dirt: a broad grey-brown mottle.
	float d = smoothstep(0.4, 0.8, n3(grain_at * 0.22 + 9.0) * 0.7 + n3(grain_at * 0.9) * 0.3);
	base = mix(base, base * dirt_colour / 0.6, d * dirt);
	// Rain streaks: long runs down the sides, broken along their length.
	float run = n3(grain_at * vec3(1.3, 0.06, 1.3)) * 0.75 + n3(grain_at * vec3(3.1, 0.25, 3.1) + 4.0) * 0.25;
	float st = smoothstep(0.5, 0.78, run) * side;
	base = mix(base, base * streak_colour / 0.62, st * streaks);
	// Lichen crusts, in patches, more on the sides and tops than under.
	float lp = n3(grain_at * 0.55 + 21.0) * 0.6 + n3(grain_at * 2.4 + 3.0) * 0.4;
	float crust = smoothstep(0.62, 0.7, lp) * (0.5 + 0.5 * clamp(face.y + 0.6, 0.0, 1.0));
	base = mix(base, lichen_colour * dot(base, vec3(0.33)) / 0.55, crust * lichen);
	float spot = smoothstep(0.8, 0.86, n3(grain_at * 1.7 + 40.0)) * smoothstep(0.55, 0.65, lp);
	base = mix(base, ochre_colour * 0.8, spot * lichen * 0.7);
	// Moss on what looks up.
	float up = smoothstep(0.55, 0.9, face.y);
	float mp = smoothstep(0.45, 0.6, n3(grain_at * 0.7 + 13.0) * 0.65 + n3(grain_at * 3.0) * 0.35);
	base = mix(base, moss_colour, up * mp * moss_top);
	if (near > 0.0) {
		base *= 1.0 + (g - 0.5) * 2.0 * grain * near;
		// Pits: small dark holes in the limestone.
		float pit = smoothstep(0.84, 0.94, n3(p * 4.5 + 1.3)) * smoothstep(0.3, 0.7, n3(p * 0.4 + 6.0));
		base *= 1.0 - pit * pits * near;
		// The grain on the normal: its gradient, by finite differences.
		float e = 0.12;
		vec3 grad = vec3(fbm(p + vec3(e, 0, 0)) - g, fbm(p + vec3(0, e, 0)) - g, fbm(p + vec3(0, 0, e)) - g) / e;
		vec3 wn = face;
		grad -= wn * dot(grad, wn);
		vec3 bumped = normalize(wn - grad * bump * 0.25 * near);
		NORMAL = normalize((VIEW_MATRIX * vec4(bumped, 0.0)).xyz);
	}
	ALBEDO = base;
	ROUGHNESS = roughness_value;
	vec3 normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// (Times COLOR.a: where little sky is seen, the fill is what the stone round it gives back.)
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, (normal.y * 0.5 + 0.5) * COLOR.a) * zs_hemi_energy / PI;
	float sunward = clamp(dot(normal, zs_key_direction), 0.0, 1.0);
	float below = clamp(0.5 - 0.5 * normal.y, 0.0, 1.0);
	vec3 bounce = zs_cloud_sun * clamp(zs_key_direction.y, 0.0, 1.0) * ground_bounce * below / PI;
	// COLOR.a: the sky a vertex sees (the great dome's inside bakes it; every
	// other piece has 1): it dims the fill and the sky's reflection (AO).
	AO = COLOR.a;
	EMISSION = base * (hemi * fill + bounce + zs_look_bounce_light(normal) + zs_look_fill_light(1.0 - 0.75 * sunward)) * COLOR.a;
}
