shader_type spatial;
// The tunnels' hanging roots and vines (scripts/endless/land_tunnels.gd
// `_build_growth`): HangingRoots' strand, wander, kinks, fork and sway
// (scripts/shared/hanging_roots.gd SHADER, its FORK_AT 0.35), worn in
// `tint` (bark or vine green) and torch lit only, with a faint fill.
render_mode cull_back, ambient_light_disabled, fog_disabled;
uniform vec3 tint : source_color = vec3(0.1);
uniform float sway_speed = 0.8;
const float FORK_AT = 0.35;
float tri(float x) { return abs(fract(x) * 2.0 - 1.0); }
void vertex() {
	float t = -VERTEX.y;
	float len = length(MODEL_MATRIX[1].xyz);
	vec4 c = INSTANCE_CUSTOM; // phase, thickness, shape, fork
	float ph = c.x * 6.2831;
	float amp = min(0.06 * len + 0.12, 2.2);
	vec2 wander = vec2(sin(t * 2.6 + ph), sin(t * 2.1 + ph * 1.7 + 1.3)) * 0.8;
	vec2 kink = vec2(tri(t * 2.3 + c.z) - 0.5, tri(t * 1.7 + c.z * 3.1 + 0.4) - 0.5) * 1.6;
	vec2 off = (wander + kink) * amp * t;
	vec2 sway = vec2(sin(TIME * sway_speed + ph + t * 2.0), cos(TIME * sway_speed * 0.8 + ph * 1.3 + t * 1.6));
	off += sway * min(0.025 * len, 0.5) * t * t;
	float ring_scale = c.y;
	if (UV.x > 0.5) {
		float a = c.z * 6.2831;
		off += vec2(cos(a), sin(a)) * (t - FORK_AT) * len * 0.3;
		if (c.w < 0.5) ring_scale = 0.0;
	}
	VERTEX.xz = VERTEX.xz * ring_scale + off;
}
void fragment() {
	// The strand's own bark gradient (about 0.3 in red) shades the tint.
	ALBEDO = tint * (0.6 + 0.8 * COLOR.r / 0.3);
	ROUGHNESS = 0.95;
	EMISSION = ALBEDO * 0.25;
}
