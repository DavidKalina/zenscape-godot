
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
// Live still water is drawn under the moving water everywhere wet, sheets on
// a face too. With `live_level` it fades out where its surface tilts (a pond
// lies level), so on a slope only the moving water's own look shows.
uniform bool live_level = false;
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
		vec3 absorption = exp(-vec3(2.0, 0.7, 0.45) * water_depth * bed_absorb);
		body = mix(body, bed * absorption + body * (1.0 - absorption), 1.0 - zs_ice);
		shore_depth = min(shore_depth, max(submerged, 0.0));
		fresnel = mix(plain_fresnel, fresnel, planar_weight);
		reflection = mix(plain_reflection, reflection, planar_weight);
		body = mix(plain_body, body, planar_weight);
		shore_depth = mix(plain_shore, shore_depth, planar_weight);
	}
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
		// Live water pouring down a face is white water, as the fall it runs
		// beside (shaders/flow_fall.gdshader), not a pale glassy veil.
		if (live_thin.y > 0.0) cascade = (1.0 - smoothstep(0.45, 0.8, wave_normal.y)) * smoothstep(live_thin.y * 0.6, live_thin.y * 1.6, water_depth);
		foam = max(foam, cascade * 0.6);
	}
	if (!flowing && cut_face < 0.5 && zs_look_shore > 0.0) {
		// Look pass: a thin broken foam line where still water meets the bank,
		// lapping in and out slowly with the wind.
		float lap = 0.035 + 0.02 * sin(zs_flow_time * 0.9 + zs_noise(world_position.xz * 0.6) * 6.2832) * (0.4 + min(zs_wind_strength, 1.0) * 0.6);
		float band = (1.0 - smoothstep(lap * 0.5, lap, shore_depth)) * (1.0 - smoothstep(0.2, 0.55, shore_run));
		float broken = smoothstep(0.35, 0.7, zs_noise(world_position.xz * 3.1 + vec2(zs_flow_time * 0.05, 0.0)));
		foam = max(foam, band * mix(0.35, 0.8, broken) * zs_look_shore);
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
		float spread = zs_noise((world_position.xz - outward * zs_flow_time * 0.55) * 3.2 + float(i) * 7.1);
		float fine = zs_noise((world_position.xz - outward * zs_flow_time * 0.9) * 7.5 + float(i) * 3.3);
		float core = 1.0 - smoothstep(0.12, 0.42, r);
		float patches = smoothstep(0.42, 0.7, spread * 0.7 + fine * 0.3) * (1.0 - smoothstep(0.3, 1.0, r));
		fall_churn = max(fall_churn, clamp(core * (0.7 + 0.3 * fine) + patches, 0.0, 1.0) * f.w);
	}
	body = mix(body, vec3(0.86, 0.92, 0.93), fall_churn * (1.0 - zs_ice));
	float absorption = 1.0 - exp(-water_depth / 0.45);
	float alpha = mix(0.40, 1.0, max(absorption, fresnel));
	if (flowing && live_thin.y > 0.0) {
		// Its vertex colour takes foam with speed, and a fast film is pale.
		float film = 1.0 - smoothstep(live_thin.x, live_thin.y, water_depth);
		body = mix(body, vec3(0.02, 0.09, 0.08) * zs_palette_water, film);
		fresnel *= 1.0 - film;
		glint *= 1.0 - film;
		alpha = mix(alpha, 0.28, film);
	}
	if (!flowing && source_lake_material) alpha = zs_lake_opacity(water_depth, zs_ice);
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
