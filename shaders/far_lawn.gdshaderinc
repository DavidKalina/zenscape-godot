// Far grass as a fine lawn (clean look round 8): past the real tufts the
// meadow is drawn as a grain of tiny blades, as if the grass were cut to a
// millimetre and seen from above: a texture baked from the game's own tuft
// (tools/bake_turf.gd, assets/textures/far_turf.png) laid on the ground twice
// at two scales and turns, so it never repeats, with
//  - micro shadows: each blade shades the grain on its side away from the sun
//    (a second sample toward the sun, darker where the neighbour stands higher),
//  - gaps dark and cool, tips lighter, in round 6's near-grass mass,
//  - nap: the grass leans with the wind and its shade depends on the view
//    against that lean (lighter looking along it, darker against it, and a soft
//    sheen along it); gusts (zs_sheen_field, the near tufts' waves, gust bands
//    and fronts) turn and flatten it, so light and dark bands roll over the
//    meadow in step with the tufts' sway.
// Texture only: the surface stays flat. Include after grass_sheen.
#ifndef ZS_FAR_LAWN
#define ZS_FAR_LAWN

// x strength (0 off), y..z the ring distance (m) it comes in over (the far
// ring's tufts thin out over about 150..230), w the nap's share.
uniform vec4 grass_lawn = vec4(0.0, 140.0, 230.0, 1.0);
// The two scales: metres one tile of the texture covers.
uniform vec2 grass_lawn_tiles = vec2(64.0, 39.0);
// R shade, G height, BA the blade's lean on the ground (0.5 + 0.5 v).
uniform sampler2D grass_lawn_tex : filter_linear_mipmap_anisotropic, repeat_enable;

const float ZS_LAWN_TEXELS = 1024.0;

mat2 zs_lawn_turn(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat2(vec2(c, s), vec2(-s, c));
}

// The grass colour `g` as a lawn. `view` the unit ray from the eye to the
// point, `fp` the pixel's footprint (m), `s` the sheen's lean (-1..1,
// zs_sheen_field), `key` the key light's colour, `warm`/`cool` the clean
// look's tints. `on` 0..1 how much.
vec3 zs_far_lawn(vec3 g, vec2 p, vec3 view, float fp, float s, vec3 key, vec3 warm, vec3 cool, float on) {
	vec2 sun_h = zs_sun_direction.xz / max(length(zs_sun_direction.xz), 0.001);
	float sun_up = clamp(zs_sun_direction.y, 0.0, 1.0);
	float day = clamp(sun_up * 4.0, 0.0, 1.0);
	// Lower sun, longer shadows (in texels).
	float reach = 2.0 + 3.5 * (1.0 - sun_up);
	vec3 tint = mix(vec3(1.0), key / max(max(key.r, max(key.g, key.b)), 0.001), 0.8);

	// The nap: the wind's way, turned by the gust's lean (up to ~50 degrees),
	// the more laid down the harder it leans.
	// (The lawn takes the field a little harder than the tufts' tone does.)
	s = clamp(s * 1.7, -1.0, 1.0);
	float lay = clamp(0.5 + 0.5 * s, 0.0, 1.0);
	vec2 lean_dir = zs_lawn_turn(s * 0.9) * zs_wind_direction;
	float vlen = length(view.xz);
	vec2 vh = view.xz / max(vlen, 0.12);
	float seen = smoothstep(0.0, 0.3, vlen);

	float r_sum = 0.0;
	float h_sum = 0.0;
	float shadow = 0.0;
	float nap = 0.0;
	vec2 lean_sum = vec2(0.0);
	vec2 tiles = grass_lawn_tiles;
	for (int i = 0; i < 2; i++) {
		float tile = tiles[i];
		mat2 turn = zs_lawn_turn(0.83 * float(i));
		vec2 uv = turn * p / tile + vec2(0.31, 0.57) * float(i);
		vec4 t = texture(grass_lawn_tex, uv);
		vec2 off = turn * sun_h * (reach / ZS_LAWN_TEXELS);
		float h_sun = texture(grass_lawn_tex, uv + off).g;
		r_sum += t.r;
		h_sum += t.g;
		shadow += clamp((h_sun - t.g) * 3.5, 0.0, 1.0);
		// This blade's lean, back in the world (the texture's turn undone).
		vec2 bl = (t.ba * 2.0 - 1.0) * turn;
		lean_sum += bl;
		nap += dot(normalize(lean_dir + bl * 0.9), vh);
	}
	// Two independent grains, their sum rescaled to one grain's spread.
	float grain = (r_sum - 1.0) * 0.7071;
	float hgt = 0.5 + (h_sum - 1.0) * 0.7071;
	shadow *= 0.5 * day;
	nap *= 0.5;

	// The grain: blade colour, gaps dark and cool, tips lighter and warmer.
	float gap = 1.0 - smoothstep(0.12, 0.5, hgt);
	float tip = smoothstep(0.5, 0.95, hgt);
	// (Lifted while the grain is seen: its gaps and shadows take more than the
	// tips give; far off the mips are its mean and the mean is already right.)
	float seen_grain = 1.0 - smoothstep(0.15, 1.3, fp);
	vec3 mul = vec3((1.0 + 0.85 * grain) * mix(1.0, 1.17, seen_grain));
	mul *= mix(vec3(1.0), cool * vec3(0.85), gap * 0.5);
	mul *= mix(vec3(1.0), tint * vec3(1.1, 1.08, 0.95), tip * 0.5);
	// The micro shadows: darker and cooler on the side away from the sun.
	mul *= mix(vec3(1.0), cool * vec3(0.9), shadow * 0.5) * (1.0 - 0.3 * shadow);
	// The nap: lighter looking along the lean, darker against, more so where
	// the gust has laid the grass down.
	float nap_k = grass_lawn.w * seen * (0.35 + 0.65 * lay);
	// (Against the nap it darkens in full; along it, half as much lighter, so a
	// meadow does not brighten as a whole when you fly downwind.)
	mul *= 1.0 + 0.3 * (nap > 0.0 ? nap * 0.45 : nap) * nap_k;
	// A soft sheen along the lean (a blade's highlight runs across it).
	vec3 T = normalize(vec3(lean_dir.x, 1.3 - 0.8 * lay, lean_dir.y));
	vec3 H = normalize(zs_sun_direction - view);
	float kk = sqrt(max(1.0 - pow(dot(T, H), 2.0), 0.0));
	float sheen = pow(kk, 20.0) * day * (0.25 + 0.75 * clamp(hgt * 1.4, 0.0, 1.0));
	mul *= 1.0 + tint * vec3(1.0, 1.0, 0.8) * sheen * 0.12 * grass_lawn.w * (0.5 + 0.5 * lay);
	vec3 out_c = g * mul;
	return mix(g, out_c, on * grass_lawn.x);
}
#endif
