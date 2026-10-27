shader_type canvas_item;
render_mode unshaded, blend_disabled;
// The land's horizon march (scripts/endless/land_horizon.gd): per texel of
// the heights' square, how much of the key light reaches it past the land
// toward the light (red), how much sky it sees past the land round it
// (green: 1 - the sine of the horizon, the mean of eight ways), and the
// light again counting only occluders past `near` m (blue).

uniform sampler2D heights : filter_linear, repeat_disable;
// Metres a texel.
uniform float texel = 16.0;
// The key light (toward it).
uniform vec3 light = vec3(0.0, 1.0, 0.0);
uniform float sea_y = -40.0;
uniform float near = 220.0;

// The light's soft edge (in the horizon's tangent), and how far (m) a spot
// stands up off its own texel's height.
const float PEN = 0.025;
const float LIFT = 2.0;
const int SUN_STEPS = 48;
const int SKY_WAYS = 8;
const int SKY_STEPS = 12;

float h_at(vec2 uv) {
	return max(texture(heights, uv).r, sea_y);
}

bool outside(vec2 q) {
	return q.x < 0.0 || q.y < 0.0 || q.x > 1.0 || q.y > 1.0;
}

void fragment() {
	vec2 uv = UV;
	float side = texel * float(textureSize(heights, 0).x);
	float h0 = h_at(uv) + LIFT + texel * 0.08;
	float full = 1.0;
	float far_only = 1.0;
	float across = length(light.xz);
	if (light.y <= 0.0) {
		full = 0.0;
		far_only = 0.0;
	} else if (across > 1e-3) {
		vec2 dir = light.xz / across;
		float sun_tan = light.y / across;
		float best = -1e3;
		float best_far = -1e3;
		float t = texel;
		for (int i = 0; i < SUN_STEPS; i++) {
			vec2 q = uv + dir * t / side;
			if (outside(q)) break;
			float s = (h_at(q) - h0) / t;
			best = max(best, s);
			if (t > near) best_far = max(best_far, s);
			t += max(texel, t * 0.1);
		}
		full = smoothstep(-PEN, PEN, sun_tan - best);
		far_only = smoothstep(-PEN, PEN, sun_tan - best_far);
	}
	float sky = 0.0;
	for (int k = 0; k < SKY_WAYS; k++) {
		float a = (float(k) + 0.5) * TAU / float(SKY_WAYS);
		vec2 dir = vec2(cos(a), sin(a));
		float best = 0.0;
		float t = texel;
		for (int i = 0; i < SKY_STEPS; i++) {
			vec2 q = uv + dir * t / side;
			if (outside(q)) break;
			best = max(best, (h_at(q) - h0) / t);
			t *= 1.4;
		}
		sky += 1.0 - best * inversesqrt(1.0 + best * best);
	}
	COLOR = vec4(full, sky / float(SKY_WAYS), far_only, 1.0);
}
