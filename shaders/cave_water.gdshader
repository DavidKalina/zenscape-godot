shader_type spatial;
render_mode cull_disabled;
uniform float frozen = 0.0;
uniform vec4 water_color : source_color = vec4(0.1,0.25,0.25,1.0);
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float ripple = sin(world.x * 8.0 + TIME * 1.3) * cos(world.z * 7.0 - TIME * 0.8);
	ALBEDO = mix(water_color.rgb + ripple * 0.018, vec3(0.56, 0.75, 0.79), frozen);
	ROUGHNESS = mix(0.2, 0.4, frozen);
	METALLIC = 0.15;
	NORMAL_MAP = vec3(0.5 + ripple * 0.035 * (1.0-frozen), 0.5, 1.0);
}
