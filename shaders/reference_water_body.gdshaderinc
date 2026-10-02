
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/reference_water_gust.gdshaderinc"
#include "res://shaders/reference_rain_rings.gdshaderinc"
#include "res://shaders/reference_lake_chop.gdshaderinc"
#include "res://shaders/reference_lake_material.gdshaderinc"
#include "res://shaders/reference_lake_glint.gdshaderinc"
#include "res://shaders/reference_lake_algae.gdshaderinc"
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
#include "res://shaders/reference_tonemap.gdshaderinc"
#include "res://shaders/reference_lake_lighting.gdshaderinc"
#include "res://shaders/reference_ice.gdshaderinc"
#include "res://shaders/reference_cloud_field.gdshaderinc"
#include "res://shaders/reference_alpenglow.gdshaderinc"
#include "res://shaders/reference_inversion.gdshaderinc"
global uniform vec3 zs_palette_water;
#include "res://shaders/pool_caustics.gdshaderinc"
uniform bool hide_pool_surface = false;
// Levels (object space) that a planar reflection view draws instead; ponds
// at other levels keep the ordinary surface (scripts/planar_water.gd).
uniform vec2 planar_levels = vec2(-1000000.0);
varying float rest_height;
uniform bool planar_enabled = false;
uniform sampler2D planar_reflection : filter_linear, repeat_disable;
uniform mat4 reflection_matrix;
// Live water (scripts/water_flow_view.gd) has one planar view for all its
// ponds, at `planar_level` (object space, the mesh's rest height). With a
// band, water further than it from that level fades to the ordinary surface,
// so a second pond at another height does not take a displaced reflection.
uniform float planar_band = 0.0;
uniform float planar_level = 0.0;
// How fast the planar path's water hides the bed with depth (1 for the
// planned ponds, whose basins are a metre or more deep). Live ponds are
// shallower and take more, so a spring's pool reads as water, not the grass
// under it inside a ring of shore foam.
uniform float bed_absorb = 1.0;
// With `depth_tint`, still water takes its colour from a three-stop ramp by
// depth (light teal shallows, blue-teal, deep blue-teal), per pixel from the
// bed behind it under the planar view, and its bed fades out within
// `tint_depths.z` metres: by the vertex palette and `bed_absorb` alone a live
// pond read as clear glass over grass, with no deepening towards its middle.
// x: depth by which it is mid, y: by which it is deep.
uniform bool depth_tint = false;
uniform vec3 tint_shallow : source_color = vec3(0.42, 0.68, 0.62);
uniform vec3 tint_mid : source_color = vec3(0.25, 0.57, 0.59);
uniform vec3 tint_deep : source_color = vec3(0.18, 0.39, 0.47);
uniform vec3 tint_depths = vec3(0.3, 1.1, 0.22);
vec3 zs_depth_tint(float depth) {
	vec3 colour = mix(tint_shallow, tint_mid, smoothstep(0.0, tint_depths.x, depth));
	return mix(colour, tint_deep, smoothstep(tint_depths.x * 0.7, tint_depths.y, depth));
}
// How much of the bed shows through `depth` of tinted water, per channel:
// red goes first, so what shows is tinted teal.
vec3 zs_depth_tint_bed(float depth) {
	return exp(-max(depth, 0.0) / max(tint_depths.z, 0.01) * vec3(1.35, 1.0, 0.9));
}
// Live moving water lies over still water drawn everywhere wet; CUSTOM1.x
// fades it out towards the slow water round it, so the two meet softly.
uniform bool flow_edge_fade = false;
varying float flow_fade;
// Live still water carries its distance from dry ground in UV.x
// (ZenScapeWaterFlow::surface). With `shore_distance`, the shore foam keeps
// to the bank: a sheet a few centimetres deep lies wholly inside the lap's
// depth band, and by depth alone it would all read as foam.
uniform bool shore_distance = false;
varying float shore_run;
// Live moving water thinner than live_thin.y (fading in from live_thin.x) is
// a film running over the ground, not a stream: it darkens the ground as wet
// earth does, without the sky's sheen, foam or glint, so a sheet running
// down a steep face does not read as glass or ice. Off at (0, 0).
uniform vec2 live_thin = vec2(0.0);
// Live moving water carries its flow velocity (m/s, world xz) in CUSTOM1.yz
// (ZenScapeWaterFlow::surface). With `live_flow_map` its streaks are world
// noise smeared along the flow and slid down it in two cross-faded phases
// (a flow map), instead of waves along each vertex's own heading: where water
// lands and spreads, those headings fan out from a point and the waves drew
// starbursts of hair-thin lines. And a sheet on a face steeper than about
// 35-55 degrees is drawn as a wet film, not white water: on the 25 cm grid it
// stair-steps down a cliff in jagged terraces, and the fall's curtain
// (scripts/flow_falls.gd) is the water seen there.
uniform bool live_flow_map = false;
varying vec2 live_velocity;
// Live still water is drawn under the moving water everywhere wet, sheets on
// a face too. With `live_level` it fades out where its surface tilts (a pond
// lies level), so on a slope only the moving water's own look shows.
uniform bool live_level = false;
// With `shallow_clear` (m, 0 off; live still water), water shallower than it
// is clear: the ground under it shows through the blend itself, darkened and
// cooled by a thin layer of `shallow_body` as wet ground under clear water
// is, with less of the sky's sheen; the tinted body only comes in as the
// water deepens towards it. Without it a shelf a few centimetres deep stood
// nearly opaque, its body the screen's copy of the grass lit a second time,
// and read as a milky grey sheet.
uniform float shallow_clear = 0.0;
uniform vec3 shallow_body : source_color = vec3(0.03, 0.15, 0.16);
// Live waterfalls (scripts/flow_falls.gd) churn the water where they land and
// whiten it where they tip over: x, z, radius, strength each.
uniform vec4 fall_foam[8];
uniform int fall_foam_count = 0;
uniform sampler2D pond_screen : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D pond_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform float caustics_strength = 0.0;
uniform float metalness_value = 0.0;
varying float inversion_transmit;
uniform bool lake_display_lighting = true;
uniform bool lake_lighting_probe = false;
uniform bool lake_glints_enabled = true;
uniform bool opaque_water_probe = false;
uniform bool flowing = false;
uniform bool rain_rings_enabled = true;
uniform bool lake_wind_enabled = true;
uniform float level_drop = 0.0;
// Seconds a water-brush pond takes to rise to its level.
uniform float pond_fill_seconds = 3.2;
varying vec3 world_position;
varying float water_depth;
varying vec3 lake_state;
varying vec2 lake_local;
varying float cut_face;


void vertex() {
	rest_height = VERTEX.y;
	flow_fade = flow_edge_fade ? CUSTOM1.x : 1.0;
	live_velocity = live_flow_map ? CUSTOM1.yz : vec2(0.0);
	shore_run = shore_distance && !flowing ? UV.x : 1000.0;
	lake_local = VERTEX.xz;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	water_depth = max(UV2.x - level_drop, 0.0);
	cut_face = UV2.y;
	// Pin the shoreline and cut walls. Both wave trains follow the wind.
	float shore = smoothstep(0.015, 0.25, water_depth) * (1.0 - cut_face);
	vec2 p = world_position.xz;
	vec2 direction = zs_wind_direction;
	vec2 across = vec2(-direction.y, direction.x);
	float wave = sin(dot(p, direction) * 2.0 - zs_flow_time * 1.6)
		+ 0.45 * sin(dot(p, direction + across) * 1.8 - zs_flow_time * 2.1);
	// Water brush fills (scripts/water_brush.gd), on the emergence clock. A pond
	// carries its birth and rise in UV and comes up from below its level; a
	// stream carries its birth and run time in CUSTOM1.zw and its front runs
	// down the course. Water without a birth reads zero and stands full.
	if (!flowing && UV.y > 0.0) {
		float filled = clamp((zs_emergence_now() - UV.x) / max(pond_fill_seconds, 0.01), 0.0, 1.0);
		float below = UV.y * (1.0 - filled * (2.0 - filled));
		VERTEX.y -= below;
		water_depth = max(water_depth - below, 0.0);
	}
	float stream_front = 1.0;
	if (flowing && CUSTOM1.w > 0.0) {
		stream_front = clamp((zs_emergence_now() - CUSTOM1.z) / CUSTOM1.w, 0.0, 1.0) * 1.14;
	}
	if (flowing) {
		float arrived = smoothstep(CUSTOM0.w, CUSTOM0.w + 0.14, min(smoothstep(0.1, 0.7, zs_water_growth_now()), stream_front));
		VERTEX = mix(CUSTOM0.xyz, VERTEX, arrived);
		shore *= arrived;
		wave = sin(UV.x * 5.0 - zs_flow_time * 3.4 + UV.y * 2.0);
	}
	lake_state = vec3(0.0);
	if (flowing) {
		VERTEX.y += wave * (0.006 + zs_wind_at(p) * 0.018) * shore * (1.0 - zs_ice);
	} else if (cut_face < 0.5) {
		float swell = sin(zs_flow_time * 1.6 + VERTEX.x * 2.3 + VERTEX.z * 1.9) * 0.045;
		VERTEX.y += swell * lake_swell * (1.0 - zs_ice);
		if (lake_wind_enabled) {
			VERTEX.y += zs_lake_chop(VERTEX, world_position, water_depth, CUSTOM0, CUSTOM1, lake_state);
			VERTEX.y += zs_water_gust_height(world_position, water_depth);
		}
	}
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Foam in live moving water, 0..1: noise averaged along the flow (short
// streaks, longer the faster it runs) and carried down it, two phases half a
// period apart so neither is seen to reset. Fades to its mean where finer
// than a pixel.
float zs_live_flow_foam(vec2 p, vec2 velocity, float t) {
	float speed = length(velocity);
	vec2 heading = speed > 0.001 ? velocity / speed : vec2(0.0);
	float carry = min(speed, 2.5) * 0.7;
	float reach = clamp(speed * 0.3, 0.0, 0.5);
	const float PERIOD = 1.4;
	float detail = 1.0 - smoothstep(0.35, 0.9, max(fwidth(p.x), fwidth(p.y)) * 3.5);
	float pattern = 0.0;
	for (int layer = 0; layer < 2; layer++) {
		float phase = fract(t / PERIOD + 0.5 * float(layer));
		float weight = 1.0 - abs(2.0 * phase - 1.0);
		vec2 q = p - heading * carry * phase * PERIOD + float(layer) * vec2(17.3, 5.9);
		float smear = 0.0;
		for (int k = 0; k < 4; k++) smear += zs_noise((q - heading * reach * float(k) / 3.0) * 3.5);
		pattern += smear * 0.25 * weight;
	}
	// The average of four taps is flatter than one; stretch it back.
	pattern = clamp((pattern - 0.5) * (1.6 + reach) + 0.5, 0.0, 1.0);
	return mix(0.3, smoothstep(0.55, 0.8, pattern), detail);
}

void fragment() {
	if (hide_pool_surface && !flowing && cut_face < 0.5 && min(abs(rest_height - planar_levels.x), abs(rest_height - planar_levels.y)) < 0.02) discard;
	// A moving faceted surface catches light through its actual deformed faces.
	vec3 wave_normal = normalize(cross(dFdx(world_position), dFdy(world_position)));
	if (wave_normal.y < 0.0) { wave_normal = -wave_normal; }
	float level_face = live_level && !flowing ? smoothstep(0.82, 0.96, wave_normal.y) : 1.0;
	if (!flowing && cut_face < 0.5 && lake_wind_enabled) {
		wave_normal = zs_lake_fine_normal(wave_normal, world_position, water_depth, lake_state);
		wave_normal = zs_water_gust_normal(wave_normal, world_position, water_depth);
	}
	if (!flowing && cut_face < 0.5 && rain_rings_enabled) {
		wave_normal = zs_rain_ring_normal(wave_normal, world_position, zs_flow_time, zs_foliage_wet, zs_ice);
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(wave_normal, 0.0)).xyz);
	vec3 eye = normalize(CAMERA_POSITION_WORLD - world_position);
	vec3 reflected = reflect(-eye, wave_normal);
	float fresnel = (0.02 + 0.70 * pow(1.0 - max(dot(eye, wave_normal), 0.0), 5.0)) * (1.0 - cut_face);
	if (!flowing && source_lake_material) fresnel = zs_lake_reflection(dot(eye, wave_normal)) * (1.0 - cut_face);
	// Source vertex colors already contain the depth palette; retain it.
	vec3 body = COLOR.rgb * zs_palette_water;
	bool tinted = depth_tint && !flowing && cut_face < 0.5;
	// Under a tint, how opaque the water is for the bed it hides.
	float tint_alpha = 0.0;
	if (tinted) {
		body = zs_depth_tint(water_depth) * zs_palette_water;
		vec3 seen = zs_depth_tint_bed(water_depth);
		// Without the planar view the bed shows only through the blend:
		// thin water lets most of it through, or a broad shallow flat is a
		// milky sheet of the shallow colour over the grass.
		tint_alpha = mix(0.18, 0.97, smoothstep(0.0, 0.9, 1.0 - dot(seen, vec3(0.3, 0.4, 0.3))));
	}
	vec3 reflection = scene_linear_for_display(clamp(zsSkyGradient(vec3(reflected.x, abs(reflected.y), reflected.z)), vec3(0.0), vec3(0.98)));
	// Depth for the shoreline foam: the mesh's own, or where the planar path
	// reads the bed behind each pixel, the true per-pixel depth.
	float shore_depth = water_depth;
	float planar_weight = planar_enabled && cut_face < 0.5 ? 1.0 : 0.0;
	if (planar_band > 0.0) planar_weight *= 1.0 - smoothstep(planar_band * 0.5, planar_band, abs(rest_height - planar_level));
	if (planar_weight > 0.0) {
		float plain_fresnel = fresnel;
		vec3 plain_reflection = reflection;
		vec3 plain_body = body;
		float plain_shore = shore_depth;
		fresnel = 0.16 + 0.72 * pow(1.0 - max(dot(eye, wave_normal), 0.0), 3.0);
		vec4 projected = reflection_matrix * vec4(world_position, 1.0);
		vec2 uv = projected.xy / projected.w * vec2(0.5, -0.5) + 0.5;
		uv += wave_normal.xz * 0.12 * smoothstep(0.0, 0.3, water_depth);
		reflection = scene_linear_for_display(texture(planar_reflection, clamp(uv, vec2(0.001), vec2(0.999))).rgb);
		float depth = texture(pond_depth, SCREEN_UV).r;
		vec4 receiver_view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
		vec3 receiver = (INV_VIEW_MATRIX * vec4(receiver_view.xyz / receiver_view.w, 1.0)).xyz;
		float submerged = world_position.y - receiver.y;
		float shallows = smoothstep(0.04, 0.22, submerged) * (1.0 - smoothstep(0.8, 2.4, submerged));
		float caustics = zs_pool_caustics(receiver.xz, zs_flow_time) * shallows * caustics_strength * (1.0 - zs_ice) * zs_daylight * zs_celestial_clear;
		vec3 bed = textureLod(pond_screen, SCREEN_UV, 0.0).rgb * (1.0 + vec3(0.95, 0.90, 0.65) * caustics);
		if (tinted) {
			// The bed's own depth, so the colour deepens smoothly between
			// the mesh's vertices; the shallows are tinted towards teal.
			float bed_depth = max(submerged, 0.0);
			vec3 seen = zs_depth_tint_bed(bed_depth) * (1.0 - zs_ice);
			vec3 tinted_bed = bed * mix(vec3(1.0), tint_shallow / max(tint_shallow.g, 0.01), 0.5);
			body = mix(zs_depth_tint(bed_depth) * zs_palette_water, tinted_bed, seen);
			// The bed is in the body here: only the very edge lets the scene through.
			tint_alpha = mix(tint_alpha, 0.97 * smoothstep(0.0, 0.05, bed_depth), planar_weight);
		} else {
			vec3 absorption = exp(-vec3(2.0, 0.7, 0.45) * water_depth * bed_absorb);
			body = mix(body, bed * absorption + body * (1.0 - absorption), 1.0 - zs_ice);
		}
		shore_depth = min(shore_depth, max(submerged, 0.0));
		fresnel = mix(plain_fresnel, fresnel, planar_weight);
		reflection = mix(plain_reflection, reflection, planar_weight);
		body = mix(plain_body, body, planar_weight);
		shore_depth = mix(plain_shore, shore_depth, planar_weight);
	}
	// Clear shallows: how clear this pixel is, by its per-pixel depth where the
	// planar view reads the bed, else the mesh's.
	float clear = shallow_clear > 0.0 && tinted ? (1.0 - smoothstep(0.03, shallow_clear, shore_depth)) * (1.0 - zs_ice) : 0.0;
	body = mix(body, shallow_body * zs_palette_water, clear);
	fresnel *= 1.0 - 0.4 * clear;
	float glint = smoothstep(0.75, 1.0, zs_water_growth_now()) * pow(max(dot(reflect(-zs_sun_direction, wave_normal), eye), 0.0), 240.0) * zs_daylight * zs_celestial_clear;
	float foam = 0.0;
	float cascade = 0.0;
	if (flowing) {
		// Each wave fades to its mean where it is finer than a pixel (as the
		// rainbow's bands do): the live water's UV is each vertex's position
		// along its own flow, so where the flow turns or fans out (a plunge, a
		// rough face) it changes by metres across one facet, and these waves
		// drew fields of hair-thin aliased lines.
		float streak_phase = UV.x * 7.0 + sin(UV.y * 18.0) * 1.5;
		float broken_phase = UV.x * 2.3 + UV.y * 31.0;
		float streak_detail = 1.0 - smoothstep(0.5, 2.0, fwidth(streak_phase));
		float broken_detail = 1.0 - smoothstep(0.5, 2.0, fwidth(broken_phase));
		float streak = sin(streak_phase - zs_flow_time * 5.0);
		float broken = mix(0.5, 0.5 + 0.5 * sin(broken_phase - zs_flow_time * 1.4), broken_detail);
		foam = mix(0.12, smoothstep(0.65, 1.0, streak), streak_detail) * broken * 0.25 * smoothstep(0.01, 0.12, water_depth);
		if (live_flow_map) {
			float run = smoothstep(0.15, 1.2, length(live_velocity));
			foam = zs_live_flow_foam(world_position.xz, live_velocity, zs_flow_time) * (0.12 + 0.2 * run) * smoothstep(0.01, 0.12, water_depth);
		}
		// Live water pouring down a face is white water, as the fall it runs
		// beside (shaders/flow_fall.gdshader), not a pale glassy veil.
		else if (live_thin.y > 0.0) cascade = (1.0 - smoothstep(0.45, 0.8, wave_normal.y)) * smoothstep(live_thin.y * 0.6, live_thin.y * 1.6, water_depth);
		foam = max(foam, cascade * 0.6);
	}
	if (!flowing && cut_face < 0.5 && zs_look_shore > 0.0) {
		// Look pass: a thin broken foam line where still water meets the bank,
		// lapping in and out slowly with the wind.
		float lap = 0.035 + 0.02 * sin(zs_flow_time * 0.9 + zs_noise(world_position.xz * 0.6) * 6.2832) * (0.4 + min(zs_wind_strength, 1.0) * 0.6);
		float band = (1.0 - smoothstep(lap * 0.5, lap, shore_depth)) * (1.0 - smoothstep(0.2, 0.55, shore_run));
		float broken = smoothstep(0.35, 0.7, zs_noise(world_position.xz * 3.1 + vec2(zs_flow_time * 0.05, 0.0)));
		// Softer over clear shallows: a lap line, not a white crust.
		foam = max(foam, band * mix(0.35, 0.8, broken) * zs_look_shore * (1.0 - 0.4 * clear));
	}
	body = mix(body, vec3(0.65, 0.80, 0.79), foam * (1.0 - zs_ice));
	// Churn under a live fall, spreading outward in broken patches.
	float fall_churn = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= fall_foam_count) break;
		vec4 f = fall_foam[i];
		vec2 d = world_position.xz - f.xy;
		float r = length(d) / max(f.z, 0.01);
		if (r >= 1.0) continue;
		vec2 outward = d / max(length(d), 0.001);
		// Drifting outward in two phases that restart half a period apart
		// (a flow map): carried by the clock alone, after a minute the noise
		// at neighbouring angles lay metres apart, and the churn drew spokes
		// out of the plunge that grew finer every second.
		float spread = 0.0;
		float fine = 0.0;
		for (int layer = 0; layer < 2; layer++) {
			float phase = fract(zs_flow_time / 1.6 + 0.5 * float(layer));
			float weight = 1.0 - abs(2.0 * phase - 1.0);
			vec2 seed = float(i) * vec2(7.1, 3.3) + float(layer) * vec2(11.7, 4.9);
			spread += zs_noise((world_position.xz - outward * phase * 0.9) * 3.2 + seed) * weight;
			fine += zs_noise((world_position.xz - outward * phase * 1.4) * 7.5 + seed.yx) * weight;
		}
		float core = 1.0 - smoothstep(0.12, 0.42, r);
		float patches = smoothstep(0.42, 0.7, spread * 0.7 + fine * 0.3) * (1.0 - smoothstep(0.3, 1.0, r));
		fall_churn = max(fall_churn, clamp(core * (0.7 + 0.3 * fine) + patches, 0.0, 1.0) * f.w);
	}
	// Churn lies on fairly level water: painted on a face it was a white oval
	// hanging on the slope.
	fall_churn *= smoothstep(0.75, 0.92, wave_normal.y);
	body = mix(body, vec3(0.86, 0.92, 0.93), fall_churn * (1.0 - zs_ice));
	float absorption = 1.0 - exp(-water_depth / 0.45);
	float alpha = mix(0.40, 1.0, max(absorption, fresnel));
	if (flowing && live_thin.y > 0.0) {
		// Its vertex colour takes foam with speed, and a fast film is pale.
		float film = 1.0 - smoothstep(live_thin.x, live_thin.y, water_depth);
		float face = live_flow_map ? 1.0 - smoothstep(0.55, 0.82, wave_normal.y) : 0.0;
		// On a steep face the film replaces the body, its foam with it.
		film = max(film, face);
		body = mix(body, vec3(0.02, 0.09, 0.08) * zs_palette_water, film);
		fresnel *= 1.0 - film;
		glint *= 1.0 - film;
		alpha = mix(alpha, 0.28, film);
	}
	if (!flowing && source_lake_material) alpha = zs_lake_opacity(water_depth, zs_ice);
	if (tinted) alpha = max(alpha, tint_alpha);
	alpha = max(alpha, fall_churn * 0.95);
	alpha = max(alpha, cascade * 0.85);
	if (!flowing) zs_lake_algae(body, alpha, world_position, lake_local, water_depth, cut_face);
	if (!flowing && cut_face > 0.5) alpha = max(alpha, 0.95);
	if (!flowing && cut_face < 0.5 && lake_wind_enabled) zs_lake_foam(body, alpha, world_position, water_depth, lake_state);
	vec3 ice_state = vec3(0.0);
	vec3 ice_reflection = vec3(0.0);
	float ice_take = 0.0;
	if (!flowing) {
		zs_ice_surface(body, alpha, world_position, water_depth, cut_face, ice_state);
		vec3 frost = scene_linear_for_display(clamp(zsSkyGradient(normalize(vec3(reflected.x, abs(reflected.y) + 0.35, reflected.z))), vec3(0.0), vec3(0.98)));
		vec3 ice_sky = mix(frost, reflection, mix(0.35, 1.0, ice_state.y));
		float ice_f = 0.025 + 0.975 * pow(1.0 - max(dot(wave_normal, eye), 0.0), 5.0);
		float take = (0.12 + ice_f * 0.5) * mix(0.4, 1.0, ice_state.y) * (1.0 - ice_state.z * 0.95);
		ice_reflection = ice_sky;
		ice_take = take * ice_state.x * (1.0 - cut_face);
		if (!lake_display_lighting) {
			reflection = mix(reflection, ice_sky, ice_state.x);
			fresnel = mix(fresnel, take, ice_state.x);
		}
	} else {
		body = mix(body, vec3(0.80, 0.86, 0.90), smoothstep(0.15, 0.65, zs_ice) * 0.9);
		alpha = mix(alpha, 1.0, zs_ice);
	}
	if (!flowing && source_lake_material && cut_face < 0.5) alpha = mix(alpha, 1.0, fresnel);
	// Clear shallows let the ground through: a third at the bank to three
	// quarters by 20 cm (which hides a steep bank's earth), then the body's
	// own as it deepens; foam stays.
	alpha = mix(alpha, max(mix(0.35, 0.75, smoothstep(0.0, 0.2, shore_depth)), foam * 0.85), clear);
	ALBEDO = body;
	EMISSION = body * mix(zs_hemi_ground, zs_hemi_sky, wave_normal.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	EMISSION += zs_afterglow(world_position, wave_normal, body);
	EMISSION = mix(EMISSION, reflection * (!flowing && source_lake_material ? 1.0 : 0.8), fresnel) + ((flowing || !lake_display_lighting) ? vec3(1.0, 0.85, 0.6) * glint * 0.45 * zs_alpen_gate(world_position) : vec3(0.0));
	inversion_transmit = zs_inversion_paint(world_position, EMISSION) * (1.0 - fresnel);
	ROUGHNESS = mix(0.22, mix(mix(0.66, 0.22, ice_state.y), 0.94, ice_state.z), ice_state.x);
	if (!flowing && source_lake_material) ROUGHNESS = zs_lake_roughness(zs_ice, cut_face < 0.5 ? ice_state : vec3(0.0));
	SPECULAR = 0.7;
	if (!flowing && lake_display_lighting) {
		vec3 lit_water = body * mix(zs_hemi_ground, zs_hemi_sky, wave_normal.y * 0.5 + 0.5) * zs_hemi_energy / PI + zs_afterglow(world_position, wave_normal, body);
		lit_water += (zs_lake_direct(body, wave_normal, eye, zs_key_direction, zs_key_irradiance, ROUGHNESS) + zs_lake_direct(body, wave_normal, eye, zs_rim_direction, zs_rim_irradiance, ROUGHNESS)) * zs_alpen_gate(world_position);
		lit_water += zs_lake_flash(body, wave_normal, eye, world_position, ROUGHNESS, zs_flash) * zs_alpen_gate(world_position);
		if (cut_face < 0.5) lit_water += zs_lake_ice_highlight(wave_normal, eye, zs_key_direction, zs_key_irradiance, ice_state);
		vec4 path = zs_lake_glint(reflected, zs_sun_direction, zs_moon_direction, zs_celestial_clear, zs_ice, cut_face < 0.5 && lake_glints_enabled ? lake_effects.y : 0.0);
		EMISSION = lake_lighting_probe ? lit_water : zs_lake_ice_composite(lit_water, zs_scene_to_display(reflection), fresnel, zs_scene_to_display(ice_reflection), ice_take, path);
		inversion_transmit = zs_inversion_paint(world_position, EMISSION) * (1.0 - fresnel) * (1.0 - path.a);
		SPECULAR = 0.0;
	}
	if (fall_churn > 0.0) {
		// Froth is lit like the fall's foam, whichever lighting path ran above.
		vec3 froth = vec3(0.86, 0.92, 0.93);
		vec3 froth_light = froth * (mix(zs_hemi_ground, zs_hemi_sky, 0.8) * zs_hemi_energy / PI + 0.3 * (0.25 + 0.75 * zs_daylight));
		float take = fall_churn * (1.0 - zs_ice);
		ALBEDO = mix(ALBEDO, froth, take);
		EMISSION = mix(EMISSION, froth_light, take);
		inversion_transmit *= 1.0 - take;
	}
	ALPHA = opaque_water_probe ? 1.0 : alpha * flow_fade * level_face;
}

#define ZS_COMPLETE_LAKE_LIGHTING
#include "res://shaders/reference_direct_light.gdshaderinc"
