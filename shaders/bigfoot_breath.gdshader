shader_type spatial;
render_mode cull_disabled, depth_draw_never;
#include "res://shaders/reference_cloud_field.gdshaderinc"
uniform float age = 0.0;
uniform float diameter = 0.1;
uniform float seed = 0.0;
void vertex() {
 MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
 VERTEX.xy *= diameter;
}
void fragment() {
 vec2 p = UV * 2.0 - 1.0;
 float edge = pow(max(0.0, 1.0-dot(p,p)), 2.0);
 float wisps = wxFbm2(vec3(p*3.0+vec2(seed,seed*0.37),age*0.6));
 float fade = smoothstep(0.0,0.12,age)*(1.0-smoothstep(0.45,1.65,age));
 ALBEDO = vec3(0.76,0.84,0.78);
 EMISSION = ALBEDO*0.08;
 ROUGHNESS = 1.0;
 ALPHA = edge*(0.45+wisps)*fade*0.24;
}
