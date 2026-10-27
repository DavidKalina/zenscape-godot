shader_type canvas_item;
render_mode unshaded, blend_disabled;
// The land's horizon march (scripts/endless/land_horizon.gd): per texel of
// the heights' square, the tangent of the land's horizon toward the key
// light's bearing (red), how much sky it sees past the land round it
// (green: 1 - the sine of the horizon, the mean of eight ways), and the
// horizon again counting only occluders past `near` m (blue). The light's
// height is left to the land's shader (land_horizon.gdshaderinc), so a sun
// sinking moves the shadows smoothly between marches. Into an HDR (half
// float) viewport.

uniform sampler2D heights : filter_linear, repeat_disable;
// Metres a texel.
uniform float texel = 16.0;
// The key light (toward it); only its bearing is read.
uniform vec3 light = vec3(0.0, 1.0, 0.0);
uniform float sea_y = -40.0;
uniform float near = 220.0;

// How far (m) a spot stands up off its own texel's height; the horizon kept
// in (-LOW, HIGH) (no land toward the light: -LOW).
const float LIFT = 2.0;
const float LOW = 8.0;
const float HIGH = 8.0;
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
	float best = -LOW;
	float best_far = -LOW;
	float across = length(light.xz);
	if (across > 1e-3) {
		vec2 dir = light.xz / across;
		float t = texel;
		for (int i = 0; i < SUN_STEPS; i++) {
			vec2 q = uv + dir * t / side;
			if (outside(q)) break;
			float s = (h_at(q) - h0) / t;
			best = max(best, s);
			if (t > near) best_far = max(best_far, s);
			t += max(texel, t * 0.1);
		}
	}
	float sky = 0.0;
	for (int k = 0; k < SKY_WAYS; k++) {
		float a = (float(k) + 0.5) * TAU / float(SKY_WAYS);
		vec2 dir = vec2(cos(a), sin(a));
		float top = 0.0;
		float t = texel;
		for (int i = 0; i < SKY_STEPS; i++) {
			vec2 q = uv + dir * t / side;
			if (outside(q)) break;
			top = max(top, (h_at(q) - h0) / t);
			t *= 1.4;
		}
		sky += 1.0 - top * inversesqrt(1.0 + top * top);
	}
	COLOR = vec4(min(best, HIGH), sky / float(SKY_WAYS), min(best_far, HIGH), 1.0);
}
