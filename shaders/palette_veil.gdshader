shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
void fragment() {
 vec3 scene = textureLod(screen_texture, SCREEN_UV, 2.8).rgb;
 float distance_from_light = clamp(length((UV-vec2(.5,.12))*vec2(.8,1.2)),0.,1.);
 vec4 veil = mix(vec4(.47,.345,.408,.30),vec4(.086,.063,.078,.60),distance_from_light);
 COLOR = vec4(mix(scene,veil.rgb,veil.a),1.);
}
