shader_type spatial;
// A gun's flash and its smoke, look only: a cluster of soft discs, each turned to
// the eye about its own centre like ball_smoke.gdshader's, so neither has an edge
// or a flat side from any angle. PirateShip._puff_mesh builds them: every corner
// of a disc at its centre, UV the corner, UV2 its radius (m) and opacity, COLOR
// its tint. The node's scale grows the cluster and the discs with it; `fade`
// (per instance) thins the whole puff. Unshaded.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;
instance uniform float fade = 1.0;
varying float strength;
varying float seed;

void vertex() {
	float sc = length(MODEL_MATRIX[0].xyz);
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.xy += (UV * 2.0 - 1.0) * UV2.x * sc;
	strength = UV2.y * fade;
	seed = UV2.x * 7.0;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float reach = 0.9 + 0.1 * sin(a * 3.0 + seed) * sin(a * 2.0 - seed * 2.0);
	float soft = 1.0 - smoothstep(0.0, reach, r);
	ALBEDO = COLOR.rgb;
	ALPHA = pow(soft, 1.3) * strength;
}
