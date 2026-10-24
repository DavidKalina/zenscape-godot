shader_type spatial;
// The spruce sprites' normal pass (scripts/endless/spruce_sprites.gd): each
// face's light normal as reference_surface lights a sprays crown past its
// near detail, the flat face turned to the eye and `round` of the way to the
// volume's (out from the trunk and up, spruce_paint.gdshaderinc), written in
// the bake camera's view space as colour.
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float round = 0.7;

varying vec3 world;
varying flat vec3 root;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	root = MODEL_MATRIX[3].xyz;
}

void fragment() {
	vec3 face = normalize(cross(dFdx(world), dFdy(world)));
	if (dot(face, -CAMERA_DIRECTION_WORLD) < 0.0) face = -face;
	vec2 out_xz = world.xz - root.xz;
	float r = length(out_xz);
	vec2 dir = out_xz / max(r, 1e-3) * smoothstep(0.0, 0.5, r);
	vec3 n = normalize(mix(face, normalize(vec3(dir.x, 0.62, dir.y)), round));
	ALBEDO = (VIEW_MATRIX * vec4(n, 0.0)).xyz * 0.5 + 0.5;
}
