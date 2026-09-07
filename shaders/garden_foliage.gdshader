shader_type spatial;
render_mode cull_disabled;
uniform float wind = 0.4;
uniform float snow = 0.0;
uniform float wet = 0.0;
uniform bool sway = true;
varying float upward;
void vertex() {
	upward = (MODEL_NORMAL_MATRIX * NORMAL).y;
	if (sway) {
		vec3 origin = MODEL_MATRIX[3].xyz;
		float bend = max(VERTEX.y, 0.0);
		VERTEX.x += sin(TIME * 1.7 + origin.x * 1.9 + origin.z) * bend * 0.025 * wind;
	}
}
void fragment() {
	vec3 base = COLOR.rgb;
	base = mix(base, vec3(0.88, 0.94, 0.95), snow * smoothstep(0.25, 0.9, upward));
	ALBEDO = base * (1.0 - wet * 0.22);
	ROUGHNESS = 0.9 - wet * 0.3;
}
