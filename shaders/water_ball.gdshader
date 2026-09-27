shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_lambert;
// A held ball of the ponds' own water (scripts/water_ball.gd). It shares the
// pond surface's colours (the depth ramp in GardenView `sample_ponds` times
// zs_palette_water), its fresnel, sky reflection, hemisphere light and sun
// glint (shaders/reference_water_body.gdshaderinc, the non-planar path), and
// looks through to what is behind and inside it, so its fish show.
// The water swirls: spiral bands wind round the ball's axis and drift upward,
// bending the normal like a vortex, and a slow wobble shapes the surface.
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
global uniform vec3 zs_palette_water;
uniform sampler2D ball_screen : hint_screen_texture, filter_linear_mipmap;
// Ball radius in metres (object space is scaled to it; the mesh is a unit sphere).
uniform float radius = 1.0;
// Surface wobble height, as a share of the radius; the script raises it on
// a jolt (a hop, a catch-up, the impact) and lets it ring down.
uniform float wobble = 0.03;
// Turns per second of the swirl, and how strongly it bends the surface.
uniform float swirl_speed = 0.35;
uniform float swirl_strength = 0.35;
// 0 while held; rises to 1 as the ball bursts, thinning it to foam.
uniform float burst = 0.0;
// Seconds the ball has existed, from the script (TIME keeps running when paused).
uniform float age = 0.0;
varying vec3 local_position;
varying vec3 world_position;

float swirl_band(vec3 p, float t) {
	float around = atan(p.z, p.x);
	// Three spiral arms that climb as they wind, and a finer counter-swirl.
	return sin(around * 3.0 + p.y * 5.0 - t * swirl_speed * 6.2832 * 3.0)
		+ 0.45 * sin(around * 5.0 - p.y * 7.0 + t * swirl_speed * 6.2832 * 2.0 + 1.3);
}

void vertex() {
	local_position = VERTEX;
	float t = age;
	vec3 n = normalize(VERTEX);
	float shape = sin(n.x * 3.1 + t * 2.3) * sin(n.y * 2.7 - t * 1.9) + 0.6 * sin(n.z * 3.7 + t * 2.9 + n.y * 1.5);
	VERTEX += n * shape * wobble;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = age;
	vec3 view_normal = normalize(NORMAL);
	vec3 normal = normalize((INV_VIEW_MATRIX * vec4(view_normal, 0.0)).xyz);
	// The swirl bends the normal along the bands' gradient, round the axis.
	vec3 p = normalize(local_position);
	float e = 0.04;
	float b0 = swirl_band(p, t);
	float bx = swirl_band(normalize(p + vec3(e, 0.0, 0.0)), t) - b0;
	float by = swirl_band(normalize(p + vec3(0.0, e, 0.0)), t) - b0;
	float bz = swirl_band(normalize(p + vec3(0.0, 0.0, e)), t) - b0;
	vec3 bend = (MODEL_MATRIX * vec4(bx, by, bz, 0.0)).xyz / e;
	normal = normalize(normal - bend * swirl_strength * 0.06);
	NORMAL = normalize((VIEW_MATRIX * vec4(normal, 0.0)).xyz);
	vec3 eye = normalize(CAMERA_POSITION_WORLD - world_position);
	float facing = max(dot(eye, normal), 0.0);
	// Depth through the ball: the chord at this pixel, so the middle is deep.
	float depth = 2.0 * radius * facing;
	vec3 body = mix(vec3(0.19, 0.42, 0.33), vec3(0.018, 0.10, 0.11), 1.0 - exp(-depth / 0.45)) * zs_palette_water;
	// Swirl streaks catch a little white, like the stream's foam.
	float streak = smoothstep(0.9, 1.4, b0) * (0.35 + 0.65 * facing);
	body = mix(body, vec3(0.65, 0.80, 0.79), streak * 0.22 + burst * 0.5);
	vec3 reflected = reflect(-eye, normal);
	vec3 reflection = scene_linear_for_display(clamp(zsSkyGradient(vec3(reflected.x, abs(reflected.y), reflected.z)), vec3(0.0), vec3(0.98)));
	float fresnel = 0.02 + 0.70 * pow(1.0 - facing, 5.0);
	// What lies behind and inside, bent by the ball as a lens, then tinted
	// by the water it passes through (the ponds' absorption).
	vec2 bent = SCREEN_UV - view_normal.xy * (0.05 + 0.03 * sin(b0)) * facing;
	vec3 behind = textureLod(ball_screen, bent, 0.0).rgb;
	vec3 absorption = exp(-vec3(2.0, 0.7, 0.45) * depth * 0.55);
	vec3 seen = behind * absorption + body * (1.0 - absorption);
	float glint = pow(max(dot(reflect(-zs_sun_direction, normal), eye), 0.0), 240.0) * zs_daylight * zs_celestial_clear;
	vec3 lit = body * mix(zs_hemi_ground, zs_hemi_sky, normal.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	ALBEDO = body * 0.25;
	EMISSION = mix(mix(seen, lit, 0.35), reflection * 0.8, fresnel) + vec3(1.0, 0.85, 0.6) * glint * 0.45;
	ROUGHNESS = 0.22;
	SPECULAR = 0.7;
	ALPHA = clamp(1.0 - burst * burst, 0.0, 1.0);
}
