shader_type spatial;
// The stomper's track on the land (scripts/endless/stomper_wake.gd): one MultiMesh
// of upright boxes, each a mark laid on whatever ground the depth shows inside it,
// so a frame costs one clock and the pixels of the boxes in view. Per instance:
//   the transform   the box: its x across, y up, z along (scale = full size, m)
//   CUSTOM = (born, life s, kind, seed)
//   kind 0          a footprint: the ground bedded in, the rim shoved up round it
//   kind 1          a stretch of ground the walk has scuffed and dusted over
// Multiplied on the ground, whatever it is: the land's own colour pressed darker,
// not a paint of soil over it. The print's walls take the sun on one side and
// lose it on the other, so a dent reads as one from afar.
render_mode blend_mul, unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_front, shadows_disabled;

uniform float now = 0.0;
uniform vec3 sun = vec3(0.0, 1.0, 0.0);
// What the ground is multiplied by: a print's edge, its deep floor, a wall out
// of the sun, a scuffed stretch at its most.
uniform vec3 bed = vec3(0.74, 0.66, 0.58);
uniform vec3 bed_deep = vec3(0.5, 0.43, 0.38);
uniform vec3 wall_shade = vec3(0.42, 0.4, 0.48);
uniform vec3 scuff = vec3(0.74, 0.66, 0.54);
uniform float scuff_most = 0.9;
// Nearer the eye than this it isn't drawn (m): not on the plane.
uniform vec2 near_fade = vec2(12.0, 40.0);
// The environment's depth fog: begin, end, curve.
uniform vec3 haze = vec3(120.0, 7600.0, 0.75);
// Below the sea it isn't drawn: the water writes no depth.
uniform float sea_y = -40.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying flat vec3 v_centre;
varying flat vec3 v_across;
varying flat vec3 v_along;
varying flat vec3 v_size;
varying flat vec4 v_mark;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// The sole's edge isn't clean: the ground broke where it gave.
float wobble(vec2 w, float seed) {
	return (vnoise(w / 21.0 + seed) - 0.5) * 0.22 + (vnoise(w / 7.0 + seed) - 0.5) * 0.12;
}

// How far in the sole's edge a point is: 0 at the edge, 1 at the middle, below 0
// outside; p is in shares of the half box.
float sole(vec2 p, float wob) {
	vec2 a = abs(p) / vec2(0.62, 0.74);
	float d = pow(pow(a.x, 3.0) + pow(a.y, 3.0), 1.0 / 3.0);
	return 1.0 - d + wob;
}

// The dent: 0 on the land, -1 on the floor of the print, and above 0 on the rim.
float dent(vec2 p, vec2 w, float seed) {
	float s = sole(p, wobble(w, seed));
	float floor_ = -smoothstep(-0.02, 0.1, s);
	float lip = exp(-s * s * 90.0) * 0.55 * (0.7 + 0.6 * vnoise(w / 9.0 + seed));
	return floor_ + lip;
}

void vertex() {
	v_centre = MODEL_MATRIX[3].xyz;
	v_size = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	v_across = MODEL_MATRIX[0].xyz / v_size.x;
	v_along = MODEL_MATRIX[2].xyz / v_size.z;
	v_mark = INSTANCE_CUSTOM;
	float age = now - INSTANCE_CUSTOM.x;
	if (age < 0.0 || age >= INSTANCE_CUSTOM.y) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	float z = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z, 1.0);
	v.xyz /= v.w;
	vec3 w = (INV_VIEW_MATRIX * vec4(v.xyz, 1.0)).xyz;
	vec3 off = w - v_centre;
	vec2 half_size = v_size.xz * 0.5;
	vec2 p = vec2(dot(off, v_across), dot(off, v_along)) / half_size;
	float high = abs(off.y) / (v_size.y * 0.5);
	if (z <= 0.0 || max(abs(p.x), abs(p.y)) >= 1.0 || high >= 1.0 || w.y < sea_y) {
		discard;
	}
	vec3 flat_n = normalize(cross(dFdx(w), dFdy(w)));
	if (flat_n.y < 0.0) {
		flat_n = -flat_n;
	}
	float lies = smoothstep(0.42, 0.75, flat_n.y);
	float age = now - v_mark.x;
	float life = v_mark.y;
	float a = 0.0;
	vec3 m = scuff;
	if (v_mark.z < 0.5) {
		float e = 2.0 / half_size.y;
		float h = dent(p, w.xz, v_mark.w);
		float dx = dent(p + vec2(e, 0.0), w.xz + v_across.xz * 2.0, v_mark.w) - h;
		float dz = dent(p + vec2(0.0, e), w.xz + v_along.xz * 2.0, v_mark.w) - h;
		// The dent's slope, stated enough that the sun reads the walls from afar.
		vec3 tilt = (v_across * dx + v_along * dz) * 0.7;
		vec3 n = normalize(vec3(0.0, 1.0, 0.0) - tilt);
		float lit = clamp(dot(n, sun) / max(sun.y, 0.2), 0.0, 1.5);
		float s = sole(p, wobble(w.xz, v_mark.w));
		float deep = smoothstep(0.0, 0.5, s);
		float grain = vnoise(w.xz / 6.0 + v_mark.w) * 0.5 + vnoise(w.xz / 17.0) * 0.5;
		// Trodden in patches: the ground shows through the floor here and there.
		float patch_ = vnoise(w.xz / 38.0 + v_mark.w * 3.0);
		m = mix(bed, bed_deep, deep * mix(0.45, 1.0, grain));
		m = mix(wall_shade, vec3(1.0), smoothstep(0.0, 1.0, lit)) * m;
		m *= 1.0 + max(lit - 1.0, 0.0) * 0.5;
		float lip = exp(-s * s * 40.0);
		float floor_ = smoothstep(-0.02, 0.08, s) * mix(0.62, 1.0, smoothstep(0.25, 0.6, patch_));
		a = max(floor_, lip * 0.8 * smoothstep(0.3, 0.68, vnoise(w.xz / 12.0 + v_mark.w)));
		// The sides wear away first: the print goes from its rim in.
		a *= smoothstep(0.0, 1.5, age) * (1.0 - smoothstep(0.7, 1.0, age / life));
	} else {
		float across = abs(p.x);
		float rag = vnoise(w.xz / 64.0) * 0.6 + vnoise(w.xz / 23.0) * 0.4;
		float edge = 0.55 + (rag - 0.5) * 0.7;
		a = (1.0 - smoothstep(edge * 0.55, edge + 0.2, across));
		a *= 1.0 - smoothstep(0.3, 1.0, abs(p.y));
		a *= smoothstep(0.25, 0.6, rag + 0.15);
		a *= scuff_most * smoothstep(0.0, 6.0, age) * (1.0 - smoothstep(0.55, 1.0, age / life));
	}
	a *= lies * (1.0 - smoothstep(0.55, 1.0, high)) * smoothstep(near_fade.x, near_fade.y, -v.z);
	if (a <= 0.003) {
		discard;
	}
	float dist = length(v.xyz);
	float air = pow(smoothstep(haze.x, haze.y, dist), haze.z);
	ALBEDO = mix(vec3(1.0), m, clamp(a, 0.0, 1.0) * (1.0 - air));
}
