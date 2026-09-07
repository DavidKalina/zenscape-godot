// Source daynight.js/weather.js altitude shadow and post-sunset reflected light.
float zs_alpen_gate(vec3 p) {
	float band = max(0.8, 0.08 * (zs_summit.y - 0.15));
	float line = mix(0.15 - band, zs_summit.y + band, zs_alpen.y)
		+ (zs_noise(p.xz * 0.16 + 3.0) - 0.5) * band * 0.9;
	return mix(1.0, smoothstep(line - band * 0.45, line + band * 0.45, p.y), zs_alpen.x);
}
vec3 zs_afterglow(vec3 p, vec3 normal, vec3 albedo) {
	float height = clamp((p.y - 0.15) / max(zs_summit.y - 0.15, 0.001), 0.0, 1.0);
	float face = 0.40 + 0.60 * clamp(dot(normal, zs_alpen_direction), 0.0, 1.0);
	vec3 color = mix(albedo, vec3(dot(albedo, vec3(0.30, 0.55, 0.15))), 0.6);
	return color * vec3(1.0, 0.42, 0.40) * smoothstep(0.35, 0.92, height) * face * zs_alpen.z;
}
