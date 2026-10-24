shader_type spatial;
// The tunnels' ferns (scripts/endless/land_tunnels.gd `_build_growth`):
// UndergrowthMesh's fern (UV.y along a frond) in `tint`, lighter to the
// tips, swaying a little; torch lit only, a little light through, a faint
// fill.
render_mode cull_disabled, ambient_light_disabled, fog_disabled, diffuse_burley;
uniform vec3 tint : source_color = vec3(0.1, 0.2, 0.05);
varying float along;
void vertex() {
	along = UV.y;
	float ph = INSTANCE_CUSTOM.x * 6.2831;
	VERTEX.xz += vec2(sin(TIME * 0.7 + ph), cos(TIME * 0.55 + ph)) * 0.035 * UV.y * UV.y;
}
void fragment() {
	ALBEDO = tint * COLOR.rgb * 2.2 * mix(0.45, 1.15, along);
	ROUGHNESS = 0.75;
	BACKLIGHT = vec3(0.18, 0.3, 0.06);
	EMISSION = ALBEDO * 0.22;
}
