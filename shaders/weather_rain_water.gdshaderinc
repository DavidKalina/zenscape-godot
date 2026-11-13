// Rain on the water (the sea, shaders/endless_sea.gdshader, and the rivers
// and lakes, shaders/endless_ground.gdshader), where it rains (zs_rain_at;
// lifted from the old storm's storm_rain_water.gdshaderinc):
// - zs_rain_pocks: rings spreading from each drop, as a slope to add to the
//   water's own before its normal. Three layers of cells, each cell one ring
//   at a time on its own beat, a few lit as the rain is heavy (ZS_RING_SHARE)
//   and each brief; near only (the rings fade as a pixel grows past a few
//   tens of cm).
// - zs_rain_beaten: the colour beaten matte: a little greyed where it rains
//   (ZS_RAIN_MATTE), and near the eye a faint lighter splash as a drop lands
//   and on its ring's crest, only while the pixel is fine enough to draw
//   them (a fleck wider than its drop is averaged away, not drawn big).
// - zs_wx_mirror / zs_wx_water_fill: under an overcast (zs_weather_sky.x)
//   the water's mirror of the dome and the cloud field, and its body's fill,
//   brought down: the weather lifts the land's fill and the dome for the
//   land, and the water took both at a low angle as a pale cyan-white
//   sheet. 1 with no cover (fair, --weather=off).
// No rain anywhere (fair, or --weather=off): one global read.
#ifndef ZS_WEATHER_RAIN_WATER
#define ZS_WEATHER_RAIN_WATER

#include "res://shaders/weather.gdshaderinc"

// The share of each layer's cells that land a drop a beat at a rain of 1.
const float ZS_RING_SHARE = 0.35;
// How much of the splash's and crest's light reaches the colour.
const float ZS_RAIN_SPLASH = 0.5;
// The water greyed (toward its own luma) by a rain of 1.
const float ZS_RAIN_MATTE = 0.35;
// The mirror of the sky under a whole cover, and the body's fill.
const float ZS_WX_MIRROR = 0.36;
const float ZS_WX_WATER_FILL = 0.45;

float zs_wx_mirror() {
	return mix(1.0, ZS_WX_MIRROR, clamp(zs_weather_sky.x, 0.0, 1.0));
}

float zs_wx_water_fill() {
	return mix(1.0, ZS_WX_WATER_FILL, clamp(zs_weather_sky.x, 0.0, 1.0));
}

float zs_rain_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// One layer: cells `cell` m, `rate` drops a second each. The ring's slope,
// and in `light` its splash and crest (0..1).
vec2 zs_rain_ring_layer(vec2 p, float cell, float rate, float t, float rain, float seed, float footprint, out float light) {
	vec2 q = p / cell + seed;
	vec2 id = floor(q);
	vec2 f = fract(q);
	float h = zs_rain_hash(id);
	float h2 = zs_rain_hash(id + 17.3);
	float h3 = zs_rain_hash(id + 41.9);
	float beat = t * rate * (0.8 + 0.4 * h3) + h;
	float age = fract(beat);
	// A fresh drop each beat: where it lands moves, and it lands only in a
	// share of the cells, more as the rain is heavier.
	float n = floor(beat);
	float lands = step(zs_rain_hash(id + n * 0.37), rain * ZS_RING_SHARE);
	vec2 at = 0.3 + 0.4 * vec2(zs_rain_hash(id + n * 1.13 + 3.1), zs_rain_hash(id + n * 0.71 + 8.2));
	vec2 to = f - at;
	float r = length(to);
	float radius = age * 0.26;
	// The ring as sharp as the pixel lets it be (cell units).
	float px = footprint / cell;
	float x = (r - radius) * clamp(0.45 / max(px, 1e-4), 9.0, 38.0);
	// A ring of two crests, damped as it grows and gone early; the slope runs
	// outward.
	float wave = -sin(x * 3.14159) * exp(-x * x * 0.35);
	float life = 1.0 - age;
	float fade = life * life * life * smoothstep(0.0, 0.04, age);
	// The light only while the pixel is finer than the drop's splash (a few
	// cm); wider, it would draw each splash as a pixel-sized white dot.
	float sharp = 1.0 - smoothstep(0.02, 0.07, footprint);
	float fleck = (1.0 - smoothstep(0.0, 0.12, age)) * (1.0 - smoothstep(0.012, 0.025, r * cell));
	light = lands * sharp * (0.6 * fleck + 0.5 * fade * exp(-x * x * 0.8));
	return lands * wave * fade * (to / max(r, 1e-3)) * mix(0.8, 1.2, h2);
}

// The rain at `p` for the water: zero without a read of the field when none
// falls anywhere.
float zs_rain_on_water(vec2 p) {
	if (zs_rain_field.z <= 0.0) return 0.0;
	return zs_rain_at(p);
}

// The rings' slope at `p` (world xz), the rain there (zs_rain_on_water), the
// pixel's footprint (m) and the clock (s).
vec2 zs_rain_pocks(vec2 p, float rain, float footprint, float t) {
	if (rain <= 0.001) return vec2(0.0);
	float seen = 1.0 - smoothstep(0.05, 0.3, footprint);
	if (seen <= 0.0) return vec2(0.0);
	float l0, l1, l2;
	vec2 s = zs_rain_ring_layer(p, 1.4, 1.3, t, rain, 0.0, footprint, l0)
		+ zs_rain_ring_layer(p, 1.1, 1.7, t, rain, 5.3, footprint, l1)
		+ zs_rain_ring_layer(p + 0.35, 1.8, 1.1, t, rain, 11.7, footprint, l2);
	return s * 0.35 * seen;
}

// `color` beaten by the rain (zs_rain_on_water at `p`): greyed a little, and
// near the eye a faint splash toward `pale` (in `color`'s own space).
vec3 zs_rain_beaten(vec3 color, vec3 pale, vec2 p, float rain, float footprint, float t) {
	if (rain <= 0.001) return color;
	float light = 0.0;
	if (footprint < 0.07) {
		float l0, l1, l2;
		zs_rain_ring_layer(p, 1.4, 1.3, t, rain, 0.0, footprint, l0);
		zs_rain_ring_layer(p, 1.1, 1.7, t, rain, 5.3, footprint, l1);
		zs_rain_ring_layer(p + 0.35, 1.8, 1.1, t, rain, 11.7, footprint, l2);
		light = clamp(l0 + l1 + l2, 0.0, 1.0);
	}
	// Matte: the beaten surface's mirror broken, its colour greyed toward its
	// own brightness (never lighter).
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	color = mix(color, vec3(luma), rain * ZS_RAIN_MATTE);
	return mix(color, pale, light * ZS_RAIN_SPLASH);
}

#endif
