shader_type spatial;
// The burrower's dust (scripts/burrower/burrower.gd): soft billboards in a
// MultiMesh, each instance's custom data its colour (rgb) and opacity (a).
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;

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
	float r = dot(d, d);
	float a = (1.0 - smoothstep(0.15, 1.0, r)) * v_col.a;
	ALBEDO = v_col.rgb;
	ALPHA = a;
}
