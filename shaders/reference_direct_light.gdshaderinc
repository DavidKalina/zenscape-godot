#include "res://shaders/clean_look.gdshaderinc"
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
		vec3 crown_sun = open_sun * mix(ZS_SPRUCE_TONE2.y, 1.0, ATTENUATION);
		float d = dot(NORMAL, LIGHT);
		float t = zs_spruce_painted_light(d, ZS_SPRUCE_LIGHT.x, ZS_SPRUCE_LIGHT.z, ZS_SPRUCE_LIGHT.w);
		DIFFUSE_LIGHT += crown_sun * t * mix(vec3(0.96, 0.99, 1.04), vec3(1.04, 1.02, 0.94), t) / PI;
		float through = pow(max(dot(-LIGHT, VIEW), 0.0), 2.0);
		DIFFUSE_LIGHT += open_sun * ZS_SPRUCE_LIGHT.y * max(-d, 0.0) * (0.3 + 0.7 * through) * vec3(0.9, 1.0, 0.85) / PI;
	} else
#endif
	// the sun in soft steps, the sun side warm (clean_look.gdshaderinc).
#ifdef ZS_GRASS_CALM
	// Grass blades (clean look round 5): the blades' own normals and their
	// neighbours' shadows would light each one differently, bright beside
	// dark. Each blade's banded sun is pulled toward the mean a blade tilted
	// out by ZS_GRASS_TILT gets round the compass (so the tuft keeps its
	// brightness and the sun's side), and the little shadows between blades
	// are softened.
	{
	float grass_calm_k = ZS_GRASS_CALM;
	if (grass_calm_k > 0.0) {
		float up_l = clamp(zs_sun_direction.y, 0.1, 1.0);
		float side_l = sqrt(max(1.0 - up_l * up_l, 0.0)) * ZS_GRASS_TILT;
		float base_l = up_l * sqrt(1.0 - ZS_GRASS_TILT * ZS_GRASS_TILT);
		float mean_b = 0.25 * (zs_clean_banded(base_l + side_l) + zs_clean_banded(base_l - side_l) + 2.0 * zs_clean_banded(base_l));
		float banded = mix(zs_clean_banded(dot(NORMAL, LIGHT)), mean_b, ZS_GRASS_PULL * grass_calm_k);
		float calm_open = mix(ATTENUATION, 1.0, ZS_GRASS_SOFT * grass_calm_k);
		vec3 calm_energy = LIGHT_COLOR * calm_open * gate * inversion_transmit;
		DIFFUSE_LIGHT += calm_energy * banded * zs_clean_sun_tint() / PI * (1.0 - metalness_value);
	} else {
		DIFFUSE_LIGHT += energy * zs_clean_banded(dot(NORMAL, LIGHT)) * zs_clean_sun_tint() / PI * (1.0 - metalness_value);
	}
	}
#else
	DIFFUSE_LIGHT += energy * zs_clean_banded(dot(NORMAL, LIGHT)) * zs_clean_sun_tint() / PI * (1.0 - metalness_value);
#endif
#ifdef ZS_LOOK_FILL
	// The look pass's sky fill (shaders/look_fill.gdshaderinc), the sun's
	// light only: where its shadow falls or the face turns from it.
	if (zs_look_fill > 0.0 && LIGHT_IS_DIRECTIONAL && dot((INV_VIEW_MATRIX * vec4(LIGHT, 0.0)).xyz, zs_key_direction) > 0.999)
	{
		vec3 fill_light = zs_look_fill_light(1.0 - ATTENUATION * gate * smoothstep(0.0, 0.2, nl)) * (1.0 - metalness_value);
#ifdef ZS_SPRUCE_LIGHT
		// A crown's fill is cancelled off its blue albedo and put back olive (gated by tone2.z).
		if (ZS_SPRUCE_LIGHT.x > 0.0 && ZS_SPRUCE_TONE2.z > 0.0) {
			float la = dot(ALBEDO, vec3(0.2126, 0.7152, 0.0722));
			vec3 ratio = vec3(1.20, 1.05, 0.22) * la / max(ALBEDO, vec3(0.03));
			fill_light *= mix(vec3(1.0), clamp(ratio, 0.0, 3.0), ZS_SPRUCE_TONE2.z);
		}
#endif
		DIFFUSE_LIGHT += fill_light;
	}
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
