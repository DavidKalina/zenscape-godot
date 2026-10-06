shader_type spatial;
render_mode unshaded, blend_mix, cull_front, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;
// The near cloud sea (scripts/sky_sea.gd): the sea's heaps as a real
// surface at their own height in the world, under the dome's painted sea
// (shaders/sky_cloud_sea.gdshaderinc), which lies one depth below the eye
// wherever the eye goes and so never comes nearer or slides by. This one
// does: it lies SEA metres down, the heaps' feet at `floor_y`, so turning,
// climbing and flying over it the near heaps move against the far ones, the
// plate's and the islands' shadows lie on them, a mountain's foot or a
// plane dipped in stands in them softly, and through the gaps the land far
// below slides by slower still. Out at `reach` it hands over to the dome's
// sea, which goes on to the horizon.
//
// Drawn as a box round the eye whose inside faces only start the rays (as
// shaders/sky_tower.gdshader is): each runs through the slab of the heaps,
// stopped by anything solid nearer, and finds where it first dips under the
// heaps' surface (a height over the world's ground plane, so it is a sea of
// cloud tops, not a haze). The heaps are the Storybook sea's (its round
// domes on a heap-field that opens gaps), at a size in metres; the light is
// each style's own palette on them, worked out from the same sky colours
// and globals the dome's sea takes, so the near sea and the far one are the
// one sea in each of the player's three styles.
//
// Over the islands (`islands`) the heaps swell up toward their keels and
// close their gaps, a cushion of cloud under each; the sun casts each
// island's shadow down onto them. Round a mountain range's foot (`ranges`)
// they close their gaps, so its rock always goes down into cloud. Under a falling glide the heaps part
// round the point below the eye (zs_sea_flight.w, as the Opal dome's do).
// Close to the eye they thin away, so the glide's vapour veil
// (scripts/sky_flight.gd) takes over from a surface it never cuts through.
#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/reference_sky_common.gdshaderinc"
#define ZS_CLOUD_SEA_SHADE
#include "res://shaders/sky_cloud_sea.gdshaderinc"

// The heaps' feet and how high the tallest stands over them (m), so their
// crowns gather about the sea's top (SEA, scripts/sky_peak.gd), where the
// mountains' rock goes into the cloud.
uniform float floor_y = -130.0;
uniform float tall = 30.0;
// How far out (m, level) the heaps are drawn here, and from what share of
// it they hand over to the dome's sea.
uniform float reach = 2400.0;
uniform float hand_over = 0.55;
// The islands over the sea, nearest first: xz of the middle, the reach of
// the land (m), and the height of its underside's middle. A reach of 0 ends the list.
uniform vec4 islands[8];
// The mountain ranges standing near (scripts/sky_peaks.gd `keep_spots`),
// nearest first: xz of the middle and how far round it (z) the heaps close
// their gaps, so a range's foot stands in cloud all round, never over a
// gap that shows where its rock is cut. A reach of 0 ends the list.
uniform vec4 ranges[4];
// Where the eye is over the sea (xz), for the glide's parting.
uniform vec2 eye_xz = vec2(0.0);
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;

// The sea's top (m): the eye's height over it is the dome's "depth", so its
// haze (per depth) is matched here.
const float SEA = -105.0;
// The domes' cell (m), the heaps' drift (m/s) on the wind.
const float CELL = 46.0;
const vec2 DRIFT = vec2(0.6, 0.35) * 1.2;
// How much higher the heaps stand under an island and how far round it.
const float SWELL = 22.0;
const vec2 SWELL_REACH = vec2(0.6, 1.5);
// The land far below the gaps (m under the sea's top) and its scale.
const float GROUND = 700.0;
const float GROUND_UNIT = 150.0;
// How thick the cloud is in front of something solid dipped into it (per m),
// and where near the eye the heaps thin away (m).
const float SOLID_FADE = 0.06;
const vec2 NEAR_FADE = vec2(6.0, 45.0);
// Room over the tallest heap for the finer domes and the swell, as a share
// of `tall` + SWELL; the box (scripts/sky_sea.gd) is as tall.
const float HEADROOM = 1.3;
const int STEPS = 22;
// The march's shortest step (m): a steep look down through the slab takes
// only a few.
const float MIN_STEP = 5.0;
const int REFINE = 5;

// The heaps' height over their feet (0 to 1) at world `xz`. `detail` (0 to
// 1) brings in the finer domes, and closer still a third octave, only where
// the pixel holds them.
float sea_rise(vec2 xz, float detail, float close) {
	vec2 p = (xz + DRIFT * zs_motion_time) / CELL;
	float mass = zs_storybook_sea_gnoise(p * 0.23 + vec2(3.1, 7.7)) * 0.7 + zs_storybook_sea_gnoise(p * 0.51 + vec2(8.3, 1.9)) * 0.3;
	float heap = smoothstep(-0.2, 0.3, mass);
	float h = zs_storybook_sea_domes(p) * 0.62;
	// Without them, their mean, so the march's coarse surface stands where
	// the fine one does.
	h += 0.38 * 0.45 * (1.0 - detail);
	if (detail > 0.0) h += zs_storybook_sea_domes(p * 2.17 + vec2(5.2, 1.3)) * 0.38 * detail;
	if (close > 0.0) h += (zs_storybook_sea_domes(p * 5.3 + vec2(1.7, 9.4)) - 0.5) * 0.12 * close;
	// Under the islands: the heap-field full and the heaps higher.
	float lift = 0.0;
	for (int i = 0; i < 8; i++) {
		if (islands[i].z <= 0.0) break;
		float d = length(xz - islands[i].xy);
		lift = max(lift, 1.0 - smoothstep(islands[i].z * SWELL_REACH.x, islands[i].z * SWELL_REACH.y, d));
	}
	heap = mix(heap, 1.0, lift * 0.85);
	for (int i = 0; i < 4; i++) {
		if (ranges[i].z <= 0.0) break;
		float d = length(xz - ranges[i].xy);
		heap = mix(heap, 1.0, 0.9 * (1.0 - smoothstep(ranges[i].z * 0.6, ranges[i].z, d)));
	}
	float rise = max(h * (0.35 + 0.65 * heap) - (1.0 - heap) * 0.55, 0.0);
	rise *= 1.0 + lift * SWELL / tall;
	// Under a falling glide the heaps part round the point below the eye.
	float part = zs_sea_flight.w;
	if (part > 0.0) {
		float fray = zs_storybook_sea_gnoise(p * 3.1 + vec2(8.2, 2.9)) * 18.0;
		float d = length(xz - eye_xz) + fray;
		rise *= mix(1.0, smoothstep(part * 130.0, part * 130.0 + 45.0, d), smoothstep(0.0, 0.25, part));
	}
	return rise;
}

float sea_height(vec2 xz, float detail, float close) {
	return floor_y + tall * sea_rise(xz, detail, close);
}

// How much of the sun an island keeps off the heaps at `p`: its shadow,
// soft, cast down along the sun.
float island_shadow(vec3 p, vec3 sun) {
	float shade = 0.0;
	float up = max(sun.y, 0.25);
	for (int i = 0; i < 8; i++) {
		if (islands[i].z <= 0.0) break;
		vec2 at = p.xz + sun.xz / up * (islands[i].w - p.y);
		float d = length(at - islands[i].xy);
		shade = max(shade, 1.0 - smoothstep(islands[i].z * 0.55, islands[i].z * 1.25, d));
	}
	return shade;
}

void fragment() {
	vec3 eye = CAMERA_POSITION_WORLD;
	vec3 seen = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 rd = normalize(seen - eye);
	float top_y = floor_y + (tall + SWELL) * HEADROOM;
	// The slab of the heaps along the ray.
	float t_in;
	float t_floor;
	if (abs(rd.y) < 1e-4) {
		if (eye.y > top_y || eye.y < floor_y) discard;
		t_in = 0.0;
		t_floor = 1e9;
	} else {
		float ta = (top_y - eye.y) / rd.y;
		float tb = (floor_y - eye.y) / rd.y;
		t_in = max(min(ta, tb), 0.0);
		// Only a ray going down meets the floor; one going up leaves by the top.
		t_floor = rd.y < 0.0 ? tb : 1e9;
		if (max(ta, tb) <= t_in) discard;
	}
	float level = max(length(rd.xz), 1e-4);
	float t_reach = reach / level;
	float t_leave = rd.y < 0.0 ? t_floor : (top_y - eye.y) / max(rd.y, 1e-4);
	// Stopped by anything solid nearer.
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float t_solid = length(behind.xyz / behind.w);
	float t_end = min(min(t_leave, t_reach), t_solid);
	if (t_end <= t_in) discard;

	// Radians per pixel, for how fine the heaps can be drawn along the ray.
	float pixel = max(length(fwidth(rd)), 1e-5);
	float jitter = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	float dt = max((t_end - t_in) / float(STEPS), MIN_STEP);
	float t = t_in + dt * jitter * 0.9;
	float hit = -1.0;
	float before = t_in;
	for (int i = 0; i < STEPS; i++) {
		vec3 p = eye + rd * t;
		if (p.y < sea_height(p.xz, 0.0, 0.0)) {
			hit = t;
			break;
		}
		before = t;
		t += dt;
		if (t > t_end) break;
	}
	// Where it reached the floor in a gap instead.
	bool gap = hit < 0.0 && t_end >= t_leave - 0.5 && rd.y < 0.0 && t_floor < t_reach && t_floor < t_solid;
	if (hit < 0.0 && !gap) discard;
	float foot = (hit > 0.0 ? hit : t_floor) * pixel / CELL;
	float detail = 1.0 - smoothstep(0.08, 0.3, foot);
	float close = 1.0 - smoothstep(0.02, 0.07, foot);
	if (hit > 0.0) {
		// Between the last step over the heaps and the first under them,
		// with the finer domes in now.
		float a = before;
		float b = hit;
		for (int i = 0; i < REFINE; i++) {
			float m = (a + b) * 0.5;
			vec3 p = eye + rd * m;
			if (p.y < sea_height(p.xz, detail, close)) b = m;
			else a = m;
		}
		hit = b;
	}
	float t_seen = hit > 0.0 ? hit : t_floor;
	vec3 pos = eye + rd * t_seen;
	float far = length(pos.xz - eye.xz);
	// In the dome's terms: how many of the eye's heights over the sea away.
	float depths = far / max(eye.y - SEA, 12.0);

	// The sky's colours as the dome's sea takes them.
	vec2 flat_dir = normalize(rd.xz + 1e-5);
	float deep_night = zs_night * zs_celestial_clear;
	float dim = mix(1.0, 0.4, deep_night);
	vec3 horizon = zsSkyBase(vec3(flat_dir.x, 0.0, flat_dir.y)) * dim;
	vec3 below = zsSkyBase(rd) * dim;
	float dull = smoothstep(0.35, 0.9, zs_cloud.x);
	vec3 sun_c = max(zs_cloud_sun, vec3(1e-4));
	vec3 sun_hue = sun_c / max(max(sun_c.r, sun_c.g), sun_c.b);
	vec3 sun = normalize(zs_sun_direction + vec3(0.0, 1e-4, 0.0));
	vec2 bearing = normalize(sun.xz + vec2(1e-4, 0.0));
	// Painted light, as the Storybook sea's: the sun's bearing from a
	// storybook angle, so each heap keeps a lit and a shaded side.
	vec3 light = normalize(vec3(bearing.x, 0.62, bearing.y));
	float golden = smoothstep(0.35, 0.06, sun.y) * smoothstep(-0.12, 0.0, sun.y) * (1.0 - dull);

	// Each style's palette: lit tops, mid, shade, the deep air in the gaps
	// and the haze the far sea goes into (and how fast, per depth).
	vec3 lit_col;
	vec3 mid_col;
	vec3 shade_col;
	vec3 deep_air;
	vec3 haze_col;
	float haze_rate;
	float mood;
	float banding = 0.0;
	vec3 pearl = vec3(1.0);
	if (cloud_sea_style == 0) {
		// Opal: luminous pearl tops, cool clean shadows (sky_cloud_sea_opal).
		const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
		float lum = dot(horizon, LUMA);
		lum = max(lum, SEA_NIGHT_LEVEL * deep_night);
		lum *= 1.0 + SEA_OVERCAST_LIFT * dull * (1.0 - zs_night);
		vec3 sky_hue = zs_cloud_sky / max(max(max(zs_cloud_sky.r, zs_cloud_sky.g), zs_cloud_sky.b), 1e-3);
		pearl = mix(vec3(0.97, 0.97, 1.0), sun_hue, mix(SEA_SUN_TINT, 0.5, golden));
		vec3 shadow_hue = mix(mix(SEA_SHADOW, sky_hue, 0.35), SEA_GOLDEN_SHADOW, golden * 0.6);
		lit_col = pearl * min(lum * SEA_LEVELS.x, 0.95);
		mid_col = mix(lit_col, shadow_hue * lum * SEA_LEVELS.y, 0.5);
		shade_col = shadow_hue * lum * SEA_LEVELS.y;
		deep_air = shadow_hue * vec3(0.92, 0.95, 1.0) * lum * SEA_LEVELS.z;
		haze_col = mix(horizon, pearl * lum, 0.45);
		haze_rate = SEA_HAZE;
		mood = SEA_SEASON_MOOD.x;
	} else if (cloud_sea_style == 2) {
		// Mystic: pastel bodies, lavender flanks, periwinkle depths
		// (sky_cloud_sea_mystic).
		float day = smoothstep(0.1, 0.32, sun.y) * (1.0 - zs_night) * (1.0 - 0.6 * dull);
		vec3 tone = mix(below, horizon, 0.3);
		float lum = zs_mystic_sea_luma(tone);
		vec3 sky_hue = mix(zs_mystic_sea_hue(tone), zs_mystic_sea_hue(zs_sky_up), 0.8);
		vec3 m_sun = zs_mystic_sea_hue(zs_cloud_sun);
		vec3 lavender = mix(vec3(1.0), sky_hue * vec3(1.06, 0.95, 0.98), 0.4);
		vec3 cream = mix(vec3(1.0), m_sun, 0.4);
		vec3 day_lit = lum * 1.12 * cream;
		vec3 day_shade = lum * 0.8 * lavender;
		vec3 day_trough = lum * 0.64 * mix(vec3(1.0), sky_hue * vec3(1.06, 0.95, 1.0), 0.5);
		lit_col = mix(tone * 1.12, day_lit, day);
		shade_col = mix(tone * 0.84, day_shade, day);
		mid_col = mix(shade_col, lit_col, 0.5);
		deep_air = mix(tone * 0.8, day_trough, day);
		haze_col = mix(tone, lum * 0.96 * mix(vec3(1.0), sky_hue, 0.12), day);
		haze_rate = 0.3;
		mood = SEA_SEASON_MOOD.z;
	} else {
		// Storybook: soft natural light with a breath of painted steps
		// (sky_cloud_sea_storybook).
		vec3 base = mix(below, horizon, 0.2);
		float value = clamp(dot(base, vec3(0.3, 0.5, 0.2)) * 1.18, 0.0, 0.8);
		value = max(value, deep_night * 0.1);
		float warm = clamp((sun_hue.r - sun_hue.b) * 1.6, 0.0, 1.0) * smoothstep(0.0, 0.25, zs_daylight) * (1.0 - dull);
		value = min(max(value, zs_daylight * mix(0.6, 0.5, dull)) * (1.0 + 0.22 * warm), 0.82);
		vec3 shade_hue = mix(vec3(0.8, 0.82, 1.0), vec3(0.84, 0.86, 0.93), dull);
		lit_col = value * mix(vec3(1.0), sun_hue, mix(0.5, 0.3, dull)) * mix(1.2, 1.0, dull);
		lit_col = mix(lit_col, value * vec3(0.92, 0.97, 1.08), deep_night * 0.6);
		mid_col = mix(value * mix(vec3(0.88, 0.9, 1.0), sun_hue, 0.3), horizon, 0.1);
		shade_col = mix(value * 0.86 * shade_hue, horizon * 0.86, 0.1 + 0.4 * dull);
		deep_air = mix(horizon, value * vec3(0.84, 0.88, 1.02), 0.45);
		deep_air = mix(mix(deep_air, horizon, 0.2), value * vec3(0.74, 0.82, 0.95), 0.45 * (1.0 - dull) * (1.0 - 0.6 * warm));
		haze_col = horizon;
		haze_rate = 0.09;
		mood = SEA_SEASON_MOOD.y;
		banding = 0.25;
		pearl = lit_col;
	}

	vec3 col;
	float rise = 0.0;
	if (hit > 0.0) {
		rise = sea_rise(pos.xz, detail, close);
		// The surface's normal from its slope.
		float e = mix(9.0, 2.5, close);
		float hx = sea_height(pos.xz + vec2(e, 0.0), detail, close);
		float hz = sea_height(pos.xz + vec2(0.0, e), detail, close);
		float h0 = floor_y + tall * rise;
		vec3 n = normalize(vec3(-(hx - h0) / e, 1.0, -(hz - h0) / e));
		float l = dot(n, light) * 0.7 + 0.3;
		// A short shadow toward the sun: the creases and the far side of a
		// heap fall into the heap before it.
		float lit = 1.0;
		for (int s = 1; s <= 3; s++) {
			vec3 sp = pos + light * (tall * 0.45 * float(s));
			lit = min(lit, smoothstep(-0.6, 0.9, sp.y - sea_height(sp.xz, 0.0, 0.0)));
		}
		lit = mix(1.0, lit, 1.0 - smoothstep(0.6, 3.0, depths));
		// The islands' shadows, by day.
		float island = island_shadow(pos, sun) * smoothstep(0.02, 0.2, sun.y) * (1.0 - dull);
		lit = min(lit, 1.0 - 0.75 * island);
		l *= mix(0.72, 1.0, lit);
		float soft = 0.16 + foot * 0.3 + 0.03 * dull;
		float stepped = 0.5 * smoothstep(0.3 - soft, 0.3 + soft, l) + 0.5 * smoothstep(0.62 - soft, 0.62 + soft, l);
		float band = mix(smoothstep(0.0, 1.0, l), stepped, banding);
		col = mix(shade_col, mid_col, smoothstep(0.0, 0.5, band));
		col = mix(col, lit_col, smoothstep(0.5, 1.0, band));
		// Low in the creases the cloud is deeper in its own shade.
		float crown = clamp(rise, 0.0, 1.0);
		col = mix(shade_col * 0.96, col, mix(0.82, 1.0, smoothstep(0.0, 0.45, crown)));
		// The lining: a heap's sunward flank and an edge turned to the eye.
		float flank = smoothstep(0.25, 0.6, length(n.xz)) * smoothstep(0.2, 0.7, dot(normalize(n.xz + 1e-4), bearing));
		float edge = pow(1.0 - clamp(dot(n, -rd), 0.0, 1.0), 2.0);
		float rim = max(flank * 0.7, edge) * lit * (1.0 - dull);
		col = mix(col, lit_col * 1.1, rim * 0.3);
		if (cloud_sea_style == 0) {
			// Opal's mother-of-pearl over the rims and crowns.
			float play = crown * 1.7 + dot(flat_dir, bearing) * 0.3 + rd.y * 1.1 + depths * 0.05 + zs_motion_time * 0.002;
			col *= mix(vec3(1.0), zs_opal_sea_opal(play), SEA_OPAL * (0.35 + 0.65 * rim + 0.4 * crown) * mix(1.0, 0.35, dull));
		}
		// The heaps' feet thin into the gap below them.
		col = mix(deep_air, col, smoothstep(0.0, 0.1, rise));
	} else {
		// A gap: the Opal dome's land far below (fields, woods, a river,
		// coasts and the blue ocean), so the near sea opens onto the same
		// world the far one does, in every style.
		float t_ground = (SEA - GROUND - eye.y) / rd.y;
		vec2 gp = (eye.xz + rd.xz * t_ground) / GROUND_UNIT;
		float gfoot = t_ground * pixel / GROUND_UNIT;
		float level = clamp(dot(lit_col, vec3(0.2126, 0.7152, 0.0722)), 0.05, 1.0);
		vec3 shadow_hue = deep_air / max(dot(deep_air, vec3(0.2126, 0.7152, 0.0722)), 1e-3);
		vec3 lamp = normalize(mix(sun, zs_moon_direction, zs_night * zs_celestial_clear));
		float glint = pow(0.5 + 0.5 * dot(flat_dir, normalize(lamp.xz + 1e-4)), 8.0) * smoothstep(-0.05, 0.2, lamp.y) * mix(1.0, 0.5, zs_night) * (1.0 - dull);
		vec3 ground = zs_opal_sea_land(gp / SEA_LAND.x, gfoot / SEA_LAND.x, level, shadow_hue, pearl, max(golden, zs_night), glint);
		col = mix(ground, deep_air, mix(0.12, 0.6, dull));
		if (cloud_sea_style == 2) {
			// Mystic's faint light from the deep, breathing slowly.
			float patch = smoothstep(0.4, 0.8, zs_mystic_sea_noise(gp * 0.6 + zs_motion_time * vec2(0.003, 0.002)));
			col += mix(vec3(1.0), sun_hue, 0.5) * vec3(0.75, 1.0, 1.0) * patch * 0.05 * (1.0 - zs_daylight * 0.5);
		}
	}
	// Detail the pixel can no longer hold settles to the sea's mean.
	col = mix(col, mix(mid_col, deep_air, 0.4), smoothstep(0.5, 1.2, foot));
	// Air between the eye and the far sea, as the dome's.
	float haze = 1.0 - exp(-depths * haze_rate);
	col = mix(col, haze_col, haze * 0.85);
	col = zs_sky_season_grade(col, mood * (1.0 - SEA_SEASON_NIGHT * zs_night));

	float alpha = cloud_sea;
	// Something solid just behind the cloud's top shows through it.
	if (hit > 0.0 && t_solid < 1e8) alpha *= 1.0 - exp(-max(t_solid - hit, 0.0) * SOLID_FADE);
	// Thin away close to the eye.
	alpha *= smoothstep(NEAR_FADE.x, NEAR_FADE.y, t_seen);
	// Hand over to the dome's sea far out.
	alpha *= 1.0 - smoothstep(reach * hand_over, reach, far);
	// Far off, the dome's veil: thin at the horizon, and under a clear night
	// pulled down below the stars' band.
	float veiled = smoothstep(-0.02, -0.16, rd.y);
	veiled *= mix(1.0, smoothstep(-0.34, -0.66, rd.y), deep_night);
	alpha *= mix(1.0, veiled, smoothstep(150.0, 700.0, t_seen));
	if (alpha < 0.003) discard;
	ALBEDO = col;
	ALPHA = alpha;
}
