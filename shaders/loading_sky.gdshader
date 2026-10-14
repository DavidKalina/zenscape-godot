shader_type canvas_item;
// The loading screen's sky (scripts/roguelike/loading_screen.tscn): a calm
// three-stop gradient with two slow layers of soft painterly cloud drifting
// across it, and a faint vignette. Every colour is a uniform the scene sets,
// so the look is restyled from the scene, not here.
uniform vec4 top : source_color = vec4(0.27, 0.38, 0.50, 1.0);
uniform vec4 middle : source_color = vec4(0.58, 0.69, 0.75, 1.0);
uniform vec4 horizon : source_color = vec4(0.94, 0.85, 0.72, 1.0);
uniform vec4 cloud_light : source_color = vec4(1.0, 0.96, 0.89, 1.0);
uniform vec4 cloud_shade : source_color = vec4(0.62, 0.68, 0.76, 1.0);
// Screens of width the clouds cross per second, and how much cloud there is (0..1).
uniform float drift = 0.006;
uniform float cover : hint_range(0.0, 1.0) = 0.5;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		sum += amp * value(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		amp *= 0.5;
	}
	return sum;
}

// One cloud layer's density at uv: wide, flat banks.
float bank(vec2 uv, float aspect, float scale, float speed, float seed, float band_y, float band_h) {
	vec2 p = vec2(uv.x * aspect * scale - TIME * drift * speed * aspect * scale, uv.y * scale * 2.6 + seed);
	float n = fbm(p);
	float band = 1.0 - smoothstep(0.0, band_h, abs(uv.y - band_y));
	return smoothstep(1.0 - cover * 0.75 - 0.18, 1.0 - cover * 0.75 + 0.2, n * (0.55 + band * 0.75));
}

void fragment() {
	vec2 uv = UV;
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = res.x / res.y;
	vec3 sky = mix(top.rgb, middle.rgb, smoothstep(0.0, 0.55, uv.y));
	sky = mix(sky, horizon.rgb, smoothstep(0.42, 1.0, uv.y));
	// Far bank, slower and fainter; near bank, lit from the horizon's side.
	float far_bank = bank(uv, aspect, 1.3, 0.6, 3.0, 0.62, 0.34);
	sky = mix(sky, mix(cloud_shade.rgb, cloud_light.rgb, 0.55), far_bank * 0.42);
	float near_bank = bank(uv, aspect, 0.8, 1.0, 11.0, 0.78, 0.3);
	float lit = bank(uv + vec2(0.0, 0.012), aspect, 0.8, 1.0, 11.0, 0.78, 0.3);
	vec3 body = mix(cloud_light.rgb, cloud_shade.rgb, clamp((lit - near_bank) * 5.0 + 0.25, 0.0, 1.0));
	sky = mix(sky, body, near_bank * 0.7);
	// A very slight grain keeps the gradient from banding.
	sky += (hash(uv * res + fract(TIME)) - 0.5) * 0.012;
	float edge = length((uv - 0.5) * vec2(1.0, 0.8));
	sky *= 1.0 - vignette * smoothstep(0.35, 0.85, edge);
	COLOR = vec4(sky, 1.0);
}
