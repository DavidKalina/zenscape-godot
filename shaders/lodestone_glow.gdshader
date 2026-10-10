shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never;
// The lodestone's hum (scripts/lodestone.gd): a soft warm-white glow round
// the stone, a quad facing the eye stood a little behind the stone's
// middle, so the light seems to come from behind and around it. Wispy, not
// a disc: its falloff is broken by slow noise turning with the swirl.
#include "res://shaders/lodestone_vortex.gdshaderinc"

uniform vec3 colour : source_color = vec3(1.0, 0.9, 0.72);
uniform float strength = 0.5;
// The glow's radius (m, the lodestone's frame).
uniform float size = 0.3;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float scale = length(MODEL_MATRIX[0].xyz);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - world);
	world -= to_cam * size * scale * 0.4;
	vec2 corner = UV * 2.0 - 1.0;
	world += (INV_VIEW_MATRIX[0].xyz * corner.x + INV_VIEW_MATRIX[1].xyz * corner.y) * size * scale;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
}

float lg_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(lv_hash(i), lv_hash(i + vec2(1.0, 0.0)), f.x), mix(lv_hash(i + vec2(0.0, 1.0)), lv_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	// Wisps wound round the middle, turning with the swirl.
	float wisp = lg_noise(vec2(a * 2.0 + swirl * 0.3 - r * 3.0, r * 4.0 - clock * 0.2)) * 0.6 + lg_noise(vec2(a * 5.0 - swirl * 0.2, r * 9.0)) * 0.4;
	float body = exp(-r * r * 5.0);
	float g = body * mix(0.55, 1.15, wisp) * (1.0 - smoothstep(0.75, 1.0, r));
	ALBEDO = colour * g * strength * (0.4 + hum * 1.1);
}
