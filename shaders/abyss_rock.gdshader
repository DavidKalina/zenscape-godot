shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
// The abyss wall (scripts/underground/underground.gd): a huge, far, enclosing
// shaft of rock. Strata and cracks from noise on the world position; lit from
// far above (lighter toward the top, as if by the surface), falling into the
// murk with distance so the near ruins stand against it.
uniform vec3 rock_dark : source_color = vec3(0.05, 0.065, 0.09);
uniform vec3 rock_light : source_color = vec3(0.26, 0.30, 0.37);
uniform vec3 murk_color : source_color = vec3(0.085, 0.115, 0.17);
uniform vec3 warm_tint : source_color = vec3(0.16, 0.12, 0.10);
uniform float murk_density = 0.0028;
uniform float top_y = 300.0;
uniform float bottom_y = -400.0;
uniform float scale = 0.035;

varying vec3 wpos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0,0,0)), hash(i + vec3(1,0,0)), f.x),
				   mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
				   mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float fbm(vec3 p) {
	float a = 0.5; float s = 0.0;
	for (int i = 0; i < 5; i++) { s += a * vnoise(p); p = p * 2.03 + vec3(7.1, 3.3, 1.7); a *= 0.5; }
	return s;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float rock_h(vec3 p) {
	float warp = fbm(p * 0.45) * 4.0;
	float strata = vnoise(vec3(p.x * 0.7, p.y * 1.0 + warp, p.z * 0.7));
	return strata * 0.55 + fbm(p * 1.5) * 0.7;
}

void fragment() {
	vec3 p = wpos * scale;
	float h = rock_h(p);
	// Lit from far above: a ledge's top catches it, its underside doesn't.
	float e = 0.12;
	float up = rock_h(p + vec3(0.0, e, 0.0));
	float down = rock_h(p - vec3(0.0, e, 0.0));
	float side = rock_h(p + vec3(e, 0.0, e));
	float lit = clamp(0.55 + (down - up) * 5.0 + (h - side) * 2.0, 0.1, 1.5);
	float tone = clamp(h * 0.9, 0.0, 1.0);
	vec3 rock = mix(rock_dark, rock_light, tone);
	rock = mix(rock, warm_tint * 0.7, smoothstep(0.55, 0.8, vnoise(p * 0.7 + 3.0)) * 0.3);
	rock *= lit;
	// The far light above: lighter toward the top of the shaft.
	float hh = clamp((wpos.y - bottom_y) / (top_y - bottom_y), 0.0, 1.0);
	rock *= mix(0.3, 1.3, smoothstep(0.35, 1.0, hh));
	// Murk by distance from the eye.
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float murk = 1.0 - exp(-dist * murk_density);
	ALBEDO = mix(rock, murk_color, clamp(murk, 0.0, 0.9));
}
