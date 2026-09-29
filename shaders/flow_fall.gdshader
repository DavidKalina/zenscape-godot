shader_type spatial;
render_mode cull_disabled, diffuse_lambert;
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
// The rings come from the script every frame (smoothed), so the mesh itself
// only carries ring and angle indices.

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
varying float aeration;

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
	float chop = 1.0 + aer * (sin(tau * 19.0 - t * 7.5 + angle * 4.0 + fall_seed * 3.0) * 0.11
		+ sin(tau * 13.0 - t * 5.1 + angle * 7.0 + fall_seed) * 0.08 - 0.11);
	VERTEX = centers_tau[r].xyz + axis_a_width[r].xyz * cos(angle) * axis_a_width[r].w * swell * chop
		+ axis_b_thick[r].xyz * sin(angle) * axis_b_thick[r].w * swell * chop;
	float drop = tau / max(total, 0.0001);
	VERTEX.xz += zs_wind_direction * 0.18 * gale * drop * drop * steep;
	VERTEX += zs_fall_gust_offset(VERTEX, drop, steep);
	glass = 1.0 - aer;
	aeration = aer;
	travel = ring_travel[r];
	across = angle / 6.2831853;
	int face_ring = min(int(UV2.x), ring_count - 2);
	float sw = section_white[int(UV2.y) % 12];
	float face_aer = aer_steep[face_ring].x;
	float band = fract(centers_tau[face_ring].w * 1.8 - zs_flow_time * 1.6 + sw * 0.35);
	float white = 0.04 + body_white * face_aer + sw * (0.06 + 0.3 * face_aer) + face_aer * 0.66 + face_aer * gale * 0.12 + (band > 0.72 ? 0.16 * face_aer : 0.0);
	COLOR.rgb = mix(ramp[clamp(int(floor(white * 7.0)), 0, 6)], vec3(0.47932018, 0.60382734, 0.67244316), zs_ice * 0.85);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Streaks: noise stretched down the fall and running down it fast.
	float run = zs_flow_time * streak_speed * (1.0 - zs_ice * 0.98);
	vec2 streak_uv = vec2(across * 22.0 + fall_seed, travel * 0.9 - run * 0.9);
	float streak = zs_noise(streak_uv) * 0.65 + zs_noise(vec2(across * 47.0 + 3.1, travel * 2.1 - run * 2.1)) * 0.35;
	// A trickle is torn into strands: gaps open between the streaks, more so
	// at the sheet's edges and low down where it has broken up.
	float edge = abs(cos(across * 6.2831853));
	float torn = veil * (0.55 + 0.35 * edge + 0.25 * aeration);
	if (streak < torn * 0.85 && travel > crest * 0.5) discard;
	// Falling free past the block: strands, then beads, then gone.
	float broken = clamp((travel - break_from) / max(break_length, 0.01), 0.0, 1.0);
	if (broken > 0.0) {
		float beads = zs_noise(vec2(across * 64.0 + fall_seed * 1.7, travel * 4.5 - run * 4.5));
		float keep = mix(streak, beads, smoothstep(0.3, 0.75, broken));
		if (keep < mix(0.3, 1.02, broken) + 0.12 * edge * broken) discard;
	}
	float white_crest = (1.0 - smoothstep(crest * 0.5, crest, travel)) * (0.55 + 0.45 * smoothstep(0.3, 0.6, zs_noise(vec2(across * 30.0 + fall_seed, zs_flow_time * 1.3))));
	vec3 tint = (COLOR.rgb * zs_palette_water) * base_color.rgb;
	float bright = smoothstep(0.5, 0.8, streak) * (0.35 + 0.5 * aeration) + 0.5 * broken;
	tint = mix(tint, vec3(0.88792312, 0.93011086, 0.93868573) * zs_palette_water, clamp(bright + white_crest * 0.9, 0.0, 1.0) * (1.0 - zs_ice * 0.85));
	vec3 face = normalize(cross(dFdx(world_position), dFdy(world_position)));
	vec3 eye = normalize(CAMERA_POSITION_WORLD - world_position);
	if (dot(face, eye) < 0.0) face = -face;
	vec3 view_face = normalize((VIEW_MATRIX * vec4(face, 0.0)).xyz);
	NORMAL = faceforward(view_face, -VIEW, view_face);
	ALBEDO = tint;
	EMISSION = vec3(0.07 * (1.0 - 0.5 * zs_ice), 0.12 * (1.0 - 0.4 * zs_ice), 0.14) * (0.12 + 0.88 * zs_daylight);
	EMISSION += tint * mix(zs_hemi_ground, zs_hemi_sky, face.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	// Aerated water scatters light: in a cliff's shadow a foaming fall still glows.
	EMISSION += tint * (0.08 + 0.4 * aeration + 0.3 * white_crest) * (0.25 + 0.75 * zs_daylight) * (1.0 - zs_ice * 0.7);
	EMISSION += zs_afterglow(world_position, face, tint);
	float g = smoothstep(0.45, 1.0, glass) * (1.0 - white_crest);
	float fresnel = (0.02 + 0.98 * pow(1.0 - clamp(dot(face, eye), 0.0, 1.0), 5.0)) * g * g * 0.55;
	vec3 reflected = reflect(-eye, face);
	vec3 sky = scene_linear_for_display(clamp(zsSkyGradient(vec3(reflected.x, abs(reflected.y), reflected.z)), vec3(0.0), vec3(0.98)));
	EMISSION = mix(EMISSION, sky, fresnel);
	inversion_transmit = zs_inversion_paint(world_position, EMISSION) * (1.0 - fresnel);
	ROUGHNESS = 0.55 - 0.25 * zs_ice;
}

#include "res://shaders/reference_direct_light.gdshaderinc"
