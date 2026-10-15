shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// A soft pool of light laid on a surface (scripts/city_kit_light2.gd): where
// the sun-mirror's beam lands, the foot of a light shaft, the mirror's lit
// coin. A quad (PlaneMesh/QuadMesh), additive, brightest at its middle and
// gone at its rim, a slow breath of dust over it.

uniform vec3 tint : source_color = vec3(1.0, 0.92, 0.75);
uniform float strength = 1.0;
uniform float softness = 1.6;
uniform float far_fade = 160.0;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float pool = pow(clamp(1.0 - r, 0.0, 1.0), softness);
	float breath = 0.9 + 0.1 * sin(TIME * 1.7 + world.x * 0.3);
	float dist = length(world - CAMERA_POSITION_WORLD);
	float far = 1.0 - smoothstep(far_fade * 0.5, far_fade, dist);
	ALBEDO = tint * strength * pool * breath * far;
}
