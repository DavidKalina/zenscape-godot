shader_type spatial;
// The stomper's track on the land (scripts/endless/stomper_wake.gd): one MultiMesh
// of upright boxes, each a mark laid on whatever ground the depth shows inside it,
// so a frame costs one clock and the pixels of the boxes in view. Per instance:
//   the transform   the box: its x across, y up, z along (scale = full size, m)
//   CUSTOM = (born, life s, kind, seed)
//   kind 0          a footprint: bedded soil, the rim shoved up round it
//   kind 1          a stretch of ground the walk has scuffed and dusted over
// Lit: the land's light falls on it at the ground's point, and the print's walls
// turn the normal, so the sun picks out a real-looking dent.
render_mode depth_draw_never, depth_test_disabled, cull_front, shadows_disabled;

uniform float now = 0.0;
uniform vec3 soil = vec3(0.23, 0.18, 0.135);
uniform vec3 soil_deep = vec3(0.1, 0.085, 0.07);
uniform vec3 rim = vec3(0.38, 0.32, 0.24);
uniform vec3 scuff = vec3(0.56, 0.48, 0.36);
uniform float scuff_most = 0.3;
// Nearer the eye than this it isn't drawn (m): not on the plane.
uniform vec2 near_fade = vec2(12.0, 40.0);
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
	vec3 col = scuff;
	// The ground's faces are big and flat: lit mostly as up, or the mark shows them.
	vec3 n = normalize(mix(flat_n, vec3(0.0, 1.0, 0.0), 0.75));
	if (v_mark.z < 0.5) {
		float e = 2.0 / half_size.y;
		float h = dent(p, w.xz, v_mark.w);
		float dx = dent(p + vec2(e, 0.0), w.xz + v_across.xz * 2.0, v_mark.w) - h;
		float dz = dent(p + vec2(0.0, e), w.xz + v_along.xz * 2.0, v_mark.w) - h;
		// The dent's slope, stated strongly so the sun reads the walls from afar.
		vec3 tilt = (v_across * dx + v_along * dz) * 1.6;
		n = normalize(n - tilt);
		float s = sole(p, wobble(w.xz, v_mark.w));
		float deep = smoothstep(0.0, 0.45, s);
		float grain = vnoise(w.xz / 6.0 + v_mark.w) * 0.5 + vnoise(w.xz / 17.0) * 0.5;
		col = mix(soil, soil_deep, deep * grain);
		float lip = exp(-s * s * 40.0);
		col = mix(col, rim, lip * (1.0 - smoothstep(0.0, 0.12, s)));
		float bed = smoothstep(-0.02, 0.06, s) * mix(0.95, 0.68, grain * deep);
		a = max(bed, lip * 0.75 * smoothstep(0.3, 0.68, vnoise(w.xz / 12.0 + v_mark.w)));
		// The sides wear away first: the print goes from its rim in.
		a *= smoothstep(0.0, 1.5, age) * (1.0 - smoothstep(0.7, 1.0, age / life));
	} else {
		float across = abs(p.x);
		float rag = vnoise(w.xz / 64.0) * 0.6 + vnoise(w.xz / 23.0) * 0.4;
		float edge = 0.55 + (rag - 0.5) * 0.7;
		a = (1.0 - smoothstep(edge * 0.55, edge + 0.2, across));
		a *= 1.0 - smoothstep(0.7, 1.0, abs(p.y));
		a *= smoothstep(0.25, 0.6, rag + 0.15);
		a *= scuff_most * smoothstep(0.0, 6.0, age) * (1.0 - smoothstep(0.55, 1.0, age / life));
		col = mix(scuff, soil, 0.5 * (1.0 - rag));
	}
	a *= lies * (1.0 - smoothstep(0.55, 1.0, high)) * smoothstep(near_fade.x, near_fade.y, -v.z);
	if (a <= 0.003) {
		discard;
	}
	LIGHT_VERTEX = v.xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	ALPHA = clamp(a, 0.0, 1.0);
}
