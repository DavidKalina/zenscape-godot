#ifndef ZS_SKY_SEASON
#define ZS_SKY_SEASON
// The plate's season in the sky layer. studies/fidelity.gd publishes
// zs_sky_season from WeatherScheduler.season_sky only when it changes: how
// much of each quarter the year stands in, (spring, summer, autumn, winter),
// summing to 1 and smooth all round the year. Its default, all spring, is the
// look the sky was drawn in.
//   The peaks' snow line (shaders/reference_surface.gdshader `peak_snow`):
//     each face of a range carries how far its line must come down before it
//     whitens (scripts/sky_peak.gd `_snow_need`), and the season says how
//     far it has come.
//   The cloud sea's mood (shaders/sky_cloud_sea.gdshaderinc), and the
//     peaks' foot that goes into it: a slight grade, never a new look.
//   The peaks' grass a little dry through the summer, with the plants'
//     own straw (reference_season zs_season_grass); spring's freshness,
//     autumn's gold and winter's straw are the plants' own already.
#include "res://shaders/reference_globals.gdshaderinc"
global uniform vec4 zs_sky_season;

// How far (m) each quarter brings the peaks' snow line down from where it
// was drawn (spring's, so 0): summer back to the summits and the high
// couloirs, autumn in between, winter low and generous. A snowy sky brings it
// down a little further as it snows (zs_snow).
const vec4 ZS_SKY_SNOW_FALL = vec4(0.0, -70.0, -40.0, 110.0);
const float ZS_SKY_SNOW_WEATHER = 40.0;

float zs_sky_snow_fall() {
	return dot(zs_sky_season, ZS_SKY_SNOW_FALL) + zs_snow * ZS_SKY_SNOW_WEATHER;
}

// A snowy face's colour: the world's snow, a touch blue in the hollows and
// nudged face by face, as scripts/sky_peak.gd packs it (`_snow_pack`): the
// whole part the nudge in 1/32 steps, the fraction how blue.
const float ZS_SKY_SNOW_JITTER = 0.03;
vec3 zs_sky_snow_colour(vec3 snow, float pack) {
	float blue = clamp(fract(pack) / 0.999, 0.0, 1.0);
	float nudge = (floor(pack) / 32.0 * 2.0 - 1.0) * ZS_SKY_SNOW_JITTER;
	return snow * vec3(mix(1.0, 0.93, blue), mix(1.0, 0.965, blue), 1.0) * (1.0 + nudge);
}

// The cloud's mood by quarter: a hue it leans to (luminance kept) and how
// much of its colour it keeps. Spring fresh and clear, summer warm and a
// touch hazy, autumn peachy, winter crisp and silvery. Small on purpose.
const vec3 ZS_SKY_MOOD_SPRING = vec3(0.988, 1.010, 1.000);
const vec3 ZS_SKY_MOOD_SUMMER = vec3(1.015, 1.000, 0.975);
const vec3 ZS_SKY_MOOD_AUTUMN = vec3(1.026, 0.996, 0.964);
const vec3 ZS_SKY_MOOD_WINTER = vec3(0.985, 0.998, 1.018);
const vec4 ZS_SKY_MOOD_KEEP = vec4(1.0, 0.96, 1.0, 0.85);
// Summer's haze lifts the darks a little toward the mean.
const float ZS_SKY_MOOD_HAZE = 0.05;

// `c` graded by the season, `amount` of the way (0 leaves it be).
// Premultiplied colours grade the same.
vec3 zs_sky_season_grade(vec3 c, float amount) {
	if (amount <= 0.0) return c;
	const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
	vec4 w = zs_sky_season;
	vec3 hue = w.x * ZS_SKY_MOOD_SPRING + w.y * ZS_SKY_MOOD_SUMMER + w.z * ZS_SKY_MOOD_AUTUMN + w.w * ZS_SKY_MOOD_WINTER;
	hue /= max(dot(hue, LUMA), 1e-3);
	float lum = dot(c, LUMA);
	vec3 graded = mix(vec3(lum), c, dot(w, ZS_SKY_MOOD_KEEP)) * hue;
	graded = mix(graded, vec3(lum) * hue, ZS_SKY_MOOD_HAZE * w.y);
	return max(mix(c, graded, amount), vec3(0.0));
}

// A peak's grass through the summer: a little toward the plants' straw,
// keyed on how green it is, as zs_season_grass is.
const float ZS_SKY_SUMMER_DRY = 0.2;
void zs_sky_summer_grass(inout vec3 color) {
	if (zs_sky_season.y <= 0.004) return;
	float green = clamp((color.g - max(color.r, color.b)) * 6.0, 0.0, 1.0);
	float lum = dot(color, vec3(0.30, 0.55, 0.15));
	color = mix(color, vec3(1.16, 0.98, 0.66) * lum, zs_sky_season.y * green * ZS_SKY_SUMMER_DRY);
}
#endif
