shader_type spatial;
render_mode unshaded, blend_mix, cull_front, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;
// The near cloud sea (scripts/sky_sea.gd): a floor of cumulus heaps at
// their own height in the world, under the dome's painted sea (shaders/
// sky_cloud_sea.gdshaderinc), which lies one depth below the eye wherever
// the eye goes and so never comes nearer or slides by. This one does: its
// heaps stand on `floor_y`, so turning, climbing and flying over it the
// near heaps move against the far ones, the plate's and the islands'
// shadows lie on them, a mountain's foot or a plane dipped in stands in
// them softly, and through the gaps the land far below slides by slower
// still. Out at `reach` it hands over to the dome's sea, which goes on to
// the horizon.
//
// The heaps are the towering cumulus' own cloud (shaders/sky_tower
// .gdshader), only low and wide: a volume marched through a box round the
// eye whose inside faces only start the rays, stopped by anything solid
// nearer. Where they stand and how tall is the Storybook sea's heap-field
// (its round domes on a field that opens gaps), at a size in metres; on
// that envelope the towers' cauliflower swells (the shared noise volume,
// scripts/cumulus_noise.gd: round bumps bigger toward the crowns, a finer
// octave near the eye, wisps fraying the edge), and the towers' light
// (shaders/cumulus_light.gdshaderinc) lies on them: sunlit crowns in the
// sun's hue, cool shaded undersides and creases, a silver or gold lining
// on thin edges against the sun. Each of the player's three styles tints
// that light toward its own palette (Opal's mother-of-pearl, Mystic's
// pastels; Storybook is the towers' own), and the far heaps go into each
// style's haze as the dome's sea does, so the near sea and the far one
// meet as one.
//
// Over the islands (`islands`) the heaps swell up toward their keels and
// close their gaps, a cushion of cloud under each; the sun casts each
// island's shadow down onto them. Round a mountain range's foot (`ranges`)
// they close their gaps and rise, so its rock always goes down into cloud.
// Under a falling glide the heaps part round the point below the eye
// (zs_sea_flight.w, as the Opal dome's do). Close to the eye they thin
// away, so the glide's vapour veil (scripts/sky_flight.gd) takes over.
// Through the gaps lies the Opal dome's land far below: fields, woods, a
// river, coasts and the blue ocean.
//
// Cost: the march leaps through the clear air over the heaps (by how far
// over their envelope a point stands), then steps through them, two reads
// a step (the envelope, the noise), a third near the eye (the finer
// bumps), two more toward the sun to light a point, and four once where
// the ray first meets the cloud (the lobe's face); it stops once all but
// 3% of the light is gone. STEPS, STEP and FINE_NEAR are the knobs.
#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/cumulus_light.gdshaderinc"
#define ZS_CLOUD_SEA_SHADE
#include "res://shaders/sky_cloud_sea.gdshaderinc"

// The heaps' feet and how high the tallest stands over them (m), so their
// crowns gather under the sea's top (SEA, scripts/sky_peak.gd), where the
// mountains' rock goes into the cloud.
uniform float floor_y = -150.0;
uniform float tall = 45.0;
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
// The cumulus' noise volume (scripts/cumulus_noise.gd), once it is made:
// till then (`has_noise` 0) the heaps are the envelope alone.
uniform sampler3D cauliflower : filter_linear, repeat_enable;
uniform float has_noise = 0.0;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
// The envelope's heap-field and domes baked round the eye (scripts/
// sky_sea.gd `_bake`, shaders/sky_sea_envelope.gdshader): xy the square's
// corner in the drifting field, z its side (m), w 1 once it is drawn.
uniform sampler2D envelope : filter_linear, repeat_disable;
uniform vec4 envelope_at = vec4(0.0);

// The sea's top (m): the eye's height over it is the dome's "depth", so its
// haze (per depth) is matched here.
const float SEA = -105.0;
// The domes' cell (m), the heaps' drift (m/s) on the wind.
const float CELL = 72.0;
const vec2 DRIFT = vec2(0.6, 0.35) * 1.2;
// How much higher the heaps stand under an island or round a range's foot,
// and how far round an island.
const float SWELL = 22.0;
const vec2 SWELL_REACH = vec2(0.6, 1.5);
// The land far below the gaps (m under the sea's top) and its scale.
const float GROUND = 700.0;
const float GROUND_UNIT = 100.0;
// Where near the eye the heaps thin away (m).
const vec2 NEAR_FADE = vec2(6.0, 45.0);
// Room over the tallest heap for its bumps and the swell, as a share of
// `tall` + SWELL; the box (scripts/sky_sea.gd) is as tall.
const float HEADROOM = 1.3;
// The cauliflower: the noise's tile (m), how far its bumps swell the
// heaps (m) and how much the wisps fray them; the finer octave's tile and
// swell, and how near the eye (m) it shows; how soft the edge is at the
// crown and the foot (m); how the bumps boil up and drift with the heaps
// (m/s).
const float TILE = 150.0;
const float LOBE = 26.0;
const float WISP = 2.5;
const float FINE = 34.0;
const float FINE_SWELL = 4.0;
const float FINE_NEAR = 260.0;
const vec2 SOFT = vec2(1.5, 3.5);
const vec3 BOIL = vec3(0.72, -0.4, 0.42);
// How thick the cloud is (per metre at full density): denser than a
// tower's, so the heaps' tops read as a surface of lobes, not a haze.
const float SIGMA = 0.22;
// How much cloud (m) a lobe's face turned from the sun counts as lying
// between it and the sun, so its far side falls into shade even with the
// sun high; and how far apart the taps that find the face are (m, near and
// far).
const float FACE_SHADE = 70.0;
const vec2 FACE_TAP = vec2(2.5, 7.0);
// The march: its most steps; a step's length in the heaps (m), from the
// eye out, growing by STEP_GROW of the distance; the envelope's steepest
// slope, so a leap through the clear air over it never passes into a heap.
const int STEPS = 72;
const vec2 STEP = vec2(2.0, 14.0);
const float STEP_GROW = 0.012;
const float SLOPE = 1.6;
// How far over the envelope a bump can stand (m): over that, clear air.
const float OVER = LOBE * 0.6 + WISP * 0.5 + FINE_SWELL * 0.6 + 2.0;
// Each style's pull toward its own palette (Opal, Storybook, Mystic), and
// at night toward the style's own moonlit sea.
const vec3 STYLE_TINT = vec3(0.3, 0.0, 0.45);
const float NIGHT_TINT = 0.4;
// The air (m): the near heaps go into the haze over AIR, the land under
// the gaps into the deep blue air over LAND_AIR of its own (so it reads
// far below and clear, not drowned).
const float AIR = 2600.0;
const float LAND_AIR = 4000.0;
// The heaps a little brighter than a tower's light by day, so their sunlit
// tops read as white cloud from above.
const float LIFT = 1.2;

// The heaps' envelope: how high they stand over their feet (0 to 1) at
// world `xz`, the Storybook sea's domes (their finer octave as its mean:
// the cauliflower is the finer form now).
float sea_rise(vec2 xz) {
	vec2 drifted = xz + DRIFT * zs_motion_time;
	vec2 p = drifted / CELL;
	float mass;
	float h;
	if (envelope_at.w > 0.5) {
		vec2 baked = texture(envelope, (drifted - envelope_at.xy) / envelope_at.z).rg;
		mass = baked.r * 2.0 - 1.0;
		h = baked.g;
	} else {
		mass = zs_storybook_sea_gnoise(p * 0.23 + vec2(3.1, 7.7)) * 0.7 + zs_storybook_sea_gnoise(p * 0.51 + vec2(8.3, 1.9)) * 0.3;
		h = zs_storybook_sea_domes(p) * 0.62 + 0.38 * 0.45;
	}
	float heap = smoothstep(-0.2, 0.3, mass);
	// Under the islands: the heap-field full and the heaps higher.
	float lift = 0.0;
	for (int i = 0; i < 8; i++) {
		if (islands[i].z <= 0.0) break;
		float d = length(xz - islands[i].xy);
		lift = max(lift, 1.0 - smoothstep(islands[i].z * SWELL_REACH.x, islands[i].z * SWELL_REACH.y, d));
	}
	heap = mix(heap, 1.0, lift * 0.85);
	// Round a range's foot: the heap-field full and the heaps up over
	// where its rock is cut (SEA), so it always goes down into cloud.
	float foot = 0.0;
	for (int i = 0; i < 4; i++) {
		if (ranges[i].z <= 0.0) break;
		float d = length(xz - ranges[i].xy);
		foot = max(foot, 1.0 - smoothstep(ranges[i].z * 0.6, ranges[i].z, d));
	}
	heap = mix(heap, 1.0, 0.9 * foot);
	float rise = max(h * (0.35 + 0.65 * heap) - (1.0 - heap) * 0.55, 0.0);
	rise *= 1.0 + max(lift, foot) * SWELL / tall;
	// Under a falling glide the heaps part round the point below the eye.
	float part = zs_sea_flight.w;
	if (part > 0.0) {
		float fray = zs_storybook_sea_gnoise(p * 3.1 + vec2(8.2, 2.9)) * 18.0;
		float d = length(xz - eye_xz) + fray;
		rise *= mix(1.0, smoothstep(part * 130.0, part * 130.0 + 45.0, d), smoothstep(0.0, 0.25, part));
	}
	return rise;
}

// The envelope's top (m) at world `xz`.
float sea_top(vec2 xz) {
	return floor_y + tall * sea_rise(xz);
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


// How far into the heaps a point is (m, below 0 outside): under the
// envelope's top (`env`, at `rise`), swollen by the cauliflower `n` (red
// the bumps, bigger toward the crown, `hh` 0 at the feet to 1 there; green
// the wisps). The gaps (rise 0) stay clear.
float heap_inside(vec3 p, float env, float rise, vec2 n, float hh) {
	float lobe = smoothstep(0.0, 0.15, rise);
	return env - p.y + lobe * (mix(0.4, 1.0, hh) * LOBE * (n.r - 0.45) + (n.g - 0.5) * WISP);
}

vec2 noise_at(vec3 p, vec3 boil) {
	if (has_noise < 0.5) return vec2(0.45, 0.5);
	return texture(cauliflower, (p + boil) / TILE).rg;
}

// How far into the heaps a point is, all worked out at it.
float inside_at(vec3 p, vec3 boil) {
	float rise = sea_rise(p.xz);
	float env = floor_y + tall * rise;
	float hh = clamp((p.y - floor_y) / max(env - floor_y, 4.0), 0.0, 1.0);
	return heap_inside(p, env, rise, noise_at(p, boil), hh);
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

	// Radians per pixel, for how fine the land below can be drawn.
	float pixel = max(length(fwidth(rd)), 1e-5);
	float jitter = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	vec3 sun = normalize(zs_sun_direction + vec3(0.0, 1e-4, 0.0));
	// The towers' light (shaders/cumulus_light.gdshaderinc).
	vec3 c_sun_hue;
	vec3 c_sun;
	vec3 c_shade;
	float lining;
	zs_cumulus_palette(rd, sun, c_sun_hue, c_sun, c_shade, lining);
	float day_shadow = smoothstep(0.02, 0.2, sun.y) * (1.0 - smoothstep(0.35, 0.9, zs_cloud.x));
	// What lights the lobes' faces: the sun, and once it is down the moon.
	vec3 key = normalize(mix(sun, zs_moon_direction + vec3(0.0, 1e-4, 0.0), smoothstep(0.05, -0.1, sun.y)));
	vec3 boil = BOIL * zs_motion_time;

	float T = 1.0;
	vec3 lit = vec3(0.0);
	float met = 0.0;
	float crown = 0.0;
	float bright = 0.0;
	float t = t_in;
	bool started = false;
	// The face of the lobe the ray first meets, found once.
	bool faced = false;
	vec3 face = vec3(0.0, 1.0, 0.0);
	for (int i = 0; i < STEPS; i++) {
		if (t >= t_end || T < 0.03) break;
		vec3 p = eye + rd * t;
		float rise = sea_rise(p.xz);
		float env = floor_y + tall * rise;
		float over = p.y - env - OVER;
		if (over > 0.0) {
			// Clear air over the heaps: leap.
			t += clamp(over / (abs(rd.y) + SLOPE * level), STEP.x, 160.0);
			continue;
		}
		float step = clamp(STEP.x + t * STEP_GROW, STEP.x, STEP.y);
		if (!started) {
			started = true;
			t += step * jitter;
			if (t >= t_end) break;
			p = eye + rd * t;
			rise = sea_rise(p.xz);
			env = floor_y + tall * rise;
		}
		float hh = clamp((p.y - floor_y) / max(env - floor_y, 4.0), 0.0, 1.0);
		vec2 n = noise_at(p, boil);
		float inside = heap_inside(p, env, rise, n, hh);
		// The finer bumps, close to the eye only.
		float fine = (1.0 - smoothstep(FINE_NEAR * 0.6, FINE_NEAR, t)) * has_noise;
		if (fine > 0.0) inside += fine * smoothstep(0.0, 0.15, rise) * FINE_SWELL * (texture(cauliflower, (p + boil * 1.6 + 71.0) / FINE).r - 0.45);
		// Crisper close to the eye, so flying over it the edge is never a blur.
		float soft = mix(SOFT.y, SOFT.x, hh) * mix(0.5, 1.0, smoothstep(40.0, 300.0, t));
		float density = zs_cumulus_density(inside, soft, n.g);
		// The feet thin into the gap below them; close to the eye it thins away.
		density *= smoothstep(floor_y - 1.0, floor_y + 10.0, p.y);
		density *= smoothstep(NEAR_FADE.x, NEAR_FADE.y, t);
		if (density > 0.002) {
			// The face of the lobe where the ray first meets the cloud (four
			// taps, once): its slope lights the lobe, a lit side toward the
			// sun and a shaded one away, open to the sky on top and darker
			// under its bulge; what lies behind it along the ray takes the
			// same face.
			if (!faced) {
				faced = true;
				float e = mix(FACE_TAP.x, FACE_TAP.y, smoothstep(60.0, 900.0, t));
				float here = inside_at(p, boil);
				vec3 grad = vec3(inside_at(p + vec3(e, 0.0, 0.0), boil), inside_at(p + vec3(0.0, e, 0.0), boil), inside_at(p + vec3(0.0, 0.0, e), boil)) - here;
				if (dot(grad, grad) > 1e-6) face = -normalize(grad);
			}
			float turned = smoothstep(-0.3, 0.85, dot(face, key));
			float up_open = clamp(face.y * 0.6 + 0.5, 0.0, 1.0);
			vec3 q2 = p + key * 35.0;
			vec3 q3 = p + key * 90.0;
			float o2 = clamp((sea_top(q2.xz) - q2.y + 10.0) / 35.0, 0.0, 1.0);
			float o3 = clamp((sea_top(q3.xz) - q3.y + 10.0) / 35.0, 0.0, 1.0);
			// The islands' shadows, by day.
			float island = island_shadow(p, sun) * day_shadow;
			float thick = (1.0 - turned) * FACE_SHADE + o2 * 50.0 + o3 * 80.0 + island * 140.0;
			float deep = smoothstep(0.0, 30.0, inside);
			vec3 col = zs_cumulus_shade(c_sun, c_shade, lining, thick, up_open, hh, deep, density);
			float alpha = 1.0 - exp(-density * SIGMA * step);
			lit += T * alpha * col;
			met += T * alpha * t;
			crown += T * alpha * hh;
			bright += T * alpha * zs_cumulus_sunlit(thick) * up_open;
			T *= 1.0 - alpha;
		}
		t += step;
	}
	float cloud_a = 1.0 - T;
	if (cloud_a > 1e-4) {
		lit /= cloud_a;
		met /= cloud_a;
		crown /= cloud_a;
		bright /= cloud_a;
	}
	// The ray goes down to the floor with light still left: the land shows
	// through the gaps (and, the steps spent on a long low look, through
	// what was not marched, which is mostly the clear air of gaps).
	bool ground = rd.y < 0.0 && t_end >= t_floor - 0.5 && t_floor < t_reach && t_floor < t_solid && T >= 0.03;
	if (!ground && cloud_a < 0.003) discard;
	float t_seen = (cloud_a > 0.5 || !ground) ? met : t_floor;

	// The sky's colours as the dome's sea takes them.
	vec2 flat_dir = normalize(rd.xz + 1e-5);
	float deep_night = zs_night * zs_celestial_clear;
	float dim = mix(1.0, 0.4, deep_night);
	vec3 horizon = zsSkyBase(vec3(flat_dir.x, 0.0, flat_dir.y)) * dim;
	vec3 below = zsSkyBase(rd) * dim;
	float dull = smoothstep(0.35, 0.9, zs_cloud.x);
	vec3 sun_c = max(zs_cloud_sun, vec3(1e-4));
	vec3 sun_hue = sun_c / max(max(sun_c.r, sun_c.g), sun_c.b);
	vec2 bearing = normalize(sun.xz + vec2(1e-4, 0.0));
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


	// The towers' light on the heaps, tinted toward the style's own.
	vec3 col = lit * mix(1.0, LIFT, zs_daylight);
	float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
	float tint = cloud_sea_style == 0 ? STYLE_TINT.x : (cloud_sea_style == 2 ? STYLE_TINT.z : STYLE_TINT.y);
	vec3 style_hue = lit_col / max(dot(lit_col, vec3(0.2126, 0.7152, 0.0722)), 1e-3);
	col = mix(col, luma * style_hue, tint);
	// At night the style's own moonlit sea, its lit and shaded sides where
	// the towers' light falls and does not, so the heaps read as cloud
	// under the moon, never as dark ground.
	vec3 painted = mix(shade_col, lit_col, bright);
	col = mix(col, painted, NIGHT_TINT * zs_night);
	if (cloud_sea_style == 0) {
		// Opal's mother-of-pearl over the rims and crowns.
		float play = crown * 1.7 + dot(flat_dir, bearing) * 0.3 + rd.y * 1.1 + met * 0.0006 + zs_motion_time * 0.002;
		col *= mix(vec3(1.0), zs_opal_sea_opal(play), SEA_OPAL * (0.35 + 0.4 * crown + 0.65 * min(lining, 1.0)) * mix(1.0, 0.35, dull));
	}
	// Air between the eye and the far heaps, by the metre.
	col = mix(col, haze_col, (1.0 - exp(-met / AIR)) * 0.85);

	float alpha = cloud_a;
	if (ground) {
		// A gap: the Opal dome's land far below (fields, woods, a river,
		// coasts and the blue ocean), so the near sea opens onto the same
		// world the far one does, in every style.
		float t_ground = (SEA - GROUND - eye.y) / rd.y;
		vec2 gp = (eye.xz + rd.xz * t_ground) / GROUND_UNIT;
		float gfoot = t_ground * pixel / GROUND_UNIT;
		float light_level = clamp(dot(lit_col, vec3(0.2126, 0.7152, 0.0722)), 0.05, 1.0);
		vec3 lamp = normalize(mix(sun, zs_moon_direction, zs_night * zs_celestial_clear));
		float glint = pow(0.5 + 0.5 * dot(flat_dir, normalize(lamp.xz + 1e-4)), 8.0) * smoothstep(-0.05, 0.2, lamp.y) * mix(1.0, 0.5, zs_night) * (1.0 - dull);
		vec3 land = zs_opal_sea_land_lit(gp / SEA_LAND.x, gfoot / SEA_LAND.x, light_level, pearl, glint);
		// The deep air between: more of it the farther the land, and in
		// dull weather and low light.
		float deep_veil = max(1.0 - exp(-t_ground / LAND_AIR), max(0.5 * dull, 0.35 * max(golden, zs_night)));
		land = mix(land, deep_air, deep_veil);
		if (cloud_sea_style == 2) {
			// Mystic's faint light from the deep, breathing slowly.
			float patch = smoothstep(0.4, 0.8, zs_mystic_sea_noise(gp * 0.6 + zs_motion_time * vec2(0.003, 0.002)));
			land += mix(vec3(1.0), sun_hue, 0.5) * vec3(0.75, 1.0, 1.0) * patch * 0.05 * (1.0 - zs_daylight * 0.5);
		}
		// Detail the pixel can no longer hold settles to the sea's mean.
		land = mix(land, mix(mid_col, deep_air, 0.4), smoothstep(0.5, 1.2, t_floor * pixel / CELL));
		land = mix(land, haze_col, (1.0 - exp(-t_floor / AIR)) * 0.6);
		col = col * cloud_a + land * T;
		alpha = 1.0;
	}
	col = zs_sky_season_grade(col, mood * (1.0 - SEA_SEASON_NIGHT * zs_night));

	vec3 pos = eye + rd * t_seen;
	float far = length(pos.xz - eye.xz);
	alpha *= cloud_sea;
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
