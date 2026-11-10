shader_type spatial;
render_mode cull_disabled, diffuse_lambert, depth_draw_always;
// The curtain's waterfall sheet (scripts/endless/world/wilderness/
// waterfall.gd): a tall fall the plane punches through, with a cave behind
// it. The falls' ring mesh and its swept, flattened tube (flow_fall.gdshader's
// vertex stage, unchanged), painted for a sheet 60 m tall seen from the
// valley rather than a spill seen close:
// - the water is the world's (zs_palette_water over the water ramp): clear
//   teal glass at the lip under a white crest, whitening down the fall in
//   streaks rather than all at once;
// - the streaks come in three sizes: bands a few metres wide that slide down
//   slowly and still read from the valley, then hand-width and finger-width
//   ones that fade to their mean once finer than a pixel;
// - below `thin_from` (m of travel) the sheet thins over `thin_length` to
//   `thin_cover` (the streaks) and `thin_glass` (the glass between them): the
//   glass goes nearly clear and the streaks tear, so the dark mouth behind
//   shows through;
// - only the half of the tube facing the eye is drawn (discarded by the
//   sheet's smooth normal), so the thin sheet never doubles its own alpha.

global uniform vec3 zs_palette_water;
uniform vec4 base_color : source_color = vec4(1.0);
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/reference_water_gust.gdshaderinc"
#include "res://shaders/reference_cloud_field.gdshaderinc"
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
#include "res://shaders/reference_alpenglow.gdshaderinc"
#include "res://shaders/reference_inversion.gdshaderinc"
uniform float metalness_value = 0.0;
varying float inversion_transmit;
varying vec3 world_position;
varying float travel;
varying float lateral;
// 0 on the sheet's centre line, 1 at its sides.
varying float edge;
varying vec3 sheet_normal;

uniform int ring_count = 2;
uniform vec4 centers_tau[32];
uniform vec4 axis_a_width[32];
uniform vec4 axis_b_thick[32];
uniform vec2 aer_steep[32];
uniform float ring_travel[32];
uniform float fall_seed = 0.0;
uniform float streak_speed = 3.0;
// m of travel: the white break at the lip.
uniform float crest = 0.6;
// m of travel from the lip to where it lands (the face's last ring).
uniform float face_travel = 60.0;
// The share of the sheet that is white streaks at the lip and at the foot.
uniform float white_top = 0.12;
uniform float white_low = 0.5;
// m across one of the broad bands.
uniform float band_width = 2.4;
// The glass's alpha (0 clear, 1 opaque), and the streaks'.
uniform float glass_alpha = 0.58;
uniform float foam_alpha = 0.96;
uniform float thin_from = 100000.0;
uniform float thin_length = 8.0;
uniform float thin_cover = 0.35;
// The share of its alpha the glass keeps there.
uniform float thin_glass = 0.45;
const vec3 ramp[7] = vec3[7](vec3(0.02842604, 0.21223076, 0.33245154), vec3(0.07036010, 0.33245154, 0.47932018), vec3(0.15896084, 0.47932018, 0.61049557), vec3(0.30054379, 0.63759687, 0.73046074), vec3(0.50888132, 0.78353779, 0.85499261), vec3(0.71569350, 0.87962240, 0.92158186), vec3(0.88792312, 0.93011086, 0.93868573));

void vertex() {
	int r = min(int(UV.x), ring_count - 1);
	float angle = UV.y;
	float tau = centers_tau[r].w;
	float total = centers_tau[ring_count - 1].w;
	vec3 impact = centers_tau[ring_count - 1].xyz;
	float gale = zs_wind_at(impact.xz) * (1.0 - zs_ice);
	float steep = aer_steep[r].y;
	float aer = aer_steep[r].x;
	float t = zs_flow_time;
	float swell = 1.0 + sin(tau * 5.0 - t * 2.4 + angle * 2.0 + fall_seed) * (0.02 + steep * 0.06)
		+ sin(tau * 9.0 - t * 3.6 + angle * 3.0 + fall_seed) * (0.01 + steep * 0.04);
	float chop = 1.0 + aer * (sin(tau * 19.0 - t * 7.5 + angle * 4.0 + fall_seed * 3.0) * 0.05
		+ sin(tau * 13.0 - t * 5.1 + angle * 7.0 + fall_seed) * 0.035 - 0.05);
	VERTEX = centers_tau[r].xyz + axis_a_width[r].xyz * cos(angle) * axis_a_width[r].w * swell * chop
		+ axis_b_thick[r].xyz * sin(angle) * axis_b_thick[r].w * swell * chop;
	float drop = tau / max(total, 0.0001);
	VERTEX.xz += zs_wind_direction * 0.18 * gale * drop * drop * steep;
	VERTEX += zs_fall_gust_offset(VERTEX, drop, steep);
	travel = ring_travel[r];
	lateral = cos(angle) * axis_a_width[r].w;
	edge = abs(cos(angle));
	sheet_normal = (MODEL_MATRIX * vec4(axis_a_width[r].xyz * cos(angle) * max(axis_b_thick[r].w, 0.002)
		+ axis_b_thick[r].xyz * sin(angle) * max(axis_a_width[r].w, 0.002), 0.0)).xyz;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 1 where a noise of `uv` holds detail coarser than a pixel, fading to 0 as a
// pixel spans a whole noise cell (then it would only alias).
float fall_detail(vec2 uv) {
	vec2 w = fwidth(uv);
	return 1.0 - smoothstep(0.3, 0.9, max(w.x, w.y));
}

// The share of a pixel a streak `value` above `at` covers, antialiased.
float fall_cover(float value, float at) {
	float aa = max(fwidth(value), 0.02);
	return smoothstep(at - aa, at + aa, value);
}

void fragment() {
	vec3 eye = normalize(CAMERA_POSITION_WORLD - world_position);
	vec3 smooth_n = normalize(sheet_normal);
	float near_side = dot(smooth_n, eye);
	float run = zs_flow_time * streak_speed * (1.0 - zs_ice * 0.98);
	float down = clamp(travel / max(face_travel, 0.01), 0.0, 1.0);
	// Three sizes of streak, each stretched down the fall and sliding down it
	// (the broad bands slower, so they read as the sheet's shape, not flicker).
	vec2 band_uv = vec2(lateral / band_width + fall_seed, travel * 0.035 - run * 0.02);
	vec2 mid_uv = vec2(lateral * 2.2 + fall_seed * 1.3, travel * 0.22 - run * 0.22);
	vec2 fine_uv = vec2(lateral * 6.5 + 3.1, travel * 0.8 - run * 0.8);
	float band = mix(0.5, zs_noise(band_uv), fall_detail(band_uv));
	float mid = mix(0.5, zs_noise(mid_uv), fall_detail(mid_uv));
	float fine_d = fall_detail(fine_uv);
	float fine = mix(0.5, zs_noise(fine_uv), fine_d);
	float water = band * 0.55 + mid * 0.3 + fine * 0.15;
	// White streaks: the share of the sheet above a threshold that falls as the
	// water whitens down the fall (value noise bunches round 0.5, so the
	// thresholds sit close to it).
	float share = mix(white_top, white_low, smoothstep(0.0, 0.6, down));
	float edge_at = 0.5 + 0.2 * (1.0 - 2.0 * share);
	float foam = fall_cover(water, edge_at);
	// Seen from far off the streaks blur toward their share instead of shimmering.
	foam = mix(share, foam, max(fall_detail(band_uv * 6.0), 0.35));
	vec2 crest_uv = vec2(lateral * 1.6 + fall_seed, zs_flow_time * 1.3);
	float white_crest = (1.0 - smoothstep(crest * 0.4, crest, travel)) * (0.6 + 0.4 * smoothstep(0.3, 0.6, zs_noise(crest_uv)));
	foam = clamp(max(foam, white_crest), 0.0, 1.0);
	// The glass: clear teal at the lip, paler and bluer down the fall, the
	// broad bands shading it so the sheet has a shape between the streaks.
	vec3 glass_tint = mix(ramp[2], ramp[3], clamp(down * 0.8 + (band - 0.5) * 1.2, 0.0, 1.0));
	vec3 foam_tint = mix(ramp[5], ramp[6], smoothstep(0.5, 0.8, water));
	vec3 tint = mix(glass_tint, foam_tint, foam) * zs_palette_water * base_color.rgb;
	tint = mix(tint, vec3(0.47932018, 0.60382734, 0.67244316), zs_ice * 0.85);
	// Thinning low down: the glass goes nearly clear and the streaks tear.
	float thin = smoothstep(thin_from, thin_from + thin_length, travel);
	float torn = fall_cover(mid * 0.6 + fine * 0.4, 0.38 * thin);
	vec3 face = normalize(cross(dFdx(world_position), dFdy(world_position)));
	if (dot(face, eye) < 0.0) face = -face;
	if (near_side < 0.0) smooth_n = -smooth_n;
	face = normalize(mix(smooth_n, face, 0.2));
	vec3 view_face = normalize((VIEW_MATRIX * vec4(face, 0.0)).xyz);
	NORMAL = faceforward(view_face, -VIEW, view_face);
	ALBEDO = tint;
	EMISSION = vec3(0.05, 0.09, 0.11) * (0.12 + 0.88 * zs_daylight);
	EMISSION += tint * mix(zs_hemi_ground, zs_hemi_sky, face.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	// The foam scatters light: in the alcove's shade a white streak still glows.
	EMISSION += tint * (0.03 + 0.3 * foam) * (0.25 + 0.75 * zs_daylight) * (1.0 - zs_ice * 0.7);
	EMISSION += zs_afterglow(world_position, face, tint);
	float facing = clamp(dot(face, eye), 0.0, 1.0);
	float g = 1.0 - foam;
	float fresnel = (0.02 + 0.98 * pow(1.0 - facing, 5.0)) * g * 0.5;
	vec3 reflected = reflect(-eye, face);
	vec3 sky = scene_linear_for_display(clamp(zsSkyGradient(vec3(reflected.x, abs(reflected.y), reflected.z)), vec3(0.0), vec3(0.98)));
	EMISSION = mix(EMISSION, sky, fresnel);
	float glass_a = mix(glass_alpha, glass_alpha * thin_glass, thin) + 0.3 * pow(1.0 - facing, 3.0) * (1.0 - 0.6 * thin);
	float foam_a = foam_alpha * mix(1.0, thin_cover + (1.0 - thin_cover) * torn, thin);
	float a = mix(mix(glass_a, foam_a, foam), 1.0, zs_ice);
	// The sheet's sides feather out rather than ending on a hard wall.
	a *= 1.0 - 0.7 * smoothstep(0.8, 1.0, edge);
	ALPHA = clamp(a, 0.0, 1.0);
	inversion_transmit = zs_inversion_paint(world_position, EMISSION) * (1.0 - fresnel);
	ROUGHNESS = 0.5 - 0.25 * zs_ice;
	if (near_side < 0.0) discard;
}

#include "res://shaders/reference_direct_light.gdshaderinc"
