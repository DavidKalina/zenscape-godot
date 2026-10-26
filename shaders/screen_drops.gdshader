shader_type canvas_item;
// Drops of water on the chase camera's lens (scripts/endless/screen_wet.gd):
// one quad per drop of a MultiMesh. Each is a little lens: it shows the scene
// behind it flipped and drawn in, a touch blurred, darker at its rim where the
// light bends away, with a highlight. INSTANCE_CUSTOM: x opacity, y how far
// the lens reaches (screen uv), z seed, w unused.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;

varying vec4 drop;

void vertex() {
	drop = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	// A little wobble round the edge, so no drop is a perfect circle.
	float a = atan(p.y, p.x);
	float wob = 1.0 + 0.06 * sin(a * 3.0 + drop.z * 40.0) + 0.04 * sin(a * 5.0 + drop.z * 17.0);
	float r = length(p) * wob;
	float mask = smoothstep(1.0, 0.86, r);
	if (mask <= 0.0) discard;
	float dome = sqrt(max(0.0, 1.0 - r * r));
	vec2 look = SCREEN_UV - p * drop.y * (1.2 - 0.5 * dome);
	vec3 scene = textureLod(screen, look, 0.0).rgb;
	float rim = smoothstep(0.55, 1.0, r);
	vec3 colour = scene * mix(1.1, 0.42, rim);
	// The sky's highlight up and to the left, and a faint one opposite.
	vec2 h = p - vec2(-0.32, -0.42);
	colour += vec3(1.0) * 0.55 * exp(-dot(h, h) * 22.0);
	vec2 h2 = p - vec2(0.38, 0.5);
	colour += vec3(1.0) * 0.12 * exp(-dot(h2, h2) * 14.0);
	COLOR = vec4(colour, mask * drop.x);
}
