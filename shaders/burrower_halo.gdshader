shader_type spatial;
// A push-up orb's glow (scripts/burrower/push_ups.gd): a soft additive
// billboard round the orb, its colour and strength the instance's custom
// data (rgb, a), its size the instance's scale.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

varying vec4 v_col;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 c = MODEL_MATRIX[3].xyz;
	vec3 w = c + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * s;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
	v_col = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	// A bright rim close in, a long soft falloff out.
	float a = pow(max(1.0 - r, 0.0), 2.2) * 0.8 + exp(-r * r * 30.0) * 0.6;
	ALBEDO = v_col.rgb * a * v_col.a;
}
