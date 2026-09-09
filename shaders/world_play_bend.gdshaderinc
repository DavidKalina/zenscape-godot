// Only promoted trees supply these uniforms. Batched scenery takes the no-op path.
uniform vec2 play_bend = vec2(0.0);
uniform float play_height = 5.0;
uniform mat4 play_to_tree = mat4(1.0);
uniform mat4 play_from_tree = mat4(1.0);
vec3 play_curve(vec3 vertex) {
	vec3 p = (play_to_tree * vec4(vertex,1.0)).xyz;
	float amount = length(play_bend);
	vec3 d = vec3(play_bend.x,0.0,play_bend.y)/amount;
	vec3 side = cross(vec3(0.0,1.0,0.0),d);
	float theta = amount*max(p.y,0.0)/play_height;
	vec3 center = (d*(1.0-cos(theta))+vec3(0.0,sin(theta),0.0))*play_height/amount;
	vec3 radial = vec3(p.x,0.0,p.z);
	vec3 bent = center+radial*cos(theta)+cross(side,radial)*sin(theta)+side*dot(side,radial)*(1.0-cos(theta));
	return (play_from_tree*vec4(bent,1.0)).xyz;
}
void play_deform(inout vec3 vertex, inout vec3 normal) {
	if (length(play_bend)>0.0001) {
		vec3 tangent = normalize(cross(normal,abs(normal.y)<0.9?vec3(0,1,0):vec3(1,0,0)));
		vec3 bitangent = cross(normal,tangent);
		vec3 p = play_curve(vertex);
		normal = normalize(cross(play_curve(vertex+tangent*0.01)-p,play_curve(vertex+bitangent*0.01)-p));
		vertex = p;
	}
}
