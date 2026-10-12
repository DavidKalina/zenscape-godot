shader_type spatial;
render_mode diffuse_lambert;
// The plane's paint and its cockpit pilot's (scripts/plane_figure.gd
// `paints`, scripts/plane_pilot.gd), a sibling of the walker's
// (shaders/pilot_paint.gdshader): soft painted, not lacquered. The sun falls
// in a few soft bands (lit, half lit, shade), warm on the lit side; the
// shade takes the sky's hemisphere as the folk do (the world takes no
// ambient), cooled; a gentle sky rim on the edges. Flat colours are broken
// by a slow mottle and brush-like streaks laid in the mesh's own space (the
// plane's meshes carry no UVs), and a paint's own number (`own`) shifts its
// colour a touch. The band edges wander with the same noise.
//
// Worn (`wear`, scripts/plane_figure.gd `set_wear`; 0 new): the colour
// drained by the sun, patches lifted chalky, fine scuffs, dust on what faces
// up. `shine` gives metal a soft painted highlight band instead of a mirror.
// A gleam (`gleam`, the plane mended) sweeps a warm band over it.
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float fill = 2.6;
uniform vec3 warm = vec3(1.06, 1.0, 0.9);
uniform vec3 cool = vec3(0.92, 0.96, 1.04);
uniform float half_at = -0.05;
uniform float full_at = 0.38;
uniform float soft = 0.09;
uniform float half_share = 0.55;
uniform float rim = 0.12;
uniform float sun = 0.62;
uniform float mottle = 0.08;
uniform float streaks = 0.05;
uniform float paint_scale = 9.0;
uniform float wobble = 0.08;
uniform float own = 0.5;
uniform float shine = 0.0;
uniform float wear : hint_range(0.0, 1.0) = 0.0;
uniform float wear_scale = 14.0;
uniform vec3 wear_dust : source_color = vec3(0.71, 0.65, 0.55);
uniform float gleam = 0.0;
uniform vec3 gleam_dir = vec3(0.0, 0.0, 1.0);
uniform float gleam_at = 0.0;
uniform float gleam_width = 0.12;

varying vec3 rest;
varying vec3 world;

void vertex() {
	rest = VERTEX;
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
			mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
			mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

varying float paint;

void fragment() {
	vec3 p = rest * paint_scale;
	float m = noise3(p) * 0.6 + noise3(p * 2.3 + 7.1) * 0.4;
	float s = noise3(vec3(p.x * 5.0 + p.z * 3.0, p.y * 0.8 - p.x * 0.6, p.z * 5.0 - p.y)) - 0.5;
	paint = m;
	vec3 base = albedo.rgb;
	base *= 1.0 + (m - 0.5) * 2.0 * mottle + s * 2.0 * streaks;
	base *= mix(vec3(1.03, 1.0, 0.96), vec3(0.97, 1.0, 1.04), own);
	vec3 normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (wear > 0.0) {
		vec3 q = rest * wear_scale;
		float w = noise3(q) * 0.65 + noise3(q * 2.7 + 4.1) * 0.35;
		base = mix(base, vec3(dot(base, vec3(0.3, 0.55, 0.15))), 0.28 * wear);
		base = mix(base, mix(base, vec3(0.93, 0.88, 0.78), 0.35), smoothstep(0.55, 0.85, w) * wear);
		base *= 1.0 - (0.5 - w) * 0.2 * wear;
		float sc = noise3(rest * vec3(wear_scale * 7.0, wear_scale * 7.0, wear_scale * 0.7) + 2.3);
		base = mix(base, vec3(0.78, 0.72, 0.62), smoothstep(0.7, 0.86, sc) * smoothstep(0.45, 0.75, w) * wear * 0.22);
		float dust = smoothstep(0.15, 0.85, normal.y) * (0.5 + 0.5 * noise3(q * 0.5 + 9.0)) * wear;
		base = mix(base, wear_dust, dust * 0.42);
	}
	ALBEDO = clamp(base, 0.0, 1.0);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, normal.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge = smoothstep(0.6, 0.95, 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0));
	EMISSION = ALBEDO * cool * hemi * fill
		+ mix(ALBEDO, vec3(1.0), 0.5) * dot(zs_hemi_sky, vec3(0.3333)) * zs_hemi_energy * edge * rim;
	if (gleam > 0.0) {
		float band = 1.0 - smoothstep(0.0, gleam_width, abs(dot(world, gleam_dir) - gleam_at));
		EMISSION += (ALBEDO * 0.9 + vec3(1.0, 0.8, 0.5) * 0.4) * band * band * gleam;
	}
}

void light() {
	float nl = dot(NORMAL, LIGHT) + (paint - 0.5) * wobble * 2.0;
	float lit = mix(smoothstep(half_at - soft, half_at + soft, nl) * half_share, 1.0,
		smoothstep(full_at - soft, full_at + soft, nl));
	float shadow = smoothstep(0.25, 0.65, ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR * warm * lit * shadow * sun / PI;
	if (shine > 0.0) {
		// A painted highlight: a soft-edged band, not a mirror's point.
		float h = dot(reflect(-LIGHT, NORMAL), VIEW);
		SPECULAR_LIGHT += LIGHT_COLOR * shadow * smoothstep(0.82, 0.9, h + (paint - 0.5) * 0.06) * shine * 0.35;
	}
}
