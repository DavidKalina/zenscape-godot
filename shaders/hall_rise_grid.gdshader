shader_type spatial;
// The hall rise's greybox stone (scripts/hall_rise.gd): the
// character study's grid (shaders/character_study_grid.gdshader), drawn
// where the chunk will stand (`offset`: how far it is from its place, set
// while it moves), so the lines ride with a rising chunk and, settled, are
// the in-world hall's own world-metre grid.
uniform vec4 tint : source_color = vec4(0.62, 0.62, 0.6, 1.0);
uniform float minor_dark = 0.22;
uniform float major_dark = 0.32;
instance uniform vec3 offset = vec3(0.0);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - offset;
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
