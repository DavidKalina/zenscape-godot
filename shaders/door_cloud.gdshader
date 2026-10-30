// One puff of a door's wall of cloud (scripts/endless/region_doors.gd): a
// camera-facing disc drawn as a lit ball, its rim eaten by noise on the
// ball's surface, soft where it meets the land and near the eye. Fogged by
// the environment like the land.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

global uniform vec3 zs_sun_direction;

uniform vec3 lit_colour : source_color = vec3(1.0, 0.86, 0.66);
uniform vec3 shade_colour : source_color = vec3(0.74, 0.62, 0.58);
uniform vec3 glow_colour : source_color = vec3(1.0, 0.72, 0.42);
uniform float glow = 0.3;
uniform float bright = 1.0;
uniform float opacity = 0.95;
// Faded where it meets the land over this many m, and near the eye.
uniform float soft_depth = 45.0;
uniform float near_fade = 30.0;
// The noise's size (m) and drift (m/s).
uniform float grain = 95.0;
uniform float drift = 1.2;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

instance uniform float puff_seed = 0.0;
// 0 at the wall's rim, 1 deep in its middle.
instance uniform float core = 0.5;

varying vec3 centre_world;
varying float radius;

void vertex() {
	radius = length(MODEL_MATRIX[0].xyz);
	centre_world = MODEL_MATRIX[3].xyz;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(radius, 0.0, 0.0, 0.0), vec4(0.0, radius, 0.0, 0.0), vec4(0.0, 0.0, radius, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

// Hash and value noise without sin(), steady far from the origin.
float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

float fbm(vec3 p) {
	return noise3(p) * 0.55 + noise3(p * 2.03 + 7.1) * 0.3 + noise3(p * 4.1 - 3.7) * 0.15;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float d2 = dot(p, p);
	if (d2 >= 1.0) discard;
	vec3 nv = vec3(p, sqrt(1.0 - d2));
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(nv, 0.0)).xyz);
	// The ball's surface, wrapped round a few km so the noise keeps its
	// precision at the far side's home.
	vec3 surf = mod(centre_world, 4096.0) + nw * radius + vec3(0.0, TIME * drift, TIME * drift * 0.4);
	float n = fbm(surf / grain + puff_seed * 3.7);
	vec3 sun = normalize(zs_sun_direction);
	float lit = smoothstep(-0.45, 0.85, dot(nw, sun) * 0.75 + nw.y * 0.3 + (n - 0.5) * 0.7);
	vec3 col = mix(shade_colour, lit_colour, lit);
	col += glow_colour * glow * core * (1.0 - 0.5 * lit) * (0.6 + 0.8 * n);
	float edge = 1.0 - smoothstep(0.25 + 0.45 * n, 1.0, sqrt(d2));
	float a = edge * opacity;
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 up = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene_z = -up.z / up.w;
	float my_z = -VERTEX.z;
	a *= clamp((scene_z - my_z) / soft_depth, 0.0, 1.0);
	a *= smoothstep(near_fade * 0.3, near_fade * 1.5, my_z);
	ALBEDO = col * bright;
	ALPHA = clamp(a, 0.0, 1.0);
}
