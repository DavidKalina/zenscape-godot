// The wind's sheen across far grass (endless flight, docs/design/endless-
// flight/grass-sheen-handoff.md): from high above a meadow reads as a field
// of wheat, light and dark swells rolling downwind. Blades lean with the
// breeze's waves; a blade leant toward the sun (and away from the eye) shows
// its lit face, a blade leant the other way shows its shaded back, and the
// leant ones catch a warm glint. One field for the painted ground and the far
// tufts, built from the same wave crests and gust bands the near tufts sway
// to (zs_wave_crest_at, zs_gust_band_at, grass_silver's trains), so the
// swells carry on from the tufts' own with no ring. Include after
// reference_wind and grass_silver.
//
// Opt-in: `grass_sheen.x` 0 (the default) draws nothing and costs nothing.
#ifndef ZS_GRASS_SHEEN
#define ZS_GRASS_SHEEN

// x strength (0 off), y..z the ring distance (m) over which it comes in
// past the near tufts, w how much more it reads far off (at 400 m).
uniform vec4 grass_sheen = vec4(0.0, 28.0, 85.0, 0.6);
// The wave trains it rides (m between crests) and each one's share.
uniform vec3 grass_sheen_waves = vec3(14.0, 30.0, 70.0);
uniform vec3 grass_sheen_share = vec3(0.1, 0.3, 0.45);
// The long swell for high flight (m between crests) and its share.
uniform vec2 grass_sheen_long = vec2(170.0, 0.5);

// 0..1: a swell's crest at `p`: a long-crested band across the wind, rolling
// downwind on the air's travel at `speed`, its line bent by slow noise so the
// bands wander and swell like a wheat field's (zs_wave_crest_at's skewed
// second train makes diamonds from far off, so this one has none).
float zs_sheen_crest(vec2 p, float crest_length, float speed, vec2 offset, float travel) {
	vec2 dir = zs_wind_direction;
	float along = dot(p, dir);
	float side = dot(p, vec2(-dir.y, dir.x));
	float wander = (zs_noise(vec2(side, along * 0.35) / (crest_length * 1.6) + offset) - 0.5) * 7.0;
	float a = 0.5 + 0.5 * sin((along - travel * speed) * TAU / crest_length + wander);
	return smoothstep(0.2, 0.9, a);
}

// -1..1: how far the blades at `p` lean downwind of their mean, a pixel there
// `fp` m across. Each train fades to its mean as the pixel outgrows it.
float zs_sheen_field(vec2 p, float fp) {
	float travel = zs_gust_distance;
	vec4 crest = vec4(
		zs_sheen_crest(p, grass_sheen_waves.x, ZS_BREEZE_WAVE_SPEED, zs_grass_offset, travel),
		zs_sheen_crest(p, grass_sheen_waves.y, ZS_BREEZE_WAVE_SPEED, zs_grass_offset + 3.0, travel),
		zs_sheen_crest(p * 0.97 + 50.0, grass_sheen_waves.z, ZS_BREEZE_WAVE_SPEED * 1.3, zs_grass_offset + 7.0, travel),
		zs_sheen_crest(p * 0.93 - 31.0, grass_sheen_long.x, ZS_BREEZE_WAVE_SPEED * 1.15, zs_grass_offset + 19.0, travel));
	vec4 lens = vec4(grass_sheen_waves, grass_sheen_long.x);
	vec4 keep = vec4(1.0) - smoothstep(lens * 0.08, lens * 0.3, vec4(fp));
	crest = mix(vec4(0.42), crest, keep);
	vec4 share = vec4(grass_sheen_share, grass_sheen_long.y);
	float w = dot(crest - vec4(0.42), share) / dot(share, vec4(1.0));
	// The gust bands swell and calm it with the breeze; a gust front lays the
	// blades hard downwind.
	float band = zs_gust_band_at(p, travel);
	float air = clamp(zs_breeze_air() / 0.53, 0.35, 1.6);
	float s = w * 3.0 * band * air + zs_front_at(p, 0.0) * 1.2;
	return clamp(s, -1.0, 1.0);
}

// The tone (a multiplier on the grass's colour) for lean `s` at `p`, seen
// from `eye` (world), `d` m along the ground from the eye's ring, with the
// key light's colour `key`.
vec3 zs_sheen_tone(float s, vec2 p, vec3 eye, float d, vec3 key) {
	vec2 w = zs_wind_direction;
	vec3 to_eye = eye - vec3(p.x, 0.0, p.y);
	float eye_flat = length(to_eye.xz);
	vec2 eye_h = to_eye.xz / max(eye_flat, 0.001);
	// How much the eye looks along the ground (a view straight down has none).
	float eye_w = clamp(eye_flat / max(length(to_eye), 0.001) * 1.4, 0.0, 1.0);
	vec2 sun_h = zs_sun_direction.xz / max(length(zs_sun_direction.xz), 0.001);
	float sun_w = clamp(1.0 - zs_sun_direction.y * 0.9, 0.0, 1.0);
	// Leant toward the sun: its lit face; leant away from the eye: the face to it.
	float turn = clamp(dot(w, sun_h) * sun_w - dot(w, eye_h) * eye_w * 0.8, -1.0, 1.0);
	float reach = 1.0 + grass_sheen.w * smoothstep(80.0, 400.0, d);
	float amount = grass_sheen.x * reach;
	float lit = s * (0.5 + 0.5 * turn);
	// Crests: the whole swell lighter, the troughs deeper; the turn decides
	// which face the eye gets.
	vec3 tone = vec3(1.0 + amount * (0.30 * s + 0.40 * lit));
	// The warm glint on the leant ones, in the key light's colour.
	float glint = max(s, 0.0) * (0.35 + 0.65 * max(turn, 0.0));
	vec3 tint = mix(vec3(1.0), key / max(max(key.r, max(key.g, key.b)), 0.001), 0.8);
	tone *= mix(vec3(1.0), tint * vec3(1.18, 1.1, 0.9), clamp(glint * amount * 0.55, 0.0, 0.8));
	return max(tone, vec3(0.4));
}
#endif
