shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;
// The unified cloud volume's composite (scripts/cloud_volume.gd): a sheet
// over the whole screen, drawn in the see-through pass where the near sea
// drew (its render priority), that reads the march's light terms
// (shaders/cloud_volume_march.glsl, resolved to the render's size over
// frames by shaders/cloud_volume_resolve.glsl) and colours them as the
// near sea did (shaders/sky_sea.gdshader): the towers' light
// (shaders/cumulus_light.gdshaderinc) in the sky's own colours, tinted
// toward the player's sea style, Opal's mother-of-pearl on the crowns, the
// haze over the far heaps, the land far below through the gaps, and the
// season's grade. The towers keep their own air instead (shaders/
// sky_tower.gdshader): the glide's haze toward the dome's colour and the
// sun's aureole, so a far tower goes pale and blue as before. The sun's
// phase and its scattering octaves are the march's; here only colour.
#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/cumulus_light.gdshaderinc"
#define ZS_CLOUD_SEA_SHADE
#include "res://shaders/sky_cloud_sea.gdshaderinc"
#include "res://shaders/glide_haze.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"

uniform sampler2D cloud_light : filter_nearest, repeat_disable;
uniform sampler2D cloud_shape : filter_nearest, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
// The heaps' feet and their reach (as scripts/sky_sea.gd), for the land
// seen through the gaps.
uniform float floor_y = -150.0;
uniform float reach = 2400.0;
// The light the cloud's lit side faces (the sun, the moon at night).
uniform vec3 key_light = vec3(0.0, 1.0, 0.0);
// 1 under the cloud sea (scripts/sky_below.gd): the heaps are seen from
// beneath, in the lower world's deck colours (zsBelowDeck); 0 leaves them
// as they are above.
uniform float from_below = 0.0;

const float SEA = -105.0;
const float CELL = 72.0;
const float GROUND = 700.0;
const float GROUND_UNIT = 100.0;
const vec3 STYLE_TINT = vec3(0.3, 0.0, 0.45);
// Night light round 1: the style's painted moonlit sea leads at night (was
// 0.4), so the heaps, towers and puffs read moonlit and cool, lit on the
// moon's side and shaded on the other, not near-day white.
const float NIGHT_TINT = 0.72;
const float AIR = 2600.0;
const float LAND_AIR = 4000.0;
const float LIFT = 1.25;
// The in-cloud glow (shaders/sky_tower.gdshader GLOW).
const float GLOW = 1.4;
// The light off the sea below on a tower's flanks: the sea's sunlit white,
// a touch cooler.
const vec3 BOUNCE_TINT = vec3(0.92, 0.96, 1.0);
// The towers' haze reach (scripts/sky_towers.gd HAZE_FAR).
const float TOWER_HAZE_FAR = 1.0;
// From beneath: the heaps' hearts and rims against the deck's mean, and the
// distance (m) over which they settle into it.
const float BELOW_HEART = 0.7;
const float BELOW_RIM = 1.12;
// At night the hearts are softly lit, the moon through the thin cloud.
const float BELOW_NIGHT_HEART = 0.8;
const vec3 BELOW_NIGHT_GLOW = vec3(0.022, 0.018, 0.04);
const float BELOW_AIR = 1600.0;
// The lowest hanging hearts' hue, cool and a breath of violet, and the thin
// rims' light lit through, against the deck's mean.
const vec3 BELOW_HEART_HUE = vec3(0.9, 0.9, 1.06);
const float BELOW_SILVER = 1.25;

// The glide's haze on a tower (glide_haze.gdshaderinc zs_glide_fog_far at
// the towers' TOWER_HAZE_FAR), its low-down thickening written with the
// edges in order.
float tower_fog(float dist, float y) {
	float low = 1.0 - smoothstep(zs_glide_haze.w, zs_glide_haze.w + 75.0, y);
	float far = dist * (1.0 + 0.6 * low) / (max(zs_glide_haze.y, 1.0) * mix(1.0, ZS_PEAK_REACH, TOWER_HAZE_FAR));
	float whole = zs_glide_haze.z * mix(1.0, ZS_PEAK_WHOLE, TOWER_HAZE_FAR);
	return 1.0 - exp(-far * far) * (1.0 - smoothstep(whole * 0.72, whole, dist));
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec3 eye = CAMERA_POSITION_WORLD;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, 1.0, 1.0);
	vec3 rd = normalize(mat3(INV_VIEW_MATRIX) * (view.xyz / view.w));
	float depth = texture(depth_texture, SCREEN_UV).r;
	float t_solid = 1e9;
	if (depth > 0.0) {
		vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
		t_solid = length(behind.xyz / behind.w);
	}
	// The resolved cloud, at the render's size.
	ivec2 here = min(ivec2(FRAGCOORD.xy), textureSize(cloud_light, 0) - 1);
	vec4 a = texelFetch(cloud_light, here, 0);
	vec4 b = texelFetch(cloud_shape, here, 0);
	float cloud_a = clamp(b.x, 0.0, 1.0);
	float T = 1.0 - cloud_a;

	float level = max(length(rd.xz), 1e-4);
	float t_reach = reach / level;
	float t_floor = rd.y < 0.0 ? (floor_y - eye.y) / rd.y : 1e9;
	// The dome's land through the gaps only from over the heaps' feet: from
	// under them (the lower world, scripts/sky_below.gd) the floor is behind
	// the eye and what lies below is real.
	bool ground = cloud_sea > 0.0 && rd.y < 0.0 && t_floor > 0.0 && t_floor < t_reach && t_floor < t_solid && T >= 0.03;
	float t_wall;
	vec4 wall = zs_front_wall(eye, rd, t_solid, TIME, t_wall);
	float t_shaft;
	vec4 shaft = zs_cell_shaft(eye, rd, t_solid, TIME, t_shaft);
	if (!ground && cloud_a < 0.003 && wall.a < 0.003 && shaft.a < 0.003) discard;

	float pixel = max(length(fwidth(rd)), 1e-5);
	vec3 sun = normalize(zs_sun_direction + vec3(0.0, 1e-4, 0.0));
	vec3 c_sun_hue;
	vec3 c_sun;
	vec3 c_shade;
	float lining;
	zs_cumulus_palette(rd, sun, c_sun_hue, c_sun, c_shade, lining);
	float toward_sun = max(dot(rd, sun), 0.0);
	vec3 glow_col = mix(vec3(0.95, 0.97, 1.0), c_sun_hue, 0.3) * GLOW;
	vec3 lit = vec3(0.0);
	float met = 0.0;
	float crown = 0.0;
	float bright = 0.0;
	float tower = 0.0;
	if (cloud_a > 1e-4) {
		vec4 terms = a / cloud_a;
		lit = (terms.x * c_shade + terms.y * c_sun + terms.z * c_sun * BOUNCE_TINT) * ZS_CUMULUS_LIT_SHARE;
		tower = clamp(terms.w, 0.0, 1.0);
		float glow = b.w / cloud_a;
		lit += glow_col * glow * (1.0 + 0.7 * pow(toward_sun, 3.0));
		met = b.y / cloud_a;
		crown = b.z / cloud_a;
		bright = clamp(terms.y / 0.95, 0.0, 1.0);
	}
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
	if (from_below > 0.0) {
		// From beneath: the heaps' undersides take the deck's own colours,
		// their far ones settling into the deck's mean as the painted deck
		// past them does (shaders/sky_below_ceiling.gdshader), so the
		// handover never shows. Near, they have shape: the lobes hanging
		// lowest are the thickest cloud over the eye and the darkest, cool
		// and a little violet in their hearts; they lighten as they rise
		// toward the gaps, and their thin rims are lit through, silver,
		// warm toward a low sun and faintly pearled, so each gap is ringed
		// with light.
		const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
		vec3 deck = zsBelowDeck(rd);
		float deep = zs_night * zs_celestial_clear;
		float v = smoothstep(0.12, 1.0, dot(col, LUMA) / max(dot(lit_col, LUMA), 1e-3));
		float toward = zsBelowToSun(rd) * (1.0 - deep);
		float golden_below = zsBelowGolden();
		// How low the underside hangs where it is seen (1 its lowest, at the
		// heaps' feet), and how thin the cloud is there (its rims).
		float hang = 1.0 - smoothstep(floor_y + 5.0, SEA - 15.0, eye.y + rd.y * met);
		float thin = 1.0 - smoothstep(0.3, 0.97, cloud_a);
		float heart = mix(BELOW_HEART, BELOW_NIGHT_HEART, deep) * mix(1.08, 0.86, hang);
		vec3 hearts = deck * heart * mix(vec3(0.95, 0.96, 1.04), BELOW_HEART_HUE, hang * (0.5 + 0.5 * golden_below));
		vec3 sunlit = mix(vec3(1.0), mix(vec3(1.0), zsBelowSunHue(), 0.65) * 1.08, (0.2 + 0.6 * golden_below) * toward);
		vec3 rims = deck * BELOW_RIM * sunlit;
		// The rims' pearl: a slow play of hue along them, lavender to a cool
		// sea-green, never strong.
		float play = met * 0.0011 + dot(flat_dir, bearing) * 0.8 + rd.y * 1.7 + zs_motion_time * 0.004;
		vec3 pearl_tint = mix(vec3(1.025, 0.985, 1.035), vec3(0.97, 1.025, 1.02), 0.5 + 0.5 * sin(play * 6.2832));
		vec3 silver = deck * BELOW_SILVER * sunlit * mix(vec3(1.0), pearl_tint, 1.0 - 0.5 * deep);
		vec3 under = mix(hearts, rims, max(v, (1.0 - hang) * 0.45));
		under = mix(under, silver, thin * (1.0 - deep * 0.4));
		// At night the thin rims hold a faint violet glow, the deck's own.
		under += BELOW_NIGHT_GLOW * max(v, thin) * deep;
		under = mix(under, deck, 1.0 - exp(-met / BELOW_AIR));
		// Overhead, the bellies are seen as the display's own colours, as
		// the painted deck writes them, so the hearts keep their shade; seen
		// low, the heaps' flanks stay as light as the air they stand in.
		float belly = smoothstep(0.3, 0.75, rd.y) * (1.0 - 0.6 * deep);
		under = mix(under, scene_linear_for_display(clamp(under, vec3(0.0), vec3(0.98))), belly);
		col = mix(col, under, from_below);
		haze_col = mix(haze_col, deck, from_below);
	}
	// Air between the eye and the far heaps, by the metre.
	col = mix(col, haze_col, (1.0 - exp(-met / AIR)) * 0.85 * (1.0 - from_below));
	// The towers in their own air (shaders/sky_tower.gdshader): the glide's
	// haze toward the dome's colour along the ray, the sun's aureole round
	// it, and gone where the haze is whole.
	float alpha = cloud_a;
	if (tower > 0.0) {
		float tower_haze = tower_fog(met, eye.y + rd.y * met) * zs_glide_haze.x;
		vec3 toward = normalize(vec3(rd.x, max(rd.y, 0.0) + 0.01, rd.z));
		float sun_away = sqrt(max(2.0 * (1.0 - dot(toward, sun)), 0.0));
		float high = smoothstep(0.02, 0.4, sun.y);
		vec3 air = zsSkyBase(toward) + mix(vec3(1.0, 0.42, 0.12), vec3(1.0, 0.8, 0.52), high) * exp(-sun_away / 0.16) * mix(0.16, 0.07, high) * zs_celestial_clear;
		vec3 tower_col = mix(lit * mix(1.0, LIFT, zs_daylight), air, tower_haze);
		tower_col = mix(tower_col, painted, NIGHT_TINT * zs_night);
		col = mix(col, tower_col, tower);
		alpha = cloud_a * mix(1.0, 1.0 - smoothstep(0.8, 1.0, tower_haze), tower);
	}
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
		// Far off, low toward the horizon, the land fades into the dome's
		// veil (shaders/sky_sea.gdshader), as the near sea did.
		float veiled = smoothstep(-0.02, -0.16, rd.y) * mix(1.0, smoothstep(-0.34, -0.66, rd.y), deep_night);
		float keep = mix(1.0, veiled, smoothstep(150.0, 700.0, t_floor));
		alpha = cloud_a + T * keep;
		col = (col * cloud_a + land * T * keep) / max(alpha, 1e-4);
	}
	col = zs_sky_season_grade(col, mood * (1.0 - SEA_SEASON_NIGHT * zs_night));

	alpha = clamp(alpha, 0.0, 1.0);
	// The front's rain wall, before or behind the cloud as it stands.
	if (wall.a > 0.0) {
		if (alpha < 0.003 || t_wall < t_seen) {
			float over = wall.a + alpha * (1.0 - wall.a);
			col = (wall.rgb * wall.a + col * alpha * (1.0 - wall.a)) / max(over, 1e-4);
			alpha = over;
		} else {
			float over = alpha + wall.a * (1.0 - alpha);
			col = (col * alpha + wall.rgb * wall.a * (1.0 - alpha)) / max(over, 1e-4);
			alpha = over;
		}
	}
	// A storm cell's rain shaft, the same.
	if (shaft.a > 0.0) {
		if (alpha < 0.003 || t_shaft < t_seen) {
			float over = shaft.a + alpha * (1.0 - shaft.a);
			col = (shaft.rgb * shaft.a + col * alpha * (1.0 - shaft.a)) / max(over, 1e-4);
			alpha = over;
		} else {
			float over = alpha + shaft.a * (1.0 - alpha);
			col = (col * alpha + shaft.rgb * shaft.a * (1.0 - alpha)) / max(over, 1e-4);
			alpha = over;
		}
	}
	if (alpha < 0.003) discard;
	col = zs_storm_graded_at(col, eye + rd * min(t_seen, 6000.0));
	ALBEDO = col;
	ALPHA = alpha;
}
