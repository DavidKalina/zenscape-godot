shader_type spatial;
render_mode cull_back, specular_schlick_ggx, shadows_disabled;
// The lower world's ocean (scripts/sky_below.gd): one plane kilometres
// across, kept under the eye. Grown from the islet's tarn (shaders/
// islet_pond.gdshader): no reflection or bed, only its ripple, a long swell
// under it (after shaders/reference_lake_chop.gdshaderinc), a sharp glint,
// and at a glance the overcast it lies under (zsBelowAir). Its blues are
// the ones the Opal sea's rifts show far below (shaders/
// sky_cloud_sea_opal.gdshaderinc, zs_opal_sea_land's water), so what was
// glimpsed through the cloud is what is flown over. The ripples fade with
// distance, so the far water lies glassy and never shimmers; the haze
// (the display fog, scripts/sky_haze.gd) takes it into the overcast.
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
uniform vec3 deep_color : source_color = vec3(0.1, 0.24, 0.46);
uniform vec3 shallow_color : source_color = vec3(0.22, 0.5, 0.58);
// The islands' swaps added up (SkyIslands `origin`, xz): taken off, so the
// water's pattern stays put on a swap.
uniform vec2 home = vec2(0.0);
// The swell's and the ripple's tilt, and the distance (m) the ripple is
// gone by and the swell by.
uniform float swell = 0.08;
uniform float ripple = 0.035;
uniform vec2 calm = vec2(160.0, 1400.0);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz - home;
	float t = zs_flow_time;
	float far = distance(world_position, CAMERA_POSITION_WORLD);
	float near_ripple = ripple * (1.0 - smoothstep(calm.x * 0.3, calm.x, far));
	float near_swell = swell * (1.0 - smoothstep(calm.y * 0.3, calm.y, far));
	// A long swell running two ways, and the tarn's ripple over it.
	vec2 s = vec2(
		sin(p.x * 0.045 + p.y * 0.02 + t * 0.55) + 0.5 * sin(p.x * 0.013 - p.y * 0.071 - t * 0.4),
		cos(p.y * 0.05 - p.x * 0.017 + t * 0.5) + 0.5 * cos(p.y * 0.019 + p.x * 0.063 + t * 0.35));
	vec2 r = vec2(
		sin(p.x * 0.9 + t * 0.8) + 0.6 * sin(p.y * 1.5 - p.x * 0.45 - t * 1.1),
		cos(p.y * 0.85 + t * 0.7) + 0.6 * cos(p.x * 1.35 + p.y * 0.4 + t * 0.9));
	vec3 n = normalize(vec3(near_swell * s.x + near_ripple * r.x, 1.0, near_swell * s.y + near_ripple * r.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	// Broad patches of lighter water, as the rifts show it.
	float patch = 0.5 + 0.25 * sin(p.x * 0.0021 + 1.3) * sin(p.y * 0.0017 - 0.6) + 0.25 * sin((p.x + p.y) * 0.0009);
	vec3 water = mix(deep_color, shallow_color, smoothstep(0.55, 0.95, patch) * 0.6);
	vec3 view = normalize(world_position - CAMERA_POSITION_WORLD);
	vec3 above = scene_linear_for_display(clamp(zsBelowAir(reflect(view, n)), vec3(0.0), vec3(0.98)));
	ALBEDO = mix(water, above, fresnel);
	ROUGHNESS = 0.06;
	SPECULAR = 0.7;
	METALLIC = 0.0;
}
