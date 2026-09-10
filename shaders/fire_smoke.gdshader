shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, cull_disabled, shadows_disabled;
// Alpha-blended smoke MUST write depth or the Balanced fog composite paints it
// as ground (docs/garden/VALIDATION.md:110).
#include "res://shaders/fire_noise.gdshaderinc"

// INSTANCE_CUSTOM = (seed, size, alpha, age).
uniform float time = 0.0;
uniform float opacity = 1.0;

varying vec2 v_uv;
varying float v_seed;
varying float v_alpha;
varying float v_age;

void vertex() {
	v_seed = INSTANCE_CUSTOM.x;
	v_alpha = INSTANCE_CUSTOM.z;
	v_age = INSTANCE_CUSTOM.w;
	v_uv = UV;
	vec3 center = MODEL_MATRIX[3].xyz;
	MODELVIEW_MATRIX = VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],vec4(center,1.0));
	VERTEX.xy *= max(INSTANCE_CUSTOM.y,0.001);
}

void fragment() {
	vec2 p = v_uv-vec2(0.5);
	float angle = v_seed*6.2831+time*0.22*(v_seed-0.5);
	float c = cos(angle);
	float s = sin(angle);
	p = mat2(vec2(c,-s),vec2(s,c))*p;
	float r = length(p)*2.0;
	float lump = zs_fire_fbm(p*4.4+vec2(v_seed*23.0,-time*0.12));
	// Erode the disc with the noise so a puff has a torn edge, not a rim.
	float mask = clamp((1.0-smoothstep(0.10,1.0,r))*(1.45*lump+0.10)-0.10,0.0,1.0);
	// Sooty at the flame, pale and thin once it has climbed and spread.
	vec3 grey = mix(vec3(0.11,0.10,0.095),vec3(0.50,0.49,0.48),v_age);
	ALBEDO = grey;
	ALPHA = clamp(mask*v_alpha*opacity,0.0,1.0);
	// Depth writes are mandatory under the Balanced fog composite, but a quad
	// that wrote depth over its transparent corners painted the fog march with
	// grey rectangles. Discard those fragments outright: no colour, no depth,
	// and unlike ALPHA_SCISSOR_THRESHOLD it keeps the soft blended edge.
	if (ALPHA < 0.02) { discard; }
}
