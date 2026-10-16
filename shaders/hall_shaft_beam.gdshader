shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// A light shaft through a torn roof (scripts/hall_shafts.gd, docs/scenic/
// hall-shafts.md). The mesh is each roof opening's four walls hung straight
// down (UV.y 0 at the roof, 1 at the floor, UV.x the way round the opening
// in m, COLOR.r the beam's own random); the vertex stage shears them along
// the scene's key light (the celestial rig's `zs_key_direction`, so the day
// clock re-aims every beam with no CPU work and they match the real shadows).
// The fragment stage is a soft additive column: edges fade by view angle so
// no wall reads as a card, noise streaks scroll down it, it fades into the
// scene's depth, up into the roof and out into the dark below, and it warms
// and brightens looking into the sun.
#include "res://shaders/reference_globals.gdshaderinc"

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform float roof_y = 11.4;
uniform float floor_y = 0.0;
uniform float max_len = 46.0;
uniform float gain = 1.0;
// How hard the depth fade bites (m of depth it takes to reach full).
uniform float soft_depth = 2.0;

varying float v_t;
varying float v_rand;
varying float v_u;
varying float v_live;
varying vec2 v_wall;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// The key light as the shaders see it: how much there is of it, 0..1.
float light_strength() {
	vec3 k = zs_key_irradiance;
	float lum = (k.x + k.y + k.z) / 3.0;
	return clamp(lum / 2.4, 0.0, 1.0) * clamp(zs_celestial_clear, 0.0, 1.0);
}

void vertex() {
	vec3 k = zs_key_direction;
	float kl = length(k);
	vec3 way = kl > 0.5 ? -k / kl : vec3(0.0, -1.0, 0.0);
	float elev = -way.y;
	float len = min((roof_y - floor_y) / max(elev, 0.12), max_len);
	v_t = UV.y;
	v_u = UV.x;
	v_rand = COLOR.r;
	v_wall = UV2;
	v_live = kl > 0.5 ? smoothstep(0.12, 0.4, elev) : 0.0;
	vec3 shear = way * len * UV.y;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * shear;
}

void fragment() {
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	float facing = abs(dot(n, normalize(VERTEX)));
	float edge = smoothstep(0.0, 0.6, facing);
	// Fade into whatever stands in the beam.
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	float soft = clamp((-view.z - (-VERTEX.z)) / soft_depth, 0.0, 1.0);
	float near_fade = smoothstep(0.4, 6.0, -VERTEX.z);
	// Up into the roof, out into the dark below.
	float corner = mix(0.25, 1.0, smoothstep(0.0, 2.6, v_wall.x) * smoothstep(0.0, 2.6, v_wall.y - v_wall.x));
	float along = smoothstep(0.0, 0.14, v_t) * (1.0 - smoothstep(0.35, 1.0, v_t));
	// Streaks down the walls, wafts across them, drifting.
	float r = v_rand * 40.0;
	float sn = vnoise(vec2(v_u * 1.3 + r, v_t * 0.9 - TIME * 0.05));
	float streak = 0.25 + 1.5 * sn * sn;
	float waft = 0.65 + 0.55 * vnoise(vec2(v_u * 0.45 - r, v_t * 3.2 - TIME * 0.11));
	// Looking into the sun the air lights up.
	vec3 world_way = normalize((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz - CAMERA_POSITION_WORLD);
	float into = max(dot(world_way, normalize(zs_key_direction + vec3(0.0, 1e-4, 0.0))), 0.0);
	float boost = 0.6 + 1.5 * pow(into, 3.0);
	vec3 k = zs_key_irradiance;
	float lum = max((k.x + k.y + k.z) / 3.0, 1e-3);
	vec3 tint = mix(k / lum, vec3(1.0, 0.84, 0.58), 0.4);
	float amount = gain * light_strength() * v_live * edge * soft * near_fade * along * corner * streak * waft * boost * (0.75 + 0.25 * fract(v_rand * 7.0));
	ALBEDO = tint * amount * 0.7;
}
