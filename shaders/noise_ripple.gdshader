shader_type spatial;
// A loud step's ring on the ground (scripts/noise/noise_ripples.gd): a soft,
// brushed band of dust-coloured air running out from the feet and thinning
// as it goes. Broken by a little value noise round the ring so it reads as
// dust pushed out, not a drawn circle.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.82, 0.76, 0.64, 1.0);
// 0 just made .. 1 run out and gone.
uniform float k = 0.0;
// How much there is of it (0..1).
uniform float strength = 0.5;
uniform float seed = 0.0;

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

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float a = atan(c.y, c.x);
	// The front: out to the rim as k runs, easing.
	float front = 1.0 - pow(1.0 - k, 2.2);
	float wide = mix(0.16, 0.34, k);
	float wobble = (vnoise(vec2(a * 3.0 + seed, k * 2.0)) - 0.5) * 0.12;
	float d = r - front + wobble;
	float band = smoothstep(-wide, 0.0, d) * (1.0 - smoothstep(0.0, wide * 0.45, d));
	// Brushed: streaks along the way out, holes in the band.
	float brush = vnoise(vec2(a * 9.0 + seed * 3.1, r * 4.0));
	band *= mix(0.45, 1.0, brush);
	float fade = (1.0 - smoothstep(0.35, 1.0, k)) * smoothstep(0.0, 0.08, k);
	ALBEDO = tint.rgb;
	ALPHA = clamp(band * fade * strength, 0.0, 1.0) * step(r, 1.0);
}
