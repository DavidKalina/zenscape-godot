shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
#include "res://shaders/reference_globals.gdshaderinc"
uniform float activity = 0.0;
varying float glow;
void vertex() {
	float phase = INSTANCE_CUSTOM.x;
	float amplitude = INSTANCE_CUSTOM.y;
	float rate = INSTANCE_CUSTOM.z;
	float t = zs_motion_time*0.5+phase*37.0;
	vec4 center = MODEL_MATRIX[3];
	center.x += sin(t*0.9+phase*6.28318)*amplitude;
	center.z += cos(t*0.7+phase*12.0)*amplitude;
	center.y += sin(t*1.3+phase*20.0)*amplitude*0.5;
	float cycle = fract(zs_motion_time/(2.8+rate*2.6)+phase);
	// INSTANCE_CUSTOM.w is absence: a firefly that has not arrived yet, or has
	// left (scripts/land_life.gd). The Fidelity set keeps 0.
	glow = smoothstep(0.0,0.05,cycle)*(1.0-smoothstep(0.09,0.17,cycle))*activity*(1.0-INSTANCE_CUSTOM.w);
	MODELVIEW_MATRIX = VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],center);
	// Room for the halo round the hot core: the core itself stays a few
	// pixels across.
	VERTEX *= (5.0+glow*11.0)*60.0/(VIEWPORT_SIZE.y*PROJECTION_MATRIX[1][1]);
}
void fragment() {
	// A white-hot heart in a wide chartreuse halo, bright past 1.0 so the
	// glow catches it: a point of light, not a flat green disc.
	float d = length(UV-vec2(0.5))*2.0;
	float edge = 1.0-smoothstep(0.75,1.0,d);
	float core = exp(-d*d*60.0);
	float inner = exp(-d*d*16.0);
	float halo = exp(-d*d*6.5)*edge;
	vec3 light = vec3(0.55,1.0,0.22)*halo*0.9 + vec3(0.86,1.0,0.45)*inner*1.6 + vec3(1.0,1.0,0.86)*core*5.0;
	ALBEDO = light;
	ALPHA = clamp(glow,0.0,1.0);
}
