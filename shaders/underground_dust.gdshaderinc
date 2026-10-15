// Underground ground cover's dust: the painterly shade the grass ground has,
// for drifted dust, ash and fine sand (scripts/underground/ground_cover.gd,
// docs/design/roguelike/underground-ground-round1.md). The terrain's ground
// (ground_look zs_ground_color, `ground_dust`) and the cover skin laid on
// stone tops (shaders/underground_cover.gdshader) both call this, so the
// two read as one dust. Include after reference_wind and grass_look.
//
// It moves with the air as the meadow does: ripples lie across the wind
// and creep along it, and a pale sheen of lifted dust rolls over the ground
// on the same crests that bow the grass (zs_grass_crest), stronger in gusts.
#ifndef ZS_UNDERGROUND_DUST
#define ZS_UNDERGROUND_DUST

// The ripples' height at `p` (metres in the world's x, z), 0..1.
float zs_dust_ripple(vec2 p) {
	vec2 w = zs_wind_direction;
	float along = dot(p, w);
	float side = dot(p, vec2(-w.y, w.x));
	float warp = zs_noise(vec2(side * 0.33, along * 0.1) + zs_grass_offset * 0.2 + 9.0) * 6.0;
	float fine = zs_noise(vec2(side * 1.7, along * 0.6) + 3.0) * 1.4;
	return 0.5 + 0.5 * sin(along * 4.6 + warp + fine - zs_gust_distance * 0.09 - zs_motion_time * 0.05);
}

// `c` (linear) laid with dust at `p`, `k` 0..1 how much. Lighter where a
// dune's back faces up the ripple, paler where a gust lifts the dust, a
// little grit in it close up.
vec3 zs_dust_tone(vec3 c, vec2 p, float k) {
	// Ripples in drifts: bare and flat between, wind-ribbed where drifted.
	float drift = smoothstep(0.38, 0.72, zs_noise(p * 0.19 + zs_grass_offset * 0.6 + 31.0));
	float rip = zs_dust_ripple(p);
	c *= 1.0 + k * drift * (rip - 0.5) * 0.46;
	// The broad dune: pale lee, deep hollow, over tens of metres.
	float dune = zs_noise(p * 0.045 + zs_grass_offset * 0.3 + 71.0) - 0.5;
	c *= 1.0 + k * dune * 0.5;
	// A gust lifts the dust: a pale sheen rolling with the grass wave.
	float crest = zs_grass_crest(p, 6.5, ZS_GRASS_WAVE_SPEED, zs_grass_offset);
	float air = clamp(0.45 + zs_breeze_air() * 0.55, 0.0, 1.4);
	c = mix(c, c * vec3(1.26, 1.2, 1.1) + 0.012, crest * k * 0.55 * air);
	// Grit: fine speckle, gone where a pixel spans more than a few cm.
	float px = length(fwidth(p));
	float grit = zs_noise(p * 23.0) + zs_noise(p * 61.0) * 0.6 - 0.8;
	c *= 1.0 + k * grit * 0.2 * (1.0 - smoothstep(0.03, 0.22, px));
	return max(c, vec3(0.0));
}

#endif
