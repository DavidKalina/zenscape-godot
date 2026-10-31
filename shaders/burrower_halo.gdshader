shader_type spatial;
// A push-up orb's glow (scripts/burrower/push_ups.gd): a soft additive
// billboard round the orb, its colour and strength the instance's custom
// data (rgb, a), its size the instance's scale (y its height: an orb on the
// move draws its glow out). No fog: fog added over an
// additive quad lit its whole square (a faint square over the pond).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying vec4 v_col;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 c = MODEL_MATRIX[3].xyz;
	float tall = length(MODEL_MATRIX[1].xyz);
	vec3 w = c + INV_VIEW_MATRIX[0].xyz * VERTEX.x * s + INV_VIEW_MATRIX[1].xyz * VERTEX.y * tall;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
	v_col = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	// A bright rim close in, a long soft falloff out.
	float a = pow(max(1.0 - r, 0.0), 2.2) * 0.8 + exp(-r * r * 30.0) * 0.6;
	a = max(a, 0.0);
	// Soft where the quad meets the ground (no straight cut through it).
	float z = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 wp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z, 1.0);
	float behind = -wp.z / wp.w - (-VERTEX.z);
	a *= clamp(behind / 2.0, 0.0, 1.0);
	ALBEDO = v_col.rgb * a * v_col.a;
}
