#include "res://shaders/spring_tree_curve.gdshaderinc"
// Only promoted trees supply these uniforms. Batched scenery takes the no-op path.
uniform vec2 play_bend = vec2(0.0);
uniform vec2 play_crown_offset = vec2(0.0);
uniform vec2 play_tip_offset = vec2(0.0);
uniform float play_height = 5.0;
uniform mat4 play_to_tree = mat4(1.0);
uniform mat4 play_from_tree = mat4(1.0);
vec3 play_curve(vec3 vertex) {
	vec3 p = (play_to_tree * vec4(vertex,1.0)).xyz;
	vec3 bent = spring_tree_curve(p,play_bend,play_crown_offset,play_tip_offset,play_height);
	return (play_from_tree*vec4(bent,1.0)).xyz;
}
void play_deform(inout vec3 vertex, inout vec3 normal) {
	if (length(play_bend)+length(play_crown_offset)+length(play_tip_offset)>0.0001) {
		vec3 tangent = normalize(cross(normal,abs(normal.y)<0.9?vec3(0,1,0):vec3(1,0,0)));
		vec3 bitangent = cross(normal,tangent);
		vec3 p = play_curve(vertex);
		normal = normalize(cross(play_curve(vertex+tangent*0.01)-p,play_curve(vertex+bitangent*0.01)-p));
		vertex = p;
	}
}
