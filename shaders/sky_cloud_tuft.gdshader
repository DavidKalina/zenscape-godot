shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never;
// A scrap of cloud torn off by a plane (scripts/cloud_wakes.gd): soft and
// lumpy, lit as the drifting puffs are (shaders/sky_cloud_puff.gdshader).
// Flung fast, it draws out along the way it flies, a pulled strand of
// cotton; slowed, it rounds up. As it ages it swells and frays from the
// inside out into wisps, never a flat fade.
// The instance transform's origin is the tuft's middle, its basis x's
// length its size (m) and y's its age as a share of its life. Instance
// custom data: its velocity (xyz) and a seed (w).
#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/glide_haze.gdshaderinc"

// How far a tuft draws out per metre a second of speed.
uniform float stretch = 0.09;

varying vec2 across;
varying float opacity;
varying float life;
varying float seed;
varying vec3 shade;

float tuft_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float tuft_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(tuft_hash(i), tuft_hash(i + vec2(1.0, 0.0)), f.x),
		mix(tuft_hash(i + vec2(0.0, 1.0)), tuft_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	life = clamp(length(MODEL_MATRIX[1].xyz), 0.0, 1.0);
	seed = INSTANCE_CUSTOM.w;
	vec3 velocity = INSTANCE_CUSTOM.xyz;
	vec3 eye = CAMERA_POSITION_WORLD;
	vec3 to_eye = eye - centre;
	float away = length(to_eye);
	vec3 view = to_eye / max(away, 1e-3);
	// Along its way across the view, drawn out by its speed there.
	vec3 flat_v = velocity - view * dot(velocity, view);
	float speed = length(flat_v);
	vec3 along = speed > 0.05 ? flat_v / speed : INV_VIEW_MATRIX[1].xyz;
	vec3 side = normalize(cross(along, view));
	float drawn = 1.0 + min(speed * stretch, 2.2);
	// A slow turn of its own, so a burst never looks stamped.
	float turn = (seed - 0.5) * 1.2 + zs_motion_time * (seed - 0.5) * 0.3 * step(speed * stretch, 0.4);
	vec2 v = vec2(cos(turn) * VERTEX.x - sin(turn) * VERTEX.y, sin(turn) * VERTEX.x + cos(turn) * VERTEX.y);
	vec3 world = centre + (side * v.x / sqrt(drawn) + along * v.y * drawn) * size * 2.0;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	across = VERTEX.xy * 2.0;
	// In fast, out slow; thinned right at the eye and into the far haze.
	opacity = smoothstep(0.0, 0.08, life) * (1.0 - smoothstep(0.55, 1.0, life));
	opacity *= smoothstep(size * 0.4, size * 2.2, away);
	opacity *= 1.0 - zs_glide_fog_far(away, centre.y, 0.0) * zs_glide_haze.x;
	// The puffs' light: the sky's colour all round, the sun's on top and
	// on the side facing it, cooler beneath.
	vec3 sun = normalize(zs_sun_direction + vec3(0.0, 1e-4, 0.0));
	float sunward = clamp(dot(-view, sun) * 0.25 + sun.y * 0.35 + 0.5, 0.0, 1.0);
	shade = zs_cloud_sky * vec3(0.93, 0.95, 1.02) * 0.9 + zs_cloud_sun * (0.3 + 0.7 * sunward) * 0.8;
}

void fragment() {
	float r = length(across);
	// Lumpy, and fraying from its heart out as it ages.
	vec2 q = across * 1.8 + vec2(seed * 23.0, seed * 7.0 + life * 0.6);
	float n = tuft_noise(q) * 0.55 + tuft_noise(q * 2.3 + 5.1) * 0.3 + tuft_noise(q * 5.0 - 2.7) * 0.15;
	float edge = 1.0 - smoothstep(0.35, 1.0, r + (n - 0.5) * 0.7);
	float fray = smoothstep(0.25, 0.95, life);
	float wisp = smoothstep(fray * 0.75, fray * 0.75 + 0.3, n);
	ALBEDO = shade * (0.95 + 0.1 * (1.0 - r));
	ALPHA = clamp(edge * wisp * (0.6 + 0.4 * (1.0 - r * r)), 0.0, 1.0) * 0.8 * opacity;
}
