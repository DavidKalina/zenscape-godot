shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, depth_test_disabled, cull_front, fog_disabled;
// The pollen cloud's footprint (scripts/pollen_cloud.gd): where it will settle,
// the promise (docs/scenic/handful.md), painted on the ground as a decal (a
// box around it reads the depth buffer back to the ground it covers). In the
// water ball's family (shaders/water_ball_ground.gdshader): a pooled shadow in
// two tones with a pale rim, faceted round its ends. It is softer and lighter,
// because pollen is diffuse, and follows the swept veil: the union of one
// capsule per knot of the veil, each round in still air and stretched along
// the wind (`ends`: world a.x, a.z, b.x, b.z; `radii`: world metres). Faint
// specks of pollen light twinkle inside it.
// Premultiplied: ALBEDO is light added, ALPHA how much of the ground is dimmed.
#include "res://shaders/reference_globals.gdshaderinc"
uniform sampler2D ground_depth : hint_depth_texture, filter_nearest, repeat_disable;
// The capsules (scripts/pollen_cloud.gd KNOTS at most) and how many are used.
const int CAPSULES = 64;
uniform vec4 ends[CAPSULES];
uniform float radii[CAPSULES];
uniform int count = 0;
// How much of it shows, and 1 for the aim's softer edge.
uniform float strength = 0.0;
uniform float soft = 0.0;
// Nothing above this world height is painted (keeps the cloud clean).
uniform float ceiling = 0.0;
uniform float age = 0.0;

const int MARK_SIDES = 12;
const float MARK_TURN = 0.08;

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	float depth = textureLod(ground_depth, SCREEN_UV, 0.0).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	vec3 box = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	if (any(greaterThan(abs(box), vec3(0.5))) || world.y > ceiling) discard;
	// The nearest capsule's spine in shares of its radius, faceted like the
	// water ball's mark (only the nearest is faceted, to keep the loop cheap).
	float best = 1e4;
	vec2 near = vec2(1.0, 0.0);
	for (int i = 0; i < CAPSULES; i++) {
		if (i >= count) break;
		vec2 a = ends[i].xy;
		vec2 ab = ends[i].zw - a;
		float along = clamp(dot(world.xz - a, ab) / max(dot(ab, ab), 1e-5), 0.0, 1.0);
		vec2 from = world.xz - (a + ab * along);
		float share = length(from) / max(radii[i], 1e-3);
		if (share < best) {
			best = share;
			near = from;
		}
	}
	float wedge = TAU / float(MARK_SIDES);
	float around = mod(atan(near.y, near.x) + age * MARK_TURN, wedge) - wedge * 0.5;
	float d = best * cos(around);
	float edge = mix(0.1, 0.2, soft);
	float pool = 1.0 - smoothstep(1.0 - edge, 1.0, d);
	float core = 1.0 - smoothstep(0.55 - edge * 0.5, 0.55, d);
	float shade = pool * 0.24 + core * 0.07;
	vec3 light = zs_key_irradiance / PI * zs_celestial_clear;
	vec3 sky_light = zs_hemi_sky * zs_hemi_energy / PI;
	vec3 glow = vec3(1.0, 0.93, 0.72) * (light * 0.3 + sky_light * 0.7 + vec3(0.02 + 0.03 * zs_night));
	float rim = exp(-pow((d - 1.0) / mix(0.05, 0.09, soft), 2.0));
	vec3 add = glow * rim * 0.5;
	// Specks of pollen light scattered through it, twinkling.
	vec2 cell = floor(world.xz * 6.0);
	float speck = step(0.93, hash2(cell)) * pow(max(0.0, 1.0 - length(fract(world.xz * 6.0) - 0.5) * 3.0), 2.0);
	add += glow * speck * pool * (0.5 + 0.5 * sin(age * 3.0 + hash2(cell + 7.0) * TAU)) * 0.6;
	ALBEDO = add * strength;
	ALPHA = clamp(shade * strength, 0.0, 1.0);
}
