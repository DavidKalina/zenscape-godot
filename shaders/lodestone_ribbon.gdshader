shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never;
// The lodestone's swirl painted (scripts/lodestone.gd): each stroke the
// trace of a mote of the current round the stone (shaders/
// lodestone_vortex.gdshaderinc), laid with the breeze ribbons' brush
// (shaders/breeze_ribbon_paint.gdshaderinc, as the plate's breeze and the
// sky's jet streams are painted): a fine needle at the head, full just
// behind, drying out down the tail. Warm white to a pale gold, lit by the
// sky as the breeze is and a breath of its own light besides, more as the
// stone hums. The vertex at `UV.x` (0 tail..1 head) stands where the mote
// stood that share of the tail ago, so the stroke travels with the air.
// Instance custom data: seed, orbit (0 inner..1 outer), level (0 low..1
// high), the tail's length (s, / 4).
#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/breeze_ribbon_paint.gdshaderinc"
#include "res://shaders/lodestone_vortex.gdshaderinc"

uniform vec3 warm : source_color = vec3(1.0, 0.97, 0.9);
uniform vec3 gold : source_color = vec3(1.0, 0.86, 0.6);
// Streaming, the strokes run a deeper gold, so they read against cloud.
uniform vec3 stream_gold : source_color = vec3(0.95, 0.6, 0.26);
// The stroke's true width (m, in the lodestone's frame), its opacity, how
// much of the sky's light it takes and how much light of its own it has.
uniform float width = 0.012;
uniform float opacity = 0.8;
uniform float sky_light = 0.7;
uniform float own_light = 0.55;
const float LR_MIN_PIXELS = 1.8;
const float LR_MAX_PIXELS = 12.0;

varying float lr_u;
varying float lr_cover;
varying float lr_facing;
varying float lr_sun;
varying float lr_seed;
varying float lr_fade;

void vertex() {
	float seed = INSTANCE_CUSTOM.r;
	float orbit = INSTANCE_CUSTOM.g;
	float level = INSTANCE_CUSTOM.b * 2.0 - 1.0;
	float tail = INSTANCE_CUSTOM.a * 4.0;
	lr_u = UV.x;
	lr_seed = seed * 100.0;
	float back = (1.0 - UV.x) * tail;
	vec3 here = lv_path(seed, orbit, level, back);
	vec3 before = lv_path(seed, orbit, level, back + 0.03);
	vec3 world = (MODEL_MATRIX * vec4(here, 1.0)).xyz;
	vec3 way = (MODEL_MATRIX * vec4(here - before, 0.0)).xyz;
	way = length(way) > 1e-6 ? normalize(way) : vec3(1.0, 0.0, 0.0);
	float scale = length(MODEL_MATRIX[0].xyz);
	float taper = rb_taper_at(lr_u);
	float press = rb_pressure_at(back * 6.0, lr_seed);
	vec3 to_cam = CAMERA_POSITION_WORLD - world;
	float dist = length(to_cam);
	to_cam /= max(dist, 1e-4);
	vec3 across = cross(way, to_cam);
	lr_facing = length(across);
	across = lr_facing > 0.001 ? across / lr_facing : vec3(0.0, 1.0, 0.0);
	vec4 c0 = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	vec4 c1 = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world + across, 1.0);
	float span = length((c1.xy / c1.w - c0.xy / c0.w) * VIEWPORT_SIZE * 0.5);
	float pixel = 1.0 / max(span, 1e-4);
	float true_width = min(width * scale * mix(0.7, 1.3, fract(seed * 7.3)) * taper * press, pixel * LR_MAX_PIXELS);
	float drawn = max(true_width, pixel * LR_MIN_PIXELS * step(0.0005, taper));
	lr_cover = drawn > 0.0 ? clamp(true_width / drawn, 0.0, 1.0) : 0.0;
	world += across * (UV.y - 0.5) * drawn;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	lr_sun = max(dot(-to_cam, normalize(zs_sun_direction + vec3(0.0, 1e-4, 0.0))), 0.0);
	lr_fade = lv_stream_fade(seed);
}

void fragment() {
	float v = (UV.y - 0.5) * 2.0;
	float scatter = pow(lr_sun, 5.0);
	vec3 tint = mix(mix(warm, gold, fract(lr_seed * 0.137)), stream_gold, stream * 0.7);
	vec3 light = rb_paint_light(scatter) * sky_light + vec3(own_light * (0.7 + 0.6 * hum + 0.3 * stream));
	ALBEDO = tint * light;
	ALPHA = clamp(opacity * lr_fade * rb_paint_alpha(lr_u, (1.0 - lr_u) * 6.0, v, lr_seed, lr_facing, lr_cover, scatter), 0.0, 1.0);
}
