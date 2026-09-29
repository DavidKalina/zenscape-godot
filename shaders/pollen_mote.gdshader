shader_type spatial;
render_mode cull_disabled, specular_disabled;
// The sprouts that pop up where the pollen cloud's seeds could take
// (scripts/pollen_cloud.gd; its motes are shaders/pollen_speck.gdshader). Faceted
// meshes lit as the scene is; vertex colour × instance colour is the albedo.
// The alpha is a glow: how much a face shines of its own, so the fluff glints
// as specks of light at the diorama's distance.
varying float glow;

void vertex() {
	glow = COLOR.a;
}

void fragment() {
	// Two-sided leaves: light the face the camera sees.
	if (!FRONT_FACING) NORMAL = -NORMAL;
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
	EMISSION = COLOR.rgb * glow;
}
