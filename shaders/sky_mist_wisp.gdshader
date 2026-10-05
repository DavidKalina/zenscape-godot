shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never;
// Thin mist hanging among the sky pillars (scripts/sky_pillars.gd): a soft
// streak drawn out along the air, lying level. Seen from the side it is a
// thin band; seen from above it opens out into a patch, so a layer reads as
// a layer from every way. Each drifts a little on its own slow beat, thins
// away up close and where it meets the rock, and takes the clouds' light.
// The instance transform's origin is its middle, its basis x's length half
// its length and y's half its thickness. Instance custom data: x its
// strength, y a seed.
#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/glide_haze.gdshaderinc"

uniform float strength = 0.8;
// How far (m) a wisp wanders about its place.
uniform float sway = 9.0;
// Within this many metres of the scene behind it, it thins away.
uniform float soft_depth = 12.0;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;

varying vec2 across;
varying float opacity;
varying vec3 shade;
varying float seed;

float wisp_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float wisp_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(wisp_hash(i), wisp_hash(i + vec2(1.0, 0.0)), f.x),
		mix(wisp_hash(i + vec2(0.0, 1.0)), wisp_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vec4 data = INSTANCE_CUSTOM;
	seed = data.y;
	float half_length = length(MODEL_MATRIX[0].xyz);
	float half_thick = length(MODEL_MATRIX[1].xyz);
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float t = zs_motion_time;
	vec3 centre = origin + vec3(sin(t * 0.021 + seed * 17.0), 0.0, cos(t * 0.017 + seed * 11.0)) * sway
		+ vec3(0.0, sin(t * 0.05 + seed * 5.0) * 1.5, 0.0);
	vec3 view = normalize(centre - CAMERA_POSITION_WORLD);
	// Level across the view; up the view's own up, opening out seen from above.
	vec3 right = normalize(vec3(-view.z, 0.0, view.x) + vec3(1e-4, 0.0, 0.0));
	vec3 up = normalize(cross(right, view));
	float above = smoothstep(0.25, 0.9, abs(view.y));
	float tall = mix(half_thick, half_length * 0.6, above);
	vec3 world = centre + right * VERTEX.x * half_length * 2.0 + up * VERTEX.y * tall * 2.0;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	across = VERTEX.xy * 2.0;
	float away = distance(CAMERA_POSITION_WORLD, centre);
	opacity = smoothstep(tall * 0.6, tall * 3.0 + 12.0, away) * (1.0 - smoothstep(2600.0, 3000.0, away)) * strength * data.x;
	opacity *= 1.0 - zs_glide_fog_far(away, centre.y, 1.0) * zs_glide_haze.x;
	float sunward = clamp(zs_sun_direction.y * 0.5 + 0.5, 0.0, 1.0);
	shade = zs_cloud_sky * vec3(0.95, 0.97, 1.02) + zs_cloud_sun * (0.35 + 0.4 * sunward);
}

void fragment() {
	// Soft at the ends and edges, streaked along its length, the streaks
	// drifting slowly through.
	vec2 q = across;
	float ends = 1.0 - smoothstep(0.35, 1.0, abs(q.x));
	float sides = 1.0 - smoothstep(0.2, 1.0, abs(q.y));
	float flow = zs_motion_time * 0.03;
	float streak = wisp_noise(vec2(q.x * 2.5 + flow + seed * 13.0, q.y * 4.5 + seed * 7.0)) * 0.6
		+ wisp_noise(vec2(q.x * 6.0 - flow * 1.7, q.y * 9.0 + seed * 3.0)) * 0.4;
	float body = ends * sides * smoothstep(0.25, 0.75, streak + (1.0 - abs(q.y)) * 0.2);
	ALBEDO = shade;
	ALPHA = clamp(body, 0.0, 1.0) * opacity;
	if (soft_depth > 0.0) {
		float scene = texture(depth_texture, SCREEN_UV).r;
		vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
		float gap = -VERTEX.z + behind.z / behind.w;
		ALPHA *= clamp(-gap / soft_depth, 0.0, 1.0);
	}
}
