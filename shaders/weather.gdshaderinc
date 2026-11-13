// The weather's globals and its rain field on the GPU (scripts/endless/
// weather.gd, the contract at its top; keep the numbers equal). Include once
// per shader: it declares the globals.
//   zs_weather      (build, severity, rain here, wet)
//   zs_weather_sky  (cover, wind, clear_sky, rain_level)
//   zs_rain_field   (drift.x, drift.y, rain_level, floor)
//   zs_lightning    (latest flash x, z, seconds since, strength)
// A compute shader (GLSL) takes zs_rain_field through its own uniforms and
// copies zs_weather_hash .. zs_rain_field_at as they are.

global uniform vec4 zs_weather;
global uniform vec4 zs_weather_sky;
global uniform vec4 zs_rain_field;
global uniform vec4 zs_lightning;

const float ZS_RAIN_CELL = 2600.0;
const vec2 ZS_RAIN_EDGE = vec2(0.42, 0.72);
const int ZS_RAIN_PERIOD = 256;

float zs_weather_hash(ivec2 i) {
	uint x = uint(((i.x % ZS_RAIN_PERIOD) + ZS_RAIN_PERIOD) % ZS_RAIN_PERIOD);
	uint y = uint(((i.y % ZS_RAIN_PERIOD) + ZS_RAIN_PERIOD) % ZS_RAIN_PERIOD);
	uint h = x * 374761393u + y * 668265263u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h = h ^ (h >> 16u);
	return float(h & 0xffffffu) / 16777215.0;
}

float zs_weather_vnoise(vec2 q) {
	vec2 i = floor(q);
	vec2 f = q - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	ivec2 c = ivec2(i);
	float a = zs_weather_hash(c);
	float b = zs_weather_hash(c + ivec2(1, 0));
	float d = zs_weather_hash(c + ivec2(0, 1));
	float e = zs_weather_hash(c + ivec2(1, 1));
	return mix(mix(a, b, u.x), mix(d, e, u.x), u.y);
}

// The cells alone at xz `p` (0..1).
float zs_rain_cell_at(vec2 p, vec4 field) {
	vec2 q = (p + field.xy) / ZS_RAIN_CELL;
	vec2 q2 = (p + field.xy * 0.5) / ZS_RAIN_CELL * 2.0;
	float n = 0.65 * zs_weather_vnoise(q) + 0.35 * zs_weather_vnoise(q2);
	return smoothstep(ZS_RAIN_EDGE.x, ZS_RAIN_EDGE.y, n);
}

// The rain at xz `p` (0..1), as Weather.rain_at.
float zs_rain_field_at(vec2 p, vec4 field) {
	if (field.z <= 0.0) return 0.0;
	return field.z * mix(field.w, 1.0, zs_rain_cell_at(p, field));
}

float zs_rain_at(vec2 p) {
	return zs_rain_field_at(p, zs_rain_field);
}
