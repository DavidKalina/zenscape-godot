shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
// The crown a landing water ball throws up (scripts/water_ball.gd): an open
// cylinder of water that rises round the impact and flares out, its rim
// fingered and foaming, then tears into ragged spray and falls. The mesh is a
// unit cylinder standing on the ground; `progress` runs 0 to 1 over the splash.
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
global uniform vec3 zs_palette_water;
uniform sampler2D splash_screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float progress = 0.0;
// Radius at the base and the tallest the crown stands (m).
uniform float base = 1.0;
uniform float tall = 1.0;
uniform float seed = 0.0;
varying vec3 world_position;
varying float up;
varying float around;

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	up = VERTEX.y + 0.5;
	around = atan(VERTEX.z, VERTEX.x);
	float rise = sin(min(progress / 0.4, 1.0) * 1.5708) * (1.0 - smoothstep(0.45, 1.0, progress) * 0.75);
	// Fingers along the rim: some stand taller than others.
	float fingers = 0.75 + 0.25 * sin(around * 11.0 + seed) + 0.15 * sin(around * 23.0 - seed * 2.0);
	float height = tall * rise * mix(1.0, fingers, up);
	float spread = base * (1.0 + up * up * (0.35 + progress * 1.1)) * (1.0 + progress * 0.5);
	VERTEX = vec3(cos(around) * spread, up * height, sin(around) * spread);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Torn into spray from the rim down as the crown falls.
	float tear = noise2(vec2(around * 9.0, up * 6.0 + seed)) * 0.7 + noise2(vec2(around * 31.0, up * 17.0)) * 0.3;
	float held = 1.15 - up * 0.6 - progress * 0.85;
	if (tear > held) discard;
	float torn = smoothstep(held - 0.1, held, tear);
	vec3 normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 eye = normalize(CAMERA_POSITION_WORLD - world_position);
	float facing = abs(dot(eye, normal));
	float fresnel = 0.04 + 0.8 * pow(max(1.0 - facing, 0.0), 4.0);
	vec3 behind = textureLod(splash_screen, clamp(SCREEN_UV + NORMAL.xy * 0.02, vec2(0.002), vec2(0.998)), 0.0).rgb;
	vec3 tint = vec3(0.62, 0.9, 0.84);
	vec3 reflected = reflect(-eye, normal);
	vec3 sky = scene_linear_for_display(clamp(zsSkyGradient(vec3(reflected.x, abs(reflected.y), reflected.z)), vec3(0.0), vec3(0.98)));
	vec3 light = zs_key_irradiance / PI * max(zs_key_direction.y, 0.2) + zs_hemi_sky * zs_hemi_energy / PI;
	// Clear water that whitens only where it thins: the rim and the torn edges.
	float foam = smoothstep(0.7, 1.0, up) * 0.6 * noise2(vec2(around * 17.0, up * 9.0 - progress * 4.0)) + torn * 0.5;
	vec3 color = mix(behind * tint, sky, fresnel);
	color = mix(color, vec3(0.86, 0.94, 0.93) * light * 1.2, clamp(foam, 0.0, 1.0));
	float glint = pow(max(dot(normalize(zs_key_direction + eye), normal), 0.0), 60.0);
	color += zs_key_irradiance / PI * glint * 0.6 * zs_celestial_clear;
	ALBEDO = color;
	ALPHA = clamp(0.2 + fresnel * 0.7 + foam * 0.5 + glint, 0.0, 1.0) * (1.0 - torn * 0.6) * (1.0 - smoothstep(0.7, 1.0, progress)) * smoothstep(0.0, 0.08, up + 0.02);
}
