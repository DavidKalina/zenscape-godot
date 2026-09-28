shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, depth_test_disabled, cull_front, fog_disabled;
// The seed handful's mark (scripts/seed_handful.gd): where its seeds will
// land, painted on the ground as a decal (a box around the spot reads the
// depth buffer back to the ground it covers). It lies straight below the
// handful, never along the sun: a softly darkened disc inside a bright ring
// with a dark outline outside it, so it reads on pale and dark ground alike.
// While the handful is held, faint rings draw in toward its middle; once the
// seeds are loose the disc brightens a little, and each landing rings out.
// Premultiplied: ALBEDO is light added, ALPHA how much of the ground is dimmed.
#include "res://shaders/reference_globals.gdshaderinc"
uniform sampler2D ground_depth : hint_depth_texture, filter_nearest, repeat_disable;
// The mark's centre on the ground (world) and radius (world metres).
uniform vec3 mark_center = vec3(0.0);
uniform float mark_radius = 1.0;
// How much of the mark shows, and 1 once the seeds are loose.
uniform float shown = 0.0;
uniform float sowing = 0.0;
// Nothing above this world height is painted (keeps the seeds clean).
uniform float ceiling = 0.0;
uniform float age = 0.0;
// Seeds landed: world x, z, the age they landed, and 1 when in use.
uniform vec4 landings[32];

void fragment() {
	float depth = textureLod(ground_depth, SCREEN_UV, 0.0).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	vec3 box = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	if (any(greaterThan(abs(box), vec3(0.5))) || world.y > ceiling) discard;
	vec3 light = zs_key_irradiance / PI * zs_celestial_clear;
	// Warm light that still reads at dusk and at night.
	vec3 glow = vec3(1.0, 0.9, 0.66) * (light * 0.55 * zs_daylight + 0.28);
	vec2 from = world.xz - mark_center.xz;
	float d = length(from);
	float r = mark_radius;
	float width = max(0.05, r * 0.022);
	float inside = 1.0 - smoothstep(r - width, r, d);
	// The disc: a soft darkening, a touch deeper toward the rim.
	float shade = inside * mix(0.1, 0.2, smoothstep(0.0, r, d));
	vec3 add = glow * inside * (0.04 + sowing * 0.06);
	// The rim: a bright band, slowly turning dashes along it, and a dark
	// outline just outside.
	float around = atan(from.y, from.x) / TAU;
	float dashes = max(6.0, floor(r * 7.0));
	float dash = smoothstep(0.35, 0.5, abs(fract(around * dashes - age * 0.06) - 0.5) * 2.0);
	float band = exp(-pow((d - r) / width, 2.0));
	add += glow * band * mix(0.55, 1.0, dash) * 0.9;
	float outline = exp(-pow((d - r - width * 1.8) / (width * 0.9), 2.0));
	shade = max(shade, outline * 0.4 + band * 0.25);
	// Held: faint rings drawing in toward the middle, the seeds gathering.
	if (sowing < 0.5) {
		float pull = fract(age * 0.7);
		float ring = exp(-pow((d - r * (1.0 - pull)) / (width * 1.5), 2.0)) * pull * (1.0 - pull) * 4.0;
		add += glow * ring * 0.18 * inside;
	}
	// A small bright point at the middle, so the centre reads under the cloud.
	add += glow * exp(-d * d / (width * width * 2.0)) * 0.5;
	for (int i = 0; i < 32; i++) {
		float since = age - landings[i].z;
		if (landings[i].w < 0.5 || since < 0.0 || since > 0.6) continue;
		float e = length(world.xz - landings[i].xy);
		float ring = exp(-pow((e - since * 0.45) / 0.025, 2.0)) * (1.0 - since / 0.6);
		add += glow * ring * 0.7;
		shade = max(shade, exp(-e * e / 0.006) * 0.3 * (1.0 - since / 0.6));
	}
	ALBEDO = add * shown;
	ALPHA = clamp(shade * shown, 0.0, 1.0);
}
