shader_type canvas_item;
render_mode unshaded;
varying float glyph_y;
void vertex() {
	glyph_y = VERTEX.y;
}
void fragment() {
	vec4 ink = texture(TEXTURE, UV) * COLOR;
	float t = clamp((glyph_y - 15.0) / 45.0, 0.0, 1.0);
	vec3 gilt = mix(vec3(0.957,0.941,0.902),vec3(0.616,0.522,0.361),t);
	COLOR = vec4(ink.rgb * gilt,ink.a);
}
