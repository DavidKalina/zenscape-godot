shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never;
// What rides the lodestone's current (scripts/lodestone.gd), one quad an
// instance facing the eye, carried round on the swirl's own paths
// (shaders/lodestone_vortex.gdshaderinc): motes (soft specks of warm
// light), petals (pale, tumbling as they turn), glints (a four-pointed
// twinkle that comes and goes) and wisps of cloud (soft puffs low round
// the miniature, slower and wider, as clouds about an island). Instance
// custom data: seed, orbit (0..1), level (0 low..1 high), kind (0 mote,
// 0.33 petal, 0.66 glint, 1 wisp).
#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/breeze_ribbon_paint.gdshaderinc"
#include "res://shaders/lodestone_vortex.gdshaderinc"

uniform vec3 warm : source_color = vec3(1.0, 0.97, 0.9);
uniform vec3 gold : source_color = vec3(1.0, 0.85, 0.58);
uniform vec3 petal : source_color = vec3(0.98, 0.9, 0.86);
uniform vec3 cloud : source_color = vec3(0.97, 0.96, 0.95);
// Each kind's size (m, the lodestone's frame): mote, petal, glint, wisp.
uniform vec4 sizes = vec4(0.006, 0.012, 0.016, 0.07);
uniform float opacity = 1.0;
// How thick the wisps are (0 none).
uniform float wisps = 1.0;

varying float lm_kind;
varying float lm_seed;
varying float lm_fade;
varying float lm_twinkle;
varying float lm_sun;

void vertex() {
	float seed = INSTANCE_CUSTOM.r;
	float orbit = INSTANCE_CUSTOM.g;
	float level = INSTANCE_CUSTOM.b * 2.0 - 1.0;
	float kind = INSTANCE_CUSTOM.a;
	lm_kind = kind;
	lm_seed = seed;
	vec3 at;
	float size;
	if (kind > 0.85) {
		// A wisp: low round the miniature's foot, turning slowly.
		float a = seed * 6.2831853 + swirl * 0.22 + sin(clock * 0.13 + seed * 9.0) * 0.4;
		float r = swirl_radius * mix(0.42, 0.78, orbit);
		at = vec3(cos(a) * r, (level * 0.25 - 0.85) * swirl_height + sin(clock * 0.3 + seed * 5.0) * 0.01, sin(a) * r);
		if (stream > 0.001) at = mix(at, lv_streaming(seed, orbit * 0.6, -0.3, 0.0), smoothstep(0.0, 1.0, stream) * 0.8);
		size = sizes.w * mix(0.7, 1.3, fract(seed * 13.1)) * wisps;
	} else {
		at = lv_path(seed, orbit, level, 0.0);
		size = kind < 0.2 ? sizes.x : (kind < 0.5 ? sizes.y : sizes.z);
		size *= mix(0.6, 1.4, fract(seed * 17.3));
	}
	lm_fade = lv_stream_fade(seed);
	lm_twinkle = pow(0.5 + 0.5 * sin(clock * mix(1.3, 2.6, fract(seed * 5.1)) + seed * 40.0), 5.0);
	if (kind > 0.5 && kind < 0.85) size *= mix(0.25, 1.0, lm_twinkle) * (1.0 + 0.4 * hum);
	vec3 world = (MODEL_MATRIX * vec4(at, 1.0)).xyz;
	float scale = length(MODEL_MATRIX[0].xyz);
	vec2 corner = UV * 2.0 - 1.0;
	if (kind > 0.2 && kind < 0.5) {
		// A petal tumbles: turned in the view and flipped edge-on by turns.
		float spin_a = clock * mix(0.8, 2.2, fract(seed * 3.3)) + seed * 30.0;
		corner = mat2(vec2(cos(spin_a), sin(spin_a)), vec2(-sin(spin_a), cos(spin_a))) * (corner * vec2(1.0, mix(0.25, 1.0, abs(sin(clock * 1.7 + seed * 12.0)))));
	}
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	world += (right * corner.x + up * corner.y) * size * scale * 0.5;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - world);
	lm_sun = max(dot(-to_cam, normalize(zs_sun_direction + vec3(0.0, 1e-4, 0.0))), 0.0);
}

float lm_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(lv_hash(i), lv_hash(i + vec2(1.0, 0.0)), f.x), mix(lv_hash(i + vec2(0.0, 1.0)), lv_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	vec3 sky = rb_paint_light(pow(lm_sun, 5.0));
	vec3 colour;
	float a;
	if (lm_kind < 0.2) {
		// A mote: a soft speck of warm light.
		a = exp(-r2 * 7.0) * (0.75 + 0.5 * hum);
		colour = mix(warm, gold, fract(lm_seed * 9.7)) * (1.1 + 0.6 * hum);
	} else if (lm_kind < 0.5) {
		// A petal: a pointed oval, pale, lit by the sky with light through it.
		vec2 q = p * vec2(1.0, 1.0);
		float oval = q.x * q.x * 2.2 + pow(abs(q.y), 1.6);
		a = (1.0 - smoothstep(0.55, 0.85, oval)) * 0.9;
		colour = petal * (sky * 0.75 + vec3(0.3 + 0.2 * hum)) * mix(0.9, 1.05, p.y * 0.5 + 0.5);
	} else if (lm_kind < 0.85) {
		// A glint: a four-pointed star of pale gold, twinkling.
		vec2 d = abs(p);
		float rays = max(exp(-d.x * 26.0 - d.y * d.y * 2.5), exp(-d.y * 26.0 - d.x * d.x * 2.5));
		a = (rays * 0.8 + exp(-r2 * 30.0)) * lm_twinkle;
		colour = mix(warm, gold, 0.6) * (1.5 + hum);
	} else {
		// A wisp of cloud: a soft puff, torn at its edges.
		float n = lm_noise(p * 2.2 + vec2(lm_seed * 40.0, clock * 0.05)) * 0.6 + lm_noise(p * 5.0 + lm_seed * 17.0) * 0.4;
		a = (1.0 - smoothstep(0.05, 1.0, sqrt(r2) + (n - 0.5) * 0.7)) * 0.2;
		colour = cloud * (sky * 0.85 + vec3(0.28 + 0.15 * hum));
	}
	ALBEDO = colour;
	ALPHA = clamp(a * lm_fade * opacity, 0.0, 1.0);
}
