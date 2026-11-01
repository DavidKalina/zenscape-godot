shader_type spatial;
// A ball's wisp of powder smoke: soft discs strung behind it, each turned to the
// eye about its own centre, so it has no edge or flat side from any angle. Head on
// they stack into a pale ring round the ball. PirateShip._smoke_mesh builds them:
// every corner of a disc at its centre, UV the corner, UV2 its radius (m) and
// opacity. Unshaded, not bright: a pale gray, no glow.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;
uniform vec3 smoke = vec3(0.70, 0.71, 0.72);
varying float strength;
varying float seed;

void vertex() {
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.xy += (UV * 2.0 - 1.0) * UV2.x;
	strength = UV2.y;
	seed = UV2.x * 7.0;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	// A lumpy edge, so overlapping discs make a wisp and not a string of beads.
	float reach = 0.9 + 0.1 * sin(a * 3.0 + seed) * sin(a * 2.0 - seed * 2.0);
	float soft = 1.0 - smoothstep(0.0, reach, r);
	ALBEDO = smoke;
	ALPHA = pow(soft, 1.5) * strength;
}
