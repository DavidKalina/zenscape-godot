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
#include "res://shaders/breeze_ribbon_paint.gdshaderinc"
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
	// The brush's pressure (shaders/breeze_ribbon_paint.gdshaderinc).
	float rb_taper = rb_taper_at(rb_u);
	float rb_press = rb_pressure_at(UV.x, rb_seed);
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

void fragment() {
	float v = (UV.y - 0.5) * 2.0;
	float scatter = pow(rb_sun, 5.0);
	ALBEDO = vec3(0.95, 0.97, 1.0) * rb_paint_light(scatter) * glow;
	ALPHA = clamp(rb_opacity * rb_paint_alpha(rb_u, UV.x, v, rb_seed, rb_facing, rb_cover, scatter), 0.0, 1.0);
	if (debug_view == 1) { ALBEDO = rb_debug; ALPHA = 1.0; }
}
