shader_type spatial;
#include "res://shaders/scene_palette.gdshaderinc"
render_mode cull_disabled, diffuse_lambert;
uniform vec2 bend = vec2(0.0);
uniform vec3 tint : source_color = vec3(1.0);
uniform float attention = 0.0;
vec3 bend_point(vec3 p) {
	float amount = length(bend);
	if (amount < 0.0001) return p;
	vec3 d = vec3(bend.x,0.0,bend.y)/amount;
	vec3 side = cross(vec3(0.0,1.0,0.0),d);
	float theta = amount*p.y/5.0;
	vec3 center = (d*(1.0-cos(theta))+vec3(0.0,sin(theta),0.0))*5.0/amount;
	vec3 radial = vec3(p.x,0.0,p.z);
	return center + radial*cos(theta)+cross(side,radial)*sin(theta)+side*dot(side,radial)*(1.0-cos(theta));
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
