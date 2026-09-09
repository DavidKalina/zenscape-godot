// Source Lambert + GGX direct lighting. The climbing valley shadow gates only
// direct contributions, preserving hemisphere and reflected-sky afterglow.
void light() {
	float nl = max(dot(NORMAL, LIGHT), 0.0);
	float gate = zs_alpen_gate(world_position);
	vec3 energy = LIGHT_COLOR * ATTENUATION * gate * inversion_transmit;
#ifdef ZS_COMPLETE_LAKE_LIGHTING
	if (!flowing && lake_display_lighting) energy = vec3(0.0);
#endif
	DIFFUSE_LIGHT += energy * nl / PI * (1.0 - metalness_value);
#ifdef ZS_FOLIAGE_TRANSMISSION
	// Thin-sheet backscatter uses the same shadow attenuation as direct light.
	// Keep it broad across a facet and strongest when looking toward the light.
	float backlight = max(-dot(NORMAL, LIGHT), 0.0);
	float forward_scatter = pow(max(dot(-LIGHT, VIEW), 0.0), 3.0);
	DIFFUSE_LIGHT += energy * foliage_transmission * leaf_thinness * backlight
		* (0.35 + 0.65 * forward_scatter) * vec3(0.82, 1.0, 0.58) / PI;
#endif
	vec3 half_vector = normalize(LIGHT + VIEW);
	float nv = max(dot(NORMAL, VIEW), 0.0001);
	float nh = max(dot(NORMAL, half_vector), 0.0);
	float vh = max(dot(VIEW, half_vector), 0.0);
	float alpha = max(ROUGHNESS * ROUGHNESS, 0.002025);
	float a2 = alpha * alpha;
	float denominator = nh * nh * (a2 - 1.0) + 1.0;
	float distribution = a2 / (PI * denominator * denominator);
	float visibility = 0.5 / max(nl * sqrt(a2 + (1.0 - a2) * nv * nv) + nv * sqrt(a2 + (1.0 - a2) * nl * nl), 0.0001);
	vec3 f0 = mix(vec3(0.04), ALBEDO, metalness_value);
	vec3 fresnel = f0 + (1.0 - f0) * pow(1.0 - vh, 5.0);
	// Three.js has no per-light specular scale; SPECULAR_AMOUNT would halve the sheen.
	SPECULAR_LIGHT += energy * nl * distribution * visibility * fresnel;
}
