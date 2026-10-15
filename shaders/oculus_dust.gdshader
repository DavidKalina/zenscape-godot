shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Dust adrift in the oculus's light (scripts/underground/underground.gd): a
// soft camera-facing speck that is only lit where it floats inside a shaft
// (the three cones from the opening), so the daylight shows itself in the
// murk and the dark between stays empty. Each speck fades in and out over
// its life (INSTANCE_CUSTOM.y, 0 to 1), so none blinks.
uniform vec3 top = vec3(0.0, 500.0, 0.0);
uniform vec3 foot_a = vec3(0.0);
uniform vec3 foot_b = vec3(0.0);
uniform vec3 foot_c = vec3(0.0);
uniform vec3 land = vec3(34.0, 26.0, 44.0);   // each shaft's radius where it lands
uniform float top_r = 60.0;                    // and at the opening
uniform vec3 tint : source_color = vec3(1.0, 0.82, 0.58);
uniform float strength = 1.0;
varying float lit;

float inside(vec3 p, vec3 foot, float r_low) {
	vec3 axis = top - foot;
	float len = length(axis);
	vec3 dir = axis / len;
	vec3 rel = p - foot;
	float t = dot(rel, dir);
	float d = length(rel - dir * t);
	float rad = mix(r_low, top_r, clamp(t / len, 0.0, 1.0));
	return (1.0 - smoothstep(0.35 * rad, 1.0 * rad, d)) * step(-20.0, t);
}

void vertex() {
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float s = inside(centre, foot_a, land.x) + inside(centre, foot_b, land.y) * 0.6 + inside(centre, foot_c, land.z);
	lit = 0.04 + 0.75 * clamp(s, 0.0, 1.0);
	float ph = INSTANCE_CUSTOM.y;
	lit *= smoothstep(0.0, 0.2, ph) * (1.0 - smoothstep(0.75, 1.0, ph));
	float size = 0.06 + 0.04 * fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 world = centre + (right * VERTEX.x + up * VERTEX.y) * size * 2.0;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float d2 = dot(q, q);
	float core = exp(-d2 * 7.0) * (1.0 - smoothstep(0.7, 1.0, d2));
	ALBEDO = tint * core * lit * strength * 0.9;
}
