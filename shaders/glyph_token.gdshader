shader_type spatial;
// Collectible glyph tokens (scripts/glyph_token.gd): the facets' vertex
// colours, the glyph's lines laid over the faces, a soft glow round the rim
// and a slow shine that sweeps across now and then.
render_mode cull_back;

uniform sampler2D lines : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 glow_tint : source_color = vec3(1.0, 0.9, 0.7);
// The rim's glow and the whole token's faint inner light.
uniform float glow = 0.35;
uniform float inner = 0.0;
// The shine: seconds between sweeps and its strength.
uniform float shine_every = 4.5;
uniform float shine = 0.3;

varying vec3 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec3 albedo = COLOR.rgb;
	if (all(greaterThanEqual(UV, vec2(0.0))) && all(lessThanEqual(UV, vec2(1.0)))) {
		vec4 ink = texture(lines, UV);
		albedo = mix(albedo, ink.rgb, ink.a);
	}
	ALBEDO = albedo;
	ROUGHNESS = 0.42;
	SPECULAR = 0.6;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float phase = fract(TIME / shine_every + (NODE_POSITION_WORLD.x + NODE_POSITION_WORLD.z) * 0.07);
	float sweep = (local.x + local.y) / 34.0 + 0.5;
	float band = smoothstep(0.08, 0.0, abs(sweep - phase * 2.2 + 0.6));
	EMISSION = glow_tint * (rim * glow + inner) + vec3(1.0, 0.97, 0.9) * band * shine;
}
