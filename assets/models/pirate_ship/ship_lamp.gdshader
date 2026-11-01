shader_type spatial;
// Written by art/blender/ship/ship_build.py: a lantern's horn pane, and its beat.
render_mode unshaded, shadows_disabled, fog_disabled;
varying float beat;
void vertex() {
	float z = round(VERTEX.z / 16.0) * 16.0;
	beat = 0.85 + 0.15 * sin(TIME * (7.0 + fract(z * 0.37 + sign(VERTEX.x)) * 5.0) + z);
}
void fragment() {
	float d = length(VERTEX);
	ALBEDO = vec3(1.0, 0.46, 0.14) * 1.5 * beat * (0.03 + 0.97 / (1.0 + d * d / 1600.0));
}
