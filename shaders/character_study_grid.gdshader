shader_type spatial;
// The character study's greybox (studies/character_study.gd): a flat
// colour with a line every metre and a stronger one every five, in the
// world's own metres, on whichever plane a face lies most along, so
// distances read on floors, walls and ramps alike.
uniform vec4 tint : source_color = vec4(0.62, 0.62, 0.6, 1.0);
uniform float minor_dark = 0.22;
uniform float major_dark = 0.32;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float lines(vec2 p, float every, float width) {
	vec2 q = p / every;
	vec2 g = abs(fract(q - 0.5) - 0.5) / max(fwidth(q), vec2(1e-4));
	return 1.0 - clamp(min(g.x, g.y) - width + 1.0, 0.0, 1.0);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 p = n.y > max(n.x, n.z) ? world_pos.xz : (n.x > n.z ? world_pos.zy : world_pos.xy);
	float minor = lines(p, 1.0, 1.0);
	float major = lines(p, 5.0, 1.6);
	ALBEDO = tint.rgb * (1.0 - minor_dark * minor) * (1.0 - major_dark * major);
	ROUGHNESS = 0.9;
}
