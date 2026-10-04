shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never;
// Breeze ribbons (scripts/breeze_ribbons.gd, docs/scenic/breeze-ribbons.md):
// the path a mote of air took, painted as one brush stroke. Laid down
// thick and bright at the head, it thins and dries out toward the tail,
// where the bristles part into streaks. It swells and narrows along its
// length as a hand's pressure would, is soft across, takes the sky's and
// the sun's light (brighter looking toward the sun) and the scene's fog.
// Attributes: VERTEX the path's centre (world: the node sits at the
// origin); NORMAL the path's way; UV.x metres back from the head, UV.y 0..1
// across; UV2.x true width (m), .y opacity; COLOR.b seed, .a 0 tail..1 head
// (width and opacity stay out of COLOR, which arrives sRGB-decoded).
#include "res://shaders/reference_globals.gdshaderinc"
// Drawn at least RB_MIN_PIXELS wide (thinning its opacity to match) and at
// most RB_MAX_PIXELS, so far strokes are threads and near ones never tape.
uniform float glow = 2.0;
uniform int debug_view = 0;
varying vec3 rb_debug;
const float RB_MIN_PIXELS = 2.0;
const float RB_MAX_PIXELS = 22.0;
varying float rb_u;
varying float rb_cover;
varying float rb_facing;
varying float rb_sun;
varying float rb_seed;
varying float rb_opacity;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 way = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	rb_u = COLOR.a;
	rb_seed = COLOR.b * 100.0;
	rb_opacity = UV2.y;
	// A brush's pressure: a fine needle at the head, full just behind, a
	// long run down to nothing at the tail, swelling and easing along it.
	float rb_taper = smoothstep(0.0, 0.35, rb_u) * (1.0 - smoothstep(0.9, 1.0, rb_u));
	float rb_press = 0.7 + 0.3 * sin(UV.x * 0.9 + rb_seed) * sin(UV.x * 0.37 + rb_seed * 1.7);
	vec3 rb_to_cam = CAMERA_POSITION_WORLD - world;
	float rb_dist = length(rb_to_cam);
	rb_to_cam /= max(rb_dist, 0.001);
	vec3 rb_across = cross(way, rb_to_cam);
	rb_facing = length(rb_across);
	rb_across = rb_facing > 0.001 ? rb_across / rb_facing : vec3(0.0, 1.0, 0.0);
	// Metres per screen pixel here, measured: a metre across the stroke,
	// projected to the screen.
	vec4 rb_c0 = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	vec4 rb_c1 = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world + rb_across, 1.0);
	float rb_span = length((rb_c1.xy / rb_c1.w - rb_c0.xy / rb_c0.w) * VIEWPORT_SIZE * 0.5);
	float rb_pixel = 1.0 / max(rb_span, 0.001);
	float rb_true = min(UV2.x * rb_taper * rb_press, rb_pixel * RB_MAX_PIXELS);
	float rb_drawn = max(rb_true, rb_pixel * RB_MIN_PIXELS * step(0.0005, rb_taper));
	rb_debug = vec3(UV2.x * 4.0, rb_u, rb_drawn / rb_pixel / 22.0);
	rb_cover = rb_drawn > 0.0 ? clamp(rb_true / rb_drawn, 0.0, 1.0) : 0.0;
	world += rb_across * (UV.y - 0.5) * rb_drawn;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	rb_sun = max(dot(-rb_to_cam, normalize(zs_sun_direction + vec3(0.0, 1e-4, 0.0))), 0.0);
}

float rb_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float rb_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(rb_hash(i), rb_hash(i + vec2(1.0, 0.0)), f.x), mix(rb_hash(i + vec2(0.0, 1.0)), rb_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float v = (UV.y - 0.5) * 2.0;
	// A loaded brush: a soft wash the full width and a brighter core a
	// little to one side, as paint gathers on the brush's heel.
	float rb_wash = (1.0 - smoothstep(0.4, 1.0, abs(v))) * 0.55;
	float rb_core_v = (v + 0.15) * 2.4;
	float rb_soft = max(rb_wash, exp(-rb_core_v * rb_core_v));
	// The brush dries toward the tail: a soft grain along the stroke. It
	// thins the paint but never breaks it, so a tail never reads as dashes.
	float rb_dry = 1.0 - rb_u;
	float rb_bristle = rb_noise(vec2(UV.x * 0.55 + rb_seed, v * 4.5 + rb_seed * 0.3));
	float rb_paint = mix(1.0, 0.55 + 0.45 * rb_bristle, smoothstep(0.5, 1.0, rb_dry));
	// Brightest just behind the head, fading down the tail.
	float rb_body = mix(0.3, 1.0, sqrt(rb_u));
	float rb_side_on = smoothstep(0.12, 0.5, rb_facing);
	vec3 sun = zs_key_irradiance / PI * zs_celestial_clear * zs_daylight;
	vec3 sky = zs_hemi_sky * zs_hemi_energy / PI;
	float scatter = pow(rb_sun, 5.0);
	vec3 light = sky * 1.15 + sun * (0.4 + 0.9 * scatter) + vec3(0.02 + 0.03 * zs_night);
	ALBEDO = vec3(0.95, 0.97, 1.0) * light * glow;
	ALPHA = clamp(rb_opacity * rb_body * rb_paint * rb_soft * rb_side_on * mix(0.75, 1.0, rb_cover) * (0.85 + 0.5 * scatter), 0.0, 1.0);
	if (debug_view == 1) { ALBEDO = rb_debug; ALPHA = 1.0; }
}
