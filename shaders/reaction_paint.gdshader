shader_type canvas_item;
// Paper grain for Bigfoot's reaction bubbles, fixed to the texture so it
// travels with the bubble. `reveal` sweeps an arc open from left to right
// around `reveal_pivot` (UV), which draws the rainbow in.

uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform vec2 reveal_pivot = vec2(0.5, 0.77);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 color = texture(TEXTURE, UV) * COLOR;
	vec2 texel = UV / TEXTURE_PIXEL_SIZE;
	float grain = hash(floor(texel / 2.0)) - 0.5;
	float fibre = sin(texel.x * 0.35 + sin(texel.y * 0.11) * 3.0) * 0.5;
	color.rgb *= 1.0 + grain * 0.08 + fibre * 0.03;
	if (reveal < 1.0) {
		vec2 d = UV - reveal_pivot;
		float angle = atan(-d.y, d.x);
		float sweep = angle < 0.0 ? step(0.0, d.x) : 1.0 - angle / PI;
		color.a *= 1.0 - smoothstep(reveal - 0.05, reveal, sweep);
	}
	COLOR = color;
}
