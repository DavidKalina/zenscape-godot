shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
void fragment() {
	vec3 backdrop = textureLod(screen_texture, SCREEN_UV, 1.5).rgb;
	COLOR.rgb = mix(backdrop, COLOR.rgb, 0.78);
}
