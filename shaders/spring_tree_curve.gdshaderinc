// Shared by the playground and promoted scenery; centerline matches PlaySpringTree.center.
vec3 spring_tree_curve(vec3 p, vec2 bend, vec2 crown, vec2 tip, float height) {
	float amount = length(bend);
	float u = max(p.y / height, 0.0);
	vec3 center = vec3(0.0, p.y, 0.0);
	vec3 tangent = vec3(0.0, 1.0, 0.0);
	if (amount >= 0.0001) {
		vec3 d = vec3(bend.x, 0.0, bend.y) / amount;
		float theta = amount * p.y / height;
		center = (d * (1.0 - cos(theta)) + vec3(0.0, sin(theta), 0.0)) * height / amount;
		tangent = d * sin(theta) + vec3(0.0, cos(theta), 0.0);
	}
	vec3 c = vec3(crown.x, 0.0, crown.y);
	vec3 t = vec3(tip.x, 0.0, tip.y);
	center += height * (0.32 * c * u*u*u + 0.14 * t * u*u*u*u*u);
	tangent = normalize(tangent + 0.96 * c * u*u + 0.70 * t * u*u*u*u);
	// Orient each cross-section along the new centerline, retaining branch volume.
	vec3 radial = vec3(p.x, 0.0, p.z);
	vec3 axis = cross(vec3(0.0, 1.0, 0.0), tangent);
	float sine = length(axis);
	if (sine > 0.00001) {
		axis /= sine;
		float cosine = tangent.y;
		radial = radial*cosine + cross(axis,radial)*sine + axis*dot(axis,radial)*(1.0-cosine);
	}
	return center + radial;
}
