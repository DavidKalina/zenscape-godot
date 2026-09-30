shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, depth_test_disabled, cull_front, fog_disabled;
// The in-hand ground mark (scripts/ground_marks.gd, docs/design/materials-tray/
// CURSOR-MARKS.md): the design's "cursor sketch" for what is in hand, drawn
// on the land as a decal. A box round the mark reads the depth buffer back to
// the ground it covers (the pollen footprint's way, shaders/pollen_footprint.
// gdshader), so the mark lies on the terrain's facets wherever they fall.
// Shapes are laid out in world metres (so a mark matches the ground a verb
// touches); line widths, dots and stitch gaps are in screen pixels read from
// the reconstructed ground's derivatives, so the stitching stays crisp at
// every zoom, as the linen HUD's hem does.
// Premultiplied: ALBEDO is the cream laid over, ALPHA how much of the ground
// it covers. fog_disabled, or the fog paints the whole box (a premultiplied
// decal's gotcha).
#include "res://shaders/reference_globals.gdshaderinc"
uniform sampler2D ground_depth : hint_depth_texture, filter_nearest, repeat_disable;

// 0 hand, 1 paddle, 2 chisel, 3 wire, 4 hammer, 5 material.
uniform int mark_kind = 0;
// World centre, the mark's major axis (a unit vector along the ground's
// plane: the paddle's width, the chisel's downhill edge), the ground's normal
// there, and half extents (metres) along the axis and across it.
uniform vec3 mark_centre = vec3(0.0);
uniform vec3 mark_axis = vec3(1.0, 0.0, 0.0);
uniform vec3 mark_normal = vec3(0.0, 1.0, 0.0);
uniform vec2 mark_half = vec2(1.0);
// The wire's two ends (world).
uniform vec3 wire_from = vec3(0.0);
uniform vec3 wire_to = vec3(0.0);
// The hammer's scree: world x, z and radius (metres) of each speck.
const int SPECKS = 6;
uniform vec4 specks[SPECKS];
uniform int speck_count = 0;
// How much shows (the fade), the line's and the fill's alpha at full show.
uniform float shown = 0.0;
uniform float line_alpha = 0.3;
uniform float fill_alpha = 0.0;
// Pixels: the line's width, a dot's radius (the material's drop ring and the
// wire's toggles).
uniform float line_px = 1.5;
uniform float dot_px = 1.6;
uniform float toggle_px = 3.0;
// Stitches round a loop, and the share of each that is thread.
uniform float stitches = 24.0;
uniform float stitch_duty = 0.55;
// Nothing above this world height is painted (keeps trees and props clean).
uniform float ceiling = 0.0;
// The cream (linear), and how far night dims it.
uniform vec3 mark_tone = vec3(1.0, 0.955, 0.871);
uniform float night_dim = 0.55;

// Anti-aliased 0..1 coverage of |d| within half of `width` (all in pixels).
float band(float d_px, float width) {
	return 1.0 - smoothstep(width * 0.5 - 0.5, width * 0.5 + 0.5, abs(d_px));
}

float disc(float d_px, float radius) {
	return 1.0 - smoothstep(radius - 0.5, radius + 0.5, d_px);
}

// A stitch pattern round a loop at turn share `t` (0..1): 1 on thread.
float stitch(float t, float count, float duty) {
	float phase = fract(t * count);
	// Across the atan seam the raw phase jumps; read its rate on a shifted copy.
	float rate = min(fwidth(phase), fwidth(fract(t * count + 0.5)));
	rate = max(rate, 1e-4);
	float on = smoothstep(-rate, rate, phase) * (1.0 - smoothstep(duty - rate, duty + rate, phase));
	return on;
}

void fragment() {
	float depth = textureLod(ground_depth, SCREEN_UV, 0.0).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	vec3 box = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	// Out of the box or above the ceiling: nothing, but only after the
	// derivatives below are read, so every pixel of a quad takes part in them.
	bool outside = any(greaterThan(abs(box), vec3(0.5))) || world.y > ceiling;

	// The ground's own frame at the centre: u along the axis, v across it.
	vec3 across = normalize(cross(mark_normal, mark_axis));
	vec3 rel = world - mark_centre;
	vec2 q = vec2(dot(rel, mark_axis), dot(rel, across));
	// Metres per pixel on the ground here.
	float mpp = max(length(fwidth(world)), 1e-4);

	float line = 0.0;
	float fill = 0.0;
	if (mark_kind == 2) {
		// The chisel: a hard square in the face's plane, one solid line.
		float d = max(abs(q.x), abs(q.y)) - mark_half.x;
		line = band(d / mpp, line_px);
	} else if (mark_kind == 3) {
		// The wire: a straight line press to pointer, a toggle at each end.
		vec2 a = wire_from.xz;
		vec2 ab = wire_to.xz - a;
		float along = clamp(dot(world.xz - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
		float d = length(world.xz - (a + ab * along));
		line = band(d / mpp, line_px);
		float ends = min(length(world.xz - wire_from.xz), length(world.xz - wire_to.xz)) / mpp;
		line = max(line, disc(ends, toggle_px));
	} else {
		// A loop: an ellipse with half extents mark_half in the ground's frame.
		vec2 n = q / max(mark_half, vec2(1e-3));
		float r = length(n);
		// Distance to the loop along the ray from the centre, in metres.
		float d = (r - 1.0) * length(q) / max(r, 1e-4);
		float t = atan(n.y, n.x) / TAU + 0.5;
		if (mark_kind == 5) {
			// The drop ring: round dots, evenly round the loop.
			float k = floor(t * stitches + 0.5) / stitches;
			float angle = (k - 0.5) * TAU;
			vec2 dot_at = vec2(cos(angle), sin(angle)) * mark_half;
			line = disc(length(q - dot_at) / mpp, dot_px);
		} else {
			line = band(d / mpp, line_px) * stitch(t, stitches, stitch_duty);
		}
		if (mark_kind == 0) fill = 1.0 - smoothstep(-0.5, 0.5, d / mpp);
		if (mark_kind == 4) {
			for (int i = 0; i < SPECKS; i++) {
				if (i >= speck_count) break;
				float to = length(world.xz - specks[i].xy) / mpp;
				line = max(line, disc(to, max(specks[i].z / mpp, 1.2)));
			}
		}
	}
	float alpha = clamp(max(line * line_alpha, fill * fill_alpha) * shown, 0.0, 1.0);
	if (outside || alpha <= 0.001) discard;
	vec3 tone = mark_tone * mix(1.0, 1.0 - night_dim, zs_night);
	ALBEDO = tone * alpha;
	ALPHA = alpha;
}
