// Complete directional contribution for the unshadowed source lake. Irradiance
// includes the same light energy convention as native LIGHT_COLOR.
vec3 zs_lake_direct(vec3 body, vec3 normal, vec3 eye, vec3 direction, vec3 energy, float roughness) {
	float nl = max(dot(normal, direction), 0.0);
	vec3 half_vector = normalize(direction + eye);
	float nv = max(dot(normal, eye), 0.0001);
	float nh = max(dot(normal, half_vector), 0.0);
	float vh = max(dot(eye, half_vector), 0.0);
	float a = max(roughness * roughness, 0.002025);
	float a2 = a * a;
	float denominator = nh * nh * (a2 - 1.0) + 1.0;
	float distribution = a2 / (PI * denominator * denominator);
	float visibility = 0.5 / max(nl * sqrt(a2 + (1.0 - a2) * nv * nv) + nv * sqrt(a2 + (1.0 - a2) * nl * nl), 0.0001);
	vec3 fresnel = vec3(0.04) + vec3(0.96) * pow(1.0 - vh, 5.0);
	return energy * nl * (body / PI + distribution * visibility * fresnel);
}

// Source weather.js boltLight: color d8e8ff, intensity 900 * flash,
// cutoff 160, decay 1.6. Three's physical point attenuation closes smoothly
// at the cutoff and clamps its denominator near the light.
vec3 zs_lake_flash(vec3 body, vec3 normal, vec3 eye, vec3 position, float roughness, vec4 flash) {
	if (flash.w <= 0.0) return vec3(0.0);
	vec3 offset = flash.xyz - position;
	float distance = length(offset);
	float cutoff = max(1.0 - pow(distance / 160.0, 4.0), 0.0);
	float attenuation = cutoff * cutoff / max(pow(distance, 1.6), 0.01);
	vec3 energy = vec3(0.6866853124, 0.8069522577, 1.0) * (900.0 * flash.w * attenuation);
	return zs_lake_direct(body, normal, eye, offset / max(distance, 0.0001), energy, roughness);
}

// lake-ice.js adds this lobe to outgoing linear light before tone mapping.
// Only the primary weather-modulated directional light contributes.
vec3 zs_lake_ice_highlight(vec3 normal, vec3 eye, vec3 direction, vec3 energy, vec3 ice_state) {
	float nh = max(dot(normal, normalize(eye + direction)), 0.0);
	float nl = max(dot(normal, direction), 0.0);
	float nv = max(dot(normal, eye), 0.0);
	float fresnel = 0.025 + 0.975 * pow(1.0 - nv, 5.0);
	float gloss = mix(32.0, 420.0, ice_state.y);
	float lobe = (gloss + 2.0) / 8.0 * pow(nh, gloss);
	return energy * lobe * nl * fresnel * (1.0 - ice_state.z) * ice_state.x;
}
