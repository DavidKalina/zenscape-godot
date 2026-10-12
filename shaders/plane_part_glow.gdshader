shader_type spatial;
// The glow over a found plane part (scripts/plane_parts.gd, the hovering
// "piece"), drawn over its own paint as a material overlay: a warm soft rim
// where its faces turn away, a faint wash of light at night, and a slow
// shine that sweeps across it now and then, as over the glyph tokens.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.82, 0.52);
// The rim's glow and the whole piece's faint inner light.
uniform float glow = 0.5;
uniform float inner = 0.0;
// The part's size (m), so the shine crosses it once whatever its size.
uniform float reach = 1.0;
// The shine: seconds between sweeps and its strength.
uniform float shine_every = 4.5;
uniform float shine = 0.22;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	vec3 rel = world - NODE_POSITION_WORLD;
	float phase = fract(TIME / shine_every + (NODE_POSITION_WORLD.x + NODE_POSITION_WORLD.z) * 0.07);
	float sweep = (rel.x + rel.y) / (2.8 * reach) + 0.5;
	float band = smoothstep(0.08, 0.0, abs(sweep - phase * 2.2 + 0.6));
	ALBEDO = tint * (rim * glow + inner) + vec3(1.0, 0.97, 0.9) * band * shine;
}
