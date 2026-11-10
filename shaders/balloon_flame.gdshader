shader_type spatial;
// The balloon burner's flame (scripts/endless/endless_balloons.gd): a cone
// from the burner up into the mouth, UV.y 0 at the jet to 1 at the tip.
// `burn` 0..1 is how hard it fires; nothing is drawn at 0.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float burn = 0.0;
instance uniform float seed = 0.0;

uniform vec3 jet : source_color = vec3(0.25, 0.45, 1.0);
uniform vec3 body : source_color = vec3(1.0, 0.5, 0.14);
uniform vec3 tip : source_color = vec3(1.0, 0.82, 0.4);
uniform float energy = 5.0;

float hash1(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash1(i), hash1(i + vec2(1.0, 0.0)), f.x), mix(hash1(i + vec2(0.0, 1.0)), hash1(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	// The flame grows with the burn and wavers toward its tip.
	float t = UV.y;
	VERTEX.y *= mix(0.35, 1.0, burn) ;
	VERTEX.xz *= mix(0.5, 1.0, burn);
	VERTEX.xz += vec2(sin(TIME * 23.0 + seed + t * 5.0), cos(TIME * 19.0 + seed * 2.0 + t * 4.0)) * 0.06 * t * t;
}

void fragment() {
	float t = UV.y;
	float n = vnoise(vec2(UV.x * 8.0, t * 5.0 - TIME * 9.0 + seed));
	float shape = smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.55 + 0.4 * n, 1.0, t));
	float facing = abs(dot(NORMAL, VIEW));
	vec3 c = mix(jet, body, smoothstep(0.02, 0.22, t));
	c = mix(c, tip, smoothstep(0.1, 0.5, t) * facing);
	ALBEDO = c * energy * shape * burn * (0.55 + 0.45 * n) * (0.35 + 0.65 * facing);
}
