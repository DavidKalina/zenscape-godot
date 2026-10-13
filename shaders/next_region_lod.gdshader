shader_type spatial;
render_mode cull_back, diffuse_lambert_wrap, specular_disabled, fog_disabled, shadows_disabled;
// The next region far off (scripts/roguelike/next_region_lod.gd): soft
// silhouettes of its isles. Turf where the hull faces up, warm stone down
// its flanks and dark earth on its keel, lit by the scene's sun; then into
// the sky's own colour (the dome's gradient and glow, as
// reference_sky_common's zsSkyBase paints it) by distance, more so down
// the keels (the isles' roots go into the air first), the landmark held a
// little clearer. NextRegionLod `haze` keeps the same curve on the CPU.
global uniform vec3 zs_sky_down;
global uniform vec3 zs_sky_up;
global uniform vec3 zs_sky_glow;

uniform float haze_reach = 1100.0;
uniform float haze_most = 0.8;
uniform float keel_mist = 0.45;
uniform float landmark_clear = 0.35;
uniform vec3 turf : source_color = vec3(0.46, 0.54, 0.40);
uniform vec3 stone : source_color = vec3(0.66, 0.61, 0.54);
uniform vec3 earth : source_color = vec3(0.38, 0.33, 0.30);

varying float v_share;
varying float v_mark;
varying vec3 v_world;
varying vec3 v_tint;

void vertex() {
	v_share = UV.x;
	v_mark = COLOR.a;
	v_tint = COLOR.rgb;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 col = mix(earth, stone, smoothstep(0.05, 0.6, v_share));
	col = mix(col, turf, smoothstep(0.55, 0.85, n.y) * smoothstep(0.15, 0.45, v_share));
	col *= v_tint;
	vec3 ray = v_world - CAMERA_POSITION_WORLD;
	float dist = length(ray);
	vec3 rd = ray / max(dist, 1e-3);
	float h = 1.0 - exp(-(dist / haze_reach) * (dist / haze_reach));
	h = mix(h, 1.0, keel_mist * (1.0 - v_share));
	h *= 1.0 - landmark_clear * v_mark;
	h = min(h, haze_most);
	float y = max(rd.y, 0.0) + 0.01;
	vec3 air = mix(zs_sky_down, zs_sky_up, smoothstep(-0.4, 0.7, y)) + exp(-abs(y) * 3.5) * zs_sky_glow;
	ALBEDO = col * (1.0 - h);
	EMISSION = air * h;
	ROUGHNESS = 1.0;
}
