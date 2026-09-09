shader_type spatial;
#include "res://shaders/scene_palette.gdshaderinc"
#include "res://shaders/spring_tree_curve.gdshaderinc"
render_mode cull_disabled, diffuse_lambert;
uniform vec2 bend = vec2(0.0);
uniform vec2 crown_offset = vec2(0.0);
uniform vec2 tip_offset = vec2(0.0);
uniform vec3 tint : source_color = vec3(1.0);
uniform float attention = 0.0;
vec3 bend_point(vec3 p) {
	return spring_tree_curve(p, bend, crown_offset, tip_offset, 5.0);
}
void vertex() {
	// Source crown reaches 4.262514 metres; normalize both parts to the play tree.
	VERTEX *= 5.0/4.262514;
	vec3 tangent = normalize(cross(NORMAL,abs(NORMAL.y)<0.9?vec3(0,1,0):vec3(1,0,0)));
	vec3 bitangent = cross(NORMAL,tangent);
	vec3 p = bend_point(VERTEX);
	NORMAL = normalize(cross(bend_point(VERTEX+tangent*0.01)-p,bend_point(VERTEX+bitangent*0.01)-p));
	VERTEX = p;
}
void fragment() {
	ALBEDO = scene_palette(COLOR.rgb*tint);
	ROUGHNESS = 0.95;
	EMISSION = vec3(1.0,0.65,0.2)*attention;
}
