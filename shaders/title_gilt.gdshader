shader_type canvas_item;
render_mode unshaded;
uniform float glyph_scale = 1.0;
varying float glyph_y;
void vertex() {
	glyph_y = VERTEX.y / max(glyph_scale, 0.001);
}
void fragment() {
	vec4 ink = texture(TEXTURE, UV) * COLOR;
	float t = clamp((glyph_y - 15.0) / 45.0, 0.0, 1.0);
	vec3 gilt = t < 0.42 ? mix(vec3(0.957,0.941,0.902),vec3(0.890,0.843,0.741),t/0.42) : t < 0.74 ? mix(vec3(0.890,0.843,0.741),vec3(0.761,0.671,0.514),(t-0.42)/0.32) : mix(vec3(0.761,0.671,0.514),vec3(0.616,0.522,0.361),(t-0.74)/0.26);
	COLOR = vec4(ink.rgb * gilt,ink.a);
}
