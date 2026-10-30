shader_type spatial;
// The crown past the camera's far plane (scripts/endless/rocks/peak_towers.gd):
// the towers' far level and the massif's coarse body, drawn where they truly
// stand but written to the depth buffer just inside the far plane, nearest
// nearest, so all the real land and rock stands in front of them and the
// proxy shows only where the real thing has been clipped. The land's own haze,
// its height term included, then a little more out past the haze's end, so
// the crown fades with distance and never quite goes. The body melts away by
// its vertex alpha at its foot and rim, so the sky shows through and it has no
// edge. The real rock's paint is far richer than a far level holds: its sunlit
// side is lifted to match, warm, and its shade stays cool (`lit`, `shade`).
render_mode blend_mix, depth_draw_always, cull_back, diffuse_lambert, specular_disabled, shadows_disabled;

#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
uniform float sea_y = -40.0;
#include "res://shaders/endless_height_haze.gdshaderinc"

// The camera's far plane (m), set each frame.
uniform float far_m = 7904.0;
// How far (m) the depth's small range is spread over.
uniform float far_span = 200000.0;
// Past the haze's end: the amount it thickens to, and its distance scale (m).
uniform vec2 far_fade = vec2(0.86, 14000.0);
// The sunlit side's lift and the shade's tint.
uniform vec3 lit = vec3(5.2, 3.9, 2.6);
uniform vec3 shade = vec3(0.86, 0.94, 1.22);

varying float world_y;

void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 clip = PROJECTION_MATRIX * view;
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	vec4 edge = PROJECTION_MATRIX * vec4(0.0, 0.0, -far_m * 0.998, 1.0);
	float z = edge.z / edge.w * (1.0 - 0.8 * clamp(length(view.xyz) / far_span, 0.0, 1.0));
	POSITION = vec4(clip.xy, z * clip.w, clip.w);
}

void fragment() {
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float sunny = smoothstep(-0.02, 0.55, dot(wn, zs_sun_direction));
	float dark = max(max(COLOR.r, COLOR.g), COLOR.b);
	ALBEDO = COLOR.rgb * mix(mix(shade, lit, sunny), vec3(1.0), smoothstep(0.2, 0.42, dark));
	ROUGHNESS = 1.0;
	vec4 haze = zs_land_haze(VERTEX, world_y, INV_VIEW_MATRIX);
	float d = length(VERTEX);
	float past = 1.0 - exp(-max(d - haze_depth.y, 0.0) / far_fade.y);
	haze.a = mix(haze.a, max(haze.a, far_fade.x), past);
	FOG = haze;
	ALPHA = COLOR.a;
}
