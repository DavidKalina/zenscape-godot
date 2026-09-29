shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Wind-carried sparks. Visual only: spotting lives in FireField.

// INSTANCE_CUSTOM = (seed, size, alpha, heat).
uniform float time = 0.0;
uniform float intensity = 1.0;

varying float v_seed;
varying float v_alpha;
varying float v_heat;
varying vec2 v_uv;

void vertex() {
	v_seed = INSTANCE_CUSTOM.x;
	v_alpha = INSTANCE_CUSTOM.z;
	v_heat = INSTANCE_CUSTOM.w;
	v_uv = UV;
	vec3 center = MODEL_MATRIX[3].xyz;
	MODELVIEW_MATRIX = VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],vec4(center,1.0));
	VERTEX.xy *= max(INSTANCE_CUSTOM.y,0.001)*(0.75+0.45*sin(time*13.0+v_seed*29.0));
}

void fragment() {
	// A spark cools from white-gold through orange to a deep ember red as its
	// heat falls; the hot ones carry a white core that blooms.
	float d = length(v_uv-vec2(0.5))*2.0;
	float edge = 1.0-smoothstep(0.7,1.0,d);
	float core = exp(-d*d*30.0);
	float halo = exp(-d*d*5.0)*edge;
	float heat = clamp(v_heat,0.0,1.0);
	vec3 cool = vec3(0.85,0.1,0.02);
	vec3 warm = vec3(1.0,0.42,0.06);
	vec3 hot = vec3(1.0,0.85,0.5);
	vec3 ramp = mix(mix(cool,warm,smoothstep(0.0,0.5,heat)),hot,smoothstep(0.5,1.0,heat));
	vec3 color = ramp*halo*1.3 + vec3(1.0,0.93,0.78)*core*(0.6+3.4*heat);
	ALBEDO = color*intensity;
	ALPHA = clamp(v_alpha,0.0,1.0);
}
