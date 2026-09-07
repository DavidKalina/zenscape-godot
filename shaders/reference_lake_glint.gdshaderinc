// Source water.js broad sun/moon reflection paths. RGB is display-space;
// alpha is the source mix weight, independent of material transparency.
vec4 zs_lake_glint(vec3 reflected, vec3 sun, vec3 moon, float clear, float ice, float enabled) {
	if (enabled <= 0.0 || ice >= 0.99) return vec4(0.0);
	float sunlight = smoothstep(-0.03, 0.12, sun.y);
	vec3 light_dir = sunlight > 0.01 ? sun : moon;
	float facing = max(dot(reflected, light_dir), 0.0);
	float shine = pow(facing, 96.0);
	float broad = pow(facing, 12.0) * 0.06;
	vec3 warm = mix(vec3(1.0, 0.47, 0.18), vec3(1.0, 0.96, 0.82), smoothstep(0.02, 0.55, sun.y));
	vec3 color = mix(vec3(0.38, 0.57, 0.85), warm, sunlight);
	float weight = (shine * 0.62 + broad) * clear * clear
		* mix(0.32, 1.0, sunlight) * (1.0 - ice) * enabled;
	return vec4(color, weight);
}
