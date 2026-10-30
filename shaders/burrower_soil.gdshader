shader_type spatial;
#include "res://shaders/burrower_grit.gdshaderinc"
// The burrower's loose earth (scripts/burrower/burrower.gd clods via a
// MultiMesh, push_ups.gd domes): gritty soil over the base colour. With
// `use_instance` the base is the instance colour and each clod has its own
// grain; otherwise `tint` and `seed`.

uniform bool use_instance = false;
uniform vec3 tint : source_color = vec3(0.29, 0.22, 0.15);
uniform float seed = 0.0;
uniform float dry = 0.4;
uniform float bump = 0.9;

varying vec3 v_p;
varying vec3 v_base;
varying float v_seed;

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void vertex() {
	v_p = VERTEX;
	if (use_instance) {
		v_base = to_linear(COLOR.rgb);
		v_seed = float(INSTANCE_ID % 61) * 0.37;
	} else {
		v_base = tint;
		v_seed = seed;
	}
}

void fragment() {
	// Dome-sized objects are scaled up, so grain stays the same size in the world
	// only roughly; fine for earth.
	vec3 p = v_p * (use_instance ? 2.6 : 1.4);
	vec3 c = grit_albedo(p, v_base * 1.15, dry, v_seed);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	float h = grit_height(p, v_seed);
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * NORMAL - bump * 0.02 * grad);
}
