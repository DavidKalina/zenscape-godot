shader_type canvas_item;
render_mode unshaded;

// Mipmap filtering softens the landscape behind the stone; a feathered signed
// distance mask gives the floating panel a quiet halo without blurring text.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec2 panel_size = vec2(968.0,164.0);

void fragment() {
	vec2 p = (UV-0.5)*panel_size;
	vec2 half_size = panel_size*0.5-vec2(14.0);
	float radius = 22.0;
	vec2 q = abs(p)-half_size+vec2(radius);
	float distance = length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-radius;
	float mask = 1.0-smoothstep(-1.0,9.0,distance);
	vec3 blurred = textureLod(screen_texture,SCREEN_UV,3.0).rgb;
	vec3 stone = mix(blurred,vec3(0.27,0.21,0.26),0.36);
	COLOR = vec4(stone,mask*0.88);
}
