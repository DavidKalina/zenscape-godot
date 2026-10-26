shader_type canvas_item;
// A sheet of water across the lens for a moment after a dousing (scripts/
// endless/screen_wet.gd `wet`): the scene bent by a running film and blurred,
// paled a touch, thinning out as `sheet` falls. `flow` is the way it runs
// off (screen uv per second).

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float sheet = 0.0;
uniform float time = 0.0;
uniform vec2 flow = vec2(0.0, 0.6);

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.55);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.55);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.55);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.55);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 q = uv * vec2(7.0, 4.0) - flow * time * 3.0;
	float n = vnoise(q) * 0.6 + vnoise(q * 2.7 + 4.0) * 0.4;
	vec2 bend = vec2(vnoise(q + 9.0) - 0.5, n - 0.5);
	// Where the film has run off already: it clears from the centre out.
	float film = smoothstep(0.15, 0.6, n + sheet - 0.35);
	float k = sheet * film;
	// A soft blur of a few taps (the screen's own mips go blocky in 2D).
	vec2 o = uv + bend * 0.03 * k;
	vec2 px = 0.004 * k * vec2(1.0, 1.7);
	vec3 scene = (textureLod(screen, o, 0.0).rgb * 2.0 + textureLod(screen, o + px, 0.0).rgb + textureLod(screen, o - px, 0.0).rgb
		+ textureLod(screen, o + vec2(px.x, -px.y), 0.0).rgb + textureLod(screen, o + vec2(-px.x, px.y), 0.0).rgb) / 6.0;
	scene = mix(scene, vec3(0.82, 0.88, 0.92), 0.12 * k);
	COLOR = vec4(scene, clamp(k * 1.1, 0.0, 0.85));
}
