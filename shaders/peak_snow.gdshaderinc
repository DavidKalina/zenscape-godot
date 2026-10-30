#ifndef ZS_PEAK_SNOW
#define ZS_PEAK_SNOW
// The Peak's snow (scripts/endless/peak_snow.gd): a surface of its own,
// outside the rock shader's direction buckets and tones. Included by
// shaders/endless_ground.gdshader after grass_react (zs_react_at) and
// reference_wind (zs_noise). Only the Peak's zone reads it (`psnow_on` and
// peak_paint's zone); the land's other snowcaps never get here.
//
// The shape is a height field given by its gradient, in world xz, at four
// bands, each gone by the time a pixel outgrows it, so detail shrinks with
// distance and far snow is the near snow's mean:
//   drifts    70..210 m  long, wind-laid dunes; what reads from 500 m
//   sastrugi  5..25 m    sharp ridges along the wind, where it scours
//   ripples   0.6..1.4 m crests across the wind, in patches
//   grain     0.15 m     the surface's tooth, only under the eye
// Steep snow has no wind lines; it runs in flutes down the fall line.
//
// It answers the plane twice. zs_react_at is the wash as it lands (the grass's
// push map: the surface stirred and paling for a few seconds). The furrow
// map (`psnow_furrow`, drawn by peak_snow.gd) is what stays: r the height
// (-1 the groove's floor, over 0 its thrown lip), g how churned; both fade
// as the wind fills it in.

uniform float psnow_on = 0.0;
// The way the wind that carved it blows (xz, unit); not the day's breeze.
uniform vec2 psnow_wind = vec2(0.82, 0.57);
uniform sampler2D psnow_furrow : filter_linear, repeat_disable;
// The furrow map's min x, min z, size (m), and 1 while it holds anything.
uniform vec4 psnow_furrow_rect = vec4(0.0);

// The groove's depth (m) at full strength, for its slopes.
const float PSNOW_DEPTH = 1.1;
// The tones: shaded and sunlit albedo, and the sky's fill on snow, which is
// what shows in the shade: blue.
const vec3 PSNOW_COOL = vec3(0.72, 0.80, 0.95);
const vec3 PSNOW_WARM = vec3(0.90, 0.87, 0.82);
const vec3 PSNOW_FILL = vec3(1.0, 1.12, 1.34);
// How much of the sun's own colour the snow takes out of itself, so a warm
// morning leaves it white with a warm edge rather than the colour of sand.
const float PSNOW_BALANCE = 0.62;

// Value noise with its gradient: x the value (0..1), yz d/dp.
vec3 psnow_nd(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	vec2 du = 6.0 * f * (1.0 - f);
	float a = zs_noise_hash(i);
	float b = zs_noise_hash(i + vec2(1.0, 0.0));
	float c = zs_noise_hash(i + vec2(0.0, 1.0));
	float d = zs_noise_hash(i + vec2(1.0, 1.0));
	float k = a - b - c + d;
	return vec3(a + (b - a) * u.x + (c - a) * u.y + k * u.x * u.y,
		du.x * (b - a + k * u.y), du.y * (c - a + k * u.x));
}

// How much of a band `scale` m long survives a pixel `fp` m wide.
float psnow_keep(float scale, float fp) {
	return 1.0 - smoothstep(scale * 0.10, scale * 0.42, fp);
}

// The furrow map at world xz: x height, y churn. Zero off the map.
vec2 psnow_furrow_at(vec2 xz) {
	vec2 uv = (xz - psnow_furrow_rect.xy) / psnow_furrow_rect.z;
	if (uv.x <= 0.0 || uv.y <= 0.0 || uv.x >= 1.0 || uv.y >= 1.0) return vec2(0.0);
	vec2 rim = min(uv, 1.0 - uv);
	return textureLod(psnow_furrow, uv, 0.0).rg * smoothstep(0.0, 0.05, min(rim.x, rim.y));
}

// Sparkle: a facet per cell (a little over a pixel, never under `PSNOW_FACET`)
// flashes when it stands between the sun and the eye. Stronger the lower the
// sun, gone as the pixel outgrows a sparkle.
float psnow_glitter(vec2 q, vec3 n, vec3 eye, float fp) {
	if (fp > 0.7) return 0.0;
	float size = max(0.035, fp * 1.5);
	vec2 c = floor(q / size);
	vec3 r = vec3(zs_noise_hash(c), zs_noise_hash(c + 17.3), zs_noise_hash(c + 41.7)) * 2.0 - 1.0;
	vec3 facet = normalize(n + r * 0.5);
	vec3 h = normalize(zs_sun_direction + eye);
	float flash = smoothstep(0.9965, 0.9992, dot(facet, h));
	if (flash <= 0.0) return 0.0;
	float dot_in = 1.0 - smoothstep(0.15, 0.5, length(q / size - c - 0.5));
	float low = mix(0.45, 1.5, 1.0 - smoothstep(0.08, 0.65, zs_sun_direction.y));
	return flash * dot_in * low * 11.0 * (1.0 - smoothstep(0.25, 0.7, fp));
}

// The snow's albedo at `p`. `q` the sheared paint point (gxz), `n` the ground's
// normal, `eye` the way to the eye, `fp` a pixel's footprint. `lit` takes the
// shaped normal, `glit` the sparkle (added to ALBEDO, so the sun's own shadow
// puts it out), and `snowy` its edge, bitten by the drifts so snow ends in a
// line against rock, not a fade.
vec3 psnow_surface(vec3 p, vec2 q, vec3 n, vec3 eye, float fp, inout float snowy, out vec3 lit, out float glit) {
	vec2 w = psnow_wind;
	vec2 c = vec2(-w.y, w.x);
	float steep = smoothstep(0.84, 0.62, n.y);
	float flat_on = 1.0 - steep;
	// The wind's lines wander: a bend across them, at two lengths.
	float bend = (zs_noise(q / 150.0) - 0.5) * 90.0 + (zs_noise(q / 47.0 + 7.0) - 0.5) * 26.0 + (zs_noise(q / 13.0 + 2.0) - 0.5) * 5.0;
	float along = dot(q, w) + (zs_noise(q / 71.0 + 23.0) - 0.5) * 44.0;
	float across = dot(q, c) + bend;
	float wave = along + bend * 0.5;

	vec2 g = vec2(0.0);
	// How far each band is from its own mean (-1..1), for the tones.
	float hh = 0.0;

	// Drifts: two sizes, the big one with a sharp crest so it holds a lit
	// and a shaded side from far off.
	float scour = 0.5;
	float k_drift = psnow_keep(70.0, fp);
	if (k_drift > 0.0) {
		vec3 d = psnow_nd(vec2(along / 210.0, across / 74.0));
		vec3 e = psnow_nd(vec2(along / 88.0 + 9.0, across / 31.0 + 3.0));
		float ridge = 2.0 * (d.x * 0.7 + e.x * 0.3) - 1.0;
		float soft = sqrt(ridge * ridge + 0.02);
		float s = ridge / soft;
		float crest = 1.0 - soft;
		vec2 grad = -2.0 * s * ((w * d.y / 210.0 + c * d.z / 74.0) * 0.7 + (w * e.y / 88.0 + c * e.z / 31.0) * 0.3) * 6.5;
		g += grad * k_drift;
		hh += (crest * 1.4 - 0.7 + (e.x - 0.5)) * k_drift;
		scour = mix(0.5, crest * 0.75 + e.x * 0.25, k_drift);
	}
	// Sastrugi: ridges along the wind on the scoured parts.
	float k_sast = psnow_keep(11.0, fp) * flat_on;
	if (k_sast > 0.0) {
		vec3 a = psnow_nd(vec2(along / 27.0 + 3.0, across / 5.5 + 1.0));
		vec3 b = psnow_nd(vec2(along / 12.0 + 5.0, across / 2.3 + 8.0));
		float ridge = 2.0 * (a.x * 0.72 + b.x * 0.28) - 1.0;
		float soft = sqrt(ridge * ridge + 0.03);
		float s = ridge / soft;
		float here = smoothstep(0.42, 0.72, scour);
		vec2 grad = -2.0 * s * ((w * a.y / 27.0 + c * a.z / 5.5) * 0.72 + (w * b.y / 12.0 + c * b.z / 2.3) * 0.28) * 0.55;
		g += grad * k_sast * here;
		hh += ((1.0 - soft) - 0.5) * 0.8 * k_sast * here;
	}
	// The furrow and the wash: they flatten what's under them.
	float churn = 0.0;
	if (psnow_furrow_rect.w > 0.5) {
		vec2 rag = vec2(zs_noise(q / 3.1), zs_noise(q / 3.1 + 19.0)) - 0.5;
		vec2 fq = p.xz + rag * 1.6;
		vec2 f0 = psnow_furrow_at(fq);
		churn = clamp(f0.y, 0.0, 1.0);
		if (abs(f0.x) + churn > 0.003) {
			const float STEP_M = 1.3;
			float dx = psnow_furrow_at(fq + vec2(STEP_M, 0.0)).x - psnow_furrow_at(fq - vec2(STEP_M, 0.0)).x;
			float dz = psnow_furrow_at(fq + vec2(0.0, STEP_M)).x - psnow_furrow_at(fq - vec2(0.0, STEP_M)).x;
			g += vec2(dx, dz) * (PSNOW_DEPTH / (2.0 * STEP_M));
			// Scooped: the groove blue, its lip catching the light.
			hh += clamp(f0.x, -1.2, 0.8) * 1.3;
			// Fresh, it's rough: lumps where the wash tore it, gone as it fills.
			vec3 l = psnow_nd(q / 1.3 + 4.0);
			g += vec2(l.y, l.z) * 0.13 * churn * (1.0 - smoothstep(0.3, 1.2, fp));
		}
	}
	vec3 r = zs_react_at(p.xz);
	float stir = clamp(max(r.z, 0.0) + length(r.xy) * 0.35, 0.0, 1.0);
	g += r.xy * 0.05;
	float smooth_out = 1.0 - clamp(max(churn, stir), 0.0, 1.0);

	// Ripples: crests across the wind, in patches, a smaller train over them.
	float k_rip = psnow_keep(1.4, fp) * flat_on * smooth_out;
	if (k_rip > 0.0) {
		float patch = smoothstep(0.42, 0.66, zs_noise(q / 21.0 + 13.0) * 0.6 + zs_noise(q / 6.7 + 31.0) * 0.4);
		float warp = zs_noise(q / 6.3) * 4.4 + zs_noise(q / 2.3 + 9.0) * 0.8;
		float th = (wave + warp) * TAU / 1.4;
		float sk = 1.0 + 0.7 * cos(th);
		float rip = cos(th + 0.7 * sin(th)) * sk * TAU / 1.4;
		g += w * rip * 0.026 * patch * k_rip;
		float k2 = psnow_keep(0.62, fp);
		if (k2 > 0.0) {
			float th2 = (wave * 0.97 + dot(q, c) * 0.22 + warp * 0.7) * TAU / 0.62;
			g += (w + c * 0.22) * cos(th2) * TAU / 0.62 * 0.008 * k2 * patch * k_rip;
		}
	}
	// Grain: the surface's tooth right under the eye.
	float k_grain = psnow_keep(0.17, fp) * smooth_out;
	if (k_grain > 0.0) {
		vec3 t = psnow_nd(q / 0.17);
		g += vec2(t.y, t.z) * 0.012 * k_grain;
	}
	// Steep snow: flutes down the fall line, from whichever of three ways
	// lies nearest it.
	float k_flute = psnow_keep(26.0, fp) * steep;
	if (k_flute > 0.0) {
		vec2 fall = n.xz / max(length(n.xz), 0.001);
		for (int i = 0; i < 3; i++) {
			float ang = float(i) * PI / 3.0 + 0.3;
			vec2 d = vec2(cos(ang), sin(ang));
			float here = smoothstep(0.6, 0.92, abs(dot(fall, d)));
			if (here <= 0.0) continue;
			vec2 e = vec2(-d.y, d.x);
			vec3 a = psnow_nd(vec2(dot(p.xz, e) / 8.5 + float(i) * 11.0, dot(p.xz, d) / 90.0));
			float ridge = 2.0 * a.x - 1.0;
			float soft = sqrt(ridge * ridge + 0.03);
			float s = ridge / soft;
			g += -2.0 * s * (e * a.y / 8.5 + d * a.z / 90.0) * 1.5 * here * k_flute;
			hh += ((1.0 - soft) - 0.5) * 0.9 * here * k_flute;
		}
	}

	// The shaped normal: the gradient taken off the ground's normal.
	vec3 t = vec3(g.x, 0.0, g.y);
	t -= n * dot(t, n);
	lit = normalize(n - t);

	// The edge against the rock, bitten by the drifts and the ridges.
	snowy = smoothstep(0.30, 0.54, snowy + clamp(hh, -1.0, 1.0) * 0.2 * (1.0 - snowy));

	// Warm where the sun lands, cool where it doesn't. Hollows and the
	// groove bluer, crests paler; the wash's stir a touch brighter.
	float sunlit = smoothstep(-0.02, 0.5, dot(lit, zs_sun_direction));
	vec3 key = zs_key_irradiance / max(dot(zs_key_irradiance, vec3(0.2126, 0.7152, 0.0722)), 0.001);
	vec3 col = mix(PSNOW_COOL, PSNOW_WARM * mix(vec3(1.0), 1.0 / max(key, vec3(0.25)), PSNOW_BALANCE), sunlit);
	float tone = clamp(hh, -1.0, 1.0);
	col *= tone > 0.0 ? mix(vec3(1.0), vec3(1.05, 1.04, 1.02), tone) : mix(vec3(1.0), vec3(0.84, 0.90, 1.0), -tone);
	// Old crust and new powder lying in sheets, far apart in tone but close in value.
	col *= 0.95 + 0.07 * zs_noise(q / 230.0 + 3.0);
	col *= 1.0 + 0.05 * stir;
	glit = psnow_glitter(q, lit, eye, fp) * smooth_out;
	return col;
}

// EMISSION over snow: the sky's fill tinted. `k` the snow's share of the pixel.
vec3 psnow_emission(vec3 emission, float k) {
	return emission * mix(vec3(1.0), PSNOW_FILL, k);
}
#endif
