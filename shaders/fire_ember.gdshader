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
	float halo = 1.0-smoothstep(0.0,0.5,length(v_uv-vec2(0.5)));
	vec3 color = mix(vec3(1.0,0.24,0.03),vec3(1.0,0.86,0.48),halo*halo*v_heat);
	ALBEDO = color*intensity*1.6;
	ALPHA = clamp(halo*halo*v_alpha,0.0,1.0);
}
