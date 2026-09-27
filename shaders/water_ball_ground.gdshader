shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, depth_test_disabled, cull_front, fog_disabled;
// What the water ball (scripts/water_ball.gd) does to the ground under it,
// painted as a decal: a box around the spot reads the depth buffer back to the
// ground it covers. While the ball is held its shadow lies on the ground with
// the sun gathered to a rippling caustic inside it, and drips that fall from it
// ring out where they land. After it bursts, the ground darkens wet under a
// ring of foam that runs out and breaks up.
// Premultiplied: ALBEDO is light added, ALPHA how much of the ground is dimmed.
#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/pool_caustics.gdshaderinc"
uniform sampler2D ground_depth : hint_depth_texture, filter_nearest, repeat_disable;
// The ball's centre (world), radius (m) and how much of the held look shows.
uniform vec3 ball_center = vec3(0.0);
uniform float radius = 1.0;
uniform float held = 0.0;
// Nothing above this world height is painted (keeps the ball's fish clean).
uniform float ceiling = 0.0;
// Seconds since the splash (negative: none), and how far its foam runs (m).
uniform float splash = -1.0;
uniform float reach = 3.0;
// Drips landed: world x, z, and the age they landed.
uniform vec4 drops[4];
uniform float age = 0.0;

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float depth = textureLod(ground_depth, SCREEN_UV, 0.0).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	vec3 box = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	if (any(greaterThan(abs(box), vec3(0.5))) || world.y > ceiling) discard;
	vec3 light = zs_key_irradiance / PI * zs_celestial_clear;
	float shade = 0.0;
	vec3 add = vec3(0.0);
	if (held > 0.001) {
		// The shadow falls along the sun; a soft contact darkening sits right
		// under the ball so it is clear where it will land.
		vec3 sun = normalize(vec3(zs_key_direction.x, max(zs_key_direction.y, 0.25), zs_key_direction.z));
		float above = ball_center.y - world.y;
		vec2 image = ball_center.xz - sun.xz / sun.y * above;
		float d = length(world.xz - image) / radius;
		float shadow = (1.0 - smoothstep(0.55, 1.05, d)) * 0.42;
		float under = exp(-pow(length(world.xz - ball_center.xz) / (radius * 1.2), 2.0) * 1.5) * 0.18;
		// The ball is a lens: it gathers the sun to a bright, restless spot.
		float focus = exp(-d * d * 10.0);
		float play = d < 0.9 ? zs_pool_caustics((world.xz - image) / radius * 3.4 + vec2(age * 0.15, 0.0), age * 2.4) * (0.4 + 0.6 * noise2((world.xz - image) * 4.0 + age)) : 0.0;
		shade = max(shadow, under) * (1.0 - focus * 0.8);
		add += light * (focus * (0.3 + play * 0.6) + (1.0 - smoothstep(0.2, 0.85, d)) * play * 0.22) * 0.5 * zs_daylight;
		shade *= held;
		add *= held;
	}
	for (int i = 0; i < 4; i++) {
		float since = age - drops[i].z;
		if (drops[i].w < 0.5 || since < 0.0 || since > 0.9) continue;
		float d = length(world.xz - drops[i].xy);
		float ring = exp(-pow((d - since * 0.9) / 0.03, 2.0)) * (1.0 - since / 0.9);
		add += vec3(0.8, 0.9, 0.9) * light * ring * 0.25;
		shade = max(shade, exp(-d * d / 0.01) * 0.25 * (1.0 - since / 0.9));
	}
	if (splash >= 0.0 && splash < 4.5 && length(world.xz - ball_center.xz) < reach * 1.4) {
		vec2 from = world.xz - ball_center.xz;
		float d = length(from);
		float around = atan(from.y, from.x);
		// The wet patch spreads with the water and dries back slowly.
		float spread = reach * (1.0 - exp(-splash * 3.5));
		float wobble = noise2(vec2(around * 3.0, 1.0)) * 0.25 + 0.85;
		float inside = 1.0 - smoothstep(spread * wobble * 0.8, spread * wobble, d);
		float wet = inside * (1.0 - smoothstep(1.5, 4.5, splash));
		shade = max(shade, wet * 0.3);
		// While it runs, the wash is a thin film of the ponds' water with light
		// playing through it.
		float film = inside * (1.0 - smoothstep(0.5, 1.6, splash));
		float play = film > 0.01 ? zs_pool_caustics(world.xz * 3.5 - from * splash * 0.8, age * 3.0) * noise2(world.xz * 1.3 + splash) : 0.0;
		vec3 sky_light = zs_hemi_sky * zs_hemi_energy / PI;
		add += (vec3(0.19, 0.42, 0.33) * (light * 0.5 + sky_light) * 0.5 + light * play * 0.14) * film;
		shade = max(shade, film * 0.45);
		// A foam ring runs out ahead of it and breaks into lace.
		float front = spread * wobble;
		float band = exp(-pow((d - front) / (0.12 + splash * 0.1), 2.0));
		float lace = smoothstep(0.35 + splash * 0.3, 0.8, noise2(from * 5.0 + vec2(splash * 0.8, 0.0)) * 0.6 + noise2(from * 13.0) * 0.4);
		float foam = band * lace * (1.0 - smoothstep(0.3, 1.8, splash));
		// Inner rings follow it out.
		float rings = pow(0.5 + 0.5 * sin((d - splash * 1.6) * 14.0), 8.0) * step(d, front) * (1.0 - smoothstep(0.2, 1.4, splash)) * 0.35;
		vec3 foam_light = light * max(zs_key_direction.y, 0.2) + zs_hemi_sky * zs_hemi_energy / PI;
		add += vec3(0.86, 0.94, 0.93) * foam_light * (foam * 1.3 + rings * lace);
		shade = max(shade, foam * 0.6);
	}
	ALBEDO = add;
	ALPHA = clamp(shade, 0.0, 1.0);
}
