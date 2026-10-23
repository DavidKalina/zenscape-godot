shader_type spatial;
// A songbird (scripts/songbird_body.gd, docs/scenic/songbirds.md). Smooth and
// vertex-coloured. On a perch it rides its limb: the wood's own breeze lean
// and wind-tool perch_bend (reference_surface's trunk path, `blow_enabled` without
// `sway_enabled`) are evaluated at the perch point in the tree's mesh space,
// so the bird moves exactly as the branch under its feet does.
#include "res://shaders/reference_wind.gdshaderinc"
render_mode diffuse_lambert, specular_schlick_ggx;
// Uniforms are prefixed: the wind functions' own locals (`bend`, ...) would
// otherwise resolve to them.

// The tree instance's transform (mesh space to world), as columns.
uniform vec4 perch_tree_x = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 perch_tree_y = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 perch_tree_z = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 perch_tree_o = vec4(0.0, 0.0, 0.0, 1.0);
// The perch in the tree's mesh space (xyz), and how much the bird rides it (w).
uniform vec4 perch_ride = vec4(0.0, 0.0, 0.0, 0.0);
// The wood's bend shape (blow_shape: bend from, height), in mesh units.
uniform vec2 perch_bend = vec2(0.4, 2.4);
uniform float bird_roughness = 0.92;

void vertex() {
	if (perch_ride.w > 0.0001) {
		mat4 tree = mat4(vec4(perch_tree_x.xyz, 0.0), vec4(perch_tree_y.xyz, 0.0), vec4(perch_tree_z.xyz, 0.0), vec4(perch_tree_o.xyz, 1.0));
		vec3 p = perch_ride.xyz;
		float gust;
		float bow;
		vec3 q = p + zs_breeze_bend(p, tree, perch_bend.x, perch_bend.y, 1.0, 0.0, gust, bow);
		float shiver;
		q += zs_blow_bend(q, tree, perch_bend.x, perch_bend.y, shiver);
		vec3 moved = mat3(tree) * (q - p) * perch_ride.w;
		VERTEX += inverse(mat3(MODEL_MATRIX)) * moved;
	}
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = bird_roughness;
}
