shader_type spatial;
render_mode cull_back, specular_schlick_ggx;
// A sky islet's pond (scripts/sky_islet.gd `build_water`): small and seen
// in passing, so no planar reflection or bed sampling as the plate's water
// has. A dark, glassy tarn: deep slate-blue looking down, the sky's pale
// blue at a glance, a slow ripple, and a sharp sun glint.
global uniform vec3 zs_palette_water;
global uniform float zs_flow_time;
uniform vec3 deep_color : source_color = vec3(0.16, 0.25, 0.32);
uniform vec3 sky_color : source_color = vec3(0.62, 0.75, 0.86);
uniform float ripple = 0.035;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 p = world_position;
	float t = zs_flow_time;
	vec3 n = normalize(vec3(
		ripple * (sin(p.x * 2.3 + t * 0.8) + 0.6 * sin(p.z * 3.7 - p.x * 1.1 - t * 1.1)),
		1.0,
		ripple * (cos(p.z * 2.1 + t * 0.7) + 0.6 * cos(p.x * 3.3 + p.z * 0.9 + t * 0.9))));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(deep_color, sky_color, fresnel) * zs_palette_water;
	ROUGHNESS = 0.05;
	SPECULAR = 0.7;
	METALLIC = 0.0;
}
