shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never;
// The mist off a tepui's falls (scripts/sky_tepuis.gd `_mist`): soft puffs
// that roll out of the spray down a fall and billow up from its foot in the
// cloud sea, each on its own beat. A puff is born small and faint where it
// stands, swells as it drifts along its way, and thins away; then it is
// born again. Lit as the glide's clouds are (shaders/sky_cloud_puff.
// gdshader), a little brighter, and glowing round the sun when lit through.
// Instance transform: origin where it is born, basis x's length its
// radius, basis y the way (and metres) it drifts over a life. Custom data:
// x its phase, y a seed, z its life (s), w how bright.
#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/glide_haze.gdshaderinc"

uniform float strength = 1.0;
uniform float soft_depth = 10.0;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;

varying vec2 across;
varying float opacity;
varying vec3 shade;
varying float seed;
varying float age;

float mist_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float mist_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mist_hash(i), mist_hash(i + vec2(1.0, 0.0)), f.x),
		mix(mist_hash(i + vec2(0.0, 1.0)), mist_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vec4 data = INSTANCE_CUSTOM;
	seed = data.y;
	float radius = length(MODEL_MATRIX[0].xyz);
	vec3 drift = MODEL_MATRIX[1].xyz;
	vec3 origin = MODEL_MATRIX[3].xyz;
	age = fract(zs_motion_time / max(data.z, 1.0) + data.x);
	float eased = 1.0 - (1.0 - age) * (1.0 - age);
	vec3 centre = origin + drift * eased;
	radius *= mix(0.45, 1.45, eased);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 world = centre + (right * VERTEX.x + up * VERTEX.y) * radius * 2.0;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	across = VERTEX.xy * 2.0;
	float away = distance(CAMERA_POSITION_WORLD, centre);
	float life = smoothstep(0.0, 0.22, age) * (1.0 - smoothstep(0.5, 1.0, age));
	opacity = life * smoothstep(radius * 0.3, radius * 1.3, away) * strength;
	opacity *= 1.0 - zs_glide_fog_far(away, centre.y, 1.0) * zs_glide_haze.x;
	vec3 view = normalize(CAMERA_POSITION_WORLD - centre);
	vec3 sun = normalize(zs_sun_direction + vec3(0.0, 1e-4, 0.0));
	float sunward = clamp(dot(view, sun) * 0.5 + 0.5, 0.0, 1.0);
	float glow = pow(clamp(dot(-view, sun), 0.0, 1.0), 4.0) * smoothstep(-0.05, 0.15, sun.y + 0.1);
	// Low down it glows with the cloud sea's own light under it.
	float low = 1.0 - smoothstep(-105.0, -20.0, centre.y);
	shade = (zs_cloud_sky * vec3(0.94, 0.97, 1.03) * (1.0 + 0.25 * low) + zs_cloud_sun * (0.6 + 0.4 * sunward) * 0.9) * (0.98 + 0.08 * data.w) + zs_cloud_sun * glow * 0.5;
}

void fragment() {
	float r = length(across);
	float rag = mist_noise(across * 2.0 + vec2(seed * 17.0, age * 3.0)) * 0.6 + mist_noise(across * 4.7 + seed * 9.0) * 0.4;
	float edge = 1.0 - smoothstep(0.3, 1.0, r + (rag - 0.5) * 0.5);
	float body = edge * (0.5 + 0.5 * (1.0 - r * r));
	ALBEDO = shade * (0.94 + 0.1 * (1.0 - r));
	ALPHA = clamp(body, 0.0, 1.0) * 0.34 * opacity;
	float scene = texture(depth_texture, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
	float gap = -VERTEX.z + behind.z / behind.w;
	ALPHA *= clamp(-gap / soft_depth, 0.0, 1.0);
}
