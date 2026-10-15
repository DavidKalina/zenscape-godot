shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// The sun-mirror's disc (scripts/city_kit_light2.gd): polished black
// obsidian, slightly concave, spotless. No reflection pass: a fake
// environment (the haze above, the dark below, by the view's angle) and a
// Fresnel rim, with the shaft's ghost in it while light falls on it. Fed,
// it is a white-hot coin: a bright core spreading from its middle (`lit`).
// UV is the disc's own (0.5, 0.5 its middle, its rim at radius 0.5).

uniform vec3 stone : source_color = vec3(0.025, 0.024, 0.028);
uniform vec3 sky : source_color = vec3(0.32, 0.27, 0.22);
uniform vec3 ground : source_color = vec3(0.03, 0.025, 0.02);
uniform vec3 hot : source_color = vec3(1.0, 0.95, 0.82);
uniform float lit : hint_range(0.0, 1.0) = 0.0;
uniform float hot_energy = 5.0;

void fragment() {
	vec2 c = UV - vec2(0.5);
	float r = length(c) * 2.0;
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float fres = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 4.0);
	// The fake environment: the reflected view's up share picks haze or dark.
	vec3 refl = reflect(-v, n);
	vec3 world_refl = (INV_VIEW_MATRIX * vec4(refl, 0.0)).xyz;
	vec3 env = mix(ground, sky, smoothstep(-0.2, 0.6, world_refl.y));
	ALBEDO = stone;
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	METALLIC = 0.0;
	float coin = smoothstep(1.0, 0.15, r);
	EMISSION = env * (0.12 + 0.5 * fres) + hot * hot_energy * lit * (coin * coin + 0.25 * coin);
}
