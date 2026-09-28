shader_type spatial;
render_mode cull_disabled, specular_disabled;
// The seed handful's pieces (scripts/seed_handful.gd): winged seeds, the
// sprouts that pop up where they take, and puffs of dust. Faceted meshes lit
// as the scene is; vertex colour × instance colour is the albedo. The alpha
// is a glow: how much a face shines of its own (the seed's wings), so a cloud
// of seeds reads as specks of light at the diorama's distance.
varying float glow;

void vertex() {
	glow = COLOR.a;
}

void fragment() {
	// Two-sided wings and leaves: light the face the camera sees.
	if (!FRONT_FACING) NORMAL = -NORMAL;
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
	EMISSION = COLOR.rgb * glow;
}
