shader_type spatial;
// The endless land's far spruces (scripts/endless/land_trees.gd): FarTrees'
// faceted crown, drawn plainly in its baked shade times the crown's tint,
// each instance shown only while its foot is `band` m from the eye: it
// grows up from its foot over band.x..band.x+band.y and sinks back over
// band.z-band.w..band.z (squashed to nothing outside, so its faces cull).
// One ring hands over to the next with no seam and no pop.
render_mode cull_back, diffuse_lambert, specular_disabled;
// The cheap sway with the wind where the tree stands (tree_wind.gdshaderinc).
#include "res://shaders/tree_wind.gdshaderinc"

uniform vec4 band = vec4(0.0, 1.0, 1e6, 1.0);
uniform vec4 albedo : source_color = vec4(1.0);
// How much the baked light and shade of the crown shows (0: flat albedo).
uniform float baked = 1.0;
// The crown's height in model units (its sway's reach).
uniform float sway_tall = 4.3;

varying float keep;

void vertex() {
	vec3 foot = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float d = distance(foot, CAMERA_POSITION_WORLD);
	keep = smoothstep(band.x, band.x + band.y, d) * (1.0 - smoothstep(band.z - band.w, band.z, d));
	if (keep > 0.0 && zs_tree_alive > 0.0) {
		float tall = sway_tall * length(MODEL_MATRIX[1].xyz);
		vec2 m = zs_tree_far_sway(foot.xz, clamp(VERTEX.y / sway_tall, 0.0, 1.2), tall);
		VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(m.x, 0.0, m.y);
	}
	VERTEX *= keep;
}

void fragment() {
	vec3 shade = mix(vec3(1.0), COLOR.rgb, baked);
	ALBEDO = albedo.rgb * shade;
	ROUGHNESS = 1.0;
}
