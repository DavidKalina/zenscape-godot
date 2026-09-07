shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
#include "res://shaders/reference_globals.gdshaderinc"
varying float fade;
void vertex() { fade = INSTANCE_CUSTOM.r; }
void fragment() {
	float radius = length(UV-vec2(0.5))*2.0;
	float edge = smoothstep(0.72,0.82,radius)*(1.0-smoothstep(0.90,1.0,radius));
	ALBEDO = vec3(0.55,0.72,0.78)*mix(0.15,1.0,zs_daylight);
	ALPHA = fade*edge*0.45;
}
