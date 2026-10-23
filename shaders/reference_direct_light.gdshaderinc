// Source Lambert + GGX direct lighting. The climbing valley shadow gates only
// direct contributions, preserving hemisphere and reflected-sky afterglow.
void light() {
	float nl = max(dot(NORMAL, LIGHT), 0.0);
	float gate = zs_alpen_gate(world_position);
	vec3 energy = LIGHT_COLOR * ATTENUATION * gate * inversion_transmit;
#ifdef ZS_COMPLETE_LAKE_LIGHTING
	if (!flowing && lake_display_lighting) energy = vec3(0.0);
#endif
#ifdef ZS_SPRUCE_LIGHT
	// The sprays spruce (shaders/spruce_paint.gdshaderinc): the rock's
	// painted steps over a wrapped term, and a soft glow through a crown
	// seen against the sun; off at x = 0.
	if (ZS_SPRUCE_LIGHT.x > 0.0) {
		// The crown is porous: its own shadow (the proxy cone's) takes only
		// part of the sun, so a backlit crown has no hard dark half.
		vec3 open_sun = LIGHT_COLOR * gate * inversion_transmit;
		vec3 crown_sun = open_sun * mix(0.5, 1.0, ATTENUATION);
		float d = dot(NORMAL, LIGHT);
		float t = zs_spruce_painted_light(d, ZS_SPRUCE_LIGHT.x);
		DIFFUSE_LIGHT += crown_sun * t * mix(vec3(0.96, 0.99, 1.04), vec3(1.04, 1.02, 0.94), t) / PI;
		float through = pow(max(dot(-LIGHT, VIEW), 0.0), 2.0);
		DIFFUSE_LIGHT += open_sun * ZS_SPRUCE_LIGHT.y * max(-d, 0.0) * (0.3 + 0.7 * through) * vec3(0.9, 1.0, 0.85) / PI;
	} else
#endif
	DIFFUSE_LIGHT += energy * nl / PI * (1.0 - metalness_value);
#ifdef ZS_LOOK_FILL
	// The look pass's sky fill (shaders/look_fill.gdshaderinc), the sun's
	// light only: where its shadow falls or the face turns from it.
	if (zs_look_fill > 0.0 && LIGHT_IS_DIRECTIONAL && dot((INV_VIEW_MATRIX * vec4(LIGHT, 0.0)).xyz, zs_key_direction) > 0.999)
		DIFFUSE_LIGHT += zs_look_fill_light(1.0 - ATTENUATION * gate * smoothstep(0.0, 0.2, nl)) * (1.0 - metalness_value);
#endif
#ifdef ZS_FOLIAGE_TRANSMISSION
	// Thin-sheet backscatter uses the same shadow attenuation as direct light.
	// Keep it broad across a facet and strongest when looking toward the light.
	float backlight = max(-dot(NORMAL, LIGHT), 0.0);
	float forward_scatter = pow(max(dot(-LIGHT, VIEW), 0.0), 3.0);
	DIFFUSE_LIGHT += energy * foliage_transmission * backlight
		* (0.35 + 0.65 * forward_scatter) * vec3(0.82, 1.0, 0.58) / PI;
#endif
#ifdef ZS_GRASS_TRANSLUCENCY
	// Grass lights as a mass (shaders/grass_look.gdshaderinc), so the sheet
	// backscatter above never sees a back face; its tips glow toward the sun
	// instead. The shader names its tip fraction and strength.
	if (ZS_GRASS_GLOW > 0.0) DIFFUSE_LIGHT += energy * zs_grass_translucency(LIGHT, VIEW, ALBEDO, ZS_GRASS_ALONG, ZS_GRASS_GLOW);
#endif
#ifdef ZS_FLOWER_TRANSLUCENCY
	// Petals glow their own colour when backlit (shaders/meadow_flower.gdshaderinc).
	if (ZS_FLOWER_GLOW > 0.0) DIFFUSE_LIGHT += energy * zs_flower_translucency(LIGHT, VIEW, NORMAL, ALBEDO, ZS_FLOWER_SHARE, ZS_FLOWER_GLOW);
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
