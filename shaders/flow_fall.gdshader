shader_type spatial;
render_mode cull_disabled, diffuse_lambert, depth_draw_always;
// A waterfall the live water finds (scripts/flow_falls.gd, docs/scenic/
// water-flow.md "Waterfalls"). The source fall's look (reference_fall.gdshader,
// waterfall.js buildStrand): a faceted swept tube flattened into a sheet, glass
// at the lip beaten white by the fall, facet columns striped down the flow and
// foam bands running down it. Driven by the flow instead of a record:
// - `veil` (0 a full curtain, 1 a trickle) tears the sheet into falling
//   streaks with gaps between them;
// - `streak_speed` (m/s) is how fast those streaks fall;
// - `crest` (m of travel) is the white break where the water tips over;
// - `break_from` and `break_length` (m of travel): an edge fall
//   (scripts/edge_falls.gd) pours off the block into the void, and past the
//   block's bottom it breaks up over break_length into strands, then
//   droplets, then nothing (off by default: break_from is far away).
// - `end_travel` and `end_fade`: where the curtain ends (m of travel), and
//   how much it fades out over its last END_FADE m there (1 where it lands on
//   running water rather than in a pool, so it has no open end in the air).
// The rings come from the script every frame (smoothed), so the mesh itself
// only carries ring and angle indices.
//
// Close up it must read as water (2026-09-29 playtest: "a bit strange up
// close"): opaque and flat-shaded, the source's strand read as crumpled white
// paper, and its discarded streaks aliased into hairs. So:
// - glass is translucent and aerated water opaque (ALPHA from aeration). Only
//   the half of the tube facing the eye is drawn, so the translucent sheet
//   never shows its own back wall through its front (the reason the source
//   kept it opaque, waterfall.js);
// - the facets are shaded half way to the sheet's smooth normal, so they
//   still read as the painted facets but no longer as folds;
// - the tears and streaks are coverage, not discard, antialiased with fwidth,
//   and any noise finer than about a pixel fades to its mean (as the
//   rainbow's bands do, reference_sky_common zsRainbow).

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
varying float glass;
varying vec3 world_position;
varying float travel;
varying float across;
// Metres across the sheet from its centre line: the front and back of the
// tube share it, so their streaks line up instead of weaving through holes.
varying float lateral;
varying float aeration;
// The sheet's smooth outward normal (world), unnormalised; its sign against
// the eye says which half of the tube a fragment is on.
varying vec3 sheet_normal;

uniform int ring_count = 2;
uniform vec4 centers_tau[32];
uniform vec4 axis_a_width[32];
uniform vec4 axis_b_thick[32];
uniform vec2 aer_steep[32];
// Metres along the course at each ring (for the streaks, in real distance).
uniform float ring_travel[32];
uniform float section_white[12];
uniform float fall_seed = 0.0;
uniform float body_white = 0.0;
uniform float veil = 0.0;
uniform float streak_speed = 3.0;
uniform float crest = 0.3;
uniform float break_from = 100000.0;
uniform float break_length = 3.0;
uniform float end_travel = 100000.0;
uniform float end_fade = 0.0;
const float END_FADE = 0.35;
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
	// Chop in the aerated water, gentler than the source's (0.11 and 0.08): on
	// a sheet a few metres tall its folds read as blocky crumples.
	float chop = 1.0 + aer * (sin(tau * 19.0 - t * 7.5 + angle * 4.0 + fall_seed * 3.0) * 0.05
		+ sin(tau * 13.0 - t * 5.1 + angle * 7.0 + fall_seed) * 0.035 - 0.05);
	VERTEX = centers_tau[r].xyz + axis_a_width[r].xyz * cos(angle) * axis_a_width[r].w * swell * chop
		+ axis_b_thick[r].xyz * sin(angle) * axis_b_thick[r].w * swell * chop;
	float drop = tau / max(total, 0.0001);
	VERTEX.xz += zs_wind_direction * 0.18 * gale * drop * drop * steep;
	VERTEX += zs_fall_gust_offset(VERTEX, drop, steep);
	glass = 1.0 - aer;
	aeration = aer;
	travel = ring_travel[r];
	across = angle / 6.2831853;
	lateral = cos(angle) * axis_a_width[r].w;
	// An ellipse's normal: (cos / a, sin / b), scaled by a·b so a sheet with
	// no thickness still has one.
	sheet_normal = (MODEL_MATRIX * vec4(axis_a_width[r].xyz * cos(angle) * max(axis_b_thick[r].w, 0.002)
		+ axis_b_thick[r].xyz * sin(angle) * max(axis_a_width[r].w, 0.002), 0.0)).xyz;
	int face_ring = min(int(UV2.x), ring_count - 2);
	float sw = section_white[int(UV2.y) % 12];
	float face_aer = aer_steep[face_ring].x;
	float band = fract(centers_tau[face_ring].w * 1.8 - zs_flow_time * 1.6 + sw * 0.35);
	float white = 0.04 + body_white * face_aer + sw * (0.06 + 0.3 * face_aer) + face_aer * 0.66 + face_aer * gale * 0.12 + (band > 0.72 ? 0.16 * face_aer : 0.0);
	COLOR.rgb = mix(ramp[clamp(int(floor(white * 7.0)), 0, 6)], vec3(0.47932018, 0.60382734, 0.67244316), zs_ice * 0.85);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 1 where a noise of `uv` holds detail coarser than a pixel, fading to 0 as a
// pixel spans a whole noise cell (then it would only alias).
float fall_detail(vec2 uv) {
	vec2 w = fwidth(uv);
	return 1.0 - smoothstep(0.3, 0.9, max(w.x, w.y));
}

// The share of a pixel a streak `value` above `edge` covers, antialiased.
float fall_cover(float value, float edge) {
	float aa = max(fwidth(value), 0.015);
	return smoothstep(edge - aa, edge + aa, value);
}

void fragment() {
	vec3 eye = normalize(CAMERA_POSITION_WORLD - world_position);
	vec3 smooth_n = normalize(sheet_normal);
	float near_side = dot(smooth_n, eye);
	// Streaks: noise stretched down the fall and running down it fast, a
	// hand's width apart (in metres, not around the tube: a narrow fall got
	// two dozen hair-thin strings). Each octave fades to its mean once it is
	// finer than a pixel.
	float run = zs_flow_time * streak_speed * (1.0 - zs_ice * 0.98);
	vec2 streak_uv = vec2(lateral * 7.0 + fall_seed, travel * 0.9 - run * 0.9);
	vec2 fine_uv = vec2(lateral * 15.0 + 3.1, travel * 1.6 - run * 1.6);
	float coarse_detail = fall_detail(streak_uv);
	float fine_detail = fall_detail(fine_uv);
	float streak = mix(0.5, zs_noise(streak_uv), coarse_detail) * 0.7 + mix(0.5, zs_noise(fine_uv), fine_detail) * 0.3;
	// Only a real trickle is torn into strands: gaps open between the
	// streaks, more so at the sheet's edges and low down where it has broken
	// up. Squared, so a middling spring stays one sheet. Seen from far off the
	// strands blur into a thinner veil instead of shimmering.
	float edge = abs(cos(across * 6.2831853));
	float torn = veil * veil * (0.55 + 0.35 * edge + 0.25 * aeration);
	float tear_cover = mix(1.0 - torn * 0.6, fall_cover(streak, torn * 0.85), coarse_detail);
	float cover = travel > crest * 0.5 ? tear_cover : 1.0;
	// Falling free past the block: strands, then beads, then gone.
	// (Derivatives are taken outside any branch and before any discard.)
	float broken = clamp((travel - break_from) / max(break_length, 0.01), 0.0, 1.0);
	vec2 bead_uv = vec2(lateral * 18.0 + fall_seed * 1.7, travel * 4.5 - run * 4.5);
	float bead_detail = fall_detail(bead_uv);
	float beads = mix(0.5, zs_noise(bead_uv), bead_detail);
	float keep = mix(streak, beads, smoothstep(0.3, 0.75, broken));
	float threshold = mix(0.3, 1.02, broken) + 0.12 * edge * broken;
	float bead_cover = mix(1.0 - smoothstep(0.2, 1.0, threshold), fall_cover(keep, threshold), min(coarse_detail, bead_detail));
	if (broken > 0.0) cover *= bead_cover;
	// It meets the running water it lands on instead of ending in the air.
	cover *= 1.0 - end_fade * smoothstep(end_travel - END_FADE, end_travel, travel);
	vec2 crest_uv = vec2(lateral * 9.0 + fall_seed, zs_flow_time * 1.3);
	float crest_noise = mix(0.45, smoothstep(0.3, 0.6, zs_noise(crest_uv)), fall_detail(crest_uv));
	float white_crest = (1.0 - smoothstep(crest * 0.5, crest, travel)) * (0.55 + 0.45 * crest_noise);
	vec3 tint = (COLOR.rgb * zs_palette_water) * base_color.rgb;
	float bright = smoothstep(0.45, 0.9, streak) * (0.2 + 0.4 * aeration) + 0.5 * broken;
	tint = mix(tint, vec3(0.88792312, 0.93011086, 0.93868573) * zs_palette_water, clamp(bright + white_crest * 0.9, 0.0, 1.0) * (1.0 - zs_ice * 0.85));
	vec3 face = normalize(cross(dFdx(world_position), dFdy(world_position)));
	if (dot(face, eye) < 0.0) face = -face;
	if (near_side < 0.0) smooth_n = -smooth_n;
	// Facets half way to the smooth sheet: painted, not crumpled.
	face = normalize(mix(smooth_n, face, 0.45));
	// Only the half of the tube facing the eye: the back wall seen through a
	// translucent front muddied every facet. Edge on, both halves stay.
	if (near_side < -0.02 || cover < 0.02) discard;
	vec3 view_face = normalize((VIEW_MATRIX * vec4(face, 0.0)).xyz);
	NORMAL = faceforward(view_face, -VIEW, view_face);
	ALBEDO = tint;
	EMISSION = vec3(0.07 * (1.0 - 0.5 * zs_ice), 0.12 * (1.0 - 0.4 * zs_ice), 0.14) * (0.12 + 0.88 * zs_daylight);
	EMISSION += tint * mix(zs_hemi_ground, zs_hemi_sky, face.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	// Aerated water scatters light: in a cliff's shadow a foaming fall still glows.
	EMISSION += tint * (0.08 + 0.4 * aeration + 0.3 * white_crest) * (0.25 + 0.75 * zs_daylight) * (1.0 - zs_ice * 0.7);
	EMISSION += zs_afterglow(world_position, face, tint);
	float g = smoothstep(0.45, 1.0, glass) * (1.0 - white_crest);
	float facing = clamp(dot(face, eye), 0.0, 1.0);
	float fresnel = (0.02 + 0.98 * pow(1.0 - facing, 5.0)) * g * g * 0.55;
	vec3 reflected = reflect(-eye, face);
	vec3 sky = scene_linear_for_display(clamp(zsSkyGradient(vec3(reflected.x, abs(reflected.y), reflected.z)), vec3(0.0), vec3(0.98)));
	EMISSION = mix(EMISSION, sky, fresnel);
	// Glass shows what is behind it, a thin veil more so; aerated water and
	// the white break are opaque; edge on, any water is.
	float white = clamp(smoothstep(0.3, 0.8, aeration) + bright * 0.6 + white_crest, 0.0, 1.0);
	float glass_alpha = mix(0.62, 0.42, veil) + 0.35 * pow(1.0 - facing, 3.0);
	ALPHA = clamp(mix(glass_alpha, 1.0, max(white, zs_ice)), 0.0, 1.0) * cover;
	inversion_transmit = zs_inversion_paint(world_position, EMISSION) * (1.0 - fresnel);
	ROUGHNESS = 0.55 - 0.25 * zs_ice;
}

#include "res://shaders/reference_direct_light.gdshaderinc"
