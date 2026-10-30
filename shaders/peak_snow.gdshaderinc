#ifndef ZS_PEAK_SNOW
#define ZS_PEAK_SNOW
// The Peak's snow (scripts/endless/peak_snow.gd): a surface of its own,
// outside the rock shader's direction buckets and tones. Included by
// shaders/endless_ground.gdshader after grass_react (zs_react_at) and
// reference_wind (zs_noise). Only the Peak's zone reads it (`psnow_on` and
// peak_paint's zone); the land's other snowcaps never get here.
//
// It paints from `psnow_point`, not the ground's sheared gxz. gxz moves by the
// shear (which follows n.y) times the height over the sea: up here that is
// hundreds of metres for a small change of slope, so anything read from it
// races past along lines of equal slope. Those were the thin contour rings on
// steep snow and at its edge, and the polygon patches on the plateau.
//
// The shape is a height field given by its gradient, in a wind-laid flow
// (world xz, bent by noise and by the land's height, so lines wander round
// it), each band gone by the time a pixel outgrows it, so detail shrinks with
// distance and far snow is the near snow's mean:
//   pillows   60..190 m  smooth drifts; what reads from 500 m
//   scour     25..130 m  patches of hard wind crust with a low bank round
//                        them, crisp in places, lost in others
//   sastrugi  1.5..3.4 m short tapered streaks along the wind, in the scour,
//                        of many lengths, row by row; they end, they don't comb
//   ripples   0.6..1.4 m crests across the wind, in small patches
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
// The tones. Sunlit: a neutral warm white. Shaded: all but white, for the blue
// comes from the sky's fill, not from here. PSNOW_FILL is how much more of the
// sky's fill snow gets than the land's ground does (the whole sky and its own
// bounce): near grey, so the shade keeps the fill's own hue, pale.
const vec3 PSNOW_COOL = vec3(0.93, 0.95, 0.98);
const vec3 PSNOW_WARM = vec3(1.0, 0.97, 0.92);
const vec3 PSNOW_FILL = vec3(5.2, 5.0, 4.6);
// How much of the sun's own colour the snow takes out of itself, so a warm
// morning leaves it white with a warm edge rather than the colour of sand;
// the sky's fill takes out the rest, so too much of this turns it lilac.
const float PSNOW_BALANCE = 0.13;
// The share of the height over the sea the paint point shears by (a constant,
// so it cannot race): enough that a steep face doesn't smear its noise.
const float PSNOW_SHEAR = 0.5;

// Where the snow paints from: see the top of this file.
vec2 psnow_point(vec3 p, float over) {
	return p.xz + vec2(0.8, 0.55) * over * PSNOW_SHEAR;
}

// The snow's mask over the ground's: peak_paint's snow line and its steep limit,
// from the same noises, at the stable point. `line` the snow line, `high` how
// far above it.
float psnow_mask(vec2 q, float over, float ny, float line, float high) {
	float mid = zs_noise(q / 19.0 + 41.0) - 0.5;
	float edge = (zs_noise(q / 160.0) - 0.5) * 120.0 + (zs_noise(q / 41.0) - 0.5) * 50.0
		+ (zs_noise(q / 23.0) - 0.5) * 16.0 + mid * 10.0;
	// (A wider rag than the ground's: its normals are per vertex, 32 m apart, and
	// a clean limit on them draws the mesh's teeth along the snow's edge.)
	float rock_e = (zs_noise(q / 9.0) - 0.5) * 0.10 + mid * 0.08 + (zs_noise(q / 33.0 + 57.0) - 0.5) * 0.20;
	return smoothstep(line - 20.0, line + 4.0, over + edge)
		* smoothstep(mix(0.58, 0.40, high), mix(0.68, 0.52, high), ny + rock_e);
}

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

// Short streaks along the wind, a row at a time. `u` along (m), `v` across (m),
// `len` and `wide` a streak's length and row width. Each row has its own
// length, its own way of carrying its crest to one side, its own strength, and
// many carry none; a streak is a crest of a 1-D noise, so it tapers to nothing
// at both ends. Returns the height (0..1), `dv` its gradient along and across.
float psnow_streaks(float u, float v, float len, float wide, float seed, out vec2 dv) {
	dv = vec2(0.0);
	float rv = v / wide + seed;
	float row = floor(rv);
	float f = rv - row;
	float h0 = zs_noise_hash(vec2(row, seed));
	float h1 = zs_noise_hash(vec2(row + 3.7, seed + 5.1));
	float carry = smoothstep(0.5, 0.82, h0);
	if (carry <= 0.0) return 0.0;
	float l = len * mix(0.7, 2.3, h1);
	float ru = u / l + h0 * 91.0;
	float i = floor(ru);
	float t = ru - i;
	float a = zs_noise_hash(vec2(i, row * 1.3 + seed));
	float b = zs_noise_hash(vec2(i + 1.0, row * 1.3 + seed));
	float st = t * t * (3.0 - 2.0 * t);
	float n = mix(a, b, st);
	float dn = (b - a) * 6.0 * t * (1.0 - t) / l;
	float c = clamp((n - 0.5) / 0.3, 0.0, 1.0);
	if (c <= 0.0) return 0.0;
	float on = c * c * (3.0 - 2.0 * c);
	float don = 6.0 * c * (1.0 - c) / 0.3 * dn;
	float m = mix(0.28, 0.72, fract(h1 * 7.3));
	float x = f < m ? f / m : (1.0 - f) / (1.0 - m);
	float bump = x * x * (3.0 - 2.0 * x);
	float dbump = 6.0 * x * (1.0 - x) * (f < m ? 1.0 / m : -1.0 / (1.0 - m)) / wide;
	dv = vec2(don * bump, on * dbump) * carry;
	return on * bump * carry;
}

// The furrow map at world xz: x height, y churn. Zero off the map.
vec2 psnow_furrow_at(vec2 xz) {
	vec2 uv = (xz - psnow_furrow_rect.xy) / psnow_furrow_rect.z;
	if (uv.x <= 0.0 || uv.y <= 0.0 || uv.x >= 1.0 || uv.y >= 1.0) return vec2(0.0);
	vec2 rim = min(uv, 1.0 - uv);
	return textureLod(psnow_furrow, uv, 0.0).rg * smoothstep(0.0, 0.05, min(rim.x, rim.y));
}

// Sparkle: a facet per cell (a little over a pixel, never under its floor)
// flashes when it stands between the sun and the eye. Stronger the lower the
// sun, gone as the pixel outgrows a sparkle. Sparse and small: it is a few
// points, not a sheen.
float psnow_glitter(vec2 q, vec3 n, vec3 eye, float fp) {
	if (fp > 0.6) return 0.0;
	float size = max(0.04, fp * 1.4);
	vec2 c = floor(q / size);
	vec3 r = vec3(zs_noise_hash(c), zs_noise_hash(c + 17.3), zs_noise_hash(c + 41.7)) * 2.0 - 1.0;
	vec3 facet = normalize(n + r * 0.55);
	vec3 h = normalize(zs_sun_direction + eye);
	float flash = smoothstep(0.9975, 0.9995, dot(facet, h));
	if (flash <= 0.0) return 0.0;
	float dot_in = 1.0 - smoothstep(0.1, 0.48, length(q / size - c - 0.5));
	float low = 1.0 - smoothstep(0.10, 0.70, zs_sun_direction.y);
	return flash * dot_in * mix(0.25, 1.0, low) * 3.2 * (1.0 - smoothstep(0.2, 0.6, fp));
}

// The snow's albedo at `p`. `q` the paint point (psnow_point), `n` the ground's
// normal, `eye` the way to the eye, `dist` how far it is, `px` a pixel's angle. `lit` takes the
// shaped normal, `glit` the sparkle (added to ALBEDO, so the sun's own shadow
// puts it out), and `snowy` its edge, bitten by the drifts so snow ends in a
// line against rock, not a fade.
vec3 psnow_surface(vec3 p, vec2 q, vec3 n, vec3 eye, float dist, float px, inout float snowy, out vec3 lit, out vec3 glit) {
	// A pixel's footprint, from the eye and the smooth normal: the ground's fp
	// comes from p's derivatives, which jump at each triangle's edge, and the
	// bands would stop and start in polygons.
	float fp = dist * px * mix(1.0, 1.0 / max(dot(eye, n), 0.12), 0.4);
	vec2 w = psnow_wind;
	vec2 c = vec2(-w.y, w.x);
	float steep = smoothstep(0.84, 0.62, n.y);
	float flat_on = 1.0 - steep;
	// The flow: the wind's lines wander at three lengths, and the land's height
	// bends them, so they lean round a rise instead of running over it.
	float bend = (zs_noise(q / 240.0) - 0.5) * 130.0 + (zs_noise(q / 70.0 + 7.0) - 0.5) * 42.0 + (zs_noise(q / 19.0 + 2.0) - 0.5) * 7.0;
	float along = dot(q, w) + (zs_noise(q / 95.0 + 23.0) - 0.5) * 60.0;
	float across = dot(q, c) + bend + p.y * 0.6;
	float wave = along + bend * 0.5;

	vec2 g = vec2(0.0);
	// How far each band is from its own mean (-1..1), for the tones.
	float hh = 0.0;

	// Pillows: smooth drifts, two sizes turned against each other, no crest.
	float k_drift = psnow_keep(60.0, fp);
	if (k_drift > 0.0) {
		vec3 d = psnow_nd(vec2(along / 190.0, across / 96.0));
		vec2 tw = vec2(along * 0.82 + across * 0.57, across * 0.82 - along * 0.57);
		vec3 e = psnow_nd(tw / vec2(66.0, 44.0) + vec2(9.0, 3.0));
		vec2 dd = (w * d.y / 190.0 + c * d.z / 96.0) * 14.0;
		vec2 tew = w * 0.82 - c * 0.57;
		vec2 tec = c * 0.82 + w * 0.57;
		vec2 de = (tew * e.y / 66.0 + tec * e.z / 44.0) * 2.6;
		g += (dd + de) * k_drift;
		hh += ((d.x - 0.5) * 1.1 + (e.x - 0.5) * 0.6) * k_drift;
	}
	// Scour: patches of hard crust with a low bank round them where they bite
	// into the drift; a bank crisp along one stretch is lost along the next.
	float scour = 0.0;
	float k_scour = psnow_keep(25.0, fp);
	{
		vec3 s1 = psnow_nd(vec2(along / 130.0 + 31.0, across / 72.0 + 12.0));
		vec3 s2 = psnow_nd(vec2(along / 41.0 + 11.0, across / 24.0 + 4.0));
		float sv = s1.x * 0.68 + s2.x * 0.32;
		float crisp = smoothstep(0.38, 0.68, zs_noise(q / 63.0 + 51.0));
		float half_w = mix(0.13, 0.026, crisp);
		float t = clamp((sv - 0.53 + half_w) / (2.0 * half_w), 0.0, 1.0);
		scour = t * t * (3.0 - 2.0 * t);
		vec2 dsv = (w * s1.y / 130.0 + c * s1.z / 72.0) * 0.68 + (w * s2.y / 41.0 + c * s2.z / 24.0) * 0.32;
		g += dsv * (6.0 * t * (1.0 - t) / (2.0 * half_w)) * 1.0 * k_scour;
	}
	// Sastrugi: short streaks along the wind in the scour, each set turned a
	// little off the last, fading in and out as a whole.
	float k_sast = psnow_keep(4.4, fp) * flat_on * scour;
	if (k_sast > 0.0) {
		float fade = smoothstep(0.30, 0.62, zs_noise(q / 17.0 + 5.0) * 0.7 + zs_noise(q / 6.1 + 15.0) * 0.3);
		// (Rows don't run ruler-straight: a small wander across them.)
		float wand = (zs_noise(q / 7.3 + 61.0) - 0.5) * 3.2;
		vec2 dv;
		float h1 = psnow_streaks(along + across * 0.15, across + wand - along * 0.15, 14.0, 3.4, 1.0, dv);
		g += (w * dv.x + c * dv.y) * 0.5 * k_sast * fade;
		hh += (h1 - 0.3) * 0.5 * k_sast * fade;
		float k2 = psnow_keep(2.2, fp);
		if (k2 > 0.0) {
			float h2 = psnow_streaks(along - across * 0.1, across + wand * 0.6 + along * 0.1, 9.0, 1.45, 7.0, dv);
			g += (w * dv.x + c * dv.y) * 0.24 * k_sast * k2 * (0.35 + 0.65 * fade);
			hh += (h2 - 0.3) * 0.25 * k_sast * k2;
			float k3 = psnow_keep(0.9, fp);
			if (k3 > 0.0) {
				float h3 = psnow_streaks(along + across * 0.3, across + wand + along * 0.05, 3.1, 0.55, 13.0, dv);
				g += (w * dv.x + c * dv.y) * 0.10 * k_sast * k3;
				hh += (h3 - 0.3) * 0.2 * k_sast * k3;
			}
		}
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
	float k_rip = psnow_keep(1.4, fp) * flat_on * smooth_out * (1.0 - scour);
	if (k_rip > 0.0) {
		float patch = smoothstep(0.56, 0.74, zs_noise(q / 17.0 + 13.0) * 0.6 + zs_noise(q / 5.3 + 31.0) * 0.4);
		float warp = zs_noise(q / 6.3) * 5.4 + zs_noise(q / 2.3 + 9.0) * 1.2;
		float th = (wave + warp) * TAU / 1.4;
		float sk = 1.0 + 0.7 * cos(th);
		float rip = cos(th + 0.7 * sin(th)) * sk * TAU / 1.4;
		g += w * rip * 0.014 * patch * k_rip;
		float k2 = psnow_keep(0.62, fp);
		if (k2 > 0.0) {
			float th2 = (wave * 0.97 + dot(q, c) * 0.22 + warp * 0.7) * TAU / 0.62;
			g += (w + c * 0.22) * cos(th2) * TAU / 0.62 * 0.004 * k2 * patch * k_rip;
		}
	}
	// Grain: the surface's tooth right under the eye.
	float k_grain = psnow_keep(0.9, fp) * mix(0.5, 1.0, smooth_out);
	if (k_grain > 0.0) {
		// (Lumps a metre across, then the grain itself.)
		vec3 l1 = psnow_nd(q / 0.95 + 21.0);
		g += vec2(l1.y, l1.z) * 0.13 * k_grain;
		hh += (l1.x - 0.5) * 0.14 * k_grain;
		vec3 t = psnow_nd(q / 0.17);
		float k_fine = psnow_keep(0.17, fp);
		g += vec2(t.y, t.z) * 0.05 * k_fine * k_grain;
		hh += (t.x - 0.5) * 0.08 * k_fine * k_grain;
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

	// The edge against the rock, bitten by the drifts and the ridges, and
	// ragged under the eye: snow ends in a line, not a fade.
	float rag = (zs_noise(q / 3.1 + 71.0) - 0.5) * 0.30 * psnow_keep(3.1, fp) + (zs_noise(q / 0.8 + 73.0) - 0.5) * 0.14 * psnow_keep(0.8, fp);
	float soft_edge = clamp(0.015 + fp * 0.012, 0.015, 0.12);
	snowy = smoothstep(0.42 - soft_edge, 0.42 + soft_edge, snowy + (clamp(hh, -1.0, 1.0) * 0.2 + rag) * (1.0 - snowy));

	// A warm white where the sun lands, all but white where it doesn't: the
	// shade's blue is the sky's fill. Hollows and the groove a little deeper,
	// crests paler; the wash's stir a touch brighter.
	float nl = dot(lit, zs_sun_direction);
	float sunlit = smoothstep(-0.02, 0.5, nl);
	vec3 key = zs_key_irradiance / max(dot(zs_key_irradiance, vec3(0.2126, 0.7152, 0.0722)), 0.001);
	vec3 col = mix(PSNOW_COOL, PSNOW_WARM * mix(vec3(1.0), 1.0 / max(key, vec3(0.25)), PSNOW_BALANCE), sunlit);
	// (A knee: slopes square to the sun keep their forms, not a blown white.)
	col *= mix(1.0, 0.80, smoothstep(0.5, 1.0, nl));
	float tone = clamp(hh, -1.0, 1.0);
	col *= tone > 0.0 ? mix(vec3(1.0), vec3(1.04, 1.04, 1.03), tone) : mix(vec3(1.0), vec3(0.86, 0.885, 0.92), -tone);
	// Form in the shade: the sky's fill has a way too, opposite the sun.
	vec3 back = normalize(vec3(-zs_sun_direction.x, 0.7, -zs_sun_direction.z));
	col *= 1.0 + dot(lit - n, back) * 1.3 * (1.0 - sunlit);
	// The crust a shade greyer and cooler than the drift, far off too.
	col *= mix(vec3(1.0), vec3(0.945, 0.955, 0.975), scour);
	// Warm near, cool far.
	col *= mix(vec3(1.012, 1.0, 0.982), vec3(0.975, 0.99, 1.02), smoothstep(30.0, 900.0, dist));
	col *= 1.0 + 0.05 * stir;
	// The sparkle goes out as sunlight, so white in spite of the sun's colour.
	glit = psnow_glitter(q, lit, eye, fp) * smooth_out / max(key, vec3(0.25));
	return col;
}

// EMISSION over snow: the sky's fill tinted. `k` the snow's share of the pixel.
vec3 psnow_emission(vec3 emission, float k) {
	return emission * mix(vec3(1.0), PSNOW_FILL, k);
}
#endif
