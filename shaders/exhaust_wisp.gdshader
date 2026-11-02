shader_type spatial;
// A wisp of exhaust (scripts/plane_exhaust.gd): a soft billboard in a MultiMesh,
// custom data its age (0 to 1), seed and strength. Ragged by value noise that
// churns with age, eaten from the edge as it thins, dark oily smoke at the
// throat going to a thin blue-grey. It takes the world's light, as the prop's
// disc does, so it stays smoke at dusk and night.
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;

global uniform vec3 zs_hemi_sky;
global uniform float zs_hemi_energy;
global uniform vec3 zs_key_irradiance;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 smoke : source_color = vec3(0.60, 0.61, 0.64);
uniform vec3 soot : source_color = vec3(0.17, 0.155, 0.15);
uniform float most = 0.8;
// How close (m) it may come to what's behind it before it fades into it.
uniform float soft = 0.25;

varying vec3 v_custom;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 c = MODEL_MATRIX[3].xyz;
	vec3 w = c + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * s;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
	v_custom = INSTANCE_CUSTOM.xyz;
}

void fragment() {
	float age = v_custom.x;
	float seed = v_custom.y * 97.0;
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	vec2 churn = vec2(age * 1.1, -age * 1.7);
	float n = vnoise(d * 1.9 + seed + churn) * 0.62 + vnoise(d * 4.3 + seed * 1.7 - churn * 1.4) * 0.38;
	float eaten = mix(0.12, 0.62, age);
	float body = (1.0 - smoothstep(0.15, 1.0, r)) * smoothstep(eaten - 0.12, eaten + 0.26, n + (1.0 - r) * 0.16);
	float fade = smoothstep(0.0, 0.06, age) * pow(1.0 - age, 1.5);
	float a = body * fade * mix(0.35, 1.0, v_custom.z) * most;
	float z = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 wp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z, 1.0);
	a *= clamp((-wp.z / wp.w + VERTEX.z) / soft, 0.0, 1.0);
	vec3 light = zs_hemi_sky * zs_hemi_energy * 1.4 + zs_key_irradiance / PI * 0.4;
	ALBEDO = mix(soot, smoke, smoothstep(0.0, 0.32, age)) * light;
	ALPHA = clamp(a, 0.0, 1.0);
}
