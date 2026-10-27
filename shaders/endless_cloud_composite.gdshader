shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;
// The endless flight's clouds into the scene (scripts/endless/
// endless_clouds.gd): a sheet over the screen, drawn in the see-through
// pass just after the sea, that colours the march's light terms
// (shaders/endless_cloud_march.glsl, resolved over frames by shaders/
// cloud_volume_resolve.glsl) in the cumulus' own light (shaders/
// cumulus_light.gdshaderinc: the sun's hue on the lit side, the sky's on
// the shaded), then lays the land's haze over them by distance, thinner
// for cloud standing high, toward the dome's own colour behind each one,
// so far cloud melts into the sky as the far land does.
#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/cumulus_light.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
#include "res://shaders/storm_front.gdshaderinc"
#include "res://shaders/storm_cloud_light.gdshaderinc"

uniform sampler2D cloud_light : filter_nearest, repeat_disable;
uniform sampler2D cloud_shape : filter_nearest, repeat_disable;
// The land's haze (scripts/endless/endless_look.gd FOG_*): begin, end (m),
// curve, and the share of the land's haze the cloud takes.
uniform vec4 haze = vec4(120.0, 7600.0, 0.75, 0.8);
// The air thins with height over the sea: the haze's scale height (m), and
// the sea's height.
uniform float haze_height = 650.0;
uniform float sea_y = -40.0;
// The sun's glow in the haze toward it (the land's fog_sun_scatter).
uniform float sun_scatter = 0.18;

// The sunny side lifted by day (the isles' LIFT).
const float LIFT = 1.25;
const float GLOW = 2.0;
// The light off the land and sea below on the bases: a cool green-grey.
const vec3 BOUNCE_TINT = vec3(0.78, 0.9, 0.82);
// At night the shade and the moonlit side painted, so cloud reads as
// moonlit cloud, never as dark ground.
const float NIGHT_TINT = 0.6;
// The valley fog (the light's fourth term, its share; 0 for cloud): its
// shade cooled toward the sky's blue and lifted, so fog in a ridge's shade
// reads as pale blue air, never as a muddy wash over the ground.
const vec3 FOG_COOL = vec3(0.8, 0.95, 1.2);
const float FOG_LIFT = 1.2;
// Clouds lit from below at sunset (zs_cloud_under, scripts/shared/
// celestial.gd CLOUD_UNDER_E): the march's bounce term (strongest at a
// cloud's base) takes the low sun's colour, half of it a rose at the sun's
// strength, this many times over, more on the sun's side of the sky. Valley
// fog keeps its own.
global uniform float zs_cloud_under;
const float UNDER_GAIN = 6.0;
const vec3 UNDER_ROSE = vec3(1.0, 0.42, 0.52);
const float UNDER_ROSE_SHARE = 0.5;
// The valley fog's light scaled (1 as the first pass drew it).
uniform float fog_gain = 1.0;
// In cloud under the storm: the share of the white glow kept.
const float ZS_STORM_GLOW = 0.3;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	ivec2 here = min(ivec2(FRAGCOORD.xy), textureSize(cloud_light, 0) - 1);
	vec4 a = texelFetch(cloud_light, here, 0);
	vec4 b = texelFetch(cloud_shape, here, 0);
	float cloud_a = clamp(b.x, 0.0, 1.0);
	if (cloud_a < 0.003) discard;
	vec3 eye = CAMERA_POSITION_WORLD;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, 1.0, 1.0);
	vec3 rd = normalize(mat3(INV_VIEW_MATRIX) * (view.xyz / view.w));

	vec3 sun = normalize(zs_sun_direction + vec3(0.0, 1e-4, 0.0));
	vec3 sun_hue;
	vec3 c_sun;
	vec3 c_shade;
	float lining;
	zs_cumulus_palette(rd, sun, sun_hue, c_sun, c_shade, lining);
	float toward_sun = max(dot(rd, sun), 0.0);
	vec4 terms = a / cloud_a;
	float fog_share = clamp(terms.w, 0.0, 1.0);
	vec3 shade_col = c_shade * mix(vec3(1.0), FOG_COOL, fog_share);
	vec3 lit = (terms.x * shade_col + terms.y * c_sun + terms.z * c_sun * BOUNCE_TINT) * ZS_CUMULUS_LIT_SHARE;
	if (zs_cloud_under > 0.0) {
		float sun_side = dot(normalize(rd.xz + 1e-4), normalize(sun.xz + 1e-4)) * 0.5 + 0.5;
		vec3 under_col = mix(c_sun, UNDER_ROSE * max(c_sun.r, max(c_sun.g, c_sun.b)), UNDER_ROSE_SHARE);
		lit += terms.z * under_col * UNDER_GAIN * zs_cloud_under * (1.0 - fog_share) * mix(0.55, 1.0, sun_side) * ZS_CUMULUS_LIT_SHARE;
	}
	lit *= mix(1.0, LIFT, zs_daylight) * mix(1.0, FOG_LIFT * fog_gain, fog_share);
	float bright = clamp(terms.y / 0.95, 0.0, 1.0);
	float met = b.y / cloud_a;
	float glow = b.w / cloud_a;
	// In the cloud: the white glow of the fog round the eye, warmer toward
	// the sun.
	vec3 glow_col = mix(vec3(0.95, 0.97, 1.0), sun_hue, 0.15) * GLOW * mix(1.0, 0.2, zs_night) * mix(0.6, 1.0, zs_daylight);
	// Under the storm the fog round the eye is its gloom, not a white glow
	// (the storm's amount at the eye, zs_storm_here).
	glow_col *= mix(1.0, ZS_STORM_GLOW, zs_storm_here);
	vec3 col = lit + glow_col * glow * (1.0 + 0.7 * pow(toward_sun, 3.0)) * ZS_CUMULUS_LIT_SHARE * 1.6;
	vec3 painted = mix(c_shade * 0.55, c_sun * 0.9, bright) * ZS_CUMULUS_LIT_SHARE * 1.6;
	col = mix(col, painted, NIGHT_TINT * zs_night);
	// The storm's deck (shaders/storm_cloud_light.gdshaderinc): dark and
	// cool, green-grey at the base, and lit from inside by the lightning.
	vec3 storm_at = eye + rd * met;
	float storm_w = zs_storm_cloud_weight(storm_at.xz);
	col = zs_storm_cloud_colour(col, storm_w, b.z / cloud_a);

	// The haze between: the land's own by distance, thinner the higher the
	// air it crosses (exponential air over the sea).
	float y0 = max(eye.y - sea_y, 0.0);
	float y1 = max(eye.y + rd.y * met - sea_y, 0.0);
	float rise = y1 - y0;
	float airmass = abs(rise) > 1.0 ? haze_height * (exp(-y0 / haze_height) - exp(-y1 / haze_height)) / rise : exp(-y0 / haze_height);
	float dist = met * airmass / exp(-min(y0, 150.0) / haze_height);
	float fog = pow(clamp((dist - haze.x) / (haze.y - haze.x), 0.0, 1.0), haze.z) * haze.w;
	vec3 behind = normalize(vec3(rd.x, max(rd.y, 0.0), rd.z));
	// The dome's colour behind, kept under white as the land's haze keeps it
	// (EndlessLook.horizon): past it the display's inverse turns hue.
	vec3 dome = zsSkyBase(behind);
	dome *= 0.98 / max(max(max(dome.r, dome.g), dome.b), 0.98);
	vec3 sky = scene_linear_for_display(dome);
	float high = smoothstep(0.02, 0.4, sun.y);
	// At a low sun the scatter grows as the land's does (endless_look.gd
	// SUN_SCATTER_SUN over SUN_SCATTER, with zs_haze_sun).
	sky += c_sun * pow(toward_sun, 6.0) * sun_scatter * mix(1.0, 0.45 / 0.18, zs_haze_sun) * mix(1.4, 0.7, high) * zs_celestial_clear;
	col = mix(col, zs_storm_haze_colour(sky, storm_w), fog * zs_storm_haze_share(storm_w));
	col += zs_storm_cloud_flash(storm_at, b.z / cloud_a, storm_w);
	ALBEDO = col;
	// The march stops once the cloud is all but whole: whole it is, so the
	// sun's disc never shines through a thick body.
	ALPHA = min(cloud_a / 0.96, 1.0);
}
