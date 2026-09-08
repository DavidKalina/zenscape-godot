shader_type canvas_item;
render_mode unshaded;
void fragment() {
	vec2 p = UV;
	float crown = (1.0-smoothstep(0.0,0.66,p.y))*0.4;
	float desk = smoothstep(0.28,0.74,p.y)*0.72;
	float center = (1.0-smoothstep(0.0,1.0,length((p-vec2(0.5,0.64))/vec2(0.62,0.34))))*0.45;
	float foot = smoothstep(0.84,1.0,p.y)*0.3;
	float alpha = 1.0-(1.0-crown)*(1.0-desk)*(1.0-center)*(1.0-foot);
	COLOR = vec4(vec3(0.031,0.043,0.059),alpha);
}
