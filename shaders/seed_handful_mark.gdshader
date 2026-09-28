shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, depth_test_disabled, cull_front, fog_disabled;
// The seed sprinkle's marks (scripts/seed_handful.gd): where its seeds will
// land, painted on the ground as a decal (a box around them reads the depth
// buffer back to the ground it covers). The promise (docs/scenic/handful.md):
// straight below the spout, never along the sun. Drawn as the water ball's
// mark is (shaders/water_ball_ground.gdshader), sized down: a slowly turning
// MARK_SIDES-gon pooled shadow in two painted tones with a pale rim, here
// warm seed light rather than water light. A quick drag leaves a short trail
// of marks, one pool where they overlap, each shrinking away once its seeds
// are down. Each landing rings out.
// Premultiplied: ALBEDO is light added, ALPHA how much of the ground is dimmed.
#include "res://shaders/reference_globals.gdshaderinc"
uniform sampler2D ground_depth : hint_depth_texture, filter_nearest, repeat_disable;
// Marks: world x, z, radius (m), and size (0..1, shrinking away); `count` in use.
uniform vec4 marks[24];
uniform int count = 0;
// 1 while seeds pour; the rim is brighter then.
uniform float pouring = 0.0;
// Nothing above this world height is painted (keeps the seeds clean).
uniform float ceiling = 0.0;
uniform float age = 0.0;
// Seeds landed: world x, z, the age they landed, and 1 when in use.
uniform vec4 landings[32];

const int MARK_SIDES = 12;
const float MARK_TURN = 0.12;

void fragment() {
	float depth = textureLod(ground_depth, SCREEN_UV, 0.0).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	vec3 box = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	if (any(greaterThan(abs(box), vec3(0.5))) || world.y > ceiling) discard;
	vec3 light = zs_key_irradiance / PI * zs_celestial_clear;
	vec3 sky_light = zs_hemi_sky * zs_hemi_energy / PI;
	vec3 glow = vec3(1.0, 0.9, 0.66) * (light * 0.3 + sky_light * 0.7 + vec3(0.02 + 0.03 * zs_night));
	float shade = 0.0;
	vec3 add = vec3(0.0);
	// The union of the marks: the nearest in shares of its own radius.
	float d = 1e6;
	float wedge = TAU / float(MARK_SIDES);
	for (int i = 0; i < 24; i++) {
		if (i >= count) break;
		vec2 from = world.xz - marks[i].xy;
		float around = mod(atan(from.y, from.x) + age * MARK_TURN, wedge) - wedge * 0.5;
		float size = marks[i].z * max(marks[i].w, 0.001);
		d = min(d, length(from) * cos(around) / size);
	}
	if (count > 0) {
		float edge = 0.08;
		float pool = 1.0 - smoothstep(1.0 - edge, 1.0, d);
		float core = 1.0 - smoothstep(0.58 - edge * 0.5, 0.58, d);
		shade = pool * 0.4 + core * 0.12;
		float rim = exp(-pow((d - 1.0) / 0.06, 2.0));
		add += glow * rim * (0.55 + 0.2 * pouring);
	}
	for (int i = 0; i < 32; i++) {
		float since = age - landings[i].z;
		if (landings[i].w < 0.5 || since < 0.0 || since > 0.5) continue;
		float e = length(world.xz - landings[i].xy);
		float ring = exp(-pow((e - since * 0.4) / 0.02, 2.0)) * (1.0 - since / 0.5);
		add += glow * ring * 0.8;
		shade = max(shade, exp(-e * e / 0.004) * 0.3 * (1.0 - since / 0.5));
	}
	ALBEDO = add;
	ALPHA = clamp(shade, 0.0, 1.0);
}
